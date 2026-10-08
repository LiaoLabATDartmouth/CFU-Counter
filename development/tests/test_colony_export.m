function tests=test_colony_export
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
app=ColonyCounterApp(fullfile(root,'Examples','IMG_7489.jpeg'),'off');
cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.applySettings(); assert(isempty(app.LastError));
r=app.Result;
labels=["AD24","AD9","Uncertain","Not a colony"];
for n=1:4, r=edit_colony(r,'classify',r.Colonies.ID(n),labels(n)); end
testCase.TestData.Result=r;
end

function testSnapshotAndFigureMatchEveryCurrentLabel(testCase)
[T,S,r]=colony_export_tables(testCase.TestData.Result);
verifyEqual(testCase,T.Label(1:4),["AD24";"AD9";"Need review";"Not a colony"]);
verifyEqual(testCase,T.AnnotationColor(1:4),["Orange";"Cyan";"White / black";"None"]);
verifyEqual(testCase,S.Count(S.Label=="AD24"),sum(T.Label=="AD24"));
verifyEqual(testCase,S.Count(S.Label=="AD9"),sum(T.Label=="AD9"));
fig=plot_colonies(r,true,'off'); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
ids=findobj(fig,'Tag','ColonyID'); palette=colony_annotation_styles();
verifyEqual(testCase,numel(ids),sum(T.IncludedInCount));
for n=1:numel(ids)
    data=ids(n).UserData; row=find(T.ID==data.ID);
    verifyTrue(testCase,T.IncludedInCount(row));
    verifyEqual(testCase,data.Label,T.Label(row));
    verifyEqual(testCase,string(ids(n).String),string(T.ID(row)));
    verifyEqual(testCase,ids(n).Color,palette.Colors(palette.Labels==data.Label,:));
end
circles=findobj(fig,'Tag','ColonyCircles');
for n=1:numel(circles)
    data=circles(n).UserData;
    verifyEqual(testCase,sort(data.IDs),sort(T.ID(T.Label==data.Label)));
end
review=findobj(fig,'Tag','ColonyWarning');
verifyEqual(testCase,sort(review.UserData.IDs),sort(T.ID(T.Label=="Need review")));
end

function testExactlyTwoFilesTwoSheetsAndMatchingCounts(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder=fixture.Folder; r=testCase.TestData.Result;
r.Summary.AD9=999; % Saving must recompute counts from current labels.
files=save_colony_app_results(r,folder);
verifyEqual(testCase,string(sheetnames(files.Workbook)),["Colonies";"Summary"]);
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(testCase,sort(string({listing.name})),["IMG_7489_annotated.png","IMG_7489_colonies.xlsx"]);
verifyFalse(testCase,any([listing.isdir]));
T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
S=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
verifyEqual(testCase,height(T),height(r.Colonies));
verifyEqual(testCase,T.Label(1:4),["AD24";"AD9";"Need review";"Not a colony"]);
for label=["AD24","AD9","Need review","Not a colony"]
    verifyEqual(testCase,S.Count(S.Label==label),sum(T.Label==label));
end
verifyEqual(testCase,S.Count(S.Label=="Total included"),sum(T.IncludedInCount));
verifyFalse(testCase,ismember('ReviewReason',T.Properties.VariableNames));
verifyTrue(testCase,isfile(files.Annotated));
% Check the workbook stores the same visible colors as the shared palette.
unzipped=tempname; unzip(files.Workbook,unzipped);
cleanup=onCleanup(@()rmdir(unzipped,'s')); %#ok<NASGU>
doc=xmlread(fullfile(unzipped,'xl','worksheets','sheet1.xml'));
styles=xmlread(fullfile(unzipped,'xl','styles.xml'));
expectedFill={'FFFFA600','FF1AE6FF','FF0D0D0D','FFEBEBEB'};
for n=1:4
    [fill,font]=cellColors(doc,styles,sprintf('B%d',n+1));
    verifyEqual(testCase,fill,expectedFill{n});
    if n==3, verifyEqual(testCase,font,'FFFFFFFF'); end
end
verifyEqual(testCase,doc.getElementsByTagName('autoFilter').getLength(),1);
verifyEqual(testCase,doc.getElementsByTagName('pane').getLength(),1);
end

function testImageStemAndPairedCollisionSuffix(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder=fixture.Folder; r=testCase.TestData.Result;
r.ImageFile=fullfile(folder,'my plate.sample.HEIC');
existing=fullfile(folder,'my plate.sample_annotated.png');
imwrite(zeros(3,3,3),existing); original=imread(existing);
first=save_colony_app_results(r,folder);
verifyEqual(testCase,first.Workbook,fullfile(folder,'my plate.sample_2_colonies.xlsx'));
verifyEqual(testCase,first.Annotated,fullfile(folder,'my plate.sample_2_annotated.png'));
second=save_colony_app_results(r,folder);
verifyEqual(testCase,second.Workbook,fullfile(folder,'my plate.sample_3_colonies.xlsx'));
verifyEqual(testCase,second.Annotated,fullfile(folder,'my plate.sample_3_annotated.png'));
verifyEqual(testCase,imread(existing),original);
verifyTrue(testCase,isfile(first.Workbook) && isfile(first.Annotated));
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(testCase,numel(listing),5); verifyFalse(testCase,any([listing.isdir]));
end

function testNoFolderCreationAndNoPartialInvalidExport(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder=fixture.Folder; missing=fullfile(folder,'do not create');
verifyError(testCase,@()save_colony_app_results(testCase.TestData.Result,missing),'CFU:OutputFolderMissing');
verifyFalse(testCase,isfolder(missing));
r=testCase.TestData.Result; r.Colonies.Class(1)="invalid";
verifyError(testCase,@()save_colony_app_results(r,folder),'CFU:InvalidClass');
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEmpty(testCase,listing);
end

function testEmptyPlateExportsHeadersAndZeroCounts(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
r=testCase.TestData.Result; r.Colonies=r.Colonies([],:); r.Labels(:)=0;
files=save_colony_app_results(r,fixture.Folder);
T=readtable(files.Workbook,'Sheet','Colonies');
S=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
verifyEqual(testCase,height(T),0); verifyEqual(testCase,S.Count,zeros(5,1));
verifyTrue(testCase,isfile(files.Annotated));
end

function [fill,font]=cellColors(doc,styles,reference)
cells=doc.getElementsByTagName('c'); target=[];
for n=0:cells.getLength()-1
    if strcmp(char(cells.item(n).getAttribute('r')),reference), target=cells.item(n); break; end
end
assert(~isempty(target));
xfs=styles.getElementsByTagName('cellXfs').item(0).getElementsByTagName('xf');
xf=xfs.item(str2double(char(target.getAttribute('s'))));
fills=styles.getElementsByTagName('fills').item(0).getElementsByTagName('fill');
fillNode=fills.item(str2double(char(xf.getAttribute('fillId'))));
fill=char(fillNode.getElementsByTagName('fgColor').item(0).getAttribute('rgb'));
fonts=styles.getElementsByTagName('fonts').item(0).getElementsByTagName('font');
fontNode=fonts.item(str2double(char(xf.getAttribute('fontId'))));
font=char(fontNode.getElementsByTagName('color').item(0).getAttribute('rgb'));
end

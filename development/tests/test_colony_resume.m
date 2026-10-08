function tests=test_colony_resume
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
[file,lease]=marking_fixture(); tc.TestData.Lease=lease;
app=ColonyCounterApp(file,'off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.applySettings(); assert(isempty(app.LastError));
T=app.Result.Colonies; [~,k]=max(T.EnclosingRadiusPixels); id=T.ID(k);
app.beginMarking(id);
app.addMarkedCenter([T.X(k)-4,T.Y(k)],'AD9');
app.addMarkedCenter([T.X(k)+4,T.Y(k)],'AD24'); app.confirmMarking();
app.beginAdding(); app.addMarkedCenter([130 300],'Need review',6); app.confirmMarking();
app.setColonyLabel(app.Result.Colonies.ID(1),'Not a colony');
tc.TestData.Result=app.Result;
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
tc.TestData.Files=app.saveResults(folder);
end
function testExactRoundTripAndPortableSource(tc)
r=tc.TestData.Result; file=r.ImageFile; moved=file+".moved";
movefile(file,moved); restore=onCleanup(@()movefile(moved,file)); %#ok<NASGU>
[loaded,state,lease]=load_colony_app_results(tc.TestData.Files.Workbook); %#ok<ASGLU>
verifyEqual(tc,loaded.Colonies,r.Colonies);
verifyEqual(tc,loaded.Labels,r.Labels);
verifyEqual(tc,loaded.Image,r.Image);
verifyEqual(tc,loaded.ROI,r.ROI);
verifyEqual(tc,loaded.Options,r.Options);
verifyEqual(tc,loaded.ManualGroups,r.ManualGroups);
verifyEqual(tc,loaded.ReviewLog,r.ReviewLog);
verifyEqual(tc,loaded.NextID,r.NextID);
verifyEqual(tc,loaded.OriginalLabels,r.OriginalLabels);
verifyEqual(tc,loaded.OriginalColonies,r.OriginalColonies);
verifyEqual(tc,loaded.Summary,r.Summary);
verifyTrue(tc,isfile(loaded.ImageFile));
verifyEqual(tc,imread(loaded.ImageFile),imread(moved,'png'));
source=loaded.ImageFile; clear lease
verifyFalse(tc,isfile(source));
end
function testResumeAppEditUndoAndReclassify(tc)
app=ColonyCounterApp('','off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.loadResults(tc.TestData.Files.Workbook);
verifyFalse(tc,app.Dirty); verifyEqual(tc,app.Result.Colonies,tc.TestData.Result.Colonies);
verifyEqual(tc,string(app.Buttons.LoadResults.Text),"Open saved results");
verifyEqual(tc,str2double(app.CountLabels.AD9.Text),app.Result.Summary.AD9);
verifyEqual(tc,str2double(app.CountLabels.Review.Text),app.Result.Summary.FlaggedForReview);
child=app.Result.ManualGroups.ChildIDs(1); app.setColonyLabel(child,'AD24');
before=app.Result.Summary; app.applySettings(); verifyEmpty(tc,app.LastError);
verifyEqual(tc,app.Result.Summary,before);
verifyEqual(tc,numel(app.Result.ManualGroups),1);
app.restoreMarkedColonies(app.Result.ManualGroups.ChildIDs(1));
verifyEmpty(tc,app.Result.ManualGroups);
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
files=app.saveResults(folder);
[loaded,~,lease]=load_colony_app_results(files.Workbook); %#ok<ASGLU>
verifyEqual(tc,loaded.Colonies,app.Result.Colonies);
verifyEqual(tc,loaded.Summary,app.Result.Summary);
verifyEqual(tc,string(sheetnames(files.Workbook)),["Colonies";"Summary"]);
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(tc,numel(listing),2); verifyFalse(tc,any([listing.isdir]));
end
function testSettingsAndDefaultsResume(tc)
app=ColonyCounterApp(tc.TestData.Result.ImageFile,'off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); baseline=app.Options;
app.setParameter('CompositeReviewMargin',0.19); app.setParameter('SplitTouchingColonies',false);
app.applySettings(); verifyEmpty(tc,app.LastError);
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
files=app.saveResults(folder); saved=app.Options;
app.loadResults(files.Workbook); verifyEqual(tc,app.Options,saved);
feval(app.Buttons.Reset.ButtonPushedFcn,app.Buttons.Reset,[]);
verifyEqual(tc,app.Options.CompositeReviewMargin,baseline.CompositeReviewMargin);
verifyEqual(tc,app.Options.SplitTouchingColonies,baseline.SplitTouchingColonies);
end
function testFailureLeavesCurrentWorkIntact(tc)
app=ColonyCounterApp('','off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.loadResults(tc.TestData.Files.Workbook); before=app.Result;
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
bad=fullfile(folder,'bad.xlsx'); fid=fopen(bad,'w'); fprintf(fid,'not a workbook'); fclose(fid);
try, app.loadResults(bad); catch, end
verifyEqual(tc,app.Result,before); verifyTrue(tc,isfile(app.ImageFile));
verifyEqual(tc,string(app.Buttons.Save.Enable),"on");
app.beginAdding(); verifyError(tc,@()app.loadResults(tc.TestData.Files.Workbook),'CFU:MarkingActive'); app.cancelMarking();
end
function testLegacyWorkbookKeepsSavedCountsAndCircles(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
legacy=legacyBook(tc.TestData.Files.Workbook,folder);
[loaded,info,lease]=load_colony_app_results(legacy,tc.TestData.Result.ImageFile); %#ok<ASGLU>
[actual,summary]=colony_export_tables(loaded); [expected,counts]=colony_export_tables(tc.TestData.Result);
verifyEqual(tc,actual.ID,expected.ID); verifyEqual(tc,actual.Label,expected.Label);
verifyEqual(tc,[actual.X actual.Y],[expected.X expected.Y],'AbsTol',1e-9);
verifyEqual(tc,colony_circle_radii(loaded.Colonies,1),colony_circle_radii(tc.TestData.Result.Colonies,1),'AbsTol',1e-9);
verifyEqual(tc,summary,counts); verifyTrue(tc,contains(info.Message,'older workbook'));
verifyFalse(tc,isfield(loaded,'ManualGroups'));
verifyGreaterThan(tc,nnz(loaded.Labels),0);
end
function testLegacyWorkbookRequestsMissingPhoto(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
legacy=legacyBook(tc.TestData.Files.Workbook,folder);
verifyError(tc,@()load_colony_app_results(legacy),'CFU:OriginalImageRequired');
end
function testCodecPreservesTypesNaNsEmptyTablesAndArrays(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
value=struct('Numbers',[NaN Inf -Inf pi],'Empty',zeros(0,3,'single'), ...
    'Strings',["a";missing;""],'Characters','µ plate', ...
    'Table',table(strings(0,1),zeros(0,1),'VariableNames',{'Name','Value'}));
value.StructArray=struct('ID',{1,2},'List',{false(0,1),uint16([1 400])});
value.Cells={int8(-8),zeros(2,0),strings(1,0),struct(),struct([])};
colony_session_data('write',folder,value);
loaded=colony_session_data('read',folder); verifyEqual(tc,loaded,value);
end
function testEmptyPlateRoundTrip(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
r=tc.TestData.Result; r.Colonies=r.Colonies([],:); r.Labels(:)=0;
r=rmfield(r,'ManualGroups'); r.Summary=summarize_colonies(r);
files=save_colony_app_results(r,folder);
[loaded,~,lease]=load_colony_app_results(files.Workbook); %#ok<ASGLU>
verifyEqual(tc,loaded.Colonies,r.Colonies); verifyEqual(tc,loaded.Summary.Total,0);
end
function testWorkbookLabelEditsUseVisibleLabel(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
file=changeCell(tc.TestData.Files.Workbook,folder,'B2','AD24',true);
[loaded,~,lease]=load_colony_app_results(file); %#ok<ASGLU>
id=tc.TestData.Result.Colonies.ID(1);
verifyEqual(tc,loaded.Colonies.Class(loaded.Colonies.ID==id),"AD24");
verifyEqual(tc,loaded.Summary.AD24,tc.TestData.Result.Summary.AD24+1);
end
function testChangedGeometryRejectedWithoutReplacingWork(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
file=changeCell(tc.TestData.Files.Workbook,folder,'D2','123',false);
app=ColonyCounterApp('','off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.loadResults(tc.TestData.Files.Workbook); before=app.Result;
verifyError(tc,@()app.loadResults(file),'CFU:WorkbookChanged');
verifyEqual(tc,app.Result,before); verifyTrue(tc,isfile(app.ImageFile));
end
function testPhotoLifetimeAcrossImageReloadAndLegacyImport(tc)
app=ColonyCounterApp('','off'); guard=onCleanup(@()delete(app)); %#ok<NASGU>
app.loadResults(tc.TestData.Files.Workbook); source=app.ImageFile;
app.loadImage(source); verifyTrue(tc,isfile(source));
app.applySettings(); verifyEmpty(tc,app.LastError);
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
legacy=legacyBook(tc.TestData.Files.Workbook,folder);
app.loadResults(legacy,source);
verifyFalse(tc,isfile(source)); verifyTrue(tc,isfile(app.ImageFile));
current=app.ImageFile; app.loadImage(tc.TestData.Result.ImageFile);
verifyFalse(tc,isfile(current)); verifyTrue(tc,isfile(app.ImageFile));
end
function testMissingEmbeddedPhotoCanBeLocated(tc)
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
r=tc.TestData.Result; r.ImageFile=fullfile(folder,'missing photo.png');
files=save_colony_app_results(r,folder);
verifyError(tc,@()load_colony_app_results(files.Workbook),'CFU:OriginalImageRequired');
[loaded,~,lease]=load_colony_app_results(files.Workbook,tc.TestData.Result.ImageFile); %#ok<ASGLU>
verifyEqual(tc,loaded.Colonies,r.Colonies);
end
function file=changeCell(workbook,folder,reference,value,isText)
unpacked=fullfile(folder,'unpacked'); unzip(workbook,unpacked);
path=fullfile(unpacked,'xl','worksheets','sheet1.xml');
parser=matlab.io.xml.dom.Parser(); writer=matlab.io.xml.dom.DOMWriter(); doc=parser.parseFile(path);
nodes=doc.getElementsByTagName('c'); target=[];
for n=0:nodes.getLength()-1
    if strcmp(char(nodes.item(n).getAttribute('r')),reference), target=nodes.item(n); break; end
end
assert(~isempty(target));
while ~isempty(target.getFirstChild()), target.removeChild(target.getFirstChild()); end
ns=doc.getDocumentElement().getNamespaceURI();
if isText
    target.setAttribute('t','inlineStr'); part=doc.createElementNS(ns,'is');
    text=doc.createElementNS(ns,'t'); text.appendChild(doc.createTextNode(value)); part.appendChild(text);
else
    target.removeAttribute('t'); part=doc.createElementNS(ns,'v'); part.appendChild(doc.createTextNode(value));
end
target.appendChild(part); writer.writeToFile(doc,path);
entries=dir(unpacked); entries=entries(~ismember({entries.name},{'.','..'}));
archive=fullfile(folder,'changed.zip'); zip(archive,{entries.name},unpacked);
file=fullfile(folder,'changed_colonies.xlsx'); movefile(archive,file);
end

function file=legacyBook(workbook,folder)
unpacked=fullfile(folder,'unpacked'); unzip(workbook,unpacked);
rmdir(fullfile(unpacked,'cfuSession'),'s');
entries=dir(unpacked); entries=entries(~ismember({entries.name},{'.','..'}));
archive=fullfile(folder,'legacy.zip'); zip(archive,{entries.name},unpacked);
file=fullfile(folder,'legacy_colonies.xlsx'); movefile(archive,file);
end

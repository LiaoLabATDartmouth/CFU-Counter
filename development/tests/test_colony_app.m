function tests=test_colony_app
% App state and export checks; see development/validation/VALIDATION.md for UI gestures.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testManualApplyAndSimpleExport(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEmpty(testCase,app.Result);
app.setPlateBoundary([300 300 255 255 0]); app.classify();
verifyEmpty(testCase,app.LastError); verifyGreaterThan(testCase,app.Result.Summary.Total,10);
old=app.Result;
app.setParameter('PinkContrastThreshold',0.075);
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Result.Options,old.Options);
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
verifyError(testCase,@()app.saveResults(fullfile(folder,'pending')),'CFU:PendingSettings');
app.applySettings(); verifyEmpty(testCase,app.LastError);
verifyFalse(testCase,app.Dirty); verifyEqual(testCase,app.Result.Options.PinkContrastThreshold,0.075);
verifyEqual(testCase,str2double(app.CountLabels.AD9.Text),app.Result.Summary.AD9);
verifyEqual(testCase,str2double(app.CountLabels.Review.Text),app.Result.Summary.FlaggedForReview);
app.ReviewOnly.Value=true; app.ShowCircles.Value=false; app.ShowIDs.Value=false;
files=app.saveResults(folder);
T=readtable(files.Workbook,'Sheet','Colonies');
verifyEqual(testCase,height(T),height(app.Result.Colonies));
verifyTrue(testCase,app.ReviewOnly.Value); verifyFalse(testCase,app.ShowCircles.Value);
verifyFalse(testCase,ismember('ReviewReason',T.Properties.VariableNames));
verifyTrue(testCase,ismember('NeedsReview',T.Properties.VariableNames));
verifyTrue(testCase,isfile(files.Annotated));
verifyEqual(testCase,sort(string(sheetnames(files.Workbook))),sort(["Colonies";"Summary"]));
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyFalse(testCase,any([listing.isdir])); verifyEqual(testCase,numel(listing),3);
end

function testDefaultsAndImageSwitch(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
starting=app.Options;
verifyTrue(testCase,app.EstimationInfo.Estimated);
verifyEqual(testCase,string(app.Controls.PinkContrastThreshold.Edit.Enable),"on");
verifyEqual(testCase,sort(string({app.Tabs.Children.Title})),sort(["Detection","Classification","Advanced"]));
verifyTrue(testCase,isequal(app.ColonyTable.Parent.Parent,app.ReviewPanel));
verifyFalse(testCase,isequal(app.ReviewPanel,app.SettingsPanel));
verifyEqual(testCase,app.ColonyTable.ColumnFormat{2},{'Need review','AD9','AD24','Not a colony'});
verifyEqual(testCase,app.CountLabels.Review.Parent.Parent.Layout.Column,1);
verifyEqual(testCase,app.CountLabels.AD9.Parent.Parent.Layout.Column,2);
verifyEqual(testCase,app.CountLabels.AD24.Parent.Parent.Layout.Column,3);
verifyFalse(testCase,any(isfield(app.Buttons,{'Auto','Manual','Classify'})));
verifyEqual(testCase,string(app.Buttons.Apply.Text),"Apply and classify");
app.setPlateBoundary([300 300 255 255 0]); app.setParameter('PinkContrastThreshold',0.075);
app.applySettings(); verifyEmpty(testCase,app.LastError);
second=fullfile(folder,'second.png'); copyfile(file,second); app.loadImage(second);
verifyEmpty(testCase,app.Options.PlateEllipse); verifyEmpty(testCase,app.Result);
verifyEqual(testCase,app.Options,starting);
verifyEqual(testCase,app.CountLabels.AD9.Text,'—');
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
verifyEqual(testCase,string(app.Buttons.Apply.Enable),"on");
end

function testWholePlateViewChangesOnlyZoom(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp('','off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEqual(testCase,string(app.Buttons.WholePlate.Enable),"off");
app.showWholePlate(); verifyEmpty(testCase,app.Result);
app.loadImage(file);
verifyEqual(testCase,string(app.Buttons.WholePlate.Enable),"on");
% The initial whole-plate view includes the automatically proposed outline.
initialX=xlim(app.ImageAxes); initialY=ylim(app.ImageAxes);
xlim(app.ImageAxes,[200 240]); ylim(app.ImageAxes,[250 290]);
feval(app.Buttons.WholePlate.ButtonPushedFcn,app.Buttons.WholePlate,[]);
verifyEqual(testCase,xlim(app.ImageAxes),initialX);
verifyEqual(testCase,ylim(app.ImageAxes),initialY);
app.setPlateBoundary([300 300 255 255 0]); app.classify();
verifyEmpty(testCase,app.LastError);
wholeX=xlim(app.ImageAxes); wholeY=ylim(app.ImageAxes);
id=app.ColonyTable.Data{1,1};
feval(app.ColonyTable.CellSelectionCallback,app.ColonyTable,struct('Indices',[1 2]));
verifyLessThan(testCase,diff(xlim(app.ImageAxes)),diff(wholeX));
app.setColonyLabel(id,'Need review');
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
before=app.Result; options=app.Options; rows=app.ColonyTable.Data;
children=app.ImageAxes.Children;
feval(app.Buttons.WholePlate.ButtonPushedFcn,app.Buttons.WholePlate,[]);
verifyEqual(testCase,xlim(app.ImageAxes),wholeX);
verifyEqual(testCase,ylim(app.ImageAxes),wholeY);
verifyEqual(testCase,app.Result,before); verifyEqual(testCase,app.Options,options);
verifyEqual(testCase,app.ColonyTable.Data,rows); verifyTrue(testCase,app.ReviewOnly.Value);
verifyFalse(testCase,app.Dirty); verifyEqual(testCase,app.ImageAxes.Children,children);
% A view reset must never accept or recreate the editable boundary.
app.setParameter('PinkContrastThreshold',0.075); app.choosePlateBoundary();
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
roi.Center=[320 310]; roi.SemiAxes=[220 200];
xlim(app.ImageAxes,[300 340]); ylim(app.ImageAxes,[290 330]);
before=app.Result; options=app.Options;
app.showWholePlate();
verifyTrue(testCase,isvalid(roi)); verifyEqual(testCase,roi.Center,[320 310]);
verifyEqual(testCase,roi.SemiAxes,[220 200]);
verifyLessThan(testCase,min(xlim(app.ImageAxes)),100);
verifyGreaterThan(testCase,max(xlim(app.ImageAxes)),540);
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Options,options);
verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
end

function testImageSelectionRespectsFiltersAndPendingChanges(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify(); verifyEmpty(testCase,app.LastError);
T=app.Result.Colonies; id=T.ID(end);
point=([T.X(end) T.Y(end)]-0.5)*app.Result.Scale+0.5;
app.setColonyLabel(id,'AD24'); before=app.Result;
limits=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
picture=findobj(app.ImageAxes,'Type','image');
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
verifyEqual(testCase,app.ColonyTable.StyleConfigurations.TargetIndex{1},row);
verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,[xlim(app.ImageAxes) ylim(app.ImageAxes)],limits);
verifyNotEmpty(testCase,findobj(app.ImageAxes,'Tag','SelectedColony','String',sprintf('ID %d',id)));
app.setColonyLabel(id,'Need review');
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
picture=findobj(app.ImageAxes,'Type','image');
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
verifyEqual(testCase,app.ColonyTable.StyleConfigurations.TargetIndex{1},row);
app.ShowCircles.Value=false;
picture=findobj(app.ImageAxes,'Type','image');
before=app.Result;
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[20 20 0]));
verifyEqual(testCase,app.Result,before);
app.ShowCircles.Value=true;
app.setParameter('PinkContrastThreshold',0.075); app.choosePlateBoundary();
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
roi.Center=[310 320]; options=app.Options;
picture=findobj(app.ImageAxes,'Type','image');
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
verifyTrue(testCase,isvalid(roi)); verifyEqual(testCase,roi.Center,[310 320]);
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Options,options);
verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
end

function testFailedRunDoesNotReplacePreviousCount(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify(); old=app.Result;
delete(file); app.classify();
verifyNotEmpty(testCase,app.LastError); verifyTrue(testCase,app.Dirty);
verifyEqual(testCase,app.Result.Summary,old.Summary);
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
end

function testSingleApplyUsesDisplayedSettings(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]);
app.setParameter('PinkContrastThreshold',0.075);
app.setParameter('CompositeReviewMargin',0.3);
app.setParameter('MinSolidity',0.75);
expected=app.Options;
profilerCleanup=onCleanup(@()profile('off')); %#ok<NASGU>
for pass=1:2 % The same button also explicitly reruns unchanged settings.
    profile clear; profile on;
    feval(app.Buttons.Apply.ButtonPushedFcn,app.Buttons.Apply,[]);
    profile off; report=profile('info');
    names=string({report.FunctionTable.FunctionName});
    verifyTrue(testCase,any(contains(names,'count_colonies')));
    verifyFalse(testCase,any(contains(names,'estimate_colony_settings')));
    verifyEmpty(testCase,app.LastError); verifyFalse(testCase,app.Dirty);
    verifyEqual(testCase,app.Options,expected); verifyEqual(testCase,app.Result.Options,expected);
    verifyEqual(testCase,string(app.Controls.PinkContrastThreshold.Edit.Enable),"on");
    verifyTrue(testCase,contains(app.SettingsHint.Text,'Current counts'));
end
before=app.Result;
app.setParameter('PinkContrastThreshold',app.Options.PinkContrastThreshold);
verifyFalse(testCase,app.Dirty); verifyEqual(testCase,app.Result,before);
end

function testResetChangesControlsWithoutRunning(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
ellipse=[300 300 255 250 3]; app.setPlateBoundary(ellipse);
expected=app.Options;
app.setParameter('PinkContrastThreshold',0.075);
app.setParameter('CompositeReviewMargin',0.3);
app.setParameter('MinSolidity',0.75);
app.setParameter('SplitTouchingColonies',false);
app.applySettings(); verifyEmpty(testCase,app.LastError);
app.setColonyLabel(app.Result.Colonies.ID(1),'Not a colony'); before=app.Result;
profile clear; profile on; profilerCleanup=onCleanup(@()profile('off')); %#ok<NASGU>
feval(app.Buttons.Reset.ButtonPushedFcn,app.Buttons.Reset,[]);
profile off; report=profile('info');
names=string({report.FunctionTable.FunctionName});
verifyFalse(testCase,any(contains(names,'count_colonies')));
verifyFalse(testCase,any(contains(names,'estimate_colony_settings')));
verifyEqual(testCase,app.Options,expected); verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,app.Controls.PinkContrastThreshold.Edit.Value,expected.PinkContrastThreshold);
verifyEqual(testCase,app.Controls.CompositeReviewMargin.Edit.Value,expected.CompositeReviewMargin);
verifyEqual(testCase,app.Controls.MinSolidity.Edit.Value,expected.MinSolidity);
verifyTrue(testCase,app.Controls.SplitTouchingColonies.Value);
verifyTrue(testCase,app.Dirty); verifyTrue(testCase,contains(app.SettingsHint.Text,'Changes pending'));
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
verifyEqual(testCase,string(app.ColonyTable.Enable),"off");
app.applySettings(); verifyEmpty(testCase,app.LastError);
verifyFalse(testCase,app.Dirty); verifyEqual(testCase,app.Result.Options,expected);
before=app.Result;
feval(app.Buttons.Reset.ButtonPushedFcn,app.Buttons.Reset,[]);
verifyFalse(testCase,app.Dirty); verifyEqual(testCase,app.Result,before);
end

function testSettingsEditedDuringBoundaryRemainPending(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.applySettings();
app.choosePlateBoundary(); app.setParameter('PinkContrastThreshold',0.075);
app.choosePlateBoundary();
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Options.PinkContrastThreshold,0.075);
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
app.applySettings(); verifyEmpty(testCase,app.LastError);
app.choosePlateBoundary(); feval(app.Buttons.Reset.ButtonPushedFcn,app.Buttons.Reset,[]);
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
app.choosePlateBoundary(); verifyTrue(testCase,app.Dirty);
verifyEqual(testCase,app.Options.PlateEllipse,[300 300 255 255 0]);
estimated=estimate_colony_settings(file,[300 300 255 255 0]);
verifyEqual(testCase,app.Options.PinkContrastThreshold,estimated.PinkContrastThreshold);
end

function testApplyRereadsImageAndRecovers(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.applySettings();
verifyEmpty(testCase,app.LastError); before=app.Result;
backup=fullfile(folder,'original.png'); copyfile(file,backup);
imwrite(uint8(zeros(20,20)),file); app.applySettings();
verifyNotEmpty(testCase,app.LastError); verifyTrue(testCase,app.Dirty);
verifyEqual(testCase,app.Result,before);
copyfile(backup,file); app.applySettings();
verifyEmpty(testCase,app.LastError); verifyFalse(testCase,app.Dirty);
end

function testAutomaticEstimatorRespondsToDensity(testCase)
[sparse,~,c1]=fixturePlate(false); [dense,~,c2]=fixturePlate(true); %#ok<ASGLU>
[a,infoA]=estimate_colony_settings(sparse,[300 300 255 255 0]);
[b,infoB]=estimate_colony_settings(dense,[300 300 255 255 0]);
verifyTrue(testCase,infoA.Estimated); verifyTrue(testCase,infoB.Estimated);
verifyGreaterThan(testCase,infoB.OccupiedFraction,infoA.OccupiedFraction);
verifyGreaterThan(testCase,infoB.PilotColonies,infoA.PilotColonies);
schema=colony_app_parameters();
for k=1:numel(schema)
    s=schema(k);
    verifyGreaterThanOrEqual(testCase,a.(s.Name),s.Minimum); verifyLessThanOrEqual(testCase,a.(s.Name),s.Maximum);
    verifyGreaterThanOrEqual(testCase,b.(s.Name),s.Minimum); verifyLessThanOrEqual(testCase,b.(s.Name),s.Maximum);
end
end

function testLabelsUpdateCountsOverlayAndExport(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify();
verifyEmpty(testCase,app.LastError); T=app.Result.Colonies;
verifyEqual(testCase,height(T),app.Result.Summary.AD9+app.Result.Summary.AD24+app.Result.Summary.FlaggedForReview);
verifyEqual(testCase,app.ColonyTable.ColumnEditable,[false true]);
id=T.ID(1); before=app.Result.Labels;
app.setColonyLabel(id,'Need review');
reviewCount=app.Result.Summary.FlaggedForReview;
verifyEqual(testCase,app.ColonyTable.Data{1,2},'Need review');
verifyEqual(testCase,str2double(app.CountLabels.Review.Text),reviewCount);
app.selectColony(id); verifyNotEmpty(testCase,findobj(app.ImageAxes,'Tag','SelectedColony'));
app.setColonyLabel(id,'AD24');
verifyEqual(testCase,app.Result.Summary.FlaggedForReview,reviewCount-1);
ad24=app.Result.Summary.AD24; ad9=app.Result.Summary.AD9;
% Exercise the exact callback used by the editable label dropdown.
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
event=struct('Indices',[row 2],'NewData','AD9');
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,event);
verifyEqual(testCase,app.Result.Summary.AD24,ad24-1);
verifyEqual(testCase,app.Result.Summary.AD9,ad9+1);
verifyEqual(testCase,app.Result.Labels,before);
verifyEqual(testCase,str2double(app.CountLabels.AD9.Text),ad9+1);
verifyFalse(testCase,app.Dirty);
verifyError(testCase,@()app.setColonyLabel(id,'bad label'),'CFU:InvalidClass');
verifyError(testCase,@()app.setColonyLabel(99999,'AD9'),'CFU:MissingID');
files=app.saveResults(folder);
saved=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
verifyEqual(testCase,saved.Label(saved.ID==id),"AD9");
verifyTrue(testCase,logical(saved.Reviewed(saved.ID==id)));
verifyEqual(testCase,saved.AnnotationColor(saved.ID==id),"Cyan");
verifyNotEmpty(testCase,app.Result.ReviewLog);
app.classify(); % Unchanged segmentation retains this manual correction.
verifyEmpty(testCase,app.LastError);
verifyEqual(testCase,app.Result.Colonies.Class(1),"AD9");
verifyTrue(testCase,app.Result.Colonies.Reviewed(1));
app.setParameter('PinkContrastThreshold',0.075);
verifyError(testCase,@()app.setColonyLabel(id,'AD24'),'CFU:PendingSettings');
end

function testTableGroupsRowsAndKeepsIDsStable(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify();
verifyEmpty(testCase,app.LastError);
ids=app.Result.Colonies.ID; segmentation=app.Result.Labels;
% Put a high ID in review and a low ID in AD24 to distinguish label sorting
% from the old ID-only order. Include all four groups.
app.setColonyLabel(ids(1),'AD24');
app.setColonyLabel(ids(2),'Not a colony');
app.setColonyLabel(ids(end-1),'AD9');
app.setColonyLabel(ids(end),'Need review');
verifyTableGroups(testCase,app);
verifyEqual(testCase,app.Result.Colonies.ID,ids);
verifyEqual(testCase,app.Result.Labels,segmentation);
row=find(cell2mat(app.ColonyTable.Data(:,1))==ids(end));
verifyNotEqual(testCase,row,numel(ids));
% Selection and editing use the displayed ID, never the storage row number.
feval(app.ColonyTable.CellSelectionCallback,app.ColonyTable,struct('Indices',[row 1]));
verifyNotEmpty(testCase,findobj(app.ImageAxes,'Tag','SelectedColony','String',sprintf('ID %d',ids(end))));
before=app.Result.Colonies; counts=app.Result.Summary;
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,struct('Indices',[row 2],'NewData','AD24'));
verifyEqual(testCase,app.Result.Colonies.Class(end),"AD24");
verifyEqual(testCase,app.Result.Colonies.Class(1:end-1),before.Class(1:end-1));
verifyEqual(testCase,app.Result.Summary.AD24,counts.AD24+1);
verifyEqual(testCase,app.Result.Summary.FlaggedForReview,counts.FlaggedForReview-1);
verifyTableGroups(testCase,app);
verifyEqual(testCase,app.Result.Colonies.ID,ids);
% Moving the same object back into review immediately restores its group.
row=find(cell2mat(app.ColonyTable.Data(:,1))==ids(end));
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,struct('Indices',[row 2],'NewData','Need review'));
verifyTableGroups(testCase,app);
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
data=app.ColonyTable.Data;
verifyTrue(testCase,all(string(data(:,2))=="Need review"));
verifyTrue(testCase,issorted(cell2mat(data(:,1))));
verifyTrue(testCase,any(cell2mat(data(:,1))==ids(end)));
app.ReviewOnly.Value=false; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
verifyTableGroups(testCase,app);
app.classify(); verifyEmpty(testCase,app.LastError);
verifyTableGroups(testCase,app); verifyEqual(testCase,app.Result.Colonies.ID,ids);
end

function verifyTableGroups(testCase,app)
T=app.Result.Colonies;
expected=[sort(T.ID(T.NeedsReview)); ...
    sort(T.ID(T.Class=="AD9" & ~T.NeedsReview)); ...
    sort(T.ID(T.Class=="AD24" & ~T.NeedsReview)); ...
    sort(T.ID(T.Class=="Not a colony"))];
verifyEqual(testCase,cell2mat(app.ColonyTable.Data(:,1)),expected);
end

function testReviewFilterEditsTheCorrectID(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify();
id=app.Result.Colonies.ID(end); app.setColonyLabel(id,'Need review');
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
event=struct('Indices',[row 2],'NewData','AD24');
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,event);
verifyEqual(testCase,app.Result.Colonies.Class(app.Result.Colonies.ID==id),"AD24");
verifyFalse(testCase,any(cell2mat(app.ColonyTable.Data(:,1))==id));
end

function testNotAColonyIsExcludedReversibleAndSaved(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify();
verifyEmpty(testCase,app.LastError); id=app.Result.Colonies.ID(1);
verifyTrue(testCase,ismember('Not a colony',app.ColonyTable.ColumnFormat{2}));
app.setColonyLabel(id,'AD9'); before=app.Result.Summary; labels=app.Result.Labels;
app.setColonyLabel(id,'Not a colony'); after=app.Result.Summary;
verifyEqual(testCase,after.AD9,before.AD9-1);
verifyEqual(testCase,after.AD24,before.AD24);
verifyEqual(testCase,after.FlaggedForReview,before.FlaggedForReview);
verifyEqual(testCase,after.Total,before.Total-1);
verifyEqual(testCase,after.NotAColony,1);
verifyEqual(testCase,after.DetectedObjects,before.DetectedObjects);
verifyEqual(testCase,after.Total,after.AD9+after.AD24+after.FlaggedForReview);
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
verifyEqual(testCase,app.ColonyTable.Data{row,2},'Not a colony');
verifyEqual(testCase,app.Result.Labels,labels); % Needed to undo/preserve the edit.
verifyFalse(testCase,app.Result.Colonies.NeedsReview(1));
verifyEqual(testCase,str2double(app.CountLabels.AD9.Text),before.AD9-1);
app.classify(); verifyEmpty(testCase,app.LastError);
verifyEqual(testCase,app.Result.Colonies.Class(1),"Not a colony");
verifyEqual(testCase,app.Result.Summary.Total,after.Total);
files=app.saveResults(folder);
exported=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
verifyEqual(testCase,exported.Label(exported.ID==id),"Not a colony");
verifyFalse(testCase,logical(exported.IncludedInCount(exported.ID==id)));
verifyEqual(testCase,exported.AnnotationColor(exported.ID==id),"None");
summary=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
verifyEqual(testCase,summary.Count(summary.Label=="Total included"),after.Total);
verifyEqual(testCase,summary.Count(summary.Label=="Not a colony"),1);
verifyTrue(testCase,any(app.Result.Labels(:)==id)); % Exclusion stays reversible in this app session.
fig=plot_colonies(app.Result,true,'off'); closeFig=onCleanup(@()close(fig)); %#ok<NASGU>
verifyEmpty(testCase,findobj(fig,'Type','text','String',string(id)));
app.setColonyLabel(id,'AD24');
verifyEqual(testCase,app.Result.Summary.Total,before.Total);
verifyEqual(testCase,app.Result.Summary.AD24,before.AD24+1);
verifyEqual(testCase,app.Result.Summary.NotAColony,0);
app.setColonyLabel(id,'Need review'); review=app.Result.Summary.FlaggedForReview;
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,struct('Indices',[row 2],'NewData','Not a colony'));
verifyEqual(testCase,app.Result.Summary.FlaggedForReview,review-1);
verifyFalse(testCase,any(cell2mat(app.ColonyTable.Data(:,1))==id));
app.ReviewOnly.Value=false; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
verifyTrue(testCase,any(cell2mat(app.ColonyTable.Data(:,1))==id));
end

function testSelectEachPlateInOnePhoto(testCase)
[left,folder,c1]=fixturePlate(false); [right,~,c2]=fixturePlate(true); %#ok<ASGLU>
file=fullfile(folder,'two plates.png'); imwrite(cat(2,imread(left),imread(right)),file);
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
for center=[300 900]
    app.setPlateBoundary([center 300 255 255 0]); app.classify();
    verifyEmpty(testCase,app.LastError); T=app.Result.Colonies;
    verifyGreaterThan(testCase,height(T),10);
    verifyTrue(testCase,all(abs(T.X-center)<255));
    verifyFalse(testCase,any(app.Result.Labels(~app.Result.ROI)>0));
    if center==300, leftCount=height(T); else, verifyGreaterThan(testCase,height(T),leftCount); end
end
app.choosePlateBoundary();
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
verifyEqual(testCase,xlim(app.ImageAxes),[0.5 1200.5]);
verifyEqual(testCase,ylim(app.ImageAxes),[0.5 600.5]);
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
% ROI classes do not participate in findobj Type matching on every release.
if isempty(roi)
    children=app.ImageAxes.Children;
    roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
end
verifyNotEmpty(testCase,roi);
roi(1).Center=[300 300]; roi(1).SemiAxes=[255 255];
app.choosePlateBoundary(); verifyEqual(testCase,app.Options.PlateEllipse,[300 300 255 255 0]);
app.classify(); verifyEqual(testCase,height(app.Result.Colonies),leftCount);
end

function testOneBoundaryControlPreservesAnAutomaticBoundary(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
verifyFalse(testCase,isfield(app.Buttons,'SelectPlate'));
verifyFalse(testCase,isfield(app.Buttons,'AutoBoundary'));
verifyTrue(testCase,contains(app.BoundaryHint.Text,'found automatically'));
app.applySettings(); verifyEmpty(testCase,app.LastError);
verifyEmpty(testCase,app.Options.PlateEllipse);
verifyTrue(testCase,contains(app.BoundaryHint.Text,'found automatically'));
app.setColonyLabel(app.Result.Colonies.ID(1),'Not a colony'); before=app.Result;
app.choosePlateBoundary();
verifyEqual(testCase,xlim(app.ImageAxes),[0.5 600.5]);
verifyEqual(testCase,ylim(app.ImageAxes),[0.5 600.5]);
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
verifyEqual(testCase,[roi.Center roi.SemiAxes roi.RotationAngle],before.CountingEllipseWork,'AbsTol',1e-10);
app.choosePlateBoundary(); % Inspecting without moving is not a parameter change.
verifyFalse(testCase,app.Dirty); verifyEmpty(testCase,app.Options.PlateEllipse);
verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Choose plate boundary");
verifyEqual(testCase,string(app.Buttons.Save.Enable),"on");
% Inspecting the boundary a second time also preserves the edited result.
app.choosePlateBoundary(); app.choosePlateBoundary();
verifyFalse(testCase,app.Dirty); verifyNotEmpty(testCase,findobj(app.ImageAxes,'Tag','ColonyCircles'));
verifyEqual(testCase,app.Result,before);
end

function testFirstBoundaryAcceptanceAndPendingParameters(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.choosePlateBoundary(); app.choosePlateBoundary();
verifyEmpty(testCase,app.Options.PlateEllipse); verifyFalse(testCase,app.Dirty);
verifyTrue(testCase,contains(app.BoundaryHint.Text,'found automatically'));
app.setPlateBoundary([300 300 255 255 0]); app.classify(); verifyEmpty(testCase,app.LastError);
ellipse=app.Options.PlateEllipse;
app.setParameter('PinkContrastThreshold',0.075);
app.choosePlateBoundary(); app.choosePlateBoundary();
verifyTrue(testCase,app.Dirty); % Untouched boundary does not discard other edits.
verifyEqual(testCase,app.Options.PlateEllipse,ellipse);
verifyEqual(testCase,app.Options.PinkContrastThreshold,0.075);
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
end

function testPNGVariantsAndHEIC(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
I=imread(file);
alpha=uint8(255*ones(size(I,1),size(I,2))); alpha(1:20,:)=0;
transparent=fullfile(folder,'transparent.PNG'); imwrite(I,transparent,'Alpha',alpha);
read=read_plate_image(transparent); verifyEqual(testCase,read(1,1,:),ones(1,1,3,'single'));
verifyEqual(testCase,read(300,300,:),im2single(I(300,300,:)));
map=[0.1 0.2 0.3;0.5 0.7 0.9]; indexed=fullfile(folder,'indexed.png');
imwrite(uint8([0 1;1 0]),map,indexed); read=read_plate_image(indexed);
verifyEqual(testCase,size(read),[2 2 3]);
gray=fullfile(folder,'gray.png'); imwrite(I(:,:,1),gray);
verifyError(testCase,@()read_plate_image(gray),'CFU:NotRGB');
end

function testFitRimChangesBoundaryAndKeepsEditsPending(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([305 292 285 280 0]); app.classify();
verifyEmpty(testCase,app.LastError);
app.setColonyLabel(app.Result.Colonies.ID(1),'Not a colony'); before=app.Result;
options=app.Options;
% Exercise the button's callback after Done boundary, not just the helper.
feval(app.Buttons.View.ButtonPushedFcn,app.Buttons.View,[]);
verifyEmpty(testCase,app.LastError);
verifyEqual(testCase,string(app.Buttons.View.Text),"Fit to rim");
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
verifyEqual(testCase,roi.Center,[300 300],'AbsTol',2);
verifyEqual(testCase,roi.SemiAxes,[260 260],'AbsTol',2);
verifyEqual(testCase,app.Options,options); % Commit only on Done or Classify.
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Result,before);
verifyEqual(testCase,string(app.Buttons.Save.Enable),"off");
% A second fit during editing updates the same editable ROI.
app.fitImage(); verifyTrue(testCase,isvalid(roi));
app.choosePlateBoundary();
verifyEqual(testCase,app.Options.PlateEllipse(1:2),[300 300],'AbsTol',2);
verifyEqual(testCase,app.Options.PlateEllipse(3:4),[260 260],'AbsTol',2);
verifyTrue(testCase,app.Dirty); verifyEqual(testCase,app.Result,before);
app.applySettings(); verifyEmpty(testCase,app.LastError); verifyFalse(testCase,app.Dirty);
verifyEqual(testCase,app.Result.Options.PlateEllipse,app.Options.PlateEllipse);
end

function testFitRimWithoutSeedAndWithoutEvidence(testCase)
[file,folder,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.fitImage();
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Done boundary");
verifyTrue(testCase,contains(app.StatusLabel.Text,'Boundary fitted'));
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
verifyEqual(testCase,roi.Center,[300 300],'AbsTol',2);
verifyEqual(testCase,roi.SemiAxes,[260 260],'AbsTol',2);
flat=fullfile(folder,'flat.png'); imwrite(ones(600,600,3)*.5,flat);
app.loadImage(flat); seed=[300 300 260 260 0]; app.setPlateBoundary(seed);
options=app.Options; wasDirty=app.Dirty;
app.fitImage(); verifyEmpty(testCase,app.LastError);
verifyEqual(testCase,app.Options,options); verifyEqual(testCase,app.Dirty,wasDirty);
verifyEqual(testCase,string(app.Buttons.Boundary.Text),"Choose plate boundary");
verifyTrue(testCase,contains(app.StatusLabel.Text,'Could not fit a reliable rim'));
app.choosePlateBoundary();
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
app.fitImage(); verifyTrue(testCase,isvalid(roi));
verifyEqual(testCase,[roi.Center roi.SemiAxes roi.RotationAngle],seed);
end

function testReviewRingContrastInAppAndExport(testCase)
[file,~,cleanup]=fixturePlate(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]); app.classify();
app.setColonyLabel(app.Result.Colonies.ID(1),'Need review');
fig=plot_colonies(app.Result,true,'off'); closeFig=onCleanup(@()close(fig)); %#ok<NASGU>
for parent={app.ImageAxes,fig}
    ring=findobj(parent{1},'Tag','ColonyWarning');
    outline=findobj(parent{1},'Tag','ColonyWarningOutline');
    verifyEqual(testCase,ring.Color,[1 1 1]); verifyEqual(testCase,ring.LineStyle,'--');
    verifyEqual(testCase,outline.Color,[.05 .05 .05]);
    verifyGreaterThan(testCase,outline.LineWidth,ring.LineWidth);
    verifyEqual(testCase,nnz(isnan(ring.XData)),app.Result.Summary.FlaggedForReview);
end
end

function testRealHEICWhenAvailable(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 + AD24 MM 10(-6).HEIC');
assumeTrue(testCase,isfile(file),'Local HEIC research photo is not distributed in the app ZIP.');
[I,info]=read_plate_image(file); verifyEqual(testCase,size(I,3),3);
verifyGreaterThan(testCase,min(size(I,1),size(I,2)),1000);
verifyTrue(testCase,info.AutoOriented);
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEqual(testCase,app.ImageFile,string(file));
verifyEmpty(testCase,app.Result);
end

function [file,folder,cleanup]=fixturePlate(dense)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'plate.png'); [x,y]=meshgrid(1:600);
plate=(x-300).^2+(y-300).^2<260^2;
I=repmat(single(0.1),600,600,3); bg=[0.62 0.37 0.34];
for c=1:3, v=I(:,:,c); v(plate)=bg(c); I(:,:,c)=v; end
positions=180:50:430; if dense, positions=180:14:430; end
[cx,cy]=meshgrid(positions); centers=[cx(:),cy(:)];
for k=1:size(centers,1)
    radius=4; color=[0.90 0.49 0.53];
    if mod(k,5)==0, radius=8; color=[0.96 0.25 0.47]; end
    mask=(x-centers(k,1)).^2+(y-centers(k,2)).^2<=radius^2;
    for c=1:3, v=I(:,:,c); v(mask)=color(c); I(:,:,c)=v; end
end
imwrite(I,file);
end

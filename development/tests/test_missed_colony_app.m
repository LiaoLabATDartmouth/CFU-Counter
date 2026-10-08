function tests=test_missed_colony_app
tests=functiontests(localfunctions);
end
function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
end
function testStageRadiusRemoveAndCancel(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
before=app.Result; xlim(app.ImageAxes,[195 240]); ylim(app.ImageAxes,[195 240]);
view=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
verifyEqual(tc,string(app.Buttons.Add.Enable),"on");
app.beginAdding(); verifyEqual(tc,[xlim(app.ImageAxes) ylim(app.ImageAxes)],view);
verifyEqual(tc,string(app.MarkingLabel.Value),"Need review");
verifyEqual(tc,string(app.MarkingButtons.Confirm.Text),"Confirm additions");
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"off");
verifyEqual(tc,string(app.Buttons.Save.Enable),"off");
verifyError(tc,@()app.saveResults(tempdir),'CFU:MarkingActive');
verifyError(tc,@()app.beginMarking(app.Result.Colonies.ID(1)),'CFU:MarkingActive');
app.addMarkedCenter([205 205],'AD9',4);
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"on");
verifyEqual(tc,app.Result,before);
feval(app.MarkingTable.CellEditCallback,app.MarkingTable,struct('Indices',[1 3],'NewData',8));
verifyEqual(tc,app.MarkingTable.Data{1,3},8);
feval(app.MarkingTable.CellEditCallback,app.MarkingTable,struct('Indices',[1 3],'NewData',-1));
verifyEqual(tc,app.MarkingTable.Data{1,3},8);
feval(app.MarkingButtons.Remove.ButtonPushedFcn,app.MarkingButtons.Remove,[]);
verifyEqual(tc,size(app.MarkingTable.Data,1),0);
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"off");
app.addMarkedCenter([205 205],'AD9',4);
feval(app.MarkingFigure.CloseRequestFcn,app.MarkingFigure,[]);
verifyEqual(tc,app.Result,before); verifyEmpty(tc,app.MarkingFigure);
verifyEqual(tc,[xlim(app.ImageAxes) ylim(app.ImageAxes)],view);
verifyEqual(tc,string(app.Buttons.Save.Enable),"on");
end
function testImageClicksConfirmAndLaterEditing(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
before=app.Result; app.ShowCircles.Value=false; app.ReviewOnly.Value=true;
app.beginAdding(); picture=findobj(app.ImageAxes,'Type','image');
app.MarkingLabel.Value='AD24'; app.MarkingRadius.Value=7;
point=([205 205]-.5)*app.Result.Scale+.5;
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
verifyEqual(tc,size(app.MarkingTable.Data,1),1);
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
verifyEqual(tc,size(app.MarkingTable.Data,1),1);
app.confirmMarking(); T=app.Result.Colonies; id=T.ID(end);
verifyEqual(tc,app.Result.Summary.AD24,before.Summary.AD24+1);
verifyEqual(tc,str2double(app.CountLabels.AD24.Text),before.Summary.AD24+1);
verifyEqual(tc,T.MarkerRadiusPixels(end),7);
verifyFalse(tc,app.ReviewOnly.Value); verifyTrue(tc,app.ShowCircles.Value);
verifyEqual(tc,string(app.Buttons.Mark.Enable),"off");
verifyEqual(tc,string(app.Buttons.UndoMarks.Enable),"off");
verifyEqual(tc,string(app.Buttons.Add.Enable),"on");
app.setColonyLabel(id,'Need review');
verifyEqual(tc,app.Result.Summary.FlaggedForReview,before.Summary.FlaggedForReview+1);
app.setColonyLabel(id,'Not a colony'); verifyEqual(tc,app.Result.Summary.Total,before.Summary.Total);
app.setColonyLabel(id,'AD9'); verifyEqual(tc,app.Result.Summary.AD9,before.Summary.AD9+1);
end
function testReapplyAndPendingChanges(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
app.beginAdding(); app.addMarkedCenter([205 205],'AD9',4); app.confirmMarking();
before=app.Result.Summary; app.applySettings(); verifyEmpty(tc,app.LastError);
verifyEqual(tc,app.Result.Summary,before);
verifyTrue(tc,contains(app.StatusLabel.Text,'1 manual labels retained'));
verifyEqual(tc,sum(app.Result.Colonies.Source=="manual_add"),1);
app.setParameter('PinkContrastThreshold',.08);
verifyEqual(tc,string(app.Buttons.Add.Enable),"off");
verifyError(tc,@()app.beginAdding(),'CFU:PendingSettings');
end
function [app,cleanup,closeApp]=makeApp()
[file,cleanup]=marking_fixture();
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app));
app.setPlateBoundary([300 300 255 255 0]); app.applySettings(); assert(isempty(app.LastError));
end

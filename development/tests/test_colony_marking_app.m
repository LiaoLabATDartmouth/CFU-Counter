function tests=test_colony_marking_app
tests=functiontests(localfunctions);
end
function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
end

function testStageEditRemoveAndCancelKeepResults(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
[id,points]=target(app); before=app.Result; view=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
app.beginMarking(id);
verifyEqual(tc,string(app.MarkingLabel.Value),"Need review");
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"off");
verifyEqual(tc,string(app.Buttons.Save.Enable),"off");
verifyEqual(tc,string(app.Buttons.Apply.Enable),"off");
verifyEqual(tc,string(app.ColonyTable.Enable),"off");
verifyError(tc,@()app.saveResults(tempdir),'CFU:MarkingActive');
verifyError(tc,@()app.setColonyLabel(id,'AD9'),'CFU:MarkingActive');
options=app.Options; app.setParameter('PinkContrastThreshold',0.08); app.applySettings();
verifyEqual(tc,app.Options,options); verifyEqual(tc,app.Result,before);
app.addMarkedCenter(points(1,:)); app.addMarkedCenter(points(2,:),'AD24');
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"on");
verifyEqual(tc,app.Result,before);
verifyEqual(tc,string(app.MarkingTable.Data(:,2)),["Need review";"AD24"]);
event=struct('Indices',[1 2],'NewData','AD9');
feval(app.MarkingTable.CellEditCallback,app.MarkingTable,event);
verifyEqual(tc,string(app.MarkingTable.Data(:,2)),["AD9";"AD24"]);
feval(app.MarkingButtons.Remove.ButtonPushedFcn,app.MarkingButtons.Remove,[]);
verifyEqual(tc,size(app.MarkingTable.Data,1),1);
verifyEqual(tc,string(app.MarkingTable.Data{1,2}),"AD24");
verifyEqual(tc,string(app.MarkingButtons.Confirm.Enable),"off");
verifyError(tc,@()app.confirmMarking(),'CFU:TooFewMarks');
verifyEqual(tc,app.Result,before);
feval(app.MarkingFigure.CloseRequestFcn,app.MarkingFigure,[]);
verifyEmpty(tc,app.MarkingFigure); verifyEqual(tc,app.Result,before);
verifyEqual(tc,[xlim(app.ImageAxes) ylim(app.ImageAxes)],view);
verifyEmpty(tc,findobj(app.ImageAxes,'Tag','MarkDraft'));
verifyEqual(tc,string(app.Buttons.Save.Enable),"on");
end

function testImageClickConfirmEditAndUndo(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
[id,points]=target(app); app.setColonyLabel(id,'Need review'); before=app.Result;
for labels={["AD9";"AD9"],["AD9";"AD24"]}
    app.selectColony(id,false); verifyEqual(tc,string(app.Buttons.Mark.Enable),"on");
    feval(app.Buttons.Mark.ButtonPushedFcn,app.Buttons.Mark,[]);
    picture=findobj(app.ImageAxes,'Type','image');
    for k=1:2
        app.MarkingLabel.Value=char(labels{1}(k)); xy=(points(k,:)-.5)*app.Result.Scale+.5;
        feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[xy 0]));
    end
    % Duplicate clicks produce guidance without modifying the staged entries.
    feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[xy 0]));
    verifyEqual(tc,size(app.MarkingTable.Data,1),2); verifyEqual(tc,app.Result,before);
    feval(app.MarkingButtons.Confirm.ButtonPushedFcn,app.MarkingButtons.Confirm,[]);
    verifyEmpty(tc,app.MarkingFigure);
    verifyEqual(tc,app.Result.Summary.AD9,before.Summary.AD9+sum(labels{1}=="AD9"));
    verifyEqual(tc,app.Result.Summary.AD24,before.Summary.AD24+sum(labels{1}=="AD24"));
    verifyEqual(tc,app.Result.Summary.Total,before.Summary.Total+1);
    verifyEqual(tc,str2double(app.CountLabels.AD9.Text),app.Result.Summary.AD9);
    verifyEqual(tc,str2double(app.CountLabels.AD24.Text),app.Result.Summary.AD24);
    verifyFalse(tc,any(cell2mat(app.ColonyTable.Data(:,1))==id));
    child=app.Result.ManualGroups(end).ChildIDs(1);
    verifyEqual(tc,string(app.Buttons.UndoMarks.Enable),"on");
    verifyEqual(tc,string(app.Buttons.Mark.Enable),"off");
    app.setColonyLabel(child,'Not a colony');
    verifyEqual(tc,app.Result.Summary.Total,before.Summary.Total);
    feval(app.Buttons.UndoMarks.ButtonPushedFcn,app.Buttons.UndoMarks,[]);
    verifyEqual(tc,app.Result.Labels,before.Labels);
    verifyEqual(tc,app.Result.Summary,before.Summary);
    before=app.Result; % Audit log and the next unused ID intentionally persist.
end
end

function testConfirmedMarksSurviveApplyAndCanBeUndone(tc)
[app,cleanup,closeApp]=makeApp(); %#ok<ASGLU>
[id,points]=target(app); app.beginMarking(id);
app.addMarkedCenter(points(1,:),'AD9'); app.addMarkedCenter(points(2,:),'AD24'); app.confirmMarking();
before=app.Result.Summary; app.applySettings(); verifyEmpty(tc,app.LastError);
verifyEqual(tc,app.Result.Summary,before); verifyEqual(tc,numel(app.Result.ManualGroups),1);
verifyTrue(tc,contains(app.StatusLabel.Text,'2 manual labels retained'));
child=app.Result.ManualGroups(1).ChildIDs(2); app.selectColony(child);
verifyTrue(tc,all(isfinite([xlim(app.ImageAxes) ylim(app.ImageAxes)])));
app.restoreMarkedColonies(child); verifyEmpty(tc,app.Result.ManualGroups);
verifyTrue(tc,any(app.Result.Colonies.ID==id));
end

function [app,cleanup,closeApp]=makeApp()
[file,cleanup]=marking_fixture();
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app));
app.setPlateBoundary([300 300 255 255 0]); app.applySettings(); assert(isempty(app.LastError));
end
function [id,points]=target(app)
T=app.Result.Colonies; [~,row]=max(T.EnclosingRadiusPixels); id=T.ID(row);
points=[T.X(row)-4 T.Y(row);T.X(row)+4 T.Y(row)];
end

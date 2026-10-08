function smoke_marking_ui(outputFolder)
% Native mouse/dropdown interaction for staging and committing individual marks.
% Fixture labels test workflow; they are not biological ground-truth claims.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
app=ColonyCounterApp(file); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]);
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
T=app.Result.Colonies; [~,row]=max(T.EnclosingRadiusPixels); id=T.ID(row);
points=[T.X(row)-4 T.Y(row);T.X(row)+4 T.Y(row)];
app.setColonyLabel(id,'Need review'); before=app.Result;
tc.press(app.ImageAxes,([T.X(row) T.Y(row)]-.5)*app.Result.Scale+.5);
assert(strcmp(app.Buttons.Mark.Enable,'on'));
tc.press(app.Buttons.Mark); settle();
assert(strcmp(app.MarkingFigure.WindowStyle,'alwaysontop'));
assert(strcmp(app.MarkingButtons.Confirm.Enable,'off'));
tc.choose(app.MarkingLabel,'AD9');
tc.press(app.ImageAxes,(points(1,:)-.5)*app.Result.Scale+.5); settle();
tc.press(app.ImageAxes,(points(2,:)-.5)*app.Result.Scale+.5); settle();
assert(size(app.MarkingTable.Data,1)==2);
assert(all(string(app.MarkingTable.Data(:,2))=="AD9"));
assert(isequaln(app.Result,before));
tc.press(app.MarkingButtons.Confirm); settle();
assert(app.Result.Summary.AD9==before.Summary.AD9+2);
assert(app.Result.Summary.Total==before.Summary.Total+1);
tc.press(app.Buttons.UndoMarks); settle();
assert(isequal(app.Result.Labels,before.Labels));
assert(isequal(app.Result.Summary,before.Summary));

% Remove an incorrect mark, edit its replacement's label, then cancel.
tc.press(app.Buttons.Mark);
tc.press(app.ImageAxes,(points(1,:)-.5)*app.Result.Scale+.5);
tc.press(app.ImageAxes,(points(2,:)-.5)*app.Result.Scale+.5);
tc.choose(app.MarkingTable,[1 1]); tc.press(app.MarkingButtons.Remove);
assert(size(app.MarkingTable.Data,1)==1);
tc.choose(app.MarkingTable,[1 2],'AD24'); settle();
assert(string(app.MarkingTable.Data{1,2})=="AD24");
tc.press(app.MarkingButtons.Cancel); assert(isequal(app.Result.Summary,before.Summary));

% Mixed pair: commit and select/edit the new entries from their circles.
tc.press(app.Buttons.Mark);
tc.choose(app.MarkingLabel,'AD9');
tc.press(app.ImageAxes,(points(1,:)-.5)*app.Result.Scale+.5);
tc.choose(app.MarkingLabel,'AD24');
tc.press(app.ImageAxes,(points(2,:)-.5)*app.Result.Scale+.5); settle();
app.exportPreview(fullfile(outputFolder,'app_marking_centers.png'));
exportapp(app.MarkingFigure,fullfile(outputFolder,'app_marking_editor.png'));
tc.press(app.MarkingButtons.Confirm); settle();
assert(app.Result.Summary.AD9==before.Summary.AD9+1);
assert(app.Result.Summary.AD24==before.Summary.AD24+1);
ids=app.Result.ManualGroups(1).ChildIDs;
tc.press(app.ImageAxes,(points(2,:)-.5)*app.Result.Scale+.5); settle();
row=find(cell2mat(app.ColonyTable.Data(:,1))==ids(2));
assert(isequal(app.ColonyTable.StyleConfigurations.TargetIndex{1},row));
assert(strcmp(app.Buttons.UndoMarks.Enable,'on'));
app.exportPreview(fullfile(outputFolder,'app_marking_confirmed.png'));
choose_colony_label_ui(tc,app,ids(2),'Need review');
assert(app.Result.Summary.AD24==before.Summary.AD24);
assert(app.Result.Summary.FlaggedForReview==before.Summary.FlaggedForReview);
tc.press(app.Buttons.WholePlate); tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(numel(app.Result.ManualGroups)==1);
assert(app.Result.Summary.AD9==before.Summary.AD9+1);
assert(app.Result.Summary.FlaggedForReview==before.Summary.FlaggedForReview);
fprintf('Marking UI passed: actual image clicks, two AD9 / mixed counts, picker and table labels, removal, cancel, undo, child selection/editing and rerun persistence.\n');
end
function settle()
drawnow; pause(0.3); drawnow;
end

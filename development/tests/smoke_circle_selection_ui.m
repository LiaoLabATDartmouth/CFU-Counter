function smoke_circle_selection_ui(outputFolder)
%SMOKE_CIRCLE_SELECTION_UI Real circle/interior clicks reveal sorted table rows.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'app_main.png'));
wholeX=xlim(app.ImageAxes); wholeY=ylim(app.ImageAxes);
before=app.Result; T=app.Result.Colonies;
% AD24 is far down the grouped table, beyond the initially visible rows.
index=find(T.Class=="AD24",1,'last'); id=T.ID(index);
point=([T.X(index) T.Y(index)]-0.5)*app.Result.Scale+0.5;
tc.press(app.ImageAxes,point); settle();
assertSelected(app,id);
assert(isequal(xlim(app.ImageAxes),wholeX) && isequal(ylim(app.ImageAxes),wholeY));
assert(isequaln(app.Result,before));
app.exportPreview(fullfile(outputFolder,'app_circle_selected.png'));
% Edit that revealed row, then click it again after it moves into review.
choose_colony_label_ui(tc,app,id,'Need review');
tc.press(app.Buttons.WholePlate); tc.press(app.ImageAxes,point); settle();
assertSelected(app,id); assert(app.Result.Colonies.Class(index)=="Uncertain");
before=app.Result;
% A ring edge triggers selection too, including the white/black review ring.
other=find(T.NeedsReview & T.ID~=id,1);
otherPoint=([T.X(other) T.Y(other)]-0.5)*app.Result.Scale+0.5;
assert(colony_at_point(app.Result,otherPoint)==T.ID(other));
tc.press(app.ImageAxes,otherPoint); settle(); assertSelected(app,T.ID(other));
assert(isequal(xlim(app.ImageAxes),wholeX) && isequal(ylim(app.ImageAxes),wholeY));
ring=point+[max(3,T.EnclosingRadiusPixels(index)*app.Result.Scale)+3,0];
tc.press(app.ImageAxes,ring); settle(); assertSelected(app,id);
tc.press(app.ReviewOnly);
tc.press(app.ImageAxes,point); settle(); assertSelected(app,id);
app.exportPreview(fullfile(outputFolder,'app_circle_review.png'));
% Clicking empty background must not jump to a different colony.
tc.press(app.ImageAxes,[mean(wholeX) min(wholeY)+2]); settle();
assertSelected(app,id); assert(isequaln(app.Result,before));
% Existing table -> image zoom and whole-plate return still work.
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
tc.choose(app.ColonyTable,[row 1]);
assert(diff(xlim(app.ImageAxes))<diff(wholeX));
tc.press(app.Buttons.WholePlate);
assert(isequal(xlim(app.ImageAxes),wholeX));
fprintf('Circle selection UI passed: interior and ring clicks, off-screen sorted rows, edits/regrouping, review filtering, stable counts, and reverse table selection.\n');
end

function assertSelected(app,id)
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
styles=app.ColonyTable.StyleConfigurations;
assert(height(styles)==1 && isequal(styles.TargetIndex{1},row), ...
    'Expected colony ID %d at highlighted row %d. %s',id,row,app.StatusLabel.Text);
assert(~isempty(findobj(app.ImageAxes,'Tag','SelectedColony','String',sprintf('ID %d',id))));
end

function settle()
drawnow; pause(0.3); drawnow;
end

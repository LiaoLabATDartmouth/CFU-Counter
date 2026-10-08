function smoke_whole_plate_ui(outputFolder)
%SMOKE_WHOLE_PLATE_UI Select a table row, then return using the view button.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(app.Result.Summary.Total>250 && app.Result.Summary.Total<400);
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'app_main.png'));
wholeX=xlim(app.ImageAxes); wholeY=ylim(app.ImageAxes);
before=app.Result; options=app.Options;
tc.choose(app.ColonyTable,[1 1]);
assert(diff(xlim(app.ImageAxes))<diff(wholeX)/2);
app.exportPreview(fullfile(outputFolder,'app_colony_closeup.png'));
tc.press(app.Buttons.WholePlate);
assert(max(abs(xlim(app.ImageAxes)-wholeX))<1e-8);
assert(max(abs(ylim(app.ImageAxes)-wholeY))<1e-8);
assert(isequaln(app.Result,before) && isequaln(app.Options,options) && ~app.Dirty);
assert(strcmp(app.Buttons.Save.Enable,'on'));
app.exportPreview(fullfile(outputFolder,'app_whole_plate.png'));
app.UIFigure.Position(3:4)=[1120 760]; drawnow;
app.exportPreview(fullfile(outputFolder,'app_compact.png'));
tc.choose(app.ColonyTable,[3 1]); % A row in the sorted review group.
assert(diff(xlim(app.ImageAxes))<diff(wholeX)/2);
tc.press(app.Buttons.WholePlate);
assert(max(abs(xlim(app.ImageAxes)-wholeX))<1e-8);
assert(isequaln(app.Result,before));
fprintf('Whole plate UI passed: row selection zooms in, Show whole plate restores the overview, counts and labels are preserved, and the button fits at both window sizes.\n');
end

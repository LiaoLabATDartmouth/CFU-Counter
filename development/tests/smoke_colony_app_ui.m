function smoke_colony_app_ui(outputFolder)
%SMOKE_COLONY_APP_UI Exercise actual UI gestures on the bundled example.
% Run with the project and tests folders on the MATLAB path.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app));
tc=matlab.uitest.TestCase.forInteractiveUse;
assert(isequal(sort(string({app.Tabs.Children.Title})),sort(["Detection","Classification","Advanced"])));
assert(~any(isfield(app.Buttons,{'Auto','Manual','Classify'})));
tc.press(app.Buttons.Apply);
assert(isempty(app.LastError)); initialTotal=app.Result.Summary.Total; assert(initialTotal>250 && initialTotal<400);
originalLabels=app.Result.Labels; originalEllipse=app.Options.PlateEllipse; startingOptions=app.Options;
tc.press(app.Buttons.Boundary); assert(strcmp(app.Buttons.Boundary.Text,'Done boundary'));
tc.press(app.Buttons.Boundary); assert(~app.Dirty);
assert(isequaln(app.Options.PlateEllipse,originalEllipse));
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(isequal(app.Result.Labels,originalLabels));
tc.press(app.ReviewOnly); assert(app.ReviewOnly.Value);
tc.press(app.ReviewOnly); assert(~app.ReviewOnly.Value);
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'app_main.png'));
disp(app.Result.Summary(:,{'Total','AD9','AD24','FlaggedForReview'}));
id=app.ColonyTable.Data{1,1};
choose_colony_label_ui(tc,app,id,'Need review');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="Uncertain");
assert(str2double(app.CountLabels.Review.Text)==app.Result.Summary.FlaggedForReview);
choose_colony_label_ui(tc,app,id,'AD24');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="AD24");
choose_colony_label_ui(tc,app,id,'AD9');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="AD9");
app.exportPreview(fullfile(outputFolder,'app_review.png'));
tabs=app.Tabs.Children; app.Tabs.SelectedTab=tabs(strcmp({tabs.Title},'Detection'));
before=app.Result;
tc.type(app.Controls.PinkContrastThreshold.Edit,0.065);
assert(app.Dirty && strcmp(app.Buttons.Save.Enable,'off'));
assert(isequaln(app.Result,before));
app.exportPreview(fullfile(outputFolder,'app_pending.png'));
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(app.Result.Options.PinkContrastThreshold==0.065 && ~app.Dirty);
before=app.Result; ellipse=app.Options.PlateEllipse;
% Reset is independent of the active tab and does not run classification.
app.Tabs.SelectedTab=tabs(strcmp({tabs.Title},'Classification'));
tc.press(app.Buttons.Reset);
defaults=startingOptions;
assert(app.Options.PinkContrastThreshold==defaults.PinkContrastThreshold);
assert(isequal(app.Options.PlateEllipse,ellipse) && isequaln(app.Result,before));
assert(app.Dirty && strcmp(app.ColonyTable.Enable,'off'));
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(~app.Dirty && app.Result.Summary.Total==initialTotal);
% Review stays available while any settings tab is selected.
choose_colony_label_ui(tc,app,id,'Not a colony');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="Not a colony");
choose_colony_label_ui(tc,app,id,'Need review');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="Uncertain");
app.UIFigure.Position(3:4)=[1120 760]; drawnow;
app.exportPreview(fullfile(outputFolder,'app_compact.png'));
% A real HEIC photo contains multiple plates, including partial plates.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
heic=fullfile(root,'Examples','AD9 + AD24 MM 10(-6).HEIC');
if isfile(heic)
    app.UIFigure.Position(3:4)=[1320 880]; app.loadImage(heic);
    tc.press(app.Buttons.Boundary);
    assert(strcmp(app.Buttons.Boundary.Text,'Done boundary'));
    children=app.ImageAxes.Children;
    roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
    scale=1800/5712;
    roi.Center=([4260 2250]-0.5)*scale+0.5; roi.SemiAxes=[1300 1450]*scale;
    app.exportPreview(fullfile(outputFolder,'app_select_plate.png'));
    tc.press(app.Buttons.Boundary); assert(app.Dirty);
    tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
    assert(all(app.Result.Colonies.X>2800));
    assert(~any(app.Result.Labels(~app.Result.ROI)>0));
    app.exportPreview(fullfile(outputFolder,'app_heic.png'));
    disp(app.Result.Summary(:,{'Total','AD9','AD24','FlaggedForReview'}));
end
fprintf('UI smoke passed: separate Review, Apply and classify, pending edits, Reset to defaults, HEIC, boundary selection and resize.\n');
end

function smoke_fit_rim_ui(outputFolder)
%SMOKE_FIT_RIM_UI Actual button gestures, original-coordinate commit and render.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
app.setPlateBoundary([1485.3 2170.9 1450 1560 0]);
tc.press(app.Buttons.Boundary); tc.press(app.Buttons.Boundary);
before=app.Options.PlateEllipse;
tc.press(app.Buttons.View);
assert(isempty(app.LastError)); assert(strcmp(app.Buttons.Boundary.Text,'Done boundary'));
assert(contains(app.StatusLabel.Text,'Boundary fitted'));
assert(isequal(app.Options.PlateEllipse,before)); % Still open for adjustment.
app.exportPreview(fullfile(outputFolder,'app_fit_rim.png'));
tc.press(app.Buttons.Boundary);
fitted=app.Options.PlateEllipse;
assert(max(abs(fitted(1:2)-[1485 2170]))<15);
assert(min(fitted(3:4))>1340 && max(fitted(3:4))<1410);
assert(app.Dirty && isempty(app.Result));
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(isequal(app.Result.Options.PlateEllipse,fitted));
assert(~app.Dirty); assert(~any(app.Result.Labels(~app.Result.ROI)>0));
review=findobj(app.ImageAxes,'Tag','ColonyWarning');
assert(isequal(review.Color,[1 1 1]) && strcmp(review.LineStyle,'--'));
app.exportPreview(fullfile(outputFolder,'app_fitted_count.png'));
fig=plot_colonies(app.Result,false,'off'); closeFig=onCleanup(@()close(fig)); %#ok<NASGU>
exportgraphics(fig,fullfile(outputFolder,'fitted_plate_overlay.png'),'Resolution',140);
disp(app.Result.Summary(:,{'Total','AD9','AD24','FlaggedForReview'}));
fprintf('Fit to rim UI smoke passed: saved boundary -> fit -> editable outline -> Done -> Apply and classify.\n');
end

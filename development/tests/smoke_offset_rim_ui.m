function smoke_offset_rim_ui(outputFolder)
% Reproduce the supplied screenshot and fit the same partly cropped plate.
if nargin<1, outputFolder=tempname; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 0.125% 10(-6).HEIC');
if ~isfile(file), fprintf('Offset rim UI skipped: local research HEIC not present.\n'); return; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp(file); cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
I=read_plate_image(file); h=size(I,1); w=size(I,2);
seed=[.552*w .477*h .225*w .337*h 0];
app.setPlateBoundary(seed); tc.press(app.Buttons.Boundary);
app.exportPreview(fullfile(outputFolder,'app_offset_rim_before.png'));
tc.press(app.Buttons.View); assert(isempty(app.LastError));
assert(strcmp(app.Buttons.View.Text,'Fit to rim'));
assert(strcmp(app.Buttons.View.Enable,'on'));
assert(strcmp(app.Buttons.Boundary.Text,'Done boundary'));
assert(contains(app.StatusLabel.Text,'Boundary fitted'));
assert(contains(app.StatusLabel.Text,'cropped section'));
assert(isequal(app.Options.PlateEllipse,seed)); % Preview is still editable.
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse'); assert(isscalar(roi));
fitted=[roi.Center roi.SemiAxes roi.RotationAngle];
scale=min(1,1800/max(h,w)); small=fitted;
small(1:2)=(small(1:2)-.5)/scale*(1000/w)+.5; small(3:4)=small(3:4)/scale*(1000/w);
assert(max(abs(small(1:2)-[692 390]))<5);
assert(max(abs(sort(small(3:4))-[333 349]))<5);
app.exportPreview(fullfile(outputFolder,'app_offset_rim_after.png'));
tc.press(app.Buttons.View);
assert(isvalid(roi)); again=[roi.Center roi.SemiAxes roi.RotationAngle];
assert(max(abs(again(1:4)-fitted(1:4)))<4);
tc.press(app.Buttons.Boundary);
assert(app.Dirty && isempty(app.Result)); committed=app.Options.PlateEllipse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(isequal(app.Result.Options.PlateEllipse,committed));
assert(~any(app.Result.Labels(~app.Result.ROI)>0));
assert(~app.Dirty); app.showWholePlate();
app.exportPreview(fullfile(outputFolder,'app_offset_rim_counted.png'));
fprintf('Offset rim UI passed: screenshot seed, fit, cropped-arc feedback, stable repeated fit, editable preview, commit and counting inside the fitted boundary.\n');
end

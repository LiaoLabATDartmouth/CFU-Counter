function smoke_initial_boundary_ui(outputFolder)
% Actual first-click gestures before classification on JPEG and cropped HEIC.
if nargin<1,outputFolder=tempname;end
if ~isfolder(outputFolder),mkdir(outputFolder);end
app=ColonyCounterApp;cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
assertLocked(app);assert(isempty(app.Result));
app.exportPreview(fullfile(outputFolder,'app_initial_boundary.png'));
tc.press(app.Buttons.View);
assert(isempty(app.LastError) && contains(app.StatusLabel.Text,'Boundary fitted'));
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');assert(isscalar(roi));
scale=1800/max(size(read_plate_image(app.ImageFile),1),size(read_plate_image(app.ImageFile),2));
e=[(roi.Center-.5)/scale+.5 roi.SemiAxes/scale];
assert(max(abs(e(1:2)-[1485 2170]))<20);
assert(min(e(3:4))>1340 && max(e(3:4))<1410);
app.exportPreview(fullfile(outputFolder,'app_initial_fitted_boundary.png'));
tc.press(app.Buttons.Boundary);assertLocked(app);
assert(app.Dirty && isempty(app.Result));
tc.press(app.Buttons.Apply);assert(isempty(app.LastError));assertLocked(app);
assert(~app.Dirty && app.Result.Summary.Total>250);
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 0.125% 10(-6).HEIC');
if isfile(file)
 app.loadImage(file);assertLocked(app);assert(isempty(app.Result));
 app.exportPreview(fullfile(outputFolder,'app_initial_heic_boundary.png'));
 tc.press(app.Buttons.View);
 assert(isempty(app.LastError) && contains(app.StatusLabel.Text,'Boundary fitted'));
 roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');assert(isscalar(roi));
 pic=findobj(app.ImageAxes,'Type','image');scale=1000/max(size(pic.CData,1),size(pic.CData,2));
 center=(roi.Center-.5)*scale+.5;axes=sort(roi.SemiAxes)*scale;
 assert(max(abs(center-[692 390]))<15);assert(max(abs(axes-[333 349]))<15);
 app.exportPreview(fullfile(outputFolder,'app_initial_heic_fitted.png'));
 tc.press(app.Buttons.Boundary);assertLocked(app);
end
fprintf('Native initial-boundary checks passed: locked JPEG/HEIC outlines, one-click fits, Done relocks, Apply works.\n');
end
function assertLocked(app)
ring=findobj(app.ImageAxes,'Tag','PlateBoundary');assert(isscalar(ring));
assert(strcmp(ring.HitTest,'off') && strcmp(ring.PickableParts,'none'));
assert(isempty(findobj(app.ImageAxes,'Type','images.roi.Ellipse')));
assert(strcmp(app.Buttons.Boundary.Text,'Choose plate boundary'));
end

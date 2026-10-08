function smoke_single_group_ui(outputFolder)
% Verify the reported all-review case through the actual Apply button.
if nargin<1, outputFolder=tempname; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 MM 10(-4).HEIC');
if ~isfile(file), fprintf('Single-group UI skipped: local HEIC photo absent.\n'); return; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
I=read_plate_image(file); scale=1000/max(size(I,1),size(I,2));
[e,info]=fit_plate_boundary(imresize(I,scale),[594 376 325 340 0]); assert(info.Fitted);
e(1:2)=(e(1:2)-.5)/scale+.5; e(3:4)=e(3:4)/scale;
app=ColonyCounterApp(file); cleanup=onCleanup(@()delete(app));
tc=matlab.uitest.TestCase.forInteractiveUse; app.setPlateBoundary(e);
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
s=app.Result.Summary;
assert(s.Total>=35 && s.Total<=55 && s.AD9>=25 && s.AD24<=2);
assert(s.Uncertain<.35*s.Total);
assert(str2double(app.CountLabels.AD9.Text)==s.AD9);
assert(str2double(app.CountLabels.AD24.Text)==s.AD24);
assert(str2double(app.CountLabels.Review.Text)==s.Uncertain);
assert(contains(app.StatusLabel.Text,'Size reference used'));
tabs=app.Tabs.Children; app.Tabs.SelectedTab=tabs(strcmp({tabs.Title},'Classification'));
app.exportPreview(fullfile(outputFolder,'app_single_group_classification.png'));
labels=app.Result.Labels;
app.setParameter('SizeReviewFraction',.25); tc.press(app.Buttons.Apply);
assert(isempty(app.LastError)); assert(app.Result.Summary.AD9<s.AD9);
assert(isequal(app.Result.Labels,labels));
fprintf('Single-group UI passed: %d AD9, %d AD24, %d reviews; adjustable size-review margin; unchanged detection.\n',s.AD9,s.AD24,s.Uncertain);
clear cleanup
end

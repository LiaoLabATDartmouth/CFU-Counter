function files=smoke_export_ui(outputFolder)
%SMOKE_EXPORT_UI Export all labels despite UI filtering/hiding annotations.
if nargin<1, outputFolder=tempname; mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
tc.press(app.ReviewOnly); tc.press(app.ShowCircles);
assert(app.ReviewOnly.Value && ~app.ShowCircles.Value && ~app.ShowIDs.Value);
assert(size(app.ColonyTable.Data,1)==app.Result.Summary.FlaggedForReview);
% A failed save leaves controls usable and reports the error in the status.
missing=tempname;
try
    app.saveResults(missing); error('CFU:TestFailure','Missing folder should fail.');
catch err
    assert(strcmp(err.identifier,'CFU:OutputFolderMissing'));
end
assert(~isfolder(missing)); assert(strcmp(app.Buttons.Save.Enable,'on'));
assert(contains(app.StatusLabel.Text,'Could not save results'));
files=app.saveResults(outputFolder);
T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
S=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
assert(height(T)==height(app.Result.Colonies));
assert(S.Count(S.Label=="AD9")==app.Result.Summary.AD9);
assert(S.Count(S.Label=="AD24")==app.Result.Summary.AD24);
assert(S.Count(S.Label=="Need review")==app.Result.Summary.FlaggedForReview);
assert(app.ReviewOnly.Value && ~app.ShowCircles.Value);
assert(isfile(files.Annotated));
disp(files);
fprintf('Export UI smoke passed: complete label snapshot despite display filters, no missing-folder creation, controls restored after error.\n');
end

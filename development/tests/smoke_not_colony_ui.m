function smoke_not_colony_ui(outputFolder)
%SMOKE_NOT_COLONY_UI Exercise exclusion and restoration through the dropdown.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
baseline=app.Result.Summary; id=app.ColonyTable.Data{1,1};
initial=app.ColonyTable.Data{1,2};
choose_colony_label_ui(tc,app,id,'Not a colony');
assert(app.Result.Summary.Total==baseline.Total-1);
assert(app.Result.Summary.NotAColony==1);
assert(~app.Result.Colonies.NeedsReview(app.Result.Colonies.ID==id));
assert(app.ColonyTable.Data{end,1}==id);
app.exportPreview(fullfile(outputFolder,'app_not_colony.png'));
choose_colony_label_ui(tc,app,id,initial);
assert(app.Result.Summary.Total==baseline.Total);
assert(app.Result.Summary.NotAColony==0);
assert(app.Result.Summary.FlaggedForReview==baseline.FlaggedForReview);
fprintf('Not a colony UI dropdown: exclusion and restoration passed.\n');
end

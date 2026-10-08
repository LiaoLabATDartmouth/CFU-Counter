function choose_colony_label_ui(tc,app,id,label)
%CHOOSE_COLONY_LABEL_UI Locate by ID each time: editing can move the row.
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
assert(isscalar(row),'The colony ID must appear exactly once in the visible table.');
before=app.Result.Colonies;
% A no-op dropdown choice need not fire an edit/selection callback. Select
% the ID explicitly first, as a user does when inspecting a review entry.
tc.choose(app.ColonyTable,[row 1]);
tc.choose(app.ColonyTable,[row 2],char(label));
drawnow;
expected=string(label); if expected=="Need review", expected="Uncertain"; end
after=app.Result.Colonies;
assert(after.Class(after.ID==id)==expected);
assert(isequal(after.ID,before.ID),'Editing a label must not renumber colony IDs.');
assert(isequal(after.Class(after.ID~=id),before.Class(before.ID~=id)), ...
    'Editing a sorted table row must change only the selected colony.');
assert(~isempty(findobj(app.ImageAxes,'Tag','SelectedColony','String',sprintf('ID %d',id))), ...
    'The image highlight must still identify the edited colony after its row moves.');
end

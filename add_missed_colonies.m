function [result,ids]=add_missed_colonies(result,centers,labels,radii)
%ADD_MISSED_COLONIES Add labeled centers without inventing measured features.
% Radii are visual marker sizes, in original-image pixels. Existing masks and
% entries are unchanged. Use Not a colony to reversibly exclude a later error.
validate_missed_colony_centers(result,centers);
n=size(centers,1);
if n<1, error('CFU:TooFewMarks','Click at least one missed colony center before confirming.'); end
labels=string(labels(:)); labels(labels=="Need review")="Uncertain";
if numel(labels)~=n || any(~ismember(labels,["AD9","AD24","Uncertain","Not a colony"]))
    error('CFU:InvalidClass','Assign one valid label to each missed colony.');
end
validateattributes(radii,{'numeric'},{'vector','numel',n,'finite','positive','real'});
if any(radii>max(size(result.Labels))/result.Scale)
    error('CFU:InvalidRadius','Circle radius cannot exceed the image size.');
end
if ~ismember('MarkerRadiusPixels',result.Colonies.Properties.VariableNames)
    result.Colonies.MarkerRadiusPixels=nan(height(result.Colonies),1);
    % All archived parent rows must share the active table's schema for Undo.
    if isfield(result,'ManualGroups')
        for k=1:numel(result.ManualGroups)
            result.ManualGroups(k).ParentRow.MarkerRadiusPixels=NaN;
        end
    end
end
ids=zeros(n,1);
for k=1:n
    result=edit_colony(result,'add',centers(k,:),labels(k));
    ids(k)=result.Colonies.ID(end);
    result.Colonies.Source(end)="manual_add";
    result.Colonies.MarkerRadiusPixels(end)=radii(k);
end
result.Summary=summarize_colonies(result);
end

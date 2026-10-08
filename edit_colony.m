function result = edit_colony(result, action, target, colonyClass)
%EDIT_COLONY Apply an auditable manual correction in original image pixels.
% result=edit_colony(result,'delete',17);
% result=edit_colony(result,'classify',17,'AD24');
% result=edit_colony(result,'classify',17,'Not a colony'); % Reversible exclusion
% result=edit_colony(result,'confirm',17);
% result=edit_colony(result,'add',[x y],'AD9');
% Manual additions have NaN area/diameter: no segmentation was measured.
if nargin<4, colonyClass=""; end
action=string(action); colonyClass=string(colonyClass); T=result.Colonies;
if ismember(action,["add","classify"]) && ...
        ~ismember(colonyClass,["AD9","AD24","Uncertain","Not a colony"])
    error('CFU:InvalidClass','Class must be AD9, AD24, Uncertain, or Not a colony.');
end
if action=="add"
    validateattributes(target,{'numeric'},{'vector','numel',2,'finite','real'});
    x=target(1); y=target(2);
    wxy=round((target-0.5)*result.Scale+0.5);
    if any(wxy<1) || wxy(1)>size(result.ROI,2) || wxy(2)>size(result.ROI,1) || ...
            ~result.ROI(wxy(2),wxy(1))
        error('CFU:OutsideROI','Addition is outside the counting region; adjust the ROI first.');
    end
    % Preserve stable IDs, including IDs removed in earlier edits.
    if ~isfield(result,'NextID'), result.NextID=max([0;T.ID])+1; end
    id=result.NextID; result.NextID=id+1;
    row=cell(1,width(T));
    for j=1:width(T)
        values=T.(T.Properties.VariableNames{j});
        if isnumeric(values), row{j}=NaN;
        elseif islogical(values), row{j}=false;
        else, row{j}="";
        end
    end
    T(end+1,:)=row;
    T.ID(end)=id; T.X(end)=x; T.Y(end)=y; T.Class(end)=colonyClass;
    T.NeedsReview(end)=colonyClass=="Uncertain";
    T.ReviewReason(end)="manual_addition"; T.Reviewed(end)=true; T.Source(end)="manual";
    T.ClassifierBasis(end)="manual";
    message=sprintf('add ID %d at (%.2f, %.2f) as %s',id,x,y,colonyClass);
else
    validateattributes(target,{'numeric'},{'scalar','integer','positive'});
    index=find(T.ID==target,1);
    if isempty(index), error('CFU:MissingID','Colony ID %d does not exist.',target); end
    if ~isfield(result,'NextID'), result.NextID=max([0;T.ID])+1; end
    switch action
        case "delete"
            message=sprintf('delete ID %d (previous class %s)',target,T.Class(index));
            result.Labels(result.Labels==target)=0;
            T(index,:)=[];
        case "classify"
            message=sprintf('classify ID %d: %s -> %s',target,T.Class(index),colonyClass);
            T.Class(index)=colonyClass;
            if ismember('ResolutionAccepted',T.Properties.VariableNames), T.ResolutionAccepted(index)=false; end
            T.Reviewed(index)=true; T.NeedsReview(index)=colonyClass=="Uncertain";
        case "confirm"
            message=sprintf('confirm ID %d as %s',target,T.Class(index));
            T.Reviewed(index)=true; T.NeedsReview(index)=T.Class(index)=="Uncertain";
        otherwise
            error('CFU:InvalidAction','Action must be add, delete, classify, or confirm.');
    end
end
result.Colonies=T;
result.ReviewLog(end+1,1)=string(message);
result=update_colony_warnings(result);
result.Summary=summarize_colonies(result);
end

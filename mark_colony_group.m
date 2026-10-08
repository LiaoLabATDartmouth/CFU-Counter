function [result,ids]=mark_colony_group(result,action,target,centers,labels)
%MARK_COLONY_GROUP Replace one detected object with individually labeled marks.
% Centers are original-image pixels. Archived parents can be restored by
% parent or child ID. Mark radii are visual aids, not segmented measurements.
T=result.Colonies;
if string(action)=="restore"
    group=[];
    if isfield(result,'ManualGroups')
        for k=1:numel(result.ManualGroups)
            g=result.ManualGroups(k);
            if target==g.ParentRow.ID || any(target==g.ChildIDs), group=k; break; end
        end
    end
    if isempty(group), error('CFU:NoManualGroup','Select an individually marked colony to undo its group.'); end
    g=result.ManualGroups(group); ids=g.ParentRow.ID;
    T(ismember(T.ID,g.ChildIDs),:)=[];
    T=[T;g.ParentRow]; T=sortrows(T,'ID');
    result.Labels(ismember(result.Labels,g.ChildIDs))=0;
    result.Labels(g.PixelIdx)=ids;
    result.ManualGroups(group)=[];
    message=sprintf('undo individual marks for ID %d; restore original object',ids);
elseif string(action)=="replace"
    row=validate_colony_centers(result,target,centers);
    n=size(centers,1); labels=string(labels(:)); labels(labels=="Need review")="Uncertain";
    if n<2, error('CFU:TooFewMarks','Mark at least two individual colony centers before confirming.'); end
    if numel(labels)~=n || any(~ismember(labels,["AD9","AD24","Uncertain","Not a colony"]))
        error('CFU:InvalidClass','Assign one valid label to each marked center.');
    end
    for name=["MarkedFromID","MarkerRadiusPixels"]
        if ~ismember(name,T.Properties.VariableNames), T.(name)=nan(height(T),1); end
    end
    parent=T(row,:); pixels=find(result.Labels==target);
    if ~isfield(result,'NextID'), result.NextID=max([0;T.ID])+1; end
    ids=(result.NextID:result.NextID+n-1)'; result.NextID=result.NextID+n;
    % Keep physical features missing: these are confirmed centers, not new
    % measured boundaries. Nearest-center mask ownership only supports picking.
    blank=cell(1,width(T));
    for k=1:width(T)
        v=T.(T.Properties.VariableNames{k});
        if isnumeric(v), blank{k}=NaN;
        elseif islogical(v), blank{k}=false;
        else, blank{k}="";
        end
    end
    children=T([],:);
    parentRadius=colony_circle_radii(parent,result.Scale)/result.Scale;
    for k=1:n
        children(k,:)=blank;
        children.ID(k)=ids(k); children.X(k)=centers(k,1); children.Y(k)=centers(k,2);
        children.Class(k)=labels(k); children.Reviewed(k)=true;
        children.Source(k)="manual_mark"; children.ClassifierBasis(k)="manual";
        children.MarkedFromID(k)=target; children.SplitStatus(k)="manual_mark";
        if ismember('ParentID',T.Properties.VariableNames), children.ParentID(k)=target; end
        distance=hypot(centers(:,1)-centers(k,1),centers(:,2)-centers(k,2)); distance(k)=Inf;
        children.MarkerRadiusPixels(k)=max(1.5/result.Scale,min(parentRadius/sqrt(n),0.4*min(distance)));
    end
    T(row,:)=[]; T=[T;children];
    [y,x]=ind2sub(size(result.Labels),pixels); work=(centers-0.5)*result.Scale+0.5;
    nearest=ones(size(pixels)); best=inf(size(pixels));
    for k=1:n
        distance=(x-work(k,1)).^2+(y-work(k,2)).^2;
        take=distance<best; nearest(take)=k; best(take)=distance(take);
    end
    result.Labels(pixels)=ids(nearest);
    g=struct('ParentRow',parent,'PixelIdx',pixels,'ChildIDs',ids);
    if ~isfield(result,'ManualGroups'), result.ManualGroups=g;
    else, result.ManualGroups(end+1)=g;
    end
    message=sprintf('replace ID %d with individually marked IDs %s',target,strjoin(string(ids'),', '));
else
    error('CFU:InvalidAction','Use replace or restore for individual colony marks.');
end
result.Colonies=T; result.ReviewLog(end+1,1)=string(message);
result=update_colony_warnings(result); result.Summary=summarize_colonies(result);
end

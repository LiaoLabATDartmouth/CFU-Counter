function [result,carried,lost]=prepare_colony_app_result(result,previous)
%PREPARE_COLONY_APP_RESULT Make app counts disjoint and retain safe edits.
% Automatic suggestions remain available separately from the user's label.
% Carry corrections only across identical segmented objects in the same image.
carried=0; lost=0;
result.Colonies.SuggestedClass=result.Colonies.Class;
result.Colonies.Class(result.Colonies.NeedsReview)="Uncertain";
if nargin>=2 && ~isempty(previous)
    manual=find(previous.Colonies.Reviewed);
    lost=numel(manual);
    sameImage=string(previous.ImageFile)==string(result.ImageFile);
    sameGrid=isequal(size(previous.Labels),size(result.Labels)) && previous.Scale==result.Scale;
    if sameImage && sameGrid
        for k=reshape(manual,1,[])
            if ismember(previous.Colonies.Source(k),["manual_mark","manual_add"]), continue; end
            oldID=previous.Colonies.ID(k); mask=previous.Labels==oldID;
            ids=unique(result.Labels(mask));
            if nnz(mask)==0 || numel(ids)~=1 || ids==0, continue; end
            if nnz(result.Labels==ids)~=nnz(mask), continue; end
            result=edit_colony(result,'classify',double(ids),previous.Colonies.Class(k));
            carried=carried+1;
        end
        % Recreate a marked group only when its entire original object is
        % unchanged. Carry current child labels, including later exclusions.
        if isfield(previous,'ManualGroups')
            for k=1:numel(previous.ManualGroups)
                g=previous.ManualGroups(k); pixels=g.PixelIdx;
                ids=unique(result.Labels(pixels));
                if isempty(pixels) || numel(ids)~=1 || ids==0, continue; end
                if nnz(result.Labels==ids)~=numel(pixels), continue; end
                [present,rows]=ismember(g.ChildIDs,previous.Colonies.ID);
                if ~all(present), continue; end
                children=previous.Colonies(rows,:);
                try
                    candidate=result;
                    if g.ParentRow.Reviewed
                        candidate=edit_colony(candidate,'classify',double(ids),g.ParentRow.Class);
                    end
                    candidate=mark_colony_group(candidate,'replace',double(ids),[children.X children.Y],children.Class);
                    result=candidate;
                    carried=carried+height(children);
                catch err
                    if ~startsWith(err.identifier,'CFU:'), rethrow(err); end
                    % Changed ROI or conflicting centers require fresh review.
                end
            end
        end
        % Keep missed centers while they remain inside the plate and still
        % undetected. A newly detected object must not receive a duplicate.
        additions=find(previous.Colonies.Source=="manual_add");
        for k=reshape(additions,1,[])
            row=previous.Colonies(k,:);
            try
                result=add_missed_colonies(result,[row.X row.Y],row.Class,row.MarkerRadiusPixels);
                carried=carried+1;
            catch err
                if ~startsWith(err.identifier,'CFU:'), rethrow(err); end
                % Report unretained corrections in the app status for review.
            end
        end
        lost=lost-carried;
    end
end
result.Summary=summarize_colonies(result);
end

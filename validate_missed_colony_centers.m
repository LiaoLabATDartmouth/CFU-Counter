function validate_missed_colony_centers(result,centers)
%VALIDATE_MISSED_COLONY_CENTERS Validate new centers in original-image pixels.
% An existing enclosing circle can overlap a missed neighbor. Test the actual
% segmented pixels and centers, not that circle's full interior.
validateattributes(centers,{'numeric'},{'2d','ncols',2,'finite','real'});
if isempty(centers), return; end
work=(centers-0.5)*result.Scale+0.5; pixels=round(work);
if any(pixels(:,1)<1 | pixels(:,2)<1 | pixels(:,1)>size(result.Labels,2) | pixels(:,2)>size(result.Labels,1))
    error('CFU:OutsideROI','Click inside the selected plate.');
end
indices=sub2ind(size(result.Labels),pixels(:,2),pixels(:,1));
if any(~result.ROI(indices)), error('CFU:OutsideROI','Click inside the selected plate.'); end
detected=double(result.Labels(indices)); detected=detected(detected~=0);
if ~isempty(detected)
    error('CFU:AlreadyCounted','That center is in object %d. Edit its label, or use Mark individual colonies if it contains several colonies.',detected(1));
end
T=result.Colonies; existing=([T.X T.Y]-0.5)*result.Scale+0.5;
for k=1:size(work,1)
    close=hypot(existing(:,1)-work(k,1),existing(:,2)-work(k,2))<3;
    if any(close)
        error('CFU:AlreadyCounted','A center already exists here (ID %d). Edit that entry instead of adding it again.',T.ID(find(close,1)));
    end
    if any(hypot(work(1:k-1,1)-work(k,1),work(1:k-1,2)-work(k,2))<3)
        error('CFU:DuplicateCenter','Click a distinct colony center, at least 3 processed-image pixels from another mark.');
    end
end
end

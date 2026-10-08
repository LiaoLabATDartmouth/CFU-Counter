function row=validate_colony_centers(result,parentID,centers)
%VALIDATE_COLONY_CENTERS Original-image centers inside one selected object.
T=result.Colonies; row=find(T.ID==parentID,1);
if isempty(row), error('CFU:MissingID','Colony ID %d does not exist.',parentID); end
if T.Source(row)=="manual_mark"
    error('CFU:ManualGroup','Select one of these marks and click Undo marks before marking this object again.');
end
if ~any(result.Labels(:)==parentID)
    error('CFU:NoSegment','Select a detected object with a boundary first.');
end
validateattributes(centers,{'numeric'},{'2d','ncols',2,'finite','real'});
if isempty(centers), return; end
work=(centers-0.5)*result.Scale+0.5; pixel=round(work);
if any(pixel(:,1)<1 | pixel(:,2)<1 | pixel(:,1)>size(result.Labels,2) | pixel(:,2)>size(result.Labels,1))
    error('CFU:OutsideROI','Click inside the selected plate.');
end
indices=sub2ind(size(result.Labels),pixel(:,2),pixel(:,1));
if any(~result.ROI(indices)), error('CFU:OutsideROI','Click inside the selected plate.'); end
radius=colony_circle_radii(T(row,:),result.Scale)+3;
center=([T.X(row),T.Y(row)]-0.5)*result.Scale+0.5;
if any(hypot(work(:,1)-center(1),work(:,2)-center(2))>radius)
    error('CFU:OutsideObject','Click a center inside the selected object''s circle.');
end
other=double(result.Labels(indices)); other=other(other~=0 & other~=parentID);
if ~isempty(other)
    error('CFU:OtherColony','That point is already detected as colony %d. Choose a center in the selected object.',other(1));
end
for k=2:size(work,1)
    if any(hypot(work(1:k-1,1)-work(k,1),work(1:k-1,2)-work(k,2))<3)
        error('CFU:DuplicateCenter','Click a distinct colony center (at least 3 image pixels from another mark).');
    end
end
end

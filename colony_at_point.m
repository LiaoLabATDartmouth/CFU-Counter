function id=colony_at_point(result,point,reviewOnly,candidateIDs,onBoundary)
%COLONY_AT_POINT Pick a visible colony in displayed-image pixel coordinates.
% Prefer segmented pixels, including where a neighboring ring crosses them.
% OnBoundary means MATLAB already hit a ring. IDs are never table rows.
if nargin<3, reviewOnly=false; end
if nargin<4, candidateIDs=[]; end
if nargin<5, onBoundary=false; end
id=[];
if numel(point)<2 || any(~isfinite(point(1:2))), return; end
point=reshape(point(1:2),1,2);
T=result.Colonies;
keep=T.Class~="Not a colony";
if reviewOnly, keep=keep & T.NeedsReview; end
T=T(keep,:); if isempty(T), return; end
pixel=round(point);
if any(pixel<1) || pixel(1)>size(result.Labels,2) || pixel(2)>size(result.Labels,1), return; end
hit=double(result.Labels(pixel(2),pixel(1)));
if any(T.ID==hit), id=hit; return; end
if ~isempty(candidateIDs), T=T(ismember(T.ID,candidateIDs),:); end
if isempty(T), return; end
xy=([T.X T.Y]-0.5)*result.Scale+0.5;
radius=colony_circle_radii(T,result.Scale)+3*double(T.NeedsReview);
distance=hypot(xy(:,1)-point(1),xy(:,2)-point(2));
if onBoundary
    % Native hit testing includes the stroke's screen-pixel width. A fixed
    % tolerance in image pixels misses small rings at the whole-plate zoom.
    score=abs(distance-radius);
    eligible=true(height(T),1);
else
    score=distance./radius;
    eligible=distance<=radius;
end
score(~eligible)=Inf;
[best,index]=min(score);
if isfinite(best), id=T.ID(index); end
end

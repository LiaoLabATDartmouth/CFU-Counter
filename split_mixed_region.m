function [parts,info]=split_mixed_region(mask,pink,smallRadius,colorCutoff)
%SPLIT_MIXED_REGION Separate a pale lobe from a strongly pink colony.
% Only partitions pixels already in mask. A surrounding pale halo is not
% accepted as a second colony: the pale core must be a compact, offset lobe.
parts=zeros(size(mask),'uint8');
info=struct('Candidate',false,'Accepted',false,'Reason',"",'ColorDifference',NaN, ...
    'CenterDistance',NaN,'PaleSolidity',NaN);
parentShape=regionprops(mask,'Solidity','Perimeter','Area');
if numel(parentShape)~=1, return; end
roundness=4*pi*parentShape.Area/max(parentShape.Perimeter^2,eps);
if parentShape.Solidity>0.95 && roundness>0.95, return; end
D=bwdist(~mask);
smooth=imgaussfilt(pink,0.65);
coreRadius=max(1,round(0.28*smallRadius));
strong=imopen(mask & smooth>colorCutoff,strel('disk',coreRadius,0));
if ~any(strong(:)), return; end
strong=bwareafilt(strong,1);
minimumCoreArea=max(5,0.18*pi*smallRadius^2);
if nnz(strong)<minimumCoreArea, return; end
pale=imopen(mask & smooth<colorCutoff,strel('disk',coreRadius,0));
components=bwconncomp(pale);
regions=regionprops(components,'Area','Centroid','Solidity','Eccentricity','PixelIdxList');
[~,highIndex]=max(D(:).*double(strong(:)));
[highY,highX]=ind2sub(size(mask),highIndex);
highRadius=sqrt(nnz(strong)/pi);
best=-Inf; paleRegion=[];
for k=1:numel(regions)
    p=regions(k);
    if p.Area<minimumCoreArea || p.Area>0.60*nnz(mask), continue; end
    separation=hypot(p.Centroid(1)-highX,p.Centroid(2)-highY);
    lowRadius=sqrt(p.Area/pi);
    if separation<0.70*(highRadius+lowRadius), continue; end
    if p.Solidity<0.78 || p.Eccentricity>0.96, continue; end
    colorDifference=median(smooth(strong))-median(smooth(p.PixelIdxList));
    if colorDifference<0.20, continue; end
    % Compact lobes should lie predominantly on one side of the high core.
    [py,px]=ind2sub(size(mask),p.PixelIdxList);
    vectors=[px-highX,py-highY]; direction=[p.Centroid(1)-highX,p.Centroid(2)-highY];
    if mean(vectors*direction'>0)<0.95, continue; end
    score=p.Area*p.Solidity*colorDifference;
    if score>best
        best=score; paleRegion=p; info.ColorDifference=colorDifference;
        info.CenterDistance=separation; info.PaleSolidity=p.Solidity;
    end
end
if isempty(paleRegion), return; end
% Fit the dominant outer circle using the boundary away from the pale lobe.
% A differently colored cap INSIDE that circle is shading, not evidence of
% an additional colony. Require most of the pale core to protrude outside.
[by,bx]=find(bwperim(mask));
direction=paleRegion.Centroid-[highX highY]; direction=direction/norm(direction);
vectors=[bx-highX,by-highY]; lengths=hypot(vectors(:,1),vectors(:,2));
away=(vectors*direction')./max(lengths,eps)<0.5;
if nnz(away)<6, return; end
circle=[2*bx(away),2*by(away),ones(nnz(away),1)]\(bx(away).^2+by(away).^2);
center=circle(1:2)'; radius=sqrt(max(0,circle(3)+sum(center.^2)));
if ~isfinite(radius) || radius<0.65*highRadius || radius>2*highRadius, return; end
[py,px]=ind2sub(size(mask),paleRegion.PixelIdxList);
outsideFraction=mean(hypot(px-center(1),py-center(2))>radius);
if outsideFraction<0.55, return; end
info.Candidate=true;
lowMask=false(size(mask)); lowMask(paleRegion.PixelIdxList)=true;
lowMask=imfill(lowMask,'holes') & mask;
[~,lowIndex]=max(reshape(bwdist(~lowMask),[],1));
[lowY,lowX]=ind2sub(size(mask),lowIndex);
% Force a seed in each color lobe, then cut at a geometric/color saddle.
% Retain the entire compact pale core as a marker. A single seed on its
% edge can be swallowed by the much deeper distance basin of the large lobe.
markers=lowMask; markers(highIndex)=true;
gradient=imgradient(smooth); gradient=gradient/max(max(gradient(mask)),eps);
surface=-D+0.20*max(D(:))*gradient;
surface(~mask)=2*max(D(:))+1;
W=watershed(imimposemin(surface,markers));
labelHigh=W(highY,highX); labelLow=W(lowY,lowX);
if labelHigh==labelLow || min(labelHigh,labelLow)==0
    info.Reason="no_stable_internal_partition"; return
end
parts(mask & W==labelHigh)=1; parts(mask & W==labelLow)=2;
missing=mask & parts==0;
if any(missing(:))
    [~,nearest]=bwdist(parts>0);
    parts(missing)=parts(nearest(missing));
end
if ~isequal(parts>0,mask), error('CFU:BoundaryChanged','Internal split changed the outer mask.'); end
for child=1:2
    cc=bwconncomp(parts==child);
    if cc.NumObjects~=1, info.Reason="disconnected_child"; parts(:)=0; return; end
end
geometry=regionprops(parts,'Area','Solidity','Eccentricity','Centroid');
minimumArea=max(8,0.30*pi*smallRadius^2);
if any([geometry.Area]<minimumArea) || any([geometry.Solidity]<0.75) || ...
        any([geometry.Eccentricity]>0.96)
    info.Reason="implausible_child_shape"; parts(:)=0; return
end
% Avoid splitting a round single colony with two-tone shading or a halo.
parentRadius=sqrt(nnz(mask)/pi);
distance=hypot(geometry(1).Centroid(1)-geometry(2).Centroid(1), ...
    geometry(1).Centroid(2)-geometry(2).Centroid(2));
if distance<0.90*parentRadius
    info.Reason="no_distinct_spatial_lobes"; parts(:)=0; return
end
info.Accepted=true; info.Reason="separate_color_and_shape_lobes";
end

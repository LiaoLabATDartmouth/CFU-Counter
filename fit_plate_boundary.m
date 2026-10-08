function [ellipse,info] = fit_plate_boundary(I,initial)
%FIT_PLATE_BOUNDARY Fit the selected plate's rim from a rough ellipse.
% Coordinates use the supplied image and MATLAB ROI rotation convention.
% Combine local refinement with coherent contours of the nearby plate
% containing the seed center. Weak/heavily cropped evidence is rejected.
validateattributes(initial,{'numeric'},{'real','finite','vector','numel',5});
initial=double(reshape(initial,1,5));
if any(initial(3:4)<=0), error('CFU:InvalidOptions','Ellipse radii must be positive.'); end
ellipse=initial; info=emptyInfo();
if size(I,3)~=3, error('CFU:NotRGB','Rim fitting requires an RGB photograph.'); end
scale=min(1,1000/max(size(I,1),size(I,2)));
I=im2single(imresize(I,scale)); seed=initial;
seed(1:2)=(seed(1:2)-0.5)*scale+0.5; seed(3:4)=seed(3:4)*scale;
radius=sqrt(prod(seed(3:4)));
if radius<15, return; end
% Image-relative smoothing is independent of the rough boundary size, so
% repeating Fit to rim does not change the underlying edge evidence.
for c=1:3
    channel=I(:,:,c); ordered=sort(channel(:));
    lo=ordered(max(1,round(.02*numel(ordered))));
    hi=ordered(max(1,round(.98*numel(ordered))));
    I(:,:,c)=imgaussfilt((channel-lo)/max(hi-lo,0.1),max(1,.0012*max(size(I,1),size(I,2))));
end
% A narrow refinement keeps a near-rim seed on one edge. Contour proposals
% also check for a larger concentric rim, rather than accepting an inner
% reflection just because it is closer to the starting ellipse.
[local,localInfo]=refineRim(I,seed,.07,.03);
if ~localInfo.Fitted, [local,localInfo]=refineRim(I,seed,.30,.22); end
proposals=rimProposals(I,seed);
fits=zeros(0,5); scores=zeros(0,1); details=repmat(emptyInfo(),0,1);
for k=0:size(proposals,1)
    if k==0
        candidate=local; trial=localInfo; trial.SearchMethod="local";
    else
        [candidate,trial]=refineRim(I,proposals(k,:),.07,.03);
        trial.SearchMethod="contour";
    end
    if ~trial.Fitted || ~matchesSelection(candidate,seed), continue; end
    % Normalize agreement by the visible arc so a slightly cropped outer rim
    % is not disadvantaged against a fully visible reflection inside it.
    score=trial.SupportedFraction/trial.VisibleFraction-.02*trial.MedianResidualPixels ...
        -.04*norm(candidate(1:2)-seed(1:2))/radius;
    fits(end+1,:)=candidate; scores(end+1,1)=score; details(end+1,1)=trial; %#ok<AGROW>
end
if isempty(fits)
    info=localInfo; info.Fitted=false; info.SearchMethod="none";
    info.MedianResidualPixels=info.MedianResidualPixels/scale; return
end
[bestScore,index]=max(scores); reference=fits(index,:); area=prod(reference(3:4));
[x,y]=ellipsePoints(reference,(0:71)*2*pi/72); referenceRadius=sqrt(area);
for k=1:size(fits,1)
    candidate=fits(k,:); candidateArea=prod(candidate(3:4));
    % Among similarly well-supported rings around the same center, use the
    % outer rim. This cannot select a separate neighboring plate.
    if scores(k)>=bestScore-.08 && candidateArea>area && ...
            norm(candidate(1:2)-reference(1:2))<.08*referenceRadius && ...
            all(sort(candidate(3:4))./sort(reference(3:4))<=1.5) && ...
            max(ellipseResidual([x' y'],candidate))<max(2,.01*referenceRadius)
        index=k; area=candidateArea;
    end
end
best=fits(index,:); info=details(index);
info.MedianResidualPixels=info.MedianResidualPixels/scale;
if ~info.Fitted, return; end
ellipse=best; ellipse(1:2)=(ellipse(1:2)-0.5)/scale+0.5; ellipse(3:4)=ellipse(3:4)/scale;
info.Message='Boundary fitted to the visible rim. Check the outline and adjust it if needed.';
if info.VisibleFraction<.98
    info.Message='Boundary fitted to the visible rim. A cropped section is estimated; check the outline.';
end
end

function info=emptyInfo()
info=struct('Fitted',false,'Message', ...
    'Could not fit a reliable rim. Center the boundary on the desired plate, resize it closer to the rim, then retry or adjust manually.', ...
    'SupportedFraction',0,'MedianResidualPixels',NaN,'VisibleFraction',0,'SearchMethod',"none");
end

function proposals=rimProposals(I,seed)
% Long curved edges propose complete ellipses even when the seed misses much
% of the rim. Other plates and short colony/text edges are rejected before
% every candidate is checked against angularly distributed rim evidence.
radius=sqrt(prod(seed(3:4))); proposals=zeros(0,5); quality=zeros(0,1);
for c=1:4
    if c<=3, channel=I(:,:,c); else, channel=rgb2gray(I); end
    edges=edge(channel,'Canny'); components=bwconncomp(edges);
    lengths=cellfun(@numel,components.PixelIdxList); [~,order]=sort(lengths,'descend');
    for index=reshape(order(1:min(40,numel(order))),1,[])
        pixels=components.PixelIdxList{index};
        if numel(pixels)<max(80,.5*radius), continue; end
        pixels=pixels(1:max(1,floor(numel(pixels)/2000)):end);
        [y,x]=ind2sub(size(edges),pixels); points=[x y];
        e=fitConic((points-seed(1:2))/radius,ones(numel(x),1));
        if isempty(e), continue; end
        e(1:2)=e(1:2)*radius+seed(1:2); e(3:4)=e(3:4)*radius;
        if ~matchesSelection(e,seed), continue; end
        residual=median(abs(ellipseResidual(points,e)));
        if residual>max(1.5,.01*radius), continue; end
        a=deg2rad(e(5)); delta=points-e(1:2);
        u=(delta(:,1)*cos(a)-delta(:,2)*sin(a))/e(3);
        v=(delta(:,1)*sin(a)+delta(:,2)*cos(a))/e(4);
        bins=min(12,floor(mod(atan2(v,u),2*pi)/(2*pi)*12)+1);
        coverage=nnz(accumarray(bins,1,[12 1])>=5);
        if coverage<5, continue; end
        proposals(end+1,:)=e; %#ok<AGROW>
        quality(end+1,1)=coverage/12-.05*residual ...
            -.05*norm(e(1:2)-seed(1:2))/radius; %#ok<AGROW>
    end
end
[~,order]=sort(quality,'descend'); candidates=proposals(order,:); proposals=zeros(0,5);
for k=1:size(candidates,1)
    e=candidates(k,:); [x,y]=ellipsePoints(e,(0:35)*2*pi/36); duplicate=false;
    for j=1:size(proposals,1)
        if max(abs(ellipseResidual([x' y'],proposals(j,:))))<max(1,.008*radius)
            duplicate=true; break
        end
    end
    if ~duplicate, proposals(end+1,:)=e; end %#ok<AGROW>
    if size(proposals,1)>=24, break; end
end
end

function yes=matchesSelection(e,seed)
radius=sqrt(prod(seed(3:4))); ratios=sort(e(3:4))./sort(seed(3:4));
a=deg2rad(e(5)); delta=seed(1:2)-e(1:2);
u=delta(1)*cos(a)-delta(2)*sin(a); v=delta(1)*sin(a)+delta(2)*cos(a);
yes=all(ratios>=.60 & ratios<=2.0) && min(e(3:4))/max(e(3:4))>=.40 ...
    && norm(delta)<=1.1*radius && (u/e(3))^2+(v/e(4))^2<=.95^2;
end

function [x,y]=ellipsePoints(e,theta)
a=deg2rad(e(5));
x=e(1)+e(3)*cos(theta)*cos(a)+e(4)*sin(theta)*sin(a);
y=e(2)-e(3)*cos(theta)*sin(a)+e(4)*sin(theta)*cos(a);
end

function [ellipse,info]=refineRim(I,e,searchWidth,proximityWidth)
ellipse=e; info=emptyInfo(); radius=sqrt(prod(e(3:4)));
theta=(0:239)*2*pi/240;
angle=deg2rad(e(5));
vx=e(3)*cos(theta)*cos(angle)+e(4)*sin(theta)*sin(angle);
vy=-e(3)*cos(theta)*sin(angle)+e(4)*sin(theta)*cos(angle);
rhos=linspace(1-searchWidth,1+searchWidth,max(61,ceil(2*searchWidth*radius)))';
x=e(1)+rhos*vx; y=e(2)+rhos*vy;
strength=zeros(size(x));
for c=1:3
    inside=interp2(I(:,:,c),x-vx/radius,y-vy/radius,'linear',NaN);
    outside=interp2(I(:,:,c),x+vx/radius,y+vy/radius,'linear',NaN);
    strength=strength+double(outside-inside).^2;
end
strength=sqrt(strength); strength(~isfinite(strength))=0;
% A rim continues over neighboring rays; isolated colony/label edges do not.
strength=movmedian(strength(:,[end-1:end 1:end 1:2]),5,2);
strength=strength(:,3:end-2);
% A broad proximity preference helps avoid jumping to a neighboring plate.
score=strength.*exp(-0.5*((rhos-1)/proximityWidth).^2);
[~,index]=max(score,[],1); pick=sub2ind(size(x),index,1:numel(theta));
points=[x(pick)' y(pick)']; edge=strength(pick)';
% A proximity-weighted search can trace an ellipse through random texture.
% Require a peak above the surrounding radial texture, in addition to the
% absolute contrast floor. This ratio adapts to exposure and color balance.
background=median(strength,1)';
good=edge>max(0.008,0.15*median(edge)) & edge>1.6*background;
if nnz(good)<0.60*numel(theta), return; end
pointsNormalized=(points-e(1:2))/radius;
weights=double(good);
candidate=[];
for iteration=1:8
    candidate=fitConic(pointsNormalized,weights);
    if isempty(candidate), return; end
    residual=ellipseResidual(pointsNormalized,candidate);
    active=abs(residual(good));
    spread=max(0.003,1.4826*median(abs(active-median(active))));
    cutoff=max(0.012,4.685*spread);
    weights=double(good).*max(0,1-(residual/cutoff).^2).^2;
    if nnz(weights>0)<0.55*numel(theta), return; end
end
candidate(1:2)=candidate(1:2)*radius+e(1:2);
candidate(3:4)=candidate(3:4)*radius;
residual=ellipseResidual(points,candidate);
supported=good & abs(residual)<max(2,0.015*radius);
info.SupportedFraction=mean(supported);
if any(supported), info.MedianResidualPixels=median(abs(residual(supported))); end
% Require evidence around the plate, not just a bright arc or a straight edge.
sectors=reshape(supported,20,12);
coverage=nnz(sum(sectors,1)>=10);
axisRatio=sort(candidate(3:4))./sort(e(3:4));
[rimX,rimY]=ellipsePoints(candidate,theta);
info.VisibleFraction=mean(rimX>=2 & rimX<=size(I,2)-1 & rimY>=2 & rimY<=size(I,1)-1);
if info.SupportedFraction<0.65 || coverage<9 || info.VisibleFraction<0.75 || ...
        norm(candidate(1:2)-e(1:2))>0.22*radius || ...
        any(axisRatio<0.70 | axisRatio>1.30)
    return
end
ellipse=candidate; info.Fitted=true;
end

function e=fitConic(points,weights)
% Weighted linear ellipse fit in coordinates normalized by the seed radius.
x=points(:,1); y=points(:,2); design=[x.^2 2*x.*y y.^2 x y];
active=weights>0; e=[];
if nnz(active)<10, return; end
design=design(active,:).*sqrt(weights(active)); rhs=sqrt(weights(active));
if rcond(design'*design)<1e-10, return; end
coefficient=design\rhs;
Q=[coefficient(1) coefficient(2);coefficient(2) coefficient(3)];
if any(eig(Q)<=0), return; end
center=-0.5*(Q\coefficient(4:5));
level=1+center'*Q*center;
[vectors,values]=eig(Q/level); [values,order]=sort(diag(values));
if any(values<=0), return; end
major=vectors(:,order(1));
angle=mod(atan2d(-major(2),major(1))+90,180)-90;
e=[center' 1./sqrt(values') angle];
end

function distance=ellipseResidual(points,e)
angle=deg2rad(e(5)); delta=points-e(1:2);
u=delta(:,1)*cos(angle)-delta(:,2)*sin(angle);
v=delta(:,1)*sin(angle)+delta(:,2)*cos(angle);
level=(u/e(3)).^2+(v/e(4)).^2;
gradient=2*hypot(u/e(3)^2,v/e(4)^2);
distance=(level-1)./max(gradient,eps);
end

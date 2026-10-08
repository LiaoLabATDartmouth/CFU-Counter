function result=measure_resolution_features(result)
%MEASURE_RESOLUTION_FEATURES Measure clean interiors without altering labels.
% A larger local annulus is tried when nearby clean agar is scarce. Pixels
% in other detections, rejected objects, ink, or outside the ROI are excluded.
T=result.Colonies; I=result.Image;
logs=log(max(rgb2lin(I),1e-5));
rg=logs(:,:,1)-logs(:,:,2); bg=logs(:,:,3)-logs(:,:,2);
pink=rg+bg; light=mean(logs,3);
names={'CoreLogRG','CoreLogBG','CoreLogBrightness','CorePinkQ90', ...
    'CorePinkSpread','CoreToEdgePink','CoreBrightnessSpread', ...
    'ResolutionBackgroundPixels','ResolutionBackgroundRadiusPixels', ...
    'CleanCoreFraction','CleanCorePixels'};
for name=names, T.(name{1})=nan(height(T),1); end
occupied=result.Labels>0 | result.RejectedMask;
for i=1:height(T)
    [yy,xx]=find(result.Labels==T.ID(i));
    if isempty(xx), continue; end
    radius=T.DiameterPixels(i)*result.Scale/2;
    initial=max(3,ceil(0.7*radius)); maximum=max(initial,ceil(2.5*radius));
    xs=max(1,min(xx)-maximum):min(size(I,2),max(xx)+maximum);
    ys=max(1,min(yy)-maximum):min(size(I,1),max(yy)+maximum);
    mask=result.Labels(ys,xs)==T.ID(i);
    allowed=~occupied(ys,xs) & result.ROI(ys,xs) & ~result.InkMask(ys,xs);
    outsideDistance=bwdist(mask);
    for padding=unique([initial,ceil(1.2*radius),ceil(1.8*radius),maximum])
        ring=outsideDistance<=padding & allowed;
        if nnz(ring)>=30, break; end
    end
    T.ResolutionBackgroundPixels(i)=nnz(ring);
    T.ResolutionBackgroundRadiusPixels(i)=padding/result.Scale;
    distance=bwdist(~mask);
    core=mask & distance>=max(1,0.40*max(distance(:)));
    clean=core & ~result.InkMask(ys,xs);
    T.CleanCorePixels(i)=nnz(clean);
    T.CleanCoreFraction(i)=nnz(clean)/max(nnz(core),1);
    if nnz(ring)<30 || nnz(clean)<8 || T.CleanCoreFraction(i)<0.6, continue; end
    r=rg(ys,xs); b=bg(ys,xs); p=pink(ys,xs); l=light(ys,xs);
    T.CoreLogRG(i)=median(r(clean))-median(r(ring));
    T.CoreLogBG(i)=median(b(clean))-median(b(ring));
    T.CoreLogBrightness(i)=median(l(clean))-median(l(ring));
    q=quantiles(p(clean),[0.1 0.9]);
    T.CorePinkQ90(i)=q(2)-median(p(ring));
    T.CorePinkSpread(i)=q(2)-q(1);
    edge=mask & ~core & ~result.InkMask(ys,xs);
    if nnz(edge)<3, edge=clean; end
    T.CoreToEdgePink(i)=median(p(clean))-median(p(edge));
    q=quantiles(l(clean),[0.1 0.9]); T.CoreBrightnessSpread(i)=q(2)-q(1);
end
result.Colonies=T;
end

function q=quantiles(x,probabilities)
x=sort(double(x(:))); positions=1+(numel(x)-1)*probabilities;
q=interp1(1:numel(x),x,positions,'linear');
end

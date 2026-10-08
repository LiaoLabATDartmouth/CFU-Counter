function [opts,info]=derive_colony_settings(pilot)
%DERIVE_COLONY_SETTINGS Shared rule for a freshly measured fixed-option pilot.
% Robust statistics use isolated, locally supported objects, not the output
% class or review frequency. All images follow these same bounded formulas.
opts=colony_defaults(); opts.PlateEllipse=pilot.Options.PlateEllipse;
T=pilot.Colonies;
anchor=T.Solidity>=.90 & T.Circularity>=.75 & T.BackgroundPixels>=30 & ...
    ~contains(T.DetectionNotes,"near_ink") & ~contains(T.DetectionNotes,"near_rim") & ...
    isfinite(T.DiameterFraction) & T.CoreLocalLogPink>=max(.12,3*T.LocalPinkNoise) & ...
    T.CoreLocalLogRed>.03;
info=struct('Estimated',true,'Method',"Image content / version 2", ...
    'PilotColonies',height(T),'ReferenceObjects',nnz(anchor), ...
    'OccupiedFraction',nnz(pilot.Labels)/max(nnz(pilot.ROI),1), ...
    'CloseNeighborFraction',0,'Density',"Sparse",'PinkNoise',NaN, ...
    'BrightnessNoise',NaN,'SignalPink',NaN,'SmallDiameterFraction',NaN, ...
    'LargeDiameterFraction',NaN,'SizeReferenceEstimated',false, ...
    'Message',"Conservative settings: few clean reference objects.");
% Report occupied-area crowding even when most objects are merged and there
% are too few isolated references to estimate a reliable diameter.
if info.OccupiedFraction>.10, info.Density="Dense";
elseif info.OccupiedFraction>.04, info.Density="Moderate"; end
% Pixel-scale fluctuations on clean interior agar, after smooth illumination
% has been removed. Robust MAD is insensitive to a minority of missed colonies.
logs=log(max(rgb2lin(pilot.Image),1e-5));
pink=logs(:,:,1)+logs(:,:,3)-2*logs(:,:,2); light=mean(logs,3);
occupied=imdilate(pilot.Labels>0 | pilot.RejectedMask,strel('disk',2,0));
agar=pilot.ROI & ~occupied & ~pilot.InkMask & bwdist(~pilot.ROI)>4;
if nnz(agar)>=500
    residual=pink-imgaussfilt(pink,1);
    info.PinkNoise=robustNoise(residual(agar));
    residual=light-imgaussfilt(light,1);
    info.BrightnessNoise=robustNoise(residual(agar));
end
% The weak end of the reliable signal distribution sets artifact rejection.
% With no reliable evidence, do not lower thresholds until noise is counted.
if nnz(anchor)>=1
    signal=quantileLocal(T.CoreLocalLogPink(anchor),.20);
    info.SignalPink=signal;
    opts.ArtifactFilterStrength=clamp(signal/.50,.5,1.5);
    opts.PinkContrastThreshold=clamp(.10*signal,.04,.08);
else
    opts.ArtifactFilterStrength=2;
end
if isfinite(info.PinkNoise)
    opts.PinkContrastThreshold=clamp(max(opts.PinkContrastThreshold,3*info.PinkNoise),.04,.14);
end
if isfinite(info.BrightnessNoise)
    opts.PaleBrightnessThreshold=clamp(max(.20,3*info.BrightnessNoise),.20,.30);
end
if nnz(anchor)>=3
    % Even a sparse plate can establish the order of magnitude of colony
    % size. Retain objects down to 40% of the lower reference quintile;
    % the upper bound protects a minority of small colonies on mixed plates.
    opts.MinDiameterFraction=clamp(.40*quantileLocal(T.DiameterFraction(anchor),.20),.003,.008);
elseif ~any(anchor)
    % Without reliable colony evidence, tiny sampled ink/rim fragments are
    % not useful size references. Target six processing pixels across an
    % object within control bounds; this scales with resolution, not identity.
    diameter=2*sqrt(prod(pilot.CountingEllipseWork(3:4)));
    opts.MinDiameterFraction=clamp(max(.005,6/diameter),.005,.012);
end
if nnz(anchor)>=10
    d=T.DiameterFraction(anchor); small=quantileLocal(d,.20); large=quantileLocal(d,.90);
    info.SmallDiameterFraction=small; info.LargeDiameterFraction=large;
    opts.MaxDiameterFraction=clamp(1.6*quantileLocal(d,.95),.05,.09);
    opts.BackgroundSigmaFraction=clamp(.55*large,.012,.025);
    % Bounded sample: nearest-neighbor distances do not allocate an N-by-N matrix.
    indices=find(anchor); sample=indices(unique(round(linspace(1,numel(indices),min(1000,numel(indices))))));
    xy=[T.X T.Y]; near=Inf(numel(sample),1); neighbor=ones(numel(sample),1);
    for k=1:numel(sample)
        i=sample(k); distances=hypot(xy(:,1)-xy(i,1),xy(:,2)-xy(i,2)); distances(i)=Inf;
        [near(k),neighbor(k)]=min(distances);
    end
    info.CloseNeighborFraction=mean(near<1.2*(T.DiameterPixels(sample)+T.DiameterPixels(neighbor))/2);
    crowded=info.OccupiedFraction>.10 || info.CloseNeighborFraction>.25;
    opts.WatershedPeakFraction=clamp(.05*small*(1-.10*crowded),.00025,.0007);
    if crowded, info.Density="Dense";
    elseif info.OccupiedFraction>.04 || info.CloseNeighborFraction>.10, info.Density="Moderate"; end
    info.Message=info.Density+" plate: settings estimated from local contrast, noise, size and spacing.";
end
% Keep a common AD9/AD24 size anchor. A single-population size distribution
% must not be split into two invented classes. The composite classifier can
% still learn color/shape weights from sufficient small and large references.
info.EstimatedFields=["PinkContrastThreshold","PaleBrightnessThreshold", ...
    "ArtifactFilterStrength","MinDiameterFraction","MaxDiameterFraction", ...
    "BackgroundSigmaFraction","WatershedPeakFraction"];
info.ProposedEllipse=pilot.CountingEllipseWork;
info.ProposedEllipse(1:2)=(info.ProposedEllipse(1:2)-.5)/pilot.Scale+.5;
info.ProposedEllipse(3:4)=info.ProposedEllipse(3:4)/pilot.Scale;
end
function v=clamp(v,low,high)
v=max(low,min(high,double(v)));
end
function v=robustNoise(x)
v=1.4826*median(abs(double(x)-median(double(x))));
end
function q=quantileLocal(x,p)
x=sort(double(x(:))); at=1+(numel(x)-1)*p;
q=x(floor(at))+(at-floor(at))*(x(ceil(at))-x(floor(at)));
end

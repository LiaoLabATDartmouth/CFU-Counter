function result=measure_colony_features(result,rejectArtifacts)
%MEASURE_COLONY_FEATURES Pixel-level color and morphology of each object.
% Local color differences are relative to an annulus that excludes other
% detected/rejected objects, pixels outside the ROI, and dark printed ink.
if nargin<2, rejectArtifacts=true; end
T=result.Colonies; I=result.Image; lab=rgb2lab(I); hsv=rgb2hsv(I);
L=lab(:,:,1); A=lab(:,:,2); B=lab(:,:,3); saturation=hsv(:,:,2);
plateDiameter=2*sqrt(prod(result.CountingEllipseWork(3:4)));
logRGB=log(max(rgb2lin(I),1e-5));
logRG=logRGB(:,:,1)-logRGB(:,:,2); logBG=logRGB(:,:,3)-logRGB(:,:,2);
logBrightness=mean(logRGB,3);
G=sqrt(imgradient(imgaussfilt(logRG,0.7)).^2+ ...
    imgradient(imgaussfilt(logBG,0.7)).^2+imgradient(imgaussfilt(logBrightness,0.7)).^2);
G=G*plateDiameter/1200; % Approximately compensate for image sampling scale
newNames={'MedianSaturation','LocalDeltaA','LocalDeltaL','LocalDeltaB', ...
    'ColorDeltaE','PinkPixelFraction','TextureL','BoundaryGradient', ...
    'EdgeDensity','BoundaryRoughness','EnclosingRadiusPixels','BackgroundPixels', ...
    'LocalLogRG','LocalLogBG','LocalLogBrightness','LogColorDistance','LocalLogPink', ...
    'LocalLogRed','LocalPinkNoise','LocalRedNoise','CoreLocalLogPink','CoreLocalLogRed', ...
    'CleanSignalCoreFraction'};
for name=newNames, T.(name{1})=nan(height(T),1); end
objects=result.Labels>0 | result.RejectedMask;
for i=1:height(T)
    [yy,xx]=find(result.Labels==T.ID(i));
    if isempty(xx), continue; end
    radius=T.DiameterPixels(i)*result.Scale/2;
    center=([T.X(i),T.Y(i)]-0.5)*result.Scale+0.5;
    T.EnclosingRadiusPixels(i)=(max(hypot(xx-center(1),yy-center(2)))+2)/result.Scale;
    % Enlarge the sampling window when lettering or crowding leaves too
    % little clean agar immediately beside the object. Prefer the nearest
    % usable annulus so gradual illumination changes remain local.
    padding=max(8,ceil(radius*4));
    xs=max(1,min(xx)-padding):min(size(I,2),max(xx)+padding);
    ys=max(1,min(yy)-padding):min(size(I,1),max(yy)+padding);
    object=result.Labels(ys,xs)==T.ID(i);
    localA=A(ys,xs); T.MedianLabA(i)=median(localA(object));
    available=~objects(ys,xs) & result.ROI(ys,xs) & ~result.InkMask(ys,xs);
    for fraction=[0.7 1.2 2 4]
        ring=imdilate(object,strel('disk',max(3,ceil(radius*fraction)),0)) & available;
        if nnz(ring)>=30, break; end
    end
    localA=A(ys,xs); localL=L(ys,xs); localB=B(ys,xs); localS=saturation(ys,xs);
    T.BackgroundPixels(i)=nnz(ring);
    if nnz(ring)<10
        T.NeedsReview(i)=true;
        T.ReviewReason(i)=appendReason(T.ReviewReason(i),"insufficient_local_background");
        continue
    end
    bg=[median(localL(ring)),median(localA(ring)),median(localB(ring))];
    pixelDelta=[localL(object)-bg(1),localA(object)-bg(2),localB(object)-bg(3)];
    T.MedianSaturation(i)=median(localS(object));
    T.LocalDeltaA(i)=median(pixelDelta(:,2));
    T.LocalDeltaL(i)=median(pixelDelta(:,1));
    T.LocalDeltaB(i)=median(pixelDelta(:,3));
    T.ColorDeltaE(i)=median(sqrt(sum(pixelDelta.^2,2)));
    lr=logRG(ys,xs); lb=logBG(ys,xs); light=logBrightness(ys,xs);
    T.LocalLogRG(i)=median(lr(object))-median(lr(ring));
    T.LocalLogBG(i)=median(lb(object))-median(lb(ring));
    T.LocalLogBrightness(i)=median(light(object))-median(light(ring));
    pink=lr+lb;
    T.LocalLogPink(i)=median(pink(object))-median(pink(ring));
    red=logRGB(ys,xs,1);
    T.LocalLogRed(i)=median(red(object))-median(red(ring));
    T.LocalPinkNoise(i)=1.4826*median(abs(pink(ring)-median(pink(ring))));
    T.LocalRedNoise(i)=1.4826*median(abs(red(ring)-median(red(ring))));
    T.PinkPixelFraction(i)=mean(pink(object)-median(pink(ring))>0.30);
    delta=zeros(nnz(object),3);
    for c=1:3
        channel=logRGB(ys,xs,c);
        delta(:,c)=channel(object)-median(channel(ring));
    end
    T.LogColorDistance(i)=median(sqrt(sum(delta.^2,2)));
    core=imerode(object,strel('disk',max(1,round(radius*0.2)),0));
    if nnz(core)<5, core=object; end
    cleanCore=core & ~result.InkMask(ys,xs);
    T.CleanSignalCoreFraction(i)=nnz(cleanCore)/max(1,nnz(core));
    if nnz(cleanCore)>=max(5,.4*nnz(core))
        T.CoreLocalLogPink(i)=median(pink(cleanCore))-median(pink(ring));
        T.CoreLocalLogRed(i)=median(red(cleanCore))-median(red(ring));
    end
    T.TextureL(i)=median(abs(light(core)-median(light(core))));
    gradient=G(ys,xs);
    T.BoundaryGradient(i)=median(gradient(bwperim(object)));
    backgroundGradient=gradient(ring);
    edgeThreshold=median(backgroundGradient)+3*1.4826*median(abs(backgroundGradient-median(backgroundGradient)));
    T.EdgeDensity(i)=mean(gradient(object)>max(edgeThreshold,0.03));
    T.BoundaryRoughness(i)=1/sqrt(max(T.Circularity(i),eps));
end
% Gaussian background subtraction can create halos around dark lettering.
% Require an actual color difference from nearby unoccupied agar pixels.
colorDifference=T.LocalLogPink>=result.Options.MinLocalPinkDifference;
paleDifference=T.LocalLogBrightness>=0.6*result.Options.PaleBrightnessThreshold & T.LocalLogPink>-0.10;
reject=rejectArtifacts & isfinite(T.LocalLogPink) & ~(colorDifference | paleDifference);
if result.Options.ArtifactFilterStrength>0
    % A pink halo around black ink is not a bright colony. Conversely, a
    % reflection can be bright without a localized pink signal. Evaluate
    % both channels, using annular variation at the rim to avoid accepting
    % the plate's pink plastic as a colony. Strong pink objects may be darker
    % than the background beside a glare streak and remain eligible.
    strength=result.Options.ArtifactFilterStrength;
    p=T.CoreLocalLogPink; red=T.CoreLocalLogRed;
    strongPink=p>=0.35*strength & p>=1.5*strength*T.LocalPinkNoise;
    pink=colorDifference & p>=0.04*strength & (T.LocalLogRed>=1.5*strength*result.Options.RedContrastThreshold | ...
        red>=1.5*strength*result.Options.RedContrastThreshold | strongPink);
    pale=paleDifference & T.LocalLogRed>=0.12*strength & p>=max(0.01,0.25*strength*T.LocalPinkNoise) & ...
        T.Solidity>=0.85 & T.Circularity>=0.65;
    supported=pink | pale;
    nearInk=contains(T.ReviewReason,"near_ink");
    nearRim=contains(T.ReviewReason,"near_rim");
    if ismember('DetectionNotes',T.Properties.VariableNames)
        nearInk=contains(T.DetectionNotes,"near_ink");
        nearRim=contains(T.DetectionNotes,"near_rim");
    end
    inkOK=p>=0.20*strength | (red>=0.30*strength & p>=0.04*strength & T.Solidity>=0.85);
    rimOK=(p>=0.30*strength & p>=1.5*strength*T.LocalPinkNoise) | ...
        (pale & p>=0.07*strength & T.Circularity>=0.90 & T.Solidity>=0.90);
    supported=supported & (~nearInk | inkOK) & (~nearRim | rimOK);
    weakIrregular=(T.Solidity<0.85 | T.Circularity<0.62) & ...
        p<0.15*strength & red<0.15*strength;
    supported=supported & ~weakIrregular;
    % An obscured core alone is insufficient evidence to discard an object.
    % Retain strong whole-object evidence for review in that situation.
    obscured=~isfinite(p) & (T.LocalLogPink>=0.20*strength | ...
        (T.LocalLogPink>=0.04*strength & T.LocalLogRed>=0.15*strength));
    supported=supported | obscured;
    reject=rejectArtifacts & isfinite(T.LocalLogPink) & ~supported;
end
for i=find(reject)'
    pixels=result.Labels==T.ID(i);
    result.RejectedMask=result.RejectedMask | pixels;
    result.Labels(pixels)=0;
    result.Rejected(end+1,:)={T.X(i),T.Y(i),T.AreaPixels(i),T.DiameterPixels(i),"insufficient_local_colony_signal"};
end
T(reject,:)=[];
result.Colonies=T;
end

function text=appendReason(text,reason)
if strlength(text)>0, text=text+";"; end
text=text+reason;
end

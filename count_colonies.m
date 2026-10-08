function result = count_colonies(imageFile, overrides)
%COUNT_COLONIES Detect pink colonies; classify AD9/AD24 by composite features.
% result = count_colonies(imageFile)
% opts = colony_defaults(); opts.DiameterThresholdPixels = 45;
% result = count_colonies(imageFile, opts)
%
% Requires MATLAB R2021a+ and Image Processing Toolbox. Classification
% uses size, color, shape and boundary features, NOT species identification.
% Inspect the overlay and review flagged/merged/missed colonies before use.
if nargin < 2, overrides = struct(); end
opts = colony_defaults();
names = fieldnames(overrides);
for k = 1:numel(names)
    if ~isfield(opts,names{k})
        error('CFU:UnknownOption','Unknown option: %s',names{k});
    end
    opts.(names{k}) = overrides.(names{k});
end
validateOptions(opts);
if exist('rgb2lab','file') ~= 2
    error('CFU:MissingToolbox','Image Processing Toolbox is required.');
end
[original,imageInfo] = read_plate_image(imageFile);
scale = min(1,opts.MaxImageDimension/max(size(original,1),size(original,2)));
I = im2single(imresize(original,scale));
lab = rgb2lab(I); A = lab(:,:,2); L = lab(:,:,1);
[x,y] = meshgrid(1:size(I,2),1:size(I,1));

if isempty(opts.PlateEllipse)
    % The largest pink, reasonably bright region is the plate. This heuristic
    % is intended for one plate on a dark background, as in the example.
    plate = A > 10 & L > 28;
    plate = imclose(plate,strel('disk',max(2,round(8*size(I,1)/1800)),0));
    if ~any(plate(:)), error('CFU:NoPlate','No plate found; set opts.PlateEllipse.'); end
    plate = imfill(bwareafilt(plate,1),'holes');
    p = regionprops(plate,'Centroid','MajorAxisLength','MinorAxisLength','Orientation');
    if nnz(plate) < 0.08*numel(plate) || p.MinorAxisLength/p.MajorAxisLength < 0.5
        error('CFU:NoPlate','Plate detection is unreliable; use select_plate_roi.');
    end
    ellipse = [p.Centroid, opts.PlateInset*[p.MajorAxisLength p.MinorAxisLength]/2, p.Orientation];
    roiSource = "automatic";
else
    ellipse = opts.PlateEllipse;
    ellipse(1:2) = (ellipse(1:2)-0.5)*scale+0.5;
    ellipse(3:4) = ellipse(3:4)*scale;
    roiSource = "user-specified";
end
angle = deg2rad(ellipse(5)); dx = x-ellipse(1); dy = y-ellipse(2);
u = dx*cos(angle)-dy*sin(angle); v = dx*sin(angle)+dy*cos(angle);
radial = sqrt((u/ellipse(3)).^2+(v/ellipse(4)).^2);
roi = radial <= 1;
if nnz(roi)<100, error('CFU:EmptyROI','Counting ellipse does not overlap the image.'); end
diameter = 2*sqrt(ellipse(3)*ellipse(4));
sigma = max(3,opts.BackgroundSigmaFraction*diameter);
smoothSigma = max(0.5,0.0006*diameter);
% Normalize the background by ROI support: the dark tabletop outside the
% counting boundary must not make the entire plate edge look like a colony.
support=max(imgaussfilt(single(roi),sigma),eps('single'));
linear=rgb2lin(I); localLog=zeros(size(I),'single');
for c=1:3
    ch=linear(:,:,c);
    background=imgaussfilt(ch.*single(roi),sigma)./support;
    localLog(:,:,c)=log(max(imgaussfilt(ch,smoothSigma),1e-5)./max(background,1e-5));
end
% Multiplicative exposure and channel gains cancel in these local ratios
% (except clipping, sensor noise, and spatially abrupt illumination changes).
pinkContrast=localLog(:,:,1)+localLog(:,:,3)-2*localLog(:,:,2);
redContrast=localLog(:,:,1);
colored=pinkContrast>opts.PinkContrastThreshold & ...
    (redContrast>opts.RedContrastThreshold | (pinkContrast>0.40 & redContrast>-0.30));
pale=mean(localLog,3)>opts.PaleBrightnessThreshold & pinkContrast>-0.10;
foreground=(colored | pale) & roi;
minArea = pi*(opts.MinDiameterFraction*diameter/2)^2;
maxArea = pi*(opts.MaxDiameterFraction*diameter/2)^2;
foreground = imclose(foreground,strel('disk',1,0)) & roi;
% Fill colony-scale holes only. A continuous bright plate rim must not fill
% the entire agar interior and turn it into a single giant candidate.
holes=imfill(foreground,'holes') & ~foreground;
foreground=foreground | bwareafilt(holes,[1 ceil(maxArea)]);
foreground = bwareaopen(foreground,max(1,ceil(minArea)));

% Split touching objects at distance-map saddles. Keep each watershed label
% distinct, including diagonal contact between neighboring segments.
distance = imgaussfilt(bwdist(~foreground),smoothSigma);
distance(~foreground) = 0;
seeds = imextendedmax(distance,max(0.4,opts.WatershedPeakFraction*diameter)) & foreground;
if any(foreground(:))
    W = watershed(imimposemin(-distance,seeds | ~foreground));
    foreground(W==0) = false;
end
components = bwconncomp(foreground);
stats = regionprops(components,'Area','Centroid','EquivDiameter','Eccentricity', ...
    'Solidity','Perimeter','PixelIdxList');
labels = zeros(size(roi),'uint16'); rejectedMask = false(size(roi));
T = emptyColonyTable(); rejected = table('Size',[0 5], ...
    'VariableTypes',{'double','double','double','double','string'}, ...
    'VariableNames',{'X','Y','AreaPixels','DiameterPixels','Reason'});
if isempty(opts.DiameterThresholdPixels)
    threshold = opts.SizeThresholdFraction*diameter;
else
    threshold = opts.DiameterThresholdPixels*scale;
end
ink = localLog(:,:,1)<-0.5 & localLog(:,:,2)<-0.5;
ink = imdilate(ink,strel('disk',max(2,round(0.003*diameter)),0));
roiDistance = bwdist(~roi);
for k = 1:numel(stats)
    s = stats(k); pix = s.PixelIdxList;
    circularity = min(1,4*pi*s.Area/max(s.Perimeter^2,eps));
    xy = (s.Centroid-0.5)/scale+0.5;
    rejection = strings(0,1);
    if s.Area<minArea, rejection(end+1)="too_small"; end
    if s.Area>maxArea, rejection(end+1)="too_large_or_confluent"; end
    if s.Eccentricity>opts.MaxEccentricity, rejection(end+1)="elongated"; end
    if s.Solidity<opts.MinSolidity, rejection(end+1)="irregular"; end
    if circularity<opts.MinCircularity, rejection(end+1)="low_circularity"; end
    if ~isempty(rejection)
        rejectedMask(pix) = true;
        rejected(end+1,:) = {xy(1),xy(2),s.Area/scale^2,s.EquivDiameter/scale,strjoin(rejection,";")}; %#ok<AGROW>
        continue
    end
    % Class sizes refer to the segmented colony, not any surrounding halo.
    colonyClass = "AD9";
    if s.EquivDiameter >= threshold, colonyClass = "AD24"; end
    reasons = strings(0,1);
    if abs(s.EquivDiameter-threshold)<=opts.SizeReviewFraction*threshold
        reasons(end+1)="near_size_cutoff";
    end
    if any(radial(pix)>opts.EdgeReviewFraction), reasons(end+1)="near_rim"; end
    if any(roiDistance(pix)<=1), reasons(end+1)="touches_counting_boundary"; end
    if any(ink(pix)), reasons(end+1)="near_ink_or_shadow"; end
    if s.Solidity<0.85 || circularity<0.62
        reasons(end+1)="possible_merge_or_artifact";
    end
    contrast90 = percentile(pinkContrast(pix),0.9);
    if contrast90<2*opts.PinkContrastThreshold, reasons(end+1)="faint"; end
    id = height(T)+1;
    labels(pix) = id;
    T(end+1,:) = {id,xy(1),xy(2),s.Area/scale^2,s.EquivDiameter/scale, ...
        s.EquivDiameter/diameter,circularity,s.Solidity,s.Eccentricity, ...
        median(A(pix)),contrast90,colonyClass,~isempty(reasons), ...
        strjoin(reasons,";"),false,"automatic"}; %#ok<AGROW>
end
result = struct('ImageFile',string(imageFile),'Options',opts,'Image',I, ...
    'ROI',roi,'Labels',labels,'RejectedMask',rejectedMask,'InkMask',ink,'Colonies',T, ...
    'Rejected',rejected,'Scale',scale,'CountingEllipseWork',ellipse, ...
    'ROISource',roiSource,'DiameterThresholdPixels',threshold/scale, ...
    'OriginalImageSize',size(original),'ReviewLog',strings(0,1));
result.ImageInfo=imageInfo;
result=measure_colony_features(result);
result.Colonies.DetectionNotes=result.Colonies.ReviewReason;
result=classify_colonies(result);
result=refine_touching_colonies(result);
result=update_colony_warnings(result);
result=resolve_colony_classification(result);
result.Summary = summarize_colonies(result);
end

function T = emptyColonyTable()
names = {'ID','X','Y','AreaPixels','DiameterPixels','DiameterFraction', ...
    'Circularity','Solidity','Eccentricity','MedianLabA','PinkContrast90', ...
    'Class','NeedsReview','ReviewReason','Reviewed','Source'};
types = [repmat({'double'},1,11),{'string','logical','string','logical','string'}];
T = table('Size',[0 numel(names)],'VariableTypes',types,'VariableNames',names);
end

function q = percentile(values,fraction)
% Avoid a Statistics and Machine Learning Toolbox dependency.
values = sort(values); q = double(values(max(1,ceil(fraction*numel(values)))));
end

function validateOptions(o)
fields = {'MaxImageDimension','MinDiameterFraction','MaxDiameterFraction', ...
    'BackgroundSigmaFraction','PinkContrastThreshold','RedContrastThreshold', ...
    'WatershedPeakFraction','SizeThresholdFraction','MinLocalPinkDifference','PaleBrightnessThreshold'};
for k=1:numel(fields)
    validateattributes(o.(fields{k}),{'numeric'},{'scalar','real','finite','positive'},mfilename,fields{k});
end
fields = {'PlateInset','MaxEccentricity','MinSolidity','MinCircularity','SizeReviewFraction','EdgeReviewFraction'};
for k=1:numel(fields)
    validateattributes(o.(fields{k}),{'numeric'},{'scalar','real','finite','>',0,'<=',1},mfilename,fields{k});
end
if o.MaxDiameterFraction<=o.MinDiameterFraction
    error('CFU:InvalidOptions','MaxDiameterFraction must exceed MinDiameterFraction.');
end
if ~isempty(o.PlateEllipse)
    validateattributes(o.PlateEllipse,{'numeric'},{'vector','numel',5,'real','finite'});
    if any(o.PlateEllipse(3:4)<=0), error('CFU:InvalidOptions','Ellipse radii must be positive.'); end
end
if ~isempty(o.DiameterThresholdPixels)
    validateattributes(o.DiameterThresholdPixels,{'numeric'},{'scalar','real','finite','positive'});
end
if ~ismember(string(o.ClassifierMode),["size","composite"])
    error('CFU:InvalidOptions','ClassifierMode must be size or composite.');
end
validateattributes(o.ShrinkageCandidates,{'numeric'},{'vector','real','finite','>',0,'<=',1});
validateattributes(o.CompositeReviewMargin,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(o.ArtifactFilterStrength,{'numeric'},{'scalar','real','finite','>=',0,'<=',2});
validateattributes(o.SplitTouchingColonies,{'logical','numeric'},{'scalar','binary'});
validateattributes(o.ResolveAmbiguousClassification,{'logical','numeric'},{'scalar','binary'});
validateattributes(o.ResolverBootstrapSamples,{'numeric'},{'scalar','integer','>=',20});
end

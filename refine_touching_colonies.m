function result=refine_touching_colonies(result)
%REFINE_TOUCHING_COLONIES Split mixed lobes while preserving all outer pixels.
% Existing IDs are retained for the main child; new IDs identify satellites.
% The original classifier is frozen, so unrelated colony assignments do not
% change merely because a few regions were subdivided.
if ~isfield(result.Options,'SplitTouchingColonies')
    result.Options.SplitTouchingColonies=true;
end
T=result.Colonies;
result.OriginalLabels=result.Labels;
result.OriginalColonies=T;
T.ParentID=T.ID; T.SplitStatus=repmat("not_split",height(T),1);
if ~ismember('DetectionNotes',T.Properties.VariableNames), T.DetectionNotes=T.ReviewReason; end
result.Colonies=T;
result.SplitLog=table('Size',[0 6],'VariableTypes',{'double','double','double','double','double','string'}, ...
    'VariableNames',{'ParentID','MainID','SatelliteID','ColorDifference','CenterDistanceWork','Reason'});
if ~result.Options.SplitTouchingColonies || isempty(T), return; end
eligible=T.Class=="AD9" & isfinite(T.DiameterPixels) & T.Solidity>0.85;
if nnz(eligible)<3, return; end
smallRadius=median(T.DiameterPixels(eligible))*result.Scale/2;
large=T.Class=="AD24" & isfinite(T.LocalLogPink);
if nnz(large)<2, return; end
lowColor=median(T.LocalLogPink(eligible)); highColor=median(T.LocalLogPink(large));
if highColor-lowColor<0.20, return; end
colorCutoff=(lowColor+highColor)/2;
logs=log(max(rgb2lin(result.Image),1e-5));
pink=logs(:,:,1)+logs(:,:,3)-2*logs(:,:,2);
model=result.ClassifierModel; nextID=max(T.ID)+1;
for i=1:height(result.OriginalColonies)
    parent=result.OriginalColonies(i,:);
    if parent.DiameterPixels<0.85*result.DiameterThresholdPixels, continue; end
    [yy,xx]=find(result.OriginalLabels==parent.ID);
    padding=max(5,ceil(smallRadius));
    xs=max(1,min(xx)-padding):min(size(pink,2),max(xx)+padding);
    ys=max(1,min(yy)-padding):min(size(pink,1),max(yy)+padding);
    mask=result.OriginalLabels(ys,xs)==parent.ID;
    % Use the already measured local-background contrast to remove the
    % background offset from every pixel in this original region.
    color=pink(ys,xs);
    background=median(color(mask))-parent.LocalLogPink;
    [parts,info]=split_mixed_region(mask,color-background,smallRadius,colorCutoff);
    if info.Candidate && ~info.Accepted
        T.DetectionNotes(i)=T.DetectionNotes(i)+";unresolved_internal_lobes";
    end
    if ~info.Accepted, continue; end
    patch=result.Labels(ys,xs);
    patch(parts==1)=parent.ID; patch(parts==2)=nextID;
    result.Labels(ys,xs)=patch;
    T(i,:)=geometryRow(T(i,:),parts==1,xs,ys,result);
    T.SplitStatus(i)="main_child";
    child=geometryRow(T(i,:),parts==2,xs,ys,result);
    child.ID=nextID; child.ParentID=parent.ID; child.SplitStatus="satellite_child";
    T=[T;child]; %#ok<AGROW>
    result.SplitLog(end+1,:)={parent.ID,parent.ID,nextID,info.ColorDifference,info.CenterDistance,info.Reason};
    nextID=nextID+1;
end
result.Colonies=T; result.NextID=nextID;
if ~isempty(result.SplitLog)
    result=measure_colony_features(result,false);
    originalModel=result.Options.ClassifierModel;
    result.Options.ClassifierModel=model;
    result=classify_colonies(result);
    result.Options.ClassifierModel=originalModel;
end
assert(isequal(result.Labels>0,result.OriginalLabels>0),'CFU:BoundaryChanged', ...
    'Refinement must preserve every accepted foreground pixel.');
end

function row=geometryRow(row,mask,xs,ys,result)
s=regionprops(mask,'Area','Centroid','EquivDiameter','Solidity','Eccentricity','Perimeter');
center=s.Centroid+[xs(1)-1,ys(1)-1];
xy=(center-0.5)/result.Scale+0.5;
row.X=xy(1); row.Y=xy(2); row.AreaPixels=s.Area/result.Scale^2;
row.DiameterPixels=s.EquivDiameter/result.Scale;
row.DiameterFraction=s.EquivDiameter/(2*sqrt(prod(result.CountingEllipseWork(3:4))));
row.Circularity=min(1,4*pi*s.Area/max(s.Perimeter^2,eps));
row.Solidity=s.Solidity; row.Eccentricity=s.Eccentricity;
row.Reviewed=false; row.Source="automatic";
end

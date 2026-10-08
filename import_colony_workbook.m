function result=import_colony_workbook(workbook,imageFile)
%IMPORT_COLONY_WORKBOOK Recover annotations from exports predating sessions.
% Reuse the existing detector only to recover matching region geometry. Saved
% labels, IDs and circles are authoritative; unmatched rows become manual marks.
T=readtable(workbook,'Sheet','Colonies','TextType','string');
required={'ID','Label','X','Y','EnclosingRadiusPixels','DiameterPixels'};
if ismember('Label',T.Properties.VariableNames), T.Label=string(T.Label); end
if ~all(ismember(required,T.Properties.VariableNames)) || ...
        any(~ismember(T.Label,["AD9","AD24","Need review","Not a colony"]))
    error('CFU:InvalidWorkbook','Choose a Colony Counter results workbook.');
end
if numel(unique(T.ID))~=height(T) || any(~isfinite(T.ID) | T.ID<1 | T.ID~=floor(T.ID) | T.ID>65535) || ...
        any(~isfinite(T.X) | ~isfinite(T.Y))
    error('CFU:InvalidWorkbook','Saved IDs or positions are invalid.');
end
metadata=readcell(workbook,'Sheet','Summary','Range','A9:B28');
name=string(metadata{1,2});
if nargin<2 || strlength(string(imageFile))==0
    candidates=[string(fullfile(fileparts(workbook),name)), ...
        string(fullfile(fileparts(mfilename('fullpath')),'Examples',name))];
    found=find(isfile(candidates),1);
    if isempty(found)
        error('CFU:OriginalImageRequired','Select the original photo for this older workbook: %s',name);
    end
    imageFile=candidates(found);
end
opts=colony_defaults();
keys={'Minimum diameter (% of plate)','MinDiameterFraction',.01; ...
    'Separation peak (% of plate)','WatershedPeakFraction',.01; ...
    'Ink / reflection rejection','ArtifactFilterStrength',1; ...
    'Processing image size (pixels)','MaxImageDimension',1; ...
    'AD9 / AD24 size reference (%)','SizeThresholdFraction',.01; ...
    'Pink color threshold','PinkContrastThreshold',1; ...
    'Pale colony threshold','PaleBrightnessThreshold',1; ...
    'Review sensitivity','CompositeReviewMargin',1; ...
    'Size review margin (%)','SizeReviewFraction',.01; ...
    'Maximum diameter (% of plate)','MaxDiameterFraction',.01; ...
    'Background scale (% of plate)','BackgroundSigmaFraction',.01};
for n=1:size(metadata,1)
    key=metadata{n,1};
    if ~(ischar(key) || isstring(key)), continue; end
    match=find(strcmp(key,keys(:,1)),1);
    if ~isempty(match)
        value=metadata{n,2};
        if isnumeric(value) && isscalar(value) && isfinite(value)
            opts.(keys{match,2})=value*keys{match,3};
        end
    elseif strcmp(key,'Counting ellipse (original pixels)')
        text=char(string(metadata{n,2}));
        if isempty(regexp(text,'^\[[0-9eE+.,; \-]+\]$','once'))
            error('CFU:InvalidWorkbook','Invalid saved plate boundary.');
        end
        nums=regexp(text,'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?','match');
        ellipse=str2double(nums);
        if numel(ellipse)~=5 || any(~isfinite(ellipse)) || any(ellipse(3:4)<=0)
            error('CFU:InvalidWorkbook','Invalid saved plate boundary.');
        end
        opts.PlateEllipse=ellipse;
    end
end
result=count_colonies(imageFile,opts); result=prepare_colony_app_result(result);
original=result.Colonies; oldLabels=result.Labels; newLabels=zeros(size(oldLabels),'like',oldLabels);
restored=original([],:); used=false(height(original),1);
for n=1:height(T)
    distances=hypot(original.X-T.X(n),original.Y-T.Y(n)); distances(used)=Inf;
    [distance,row]=min(distances);
    matched=~isempty(row) && distance<0.05 && ...
        abs(original.EnclosingRadiusPixels(row)-T.EnclosingRadiusPixels(n))<0.1;
    if matched
        current=original(row,:); used(row)=true;
        newLabels(oldLabels==current.ID)=T.ID(n);
    else
        current=blankRow(original);
        current.Source="manual_add"; current.ClassifierBasis="manual";
        current.ReviewReason="imported_annotation";
    end
    current.ID=T.ID(n); current.X=T.X(n); current.Y=T.Y(n);
    current.DiameterPixels=T.DiameterPixels(n); current.EnclosingRadiusPixels=T.EnclosingRadiusPixels(n);
    current.Class=T.Label(n); if current.Class=="Need review", current.Class="Uncertain"; end
    current.NeedsReview=current.Class=="Uncertain"; current.Reviewed=true;
    if ismember('OriginalSuggestion',T.Properties.VariableNames)
        current.SuggestedClass=T.OriginalSuggestion(n);
    end
    if ~ismember('MarkerRadiusPixels',current.Properties.VariableNames), current.MarkerRadiusPixels=NaN; end
    if ~ismember('MarkerRadiusPixels',restored.Properties.VariableNames), restored.MarkerRadiusPixels=zeros(0,1); end
    if ismember('MarkerRadiusPixels',T.Properties.VariableNames) && isfinite(T.MarkerRadiusPixels(n))
        current.MarkerRadiusPixels=T.MarkerRadiusPixels(n);
    elseif ~matched
        current.MarkerRadiusPixels=max(3/result.Scale,T.EnclosingRadiusPixels(n));
    end
    % The old export has no archived parent mask: do not invent Undo history.
    restored=[restored;current]; %#ok<AGROW>
end
result.Colonies=restored; result.Labels=newLabels; result.NextID=max([0;T.ID])+1;
if isfield(result,'ManualGroups'), result=rmfield(result,'ManualGroups'); end
result.ReviewLog(end+1,1)="Imported saved labels and circles from an older workbook; full original session unavailable.";
result.Summary=summarize_colonies(result);
end

function row=blankRow(T)
values=cell(1,width(T));
for n=1:width(T)
    column=T.(T.Properties.VariableNames{n});
    if islogical(column), values{n}=false;
    elseif isnumeric(column), values{n}=NaN;
    else, values{n}="";
    end
end
row=cell2table(values,'VariableNames',T.Properties.VariableNames);
end

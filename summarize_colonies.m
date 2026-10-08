function summary = summarize_colonies(result)
%SUMMARIZE_COLONIES Recompute counts after automatic analysis or manual edits.
T = result.Colonies;
included=T.Class~="Not a colony";
[~,name,ext] = fileparts(result.ImageFile);
summary = table(string(name)+string(ext),sum(included),sum(T.Class=="AD9"), ...
    sum(T.Class=="AD24"),sum(T.Class=="Uncertain"),sum(T.NeedsReview), ...
    sum(T.Reviewed),height(result.Rejected),result.DiameterThresholdPixels, ...
    string(result.ROISource),'VariableNames',{'Image','Total','AD9','AD24', ...
    'Uncertain','FlaggedForReview','ManuallyReviewed','RejectedObjects', ...
    'SizeCutoffPixels','ROISource'});
summary.DetectedObjects=height(T);
summary.NotAColony=sum(~included);
summary.Classifier=string(result.Options.ClassifierMode);
if isfield(result,'ClassificationInfo'), summary.Classifier=result.ClassificationInfo.Mode; end
summary.WeakCompositeAssignments=sum(included & T.SeparationMargin<result.Options.CompositeReviewMargin);
summary.CompositeSizeDisagreements=sum(included & T.AutomaticClass~=T.SizeOnlyClass & T.Source=="automatic");
if ismember('MergeWarning',T.Properties.VariableNames)
    summary.MergeWarnings=sum(T.MergeWarning);
    summary.ClassificationWarnings=sum(T.ClassificationWarning);
end
if isfield(result,'SplitLog')
    summary.RegionsSplit=height(result.SplitLog);
end
if ismember('ResolutionAccepted',T.Properties.VariableNames)
    summary.ClassificationsCorroborated=sum(T.ResolutionAccepted);
end
end

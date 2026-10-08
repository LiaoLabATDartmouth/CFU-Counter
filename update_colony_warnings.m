function result=update_colony_warnings(result)
%UPDATE_COLONY_WARNINGS Exactly two user-facing warning categories.
T=result.Colonies;
if ~ismember('DetectionNotes',T.Properties.VariableNames), T.DetectionNotes=T.ReviewReason; end
if ~ismember('SplitStatus',T.Properties.VariableNames), T.SplitStatus=repmat("not_split",height(T),1); end
[features,~,~,~]=colony_feature_matrix(T);
unresolved=contains(T.DetectionNotes,"unresolved_internal_lobes");
% Large, round, single colonies are not merges merely because they exceed
% the AD9/AD24 size reference. Require an irregular shape or internal lobes.
shape=T.Solidity<0.85 | T.Circularity<0.62;
T.MergeWarning=shape | unresolved;
T.ClassificationWarning=~all(isfinite(features),2) | T.Class=="Uncertain";
if string(result.Options.ClassifierMode)=="composite"
    weak=~isfinite(T.FisherScore) | abs(T.FisherScore)<result.Options.CompositeReviewMargin;
    if ismember('SizeFallbackUsed',T.Properties.VariableNames)
        fallback=T.SizeFallbackUsed;
        % Missing two-class references alone need not make every object
        % uncertain. Size-only calls need a clear pink signal, usable local
        % background, separation from the size cutoff and no ink/rim overlap.
        % Keep the existing merge warning and exactly two warning categories.
        obscured=contains(T.DetectionNotes,"near_ink") | ...
            contains(T.DetectionNotes,"near_rim") | ...
            contains(T.DetectionNotes,"touches_counting_boundary");
        if ismember('CleanSignalCoreFraction',T.Properties.VariableNames)
            clearCore=T.CleanSignalCoreFraction>=0.6 & ...
                T.CoreLocalLogPink>=max(0.30,2*T.LocalPinkNoise) & ...
                T.BackgroundPixels>=30 & T.Solidity>=0.90 & T.Circularity>=0.80;
            obscured=obscured & ~clearCore;
            obscured=obscured | contains(T.DetectionNotes,"touches_counting_boundary");
        end
        colorOK=T.LocalLogPink>=max(result.Options.MinLocalPinkDifference, ...
            2*result.Options.PinkContrastThreshold) & T.BackgroundPixels>=30;
        nearCutoff=abs(T.DiameterPixels-result.DiameterThresholdPixels)<= ...
            result.Options.SizeReviewFraction*result.DiameterThresholdPixels;
        weak(fallback)=nearCutoff(fallback) | obscured(fallback) | ~colorOK(fallback);
    end
    T.ClassificationWarning=T.ClassificationWarning | weak;
else
    T.ClassificationWarning=T.ClassificationWarning | ...
        abs(T.DiameterPixels-result.DiameterThresholdPixels)<= ...
        result.Options.SizeReviewFraction*result.DiameterThresholdPixels;
end
if ismember('ResolutionAccepted',T.Properties.VariableNames)
    T.ClassificationWarning=T.ClassificationWarning & ~T.ResolutionAccepted;
end
% A reviewed decision is resolved unless the reviewer explicitly chose Uncertain.
included=T.Class~="Not a colony";
T.MergeWarning=T.MergeWarning & ~T.Reviewed & included;
T.ClassificationWarning=((T.ClassificationWarning & ~T.Reviewed) | T.Class=="Uncertain") & included;
T.ReviewReason=repmat("",height(T),1);
for i=1:height(T)
    reasons=strings(0,1);
    if T.MergeWarning(i), reasons(end+1)="shape suggests a merged object or two colonies"; end
    if T.ClassificationWarning(i), reasons(end+1)="unclear classification or insufficient features"; end
    T.ReviewReason(i)=strjoin(reasons,";");
end
T.NeedsReview=T.MergeWarning | T.ClassificationWarning;
result.Colonies=T;
end

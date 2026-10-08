function result=resolve_colony_classification(result)
%RESOLVE_COLONY_CLASSIFICATION Corroborate weak classifications; keep all masks.
% The primary assignment is retained. A warning is cleared only if interior
% color agrees, its bootstrap interval excludes zero, its margin is sufficient,
% and the object lies within the reference population's feature coverage.
defaults=colony_defaults();
for name={'ResolveAmbiguousClassification','ClassificationResolverModel','ResolverBootstrapSamples'}
    if ~isfield(result.Options,name{1}), result.Options.(name{1})=defaults.(name{1}); end
end
T=result.Colonies; n=height(T); T.ResolutionAccepted=false(n,1);
result.Colonies=T; result=update_colony_warnings(result); T=result.Colonies;
T.ClassificationWarningBeforeResolution=T.ClassificationWarning;
T.ResolutionAccepted=false(n,1); T.ResolutionScore=nan(n,1);
T.ResolutionScoreLow=nan(n,1); T.ResolutionScoreHigh=nan(n,1);
T.ResolutionAgreement=nan(n,1); T.ResolutionReferenceDistance=nan(n,1);
T.ResolutionReferenceLimit=nan(n,1); T.ResolutionReferenceIDs=repmat("",n,1);
T.ResolutionReason=repmat("not_requested",n,1); result.Colonies=T;
result.ClassificationResolverModel=struct('Ready',false);
if ~result.Options.ResolveAmbiguousClassification || string(result.Options.ClassifierMode)~="composite"
    T.ResolutionReason(T.ClassificationWarning)="disabled"; result.Colonies=T;
    result.Summary=summarize_colonies(result); return
end
result=measure_resolution_features(result); T=result.Colonies;
if isempty(result.Options.ClassificationResolverModel)
    if ~isempty(result.Options.ClassifierModel)
        % IDs from a classifier fitted on another plate must not be reused as
        % current-image reference IDs. Supply its paired resolver explicitly.
        model=struct('Ready',false);
    else
        model=fit_colony_resolver(result);
    end
else
    model=result.Options.ClassificationResolverModel;
end
if ~isstruct(model) || ~isfield(model,'Ready')
    error('CFU:InvalidResolver','ClassificationResolverModel must come from fit_colony_resolver.');
end
result.ClassificationResolverModel=model;
[F,names]=colony_resolution_matrix(T);
if model.Ready && (~isfield(model,'Version') || model.Version~=1 || ...
        ~isequal(string(model.FeatureNames),names) || ...
        numel(model.Scale)~=numel(names) || any(~isfinite(model.Scale) | model.Scale<=0) || ...
        numel(model.Coefficients)~=numel(names) || any(~isfinite(model.Coefficients)) || ...
        ~isfinite(model.Intercept) || ~isfield(model,'Bootstrap') || numel(model.Bootstrap)<20)
    error('CFU:InvalidResolver','Interior-color model is incompatible with the current features.');
end
for i=find(T.ClassificationWarningBeforeResolution & ~T.Reviewed)'
    if T.ResolutionBackgroundPixels(i)<30
        T.ResolutionReason(i)="insufficient_clean_background"; continue
    end
    if ~all(isfinite(F(i,:)))
        T.ResolutionReason(i)="insufficient_unobscured_interior"; continue
    end
    if ~model.Ready
        T.ResolutionReason(i)="insufficient_reference_support"; continue
    end
    z=max(-5,min(5,(F(i,:)-model.Location)./model.Scale));
    score=z*model.Coefficients+model.Intercept; T.ResolutionScore(i)=score;
    predicted=double(score>=0); primary=double(T.Class(i)=="AD24");
    boot=zeros(numel(model.Bootstrap),1);
    for k=1:numel(boot)
        m=model.Bootstrap(k);
        boot(k)=max(-5,min(5,(F(i,:)-m.Location)./m.Scale))*m.Coefficients+m.Intercept;
    end
    boot=sort(boot); lo=boot(max(1,ceil(0.025*numel(boot)))); hi=boot(ceil(0.975*numel(boot)));
    T.ResolutionScoreLow(i)=lo; T.ResolutionScoreHigh(i)=hi;
    T.ResolutionAgreement(i)=mean((boot>=0)==predicted);
    own=model.ReferenceLabels==predicted;
    d=sqrt(mean((model.ReferenceFeatures(own,:)-z).^2,2));
    [d,order]=sort(d); ids=model.ReferenceIDs(own);
    T.ResolutionReferenceDistance(i)=mean(d(1:model.NeighborCount));
    T.ResolutionReferenceLimit(i)=model.CoverageLimit(predicted+1);
    T.ResolutionReferenceIDs(i)=strjoin(string(ids(order(1:model.NeighborCount))),";");
    if predicted~=primary
        T.ResolutionReason(i)="interior_color_disagrees_with_primary";
    elseif abs(score)<result.Options.CompositeReviewMargin
        T.ResolutionReason(i)="weak_interior_color_separation";
    elseif lo<=0 && hi>=0
        T.ResolutionReason(i)="unstable_reference_resampling";
    elseif T.ResolutionReferenceDistance(i)>T.ResolutionReferenceLimit(i)
        T.ResolutionReason(i)="outside_reference_feature_range";
    else
        T.ResolutionAccepted(i)=true;
        T.ResolutionReason(i)="corroborated_by_interior_color";
    end
end
result.Colonies=T; result=update_colony_warnings(result);
result.Summary=summarize_colonies(result);
end

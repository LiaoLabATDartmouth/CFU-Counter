function result=classify_colonies(result)
%CLASSIFY_COLONIES Apply learned Fisher coefficients to normalized features.
% FisherScore >= 0 assigns AD24. ScoreAD24 is a rescaled coordinate, NOT a
% probability. Warning policy is centralized in update_colony_warnings.
T=result.Colonies; n=height(T);
if ismember('ResolutionAccepted',T.Properties.VariableNames), T.ResolutionAccepted(:)=false; end
T.SizeOnlyClass=repmat("AD9",n,1);
T.SizeOnlyClass(T.DiameterPixels>=result.DiameterThresholdPixels)="AD24";
T.Class=T.SizeOnlyClass; T.FisherScore=nan(n,1);
T.ScoreAD24=nan(n,1); T.SeparationMargin=nan(n,1);
T.SizeEvidence=nan(n,1); T.ColorEvidence=nan(n,1);
T.ShapeEvidence=nan(n,1); T.BoundaryEvidence=nan(n,1);
T.ClassifierBasis=repmat("size rule",n,1);
T.SizeFallbackUsed=false(n,1);
result.ClassificationInfo=struct('Mode',"size",'Message',"Labels use the size reference.");
if string(result.Options.ClassifierMode)=="size"
    T.AutomaticClass=T.Class;
    result.Colonies=T; result.ClassifierModel=struct('Ready',false,'Source',"size rule");
    result=update_colony_warnings(result); return
end
if isempty(result.Options.ClassifierModel), model=fit_colony_classifier(result);
else, model=result.Options.ClassifierModel;
end
[F,names,groups]=colony_feature_matrix(T);
if ~isstruct(model) || ~isfield(model,'Ready')
    error('CFU:InvalidModel','ClassifierModel must come from fit_colony_classifier.');
end
if model.Ready
    result.ClassificationInfo=struct('Mode',"composite", ...
        'Message',"Labels use the learned size, color, shape and boundary classifier.");
    if ~isfield(model,'Version') || model.Version~=2 || ~isequal(string(model.FeatureNames),names) || ...
            numel(model.Scale)~=numel(names) || any(~isfinite(model.Scale) | model.Scale<=0) || ...
            numel(model.Coefficients)~=numel(names) || any(~isfinite(model.Coefficients))
        error('CFU:InvalidModel','Model is incompatible with the current Fisher classifier.');
    end
    valid=all(isfinite(F),2);
    Z=max(-5,min(5,(F(valid,:)-model.Location)./model.Scale));
    score=Z*model.Coefficients+model.Intercept;
    T.FisherScore(valid)=score;
    T.ScoreAD24(valid)=max(0,min(1,(score+1)/2));
    T.SeparationMargin(valid)=abs(score);
    labels=repmat("AD9",sum(valid),1); labels(score>=0)="AD24";
    T.Class(valid)=labels;
    midpoint=(model.CenterAD9+model.CenterAD24)/2;
    contributions=(Z-midpoint).*model.Coefficients';
    evidence=zeros(sum(valid),4);
    for g=1:4, evidence(:,g)=sum(contributions(:,groups==g),2); end
    T.SizeEvidence(valid)=evidence(:,1); T.ColorEvidence(valid)=evidence(:,2);
    T.ShapeEvidence(valid)=evidence(:,3); T.BoundaryEvidence(valid)=evidence(:,4);
    T.ClassifierBasis(valid)=string(model.Source);
else
    valid=false(n,1);
    % A single appearance group cannot train a two-class discriminant. Keep
    % the configured small/large rule available, with conservative color,
    % shape, background and size-margin checks in update_colony_warnings.
    T.SizeFallbackUsed=all(isfinite(F),2);
    result.ClassificationInfo=struct('Mode',"size_fallback", ...
        'Message',"Size reference used; too few clean examples of both groups for composite classification.");
end
for i=find(~valid)'
    T.ClassifierBasis(i)="size fallback: insufficient composite references/features";
end
T.ClassifierBasis(T.SizeFallbackUsed)="size reference fallback; composite references unavailable";
T.AutomaticClass=T.Class;
result.Colonies=T; result.ClassifierModel=model;
result=update_colony_warnings(result);
end

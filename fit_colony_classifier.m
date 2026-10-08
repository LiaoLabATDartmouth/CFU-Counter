function model=fit_colony_classifier(result, AD9IDs, AD24IDs)
%FIT_COLONY_CLASSIFIER Learn a regularized Fisher discriminant from features.
% w maximizes (w'*(mu24-mu9))^2 / (w'*regularizedWithinClassCovariance*w).
% No fixed feature-group weights. Shrinkage is selected by stratified CV.
% With no ID lists, clear small/large objects supply unvalidated seed labels.
% Use >=3 verified reference IDs per class for supervised calibration instead.
T=result.Colonies; [F,names,groups,floors]=colony_feature_matrix(T);
eligible=all(isfinite(F),2);
if nargin==1
    notes=T.ReviewReason;
    if ismember('DetectionNotes',T.Properties.VariableNames), notes=T.DetectionNotes; end
    clean=eligible & ~contains(notes,"near_rim") & ...
        ~contains(notes,"near_ink") & T.Solidity>=0.85;
    cutoff=result.DiameterThresholdPixels;
    seed9=clean & T.DiameterPixels<=0.85*cutoff;
    seed24=clean & T.DiameterPixels>=1.15*cutoff;
    source="Fisher LDA with size-seeded labels; unvalidated";
else
    validateattributes(AD9IDs,{'numeric'},{'vector','integer','positive'});
    validateattributes(AD24IDs,{'numeric'},{'vector','integer','positive'});
    if any(ismember(AD9IDs,AD24IDs)) || ~all(ismember([AD9IDs(:);AD24IDs(:)],T.ID))
        error('CFU:InvalidTrainingIDs','Training IDs must exist and classes must not overlap.');
    end
    seed9=ismember(T.ID,AD9IDs) & eligible;
    seed24=ismember(T.ID,AD24IDs) & eligible;
    source="Fisher LDA with user-selected reference colonies";
end
model=struct('Version',2,'FeatureNames',names,'Groups',groups,'Source',source, ...
    'SeedAD9IDs',T.ID(seed9),'SeedAD24IDs',T.ID(seed24), ...
    'Ready',sum(seed9)>=3 && sum(seed24)>=3);
if ~model.Ready, return; end
X=[F(seed9,:);F(seed24,:)]; y=[zeros(sum(seed9),1);ones(sum(seed24),1)];
folds=min(5,min(sum(seed9),sum(seed24)));
foldID=[mod((0:sum(seed9)-1)',folds)+1;mod((0:sum(seed24)-1)',folds)+1];
lambda=sort(unique(result.Options.ShrinkageCandidates(:)));
separation=zeros(numel(lambda),1); accuracy=separation; predictions=zeros(size(X,1),numel(lambda));
for c=1:numel(lambda)
    for fold=1:folds
        train=foldID~=fold; test=~train;
        fit=fit_fisher_features(X(train,:),y(train),lambda(c),floors);
        Z=standardize(X(test,:),fit);
        predictions(test,c)=Z*fit.Coefficients+fit.Intercept;
    end
    v=predictions(:,c);
    accuracy(c)=0.5*(mean(v(y==0)<0)+mean(v(y==1)>=0));
    separation(c)=(mean(v(y==1))-mean(v(y==0)))^2 / ...
        max(0.5*(var(v(y==0),1)+var(v(y==1),1)),1e-6);
end
% Among models within 2 percentage points of the best seed-label balanced
% accuracy, maximize held-out Fisher separation; prefer stronger shrinkage
% for numerical ties. CV uses training-fold normalization only.
eligibleLambda=accuracy>=max(accuracy)-0.02;
objective=separation; objective(~eligibleLambda)=-Inf;
best=find(objective>=max(objective)-1e-10,1,'last');
fit=fit_fisher_features(X,y,lambda(best),floors);
fields=fieldnames(fit);
for i=1:numel(fields), model.(fields{i})=fit.(fields{i}); end
model.CrossValidation=table(lambda,accuracy,separation,'VariableNames', ...
    {'Shrinkage','BalancedSeedAccuracy','HeldOutSeedSeparation'});
model.SelectedCVSeedAccuracy=accuracy(best);
model.SelectedCVSeedSeparation=separation(best);
model.CVFoldCount=folds;
model.SeedOutOfFoldScores=predictions(:,best);
model.SeedLabels=y;
end

function Z=standardize(X,fit)
Z=max(-5,min(5,(X-fit.Location)./fit.Scale));
end

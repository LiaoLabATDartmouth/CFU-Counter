function model=fit_colony_resolver(result)
%FIT_COLONY_RESOLVER Learn corroborating interior-color evidence for weak calls.
% Uses original reference IDs, excluding split, flagged, or obscured objects.
% Bootstrap stability and reference coverage are not biological probabilities.
T=result.Colonies; [F,names,floors]=colony_resolution_matrix(T);
model=struct('Version',1,'Ready',false,'FeatureNames',names, ...
    'Source',"Interior-color Fisher model from provisional reference colonies");
if ~result.ClassifierModel.Ready, return; end
clean=all(isfinite(F),2) & T.SplitStatus=="not_split" & ~T.NeedsReview;
seed9=ismember(T.ID,result.ClassifierModel.SeedAD9IDs) & clean;
seed24=ismember(T.ID,result.ClassifierModel.SeedAD24IDs) & clean;
if min(nnz(seed9),nnz(seed24))<5, return; end
model.SeedAD9IDs=T.ID(seed9); model.SeedAD24IDs=T.ID(seed24);
X=[F(seed9,:);F(seed24,:)]; y=[zeros(nnz(seed9),1);ones(nnz(seed24),1)];
try
folds=min(5,min(nnz(seed9),nnz(seed24)));
foldID=[mod((0:nnz(seed9)-1)',folds)+1;mod((0:nnz(seed24)-1)',folds)+1];
lambda=sort(unique(result.Options.ShrinkageCandidates(:)));
accuracy=zeros(size(lambda)); separation=accuracy; predictions=zeros(numel(y),numel(lambda));
for c=1:numel(lambda)
    for fold=1:folds
        train=foldID~=fold; test=~train;
        fit=fit_fisher_features(X(train,:),y(train),lambda(c),floors);
        predictions(test,c)=project(X(test,:),fit);
    end
    v=predictions(:,c);
    accuracy(c)=0.5*(mean(v(y==0)<0)+mean(v(y==1)>=0));
    separation(c)=(mean(v(y==1))-mean(v(y==0)))^2/ ...
        max(0.5*(var(v(y==0),1)+var(v(y==1),1)),1e-6);
end
objective=separation; objective(accuracy<max(accuracy)-0.02)=-Inf;
best=find(objective>=max(objective)-1e-10,1,'last');
fit=fit_fisher_features(X,y,lambda(best),floors);
for name=fieldnames(fit)', model.(name{1})=fit.(name{1}); end
model.CrossValidation=table(lambda,accuracy,separation,'VariableNames', ...
    {'Shrinkage','BalancedSeedAccuracy','HeldOutSeedSeparation'});
model.CVFoldCount=folds; model.SelectedCVSeedAccuracy=accuracy(best);
model.SeedOutOfFoldScores=predictions(:,best); model.SeedLabels=y;
model.Ready=accuracy(best)>=0.95;
if ~model.Ready, return; end
% Learn a class-specific coverage limit from leave-one-out neighbor distances.
Z=max(-5,min(5,(X-model.Location)./model.Scale));
model.ReferenceFeatures=Z; model.ReferenceIDs=[T.ID(seed9);T.ID(seed24)];
model.ReferenceLabels=y; model.NeighborCount=3; model.CoverageLimit=zeros(1,2);
for c=0:1
    own=Z(y==c,:); distances=zeros(size(own,1));
    for i=1:size(own,1), distances(i,:)=sqrt(mean((own-own(i,:)).^2,2)); end
    distances(1:size(own,1)+1:end)=Inf;
    ordered=sort(distances,2); local=mean(ordered(:,1:model.NeighborCount),2);
    sorted=sort(local); model.CoverageLimit(c+1)=sorted(ceil(0.95*numel(sorted)));
end
% A local random stream makes the result repeatable without changing rng.
stream=RandStream('mt19937ar','Seed',1701); indices9=find(y==0); indices24=find(y==1);
for k=1:result.Options.ResolverBootstrapSamples
    take=[indices9(randi(stream,numel(indices9),numel(indices9),1)); ...
        indices24(randi(stream,numel(indices24),numel(indices24),1))];
    model.Bootstrap(k)=fit_fisher_features(X(take,:),y(take),lambda(best),floors);
end
catch err
    if ~strcmp(err.identifier,'CFU:IndistinguishableReferences'), rethrow(err); end
    % Two size groups can have identical interior colors. A secondary
    % classifier is then unavailable; counting and primary labels still work.
    model.Ready=false;
    model.FailureReason="Reference colors do not provide independent separation.";
end
end

function score=project(X,fit)
score=max(-5,min(5,(X-fit.Location)./fit.Scale))*fit.Coefficients+fit.Intercept;
end

function fit=fit_fisher_features(X,y,lambda,floors)
%FIT_FISHER_FEATURES Regularized Fisher fit with robust feature scaling.
fit.Location=median(X,1);
fit.Scale=max(1.4826*median(abs(X-fit.Location),1),floors);
Z=max(-5,min(5,(X-fit.Location)./fit.Scale));
mu9=mean(Z(y==0,:),1); mu24=mean(Z(y==1,:),1);
S=0.5*(cov(Z(y==0,:),1)+cov(Z(y==1,:),1));
target=max(trace(S)/size(S,1),1e-3);
regularized=(1-lambda)*S+lambda*target*eye(size(S));
w=regularized\(mu24-mu9)';
gap=(mu24-mu9)*w;
if gap<=1e-10
    error('CFU:IndistinguishableReferences','Reference groups have no measurable feature separation.');
end
w=2*w/gap;
fit.Coefficients=w; fit.Intercept=-0.5*(mu9+mu24)*w;
fit.Shrinkage=lambda; fit.CenterAD9=mu9; fit.CenterAD24=mu24;
fit.TrainingFisherSeparation=((mu24-mu9)*w)^2/max(w'*regularized*w,eps);
end

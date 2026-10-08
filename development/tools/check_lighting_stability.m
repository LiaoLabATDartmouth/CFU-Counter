function report=check_lighting_stability(result,outputFolder)
%CHECK_LIGHTING_STABILITY Simulated lighting sensitivity, not accuracy testing.
% Reuses the SAME classifier and ROI; compares matched detected colonies.
% Simulations avoid highlight clipping. Actual day-to-day photos are needed
% to evaluate glare, sensor noise, camera processing and changed colony growth.
if nargin<2, outputFolder=fullfile(pwd,'lighting_check'); end
if ~isfolder(outputFolder), mkdir(outputFolder); end
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
linear=rgb2lin(im2single(imread(result.ImageFile)));
gains=[0.60 0.60 0.60;0.66 0.51 0.57;0.76 0.90 0.82];
cases=["dimmed","dimmed_warmer","cooler"];
report=table(); opts=result.Options; opts.ClassifierModel=result.ClassifierModel;
if isfield(result,'ClassificationResolverModel')
    opts.ClassificationResolverModel=result.ClassificationResolverModel;
end
% Freeze the actual selected counting ellipse even if originally automatic.
ellipse=result.CountingEllipseWork;
ellipse(1:2)=(ellipse(1:2)-0.5)/result.Scale+0.5;
ellipse(3:4)=ellipse(3:4)/result.Scale; opts.PlateEllipse=ellipse;
for i=1:size(gains,1)
    changed=lin2rgb(linear.*reshape(single(gains(i,:)),1,1,3));
    file=fullfile(folder,'altered.png'); imwrite(im2uint16(changed),file);
    altered=count_colonies(file,opts);
    [matched,agreement]=matchColonies(result,altered);
    row=table(cases(i),altered.Summary.Total,altered.Summary.AD9,altered.Summary.AD24, ...
        matched,agreement,altered.Summary.ClassificationWarnings, ...
        'VariableNames',{'Case','Total','AD9','AD24','MatchedFraction','MatchedLabelAgreement','ClassificationWarnings'});
    report=[report;row]; %#ok<AGROW>
end
writetable(report,fullfile(outputFolder,'lighting_stability.csv'));
end

function [matched,agreement]=matchColonies(base,changed)
A=base.Colonies; B=changed.Colonies;
if isempty(A), matched=NaN; agreement=NaN; return; end
distance=hypot(A.X-B.X',A.Y-B.Y');
matches=zeros(0,2); tolerance=6/base.Scale;
while ~isempty(distance)
    [value,index]=min(distance(:));
    if isempty(value) || value>tolerance, break; end
    [a,b]=ind2sub(size(distance),index);
    matches(end+1,:)=[a b]; %#ok<AGROW>
    distance(a,:)=Inf; distance(:,b)=Inf;
end
matched=size(matches,1)/height(A);
if isempty(matches), agreement=NaN;
else, agreement=mean(A.Class(matches(:,1))==B.Class(matches(:,2)));
end
end

function fig=plot_classification_diagnostics(result,visibility)
%PLOT_CLASSIFICATION_DIAGNOSTICS Show the evidence check for original ! flags.
if nargin<2, visibility='on'; end
T=result.Colonies; candidates=find(T.ClassificationWarningBeforeResolution & T.Source=="automatic");
[~,order]=sort(T.ResolutionAccepted(candidates),'descend'); candidates=candidates(order);
rows=max(1,ceil(numel(candidates)/4));
fig=figure('Visible',visibility,'Color','w','Position',[20 20 1200 280*rows]);
layout=tiledlayout(fig,rows,4,'TileSpacing','compact','Padding','loose');
for i=candidates'
    [yy,xx]=find(result.Labels==T.ID(i));
    ax=nexttile(layout);
    if isempty(xx), axis(ax,'off'); continue; end
    padding=12;
    xs=max(1,min(xx)-padding):min(size(result.Image,2),max(xx)+padding);
    ys=max(1,min(yy)-padding):min(size(result.Image,1),max(yy)+padding);
    imshow(result.Image(ys,xs,:),'Parent',ax); hold(ax,'on');
    color=[0.1 0.9 1]; if T.Class(i)=="AD24", color=[1 0.65 0]; end
    b=bwboundaries(result.Labels(ys,xs)==T.ID(i));
    for j=1:numel(b), plot(ax,b{j}(:,2),b{j}(:,1),'Color',color,'LineWidth',1); end
    switch T.ResolutionReason(i)
        case "corroborated_by_interior_color", status="Color supports label; ! cleared";
        case "insufficient_unobscured_interior", status="! Interior obscured";
        case "insufficient_clean_background", status="! Too little clean agar";
        case "outside_reference_feature_range", status="! Outside reference range";
        case "interior_color_disagrees_with_primary", status="! Models disagree";
        case "unstable_reference_resampling", status="! Unstable color evidence";
        case "weak_interior_color_separation", status="! Color is intermediate";
        otherwise, status="! Insufficient reference support";
    end
    title(ax,{sprintf('ID %d: %s | color score %.2f',T.ID(i),T.Class(i),T.ResolutionScore(i)), ...
        char(status)},'FontSize',10,'Interpreter','none');
end
title(layout,sprintf('Interior-color check: %d corroborated; %d still unclear. Outlines unchanged.', ...
    sum(T.ResolutionAccepted),sum(T.ClassificationWarning)),'FontSize',13);
end

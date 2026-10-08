function fig = plot_colonies(result, showIDs, visibility)
%PLOT_COLONIES Show counts, counting boundary, and one marker per colony.
if nargin<2, showIDs=false; end
if nargin<3, visibility='on'; end
fig = figure('Visible',visibility,'Color','w','Name','AD9 / AD24 colony count', ...
    'Position',[50 50 1080 1000]);
layout=tiledlayout(fig,1,1,'Padding','loose');
ax=nexttile(layout); image(ax,result.Image); axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
e=result.CountingEllipseWork; radius=1.15*max(e(3:4));
xlim(ax,[max(0.5,e(1)-radius),min(size(result.Image,2)+0.5,e(1)+radius)]);
ylim(ax,[max(0.5,e(2)-radius),min(size(result.Image,1)+0.5,e(2)+radius)]);
boundary = bwboundaries(result.ROI);
for k=1:numel(boundary), plot(ax,boundary{k}(:,2),boundary{k}(:,1),'y-','LineWidth',1); end
draw_colony_overlay(ax,result,showIDs,false);
s=summarize_colonies(result);
title(ax,{sprintf('AD9: %d   |   AD24: %d   |   Need review: %d   |   Total: %d', ...
    s.AD9,s.AD24,s.Uncertain,s.Total), ...
    'Cyan = AD9; orange = AD24; yellow = counting boundary.', ...
    sprintf('White dashed circles with black outlines = needs review (%d).',s.FlaggedForReview)}, ...
    'FontSize',11,'Interpreter','none');
end

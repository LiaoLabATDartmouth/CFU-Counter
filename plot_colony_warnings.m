function plot_colony_warnings(ax,result)
%PLOT_COLONY_WARNINGS White dashed review rings on a black outline.
T=result.Colonies; palette=colony_annotation_styles();
hold(ax,'on');
rows=find(T.NeedsReview); if isempty(rows), return; end
xy=([T.X(rows),T.Y(rows)]-0.5)*result.Scale+0.5;
radius=colony_circle_radii(T(rows,:),result.Scale)+3;
theta=linspace(0,2*pi,61);
x=xy(:,1)+radius*cos(theta); y=xy(:,2)+radius*sin(theta);
xx=reshape([x,nan(numel(rows),1)]',[],1); yy=reshape([y,nan(numel(rows),1)]',[],1);
% The dark underlay remains visible on glare; white remains visible on dark
% agar. This also avoids relying on a hue close to the pink colonies.
plot(ax,xx,yy,'-','Color',palette.ReviewOutlineColor,'LineWidth',3,'Tag','ColonyWarningOutline');
plot(ax,xx,yy,'--','Color',palette.Colors(3,:),'LineWidth',1.6,'Tag','ColonyWarning', ...
    'UserData',struct('Label',palette.Labels(3),'IDs',T.ID(rows)));
end

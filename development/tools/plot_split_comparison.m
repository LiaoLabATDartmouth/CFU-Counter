function fig=plot_split_comparison(result,visibility,parentIDs)
%PLOT_SPLIT_COMPARISON Show original outer masks and the internal subdivisions.
if nargin<2, visibility='on'; end
if nargin<3, parentIDs=result.SplitLog.ParentID; end
fig=figure('Visible',visibility,'Color','w','Position',[50 50 900 max(350,260*numel(parentIDs))]);
layout=tiledlayout(fig,max(1,numel(parentIDs)),2,'Padding','loose','TileSpacing','compact');
if isempty(parentIDs)
    ax=nexttile(layout); text(ax,0.1,0.5,'No regions split.'); axis(ax,'off'); return
end
for id=parentIDs'
    [y,x]=find(result.OriginalLabels==id);
    xs=max(1,min(x)-10):min(size(result.Image,2),max(x)+10);
    ys=max(1,min(y)-10):min(size(result.Image,1),max(y)+10);
    old=result.OriginalLabels(ys,xs)==id;
    ax=nexttile(layout); image(ax,result.Image(ys,xs,:)); axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
    b=bwboundaries(old); plot(ax,b{1}(:,2),b{1}(:,1),'y-','LineWidth',1);
    title(ax,sprintf('Original region %d',id));
    ax=nexttile(layout); image(ax,result.Image(ys,xs,:)); axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
    children=result.Colonies(result.Colonies.ParentID==id,:); names=strings(0,1);
    for k=1:height(children)
        color=[0.05 0.85 1]; if children.Class(k)=="AD24", color=[1 0.60 0]; end
        b=bwboundaries(result.Labels(ys,xs)==children.ID(k));
        for j=1:numel(b), plot(ax,b{j}(:,2),b{j}(:,1),'Color',color,'LineWidth',1); end
        names(end+1)=string(children.ID(k))+": "+children.Class(k); %#ok<AGROW>
    end
    title(ax,strjoin(names,"  +  "),'Interpreter','none');
end
title(layout,'Internal splitting; the union of the outer pixels is unchanged');
end

function draw_colony_overlay(ax,result,showIDs,reviewOnly)
%DRAW_COLONY_OVERLAY Colored enclosing circles and one generic review ring.
if nargin<3, showIDs=false; end
if nargin<4, reviewOnly=false; end
T=result.Colonies; keep=true(height(T),1);
if reviewOnly, keep=T.NeedsReview; end
palette=colony_annotation_styles(); classes=palette.Classes(1:3); colors=palette.Colors(1:3,:);
theta=linspace(0,2*pi,49); hold(ax,'on');
for c=1:2
    rows=find(keep & T.Class==classes(c));
    if isempty(rows), continue; end
    xy=([T.X(rows),T.Y(rows)]-0.5)*result.Scale+0.5;
    radius=colony_circle_radii(T(rows,:),result.Scale);
    x=xy(:,1)+radius*cos(theta); y=xy(:,2)+radius*sin(theta);
    plot(ax,reshape([x,nan(numel(rows),1)]',[],1),reshape([y,nan(numel(rows),1)]',[],1), ...
        'Color',colors(c,:),'LineWidth',0.8,'Tag','ColonyCircles', ...
        'UserData',struct('Label',palette.Labels(c),'IDs',T.ID(rows)));
end
plot_colony_warnings(ax,result);
% Draw all IDs last, so review rings cannot obscure their first digits.
if ~showIDs, return; end
for c=1:3
    rows=find(keep & T.Class==classes(c));
    if isempty(rows), continue; end
    xy=([T.X(rows),T.Y(rows)]-0.5)*result.Scale+0.5;
    radius=colony_circle_radii(T(rows,:),result.Scale);
    if c==3, radius=radius+3; end
    for j=1:numel(rows)
        label=text(ax,xy(j,1)+radius(j)+3,xy(j,2),string(T.ID(rows(j))), ...
            'Color',colors(c,:),'FontSize',7,'Interpreter','none','Tag','ColonyID', ...
            'UserData',struct('ID',T.ID(rows(j)),'Label',palette.Labels(c)));
        if c==3, label.BackgroundColor=palette.ReviewOutlineColor; label.Margin=1; end
    end
end
end

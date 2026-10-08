function fig=plot_colony_features(result,visibility)
%PLOT_COLONY_FEATURES Inspect measured features, learned projection and weights.
if nargin<2, visibility='on'; end
T=result.Colonies; model=result.ClassifierModel;
fig=figure('Visible',visibility,'Color','w','Position',[50 50 1450 570]);
layout=tiledlayout(fig,1,3,'Padding','loose','TileSpacing','loose');
colors=[0.05 0.65 0.85;0.95 0.50 0.05]; labels=["AD9","AD24"];
ax=nexttile(layout); hold(ax,'on');
for c=1:2
    rows=T.Class==labels(c);
    scatter(ax,T.DiameterPixels(rows),T.LocalLogPink(rows),16,colors(c,:),'filled','DisplayName',labels(c));
end
xlabel(ax,'Equivalent diameter (original pixels)'); ylabel(ax,'Local normalized pink contrast');
title(ax,'Measured size and color'); legend(ax,'Location','best'); grid(ax,'on');
ax=nexttile(layout); hold(ax,'on');
if model.Ready
    scores=model.SeedOutOfFoldScores;
    for c=1:2
        histogram(ax,scores(model.SeedLabels==c-1),'BinWidth',0.2,'Normalization','probability', ...
            'FaceColor',colors(c,:),'FaceAlpha',0.5,'DisplayName',labels(c)+" seed");
    end
    xline(ax,0,'k--','Decision boundary','HandleVisibility','off');
    xlabel(ax,'Held-out Fisher score'); ylabel(ax,'Fraction of reference colonies');
    title(ax,sprintf('Cross-validated seed separation: %.2f',model.SelectedCVSeedSeparation));
    legend(ax,'Location','best'); grid(ax,'on');
    ax=nexttile(layout);
    barh(ax,model.Coefficients,'FaceColor',[0.35 0.45 0.6]);
    yticks(ax,1:numel(model.FeatureNames)); yticklabels(ax,model.FeatureNames);
    ax.TickLabelInterpreter='none'; ax.FontSize=8;
    xlabel(ax,'Learned standardized coefficient'); title(ax,'Fitted linear combination'); grid(ax,'on');
else
    text(ax,0.1,0.5,'Insufficient reference colonies: size fallback'); axis(ax,'off');
end
caption='Feature separation; size-seeded labels are provisional, not ground truth';
if contains(string(model.Source),'user-selected')
    caption='Feature separation using supplied references; validate on independent plates';
end
title(layout,caption,'FontSize',13);
end

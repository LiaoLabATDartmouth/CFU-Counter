function [colonies,summary,snapshot]=colony_export_tables(result)
%COLONY_EXPORT_TABLES One label snapshot for both exported files.
T=result.Colonies; palette=colony_annotation_styles();
if any(~ismember(T.Class,[palette.Classes,"Need review"]))
    error('CFU:InvalidClass','A colony has an unknown label. Correct it before saving.');
end
included=T.Class~="Not a colony";
review=included & (T.NeedsReview | T.Class=="Uncertain" | T.Class=="Need review");
label=T.Class; label(review)="Need review";
[~,style]=ismember(label,palette.Labels);
color=reshape(palette.Names(style),[],1);
colonies=table(T.ID,label,color,T.X,T.Y,T.DiameterPixels,T.EnclosingRadiusPixels, ...
    review,T.Reviewed,included,'VariableNames',{'ID','Label','AnnotationColor', ...
    'X','Y','DiameterPixels','EnclosingRadiusPixels','NeedsReview','Reviewed','IncludedInCount'});
if ismember('SuggestedClass',T.Properties.VariableNames)
    original=T.SuggestedClass; original(original=="Uncertain")="Need review";
    colonies.OriginalSuggestion=original;
end
for name=["Source","MarkedFromID","MarkerRadiusPixels"]
    if ismember(name,T.Properties.VariableNames), colonies.(name)=T.(name); end
end
summary=table(["AD24";"AD9";"Need review";"Not a colony";"Total included"], ...
    [sum(label=="AD24");sum(label=="AD9");sum(review);sum(~included);sum(included)], ...
    [palette.Names(2);palette.Names(1);palette.Names(3);palette.Names(4);""], ...
    'VariableNames',{'Label','Count','AnnotationColor'});
snapshot=result;
snapshot.Colonies.Class=label; snapshot.Colonies.Class(review)="Uncertain";
snapshot.Colonies.NeedsReview=review;
snapshot.Summary=summarize_colonies(snapshot);
end

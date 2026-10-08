function result = review_colonies(result, outputFolder)
%REVIEW_COLONIES Click to add/delete/reclassify/confirm colonies; undo supported.
% Optional older figure-based reviewer. Prefer ColonyCounterApp.
% result=review_colonies(result,'existing_output_folder');
% Select a mode at the top, then click a colony (or a missed colony to add it).
% Use the figure toolbar to zoom/pan; turn zoom/pan OFF before editing.
% Save & close writes the edited result. Closing the window cancels edits.
if nargin<2, outputFolder=pwd; end
original=result; history={}; saved=false;
fig=figure('Name','Review AD9 / AD24 counts','Color','w', ...
    'Position',[50 50 1150 1050],'CloseRequestFcn',@cancelReview);
ax=axes(fig,'Position',[0.03 0.04 0.94 0.86]);
modes={'Confirm colony','Set AD9','Set AD24','Set Uncertain','Delete colony', ...
    'Add AD9','Add AD24','Add Uncertain'};
mode=uicontrol(fig,'Style','popupmenu','String',modes,'Units','normalized', ...
    'Position',[0.02 0.95 0.23 0.035]);
uicontrol(fig,'Style','pushbutton','String','Undo','Units','normalized', ...
    'Position',[0.26 0.95 0.09 0.035],'Callback',@undoEdit);
uicontrol(fig,'Style','pushbutton','String','Save & close','Units','normalized', ...
    'Position',[0.36 0.95 0.15 0.035],'Callback',@saveReview);
uicontrol(fig,'Style','text','String','Select a mode, then click. Turn zoom/pan off to edit.', ...
    'Units','normalized','Position',[0.52 0.95 0.46 0.035],'BackgroundColor','w');
status=uicontrol(fig,'Style','text','String','','Units','normalized', ...
    'Position',[0.02 0.91 0.95 0.03],'BackgroundColor','w');
fig.WindowButtonDownFcn=@clicked;
redraw(); uiwait(fig);
if ~saved, result=original; end

    function redraw()
        previousX=xlim(ax); previousY=ylim(ax); keepView=~isempty(ax.Children);
        cla(ax); imshow(result.Image,'Parent',ax); hold(ax,'on');
        b=bwboundaries(result.ROI);
        for j=1:numel(b), plot(ax,b{j}(:,2),b{j}(:,1),'y-'); end
        draw_colony_overlay(ax,result,false,false);
        if keepView, xlim(ax,previousX); ylim(ax,previousY); end
        s=summarize_colonies(result);
        title(ax,{sprintf('AD9: %d | AD24: %d | Uncertain: %d | Total: %d | Flagged: %d', ...
            s.AD9,s.AD24,s.Uncertain,s.Total,s.FlaggedForReview), ...
            'White dashed circles with black outlines = needs review.'}, ...
            'Interpreter','none');
    end

    function clicked(~,~)
        hit=hittest(fig);
        if ~isequal(hit,ax) && ~isequal(ancestor(hit,'axes'),ax), return; end
        z=zoom(fig); p=pan(fig);
        if strcmp(z.Enable,'on') || strcmp(p.Enable,'on'), return; end
        point=ax.CurrentPoint; wxy=point(1,1:2); xy=(wxy-0.5)/result.Scale+0.5;
        choice=mode.Value;
        try
            before=result;
            if choice>=6
                classes=["AD9","AD24","Uncertain"];
                result=edit_colony(result,'add',xy,classes(choice-5));
            else
                T=result.Colonies;
                if isempty(T), return; end
                [d,index]=min(hypot(T.X-xy(1),T.Y-xy(2)));
                % Selection radius scales with colony size, capped at 24 work pixels.
                selectionRadius=max(10,min(24,T.DiameterPixels(index)*result.Scale/2+5));
                if ~isfinite(selectionRadius), selectionRadius=10; end
                if d*result.Scale>selectionRadius, status.String='Click closer to a detected colony.'; return; end
                id=T.ID(index);
                if choice==1
                    result=edit_colony(result,'confirm',id);
                elseif choice==5
                    result=edit_colony(result,'delete',id);
                else
                    classes=["AD9","AD24","Uncertain"];
                    result=edit_colony(result,'classify',id,classes(choice-1));
                end
            end
            history{end+1}=before;
            status.String=char(result.ReviewLog(end)); redraw();
        catch err
            status.String=err.message;
        end
    end

    function undoEdit(~,~)
        if isempty(history), return; end
        result=history{end}; history(end)=[]; status.String='Last edit undone.'; redraw();
    end

    function saveReview(~,~)
        status.String='Saving...'; drawnow;
        try
            save_colony_results(result,outputFolder);
            saved=true; delete(fig);
        catch err
            status.String=err.message;
        end
    end

    function cancelReview(~,~)
        delete(fig);
    end
end

classdef ColonyCounterApp < matlab.apps.AppBase
    %COLONYCOUNTERAPP Interactive AD9 / AD24 colony counting.
    % app = ColonyCounterApp;   or run launch_colony_app.m.
    % MATLAB R2021a+; classification requires Image Processing Toolbox.
    properties (SetAccess=private)
        UIFigure
        ImageAxes
        Buttons = struct()
        Controls = struct()
        CountLabels = struct()
        Options
        Result = []
        ImageFile = ""
        LastError = []
        StatusLabel
        SettingsHint
        ImageLabel
        ShowCircles
        ReviewOnly
        ShowIDs
        ColonyTable
        ReviewPanel
        SettingsPanel
        PanelDivider
        Tabs
        ReviewHelp
        BoundaryHint
        MarkingFigure = []
        MarkingTable
        MarkingLabel
        MarkingRadius
        MarkingButtons = struct()
        Dirty = false
        EstimationInfo = []
    end
    properties (Access=private)
        ImageData = []
        DisplayScale = 1
        Busy = false
        Schema
        BoundaryROI = []
        BoundaryStartEllipse = []
        BoundaryStartOptions = []
        BoundaryStartDirty = false
        Progress = []
        SourceFolder
        SelectedID = []
        PanelContainer
        ReviewPanelFraction = 0.44
        PanelDrag = []
        SelectedRowStyle
        MarkingMode = ""
        MarkingRadii = zeros(0,1)
        MarkingParent = []
        MarkingCenters = zeros(0,2)
        MarkingLabels = strings(0,1)
        MarkingSelected = []
        MarkingStartView = []
        MarkingHint
        MarkingCounts
        ImageStartingOptions = []
        ManualParameterNames = {}
        ResumeLease = []
        ResultsFolder = ""
    end
    methods
        function app=ColonyCounterApp(imageFile,visibility)
            if nargin<2, visibility='on'; end
            app.SourceFolder=fileparts(mfilename('fullpath'));
            app.Options=colony_defaults(); app.Schema=colony_app_parameters();
            app.createComponents(); registerApp(app,app.UIFigure);
            app.syncControls(); app.configureEnable();
            if nargin<1
                imageFile=fullfile(app.SourceFolder,'Examples','IMG_7489.jpeg');
            end
            if strlength(string(imageFile))>0 && isfile(imageFile), app.loadImage(imageFile); end
            app.UIFigure.Visible=visibility;
            if nargout==0, clear app; end
        end

        function loadImage(app,file)
            if app.Busy || strlength(app.MarkingMode)>0, return; end
            I=read_plate_image(file);
            app.clearBoundary();
            if string(file)~=app.ImageFile
                app.ResumeLease=[]; app.ResultsFolder="";
            end
            app.ImageFile=string(file); app.Result=[]; app.SelectedID=[];
            app.Options=colony_defaults(); app.ManualParameterNames={};
            app.ImageStartingOptions=[]; app.EstimationInfo=[];
            app.DisplayScale=min(1,1800/max(size(I,1),size(I,2)));
            if exist('imresize','file')==2, I=imresize(I,app.DisplayScale);
            else, app.DisplayScale=1; end
            app.ImageData=I; app.Dirty=false; app.LastError=[];
            [~,name,ext]=fileparts(file); app.ImageLabel.Text=string(name)+string(ext);
            app.CountLabels.AD9.Text='—'; app.CountLabels.AD24.Text='—'; app.CountLabels.Review.Text='—';
            app.syncControls(); app.refreshTable(); app.drawImage(false); app.configureEnable();
            app.estimateSettings();
            % The pilot already located a plate. Display its locked outline
            % before classification, and use this same ellipse for editing/fit.
            app.drawImage(false); app.configureEnable();
        end

        function loadResults(app,workbook,imageFile)
            % Restore only after the entire workbook has passed validation.
            if nargin<3, imageFile=""; end
            app.requireNoMarking();
            if app.Busy, error('CFU:Busy','Wait for the current operation to finish.'); end
            app.Busy=true; app.configureEnable();
            cleanup=onCleanup(@()app.finishBusy()); %#ok<NASGU>
            try
                [result,state,lease]=load_colony_app_results(workbook,imageFile);
                starting=result.Options; manual={}; estimation=[];
                if isfield(state,'ImageStartingOptions'), starting=state.ImageStartingOptions; end
                if isfield(state,'ManualParameterNames'), manual=state.ManualParameterNames; end
                if isfield(result,'EstimationInfo'), estimation=result.EstimationInfo; end
                % Check UI values before replacing any open work.
                for n=1:numel(app.Schema)
                    spec=app.Schema(n);
                    validateattributes(result.Options.(spec.Name),{'numeric'}, ...
                        {'scalar','finite','>=',spec.Minimum,'<=',spec.Maximum});
                    if ~isempty(starting)
                        validateattributes(starting.(spec.Name),{'numeric'}, ...
                            {'scalar','finite','>=',spec.Minimum,'<=',spec.Maximum});
                    end
                end
                for field={'SplitTouchingColonies','ResolveAmbiguousClassification'}
                    validateattributes(result.Options.(field{1}),{'logical','numeric'},{'scalar','binary'});
                end
                app.clearBoundary();
                app.ResumeLease=lease; app.ResultsFolder=string(fileparts(workbook));
                app.Result=result; app.ImageFile=result.ImageFile; app.Options=result.Options;
                app.ImageData=result.Image; app.DisplayScale=result.Scale;
                app.ImageStartingOptions=starting; app.ManualParameterNames=manual;
                app.EstimationInfo=estimation; app.Dirty=false; app.LastError=[]; app.SelectedID=[];
                app.ReviewOnly.Value=false; app.ShowCircles.Value=true;
                [~,name,ext]=fileparts(result.ImageFile); app.ImageLabel.Text=string(name)+string(ext);
                app.syncControls(); app.refreshCounts(); app.refreshTable(); app.drawImage(false);
                app.setStatus(state.Message);
            catch err
                app.LastError=err;
                app.setStatus(['Could not open saved results: ' err.message],true);
                rethrow(err);
            end
        end

        function setParameter(app,name,value)
            if app.Busy || strlength(app.MarkingMode)>0, return; end
            name=char(name);
            index=find(strcmp({app.Schema.Name},name),1);
            if isempty(index) && ~ismember(name,{'SplitTouchingColonies','ResolveAmbiguousClassification'})
                error('CFU:UnknownAppParameter','Unknown app parameter: %s',name);
            end
            if ~isempty(index)
                spec=app.Schema(index);
                validateattributes(value,{'numeric'},{'scalar','finite','>=',spec.Minimum,'<=',spec.Maximum});
                if strcmp(name,'MaxImageDimension'), value=round(value); end
            else
                validateattributes(value,{'logical','numeric'},{'scalar','binary'});
                value=logical(value);
            end
            candidate=app.Options; candidate.(name)=value;
            if app.sameOptions(candidate,app.Options)
                app.syncControls(); app.configureEnable(); return
            end
            app.Options.(name)=value;
            app.ManualParameterNames=union(app.ManualParameterNames,{name},'stable');
            app.Options.DiameterThresholdPixels=[];
            app.Options.ClassifierModel=[]; app.Options.ClassificationResolverModel=[];
            app.syncControls(); app.markDirty();
        end

        function classify(app)
            % Compatibility alias for scripts; the UI has one run action.
            app.applySettings();
        end

        function setPlateBoundary(app,ellipse)
            % Original-image coordinates: [centerX centerY radiusX radiusY angle].
            if app.Busy || strlength(app.MarkingMode)>0, return; end
            if ~isempty(ellipse)
                validateattributes(ellipse,{'numeric'},{'vector','numel',5,'finite','real'});
                if any(ellipse(3:4)<=0), error('CFU:InvalidOptions','Ellipse radii must be positive.'); end
                ellipse=reshape(ellipse,1,5);
            end
            changed=~app.sameOptions(struct('Ellipse',ellipse),struct('Ellipse',app.Options.PlateEllipse));
            app.clearBoundary();
            if ~changed, return; end
            app.Options.PlateEllipse=ellipse; app.markDirty();
            app.estimateSettings(); app.drawImage(true);
        end

        function setColonyLabel(app,id,label)
            % Every detected colony may be labeled; IDs remain stable keys.
            app.requireNoMarking();
            if app.Busy || isempty(app.Result) || app.Dirty
                error('CFU:PendingSettings','Click Apply and classify before editing colony labels.');
            end
            label=string(label);
            if ~isscalar(label) || ~ismember(label,["Need review","AD9","AD24","Not a colony"])
                error('CFU:InvalidClass','Choose Need review, AD9, AD24, or Not a colony.');
            end
            value=label; if value=="Need review", value="Uncertain"; end
            app.Result=edit_colony(app.Result,'classify',id,value);
            app.SelectedID=id; app.refreshCounts(); app.refreshTable(); app.drawImage(true); app.configureEnable();
            app.setStatus(sprintf('Colony %d labeled %s. Counts and circles updated; Save results to export.',id,label));
        end

        function selectColony(app,id,zoomIn)
            if nargin<3, zoomIn=true; end
            if app.Busy || strlength(app.MarkingMode)>0 || isempty(app.Result) || app.Dirty, return; end
            row=find(app.Result.Colonies.ID==id,1);
            if isempty(row), error('CFU:MissingID','Colony ID %d does not exist.',id); end
            app.SelectedID=id; app.drawImage(true); app.configureEnable();
            app.highlightTableRow(~zoomIn);
            if ~zoomIn
                app.setStatus(sprintf('Colony %d highlighted in Review colonies. Double-click its label to edit.',id));
                return
            end
            T=app.Result.Colonies; xy=([T.X(row),T.Y(row)]-0.5)*app.DisplayScale+0.5;
            radius=colony_circle_radii(T(row,:),app.DisplayScale);
            margin=max(40,6*radius);
            xlim(app.ImageAxes,[max(0.5,xy(1)-margin),min(size(app.ImageData,2)+0.5,xy(1)+margin)]);
            ylim(app.ImageAxes,[max(0.5,xy(2)-margin),min(size(app.ImageData,1)+0.5,xy(2)+margin)]);
            app.setStatus(sprintf('Colony %d selected. Click Show whole plate above the image to zoom back out.',id));
        end

        function showWholePlate(app)
            % View-only action: keep the live boundary editor and all labels.
            if app.Busy || strlength(app.MarkingMode)>0 || isempty(app.ImageData), return; end
            if ~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI)
                roi=app.BoundaryROI;
                ellipse=[roi.Center roi.SemiAxes roi.RotationAngle];
            else
                ellipse=app.displayEllipse();
            end
            [limitsX,limitsY]=app.fittedViewLimits(ellipse);
            xlim(app.ImageAxes,limitsX); ylim(app.ImageAxes,limitsY);
            if ~app.Dirty && ~isempty(app.Result)
                app.setStatus('Whole plate view. Click a review row to inspect a colony.');
            end
        end

        function choosePlateBoundary(app)
            % One boundary both selects the plate and defines the counting area.
            if app.Busy || strlength(app.MarkingMode)>0 || isempty(app.ImageData), return; end
            if ~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI)
                app.finishBoundary(); app.drawImage(false); app.configureEnable();
                if app.Dirty || isempty(app.Result)
                    app.setStatus('Boundary chosen. Click Apply and classify to count inside it. Fit to rim can refine the outline.');
                else
                    app.setStatus('Boundary unchanged. Current counts and labels kept.');
                end
                return
            end
            app.editBoundary();
        end

        function selectPlate(app)
            % Backward-compatible MATLAB method; the UI has one boundary button.
            app.choosePlateBoundary();
        end

        function fitImage(app)
            % Refine the selected boundary, including an offset rough ellipse.
            if app.Busy || strlength(app.MarkingMode)>0 || isempty(app.ImageData), return; end
            editing=~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI);
            if editing
                roi=app.BoundaryROI; ellipse=[roi.Center roi.SemiAxes roi.RotationAngle];
            else
                ellipse=app.displayEllipse();
            end
            if isempty(ellipse)
                app.editBoundary();
                if isempty(app.BoundaryROI) || ~isvalid(app.BoundaryROI), return; end
                roi=app.BoundaryROI; ellipse=[roi.Center roi.SemiAxes roi.RotationAngle];
                editing=true;
            end
            app.LastError=[]; app.Busy=true; app.configureEnable();
            app.Buttons.View.Text='Fitting rim...';
            cleanup=onCleanup(@()app.finishBusy()); %#ok<NASGU>
            app.setStatus('Fitting the boundary to the selected plate rim...'); drawnow;
            try
                [fitted,info]=fit_plate_boundary(app.ImageData,ellipse);
                if ~info.Fitted
                    app.setStatus(info.Message,true); return
                end
                if ~editing, app.editBoundary(); end
                roi=app.BoundaryROI;
                roi.Center=fitted(1:2); roi.SemiAxes=fitted(3:4); roi.RotationAngle=fitted(5);
                [limitsX,limitsY]=app.fittedViewLimits(fitted);
                xlim(app.ImageAxes,limitsX); ylim(app.ImageAxes,limitsY);
                app.setStatus([info.Message ' Click Done boundary, then Apply and classify.']);
            catch err
                app.LastError=err;
                app.setStatus(['Could not fit the rim: ' err.message],true);
            end
        end

        function applySettings(app)
            if app.Busy || strlength(app.MarkingMode)>0 || strlength(app.ImageFile)==0, return; end
            app.finishBoundary(); app.LastError=[]; app.Busy=true; app.configureEnable();
            cleanup=onCleanup(@()app.finishBusy());
            try
                if exist('rgb2lab','file')~=2
                    error('CFU:MissingToolbox','Classification requires Image Processing Toolbox.');
                end
                if strcmp(app.UIFigure.Visible,'on')
                    app.Progress=uiprogressdlg(app.UIFigure,'Title','Colony Counter', ...
                        'Message','Preparing image...','Indeterminate','on');
                end
                drawnow;
                options=app.Options;
                app.setStatus('Detecting and classifying colonies...');
                app.progressMessage('Detecting colonies and checking classifications...'); drawnow;
                result=count_colonies(app.ImageFile,options);
                [result,carried,lost]=prepare_colony_app_result(result,app.Result);
                % Commit a complete run together, so errors cannot mix counts,
                % settings and an overlay from different analyses.
                result.EstimationInfo=app.EstimationInfo;
                app.Result=result; app.Options=options;
                app.ImageData=result.Image; app.DisplayScale=result.Scale;
                app.Dirty=false; app.SelectedID=[]; app.syncControls(); app.drawImage(false);
                s=result.Summary;
                app.refreshCounts(); app.refreshTable();
                message=sprintf('Complete · %d colonies · %d need review. Edit labels in Review colonies.', ...
                    s.Total,s.FlaggedForReview);
                if result.ClassificationInfo.Mode=="size_fallback" && s.Total>0
                    message=sprintf('Complete · %d candidates · %d need review. Size reference used: too few clean examples of both groups.', ...
                        s.Total,s.FlaggedForReview);
                end
                if s.NotAColony>0, message=sprintf('%s %d excluded as Not a colony.',message,s.NotAColony); end
                if carried>0, message=sprintf('%s %d manual labels retained.',message,carried); end
                if lost>0, message=sprintf('%s %d previous corrections could not be retained; review the new detections.',message,lost); end
                app.setStatus(message);
            catch err
                app.LastError=err; app.Dirty=true;
                app.setStatus(['Could not classify: ' err.message],true);
                if strcmp(app.UIFigure.Visible,'on')
                    uialert(app.UIFigure,err.message,'Classification could not finish');
                end
            end
            clear cleanup
        end

        function beginMarking(app,id)
            % Stage individual centers without changing counts until confirmed.
            app.requireNoMarking();
            if app.Busy || isempty(app.Result) || app.Dirty
                error('CFU:PendingSettings','Click Apply and classify before marking colonies.');
            end
            if nargin<2, id=app.SelectedID; end
            if isempty(id), error('CFU:MissingID','Select a merged object in the image or table first.'); end
            validate_colony_centers(app.Result,id,zeros(0,2));
            app.MarkingStartView=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
            app.selectColony(id,true);
            app.MarkingMode="split"; app.MarkingRadii=zeros(0,1);
            app.MarkingParent=id; app.MarkingCenters=zeros(0,2);
            app.MarkingLabels=strings(0,1); app.MarkingSelected=[];
            app.createMarkingEditor(); app.configureEnable();
            app.setStatus(sprintf('Marking object %d: click each colony center in the image, assign labels, then Confirm marks.',id));
        end

        function beginAdding(app)
            % Preserve the current zoom: the missed neighbor may be tiny.
            app.requireNoMarking();
            if app.Busy || isempty(app.Result) || app.Dirty
                error('CFU:PendingSettings','Click Apply and classify before adding missed colonies.');
            end
            app.MarkingStartView=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
            app.MarkingMode="add"; app.MarkingParent=[];
            app.MarkingCenters=zeros(0,2); app.MarkingRadii=zeros(0,1);
            app.MarkingLabels=strings(0,1); app.MarkingSelected=[];
            app.createMarkingEditor(); app.configureEnable();
            app.setStatus('Click missed colony centers in the image, assign labels, then Confirm additions.');
        end

        function addMarkedCenter(app,point,label,radius)
            if strlength(app.MarkingMode)==0, error('CFU:NotMarking','Start Mark individual colonies or Add missed colony first.'); end
            if nargin<3, label=app.MarkingLabel.Value; end
            label=string(label);
            if ~isscalar(label) || ~ismember(label,["Need review","AD9","AD24"])
                error('CFU:InvalidClass','Choose Need review, AD9, or AD24 for a new mark.');
            end
            validateattributes(point,{'numeric'},{'vector','numel',2,'finite','real'});
            points=[app.MarkingCenters;reshape(point,1,2)];
            if app.MarkingMode=="add"
                if nargin<4, radius=app.MarkingRadius.Value; end
                validateattributes(radius,{'numeric'},{'scalar','finite','positive','real', ...
                    '<=',max(size(app.Result.Labels))/app.DisplayScale});
                validate_missed_colony_centers(app.Result,points);
            else
                validate_colony_centers(app.Result,app.MarkingParent,points);
                radius=NaN;
            end
            app.MarkingRadii(end+1,1)=radius;
            app.MarkingCenters=points; app.MarkingLabels(end+1,1)=label;
            app.MarkingSelected=size(points,1); app.refreshMarking();
        end

        function confirmMarking(app)
            if strlength(app.MarkingMode)==0, return; end
            parent=app.MarkingParent; adding=app.MarkingMode=="add";
            if adding
                [result,ids]=add_missed_colonies(app.Result,app.MarkingCenters,app.MarkingLabels,app.MarkingRadii);
            else
                [result,ids]=mark_colony_group(app.Result,'replace',parent,app.MarkingCenters,app.MarkingLabels);
            end
            app.endMarking(false); app.Result=result; app.SelectedID=ids(1);
            app.ReviewOnly.Value=false; app.ShowCircles.Value=true;
            app.refreshCounts(); app.refreshTable(); app.drawImage(true); app.configureEnable();
            app.highlightTableRow(true);
            if adding
                app.setStatus(sprintf('Added %d missed colonies. Counts updated. Edit labels in Review colonies; Not a colony excludes a mistaken addition.',numel(ids)));
            else
                app.setStatus(sprintf('Object %d replaced by %d individual colonies. Edit their labels in Review colonies; Undo marks restores the original.',parent,numel(ids)));
            end
        end

        function cancelMarking(app)
            if strlength(app.MarkingMode)==0, return; end
            app.endMarking(true); app.configureEnable();
            app.setStatus('Marking canceled. Colony labels and counts are unchanged.');
        end

        function restoreMarkedColonies(app,id)
            app.requireNoMarking();
            if app.Busy || isempty(app.Result) || app.Dirty
                error('CFU:PendingSettings','Click Apply and classify before undoing marks.');
            end
            if nargin<2, id=app.SelectedID; end
            if isempty(id), error('CFU:MissingID','Select an individual mark first.'); end
            [app.Result,parent]=mark_colony_group(app.Result,'restore',id);
            app.SelectedID=parent; app.ReviewOnly.Value=false;
            app.refreshCounts(); app.refreshTable(); app.drawImage(true); app.configureEnable();
            app.highlightTableRow(true);
            app.setStatus(sprintf('Restored original object %d and its previous label. Individual marks and their counts removed.',parent));
        end

        function files=saveResults(app,folder)
            app.requireNoMarking();
            if app.Busy, error('CFU:Busy','Wait for the current operation to finish before saving.'); end
            if isempty(app.Result) || app.Dirty
                error('CFU:PendingSettings','Click Apply and classify before saving the current settings.');
            end
            app.Busy=true; app.configureEnable();
            cleanup=onCleanup(@()app.finishBusy()); %#ok<NASGU>
            app.setStatus('Saving the workbook and annotated image...'); drawnow;
            try
                state=struct('ImageStartingOptions',app.ImageStartingOptions, ...
                    'ManualParameterNames',{app.ManualParameterNames});
                files=save_colony_app_results(app.Result,folder,state);
            catch err
                app.setStatus(['Could not save results: ' err.message],true);
                rethrow(err);
            end
            [~,book,bookExt]=fileparts(files.Workbook); [~,picture,pictureExt]=fileparts(files.Annotated);
            app.setStatus(sprintf('Saved %s%s and %s%s in %s.',book,bookExt,picture,pictureExt,char(folder)));
        end

        function exportPreview(app,file)
            % Allow the web-based UI layout to settle after a window resize.
            drawnow; pause(1); drawnow; exportapp(app.UIFigure,file);
        end

        function delete(app)
            app.ResumeLease=[];
            if ~isempty(app.MarkingFigure) && isgraphics(app.MarkingFigure), delete(app.MarkingFigure); end
            if ~isempty(app.UIFigure) && isgraphics(app.UIFigure), delete(app.UIFigure); end
        end
    end
    methods (Access=private)
        function requireNoMarking(app)
            if strlength(app.MarkingMode)>0
                error('CFU:MarkingActive','Confirm or cancel individual colony marks first.');
            end
        end

        function createMarkingEditor(app)
            pos=app.UIFigure.Position; adding=app.MarkingMode=="add";
            title=sprintf('Mark individual colonies · Object %d',app.MarkingParent);
            instruction='Click each colony center in the image. Assign a label to every mark. Confirm replaces the original object; counts stay unchanged until then.';
            rows={52,28,'1x',26,44,30,34}; editorHeight=440;
            if adding
                title='Add missed colonies'; editorHeight=478;
                instruction='Click each missed colony center. Choose its label and adjust its circle radius if needed. Counts change only when you confirm.';
                rows={52,28,28,'1x',26,44,30,34};
            end
            app.MarkingFigure=uifigure('Name',title, ...
                'Position',[pos(1)+pos(3)-410 pos(2)+pos(4)-editorHeight-60 390 editorHeight], ...
                'Visible',app.UIFigure.Visible,'WindowStyle','alwaysontop', ...
                'CloseRequestFcn',@(~,~)app.cancelMarking());
            grid=uigridlayout(app.MarkingFigure,[numel(rows) 1],'RowHeight',rows, ...
                'Padding',[12 12 12 12],'RowSpacing',8);
            uilabel(grid,'Text',instruction, ...
                'WordWrap','on','FontSize',11);
            picker=uigridlayout(grid,[1 2],'ColumnWidth',{118,'1x'},'Padding',[0 0 0 0]);
            uilabel(picker,'Text','Label for new marks','FontSize',11);
            app.MarkingLabel=uidropdown(picker,'Items',{'Need review','AD9','AD24'},'Value','Need review');
            columnNames={'Mark','Label'}; editable=[false true]; widths={60,'auto'};
            formats={'numeric',{'Need review','AD9','AD24'}};
            if adding
                radiusPicker=uigridlayout(grid,[1 2],'ColumnWidth',{118,'1x'},'Padding',[0 0 0 0]);
                uilabel(radiusPicker,'Text','New circle radius (px)','FontSize',11);
                radii=app.Result.Colonies.EnclosingRadiusPixels;
                radius=median(radii(isfinite(radii) & radii>0));
                if ~isfinite(radius), radius=5/app.DisplayScale; end
                app.MarkingRadius=uieditfield(radiusPicker,'numeric','Value',radius, ...
                    'Limits',[0.5 max(size(app.Result.Labels))/app.DisplayScale], ...
                    'ValueDisplayFormat','%.1f','Tooltip','Original-image pixels. You can edit each circle radius in the table.');
                columnNames{3}='Radius (px)'; editable(3)=true; widths={48,'auto',85}; formats{3}='numeric';
            end
            app.MarkingTable=uitable(grid,'Data',cell(0,numel(columnNames)),'ColumnName',columnNames, ...
                'RowName',{},'ColumnEditable',editable,'ColumnWidth',widths, ...
                'ColumnFormat',formats, ...
                'CellEditCallback',@(~,event)app.markLabelEdited(event), ...
                'CellSelectionCallback',@(~,event)app.markSelected(event));
            app.MarkingCounts=uilabel(grid,'Text','','FontWeight','bold','FontSize',11);
            app.MarkingHint=uilabel(grid,'Text','','WordWrap','on','FontSize',11);
            app.MarkingButtons.Remove=uibutton(grid,'Text','Remove selected mark', ...
                'ButtonPushedFcn',@(~,~)app.removeMarkedCenter());
            actions=uigridlayout(grid,[1 2],'ColumnWidth',{'1x','1x'},'Padding',[0 0 0 0]);
            app.MarkingButtons.Confirm=uibutton(actions,'Text','Confirm marks', ...
                'BackgroundColor',[0.08 0.36 0.67],'FontColor','w', ...
                'ButtonPushedFcn',@(~,~)app.confirmMarking());
            if adding, app.MarkingButtons.Confirm.Text='Confirm additions'; end
            app.MarkingButtons.Cancel=uibutton(actions,'Text','Cancel','ButtonPushedFcn',@(~,~)app.cancelMarking());
            app.refreshMarking();
        end

        function refreshMarking(app)
            n=size(app.MarkingCenters,1);
            if isprop(app.MarkingTable,'Selection'), app.MarkingTable.Selection=[]; end
            data=[num2cell((1:n)'),cellstr(app.MarkingLabels)];
            if app.MarkingMode=="add", data=[data,num2cell(app.MarkingRadii)]; end
            app.MarkingTable.Data=data;
            removeStyle(app.MarkingTable);
            if ~isempty(app.MarkingSelected)
                addStyle(app.MarkingTable,app.SelectedRowStyle,'row',app.MarkingSelected);
            end
            app.MarkingCounts.Text=sprintf('%d marks · %d AD9 · %d AD24 · %d need review',n, ...
                sum(app.MarkingLabels=="AD9"),sum(app.MarkingLabels=="AD24"),sum(app.MarkingLabels=="Need review"));
            app.MarkingHint.Text='Mark at least two centers. Double-click a label to change it; select a mark to remove it.';
            app.MarkingHint.FontColor=[0.27 0.33 0.41];
            required=2;
            if app.MarkingMode=="add"
                required=1;
                app.MarkingHint.Text='Double-click a label or radius to edit it. Select a mark to remove it. Confirm adds these entries to the counts.';
            end
            app.MarkingButtons.Confirm.Enable=app.onoff(n>=required);
            app.MarkingButtons.Remove.Enable=app.onoff(~isempty(app.MarkingSelected));
            delete(findobj(app.ImageAxes,'Tag','MarkDraft'));
            palette=colony_annotation_styles(); theta=linspace(0,2*pi,49);
            xy=(app.MarkingCenters-0.5)*app.DisplayScale+0.5;
            for k=1:n
                c=find(palette.Labels==app.MarkingLabels(k)); color=palette.Colors(c,:);
                if app.MarkingMode=="add"
                    radius=max(1.5,app.MarkingRadii(k)*app.DisplayScale);
                    if c==3, radius=radius+3; end
                elseif n>1
                    d=hypot(xy(:,1)-xy(k,1),xy(:,2)-xy(k,2)); d(k)=Inf;
                    radius=max(1.5,min(6,0.4*min(d)));
                else, radius=6;
                end
                plot(app.ImageAxes,xy(k,1)+radius*cos(theta),xy(k,2)+radius*sin(theta), ...
                    'Color',[0.05 0.05 0.05],'LineWidth',3,'Tag','MarkDraft','HitTest','off','PickableParts','none');
                plot(app.ImageAxes,xy(k,1)+radius*cos(theta),xy(k,2)+radius*sin(theta), ...
                    'Color',color,'LineWidth',1.4,'Tag','MarkDraft','HitTest','off','PickableParts','none');
                plot(app.ImageAxes,xy(k,1),xy(k,2),'+','Color',color,'MarkerSize',8, ...
                    'Tag','MarkDraft','HitTest','off','PickableParts','none');
                text(app.ImageAxes,xy(k,1)+radius+1,xy(k,2),sprintf('%d',k), ...
                    'Color',color,'BackgroundColor',[0.05 0.05 0.05],'Margin',1,'FontWeight','bold', ...
                    'Tag','MarkDraft','HitTest','off','PickableParts','none');
            end
        end

        function markLabelEdited(app,event)
            if isempty(event.Indices), return; end
            row=event.Indices(1); column=event.Indices(2);
            if column==2
                label=string(event.NewData);
                if ~ismember(label,["Need review","AD9","AD24"]), app.refreshMarking(); return; end
                app.MarkingLabels(row)=label;
            elseif column==3 && app.MarkingMode=="add"
                radius=event.NewData;
                if ~isnumeric(radius) || ~isscalar(radius) || ~isfinite(radius) || radius<=0 || ...
                        radius>max(size(app.Result.Labels))/app.DisplayScale
                    app.refreshMarking();
                    app.MarkingHint.Text='Enter a positive circle radius smaller than the image size.';
                    app.MarkingHint.FontColor=[0.72 0.15 0.12]; return
                end
                app.MarkingRadii(row)=radius;
            else, return;
            end
            app.MarkingSelected=row; app.refreshMarking();
        end

        function markSelected(app,event)
            if isempty(event.Indices), return; end
            app.MarkingSelected=event.Indices(1); app.MarkingButtons.Remove.Enable='on';
        end

        function removeMarkedCenter(app)
            row=app.MarkingSelected; if isempty(row), return; end
            app.MarkingCenters(row,:)=[]; app.MarkingLabels(row,:)=[]; app.MarkingRadii(row,:)=[]; app.MarkingSelected=[];
            app.refreshMarking();
        end

        function endMarking(app,restoreView)
            app.MarkingMode=""; app.MarkingRadii=zeros(0,1);
            app.MarkingParent=[]; app.MarkingCenters=zeros(0,2); app.MarkingLabels=strings(0,1);
            app.MarkingSelected=[];
            if ~isempty(app.MarkingFigure) && isgraphics(app.MarkingFigure), delete(app.MarkingFigure); end
            app.MarkingFigure=[];
            delete(findobj(app.ImageAxes,'Tag','MarkDraft'));
            if restoreView && ~isempty(app.MarkingStartView)
                xlim(app.ImageAxes,app.MarkingStartView(1:2)); ylim(app.ImageAxes,app.MarkingStartView(3:4));
            end
            app.MarkingStartView=[];
        end

        function createComponents(app)
            bg=[0.95 0.96 0.98]; ink=[0.12 0.18 0.26]; blue=[0.08 0.36 0.67];
            app.UIFigure=uifigure('Visible','off','Name','Colony Counter · AD9 / AD24', ...
                'Position',[60 60 1320 880],'Color',bg,'CloseRequestFcn',@(~,~)app.closeRequested(), ...
                'WindowButtonDownFcn',@(~,~)app.startPanelResize());
            root=uigridlayout(app.UIFigure,[3 2],'RowHeight',{58,'1x',42}, ...
                'ColumnWidth',{'1x',410},'Padding',[16 12 16 8],'ColumnSpacing',14,'RowSpacing',10);
            header=uigridlayout(root,[1 2],'ColumnWidth',{'1x',410},'Padding',[0 0 0 0]);
            header.Layout.Row=1; header.Layout.Column=[1 2];
            titleGrid=uigridlayout(header,[2 1],'RowHeight',{30,22},'Padding',[0 0 0 0],'RowSpacing',0);
            uilabel(titleGrid,'Text','Colony Counter','FontSize',25,'FontWeight','bold','FontColor',ink);
            uilabel(titleGrid,'Text','AD9 / AD24  ·  Detect, classify and review your plate','FontSize',12,'FontColor',[0.4 0.45 0.52]);
            fileHeader=uigridlayout(header,[1 2],'ColumnWidth',{'1x',146},'Padding',[0 0 0 0]);
            app.ImageLabel=uilabel(fileHeader,'Text','Open an image to begin','HorizontalAlignment','right', ...
                'FontSize',12,'FontColor',[0.4 0.45 0.52],'WordWrap','on');
            app.Buttons.LoadResults=uibutton(fileHeader,'Text','Open saved results', ...
                'ButtonPushedFcn',@(~,~)app.openResultsDialog(), ...
                'Tooltip','Open a colonies.xlsx workbook and continue reviewing saved work.');

            imagePanel=uipanel(root,'BackgroundColor','w','BorderType','line');
            imagePanel.Layout.Row=2; imagePanel.Layout.Column=1;
            imageGrid=uigridlayout(imagePanel,[5 1],'RowHeight',{36,32,'1x',30,26},'Padding',[12 12 12 8],'RowSpacing',6);
            toolbar=uigridlayout(imageGrid,[1 4],'ColumnWidth',{'1x','1.5x','0.8x','1.2x'},'Padding',[0 0 0 0]);
            app.Buttons.Load=uibutton(toolbar,'Text','Open image','ButtonPushedFcn',@(~,~)app.openDialog());
            app.Buttons.Boundary=uibutton(toolbar,'Text','Choose plate boundary', ...
                'ButtonPushedFcn',@(~,~)app.choosePlateBoundary(), ...
                'Tooltip','Show the full photo. Move/resize the yellow boundary around the plate to count.');
            app.Buttons.View=uibutton(toolbar,'Text','Fit to rim','ButtonPushedFcn',@(~,~)app.fitImage(), ...
                'Tooltip','Fit the yellow ellipse to the nearby plate rim. Keep its center inside the desired plate; a small cropped rim section can be estimated.');
            app.Buttons.WholePlate=uibutton(toolbar,'Text','Show whole plate', ...
                'ButtonPushedFcn',@(~,~)app.showWholePlate(), ...
                'Tooltip','Zoom out to show the selected plate. Keeps the boundary, settings and colony labels.');
            app.BoundaryHint=uilabel(imageGrid,'Text','','WordWrap','on', ...
                'FontSize',11,'FontColor',[0.4 0.45 0.52]);
            app.BoundaryHint.Layout.Row=2;
            app.ImageAxes=uiaxes(imageGrid,'Color',[0.97 0.97 0.97],'XTick',[],'YTick',[],'Box','off');
            app.ImageAxes.Layout.Row=3; app.ImageAxes.Toolbar.Visible='on';
            app.ImageAxes.XColor='none'; app.ImageAxes.YColor='none';
            legendGrid=uigridlayout(imageGrid,[1 3],'ColumnWidth',{'2x','1x','1x'},'Padding',[8 0 0 0]);
            uilabel(legendGrid,'Text','◌  Need review (white / black)','FontColor',[0.15 0.15 0.15],'FontWeight','bold');
            uilabel(legendGrid,'Text','○  AD9','FontColor',[0 0.52 0.66],'FontWeight','bold');
            uilabel(legendGrid,'Text','○  AD24','FontColor',[0.85 0.4 0],'FontWeight','bold');
            displayGrid=uigridlayout(imageGrid,[1 3],'ColumnWidth',{'1x','1x','1x'},'Padding',[8 0 0 0]);
            app.ShowCircles=uicheckbox(displayGrid,'Text','Show circles','Value',true,'ValueChangedFcn',@(~,~)app.drawImage(true));
            app.ReviewOnly=uicheckbox(displayGrid,'Text','Review only','Value',false,'ValueChangedFcn',@(~,~)app.reviewFilterChanged());
            app.ReviewOnly.Tooltip='Show only unresolved colonies in both the image and the label table.';
            app.ShowIDs=uicheckbox(displayGrid,'Text','Colony IDs','Value',false,'ValueChangedFcn',@(~,~)app.drawImage(true));

            side=uipanel(root,'BackgroundColor','w','BorderType','line'); side.Layout.Row=2; side.Layout.Column=2;
            panel=uigridlayout(side,[4 1],'RowHeight',{75,'1x',42,34},'Padding',[12 12 12 12],'RowSpacing',8);
            cards=uigridlayout(panel,[1 3],'ColumnWidth',{'1x','1x','1x'},'Padding',[0 0 0 0]);
            app.CountLabels.Review=app.countCard(cards,'Need review',[0.15 0.15 0.15]);
            app.CountLabels.AD9=app.countCard(cards,'AD9',[0.0 0.52 0.66]);
            app.CountLabels.AD24=app.countCard(cards,'AD24',[0.85 0.4 0]);
            % Pixel positions inside this container allow a draggable split;
            % the outer grid keeps counts and action buttons at fixed heights.
            app.PanelContainer=uipanel(panel,'BorderType','none','BackgroundColor','w', ...
                'AutoResizeChildren','off');
            app.PanelContainer.Layout.Row=2;
            app.ReviewPanel=uipanel(app.PanelContainer,'Title','Review colonies', ...
                'FontWeight','bold','BackgroundColor','w','Units','pixels');
            reviewGrid=uigridlayout(app.ReviewPanel,[3 1],'RowHeight',{42,'1x',30},'Padding',[8 6 8 8],'RowSpacing',4);
            app.ReviewHelp=uilabel(reviewGrid,'Text', ...
                'Click a circle to find its row; click a row to zoom. Double-click a label to edit. Need review comes first.', ...
                'WordWrap','on','FontSize',11);
            app.ColonyTable=uitable(reviewGrid,'Data',cell(0,2),'ColumnName',{'Colony ID','Label'}, ...
                'RowName',{},'ColumnEditable',[false true], ...
                'ColumnFormat',{'numeric',{'Need review','AD9','AD24','Not a colony'}},'ColumnWidth',{85,'auto'}, ...
                'CellEditCallback',@(~,event)app.labelEdited(event), ...
                'CellSelectionCallback',@(~,event)app.tableSelected(event));
            markToolbar=uigridlayout(reviewGrid,[1 3],'ColumnWidth',{'1.6x','1.3x','0.9x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',6);
            markToolbar.Layout.Row=3;
            app.Buttons.Mark=uibutton(markToolbar,'Text','Mark individual colonies','FontSize',11, ...
                'ButtonPushedFcn',@(~,~)app.beginMarking(), ...
                'Tooltip','Select a merged object, then mark and label each colony center.');
            app.Buttons.Add=uibutton(markToolbar,'Text','Add missed colony','FontSize',11, ...
                'ButtonPushedFcn',@(~,~)app.beginAdding(), ...
                'Tooltip','Click an undetected colony center, choose its label and circle size, then confirm.');
            app.Buttons.UndoMarks=uibutton(markToolbar,'Text','Undo marks','FontSize',11, ...
                'ButtonPushedFcn',@(~,~)app.restoreMarkedColonies(), ...
                'Tooltip','Select an individual mark to restore its original merged object.');
            app.SelectedRowStyle=uistyle('BackgroundColor',[1 0.96 0.72]);
            app.PanelDivider=uilabel(app.PanelContainer,'Text','', ...
                'BackgroundColor',[0.84 0.86 0.90], ...
                'Tooltip','Drag up for more settings space, or down for more review rows.');
            app.SettingsPanel=uipanel(app.PanelContainer,'Title','Counting settings', ...
                'FontWeight','bold','BackgroundColor','w','Units','pixels');
            settingsGrid=uigridlayout(app.SettingsPanel,[3 1],'RowHeight',{28,'1x',32}, ...
                'Padding',[8 6 8 6],'RowSpacing',4);
            settingsHeader=uigridlayout(settingsGrid,[1 2],'ColumnWidth',{'1x',126},'Padding',[0 0 0 0]);
            uilabel(settingsHeader,'Text','Edit values as needed.','FontSize',11);
            app.Buttons.Reset=uibutton(settingsHeader,'Text','Reset to defaults','FontSize',11, ...
                'ButtonPushedFcn',@(~,~)app.restoreDefaults(), ...
                'Tooltip','Restore the values estimated for this plate. Keeps the boundary and does not run classification; then click Apply and classify.');
            tabs=uitabgroup(settingsGrid); tabs.Layout.Row=2; app.Tabs=tabs;
            app.SettingsHint=uilabel(settingsGrid,'Text','','WordWrap','on','FontSize',11, ...
                'FontColor',[0.4 0.45 0.52]);
            app.SettingsHint.Layout.Row=3;
            for tabName=["Detection","Classification","Advanced"]
                tab=uitab(tabs,'Title',char(tabName));
                specs=app.Schema(strcmp({app.Schema.Tab},tabName));
                extra=0;
                if tabName=="Detection", extra=1; elseif tabName=="Classification", extra=2; end
                heights=[repmat({64},1,numel(specs)),repmat({34},1,extra),{'1x'}];
                grid=uigridlayout(tab,[numel(heights) 1],'RowHeight',heights, ...
                    'Scrollable','on','Padding',[12 12 12 8],'RowSpacing',6);
                for i=1:numel(specs), app.parameterControl(grid,specs(i)); end
                if tabName=="Detection"
                    app.Controls.SplitTouchingColonies=uicheckbox(grid,'Text','Separate attached colonies','Value',true, ...
                        'ValueChangedFcn',@(src,~)app.setParameter('SplitTouchingColonies',src.Value));
                elseif tabName=="Classification"
                    app.Controls.ResolveAmbiguousClassification=uicheckbox(grid,'Text','Use interior color for difficult cases','Value',true, ...
                        'ValueChangedFcn',@(src,~)app.setParameter('ResolveAmbiguousClassification',src.Value));
                    uilabel(grid,'Text','Size, color and shape weights are learned from this plate.', ...
                        'WordWrap','on','FontSize',11,'FontColor',[0.4 0.45 0.52]);
                end
            end
            app.Buttons.Apply=uibutton(panel,'Text','Apply and classify','FontSize',15,'FontWeight','bold', ...
                'BackgroundColor',blue,'FontColor','w','ButtonPushedFcn',@(~,~)app.applySettings(), ...
                'Tooltip','Run colony detection and classification with the displayed settings and selected boundary.');
            app.Buttons.Apply.Layout.Row=3;
            app.Buttons.Save=uibutton(panel,'Text','Save results','ButtonPushedFcn',@(~,~)app.saveDialog());
            app.Buttons.Save.Layout.Row=4;
            app.StatusLabel=uilabel(root,'Text','Open an image to begin.','WordWrap','on','FontSize',11,'FontColor',ink);
            app.StatusLabel.Layout.Row=3; app.StatusLabel.Layout.Column=[1 2];
            app.PanelContainer.SizeChangedFcn=@(~,~)app.layoutPanels();
            app.layoutPanels();
        end

        function layoutPanels(app,reviewHeight)
            % Retain the chosen proportion as the main window changes size.
            bounds=app.PanelContainer.InnerPosition;
            width=max(1,bounds(3)); height=max(3,bounds(4));
            dividerHeight=min(6,height/3);
            available=height-dividerHeight;
            % Keep both sections usable; shrink together only in tiny windows.
            scale=min(1,available/390);
            minimumReview=180*scale; minimumSettings=210*scale;
            if nargin<2, reviewHeight=available*app.ReviewPanelFraction; end
            reviewHeight=min(available-minimumSettings,max(minimumReview,reviewHeight));
            if nargin>=2, app.ReviewPanelFraction=reviewHeight/available; end
            settingsHeight=available-reviewHeight;
            app.SettingsPanel.Position=[1 1 width settingsHeight];
            app.PanelDivider.Position=[1 settingsHeight+1 width dividerHeight];
            app.ReviewPanel.Position=[1 settingsHeight+dividerHeight+1 width reviewHeight];
        end

        function startPanelResize(app)
            if app.Busy || ~isempty(app.PanelDrag) || ~strcmp(app.UIFigure.SelectionType,'normal'), return; end
            point=app.UIFigure.CurrentPoint;
            box=getpixelposition(app.PanelDivider,true);
            if any(point<box(1:2)) || any(point>box(1:2)+box(3:4)), return; end
            % Figure-level callbacks also receive gestures over the drag label.
            % Preserve existing motion/up callbacks used by other interactions.
            app.PanelDrag=struct('StartY',point(2),'ReviewHeight',app.ReviewPanel.Position(4), ...
                'Motion',app.UIFigure.WindowButtonMotionFcn,'Up',app.UIFigure.WindowButtonUpFcn, ...
                'Pointer',app.UIFigure.Pointer);
            app.UIFigure.WindowButtonMotionFcn=@(~,~)app.dragPanelResize();
            app.UIFigure.WindowButtonUpFcn=@(~,~)app.finishPanelResize();
            app.UIFigure.Pointer='top';
        end

        function dragPanelResize(app)
            if isempty(app.PanelDrag), return; end
            point=app.UIFigure.CurrentPoint;
            app.layoutPanels(app.PanelDrag.ReviewHeight-(point(2)-app.PanelDrag.StartY));
        end

        function finishPanelResize(app)
            if isempty(app.PanelDrag), return; end
            app.dragPanelResize();
            previous=app.PanelDrag; app.PanelDrag=[];
            app.UIFigure.WindowButtonMotionFcn=previous.Motion;
            app.UIFigure.WindowButtonUpFcn=previous.Up;
            app.UIFigure.Pointer=previous.Pointer;
        end

        function label=countCard(~,parent,titleText,color)
            card=uipanel(parent,'BackgroundColor',[0.96 0.97 0.99],'BorderType','none');
            grid=uigridlayout(card,[2 1],'RowHeight',{22,'1x'},'Padding',[10 6 10 6],'RowSpacing',0);
            uilabel(grid,'Text',titleText,'FontSize',11,'FontWeight','bold','FontColor',color);
            label=uilabel(grid,'Text','—','FontSize',30,'FontWeight','bold','FontColor',[0.12 0.18 0.26]);
        end

        function parameterControl(app,parent,spec)
            grid=uigridlayout(parent,[2 2],'RowHeight',{24,28},'ColumnWidth',{'1x',78}, ...
                'Padding',[0 0 0 0],'RowSpacing',6);
            uilabel(grid,'Text',spec.Label,'FontSize',11,'Tooltip',spec.Tip);
            limits=[spec.Minimum spec.Maximum]*spec.Factor;
            edit=uieditfield(grid,'numeric','Limits',limits,'Value',app.Options.(spec.Name)*spec.Factor, ...
                'ValueDisplayFormat','%.3g','Tooltip',spec.Tip, ...
                'ValueChangedFcn',@(src,~)app.setParameter(spec.Name,src.Value/spec.Factor));
            if strcmp(spec.Name,'MaxImageDimension'), edit.ValueDisplayFormat='%.0f'; end
            slider=uislider(grid,'Limits',limits,'Value',edit.Value,'MajorTicks',[],'MinorTicks',[], ...
                'Tooltip',spec.Tip,'ValueChangedFcn',@(src,~)app.setParameter(spec.Name,src.Value/spec.Factor), ...
                'ValueChangingFcn',@(~,event)set(edit,'Value',event.Value));
            slider.Layout.Row=2; slider.Layout.Column=[1 2];
            app.Controls.(spec.Name)=struct('Slider',slider,'Edit',edit);
        end

        function syncControls(app)
            for k=1:numel(app.Schema)
                spec=app.Schema(k);
                value=app.Options.(spec.Name)*spec.Factor;
                app.Controls.(spec.Name).Slider.Value=value; app.Controls.(spec.Name).Edit.Value=value;
            end
            app.Controls.SplitTouchingColonies.Value=app.Options.SplitTouchingColonies;
            app.Controls.ResolveAmbiguousClassification.Value=app.Options.ResolveAmbiguousClassification;
        end

        function configureEnable(app)
            loaded=strlength(app.ImageFile)>0; active=~app.Busy && strlength(app.MarkingMode)==0;
            for name=fieldnames(app.Buttons)'
                app.Buttons.(name{1}).Enable=app.onoff(active);
            end
            for name={'Apply','Boundary','View','WholePlate'}
                app.Buttons.(name{1}).Enable=app.onoff(active && loaded);
            end
            app.Buttons.Save.Enable=app.onoff(active && ~isempty(app.Result) && ~app.Dirty);
            ready=active && ~isempty(app.Result) && ~app.Dirty && ~isempty(app.SelectedID);
            canMark=false; canUndo=false;
            if ready
                T=app.Result.Colonies; row=find(T.ID==app.SelectedID,1);
                if ~isempty(row)
                    canMark=T.Source(row)~="manual_mark" && any(app.Result.Labels(:)==app.SelectedID);
                    canUndo=T.Source(row)=="manual_mark";
                end
            end
            app.Buttons.Add.Enable=app.onoff(active && ~isempty(app.Result) && ~app.Dirty);
            app.Buttons.Mark.Enable=app.onoff(canMark);
            app.Buttons.UndoMarks.Enable=app.onoff(canUndo);
            for k=1:numel(app.Schema)
                spec=app.Schema(k);
                app.Controls.(spec.Name).Slider.Enable=app.onoff(active);
                app.Controls.(spec.Name).Edit.Enable=app.onoff(active);
            end
            app.Controls.SplitTouchingColonies.Enable=app.onoff(active);
            app.Controls.ResolveAmbiguousClassification.Enable=app.onoff(active);
            app.ShowCircles.Enable=app.onoff(active); app.ReviewOnly.Enable=app.onoff(active);
            app.ShowIDs.Enable=app.onoff(active);
            app.ColonyTable.Enable=app.onoff(active && ~isempty(app.Result) && ~app.Dirty);
            if ~loaded
                app.BoundaryHint.Text='Open a photo, then choose the boundary of the plate to count.';
            elseif ~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI)
                app.BoundaryHint.Text='Outline one plate; Fit to rim can refine it. Check the yellow ellipse, then click Done boundary.';
            elseif ~isempty(app.Options.PlateEllipse)
                app.BoundaryHint.Text='The yellow boundary selects the plate and counting area. Everything outside it is excluded.';
            elseif (~isempty(app.Result) && ~app.Dirty) || ~isempty(app.proposedEllipse())
                app.BoundaryHint.Text='Boundary found automatically. The yellow outline is locked; use Choose plate boundary or Fit to rim to adjust it.';
            else
                app.BoundaryHint.Text='Initial yellow outline only: a plate was not detected. Use Choose plate boundary or Fit to rim to set it.';
            end
            if ~loaded
                app.SettingsHint.Text='Open an image to apply these settings.';
            elseif app.Dirty
                app.SettingsHint.Text='Changes pending. Apply and classify to update the counts.';
            elseif isempty(app.Result)
                app.SettingsHint.Text='Settings ready. Apply and classify to count colonies.';
            else
                app.SettingsHint.Text='Current counts use the displayed settings.';
            end
        end

        function drawImage(app,keepView)
            if isempty(app.ImageData), return; end
            app.finishBoundary();
            ax=app.ImageAxes; oldX=xlim(ax); oldY=ylim(ax);
            cla(ax); image(ax,app.ImageData); axis(ax,'image'); axis(ax,'off'); hold(ax,'on');
            ax.Toolbar.Visible='on';
            if ~isempty(app.Result)
                if app.ShowCircles.Value && ~app.Dirty
                    draw_colony_overlay(ax,app.Result,app.ShowIDs.Value,app.ReviewOnly.Value);
                end
                if ~app.Dirty && ~isempty(app.SelectedID)
                    T=app.Result.Colonies; row=find(T.ID==app.SelectedID,1);
                    if ~isempty(row)
                        xy=([T.X(row),T.Y(row)]-0.5)*app.DisplayScale+0.5;
                        radius=max(4,colony_circle_radii(T(row,:),app.DisplayScale))+3;
                        theta=linspace(0,2*pi,80);
                        plot(ax,xy(1)+radius*cos(theta),xy(2)+radius*sin(theta), ...
                            'Color',[1 1 0.2],'LineWidth',1.6,'Tag','SelectedColony','UserData',struct('ID',app.SelectedID));
                        text(ax,xy(1)+radius+2,xy(2),sprintf('ID %d',app.SelectedID), ...
                            'Color',[1 1 0.2],'FontSize',11,'FontWeight','bold','Tag','SelectedColony', ...
                            'UserData',struct('ID',app.SelectedID));
                    end
                end
            end
            ellipse=app.displayEllipse();
            if ~isempty(ellipse), app.plotEllipse(ellipse); end
            for handle=reshape(ax.Children,1,[])
                if isgraphics(handle,'image') || ismember(string(handle.Tag), ...
                        ["ColonyCircles","ColonyWarning","ColonyWarningOutline","ColonyID","SelectedColony"])
                    handle.ButtonDownFcn=@(source,event)app.imageColonyClicked(source,event);
                end
            end
            if keepView
                xlim(ax,oldX); ylim(ax,oldY);
            else
                [limitsX,limitsY]=app.fittedViewLimits(ellipse);
                xlim(ax,limitsX); ylim(ax,limitsY);
            end
        end

        function imageColonyClicked(app,source,event)
            if strlength(app.MarkingMode)>0
                if ~strcmp(app.UIFigure.SelectionType,'normal'), return; end
                point=(event.IntersectionPoint(1:2)-0.5)/app.DisplayScale+0.5;
                try
                    app.addMarkedCenter(point);
                catch err
                    app.MarkingHint.Text=err.message;
                    app.MarkingHint.FontColor=[0.72 0.15 0.12];
                end
                return
            end
            if app.Busy || app.Dirty || isempty(app.Result) || ~app.ShowCircles.Value || ...
                    ~strcmp(app.UIFigure.SelectionType,'normal'), return; end
            data=source.UserData; candidates=[];
            if isstruct(data) && isfield(data,'ID') && isgraphics(source,'text')
                id=data.ID;
            else
                if isstruct(data) && isfield(data,'IDs'), candidates=data.IDs; end
                if isstruct(data) && isfield(data,'ID'), candidates=data.ID; end
                if strcmp(source.Tag,'ColonyWarningOutline')
                    candidates=app.Result.Colonies.ID(app.Result.Colonies.NeedsReview);
                end
                onBoundary=ismember(string(source.Tag),["ColonyCircles","ColonyWarning","ColonyWarningOutline","SelectedColony"]);
                id=colony_at_point(app.Result,event.IntersectionPoint,app.ReviewOnly.Value,candidates,onBoundary);
            end
            if isempty(id), return; end
            T=app.Result.Colonies; row=find(T.ID==id,1);
            if isempty(row) || T.Class(row)=="Not a colony" || (app.ReviewOnly.Value && ~T.NeedsReview(row)), return; end
            app.selectColony(id,false);
        end

        function highlightTableRow(app,reveal)
            % Highlight independently of native cell selection. This keeps
            % image clicks from invoking the table's zoom-to-colony action.
            removeStyle(app.ColonyTable);
            if isempty(app.SelectedID), return; end
            row=find(cell2mat(app.ColonyTable.Data(:,1))==app.SelectedID,1);
            if isempty(row), return; end
            addStyle(app.ColonyTable,app.SelectedRowStyle,'row',row);
            if reveal
                if isprop(app.ColonyTable,'Selection'), app.ColonyTable.Selection=[]; end
                scroll(app.ColonyTable,'row',row);
            end
        end

        function ellipse=displayEllipse(app)
            ellipse=app.Options.PlateEllipse;
            if isempty(ellipse) && ~isempty(app.Result) && ~app.Dirty
                ellipse=app.Result.CountingEllipseWork; return
            end
            if isempty(ellipse), ellipse=app.proposedEllipse(); end
            if isempty(ellipse)
                % A visible, locked starting outline is still useful when
                % the image has too little evidence for automatic detection.
                % It is not accepted as a counting ROI until Done boundary.
                if ~isempty(app.ImageData)
                    h=size(app.ImageData,1); w=size(app.ImageData,2);
                    ellipse=[w/2 h/2 .3*min(h,w) .3*min(h,w) 0];
                end
                return
            end
            ellipse(1:2)=(ellipse(1:2)-0.5)*app.DisplayScale+0.5;
            ellipse(3:4)=ellipse(3:4)*app.DisplayScale;
        end

        function ellipse=proposedEllipse(app)
            % Original pixels, shared by the initial overlay and rim seed.
            ellipse=[];
            if isstruct(app.EstimationInfo) && isfield(app.EstimationInfo,'ProposedEllipse')
                ellipse=app.EstimationInfo.ProposedEllipse;
            end
        end

        function [limitsX,limitsY]=fittedViewLimits(app,ellipse)
            limitsX=[0.5 size(app.ImageData,2)+0.5];
            limitsY=[0.5 size(app.ImageData,1)+0.5];
            if isempty(ellipse), return; end
            angle=deg2rad(ellipse(5)); a=ellipse(3); b=ellipse(4);
            % True extents of a rotated ellipse, with a small viewing margin.
            % A square based on its larger radius wastes space for oval plates.
            halfWidth=1.04*hypot(a*cos(angle),b*sin(angle));
            halfHeight=1.04*hypot(a*sin(angle),b*cos(angle));
            x=[max(limitsX(1),ellipse(1)-halfWidth),min(limitsX(2),ellipse(1)+halfWidth)];
            y=[max(limitsY(1),ellipse(2)-halfHeight),min(limitsY(2),ellipse(2)+halfHeight)];
            if x(2)>x(1) && y(2)>y(1), limitsX=x; limitsY=y; end
        end

        function plotEllipse(app,e)
            theta=linspace(0,2*pi,300); a=deg2rad(e(5));
            u=e(3)*cos(theta); v=e(4)*sin(theta);
            plot(app.ImageAxes,e(1)+u*cos(a)+v*sin(a),e(2)-u*sin(a)+v*cos(a), ...
                '-','Color',[1 0.88 0.15],'LineWidth',1,'Tag','PlateBoundary','HitTest','off','PickableParts','none');
        end

        function editBoundary(app)
            if exist('drawellipse','file')~=2
                uialert(app.UIFigure,'Image Processing Toolbox is needed to edit the plate boundary.','Toolbox required'); return
            end
            h=size(app.ImageData,1); w=size(app.ImageData,2);
            existing=~isempty(app.Options.PlateEllipse) || (~isempty(app.Result) && ~app.Dirty) || ...
                ~isempty(app.proposedEllipse());
            e=app.displayEllipse();
            app.BoundaryStartOptions=app.Options.PlateEllipse;
            app.BoundaryStartDirty=app.Dirty;
            if existing, app.BoundaryStartEllipse=e; else, app.BoundaryStartEllipse=[]; end
            app.Dirty=true; app.drawImage(false);
            % Preserve an existing boundary while revealing every plate, so
            % adjusting this plate and moving to another use the same control.
            xlim(app.ImageAxes,[0.5 w+0.5]); ylim(app.ImageAxes,[0.5 h+0.5]);
            delete(findobj(app.ImageAxes,'Tag','PlateBoundary'));
            app.BoundaryROI=drawellipse(app.ImageAxes,'Center',e(1:2),'SemiAxes',e(3:4), ...
                'RotationAngle',e(5),'Color',[1 0.88 0.15]);
            app.Buttons.Boundary.Text='Done boundary'; app.configureEnable();
            app.setStatus('The boundary selects the plate. Move/resize it around the usable agar, then click Done boundary.');
        end

        function finishBoundary(app)
            if isempty(app.BoundaryROI) || ~isvalid(app.BoundaryROI), return; end
            roi=app.BoundaryROI;
            e=[roi.Center roi.SemiAxes roi.RotationAngle];
            unchanged=app.sameOptions(struct('Ellipse',e),struct('Ellipse',app.BoundaryStartEllipse));
            if unchanged
                app.Options.PlateEllipse=app.BoundaryStartOptions; app.Dirty=app.BoundaryStartDirty;
            else
                e(1:2)=(e(1:2)-0.5)/app.DisplayScale+0.5; e(3:4)=e(3:4)/app.DisplayScale;
                app.Options.PlateEllipse=e; app.Dirty=true;
            end
            app.clearBoundary(); app.configureEnable();
            if ~unchanged, app.estimateSettings(); end
        end

        function estimateSettings(app)
            % Estimate on load / changed plate only. Explicit user edits stay
            % in force within this image; Apply never changes displayed values.
            previous=app.Options;
            app.Busy=true; app.configureEnable();
            cleanup=onCleanup(@()app.finishBusy());
            app.setStatus('Estimating settings from the plate pixels...'); drawnow;
            try
                [estimated,info]=estimate_colony_settings(app.ImageFile,previous.PlateEllipse);
                app.ImageStartingOptions=estimated; app.Options=estimated;
                for name=app.ManualParameterNames
                    app.Options.(name{1})=previous.(name{1});
                end
                app.EstimationInfo=info; app.syncControls();
                message=info.Message+" Check the boundary and settings, then click Apply and classify.";
                if ~isempty(app.ManualParameterNames)
                    message=message+" Your manually edited values were kept.";
                end
                app.setStatus(message);
            catch err
                app.LastError=err;
                % Opening/selecting a plate remains possible if its image has
                % too little usable evidence or the toolbox is unavailable.
                app.Options=previous; app.ImageStartingOptions=previous;
                app.EstimationInfo=struct('Estimated',false,'Message',string(err.message));
                app.setStatus(['Could not estimate settings: ' err.message],true);
            end
            clear cleanup
        end

        function clearBoundary(app)
            if ~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI), delete(app.BoundaryROI); end
            app.BoundaryROI=[];
            app.BoundaryStartEllipse=[]; app.BoundaryStartOptions=[]; app.BoundaryStartDirty=false;
            if isfield(app.Buttons,'Boundary'), app.Buttons.Boundary.Text='Choose plate boundary'; end
        end

        function restoreDefaults(app)
            if app.Busy || strlength(app.MarkingMode)>0, return; end
            defaults=app.ImageStartingOptions;
            if isempty(defaults), defaults=colony_defaults(); end
            defaults.PlateEllipse=app.Options.PlateEllipse;
            app.ManualParameterNames={};
            if app.sameOptions(app.Options,defaults)
                app.setStatus('Estimated values are already shown. Click Apply and classify to run.'); return
            end
            app.Options=defaults; app.syncControls(); app.markDirty();
            app.setStatus('Estimated values restored for this plate. Click Apply and classify to update the counts.');
        end

        function markDirty(app)
            % Parameter changes made during boundary editing must remain
            % pending even if the ellipse itself was not moved.
            if ~isempty(app.BoundaryROI) && isvalid(app.BoundaryROI), app.BoundaryStartDirty=true; end
            app.Dirty=true; app.configureEnable();
            app.setStatus('Settings changed. Click Apply and classify to update the image and counts.');
        end

        function setStatus(app,message,isError)
            if nargin<3, isError=false; end
            app.StatusLabel.Text=message;
            if isError, app.StatusLabel.FontColor=[0.72 0.15 0.12];
            else, app.StatusLabel.FontColor=[0.27 0.33 0.41]; end
        end

        function progressMessage(app,message)
            if ~isempty(app.Progress) && isvalid(app.Progress), app.Progress.Message=message; end
        end

        function finishBusy(app)
            if ~isempty(app.Progress) && isvalid(app.Progress), close(app.Progress); end
            app.Progress=[]; app.Busy=false; app.Buttons.View.Text='Fit to rim'; app.configureEnable();
        end

        function openDialog(app)
            [file,folder]=uigetfile({ ...
                '*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp;*.heic;*.heif;*.JPG;*.JPEG;*.PNG;*.TIF;*.TIFF;*.BMP;*.HEIC;*.HEIF','All plate photographs'; ...
                '*.heic;*.heif;*.HEIC;*.HEIF','HEIC / HEIF photographs'; ...
                '*.png;*.PNG','PNG images'; ...
                '*.jpg;*.jpeg;*.JPG;*.JPEG','JPEG photographs'; ...
                '*.tif;*.tiff;*.bmp;*.TIF;*.TIFF;*.BMP','TIFF / BMP images'; ...
                '*.*','All files'},'Open plate image');
            if isequal(file,0), return; end
            try
                app.loadImage(fullfile(folder,file));
            catch err
                uialert(app.UIFigure,err.message,'Could not open image');
            end
        end

        function openResultsDialog(app)
            [file,folder]=uigetfile('*.xlsx','Open saved colony results');
            if isequal(file,0), return; end
            workbook=fullfile(folder,file);
            try
                app.loadResults(workbook);
            catch err
                if strcmp(err.identifier,'CFU:OriginalImageRequired')
                    [photo,path]=uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp;*.heic;*.heif','Original plate photo'; ...
                        '*.*','All files'},err.message,folder);
                    if isequal(photo,0), return; end
                    try
                        app.loadResults(workbook,fullfile(path,photo));
                    catch retry
                        uialert(app.UIFigure,retry.message,'Could not open saved results');
                    end
                else
                    uialert(app.UIFigure,err.message,'Could not open saved results');
                end
            end
        end

        function saveDialog(app)
            startFolder=fileparts(char(app.ImageFile));
            if strlength(app.ResultsFolder)>0, startFolder=char(app.ResultsFolder); end
            folder=uigetdir(startFolder,'Save the Excel workbook and annotated PNG here');
            if isequal(folder,0), return; end
            try
                app.saveResults(folder);
            catch err
                uialert(app.UIFigure,err.message,'Could not save results');
            end
        end

        function refreshCounts(app)
            s=app.Result.Summary;
            app.CountLabels.AD9.Text=string(s.AD9); app.CountLabels.AD24.Text=string(s.AD24);
            app.CountLabels.Review.Text=string(s.FlaggedForReview);
        end

        function refreshTable(app)
            if isprop(app.ColonyTable,'Selection'), app.ColonyTable.Selection=[]; end
            removeStyle(app.ColonyTable);
            if isempty(app.Result), app.ColonyTable.Data=cell(0,2); return; end
            T=app.Result.Colonies;
            if app.ReviewOnly.Value, T=T(T.NeedsReview,:); end
            labels=T.Class; labels(T.NeedsReview)="Need review";
            % Sort the displayed rows, not the stored colony/segmentation IDs.
            % Label edits refresh this grouping and remain keyed by colony ID.
            [~,group]=ismember(labels,["Need review","AD9","AD24","Not a colony"]);
            [~,order]=sortrows([group,double(T.ID)],[1 2]);
            app.ColonyTable.Data=[num2cell(T.ID(order)),cellstr(labels(order))];
            app.highlightTableRow(false);
        end

        function reviewFilterChanged(app)
            app.refreshTable(); app.drawImage(true);
        end

        function labelEdited(app,event)
            if isempty(event.Indices) || event.Indices(2)~=2, return; end
            id=app.ColonyTable.Data{event.Indices(1),1};
            try
                app.setColonyLabel(id,string(event.NewData));
            catch err
                app.refreshTable(); app.setStatus(err.message,true);
            end
        end

        function tableSelected(app,event)
            if isempty(event.Indices), return; end
            row=event.Indices(1,1);
            if row<=size(app.ColonyTable.Data,1), app.selectColony(app.ColonyTable.Data{row,1}); end
        end

        function closeRequested(app)
            if app.Busy, app.setStatus('Analysis is running. You can close the app when it finishes.');
            else, delete(app); end
        end
    end
    methods (Static,Access=private)
        function same=sameOptions(a,b)
            names=fieldnames(a); same=isequal(sort(names),sort(fieldnames(b)));
            if ~same, return; end
            for k=1:numel(names)
                left=a.(names{k}); right=b.(names{k});
                if isequaln(left,right), continue; end
                % UI percentage conversions and ellipse coordinate round trips
                % can differ by a few floating-point units without a real edit.
                if isnumeric(left) && isnumeric(right) && isequal(size(left),size(right)) && ...
                        all(isfinite(left(:))) && all(isfinite(right(:)))
                    tolerance=32*eps(max(1,max(abs(double(left)),abs(double(right)))));
                    if all(abs(double(left(:))-double(right(:)))<=tolerance(:)), continue; end
                end
                same=false; return
            end
        end

        function value=onoff(flag)
            value='off'; if flag, value='on'; end
        end
    end
end

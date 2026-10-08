function smoke_panel_resize_ui(outputFolder)
%SMOKE_PANEL_RESIZE_UI Drag the actual divider in a populated native window.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(app.Result.Summary.Total>250 && app.Result.Summary.Total<400);
data=app.ColonyTable.Data; counts=app.Result.Summary;
expected=[repmat("Need review",counts.Uncertain,1);repmat("AD9",counts.AD9,1);repmat("AD24",counts.AD24,1)];
assert(isequal(string(data(:,2)),expected),'Review rows must precede AD9 and AD24 rows.');
for label=["Need review","AD9","AD24"]
 ids=cell2mat(data(string(data(:,2))==label,1));assert(issorted(ids));
end
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'app_main.png'));
assert(app.PanelDivider.Position(4)<=6);
assert(isequal(app.ColonyTable.ColumnFormat{2},{'Need review','AD9','AD24','Not a colony'}));
assert(app.CountLabels.Review.Parent.Parent.Layout.Column==1);
assert(app.CountLabels.AD9.Parent.Parent.Layout.Column==2);
assert(app.CountLabels.AD24.Parent.Parent.Layout.Column==3);
before=app.Result; options=app.Options;
applyBox=getpixelposition(app.Buttons.Apply,true);
saveBox=getpixelposition(app.Buttons.Save,true);

% Down enlarges Review; up enlarges Settings by the same amount.
oldReview=app.ReviewPanel.Position(4); oldSettings=app.SettingsPanel.Position(4);
dragDivider(tc,app,-75);
assert(abs(app.ReviewPanel.Position(4)-oldReview-75)<2);
assert(abs(app.SettingsPanel.Position(4)-oldSettings+75)<2);
app.exportPreview(fullfile(outputFolder,'app_review_expanded.png'));
oldReview=app.ReviewPanel.Position(4); oldSettings=app.SettingsPanel.Position(4);
dragDivider(tc,app,130);
assert(abs(app.ReviewPanel.Position(4)-oldReview+130)<2);
assert(abs(app.SettingsPanel.Position(4)-oldSettings-130)<2);
app.exportPreview(fullfile(outputFolder,'app_settings_expanded.png'));
assert(isequal(getpixelposition(app.Buttons.Apply,true),applyBox));
assert(isequal(getpixelposition(app.Buttons.Save,true),saveBox));
assert(isequaln(app.Result,before) && isequaln(app.Options,options) && ~app.Dirty);

% Neither panel can consume all the space. Releasing restores other callbacks.
motion=@(~,~)[]; up=@(~,~)[];
app.UIFigure.WindowButtonMotionFcn=motion; app.UIFigure.WindowButtonUpFcn=up;
pointer=app.UIFigure.Pointer;
dragDivider(tc,app,250);
assert(abs(app.ReviewPanel.Position(4)-180)<1);
dragDivider(tc,app,-400);
assert(abs(app.SettingsPanel.Position(4)-210)<1);
assert(isequal(app.UIFigure.WindowButtonMotionFcn,motion));
assert(isequal(app.UIFigure.WindowButtonUpFcn,up));
assert(strcmp(app.UIFigure.Pointer,pointer));

% Window resizing retains the selected ratio, with the same minimum heights.
available=app.ReviewPanel.Position(4)+app.SettingsPanel.Position(4);
dragDivider(tc,app,app.ReviewPanel.Position(4)-0.44*available);
ratio=app.ReviewPanel.Position(4)/available;
app.UIFigure.Position(3:4)=[1120 760]; settle();
available=app.ReviewPanel.Position(4)+app.SettingsPanel.Position(4);
assert(abs(app.ReviewPanel.Position(4)/available-ratio)<0.005);
assert(app.ReviewPanel.Position(4)>=180 && app.SettingsPanel.Position(4)>=210);
app.exportPreview(fullfile(outputFolder,'app_compact.png'));
app.UIFigure.Position(3:4)=[1320 880]; settle();
available=app.ReviewPanel.Position(4)+app.SettingsPanel.Position(4);
assert(abs(app.ReviewPanel.Position(4)/available-ratio)<0.005);

% Dropdown edits and pending settings survive resizing; no analysis is run.
id=app.ColonyTable.Data{1,1};
choose_colony_label_ui(tc,app,id,'Need review');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="Uncertain");
choose_colony_label_ui(tc,app,id,'AD24');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="AD24");
choose_colony_label_ui(tc,app,id,'AD9');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="AD9");
choose_colony_label_ui(tc,app,id,'Not a colony');
assert(app.Result.Colonies.Class(app.Result.Colonies.ID==id)=="Not a colony");
app.setParameter('PinkContrastThreshold',0.065);
before=app.Result; options=app.Options;
dragDivider(tc,app,50);
assert(isequaln(app.Result,before) && isequaln(app.Options,options) && app.Dirty);
assert(strcmp(app.Buttons.Save.Enable,'off') && strcmp(app.ColonyTable.Enable,'off'));

% Resizing also works during ellipse editing without accepting the boundary.
tc.press(app.Buttons.Boundary);
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
assert(numel(roi)==1); center=roi.Center; axes=roi.SemiAxes;
dragDivider(tc,app,-50);
assert(isvalid(roi) && isequal(roi.Center,center) && isequal(roi.SemiAxes,axes));
assert(strcmp(app.Buttons.Boundary.Text,'Done boundary'));
tc.press(app.Buttons.Boundary); assert(app.Dirty);
fprintf('Panel resize UI passed: both drag directions, limits, window resize, label ordering/edits, pending settings and boundary editing.\n');
end

function dragDivider(tc,app,deltaY)
settle();
box=getpixelposition(app.PanelDivider,true);
point=box(1:2)+box(3:4)/2;
tc.drag(app.UIFigure,point,point+[0 deltaY]);
settle();
end

function settle()
drawnow; pause(0.3); drawnow;
end

function smoke_section_navigation_ui(outputFolder)
%SMOKE_SECTION_NAVIGATION_UI Exercise actual navigation buttons on a real plate.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
app=ColonyCounterApp; cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
% Keep IDs on while traversing sections and colony close-ups to inspect clipping.
app.ShowIDs.Value=true; feval(app.ShowIDs.ValueChangedFcn,app.ShowIDs,[]);
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
original=app.Result; options=app.Options; whole=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
app.exportPreview(fullfile(outputFolder,'whole_plate.png'));
views=zeros(9,4);
for n=1:9
    tc.press(app.Buttons.NextSection);
    views(n,:)=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
    assert(contains(app.Buttons.NextSection.Tooltip,sprintf('Current section: %d of 9',n)));
    assert(isequaln(app.Result,original) && isequaln(app.Options,options) && ~app.Dirty);
    if n==1
        first=[xlim(app.ImageAxes) ylim(app.ImageAxes)];
        app.exportPreview(fullfile(outputFolder,'section_1.png'));
    elseif n==5
        app.exportPreview(fullfile(outputFolder,'section_5.png'));
    end
end
for n=8:-1:1
    tc.press(app.Buttons.PreviousSection);
    assert(isequal([xlim(app.ImageAxes) ylim(app.ImageAxes)],views(n,:)));
end
tc.press(app.Buttons.PreviousSection);
assert(isequal([xlim(app.ImageAxes) ylim(app.ImageAxes)],views(9,:)));
tc.press(app.Buttons.NextSection);
assert(isequal([xlim(app.ImageAxes) ylim(app.ImageAxes)],first));
T=app.Result.Colonies; xy=([T.X,T.Y]-.5)*app.Result.Scale+.5;
inView=xy(:,1)>first(1) & xy(:,1)<first(2) & xy(:,2)>first(3) & xy(:,2)<first(4);
id=T.ID(find(inView,1)); row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
tc.choose(app.ColonyTable,[row 1]);
assert(diff(xlim(app.ImageAxes))<diff(first(1:2)));
app.exportPreview(fullfile(outputFolder,'colony_zoom.png'));
app.setColonyLabel(id,'AD24'); before=app.Result;
tc.press(app.Buttons.NextSection); assert(contains(app.Buttons.NextSection.Tooltip,'Current section: 2 of 9'));
app.exportPreview(fullfile(outputFolder,'section_2.png'));
assert(isequaln(app.Result,before));
tc.press(app.Buttons.WholePlate);
assert(isequal([xlim(app.ImageAxes) ylim(app.ImageAxes)],whole));
assert(strcmp(app.Buttons.NextSection.Text,'Next section >'));
app.UIFigure.Position(3:4)=[1120 760]; drawnow;
tc.press(app.Buttons.NextSection); assert(contains(app.Buttons.NextSection.Tooltip,'Current section: 1 of 9'));
left=getpixelposition(app.Buttons.PreviousSection,true);
right=getpixelposition(app.Buttons.NextSection,true);
wholeButton=getpixelposition(app.Buttons.WholePlate,true);
assert(abs(left(3)-right(3))<=1); % Equal halves, allowing pixel rounding.
assert(abs(left(1)+left(3)-right(1))<=1); % Shared seam, without a gap.
assert(left(1)>=wholeButton(1)+wholeButton(3));
tc.press(app.Buttons.PreviousSection); assert(contains(app.Buttons.PreviousSection.Tooltip,'Current section: 9 of 9'));
tc.press(app.Buttons.NextSection); assert(contains(app.Buttons.NextSection.Tooltip,'Current section: 1 of 9'));
app.exportPreview(fullfile(outputFolder,'section_compact.png'));
fprintf('SECTION_UI: nine sections in both directions, wraparound, table zoom, label edit, whole view reset and equal touching button halves on compact toolbar passed.\n');
end

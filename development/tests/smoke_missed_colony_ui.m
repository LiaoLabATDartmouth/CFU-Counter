function smoke_missed_colony_ui(outputFolder)
% Native gestures over a faint synthetic spot below the detector threshold.
if nargin<1, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
I=im2single(imread(file)); [x,y]=meshgrid(1:size(I,2),1:size(I,1));
point=[194 390]; mask=(x-point(1)).^2+(y-point(2)).^2<=4^2;
color=lin2rgb(rgb2lin(single([.62 .37 .34]))*1.14);
for c=1:3, channel=I(:,:,c); channel(mask)=color(c); I(:,:,c)=channel; end
imwrite(I,file);
app=ColonyCounterApp(file); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.setPlateBoundary([300 300 255 255 0]);
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
work=(point-.5)*app.Result.Scale+.5; p=round(work);
assert(app.Result.Labels(p(2),p(1))==0,'The synthetic faint center must be undetected.');
T=app.Result.Colonies; [~,near]=min(hypot(T.X-point(1),T.Y-point(2)));
app.selectColony(T.ID(near)); view=[xlim(app.ImageAxes) ylim(app.ImageAxes)]; before=app.Result;
tc.press(app.Buttons.Add); settle();
assert(isequal([xlim(app.ImageAxes) ylim(app.ImageAxes)],view));
tc.choose(app.MarkingLabel,'AD9'); tc.type(app.MarkingRadius,5);
tc.press(app.ImageAxes,work); settle();
assert(size(app.MarkingTable.Data,1)==1 && app.MarkingTable.Data{1,3}==5);
assert(isequaln(app.Result,before));
% Repeated clicks and existing centers cannot silently create duplicates.
tc.press(app.ImageAxes,work); settle(); assert(size(app.MarkingTable.Data,1)==1);
tc.press(app.ImageAxes,([T.X(near) T.Y(near)]-.5)*app.Result.Scale+.5);
settle(); assert(size(app.MarkingTable.Data,1)==1);
tc.choose(app.MarkingTable,[1 2],'AD24'); settle();
assert(string(app.MarkingTable.Data{1,2})=="AD24");
tc.choose(app.MarkingTable,[1 2],'AD9'); settle();
app.exportPreview(fullfile(outputFolder,'app_missed_preview.png'));
exportapp(app.MarkingFigure,fullfile(outputFolder,'app_missed_editor.png'));
tc.press(app.MarkingButtons.Confirm); settle();
assert(app.Result.Summary.AD9==before.Summary.AD9+1);
assert(app.Result.Summary.Total==before.Summary.Total+1);
assert(isequal(app.Result.Labels,before.Labels));
id=app.Result.Colonies.ID(end);
tc.press(app.ImageAxes,work); settle();
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
assert(isequal(app.ColonyTable.StyleConfigurations.TargetIndex{1},row));
app.exportPreview(fullfile(outputFolder,'app_missed_added.png'));
choose_colony_label_ui(tc,app,id,'Not a colony');
assert(app.Result.Summary.Total==before.Summary.Total);
choose_colony_label_ui(tc,app,id,'AD9');
tc.press(app.Buttons.WholePlate); tc.press(app.Buttons.Apply);
assert(isempty(app.LastError)); assert(app.Result.Summary.AD9==before.Summary.AD9+1);
assert(sum(app.Result.Colonies.Source=="manual_add")==1);
% Cancel leaves all counts unchanged; the tool also works with no row selected.
before=app.Result; tc.press(app.Buttons.Add); tc.press(app.MarkingButtons.Cancel);
assert(isequaln(app.Result,before));
fprintf('Missed-colony UI passed: native center clicks, radius input, labels, duplicate rejection, counts, selection, exclusion, retention and cancel.\n');
% Refresh the packaged example preview without any manual corrections.
app.loadImage(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'Examples','IMG_7489.jpeg'));
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(app.Result.Summary.Total>250 && app.Result.Summary.Total<400);
app.exportPreview(fullfile(outputFolder,'app_main.png'));
app.UIFigure.Position(3:4)=[1120 760];
app.exportPreview(fullfile(outputFolder,'app_compact.png'));
end
function settle()
drawnow; pause(.3); drawnow;
end

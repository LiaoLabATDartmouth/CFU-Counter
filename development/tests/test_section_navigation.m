function tests=test_section_navigation
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testEmptyAppAndUnclassifiedPhoto(tc)
app=ColonyCounterApp('','off'); close=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEqual(tc,string(app.Buttons.NextSection.Enable),"off");
verifyEqual(tc,string(app.Buttons.PreviousSection.Enable),"off");
before=view(app); app.showNextSection(); app.showPreviousSection(); verifyEqual(tc,view(app),before);
[file,lease]=marking_fixture(); %#ok<ASGLU>
app.loadImage(file); original=app.Options; before=view(app);
verifyEqual(tc,string(app.Buttons.NextSection.Enable),"on");
verifyEqual(tc,string(app.Buttons.PreviousSection.Enable),"on");
pressNext(app); verifyEmpty(tc,app.Result); verifyEqual(tc,app.Options,original);
verifyLessThan(tc,diff(xlim(app.ImageAxes)),diff(before(1:2))/2);
verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 1 of 9'));
end
function testNineViewsCoverPlateInOrderWithoutChangingAnalysis(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
app.setColonyLabel(app.Result.Colonies.ID(1),'Need review');
app.ReviewOnly.Value=true; feval(app.ReviewOnly.ValueChangedFcn,app.ReviewOnly,[]);
app.ShowIDs.Value=true; feval(app.ShowIDs.ValueChangedFcn,app.ShowIDs,[]);
app.showWholePlate(); whole=view(app);
original=app.Result; options=app.Options; rows=app.ColonyTable.Data;
objects=app.ImageAxes.Children;
views=zeros(9,4);
for n=1:9
    pressNext(app); views(n,:)=view(app);
    verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,sprintf('Current section: %d of 9',n)));
    verifyEqual(tc,app.Result,original); verifyEqual(tc,app.Options,options);
    verifyEqual(tc,app.ColonyTable.Data,rows); verifyFalse(tc,app.Dirty);
    verifyEqual(tc,app.ImageAxes.Children,objects);
    verifyTrue(tc,app.ReviewOnly.Value && app.ShowIDs.Value);
    verifyEqual(tc,string(app.Buttons.Save.Enable),"on");
end
% Every row moves left-to-right; successive rows move downward in the image.
centers=[mean(views(:,1:2),2),mean(views(:,3:4),2)];
for row=1:3
    ids=(row-1)*3+(1:3);
    verifyTrue(tc,all(diff(centers(ids,1))>0));
    verifyEqual(tc,centers(ids,2),repmat(centers(ids(1),2),3,1),'AbsTol',1e-9);
    verifyGreaterThanOrEqual(tc,views(ids(1:2),2),views(ids(2:3),1));
end
for col=1:3
    ids=col:3:9;
    verifyTrue(tc,all(diff(centers(ids,2))>0));
    verifyEqual(tc,centers(ids,1),repmat(centers(ids(1),1),3,1),'AbsTol',1e-9);
    verifyGreaterThanOrEqual(tc,views(ids(1:2),4),views(ids(2:3),3));
end
verifyEqual(tc,[min(views(:,1)),max(views(:,2)),min(views(:,3)),max(views(:,4))],whole,'AbsTol',1e-9);
verifyLessThan(tc,views(:,2)-views(:,1),repmat(diff(whole(1:2))/2,9,1));
verifyLessThan(tc,views(:,4)-views(:,3),repmat(diff(whole(3:4))/2,9,1));
pressNext(app); verifyEqual(tc,view(app),views(1,:),'AbsTol',1e-9);
app.showWholePlate(); verifyEqual(tc,view(app),whole);
verifyEqual(tc,string(app.Buttons.NextSection.Text),"Next section >");
pressNext(app); verifyEqual(tc,view(app),views(1,:),'AbsTol',1e-9);
end
function testPreviousRevisitsSameViewsAndWrapsBothWays(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
original=app.Result; options=app.Options; views=zeros(9,4);
for n=1:9, pressNext(app); views(n,:)=view(app); end
for n=8:-1:1
    pressPrevious(app);
    verifyEqual(tc,view(app),views(n,:),'AbsTol',1e-9);
    verifyTrue(tc,contains(app.Buttons.PreviousSection.Tooltip,sprintf('Current section: %d of 9',n)));
    verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,sprintf('Current section: %d of 9',n)));
end
pressPrevious(app); verifyEqual(tc,view(app),views(9,:));
pressNext(app); verifyEqual(tc,view(app),views(1,:));
app.showWholePlate(); pressPrevious(app); verifyEqual(tc,view(app),views(9,:));
app.showWholePlate(); pressNext(app); verifyEqual(tc,view(app),views(1,:));
% Colony-size inspection does not lose the section cursor in either direction.
app.selectColony(app.Result.Colonies.ID(1));
pressPrevious(app); verifyEqual(tc,view(app),views(9,:));
verifyEqual(tc,app.Result,original); verifyEqual(tc,app.Options,options);
verifyFalse(tc,app.Dirty);
end
function testSectionUnionCoversEveryPixelForRotatedAndClippedPlates(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
app.choosePlateBoundary(); roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
ellipses=[300 300 255 255 0; 300 300 250 150 37; ...
          120 260 250 170 35; 490 460 230 140 110; 300 300 285 75 90];
original=app.Result; options=app.Options;
for k=1:size(ellipses,1)
    e=ellipses(k,:); roi.Center=e(1:2); roi.SemiAxes=e(3:4); roi.RotationAngle=e(5);
    app.showWholePlate(); whole=view(app);
    [x,y]=meshgrid(ceil(whole(1)):floor(whole(2)),ceil(whole(3)):floor(whole(4)));
    covered=false(size(x)); views=zeros(9,4);
    for n=1:9
        pressNext(app); v=view(app); views(n,:)=v;
        covered=covered | (x>=v(1) & x<=v(2) & y>=v(3) & y<=v(4));
    end
    verifyTrue(tc,all(covered(:)),sprintf('Uncovered plate pixels for ellipse %d.',k));
    % Check exact outer extents and continuous seams, including between pixels.
    verifyEqual(tc,[min(views(:,1)) max(views(:,2)) min(views(:,3)) max(views(:,4))],whole);
    for row=0:2
        ids=row*3+(1:3);
        verifyGreaterThanOrEqual(tc,views(ids(1:2),2),views(ids(2:3),1));
    end
    for col=1:3
        ids=col:3:9;
        verifyGreaterThanOrEqual(tc,views(ids(1:2),4),views(ids(2:3),3));
    end
    for n=8:-1:1
        pressPrevious(app); verifyEqual(tc,view(app),views(n,:));
    end
end
verifyEqual(tc,app.Result,original); verifyEqual(tc,app.Options,options);
end
function testImageTableEditsAndColonyZoomKeepSequence(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
pressNext(app); section=view(app);
T=app.Result.Colonies; [~,k]=min(hypot(T.X-180,T.Y-180)); id=T.ID(k);
point=([T.X(k) T.Y(k)]-.5)*app.Result.Scale+.5;
picture=findobj(app.ImageAxes,'Type','image');
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
verifyEqual(tc,app.ColonyTable.StyleConfigurations.TargetIndex{1},row);
verifyEqual(tc,view(app),section);
feval(app.ColonyTable.CellEditCallback,app.ColonyTable,struct('Indices',[row 2],'NewData','AD24'));
verifyEqual(tc,app.Result.Colonies.Class(app.Result.Colonies.ID==id),"AD24");
verifyEqual(tc,view(app),section);
verifyEqual(tc,str2double(app.CountLabels.AD24.Text),app.Result.Summary.AD24);
app.ShowIDs.Value=true; feval(app.ShowIDs.ValueChangedFcn,app.ShowIDs,[]);
verifyEqual(tc,view(app),section);
row=find(cell2mat(app.ColonyTable.Data(:,1))==id);
feval(app.ColonyTable.CellSelectionCallback,app.ColonyTable,struct('Indices',[row 1]));
verifyLessThan(tc,diff(xlim(app.ImageAxes)),diff(section(1:2)));
% Free pan/zoom and colony close-ups must not restart the section cursor.
xlim(app.ImageAxes,[160 195]); ylim(app.ImageAxes,[160 195]);
pressNext(app); second=view(app);
verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 2 of 9'));
verifyGreaterThan(tc,mean(second(1:2)),mean(section(1:2)));
verifyEqual(tc,second(3:4),section(3:4));
end
function testAddMissedColonyAndExcludeInSection(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
pressNext(app); section=view(app); before=app.Result.Summary;
app.beginAdding(); verifyEqual(tc,view(app),section);
verifyEqual(tc,string(app.Buttons.NextSection.Enable),"off");
verifyEqual(tc,string(app.Buttons.PreviousSection.Enable),"off");
app.showNextSection(); app.showPreviousSection(); verifyEqual(tc,view(app),section);
app.MarkingLabel.Value='AD9'; app.MarkingRadius.Value=4;
picture=findobj(app.ImageAxes,'Type','image');
point=([205 205]-.5)*app.Result.Scale+.5;
feval(picture.ButtonDownFcn,picture,struct('IntersectionPoint',[point 0]));
app.confirmMarking(); verifyEqual(tc,view(app),section);
verifyEqual(tc,app.Result.Summary.AD9,before.AD9+1);
id=app.Result.Colonies.ID(end); app.setColonyLabel(id,'Not a colony');
verifyEqual(tc,app.Result.Summary.Total,before.Total);
verifyEqual(tc,string(app.Buttons.NextSection.Enable),"on");
verifyEqual(tc,string(app.Buttons.PreviousSection.Enable),"on");
pressNext(app); verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 2 of 9'));
end
function testSplitCancelConfirmAndUndoFromSection(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
T=app.Result.Colonies; [~,k]=max(T.EnclosingRadiusPixels); id=T.ID(k);
% Start in the section containing this object.
for n=1:9
    pressNext(app); limits=view(app);
    xy=([T.X(k) T.Y(k)]-.5)*app.Result.Scale+.5;
    if xy(1)>=limits(1) && xy(1)<=limits(2) && xy(2)>=limits(3) && xy(2)<=limits(4), break; end
end
section=view(app); original=app.Result;
app.beginMarking(id); app.addMarkedCenter([T.X(k)-4,T.Y(k)],'AD9');
verifyEqual(tc,string(app.Buttons.NextSection.Enable),"off");
verifyEqual(tc,string(app.Buttons.PreviousSection.Enable),"off");
app.cancelMarking(); verifyEqual(tc,view(app),section); verifyEqual(tc,app.Result,original);
app.beginMarking(id);
app.addMarkedCenter([T.X(k)-4,T.Y(k)],'AD9');
app.addMarkedCenter([T.X(k)+4,T.Y(k)],'AD24'); app.confirmMarking();
verifyEqual(tc,app.Result.Summary.Total,original.Summary.Total+1);
child=app.Result.ManualGroups.ChildIDs(1); app.restoreMarkedColonies(child);
verifyEqual(tc,app.Result.Labels,original.Labels);
verifyEqual(tc,app.Result.Summary,original.Summary);
pressNext(app); verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,sprintf('Current section: %d of 9',mod(n,9)+1)));
end
function testLiveBoundaryAndPendingSettingsAreUntouched(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
app.setParameter('PinkContrastThreshold',.075); app.choosePlateBoundary();
roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
roi.Center=[120 260]; roi.SemiAxes=[250 170]; roi.RotationAngle=35;
original=app.Result; options=app.Options;
app.showWholePlate(); whole=view(app);
for n=1:9, pressNext(app); end
verifyTrue(tc,isvalid(roi)); verifyEqual(tc,roi.Center,[120 260]);
verifyEqual(tc,roi.SemiAxes,[250 170]); verifyEqual(tc,roi.RotationAngle,35);
verifyEqual(tc,app.Result,original); verifyEqual(tc,app.Options,options);
verifyTrue(tc,app.Dirty); verifyEqual(tc,string(app.Buttons.Boundary.Text),"Done boundary");
verifyEqual(tc,string(app.Buttons.Save.Enable),"off");
verifyGreaterThanOrEqual(tc,min(xlim(app.ImageAxes)),whole(1));
verifyLessThanOrEqual(tc,max(xlim(app.ImageAxes)),whole(2));
% Moving the live boundary changes the selected grid; its next view starts at 1.
roi.Center=[420 320]; pressNext(app);
verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 1 of 9'));
verifyEqual(tc,roi.Center,[420 320]); verifyEqual(tc,app.Options,options);
end
function testReclassificationReloadAndExportsKeepWholePlate(tc)
[app,lease,close]=makeApp(); %#ok<ASGLU>
pressNext(app); pressNext(app); app.applySettings(); verifyEmpty(tc,app.LastError);
verifyEqual(tc,string(app.Buttons.NextSection.Text),"Next section >");
pressNext(app); original=app.Result;
folder=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
files=app.saveResults(folder);
exported=readtable(files.Workbook,'Sheet','Colonies');
verifyEqual(tc,height(exported),height(original.Colonies));
verifyEqual(tc,sort(exported.ID),sort(original.Colonies.ID));
% The view cursor is transient; saved results open as the whole plate.
app.loadResults(files.Workbook);
verifyEqual(tc,string(app.Buttons.NextSection.Text),"Next section >");
verifyEqual(tc,app.Result.Colonies,original.Colonies);
pressNext(app); pressNext(app); verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 2 of 9'));
app.loadImage(original.ImageFile);
verifyEqual(tc,string(app.Buttons.NextSection.Text),"Next section >");
pressNext(app); verifyTrue(tc,contains(app.Buttons.NextSection.Tooltip,'Current section: 1 of 9'));
end
function [app,lease,close]=makeApp()
[file,lease]=marking_fixture(); app=ColonyCounterApp(file,'off'); close=onCleanup(@()delete(app));
app.setPlateBoundary([300 300 255 255 0]); app.applySettings(); assert(isempty(app.LastError));
end
function limits=view(app)
limits=[xlim(app.ImageAxes),ylim(app.ImageAxes)];
end
function pressNext(app)
feval(app.Buttons.NextSection.ButtonPushedFcn,app.Buttons.NextSection,[]);
end
function pressPrevious(app)
feval(app.Buttons.PreviousSection.ButtonPushedFcn,app.Buttons.PreviousSection,[]);
end

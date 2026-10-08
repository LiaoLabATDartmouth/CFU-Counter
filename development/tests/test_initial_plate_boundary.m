function tests=test_initial_plate_boundary
% Initial display, locking and first-click fitting before any classification.
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testLoadShowsLockedProposalAndEditorStartsThere(tc)
[file,c]=fixture(); %#ok<ASGLU>
app=ColonyCounterApp(file,'off');cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEmpty(tc,app.Result);verifyEmpty(tc,app.LastError);
ring=lockedBoundary(tc,app);e=app.EstimationInfo.ProposedEllipse;
verifyGreaterThan(tc,numel(ring.XData),100);
verifyEqual(tc,min(ring.XData),e(1)-e(3),'AbsTol',.1);
verifyEqual(tc,max(ring.YData),e(2)+e(4),'AbsTol',.1);
options=app.Options;app.choosePlateBoundary();roi=editor(app);
verifyEqual(tc,[roi.Center roi.SemiAxes roi.RotationAngle],e,'AbsTol',1e-8);
verifyEmpty(tc,findobj(app.ImageAxes,'Tag','PlateBoundary'));
app.choosePlateBoundary();lockedBoundary(tc,app);
verifyEqual(tc,app.Options,options);verifyFalse(tc,app.Dirty);
end
function testFirstFitAfterLoadFitsRimAndRelocksOnDone(tc)
[file,c]=fixture(); %#ok<ASGLU>
app=ColonyCounterApp(file,'off');cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
initial=app.Options;
feval(app.Buttons.View.ButtonPushedFcn,app.Buttons.View,[]);
verifyEmpty(tc,app.LastError);verifyTrue(tc,contains(app.StatusLabel.Text,'Boundary fitted'));
roi=editor(app);verifyEqual(tc,numel(roi),1);
verifyEqual(tc,roi.Center,[335 285],'AbsTol',2);
verifyEqual(tc,sort(roi.SemiAxes),[235 260],'AbsTol',3);
verifyEqual(tc,app.Options,initial);verifyEmpty(tc,app.Result);
verifyEqual(tc,string(app.Buttons.Boundary.Text),"Done boundary");
app.choosePlateBoundary();lockedBoundary(tc,app);
verifyEqual(tc,app.Options.PlateEllipse(1:2),[335 285],'AbsTol',2);
verifyTrue(tc,app.Dirty);verifyEmpty(tc,app.Result);
app.applySettings();verifyEmpty(tc,app.LastError);lockedBoundary(tc,app);
verifyFalse(tc,app.Dirty);
end
function testDifferentImageClearsOldOutlineAndUnknownImageStaysLocked(tc)
[file,c]=fixture(); %#ok<ASGLU>
app=ColonyCounterApp(file,'off');cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.fitImage();old=editor(app);
file2=fullfile(fileparts(file),'no visible rim.png');imwrite(.5*ones(420,700,3),file2);
app.loadImage(file2);verifyFalse(tc,isvalid(old));verifyFalse(tc,app.EstimationInfo.Estimated);
ring=lockedBoundary(tc,app);
verifyEqual(tc,max(ring.XData),350+126,'AbsTol',.1);
verifyTrue(tc,contains(app.BoundaryHint.Text,'Initial yellow outline only'));
verifyEmpty(tc,app.Options.PlateEllipse);verifyEmpty(tc,app.Result);
app.fitImage();verifyEmpty(tc,app.LastError);lockedBoundary(tc,app);
verifyTrue(tc,contains(app.StatusLabel.Text,'Could not fit a reliable rim'));
verifyEmpty(tc,app.Options.PlateEllipse);
app.choosePlateBoundary();roi=editor(app);
verifyEqual(tc,[roi.Center roi.SemiAxes],[350 210 126 126]);
app.choosePlateBoundary();lockedBoundary(tc,app);
verifyEqual(tc,app.Options.PlateEllipse,[350 210 126 126 0]);
end
function ring=lockedBoundary(tc,app)
ring=findobj(app.ImageAxes,'Tag','PlateBoundary');verifyEqual(tc,numel(ring),1);
verifyEqual(tc,string(ring.HitTest),"off");verifyEqual(tc,string(ring.PickableParts),"none");
verifyEmpty(tc,editor(app));verifyEqual(tc,string(app.Buttons.Boundary.Text),"Choose plate boundary");
end
function roi=editor(app)
children=app.ImageAxes.Children;
roi=children(arrayfun(@(x)isa(x,'images.roi.Ellipse'),children));
end
function [file,c]=fixture()
folder=tempname;mkdir(folder);c=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'plate.png');[x,y]=meshgrid(1:700,1:600);
mask=((x-335)/260).^2+((y-285)/235).^2<=1;
I=repmat(single(.1),600,700,3);color=[.62 .37 .34];
for k=1:3,v=I(:,:,k);v(mask)=color(k);I(:,:,k)=v;end
imwrite(I,file);
end

function tests=test_adaptive_settings
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testFilenameAndEncodingDoNotSelectSettings(tc)
[file,e,c]=fixture(false); %#ok<ASGLU>
[a,info]=estimate_colony_settings(file,e);
copy=fullfile(fileparts(file),'AD24 arbitrary name.tif');imwrite(imread(file),copy);
[b,other]=estimate_colony_settings(copy,e);
verifyEqual(tc,a,b);verifyEqual(tc,info,other);verifyTrue(tc,info.Estimated);
% Change pixels at the same path: the estimator must measure them again.
imwrite(uint8(100*ones(600,600,3)),file);
[b,other]=estimate_colony_settings(file,e);
verifyEqual(tc,other.ReferenceObjects,0);verifyEqual(tc,b.ArtifactFilterStrength,2);
verifyNotEqual(tc,a,b);
end
function testLinearExposureAndColorGainsCancel(tc)
[file,e,c]=fixture(false); %#ok<ASGLU>
a=estimate_colony_settings(file,e);I=im2single(imread(file));
V=lin2rgb(rgb2lin(I).*reshape(single([.48 .70 .62]),1,1,3));
copy=fullfile(fileparts(file),'new_camera.png');imwrite(im2uint16(V),copy);
b=estimate_colony_settings(copy,e);
for name={'PinkContrastThreshold','ArtifactFilterStrength','MinDiameterFraction','WatershedPeakFraction'}
 verifyEqual(tc,a.(name{1}),b.(name{1}),'RelTol',.025);
end
ra=count_colonies(file,a);rb=count_colonies(copy,b);
verifyEqual(tc,ra.Summary.Total,rb.Summary.Total);
verifyEqual(tc,ra.Colonies.Class,rb.Colonies.Class);
end
function testMoreNoiseRaisesThresholdWithoutInventingClasses(tc)
[file,e,c]=fixture(false); %#ok<ASGLU>
[a,ia]=estimate_colony_settings(file,e);I=im2single(imread(file));
s=rng;cleanup=onCleanup(@()rng(s));rng(11); %#ok<NASGU>
I=max(0,min(1,I+.018*randn(size(I),'single')));imwrite(I,file);
[b,ib]=estimate_colony_settings(file,e);
verifyGreaterThan(tc,ib.PinkNoise,ia.PinkNoise);
verifyGreaterThan(tc,b.PinkContrastThreshold,a.PinkContrastThreshold);
verifyEqual(tc,b.SizeThresholdFraction,a.SizeThresholdFraction);
verifyFalse(tc,ib.SizeReferenceEstimated);
end
function testBlankAndNoPlateAreFinite(tc)
folder=tempname;mkdir(folder);c=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'blank.png');imwrite(uint8(100*ones(600,600,3)),file);
[o,info]=estimate_colony_settings(file,[300 300 255 255 0]);
verifyEqual(tc,info.ReferenceObjects,0);verifyEqual(tc,o.ArtifactFilterStrength,2);
r=count_colonies(file,o);verifyEqual(tc,r.Summary.Total,0);
imwrite(uint8(zeros(80,80,3)),file);[o,info]=estimate_colony_settings(file);
verifyFalse(tc,info.Estimated);verifyEqual(tc,o,colony_defaults());
end
function testAppEstimatesOnLoadAndSelectedPlateKeepsEdits(tc)
[file,e,c]=fixture(false); %#ok<ASGLU>
app=ColonyCounterApp(file,'off');closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
verifyEmpty(tc,app.LastError);verifyTrue(tc,app.EstimationInfo.Estimated);
verifyEmpty(tc,app.Result);app.setPlateBoundary(e);starting=app.Options;
app.setParameter('PinkContrastThreshold',.11);
% New region refreshes estimates but keeps deliberate parameter edits.
e(3:4)=[240 245];app.setPlateBoundary(e);
verifyEqual(tc,app.Options.PinkContrastThreshold,.11);
verifyEqual(tc,app.Controls.PinkContrastThreshold.Edit.Value,.11);
[expected,~]=estimate_colony_settings(file,e);
feval(app.Buttons.Reset.ButtonPushedFcn,app.Buttons.Reset,[]);
verifyEqual(tc,app.Options,expected);verifyEmpty(tc,app.Result);
% Unchanged boundary performs no estimation and preserves edits.
app.setParameter('PinkContrastThreshold',.11);profile clear;profile on;
c2=onCleanup(@()profile('off')); %#ok<NASGU>
app.setPlateBoundary(e);profile off;p=profile('info');
verifyFalse(tc,any(contains(string({p.FunctionTable.FunctionName}),'estimate_colony_settings')));
copy=fullfile(fileparts(file),'renamed.png');copyfile(file,copy);app.loadImage(copy);
verifyEqual(tc,app.Options,estimate_colony_settings(copy));
verifyNotEqual(tc,app.Options.PinkContrastThreshold,.11);
verifyEqual(tc,app.Options.SizeThresholdFraction,starting.SizeThresholdFraction);
end
function testSelectedPlateChangesDensityEstimate(tc)
[left,e,c]=fixture(false);[right,~,c2]=fixture(true); %#ok<ASGLU>
file=fullfile(fileparts(left),'two.png');imwrite(cat(2,imread(left),imread(right)),file);
[a,ia]=estimate_colony_settings(file,e);e(1)=900;
[b,ib]=estimate_colony_settings(file,e);
verifyGreaterThan(tc,ib.PilotColonies,ia.PilotColonies);
verifyGreaterThan(tc,ib.OccupiedFraction,ia.OccupiedFraction);
% Crowding also changes the measured object-size distribution, so an
% individual threshold need not move monotonically. Check that the selected
% pixels actually change both the measured occupancy and suggested settings.
verifyNotEqual(tc,rmfield(a,'PlateEllipse'),rmfield(b,'PlateEllipse'));
end
function [file,e,c]=fixture(dense)
folder=tempname;mkdir(folder);c=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'unlabeled.png');[x,y]=meshgrid(1:600);
plate=(x-300).^2+(y-300).^2<260^2;
I=repmat(single(.1),600,600,3);bg=[.62 .37 .34];
for channel=1:3, v=I(:,:,channel);v(plate)=bg(channel);I(:,:,channel)=v;end
step=50;if dense,step=14;end
[cx,cy]=meshgrid(180:step:430);
for k=1:numel(cx)
 radius=4;color=[.90 .49 .53];if mod(k,5)==0,radius=8;color=[.96 .25 .47];end
 m=(x-cx(k)).^2+(y-cy(k)).^2<=radius^2;
 for channel=1:3,v=I(:,:,channel);v(m)=color(channel);I(:,:,channel)=v;end
end
imwrite(I,file);e=[300 300 255 255 0];
end

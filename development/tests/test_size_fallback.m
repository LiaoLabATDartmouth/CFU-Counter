function tests=test_size_fallback
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testSingleSmallOrLargePopulation(tc)
for radius=[3 7]
    [file,opts,cleanup]=fixture(radius); %#ok<ASGLU>
    r=count_colonies(file,opts); r=prepare_colony_app_result(r);
    verifyFalse(tc,r.ClassifierModel.Ready);
    verifyEqual(tc,r.ClassificationInfo.Mode,"size_fallback");
    verifyEqual(tc,r.Summary.Classifier,"size_fallback");
    verifyEqual(tc,r.Summary.Total,6);
    verifyEqual(tc,r.Summary.Uncertain,0);
    label="AD9"; if radius==7, label="AD24"; end
    verifyEqual(tc,r.Colonies.Class,repmat(label,6,1));
    verifyTrue(tc,all(r.Colonies.SizeFallbackUsed));
    verifyTrue(tc,all(isnan(r.Colonies.FisherScore)));
    clear cleanup
end
end

function testFallbackKeepsAmbiguousAndObscuredObjectsForReview(tc)
[file,opts,cleanup]=fixture(3); %#ok<ASGLU>
r=count_colonies(file,opts); T=r.Colonies;
T.DiameterPixels(1)=r.DiameterThresholdPixels;
T.DetectionNotes(2)="near_ink_or_shadow";
T.CleanSignalCoreFraction(2)=0.2;
T.LocalLogPink(3)=0.05;
T.BackgroundPixels(4)=9;
T.Solidity(5)=0.7;
T.LocalLogRG(6)=NaN;
r.Colonies=T; r=classify_colonies(r);
verifyTrue(tc,all(r.Colonies.NeedsReview));
verifyTrue(tc,r.Colonies.MergeWarning(5));
verifyTrue(tc,all(r.Colonies.ClassificationWarning([1:4 6])));
verifyFalse(tc,r.Colonies.SizeFallbackUsed(6));
% Both perimeter proximity and ink are reviewed in this untrained fallback.
r.Colonies.DetectionNotes(2)="near_rim"; r=update_colony_warnings(r);
verifyTrue(tc,r.Colonies.NeedsReview(2));
r=prepare_colony_app_result(r);
r=edit_colony(r,'classify',r.Colonies.ID(2),'AD9');
verifyFalse(tc,r.Colonies.NeedsReview(2));
end

function testSizeReviewMarginIsAdjustable(tc)
[file,opts,cleanup]=fixture(3); %#ok<ASGLU>
r=count_colonies(file,opts);
r.Colonies.DiameterPixels(:)=0.85*r.DiameterThresholdPixels;
r=classify_colonies(r); verifyFalse(tc,any(r.Colonies.NeedsReview));
r.Options.SizeReviewFraction=.20; r=classify_colonies(r);
verifyTrue(tc,all(r.Colonies.NeedsReview));
end

function testAvailableCompositeModelIsStillUsed(tc)
[file,opts,cleanup]=fixture([3 3 3 7 7 7]); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyTrue(tc,r.ClassifierModel.Ready);
verifyEqual(tc,r.ClassificationInfo.Mode,"composite");
verifyFalse(tc,any(r.Colonies.SizeFallbackUsed));
labels=r.Labels; r.Options.ClassifierModel=r.ClassifierModel;
r.Colonies.LocalLogRG(1)=NaN; r=classify_colonies(r);
verifyTrue(tc,r.Colonies.NeedsReview(1));
verifyFalse(tc,r.Colonies.SizeFallbackUsed(1));
verifyEqual(tc,r.Labels,labels);
end

function testScreenshotPhotoRejectsArtifactsAndKeepsUsefulLabels(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 MM 10(-4).HEIC');
assumeTrue(tc,isfile(file),'Local HEIC research photo is not included in ZIP.');
I=read_plate_image(file); scale=1000/max(size(I,1),size(I,2));
[ellipse,info]=fit_plate_boundary(imresize(I,scale),[594 376 325 340 0]);
assert(info.Fitted); ellipse(1:2)=(ellipse(1:2)-.5)/scale+.5;
ellipse(3:4)=ellipse(3:4)/scale; opts=colony_defaults(); opts.PlateEllipse=ellipse;
r=count_colonies(file,opts); labels=r.Labels;
verifyFalse(tc,r.ClassifierModel.Ready);
verifyEqual(tc,numel(r.ClassifierModel.SeedAD24IDs),0);
r=prepare_colony_app_result(r);
% Visual audit: approximately forty visible pink objects; the previous 81
% included printing and plastic. These bounds detect a regression, and are
% not an assertion of independently annotated biological ground truth.
verifyGreaterThanOrEqual(tc,r.Summary.Total,35);
verifyLessThanOrEqual(tc,r.Summary.Total,55);
verifyGreaterThanOrEqual(tc,r.Summary.AD9,25);
verifyLessThanOrEqual(tc,r.Summary.AD24,2);
verifyLessThan(tc,r.Summary.Uncertain,0.35*r.Summary.Total);
verifyEqual(tc,r.Labels,labels);
verifyTrue(tc,all(isnan(r.Colonies.FisherScore)));
end

function testAppCountsMarginAndWorkbookState(tc)
[file,opts,cleanup]=fixture(3); %#ok<ASGLU>
app=ColonyCounterApp(file,'off'); closeApp=onCleanup(@()delete(app));
app.setPlateBoundary(opts.PlateEllipse); app.applySettings();
verifyEmpty(tc,app.LastError); verifyEqual(tc,app.CountLabels.AD9.Text,'6');
verifyEqual(tc,app.CountLabels.Review.Text,'0');
verifyTrue(tc,contains(app.StatusLabel.Text,'Size reference used'));
verifyTrue(tc,isfield(app.Controls,'SizeReviewFraction'));
app.setParameter('SizeReviewFraction',.20); verifyTrue(tc,app.Dirty);
app.applySettings(); verifyEmpty(tc,app.LastError);
verifyEqual(tc,app.Result.Options.SizeReviewFraction,.20);
files=app.saveResults(fileparts(file));
metadata=readcell(files.Workbook,'Sheet','Summary','Range','A14:B14');
verifyEqual(tc,string(metadata{1}),"Automatic classification");
verifyTrue(tc,contains(string(metadata{2}),"Size reference used"));
[T,S]=colony_export_tables(app.Result);
verifyEqual(tc,sum(T.Label=="AD9"),S.Count(S.Label=="AD9"));
clear closeApp
end

function [file,opts,cleanup]=fixture(radii)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'unlabeled_plate.png');
[x,y]=meshgrid(1:600); plate=(x-300).^2+(y-300).^2<260^2;
I=repmat(single(.1),600,600,3); bg=[.62 .37 .34];
for c=1:3, channel=I(:,:,c); channel(plate)=bg(c); I(:,:,c)=channel; end
centers=[210 220;300 220;390 220;210 370;300 370;390 370];
if isscalar(radii), radii=repmat(radii,1,6); end
for k=1:6
    mask=(x-centers(k,1)).^2+(y-centers(k,2)).^2<=radii(k)^2;
    color=[.96 .35 .48];
    for c=1:3, channel=I(:,:,c); channel(mask)=color(c); I(:,:,c)=channel; end
end
imwrite(I,file); opts=colony_defaults(); opts.PlateEllipse=[300 300 255 255 0];
end

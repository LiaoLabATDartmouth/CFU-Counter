function tests=test_colony_counter
% Synthetic regression checks, not a validation against biological ground truth.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testKnownCountsAndInk(testCase)
[file,opts,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyEqual(testCase,r.Summary.AD9,4);
verifyEqual(testCase,r.Summary.AD24,2);
verifyEqual(testCase,r.Summary.Total,6);
verifyEqual(testCase,numel(unique(r.Labels(r.Labels>0))),6);
verifyTrue(testCase,all(r.ROI(r.Labels>0)));
end

function testTouchingColonies(testCase)
[file,opts,cleaner]=syntheticPlate(true,false); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyEqual(testCase,r.Summary.Total,8);
verifyEqual(testCase,r.Summary.AD9,6);
verifyEqual(testCase,r.Summary.AD24,2);
end

function testBlankPlate(testCase)
[file,opts,cleaner]=syntheticPlate(false,true); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyEqual(testCase,r.Summary.Total,0);
verifyEqual(testCase,height(r.Colonies),0);
end

function testScaleAndCoordinates(testCase)
[file,opts,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
r=count_colonies(file,opts);
I=imresize(imread(file),2,'nearest'); imwrite(I,file);
opts.PlateEllipse(1:2)=(opts.PlateEllipse(1:2)-0.5)*2+0.5;
opts.PlateEllipse(3:4)=opts.PlateEllipse(3:4)*2;
opts.MaxImageDimension=800;
r2=count_colonies(file,opts);
verifyEqual(testCase,r2.Summary.AD9,r.Summary.AD9);
verifyEqual(testCase,r2.Summary.AD24,r.Summary.AD24);
p=sortrows([r.Colonies.X r.Colonies.Y]); q=sortrows([r2.Colonies.X r2.Colonies.Y]);
verifyEqual(testCase,q,(p-0.5)*2+0.5,'AbsTol',1);
end

function testManualCorrections(testCase)
[file,opts,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
r=count_colonies(file,opts); initial=r.Summary;
smallID=r.Colonies.ID(find(r.Colonies.Class=="AD9",1));
r=edit_colony(r,'classify',smallID,'AD24');
verifyEqual(testCase,r.Summary.AD9,initial.AD9-1);
verifyEqual(testCase,r.Summary.AD24,initial.AD24+1);
oldMax=max(r.Colonies.ID); r=edit_colony(r,'delete',oldMax);
verifyFalse(testCase,any(r.Labels(:)==oldMax));
r=edit_colony(r,'add',[400 450],'AD9');
verifyGreaterThan(testCase,r.Colonies.ID(end),oldMax);
verifyTrue(testCase,isnan(r.Colonies.AreaPixels(end)));
verifyEqual(testCase,r.Summary.Total,initial.Total);
verifyError(testCase,@()edit_colony(r,'add',[1 1],'AD9'),'CFU:OutsideROI');
end

function testExplicitSizeCutoff(testCase)
[file,opts,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
opts.DiameterThresholdPixels=100;
r=count_colonies(file,opts);
verifyEqual(testCase,r.Summary.AD24,0);
verifyEqual(testCase,r.Summary.AD9,6);
end

function testExportsAndBatch(testCase)
[file,opts,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
folder=fileparts(file); out=fullfile(folder,'results'); mkdir(out);
s=count_folder(folder,opts,out);
verifyEqual(testCase,height(s),1);
verifyEqual(testCase,s.Total,6);
verifyTrue(testCase,isfile(fullfile(out,'plate_annotated.png')));
verifyTrue(testCase,isfile(fullfile(out,'plate_colonies.xlsx')));
listing=dir(out); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(testCase,numel(listing),2);
verifyFalse(testCase,any([listing.isdir]));
data=readtable(fullfile(out,'plate_colonies.xlsx'),'Sheet','Summary', ...
    'Range','A1:C6','TextType','string');
verifyEqual(testCase,data.Count(data.Label=="Total included"),6);
end

function testInvalidOption(testCase)
[file,~,cleaner]=syntheticPlate(false,false); %#ok<ASGLU>
verifyError(testCase,@()count_colonies(file,struct('Typo',1)),'CFU:UnknownOption');
end

function testCompositeAndReferenceReuse(testCase)
[file,opts,cleaner]=syntheticPlate(false,false,true); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyTrue(testCase,r.ClassifierModel.Ready);
verifyEqual(testCase,r.Summary.AD9,4);
verifyEqual(testCase,r.Summary.AD24,3);
verifyTrue(testCase,all(isfinite(r.Colonies.ScoreAD24)));
model=fit_colony_classifier(r,r.Colonies.ID(r.Colonies.SizeOnlyClass=="AD9"), ...
    r.Colonies.ID(r.Colonies.SizeOnlyClass=="AD24"));
opts.ClassifierModel=model;
r2=count_colonies(file,opts);
verifyEqual(testCase,r2.Colonies.Class,r.Colonies.Class);
verifyEqual(testCase,r2.ClassifierModel.Source,"Fisher LDA with user-selected reference colonies");
end

function testLearnedFeaturesAndLighting(testCase)
[file,opts,cleaner]=syntheticPlate(false,false,true); %#ok<ASGLU>
r=count_colonies(file,opts);
verifyFalse(testCase,isfield(r.ClassifierModel,'GroupWeights'));
verifyGreaterThan(testCase,norm(r.ClassifierModel.Coefficients(2:6)),1e-6);
T=r.Colonies;
verifyEqual(testCase,T.FisherScore,T.SizeEvidence+T.ColorEvidence+T.ShapeEvidence+T.BoundaryEvidence,'AbsTol',1e-8);
% Simulate a dimmer photograph with different white balance, without clipping.
linear=rgb2lin(im2single(imread(file)));
linear=linear.*reshape(single([0.45 0.60 0.52]),1,1,3);
imwrite(im2uint16(lin2rgb(linear)),file);
opts.ClassifierModel=r.ClassifierModel;
r2=count_colonies(file,opts);
verifyEqual(testCase,r2.Summary.AD9,r.Summary.AD9);
verifyEqual(testCase,r2.Summary.AD24,r.Summary.AD24);
verifyEqual(testCase,r2.Colonies.LocalLogRG,r.Colonies.LocalLogRG,'AbsTol',0.01);
verifyEqual(testCase,r2.Colonies.LocalLogBG,r.Colonies.LocalLogBG,'AbsTol',0.01);
end

function testMixedLobesPreserveOuterBoundary(testCase)
[x,y]=meshgrid(1:90);
large=(x-40).^2+(y-40).^2<=12^2;
small=(x-54).^2+(y-49).^2<=6^2;
mask=large | small; pink=zeros(size(x)); pink(large)=1.2; pink(small)=0.2;
[parts,info]=split_mixed_region(mask,pink,5,0.6);
verifyTrue(testCase,info.Accepted);
verifyEqual(testCase,parts>0,mask);
verifyEqual(testCase,numel(unique(parts(mask))),2);
verifyEqual(testCase,parts(40,40),uint8(1));
verifyEqual(testCase,parts(49,54),uint8(2));
end

function testHaloAndShadingStaySingle(testCase)
[x,y]=meshgrid(1:90); distance=hypot(x-45,y-45); mask=distance<=14;
pink=zeros(size(x)); pink(mask)=0.2; pink(distance<=11)=1.2;
[~,info]=split_mixed_region(mask,pink,5,0.6);
verifyFalse(testCase,info.Accepted);
pink(mask)=1.2; pink(mask & x<38)=0.2;
[~,info]=split_mixed_region(mask,pink,5,0.6);
verifyFalse(testCase,info.Accepted);
% A bite from an irregular boundary does not make an internal pale cap a lobe.
mask(39:43,57:60)=false;
[~,info]=split_mixed_region(mask,pink,5,0.6);
verifyFalse(testCase,info.Accepted);
end

function testExactlyTwoWarningCategories(testCase)
[file,opts,cleaner]=syntheticPlate(false,false,true); %#ok<ASGLU>
r=count_colonies(file,opts); T=r.Colonies;
T.Solidity(:)=1; T.Circularity(:)=1; T.FisherScore(:)=1;
T.DiameterPixels(:)=r.DiameterThresholdPixels/2;
T.DetectionNotes(:)="near_rim;near_ink_or_shadow;faint;composite_size_disagreement";
T.Solidity(1)=0.7; T.FisherScore(2)=0.01; T.LocalLogRG(3)=NaN;
T.Reviewed(:)=false; r.Colonies=T; r=update_colony_warnings(r);
verifyEqual(testCase,find(r.Colonies.NeedsReview),[1;2;3]);
verifyEqual(testCase,r.Colonies.ReviewReason(1),"shape suggests a merged object or two colonies");
verifyEqual(testCase,r.Colonies.ReviewReason(2:3),repmat("unclear classification or insufficient features",2,1));
verifyTrue(testCase,all(r.Colonies.ReviewReason(4:end)==""));
end

function testExampleInternalRefinement(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
opts=colony_defaults(); opts.PlateEllipse=[1485.3 2170.9 1265.6 1265.6 0];
r=count_colonies(fullfile(root,'Examples','IMG_7489.jpeg'),opts);
verifyEqual(testCase,r.Labels>0,r.OriginalLabels>0);
verifyEqual(testCase,r.Summary.Total,height(r.OriginalColonies)+height(r.SplitLog));
% These two visually clear mixed pairs must acquire separate child labels.
verifyTrue(testCase,all(ismember([175;287],r.SplitLog.ParentID)));
% Round colonies with uneven pigment must not acquire spurious satellites.
verifyFalse(testCase,any(ismember([59;121;133;306],r.SplitLog.ParentID)));
unmodified=~ismember(r.OriginalColonies.ID,r.SplitLog.ParentID);
ids=r.OriginalColonies.ID(unmodified);
verifyEqual(testCase,r.Labels(ismember(r.OriginalLabels,ids)),r.OriginalLabels(ismember(r.OriginalLabels,ids)));
verifyEqual(testCase,r.Colonies.Class(ismember(r.Colonies.ID,ids)),r.OriginalColonies.Class(unmodified));
end

function testInteriorColorResolutionAndLighting(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
opts=colony_defaults(); opts.PlateEllipse=[1485.3 2170.9 1265.6 1265.6 0];
opts.ResolveAmbiguousClassification=false;
base=count_colonies(fullfile(root,'Examples','IMG_7489.jpeg'),opts);
base.Options.ResolveAmbiguousClassification=true;
state=rng; r=resolve_colony_classification(base);
verifyEqual(testCase,rng,state); % Reference resampling must not alter user RNG.
verifyEqual(testCase,r.Labels,base.Labels);
verifyEqual(testCase,r.Colonies.Class,base.Colonies.Class);
verifyLessThan(testCase,r.Summary.ClassificationWarnings,base.Summary.ClassificationWarnings);
T=r.Colonies; accepted=T.ResolutionAccepted;
verifyTrue(testCase,any(accepted));
verifyTrue(testCase,all(T.ResolutionScoreLow(accepted)>0 | T.ResolutionScoreHigh(accepted)<0));
verifyTrue(testCase,all(T.ResolutionReferenceDistance(accepted)<=T.ResolutionReferenceLimit(accepted)));
verifyTrue(testCase,all(abs(T.ResolutionScore(accepted))>=opts.CompositeReviewMargin));
% A larger agar annulus cannot recover an obscured interior. Mask a known
% object deterministically; the old hard-coded ID was an ink halo that the
% improved detector now rejects, so retaining it would test a false positive.
obscured=base; row=find(T.ResolutionBackgroundPixels>=30 & T.CleanCoreFraction>=.6,1);
assertNotEmpty(testCase,row);id=T.ID(row);
obscured.InkMask(obscured.Labels==id)=true;
obscured.Colonies.FisherScore(row)=0;
obscured=resolve_colony_classification(obscured); ink=obscured.Colonies;
verifyGreaterThanOrEqual(testCase,ink.ResolutionBackgroundPixels(row),30);
verifyLessThan(testCase,ink.CleanCoreFraction(row),0.6);
verifyTrue(testCase,ink.ClassificationWarning(row));
verifyEqual(testCase,ink.ResolutionReason(row),"insufficient_unobscured_interior");
% Repeated calls are idempotent; reference IDs from another image are not
% silently reused to refit the secondary model.
again=resolve_colony_classification(r);
verifyEqual(testCase,again.Colonies.ResolutionAccepted,T.ResolutionAccepted);
r.Options.ClassifierModel=r.ClassifierModel;
r.Options.ClassificationResolverModel=r.ClassificationResolverModel;
changed=r; changed.Image=lin2rgb(rgb2lin(r.Image).*reshape(single([0.55 0.70 0.60]),1,1,3));
changed=resolve_colony_classification(changed);
verifyEqual(testCase,changed.Colonies.ResolutionAccepted,T.ResolutionAccepted);
valid=isfinite(T.ResolutionScore);
verifyEqual(testCase,changed.Colonies.ResolutionScore(valid),T.ResolutionScore(valid),'AbsTol',1e-4);
verifyEqual(testCase,changed.Labels,r.Labels);
end

function testResolverDoesNotGuessWithoutReferences(testCase)
[file,opts,cleaner]=syntheticPlate(false,false,true); %#ok<ASGLU>
r=count_colonies(file,opts);
r.Colonies.FisherScore(:)=0;
r=resolve_colony_classification(r);
verifyFalse(testCase,r.ClassificationResolverModel.Ready);
verifyFalse(testCase,any(r.Colonies.ResolutionAccepted));
verifyTrue(testCase,all(r.Colonies.ClassificationWarning));
end

function testResolverKeepsWarningWhenBackgroundUnavailable(testCase)
[file,opts,cleaner]=syntheticPlate(false,false,true); %#ok<ASGLU>
r=count_colonies(file,opts); labels=r.Labels;
r.Colonies.FisherScore(1)=0; r.InkMask(:)=true;
r=resolve_colony_classification(r);
verifyTrue(testCase,r.Colonies.ClassificationWarning(1));
verifyFalse(testCase,r.Colonies.ResolutionAccepted(1));
verifyEqual(testCase,r.Colonies.ResolutionReason(1),"insufficient_clean_background");
verifyEqual(testCase,r.Labels,labels);
end

function [file,opts,cleaner]=syntheticPlate(touching,blank,extraLarge)
if nargin<3, extraLarge=false; end
folder=tempname; mkdir(folder); cleaner=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'plate.png');
[x,y]=meshgrid(1:800); plate=(x-400).^2+(y-400).^2<=335^2;
I=repmat(single(0.10),800,800,3);
background=[0.62 0.37 0.34];
for c=1:3, channel=I(:,:,c); channel(plate)=background(c); I(:,:,c)=channel; end
if ~blank
    centers=[250 250 5;350 250 5;450 250 5;550 250 5;300 520 11;500 520 11];
    if extraLarge, centers=[centers;400 550 11]; end
    if touching, centers=[centers; 390 390 6;400 390 6]; end
    for k=1:size(centers,1)
        mask=(x-centers(k,1)).^2+(y-centers(k,2)).^2<=centers(k,3)^2;
        color=[0.90 0.49 0.53]; if centers(k,3)>8, color=[0.96 0.25 0.47]; end
        for c=1:3, channel=I(:,:,c); channel(mask)=color(c); I(:,:,c)=channel; end
    end
    % Printed dark ink and a neutral reflection should not become colonies.
    I(310:313,260:330,:)=0.1; I(320:335,275:278,:)=0.1;
    for c=1:3, I(600:603,330:470,c)=0.92; end
end
imwrite(I,file);
opts=colony_defaults(); opts.PlateEllipse=[400 400 330 330 0];
end

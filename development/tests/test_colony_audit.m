function tests=test_colony_audit
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'development','tests')));
tc.TestData.Root=root;
end

function testOneObjectOverlayAndExportForEveryLabel(tc)
[file,fixtureCleanup]=marking_fixture(); %#ok<ASGLU>
r=count_colonies(file,struct('PlateEllipse',[300 300 255 255 0]));r.Colonies=r.Colonies(1,:);
r.Labels(r.Labels~=r.Colonies.ID)=0;
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
for label=["AD9","AD24","Uncertain","Not a colony"]
 r.Colonies.Class(:)=label;r.Colonies.NeedsReview(:)=label=="Uncertain";
 r.Summary=summarize_colonies(r);
 files=save_colony_app_results(r,folder);
 verifyTrue(tc,isfile(files.Annotated));
 T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
 verifyEqual(tc,height(T),1);verifyEqual(tc,T.IncludedInCount,label~="Not a colony");
end
end

function testLargeRoundObjectDoesNotImplyMerge(tc)
[file,fixtureCleanup]=marking_fixture(); %#ok<ASGLU>
r=count_colonies(file,struct('PlateEllipse',[300 300 255 255 0]));
r.Colonies.Solidity(:)=1;r.Colonies.Circularity(:)=1;
r.Colonies.DiameterPixels(:)=3*r.DiameterThresholdPixels;
r.Colonies.DetectionNotes(:)="";r.Colonies.Reviewed(:)=false;
r=update_colony_warnings(r);verifyFalse(tc,any(r.Colonies.MergeWarning));
r.Colonies.Solidity(1)=.7;r=update_colony_warnings(r);
verifyTrue(tc,r.Colonies.MergeWarning(1));
end

function testIndistinguishableColorReferencesDoNotCrash(tc)
n=12;T=table((1:n)',repmat("not_split",n,1),false(n,1), ...
 'VariableNames',{'ID','SplitStatus','NeedsReview'});
for name=["CoreLogRG","CoreLogBG","CoreLogBrightness","CorePinkQ90", ...
 "CorePinkSpread","CoreToEdgePink","CoreBrightnessSpread"]
 T.(name)=ones(n,1);
end
r=struct('Colonies',T,'Options',colony_defaults(),'ClassifierModel', ...
 struct('Ready',true,'SeedAD9IDs',(1:6)','SeedAD24IDs',(7:12)'));
m=fit_colony_resolver(r);verifyFalse(tc,m.Ready);verifyTrue(tc,isfield(m,'FailureReason'));
end

function tests=test_batch_exports
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'development','tests')));
end

function testFreshEstimatesAndGeneratedOverlaysAreSkipped(tc)
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
folder=fileparts(file);
[opts,info]=estimate_colony_settings(file);
verifyTrue(tc,info.Estimated);
expected=prepare_colony_app_result(count_colonies(file,opts));
first=count_folder(folder);
verifyEqual(tc,first,expected.Summary);
verifyTrue(tc,isfile(fullfile(folder,'marking plate_colonies.xlsx')));
verifyTrue(tc,isfile(fullfile(folder,'marking plate_annotated.png')));
% A later run must process the original once, never its annotation PNG.
second=count_folder(folder);
verifyEqual(tc,second,first);
verifyTrue(tc,isfile(fullfile(folder,'marking plate_2_colonies.xlsx')));
verifyTrue(tc,isfile(fullfile(folder,'marking plate_2_annotated.png')));
listing=dir(folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(tc,numel(listing),5); verifyFalse(tc,any([listing.isdir]));
end

function testExplicitOverridesAndCompatibilitySave(tc)
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
folder=fileparts(file); output=fullfile(folder,'exports'); mkdir(output);
overrides=struct('SizeThresholdFraction',.03,'PinkContrastThreshold',.08);
opts=estimate_colony_settings(file);
opts.SizeThresholdFraction=.03; opts.PinkContrastThreshold=.08;
r=prepare_colony_app_result(count_colonies(file,opts));
actual=count_folder(folder,overrides,output);
verifyEqual(tc,actual,r.Summary);
saved=save_colony_results(r,output);
verifyEqual(tc,saved,output);
listing=dir(output); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(tc,numel(listing),4); verifyFalse(tc,any([listing.isdir]));
verifyTrue(tc,all(endsWith(string({listing.name}),[".xlsx" ".png"])));
end

function testRejectsBadDestinationsAndNoOriginals(tc)
fixture=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folder=fixture.Folder; missing=fullfile(folder,'missing');
verifyError(tc,@()count_folder(folder,struct(),missing),'CFU:OutputFolderMissing');
verifyFalse(tc,isfolder(missing));
verifyError(tc,@()count_folder(missing),'CFU:InputFolderMissing');
verifyError(tc,@()count_folder(folder,struct('Typo',1)),'CFU:UnknownOption');
imwrite(zeros(4,4,3),fullfile(folder,'previous_ANNOTATED.PNG'));
verifyError(tc,@()count_folder(folder),'CFU:NoImages');
end

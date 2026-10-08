function tests=test_colony_at_point
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
r.Scale=0.5; r.Labels=zeros(120,120,'uint32');
centers=[50 50;56 50;90 90;20 20]; original=(centers-0.5)/r.Scale+0.5;
r.Colonies=table([4;19;90;120],original(:,1),original(:,2),[30;10;24;12], ...
    ["AD24";"AD9";"Uncertain";"Not a colony"],[false;false;true;false], ...
    'VariableNames',{'ID','X','Y','EnclosingRadiusPixels','Class','NeedsReview'});
r.Labels(50,50)=4; r.Labels(50,56)=19; r.Labels(90,90)=90; r.Labels(20,20)=120;
testCase.TestData.Result=r;
end

function testPixelsResolveOverlappingCircles(testCase)
r=testCase.TestData.Result;
verifyEqual(testCase,colony_at_point(r,[56 50],false),19);
verifyEqual(testCase,colony_at_point(r,[50 50],false),4);
% Interior not covered by segmented pixels still belongs to a drawn circle.
verifyEqual(testCase,colony_at_point(r,[40 50],false),4);
% Pixels win even when the native click landed on a neighboring ring.
verifyEqual(testCase,colony_at_point(r,[56 50],false,4,true),19);
end

function testEdgesAndDisplayedCoordinateScale(testCase)
r=testCase.TestData.Result;
verifyEqual(testCase,colony_at_point(r,[65 50 0],false,4,true),4);
verifyEqual(testCase,colony_at_point(r,[61 50],false,19,true),19);
% Review rings include the three-pixel padding drawn by the overlay.
verifyEqual(testCase,colony_at_point(r,[105 90],true,90,true),90);
% The rendered stroke has screen-pixel width, which grows in image units
% when zoomed out. Native ring hits must not fail a fixed image-pixel cutoff.
verifyEqual(testCase,colony_at_point(r,[54 55],false,4,true),4);
end

function testHiddenExcludedAndBackgroundAreNotSelected(testCase)
r=testCase.TestData.Result;
verifyEmpty(testCase,colony_at_point(r,[50 50],true));
verifyEmpty(testCase,colony_at_point(r,[20 20],false));
verifyEmpty(testCase,colony_at_point(r,[115 10],false));
verifyEmpty(testCase,colony_at_point(r,[-10 50],false));
verifyEmpty(testCase,colony_at_point(r,[NaN 50],false));
r.Colonies=r.Colonies([],:);
verifyEmpty(testCase,colony_at_point(r,[50 50],false));
end

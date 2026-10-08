function tests=test_fit_plate_boundary
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testRotatedPlateWithClutterAndUnevenLight(testCase)
truth=[320 300 220 165 28]; I=fixture(truth,640,650);
seed=truth+[9 -10 22 17 5];
[fitted,info]=fit_plate_boundary(I,seed);
verifyTrue(testCase,info.Fitted);
verifyLessThan(testCase,boundaryError(fitted,truth),3);
% Multiplicative illumination and channel balance change over the photograph.
[x,y]=meshgrid(1:size(I,2),1:size(I,1));
gain=single(0.45+0.30*x/size(I,2)+0.15*y/size(I,1));
I=I.*gain.*reshape(single([0.9 1.05 0.8]),1,1,3);
[fitted,info]=fit_plate_boundary(I,seed);
verifyTrue(testCase,info.Fitted);
verifyLessThan(testCase,boundaryError(fitted,truth),3);
end

function testSelectsEitherPlateNotLargestRegion(testCase)
left=[280 300 220 195 14]; right=[850 290 240 210 -20];
I=max(fixture(left,600,1150),fixture(right,600,1150));
for column=[left;right]'
    truth=column'; seed=truth+[8 -7 18 20 -3];
    [fitted,info]=fit_plate_boundary(I,seed);
    verifyTrue(testCase,info.Fitted);
    verifyLessThan(testCase,boundaryError(fitted,truth),3);
end
end

function testWeakOrPartialEdgesLeaveBoundaryUnchanged(testCase)
seed=[300 300 240 210 0];
images={ones(600,600,3,'single')*.5,fixture([70 70 240 210 0],600,600)};
seeds={seed,[70 70 250 220 0]};
for k=1:numel(images)
    [fitted,info]=fit_plate_boundary(images{k},seeds{k});
    verifyFalse(testCase,info.Fitted);
    verifyEqual(testCase,fitted,seeds{k});
end
end

function testRandomTextureDoesNotInventARim(testCase)
state=rng; cleanup=onCleanup(@()rng(state));
rng(42); seed=[500 375 300 300 0];
for noise=[.005 .01 .02 .05]
    I=single(.5+noise*randn(750,1000,3));
    [fitted,info]=fit_plate_boundary(I,seed);
    verifyFalse(testCase,info.Fitted);
    verifyEqual(testCase,fitted,seed);
end
% Correlated texture also has strong gradients but no coherent circular rim.
I=imgaussfilt(single(rand(750,1000,3)),3);
[fitted,info]=fit_plate_boundary(I,seed);
verifyFalse(testCase,info.Fitted); verifyEqual(testCase,fitted,seed);
end

function testSuppliedPhotoFitsVisibleOuterRim(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
I=read_plate_image(fullfile(root,'Examples','IMG_7489.jpeg'));
seed=[1485.3 2170.9 1450 1560 0];
[fitted,info]=fit_plate_boundary(I,seed);
verifyTrue(testCase,info.Fitted);
% Approximate rim extent checked against the original image, not colony labels.
verifyEqual(testCase,fitted(1:2),[1485 2170],'AbsTol',15);
verifyGreaterThan(testCase,min(fitted(3:4)),1340);
verifyLessThan(testCase,max(fitted(3:4)),1410);
verifyGreaterThan(testCase,info.SupportedFraction,0.85);
end

function testOffsetUndersizedSeedFindsRotatedRim(testCase)
truth=[370 340 250 200 32]; I=fixture(truth,720,760);
seed=[270 320 170 155 0];
[fitted,info]=fit_plate_boundary(I,seed);
verifyTrue(testCase,info.Fitted); verifyEqual(testCase,info.SearchMethod,"contour");
verifyLessThan(testCase,boundaryError(fitted,truth),4);
[again,info]=fit_plate_boundary(I,fitted);
verifyTrue(testCase,info.Fitted); verifyLessThan(testCase,boundaryError(again,fitted),2);
end

function testBroadSearchKeepsTheSelectedPlate(testCase)
left=[280 310 220 200 15]; right=[850 300 240 215 -17];
I=max(fixture(left,640,1150),fixture(right,640,1150));
seeds=[left(1)-85 left(2)+5 155 155 0;right(1)+90 right(2)-8 165 160 0];
truths=[left;right];
for k=1:2
    [fitted,info]=fit_plate_boundary(I,seeds(k,:));
    verifyTrue(testCase,info.Fitted);
    verifyLessThan(testCase,boundaryError(fitted,truths(k,:)),4);
end
end

function testCroppedRimWinsOverInnerReflection(testCase)
truth=[690 390 350 332 82]; I=fixture(truth,750,1000);
[x,y]=meshgrid(1:1000,1:750); a=deg2rad(truth(5));
u=(x-truth(1))*cos(a)-(y-truth(2))*sin(a);
v=(x-truth(1))*sin(a)+(y-truth(2))*cos(a);
r=sqrt((u/truth(3)).^2+(v/truth(4)).^2);
I(repmat(r>.79 & r<.81,1,1,3))=.8;
% Both the user's offset seed and a seed close to the inner reflection must
% resolve to the supported outer rim, not the fully visible interior ring.
seeds=[552 357.75 225 252.75 0;truth.*[1 1 .81 .81 1]];
for k=1:2
    [fitted,info]=fit_plate_boundary(I,seeds(k,:));
    verifyTrue(testCase,info.Fitted);
    verifyLessThan(testCase,boundaryError(fitted,truth),4);
    verifyGreaterThan(testCase,info.VisibleFraction,.75);
    verifyLessThan(testCase,info.VisibleFraction,.98);
    verifyTrue(testCase,contains(info.Message,'cropped section'));
end
end

function testScreenshotPhotoWithOffsetSeed(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'Examples','AD9 0.125% 10(-6).HEIC');
assumeTrue(testCase,isfile(file),'The local HEIC research photo is not distributed in the app ZIP.');
I=read_plate_image(file); J=imresize(I,1000/max(size(I,1),size(I,2)));
seed=[.552*size(J,2) .477*size(J,1) .225*size(J,2) .337*size(J,1) 0];
[fitted,info]=fit_plate_boundary(J,seed);
verifyTrue(testCase,info.Fitted); verifyEqual(testCase,info.SearchMethod,"contour");
% Independent approximate outer-rim geometry from the supplied photograph.
verifyEqual(testCase,fitted(1:2),[692 390],'AbsTol',5);
verifyEqual(testCase,sort(fitted(3:4)),[333 349],'AbsTol',5);
verifyLessThan(testCase,info.VisibleFraction,.98);
[again,info]=fit_plate_boundary(J,fitted);
verifyTrue(testCase,info.Fitted); verifyLessThan(testCase,boundaryError(again,fitted),2);
% Coordinate conversion at the original HEIC resolution must be consistent.
scale=1000/max(size(I,1),size(I,2)); original=seed;
original(1:2)=(original(1:2)-.5)/scale+.5; original(3:4)=original(3:4)/scale;
[full,info]=fit_plate_boundary(I,original);
verifyTrue(testCase,info.Fitted);
full(1:2)=(full(1:2)-.5)*scale+.5; full(3:4)=full(3:4)*scale;
verifyLessThan(testCase,boundaryError(full,fitted),2);
end

function I=fixture(e,height,width)
[x,y]=meshgrid(1:width,1:height); a=deg2rad(e(5));
u=(x-e(1))*cos(a)-(y-e(2))*sin(a);
v=(x-e(1))*sin(a)+(y-e(2))*cos(a);
r=sqrt((u/e(3)).^2+(v/e(4)).^2);
I=repmat(single(.09),height,width,3);
for c=1:3
    bg=[.58 .35 .32]; channel=I(:,:,c);
    channel(r<=1)=bg(c); channel(r>.972 & r<=1)=.85;
    I(:,:,c)=channel;
end
% Strong colony and ink-like edges in the interior; only rim is continuous.
spots=mod(floor(x/34)+floor(y/39),3)==0 & mod(x,34)<9 & mod(y,39)<9 & r<.93;
for c=1:3
    color=[.95 .25 .5]; channel=I(:,:,c); channel(spots)=color(c); I(:,:,c)=channel;
end
glare=(x-e(1)-.80*e(3)).^2+(y-e(2)).^2<(0.12*e(3))^2;
I(repmat(glare,1,1,3))=.97;
end

function error=boundaryError(e,truth)
t=linspace(0,2*pi,360); a=deg2rad(e(5));
x=e(1)+e(3)*cos(t)*cos(a)+e(4)*sin(t)*sin(a);
y=e(2)-e(3)*cos(t)*sin(a)+e(4)*sin(t)*cos(a);
a=deg2rad(truth(5));
u=(x-truth(1))*cos(a)-(y-truth(2))*sin(a);
v=(x-truth(1))*sin(a)+(y-truth(2))*cos(a);
error=max(abs(sqrt((u/truth(3)).^2+(v/truth(4)).^2)-1))*max(truth(3:4));
end

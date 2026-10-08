function tests=test_rim_photo_set
% Local photo regression set; HEIC research photos are not bundled in ZIP.
% Tests measure rim geometry and repeatability, not colony-count accuracy.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
names={ ...
    'AD24 0.125% 10(-4).HEIC';'AD24 0.125% 10(-6).HEIC'; ...
    'AD24 10% 10(-4).HEIC';'AD24 10% 10(-6).HEIC'; ...
    'AD24 MM 10(-4).HEIC';'AD24 MM 10(-6).HEIC'; ...
    'AD9 + AD24 0.125% 10(-4).HEIC';'AD9 + AD24 0.125% 10(-6).HEIC'; ...
    'AD9 + AD24 10% 10(-4).HEIC';'AD9 + AD24 10% 10(-6).HEIC'; ...
    'AD9 + AD24 MM 10(-4).HEIC';'AD9 + AD24 MM 10(-6).HEIC'; ...
    'AD9 0.125% 10(-4).HEIC';'AD9 0.125% 10(-6).HEIC'; ...
    'AD9 10% 10(-4).HEIC';'AD9 10% 10(-6).HEIC'; ...
    'AD9 MM 10(-4).HEIC';'AD9 MM 10(-6).HEIC'; ...
    'No bacteria MM.HEIC';'IMG_7489.jpeg'};
paths=fullfile(root,'Examples',names);
assumeTrue(testCase,all(cellfun(@isfile,paths)), ...
    'The complete local HEIC photo set is not distributed with the app.');
images=cell(size(names));
for k=1:numel(names)
    I=read_plate_image(paths{k});
    images{k}=imresize(I,1000/max(size(I,1),size(I,2)));
end
testCase.TestData.Images=images;
testCase.TestData.Names=names;
% Approximate centers and horizontal/vertical extents read from the photos
% BEFORE fitting. These deliberately loose references catch wrong plates or
% interior-ring fits; they are not precise, independently labeled boundaries.
testCase.TestData.Reference=[ ...
    625 365 315 330 0;670 352 315 333 0;600 365 315 330 0;545 410 355 366 0; ...
    595 340 310 330 0;650 380 312 332 0;650 411 290 301 0;670 401 310 328 0; ...
    650 364 312 323 0;680 437 305 314 0;698 367 293 289 0;720 395 290 300 0; ...
    620 380 275 293 0;692 390 333 349 0;550 382 315 329 0;621 409 326 341 0; ...
    598 380 323 341 0;650 341 310 323 0;686 416 304 319 0;368 537 341 339 0];
end

function testThreePlacementsAndRepeatFit(testCase)
for k=1:numel(testCase.TestData.Images)
    I=testCase.TestData.Images{k}; reference=testCase.TestData.Reference(k,:);
    seeds=roughSeeds(reference); fits=zeros(3,5);
    for j=1:3
        [fits(j,:),info]=fit_plate_boundary(I,seeds(j,:));
        verifyTrue(testCase,info.Fitted,testCase.TestData.Names{k});
        verifyLessThan(testCase,boundaryError(fits(j,:),reference),25);
        verifyLessThan(testCase,boundaryError(fits(j,:),fits(1,:)),2);
    end
    [again,info]=fit_plate_boundary(I,fits(2,:));
    verifyTrue(testCase,info.Fitted);
    verifyLessThan(testCase,boundaryError(again,fits(2,:)),2);
end
end

function testExposureColorBalanceAndBlur(testCase)
state=rng; cleanup=onCleanup(@()rng(state));
rng(42);
for k=1:numel(testCase.TestData.Images)
    I=im2single(testCase.TestData.Images{k});
    seeds=roughSeeds(testCase.TestData.Reference(k,:)); seed=seeds(2,:);
    [baseline,info]=fit_plate_boundary(I,seed); verifyTrue(testCase,info.Fitted);
    x=single(linspace(0,1,size(I,2)));
    variants={I*.22, I.*(.3+.65*x).*reshape(single([1.25 .85 .6]),1,1,3), ...
        I.^2.2, imgaussfilt(I,2)+.008*randn(size(I),'single')};
    for j=1:numel(variants)
        [fitted,info]=fit_plate_boundary(variants{j},seed);
        verifyTrue(testCase,info.Fitted,sprintf('%s, variant %d',testCase.TestData.Names{k},j));
        % Consistency relative to the original photograph, not accuracy.
        verifyLessThan(testCase,boundaryError(fitted,baseline),12);
    end
end
end

function testBareTabletopDoesNotFit(testCase)
% These left-side patches were visually checked to contain only tabletop.
for k=[1 3 5 7 9 11 13 15 16 17 18 19]
    I=testCase.TestData.Images{k}(120:300,30:210,:); seed=[91 91 65 65 0];
    [fitted,info]=fit_plate_boundary(I,seed);
    verifyFalse(testCase,info.Fitted,testCase.TestData.Names{k});
    verifyEqual(testCase,fitted,seed);
end
end

function seeds=roughSeeds(e)
seeds=[e(1:2)+[.03 -.03].*e(3:4),1.06*e(3:4),0; ...
    e(1:2)+[-.40 -.10].*e(3:4),.72*e(3:4),0; ...
    e(1:2)+[.20 .10].*e(3:4),.88*e(3:4),0];
end

function error=boundaryError(e,reference)
t=linspace(0,2*pi,360);a=deg2rad(e(5));
x=e(1)+e(3)*cos(t)*cos(a)+e(4)*sin(t)*sin(a);
y=e(2)-e(3)*cos(t)*sin(a)+e(4)*sin(t)*cos(a);
a=deg2rad(reference(5));
u=(x-reference(1))*cos(a)-(y-reference(2))*sin(a);
v=(x-reference(1))*sin(a)+(y-reference(2))*cos(a);
error=max(abs(sqrt((u/reference(3)).^2+(v/reference(4)).^2)-1))*max(reference(3:4));
end

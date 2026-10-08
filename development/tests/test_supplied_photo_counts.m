function tests=test_supplied_photo_counts
% Regression safeguards on inspected photos, not independent count accuracy.
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'development','tests')));
tc.TestData.Cases=supplied_photo_cases(root);
end
function testEverySuppliedOriginal(tc)
cases=tc.TestData.Cases;
assumeTrue(tc,all(isfile(cases.File)),'Local HEIC photos are not bundled with the portable app.');
for k=1:height(cases)
 I=read_plate_image(cases.File(k));scale=1000/max(size(I,1),size(I,2));
 e=cases.RoughEllipse(k,:);seed=[e(1:2)+[-.4 -.1].*e(3:4),.72*e(3:4),0];
 [e,info]=fit_plate_boundary(imresize(I,scale),seed);
 verifyTrue(tc,info.Fitted,char(cases.Name(k)));
 e(1:2)=(e(1:2)-.5)/scale+.5;e(3:4)=e(3:4)/scale;
 [opts,estimated]=estimate_colony_settings(cases.File(k),e);
 verifyTrue(tc,estimated.Estimated,char(cases.Name(k)));
 r=prepare_colony_app_result(count_colonies(cases.File(k),opts));
 T=r.Colonies;S=r.Summary;
 verifyEqual(tc,S.Total,S.AD9+S.AD24+S.Uncertain);
 verifyEqual(tc,height(T),S.Total);
 verifyEqual(tc,numel(unique(r.Labels(r.Labels>0))),height(T));
 verifyTrue(tc,all(r.ROI(r.Labels>0)));verifyEqual(tc,numel(unique(T.ID)),height(T));
 verifyTrue(tc,all(isfinite(T.X)&isfinite(T.Y)));
 if ismember(k,[6 12 19])
  % Visually inspected selected plates: no convincing localized pink colonies.
  verifyEqual(tc,S.Total,0,char(cases.Name(k)));
 elseif k==8
  % Three isolated large pink colonies, distinct from lettering/reflections.
  verifyEqual(tc,S.Total,3);verifyEqual(tc,S.AD24,3);verifyEqual(tc,S.Uncertain,0);
 else
  verifyGreaterThan(tc,S.AD9+S.AD24,S.Uncertain,char(cases.Name(k)));
 end
 % Empty, singleton and single-class overlays must all render safely.
 f=plot_colonies(r,false,'off');verifyTrue(tc,isgraphics(f));close(f);
end
end

function testEveryOriginalLoadsAndEstimates(tc)
cases=tc.TestData.Cases;
assumeTrue(tc,all(isfile(cases.File)),'Local HEIC photos are not bundled with the portable app.');
app=ColonyCounterApp('','off');cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
for k=1:height(cases)
 app.loadImage(cases.File(k));
 verifyEmpty(tc,app.LastError,char(cases.Name(k)));
 verifyTrue(tc,app.EstimationInfo.Estimated,char(cases.Name(k)));
 verifyEmpty(tc,app.Result);verifyEmpty(tc,app.Options.PlateEllipse);
 ring=findobj(app.ImageAxes,'Tag','PlateBoundary');
 verifyEqual(tc,numel(ring),1,char(cases.Name(k)));
 verifyEqual(tc,string(ring.HitTest),"off");verifyEqual(tc,string(ring.PickableParts),"none");
 verifyEmpty(tc,findobj(app.ImageAxes,'Type','images.roi.Ellipse'));
 verifyEqual(tc,app.Controls.MinDiameterFraction.Edit.Value,100*app.Options.MinDiameterFraction);
 verifyEqual(tc,app.Controls.PinkContrastThreshold.Edit.Value,app.Options.PinkContrastThreshold);
 % One click must fit the proposed main plate, before any Apply or editor click.
 feval(app.Buttons.View.ButtonPushedFcn,app.Buttons.View,[]);
 verifyEmpty(tc,app.LastError,char(cases.Name(k)));
 verifyTrue(tc,contains(app.StatusLabel.Text,'Boundary fitted'),char(cases.Name(k)));
 roi=findobj(app.ImageAxes,'Type','images.roi.Ellipse');
 assertEqual(tc,numel(roi),1,char(cases.Name(k)));
 pic=findobj(app.ImageAxes,'Type','image');scale=1000/max(size(pic.CData,1),size(pic.CData,2));
 fitted=[(roi.Center-.5)*scale+.5,sort(roi.SemiAxes)*scale];
 target=cases.RoughEllipse(k,:);
 verifyLessThanOrEqual(tc,max(abs(fitted(1:2)-target(1:2))),25,char(cases.Name(k)));
 verifyLessThanOrEqual(tc,max(abs(fitted(3:4)-sort(target(3:4)))),25,char(cases.Name(k)));
 verifyEmpty(tc,app.Result);
end
end

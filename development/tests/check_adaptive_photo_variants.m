function S=check_adaptive_photo_variants(root)
%CHECK_ADAPTIVE_PHOTO_VARIANTS Re-estimate five variants of every original.
% Run with the project and tests folders on the path. Returns a table only;
% temporary image files are cleaned up. Requires the local 20-photo corpus.
if nargin<1,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
cases=supplied_photo_cases(root);assert(all(isfile(cases.File)),'The full original photo corpus is required.');
S=table;
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
for k=1:20
 original=read_plate_image(cases.File(k));scale=1000/max(size(original,1),size(original,2));
 e=cases.RoughEllipse(k,:);seed=[e(1:2)+[-.4 -.1].*e(3:4),.72*e(3:4),0];
 [e,fitInfo]=fit_plate_boundary(imresize(original,scale),seed);assert(fitInfo.Fitted);
 e(1:2)=(e(1:2)-.5)/scale+.5;e(3:4)=e(3:4)/scale;
 o=estimate_colony_settings(cases.File(k),e);
 b=prepare_colony_app_result(count_colonies(cases.File(k),o));I=b.Image;linear=rgb2lin(I);
 for j=1:5
  e=b.CountingEllipseWork;
  switch j
   case 1, V=I;name="reencoded";
   case 2, V=lin2rgb(linear*.45);name="dimmer";
   case 3, V=lin2rgb(linear.*reshape(single([.55 .75 .65]),1,1,3));name="white_balance";
   case 4
    [x,y]=meshgrid(linspace(0,1,size(I,2)),linspace(0,1,size(I,1)));
    V=lin2rgb(linear.*single(.45+.35*(x+y)/2));name="smooth_shadow";
   case 5
    V=imresize(rot90(I),.8);name="rotated_resized";
    e=[e(2),size(I,2)-e(1)+1,e(3:4),e(5)+90];e(1:2)=(e(1:2)-.5)*.8+.5;e(3:4)=e(3:4)*.8;
  end
  file=fullfile(folder,'unseen_pixels.png');imwrite(im2uint16(max(0,min(1,V))),file);
  % Critically: derive NEW settings, not the originals' previous options.
  [o,info]=estimate_colony_settings(file,e);
  r=prepare_colony_app_result(count_colonies(file,o));assert(info.Estimated);
  assert(r.Summary.Total==r.Summary.AD9+r.Summary.AD24+r.Summary.Uncertain);
  row=table(k,string(b.Summary.Image),name,b.Summary.Total,r.Summary.Total,r.Summary.AD9,r.Summary.AD24,r.Summary.Uncertain, ...
   o.PinkContrastThreshold,o.MinDiameterFraction,o.WatershedPeakFraction,o.ArtifactFilterStrength, ...
   'VariableNames',{'Photo','Image','Variant','BaselineTotal','Total','AD9','AD24','Review','PinkThreshold','MinDiameter','SeparationPeak','ArtifactStrength'});
  S=[S;row];fprintf('Re-estimate %02d %s %d -> %d; review%d\n',k,name,b.Summary.Total,r.Summary.Total,r.Summary.Uncertain);
 end
end
end

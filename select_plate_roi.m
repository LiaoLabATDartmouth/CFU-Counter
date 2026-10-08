function ellipse = select_plate_roi(imageFile)
%SELECT_PLATE_ROI Draw/edit the usable agar boundary; double-click to accept.
% opts.PlateEllipse=select_plate_roi('my_plate.jpg');
% result=count_colonies('my_plate.jpg',opts);
fig=figure('Name','Select usable agar: double-click ellipse to accept');
cleanup=onCleanup(@()closeIfValid(fig));
imshow(read_plate_image(imageFile));
title('Draw ellipse around usable agar; adjust it, then double-click to accept.');
r=drawellipse('Color','yellow');
if ~isvalid(r), error('CFU:Cancelled','ROI selection cancelled.'); end
wait(r);
if ~isvalid(r), error('CFU:Cancelled','ROI selection cancelled.'); end
ellipse=[r.Center r.SemiAxes r.RotationAngle];
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end

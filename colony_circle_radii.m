function radius=colony_circle_radii(T,scale)
%COLONY_CIRCLE_RADII Display radii; manual center marks are not measurements.
radius=T.EnclosingRadiusPixels*scale;
radius(~isfinite(radius))=5; radius=max(3,radius);
if ismember('MarkerRadiusPixels',T.Properties.VariableNames)
    manual=isfinite(T.MarkerRadiusPixels) & T.MarkerRadiusPixels>0;
    radius(manual)=max(1.5,T.MarkerRadiusPixels(manual)*scale);
end
end

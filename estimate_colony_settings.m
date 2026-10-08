function [opts,info]=estimate_colony_settings(imageFile,plateEllipse)
%ESTIMATE_COLONY_SETTINGS Estimate editable settings from the current pixels.
% No filenames, hashes, stored photo profiles, or class counts are consulted.
% The pilot uses fixed settings; count_colonies never calls this estimator.
% A selected ellipse is in upright original-image coordinates. Without one,
% the pilot proposes the largest pink region; check it on multi-plate images.
if nargin<2, plateEllipse=[]; end
opts=colony_defaults(); opts.PlateEllipse=plateEllipse;
info=struct('Estimated',false,'Method',"Image content / version 2", ...
    'Message',"Choose a plate boundary to estimate its settings.");
pilotOptions=opts;
pilotOptions.ArtifactFilterStrength=0;
pilotOptions.ClassifierMode="size";
pilotOptions.SplitTouchingColonies=false;
pilotOptions.ResolveAmbiguousClassification=false;
try
    pilot=count_colonies(imageFile,pilotOptions);
catch err
    if ismember(string(err.identifier),["CFU:NoPlate","CFU:EmptyROI"])
        info.Message=string(err.message)+" Choose the plate boundary to estimate settings.";
        return
    end
    rethrow(err)
end
[opts,info]=derive_colony_settings(pilot);
end

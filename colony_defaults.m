function opts = colony_defaults()
%COLONY_DEFAULTS Settings for pink colonies on MacConkey agar.
% Sizes are fractions of the counting ellipse diameter unless specified.
% AD9 = smaller colonies; AD24 = larger colonies (user-defined labels).
opts.MaxImageDimension = 1800;
opts.PlateEllipse = []; % [centerX centerY radiusX radiusY angleDegrees], ORIGINAL pixels
opts.PlateInset = 0.94; % Used only with automatic plate detection
opts.MinDiameterFraction = 0.005;
opts.MaxDiameterFraction = 0.05;
opts.BackgroundSigmaFraction = 0.015;
opts.PinkContrastThreshold = 0.06; % Local log(R*B/G^2) contrast in linear RGB
opts.RedContrastThreshold = 0.04; % Local log red-channel brightness contrast
opts.PaleBrightnessThreshold = 0.20; % Detect pale colonies by local log brightness
opts.MinLocalPinkDifference = 0.04; % Minimum log pink contrast against local annulus
opts.ArtifactFilterStrength = 1; % 0 disables extra ink/reflection rejection; larger is stricter
opts.WatershedPeakFraction = 0.0007;
opts.MaxEccentricity = 0.93;
opts.MinSolidity = 0.65;
opts.MinCircularity = 0.32;
opts.SizeThresholdFraction = 0.018;
opts.DiameterThresholdPixels = []; % Optional override in ORIGINAL image pixels
opts.SizeReviewFraction = 0.10; % Flag diameters within +/-10% of the cutoff
opts.EdgeReviewFraction = 0.90; % Record outer-rim diagnostics; not a warning alone
opts.ClassifierMode = "composite"; % "composite" or "size"
opts.ClassifierModel = []; % Reuse a model from fit_colony_classifier
opts.ShrinkageCandidates = [0.01 0.05 0.10 0.25 0.50 0.75 1];
opts.CompositeReviewMargin = 0.25; % Absolute Fisher score; not a probability
opts.SplitTouchingColonies = true; % Internal splitting only; outer masks preserved
opts.ResolveAmbiguousClassification = true; % Corroborating clean-interior color model
opts.ClassificationResolverModel = []; % Paired model for reuse across images
opts.ResolverBootstrapSamples = 100; % Deterministic reference-resampling check
end

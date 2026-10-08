function [F,names,floors]=colony_resolution_matrix(T)
%COLONY_RESOLUTION_MATRIX Interior color/distribution features, without size.
names=["CoreLogRG","CoreLogBG","CoreLogBrightness","CorePinkQ90", ...
    "CorePinkSpread","CoreToEdgePink","CoreBrightnessSpread"];
F=T{:,cellstr(names)};
floors=[0.05 0.05 0.08 0.10 0.08 0.05 0.08];
end

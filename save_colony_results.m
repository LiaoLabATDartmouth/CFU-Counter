function outputFolder=save_colony_results(result,outputFolder)
%SAVE_COLONY_RESULTS Compatibility entry point for the two-file export.
% Writes <image>_colonies.xlsx and <image>_annotated.png in an existing folder.
% Use save_colony_app_results to receive both output paths instead.
if nargin<2 || strlength(string(outputFolder))==0
    outputFolder=fileparts(char(result.ImageFile));
    if isempty(outputFolder), outputFolder=pwd; end
end
save_colony_app_results(result,outputFolder);
end

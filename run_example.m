% RUN_EXAMPLE Estimate settings and count the supplied photograph.
% MATLAB with Image Processing Toolbox. Use launch_colony_app for plate selection.
projectFolder=fileparts(mfilename('fullpath'));
addpath(projectFolder);
imageFile=fullfile(projectFolder,'Examples','IMG_7489.jpeg');
% The same pixel-based rule is used for this image and new photographs.
% For multiple plates, pass a selected original-pixel ellipse as argument 2.
[opts,info]=estimate_colony_settings(imageFile);
result=prepare_colony_app_result(count_colonies(imageFile,opts));
result.EstimationInfo=info;
files=save_colony_app_results(result,projectFolder);
disp(result.Summary);
fprintf('Workbook: %s\nAnnotated image: %s\n',files.Workbook,files.Annotated);

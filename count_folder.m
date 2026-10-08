function summary=count_folder(inputFolder,overrides,outputFolder)
%COUNT_FOLDER Estimate settings for each original and save two files per image.
% summary=count_folder('Examples',struct(),'existing_output_folder');
% Explicit overrides take precedence over the pixel-derived settings.
% Outputs go into an existing folder (inputFolder by default), without
% subfolders or an extra summary file. App-exported *_annotated.png files are
% skipped, so saving beside the originals does not feed overlays back in.
% Automatic plate selection is used unless overrides.PlateEllipse is given;
% use the app to choose individual plates in a multi-plate photograph.
if nargin<2, overrides=struct(); end
if nargin<3, outputFolder=inputFolder; end
if ~isfolder(inputFolder)
    error('CFU:InputFolderMissing','Input folder does not exist: %s.',inputFolder);
end
if ~isfolder(outputFolder)
    error('CFU:OutputFolderMissing','Choose an existing output folder. No subfolder is created.');
end
validateattributes(overrides,{'struct'},{'scalar'});
names=fieldnames(overrides); defaults=colony_defaults(); ellipse=[];
for k=1:numel(names)
    if ~isfield(defaults,names{k})
        error('CFU:UnknownOption','Unknown option: %s',names{k});
    end
end
if isfield(overrides,'PlateEllipse'), ellipse=overrides.PlateEllipse; end
files=dir(inputFolder); summary=table();
extensions=[".jpg",".jpeg",".png",".tif",".tiff",".bmp",".heic",".heif"];
for i=1:numel(files)
    if files(i).isdir, continue; end
    [~,name,ext]=fileparts(files(i).name);
    if ~ismember(lower(string(ext)),extensions), continue; end
    if strcmpi(ext,'.png') && endsWith(lower(string(name)),"_annotated"), continue; end
    file=fullfile(files(i).folder,files(i).name);
    [options,info]=estimate_colony_settings(file,ellipse);
    for k=1:numel(names), options.(names{k})=overrides.(names{k}); end
    result=prepare_colony_app_result(count_colonies(file,options));
    result.EstimationInfo=info;
    save_colony_app_results(result,outputFolder);
    summary=[summary;result.Summary]; %#ok<AGROW>
end
if isempty(summary), error('CFU:NoImages','No supported original images found in %s.',inputFolder); end
end

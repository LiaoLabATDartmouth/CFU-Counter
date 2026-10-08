function files=save_colony_app_results(result,folder)
%SAVE_COLONY_APP_RESULTS Save exactly one Excel workbook and one annotated PNG.
% Writes directly into an existing folder; filenames inherit the image stem.
% Repeated saves use the same numeric suffix for both files, without overwrite.
if nargin<2 || strlength(string(folder))==0
    folder=fileparts(char(result.ImageFile));
    if isempty(folder), folder=pwd; end
end
folder=char(folder);
if ~isfolder(folder)
    error('CFU:OutputFolderMissing','Choose an existing folder. No results subfolder is created.');
end
[~,name,extension]=fileparts(char(result.ImageFile));
if isempty(name), name='plate'; end
[colonies,summary,snapshot]=colony_export_tables(result);
% Prepare both files before publishing either. Temporary files are outside
% the chosen output folder and removed on success or failure.
stage=tempname; mkdir(stage); cleanup=onCleanup(@()rmdir(stage,'s')); %#ok<NASGU>
workbook=fullfile(stage,'colonies.xlsx'); annotated=fullfile(stage,'annotated.png');
writetable(colonies,workbook,'Sheet','Colonies','UseExcel',false);
writetable(summary,workbook,'Sheet','Summary','UseExcel',false);
writecell({'Image',[name extension];'Coordinates','Upright original-image pixels'; ...
    'Labels','Current labels at save time; Not a colony objects are not circled.'; ...
    'OriginalSuggestion','Original prediction only; Label controls the figure and summary.'; ...
    'Manual marks','MarkerRadiusPixels is a display radius; measurements remain blank. MarkedFromID is the replaced object ID.'}, ...
    workbook,'Sheet','Summary','Range','A9','UseExcel',false);
if isfield(result,'ClassificationInfo')
    writecell({'Automatic classification',char(result.ClassificationInfo.Message)}, ...
        workbook,'Sheet','Summary','Range','A14','UseExcel',false);
end
if isfield(result,'Options')
    o=result.Options;
    settings={'Minimum diameter (% of plate)',100*o.MinDiameterFraction; ...
        'Separation peak (% of plate)',100*o.WatershedPeakFraction; ...
        'Ink / reflection rejection',o.ArtifactFilterStrength; ...
        'Processing image size (pixels)',o.MaxImageDimension; ...
        'AD9 / AD24 size reference (%)',100*o.SizeThresholdFraction; ...
        'Pink color threshold',o.PinkContrastThreshold; ...
        'Pale colony threshold',o.PaleBrightnessThreshold; ...
        'Review sensitivity',o.CompositeReviewMargin; ...
        'Size review margin (%)',100*o.SizeReviewFraction; ...
        'Counting ellipse (original pixels)',mat2str([(result.CountingEllipseWork(1:2)-.5)/result.Scale+.5, ...
            result.CountingEllipseWork(3:4)/result.Scale,result.CountingEllipseWork(5)],8); ...
        'Maximum diameter (% of plate)',100*o.MaxDiameterFraction; ...
        'Background scale (% of plate)',100*o.BackgroundSigmaFraction};
    writecell(settings,workbook,'Sheet','Summary','Range','A16','UseExcel',false);
end
if isfield(result,'EstimationInfo') && isfield(result.EstimationInfo,'Method')
    writecell({'Settings estimator',char(result.EstimationInfo.Method)}, ...
        workbook,'Sheet','Summary','Range','A28','UseExcel',false);
end
format_colony_workbook(workbook,colonies,summary);
% Always include all current labels and IDs, independent of app display filters.
fig=plot_colonies(snapshot,true,'off'); closeFig=onCleanup(@()close(fig));
exportgraphics(fig,annotated,'Resolution',240); clear closeFig
base=name; suffix=2;
while occupied(folder,base)
    base=sprintf('%s_%d',name,suffix); suffix=suffix+1;
end
files=struct('Workbook',fullfile(folder,[base '_colonies.xlsx']), ...
    'Annotated',fullfile(folder,[base '_annotated.png']));
[ok,message]=movefile(workbook,files.Workbook);
if ~ok, error('CFU:WriteFailed','Could not save the workbook: %s',message); end
try
    [ok,message]=movefile(annotated,files.Annotated);
    if ~ok, error('CFU:WriteFailed','Could not save the annotated image: %s',message); end
catch err
    % Roll back only the new file from this save, never previous exports.
    if isfile(files.Workbook), delete(files.Workbook); end
    rethrow(err);
end
end

function exists=occupied(folder,base)
paths={fullfile(folder,[base '_colonies.xlsx']),fullfile(folder,[base '_annotated.png'])};
exists=any(cellfun(@(p)isfile(p) || isfolder(p),paths));
end

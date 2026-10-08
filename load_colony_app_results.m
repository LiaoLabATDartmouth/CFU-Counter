function [result,state,lease]=load_colony_app_results(workbook,imageFile)
%LOAD_COLONY_APP_RESULTS Resume a saved workbook without rerunning detection.
% Keep lease alive while using result: it owns the extracted source photo.
% Older workbooks need their original photo (optional second argument).
if nargin<2, imageFile=""; end
if ~isfile(workbook), error('CFU:MissingWorkbook','Workbook does not exist.'); end
folder=tempname; mkdir(folder); lease=onCleanup(@()rmdir(folder,'s'));
% Reject unsafe archive paths and implausibly large payloads before extraction.
archive=java.util.zip.ZipFile(java.io.File(char(workbook)));
closeArchive=onCleanup(@()archive.close()); entries=archive.entries(); total=0;
while entries.hasMoreElements()
    entry=entries.nextElement(); name=char(entry.getName());
    parts=regexp(strrep(name,'\','/'),'/','split');
    total=total+max(0,double(entry.getSize()));
    if startsWith(name,{'/','\'}) || contains(name,':') || any(strcmp(parts,'..')) || total>2e9
        error('CFU:InvalidSession','Unsafe or oversized workbook archive.');
    end
end
clear closeArchive
unzip(workbook,folder);
manifest=fullfile(folder,'cfuSession','manifest.json');
if ~isfile(manifest)
    result=import_colony_workbook(workbook,imageFile);
    result.ImageFile=string(copySource(result.ImageFile,folder));
    state=struct('Message',['Imported older workbook. Saved labels and circles restored. ' ...
        'Original merge undo history and settings absent from the workbook cannot be recovered.']);
    return
end
payload=colony_session_data('read',fileparts(manifest));
if ~isstruct(payload) || ~all(isfield(payload,{'Result','State','SourceName','EmbeddedSource'}))
    error('CFU:InvalidSession','Incomplete session metadata.');
end
result=payload.Result; state=payload.State;
validateSession(result,state);
name=char(payload.SourceName);
if isempty(name) || contains(name,{'/','\',':'}) || ismember(name,{'.','..'})
    error('CFU:InvalidSession','Invalid source photo name.');
end
if payload.EmbeddedSource
    sourceFolder=fullfile(folder,'source'); mkdir(sourceFolder);
    source=fullfile(sourceFolder,name);
    copyfile(fullfile(folder,'cfuSession','source.bin'),source);
elseif strlength(string(imageFile))>0 && isfile(imageFile)
    source=char(imageFile);
elseif isfile(result.ImageFile)
    source=char(result.ImageFile);
elseif isfile(fullfile(fileparts(workbook),name))
    source=fullfile(fileparts(workbook),name);
else
    error('CFU:OriginalImageRequired','This workbook has no embedded photo. Select the original photo: %s',name);
end
% The visible Label column remains authoritative if labels were edited in Excel.
T=readtable(workbook,'Sheet','Colonies','TextType','string');
[saved,~,result]=colony_export_tables(result);
if ~all(ismember({'ID','Label','X','Y'},T.Properties.VariableNames)) || ...
        height(T)~=height(saved) || numel(unique(T.ID))~=height(T)
    error('CFU:WorkbookChanged','Colony rows were added or removed outside the app. Reopen an unmodified workbook.');
end
[found,rows]=ismember(saved.ID,T.ID);
if ~all(found) || any(abs(saved.X-T.X(rows))>1e-6 | abs(saved.Y-T.Y(rows))>1e-6)
    error('CFU:WorkbookChanged','Colony IDs or positions no longer match the saved session.');
end
labels=string(T.Label(rows));
if any(~ismember(labels,["Need review","AD9","AD24","Not a colony"]))
    error('CFU:InvalidClass','Workbook labels must be Need review, AD9, AD24, or Not a colony.');
end
for k=reshape(find(labels~=saved.Label),1,[])
    label=labels(k); if label=="Need review", label="Uncertain"; end
    result=edit_colony(result,'classify',saved.ID(k),label);
end
if ~payload.EmbeddedSource, source=copySource(source,folder); end
result.ImageFile=string(source); result.Summary=summarize_colonies(result);
state.Message='Saved work restored. Continue reviewing, or change settings and click Apply and classify.';
end

function source=copySource(file,folder)
% Own the photo before an app releases the previously open session's files.
[~,name,ext]=fileparts(file); destination=fullfile(folder,'source'); mkdir(destination);
source=fullfile(destination,[char(name) char(ext)]); copyfile(file,source);
end

function validateSession(r,state)
required={'ImageFile','Image','Labels','ROI','Colonies','Options','Scale','CountingEllipseWork', ...
    'OriginalImageSize','Rejected','ReviewLog','DiameterThresholdPixels','ROISource'};
if ~isstruct(r) || ~isscalar(r) || ~all(isfield(r,required)) || ~isstruct(state) || ~isscalar(state)
    error('CFU:InvalidSession','Incomplete saved analysis.');
end
if ~istable(r.Colonies) || ~isnumeric(r.Image) || ndims(r.Image)~=3 || size(r.Image,3)~=3 || ...
        ~isequal(size(r.Labels),size(r.ROI),[size(r.Image,1),size(r.Image,2)])
    error('CFU:InvalidSession','Saved image, boundaries and labels have inconsistent dimensions.');
end
validateattributes(r.Scale,{'numeric'},{'scalar','finite','positive','<=',1});
validateattributes(r.CountingEllipseWork,{'numeric'},{'vector','numel',5,'finite'});
defaults=colony_defaults();
if ~isstruct(r.Options) || ~all(isfield(r.Options,fieldnames(defaults)))
    error('CFU:InvalidSession','Saved counting settings are incomplete.');
end
names={'ID','X','Y','Class','NeedsReview','Reviewed','Source','EnclosingRadiusPixels'};
if ~all(ismember(names,r.Colonies.Properties.VariableNames))
    error('CFU:InvalidSession','Saved colony table is incomplete.');
end
validateattributes(r.OriginalImageSize,{'numeric'},{'vector','numel',3,'finite','positive','integer'});
validateattributes(r.Labels,{'numeric'},{'real','nonnegative','integer'});
if any(r.CountingEllipseWork(3:4)<=0) || ...
        any(~isfinite(r.Colonies.X) | ~isfinite(r.Colonies.Y))
    error('CFU:InvalidSession','Invalid saved boundary or colony coordinates.');
end
if isfield(r,'ManualGroups') && ~isempty(r.ManualGroups)
    if ~isstruct(r.ManualGroups) || ~all(isfield(r.ManualGroups,{'ParentRow','PixelIdx','ChildIDs'}))
        error('CFU:InvalidSession','Invalid saved manual marks.');
    end
    for k=1:numel(r.ManualGroups)
        group=r.ManualGroups(k);
        if ~istable(group.ParentRow) || height(group.ParentRow)~=1 || ...
                any(~ismember(group.ChildIDs,r.Colonies.ID)) || ...
                any(group.PixelIdx<1 | group.PixelIdx>numel(r.Labels) | group.PixelIdx~=floor(group.PixelIdx))
            error('CFU:InvalidSession','Invalid saved merge history.');
        end
    end
end
ids=r.Colonies.ID;
if any(~isfinite(ids) | ids<1 | ids~=floor(ids)) || numel(unique(ids))~=numel(ids) || ...
        any(~ismember(unique(r.Labels(:)),[0;ids]))
    error('CFU:InvalidSession','Saved colony IDs and regions are inconsistent.');
end
end

function value=colony_session_data(action,folder,value)
%COLONY_SESSION_DATA Plain-data session codec; never loads MATLAB objects/code.
% JSON describes tables/structures; little-endian binary arrays preserve types,
% dimensions and NaNs exactly. Only the explicitly listed data types are read.
if strcmp(action,'write')
    counter=0;
    manifest=struct('Format','CFU-Counter session','Version',1,'Data',encode(value));
    file=fullfile(folder,'manifest.json');
    fid=fopen(file,'w','n','UTF-8');
    if fid<0, error('CFU:SessionWrite','Cannot write session metadata.'); end
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(manifest));
elseif strcmp(action,'read')
    manifest=jsondecode(fileread(fullfile(folder,'manifest.json')));
    if ~isstruct(manifest) || ~isfield(manifest,'Format') || ...
            ~strcmp(manifest.Format,'CFU-Counter session') || ...
            ~isfield(manifest,'Version') || ~isequal(manifest.Version,1)
        error('CFU:SessionVersion','This workbook uses an unsupported session format.');
    end
    value=decode(manifest.Data,0);
else
    error('CFU:SessionAction','Unknown session codec action.');
end

    function node=encode(v)
        node=struct('Type',class(v),'Size',size(v));
        if (isnumeric(v) || islogical(v) || ischar(v)) && isreal(v) && ~issparse(v)
            counter=counter+1; node.File=sprintf('data_%06d.bin',counter);
            precision=class(v);
            if islogical(v), precision='uint8'; elseif ischar(v), precision='uint16'; end
            fid=fopen(fullfile(folder,node.File),'w','ieee-le');
            if fid<0, error('CFU:SessionWrite','Cannot write session array.'); end
            guard=onCleanup(@()fclose(fid));
            count=fwrite(fid,v,precision);
            if count~=numel(v), error('CFU:SessionWrite','Incomplete session array.'); end
            clear guard
        elseif isstring(v)
            text=v; text(ismissing(v))="";
            node.Values=cellstr(text(:)); node.Missing=find(ismissing(v));
        elseif istable(v)
            node.Names=v.Properties.VariableNames;
            node.Rows=v.Properties.RowNames;
            node.DimensionNames=v.Properties.DimensionNames;
            node.Units=v.Properties.VariableUnits;
            node.Descriptions=v.Properties.VariableDescriptions;
            node.Values=cell(1,width(v));
            for n=1:width(v), node.Values{n}=encode(v.(node.Names{n})); end
        elseif iscell(v)
            node.Values=cell(1,numel(v));
            for n=1:numel(v), node.Values{n}=encode(v{n}); end
        elseif isstruct(v)
            node.Names=fieldnames(v); node.Values=cell(numel(node.Names),numel(v));
            for n=1:numel(v)
                for f=1:numel(node.Names), node.Values{f,n}=encode(v(n).(node.Names{f})); end
            end
            node.Values=node.Values(:)';
        else
            error('CFU:SessionType','Unsupported session data type: %s.',class(v));
        end
    end

    function v=decode(node,depth)
        if depth>40 || ~isstruct(node) || ~isscalar(node) || ~all(isfield(node,{'Type','Size'}))
            error('CFU:InvalidSession','Invalid session structure.');
        end
        dims=double(node.Size(:)');
        if numel(dims)<2 || numel(dims)>8 || any(~isfinite(dims) | dims<0 | dims~=floor(dims)) || prod(dims)>1e8
            error('CFU:InvalidSession','Invalid session dimensions.');
        end
        numericTypes={'double','single','uint8','uint16','uint32','uint64','int8','int16','int32','int64','logical','char'};
        if ismember(node.Type,numericTypes)
            if isempty(regexp(node.File,'^data_[0-9]{6}\.bin$','once'))
                error('CFU:InvalidSession','Invalid session array path.');
            end
            precision=node.Type;
            if strcmp(precision,'logical'), precision='uint8'; elseif strcmp(precision,'char'), precision='uint16'; end
            fid=fopen(fullfile(folder,node.File),'r','ieee-le');
            if fid<0, error('CFU:InvalidSession','Missing session array.'); end
            guard=onCleanup(@()fclose(fid));
            [v,count]=fread(fid,prod(dims)+1,['*' precision]);
            if count~=prod(dims), error('CFU:InvalidSession','Incorrect session array length.'); end
            clear guard
            if strcmp(node.Type,'logical'), v=logical(v); elseif strcmp(node.Type,'char'), v=char(v); end
            v=reshape(v,dims);
        elseif strcmp(node.Type,'string')
            v=reshape(string(node.Values),dims);
            if any(node.Missing<1 | node.Missing>numel(v) | node.Missing~=floor(node.Missing))
                error('CFU:InvalidSession','Invalid missing-string index.');
            end
            v(node.Missing)=missing;
        elseif strcmp(node.Type,'table')
            names=cellstr(string(node.Names)); cols=cell(1,numel(names));
            for n=1:numel(names), cols{n}=decode(item(node.Values,n),depth+1); end
            v=table(cols{:},'VariableNames',names);
            if ~isequal(size(v),dims), error('CFU:InvalidSession','Invalid table dimensions.'); end
            v.Properties.RowNames=cellstr(string(node.Rows));
            v.Properties.DimensionNames=cellstr(string(node.DimensionNames));
            v.Properties.VariableUnits=cellstr(string(node.Units));
            v.Properties.VariableDescriptions=cellstr(string(node.Descriptions));
        elseif strcmp(node.Type,'cell')
            v=cell(dims);
            for n=1:numel(v), v{n}=decode(item(node.Values,n),depth+1); end
        elseif strcmp(node.Type,'struct')
            names=cellstr(string(node.Names));
            if any(~cellfun(@isvarname,names)) || numel(unique(names))~=numel(names)
                error('CFU:InvalidSession','Invalid structure fields.');
            end
            v=struct();
            for f=1:numel(names), v.(names{f})=[]; end
            v=repmat(v,dims);
            for n=1:numel(v)
                for f=1:numel(names)
                    v(n).(names{f})=decode(item(node.Values,(n-1)*numel(names)+f),depth+1);
                end
            end
        else
            error('CFU:InvalidSession','Unsupported session data type.');
        end
    end
end

function v=item(values,n)
% jsondecode uses structure arrays for homogeneous lists, cells otherwise.
if iscell(values), v=values{n}; else, v=values(n); end
end

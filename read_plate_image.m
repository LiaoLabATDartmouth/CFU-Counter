function [I,info]=read_plate_image(file)
%READ_PLATE_IMAGE Read an upright RGB photograph, including PNG and HEIC.
% HEIC/HEIF: use MATLAB R2025a+ with the HEIF/HEIC support package, or the
% built-in macOS image converter. No source file is modified.
file=char(file);
if ~isfile(file), error('CFU:MissingImage','Image does not exist: %s',file); end
[~,~,ext]=fileparts(file); ext=lower(string(ext));
info=struct('Format',ext,'Decoder',"MATLAB",'AutoOriented',false);
isHEIC=ismember(ext,[".heic",".heif"]);
map=[]; alpha=[];
try
    if ~verLessThan('matlab','24.2') && ismember(ext,[".jpg",".jpeg",".tif",".tiff",".heic",".heif"])
        I=imread(file,'AutoOrient',true); info.AutoOriented=true;
    else
        [I,map,alpha]=imread(file);
    end
catch err
    if ~isHEIC, rethrow(err); end
    if ~ismac
        error('CFU:HEICSupport', ...
            ['Cannot decode this HEIC/HEIF image. In MATLAB R2025a or newer, install ' ...
            '"MATLAB Support for HEIF/HEIC Image Format" from Add-Ons, or export the photo as PNG/JPEG. ' ...
            'Decoder message: %s'],err.message);
    end
    % ProcessBuilder passes paths as arguments, never through a shell. Spaces,
    % quotes, parentheses and shell metacharacters in filenames remain literal.
    converted=[tempname '.png']; cleanup=onCleanup(@()deleteIfPresent(converted));
    args=java.util.ArrayList();
    for value={'/usr/bin/sips','-s','format','png',file,'--out',converted}
        args.add(java.lang.String(value{1}));
    end
    builder=java.lang.ProcessBuilder(args); builder.redirectErrorStream(true);
    process=builder.start(); stream=java.io.BufferedReader(java.io.InputStreamReader(process.getInputStream()));
    message=""; line=stream.readLine();
    while ~isempty(line)
        message=message+string(line)+newline; line=stream.readLine();
    end
    status=process.waitFor(); stream.close();
    if status~=0 || ~isfile(converted)
        error('CFU:HEICSupport','Could not decode HEIC/HEIF. Export as PNG/JPEG and reopen. %s',message);
    end
    I=imread(converted); info.Decoder="macOS"; info.AutoOriented=true;
    clear cleanup
end
if ~isempty(map), I=ind2rgb(I,map); end
if ndims(I)~=3 || size(I,3)~=3
    error('CFU:NotRGB','Choose a color photograph. Grayscale images lack the color features used for AD9/AD24.');
end
if ~isempty(alpha)
    % Composite transparent PNG pixels on white, so hidden RGB data cannot
    % create spurious colonies. Preserve color channels in their native range.
    a=im2single(alpha); I=im2single(I).*a+(1-a);
end
if ~info.AutoOriented && ismember(ext,[".jpg",".jpeg",".tif",".tiff"])
    metadata=imfinfo(file);
    if isfield(metadata,'Orientation') && isnumeric(metadata(1).Orientation)
        switch metadata(1).Orientation
            case 2, I=fliplr(I);
            case 3, I=rot90(I,2);
            case 4, I=flipud(I);
            case 5, I=permute(I,[2 1 3]);
            case 6, I=rot90(I,-1);
            case 7, I=rot90(permute(I,[2 1 3]),2);
            case 8, I=rot90(I);
        end
        info.AutoOriented=true;
    end
end
end

function deleteIfPresent(file)
if isfile(file), delete(file); end
end

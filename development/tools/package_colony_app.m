function archive=package_colony_app(archive)
%PACKAGE_COLONY_APP Build the runnable source app, without development/history.
% Run with development/tools on the MATLAB path. No Compiler is needed.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, archive=fullfile(root,'ColonyCounterApp.zip'); end
stage=tempname; mkdir(stage); cleanup=onCleanup(@()rmdir(stage,'s')); %#ok<NASGU>
destination=fullfile(stage,'ColonyCounterApp'); mkdir(destination);
files=dir(fullfile(root,'*.m'));
for k=1:numel(files), copyfile(fullfile(root,files(k).name),destination); end
for name={'README_APP.md','README.md'}
    copyfile(fullfile(root,name{1}),destination);
end
mkdir(fullfile(destination,'Examples'));
copyfile(fullfile(root,'Examples','IMG_7489.jpeg'),fullfile(destination,'Examples'));
% zip updates an existing archive on some MATLAB releases. Build a fresh one
% so obsolete tests, reports, paths and old helpers cannot survive a rebuild.
fresh=fullfile(stage,'ColonyCounterApp.zip');
zip(fresh,{'ColonyCounterApp'},stage);
[ok,message]=movefile(fresh,archive,'f');
if ~ok, error('CFU:PackageFailed','Could not publish the app ZIP: %s',message); end
fprintf('Portable MATLAB app saved to %s\n',archive);
end

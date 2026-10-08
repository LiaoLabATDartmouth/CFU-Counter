function smoke_portable_install(archive,outputFolder)
%SMOKE_PORTABLE_INSTALL Run in a fresh MATLAB process, using the ZIP alone.
% This must not reuse an already loaded ColonyCounterApp class.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, archive=fullfile(root,'ColonyCounterApp.zip'); end
if nargin<2, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
stage=tempname; mkdir(stage);
oldFolder=pwd; oldPath=path;
cleanup=onCleanup(@()restoreEnvironment(oldFolder,oldPath,stage)); %#ok<NASGU>
unzip(archive,stage); release=fullfile(stage,'ColonyCounterApp');
cd(release); addpath(release,'-begin');
assert(startsWith(which('ColonyCounterApp'),[release filesep]));
assert(~isfolder('development') && ~isfolder('tests') && ~isfolder('app_preview'));
assert(~isfolder('archive') && ~isfolder('results') && ~isfolder('Example'));
assert(isfile(fullfile('Examples','IMG_7489.jpeg')));
originals=dir('Examples'); originals=originals(~ismember({originals.name},{'.','..'}));
assert(numel(originals)==1 && ~originals.isdir);
[dependencies,products]=matlab.codetools.requiredFilesAndProducts( ...
    {'launch_colony_app.m','run_example.m','count_folder.m'});
assert(all(startsWith(string(dependencies),string(release)+filesep)));
assert(all(ismember(string({products.Name}),["MATLAB","Image Processing Toolbox"])));
app=ColonyCounterApp;
closeApp=onCleanup(@()delete(app));
tc=matlab.uitest.TestCase.forInteractiveUse;
ring=findobj(app.ImageAxes,'Tag','PlateBoundary');
assert(isscalar(ring) && strcmp(ring.HitTest,'off'));
assert(isempty(findobj(app.ImageAxes,'Type','images.roi.Ellipse')));
tc.press(app.Buttons.View);
assert(isempty(app.LastError) && contains(app.StatusLabel.Text,'Boundary fitted'));
tc.press(app.Buttons.Boundary);
tc.press(app.Buttons.Apply);
assert(isempty(app.LastError) && ~app.Dirty);
assert(app.Result.Summary.Total>250 && app.Result.Summary.Total<400);
id=app.ColonyTable.Data{1,1}; app.setColonyLabel(id,'AD24');
tc.press(app.ShowIDs); app.selectColony(id); tc.press(app.Buttons.WholePlate);
exportFolder=fullfile(outputFolder,'exports'); mkdir(exportFolder);
files=app.saveResults(exportFolder);
entries=dir(exportFolder); entries=entries(~ismember({entries.name},{'.','..'}));
assert(numel(entries)==2 && ~any([entries.isdir]));
assert(isequal(string(sheetnames(files.Workbook)),["Colonies";"Summary"]));
T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
assert(T.Label(T.ID==id)=="AD24");
assert(isfile(files.Annotated));
app.UIFigure.WindowState='normal'; app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'portable_app.png'));
fprintf('PORTABLE_INSTALL: source from ZIP, initial outline, first fit, Apply, review edit, whole plate and two-file save passed.\n');
clear closeApp
end

function restoreEnvironment(folder,oldPath,stage)
cd(folder); path(oldPath);
if isfolder(stage), rmdir(stage,'s'); end
end

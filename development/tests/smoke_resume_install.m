function smoke_resume_install(archive,outputFolder)
%SMOKE_RESUME_INSTALL Fresh MATLAB process; use only code from the app ZIP.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1, archive=fullfile(root,'ColonyCounterApp.zip'); end
if nargin<2, outputFolder=tempname; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
stage=tempname; mkdir(stage); oldFolder=pwd; oldPath=path;
cleanup=onCleanup(@()restoreEnvironment(oldFolder,oldPath,stage)); %#ok<NASGU>
unzip(archive,stage); release=fullfile(stage,'ColonyCounterApp'); cd(release); addpath(release,'-begin');
for name={'ColonyCounterApp','load_colony_app_results','colony_session_data','write_colony_session','import_colony_workbook'}
    assert(startsWith(which(name{1}),[release filesep]));
end
app=ColonyCounterApp; closeApp=onCleanup(@()delete(app));
tc=matlab.uitest.TestCase.forInteractiveUse;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
id=app.ColonyTable.Data{1,1}; app.setColonyLabel(id,'AD24');
T=app.Result.Colonies; [~,k]=max(T.EnclosingRadiusPixels); parent=T.ID(k);
delta=max(2,T.EnclosingRadiusPixels(k)/4);
app.beginMarking(parent);
app.addMarkedCenter([T.X(k)-delta T.Y(k)],'AD9');
app.addMarkedCenter([T.X(k)+delta T.Y(k)],'AD24'); app.confirmMarking();
original=app.Result; files=app.saveResults(outputFolder);
clear closeApp
% The saved workbook alone must be enough on another computer.
movefile(original.ImageFile,char(original.ImageFile+".unavailable"));
app=ColonyCounterApp('','on'); closeApp=onCleanup(@()delete(app)); %#ok<NASGU>
app.loadResults(files.Workbook);
assert(isequaln(app.Result.Colonies,original.Colonies));
assert(isequaln(app.Result.Options,original.Options));
assert(isequaln(app.Result.Labels,original.Labels));
assert(isequaln(app.Result.Summary,original.Summary));
assert(isempty(app.LastError) && ~app.Dirty);
app.selectColony(app.Result.ManualGroups.ChildIDs(1));
tc.press(app.Buttons.WholePlate);
app.UIFigure.Position=[60 60 1320 880];
app.exportPreview(fullfile(outputFolder,'resumed_app.png'));
tc.press(app.Buttons.UndoMarks); assert(isempty(app.Result.ManualGroups));
app.setColonyLabel(parent,'AD9'); before=app.Result.Summary;
tc.press(app.Buttons.Apply); assert(isempty(app.LastError));
assert(isequaln(app.Result.Summary,before));
second=app.saveResults(outputFolder);
assert(~strcmp(files.Workbook,second.Workbook));
assert(isequal(string(sheetnames(second.Workbook)),["Colonies";"Summary"]));
clear closeApp
fprintf('RESUME_INSTALL: ZIP-only source; original photo absent; exact labels, settings, masks and counts; whole plate, Undo marks, edit, reclassify and resave passed.\n');
end
function restoreEnvironment(folder,oldPath,stage)
cd(folder); path(oldPath); if isfolder(stage), rmdir(stage,'s'); end
end

function tests=test_missed_colonies
tests=functiontests(localfunctions);
end
function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
o=colony_defaults(); o.PlateEllipse=[300 300 255 255 0];
full=prepare_colony_app_result(count_colonies(file,o));
[~,row]=min(full.Colonies.EnclosingRadiusPixels);
tc.TestData.Point=[full.Colonies.X(row) full.Colonies.Y(row)];
tc.TestData.Full=full;
tc.TestData.Result=edit_colony(full,'delete',full.Colonies.ID(row));
end

function testAddsLabelsWithoutReplacingExistingObjects(tc)
r=tc.TestData.Result; points=[tc.TestData.Point;205 205;255 255];
[s,ids]=add_missed_colonies(r,points,["AD9","AD24","Need review"],[4 6 5]);
verifyEqual(tc,s.Summary.Total,r.Summary.Total+3);
verifyEqual(tc,s.Summary.AD9,r.Summary.AD9+1); verifyEqual(tc,s.Summary.AD24,r.Summary.AD24+1);
verifyEqual(tc,s.Summary.FlaggedForReview,r.Summary.FlaggedForReview+1);
verifyEqual(tc,s.Labels,r.Labels);
verifyEqual(tc,s.Colonies(1:height(r.Colonies),r.Colonies.Properties.VariableNames),r.Colonies);
T=s.Colonies(ismember(s.Colonies.ID,ids),:);
verifyEqual(tc,[T.X T.Y],points); verifyEqual(tc,T.MarkerRadiusPixels,[4;6;5]);
verifyEqual(tc,T.Source,repmat("manual_add",3,1)); verifyTrue(tc,all(T.Reviewed));
verifyTrue(tc,all(isnan(T.DiameterPixels))); verifyTrue(tc,all(isnan(T.AreaPixels)));
verifyTrue(tc,all(isnan(T.EnclosingRadiusPixels)));
for k=1:3, verifyEqual(tc,colony_at_point(s,(points(k,:)-.5)*s.Scale+.5),ids(k)); end
s=edit_colony(s,'classify',ids(1),'Not a colony'); verifyEqual(tc,s.Summary.Total,r.Summary.Total+2);
s=edit_colony(s,'classify',ids(1),'AD24'); verifyEqual(tc,s.Summary.AD24,r.Summary.AD24+2);
end

function testRejectsDuplicatesAndInvalidCenters(tc)
r=tc.TestData.Result; p=tc.TestData.Point;
verifyError(tc,@()add_missed_colonies(r,zeros(0,2),strings(0,1),[]),'CFU:TooFewMarks');
verifyError(tc,@()add_missed_colonies(r,[p;p],["AD9","AD9"],[4 4]),'CFU:DuplicateCenter');
verifyError(tc,@()add_missed_colonies(r,[1 1],"AD9",4),'CFU:OutsideROI');
existing=[r.Colonies.X(1) r.Colonies.Y(1)];
verifyError(tc,@()add_missed_colonies(r,existing,"AD9",4),'CFU:AlreadyCounted');
verifyError(tc,@()add_missed_colonies(r,p,"unknown",4),'CFU:InvalidClass');
verifyError(tc,@()add_missed_colonies(r,p,"AD9",1e6),'CFU:InvalidRadius');
s=add_missed_colonies(r,p,"AD9",4);
verifyError(tc,@()add_missed_colonies(s,p,"AD24",4),'CFU:AlreadyCounted');
% The enlarged circle of an adjacent object does not exclude a missed center.
r.Colonies.EnclosingRadiusPixels(:)=100;
s=add_missed_colonies(r,p,"AD9",4); verifyEqual(tc,s.Summary.Total,r.Summary.Total+1);
end

function testScaledCoordinatesAndEmptyResult(tc)
r=tc.TestData.Result; r.Scale=.5;
r.Colonies.X=(r.Colonies.X-.5)/r.Scale+.5; r.Colonies.Y=(r.Colonies.Y-.5)/r.Scale+.5;
p=(tc.TestData.Point-.5)/r.Scale+.5;
[s,ids]=add_missed_colonies(r,p,"AD9",8);
verifyEqual(tc,colony_at_point(s,tc.TestData.Point),ids);
verifyEqual(tc,colony_circle_radii(s.Colonies(end,:),s.Scale),4);
r.Colonies=r.Colonies([],:); r.Labels(:)=0;
s=add_missed_colonies(r,[600 600],"Need review",8);
verifyEqual(tc,s.Summary.Total,1); verifyEqual(tc,s.Summary.FlaggedForReview,1);
end

function testRerunRetainsOrFlagsWithoutDoubleCounting(tc)
r=tc.TestData.Result; s=add_missed_colonies(r,tc.TestData.Point,"AD24",7);
[t,carried,lost]=prepare_colony_app_result(r,s);
verifyEqual(tc,[carried lost],[1 0]); verifyEqual(tc,t.Summary.AD24,s.Summary.AD24);
verifyEqual(tc,t.Colonies.MarkerRadiusPixels(end),7);
s=edit_colony(s,'classify',s.Colonies.ID(end),'Not a colony');
[t,carried,lost]=prepare_colony_app_result(r,s);
verifyEqual(tc,[carried lost],[1 0]); verifyEqual(tc,t.Summary.NotAColony,1);
% A changed analysis detects the previously missed object: do not add it twice.
[t,carried,lost]=prepare_colony_app_result(tc.TestData.Full,s);
verifyEqual(tc,[carried lost],[0 1]); verifyFalse(tc,any(t.Colonies.Source=="manual_add"));
verifyEqual(tc,t.Summary.Total,tc.TestData.Full.Summary.Total);
pixel=round((tc.TestData.Point-.5)*r.Scale+.5); r.ROI(pixel(2),pixel(1))=false;
[~,carried,lost]=prepare_colony_app_result(r,s); verifyEqual(tc,[carried lost],[0 1]);
end

function testAdditionsCoexistWithSplitsAndUndo(tc)
r=tc.TestData.Result; T=r.Colonies; [~,row]=max(T.EnclosingRadiusPixels); parent=T.ID(row);
points=[T.X(row)-4 T.Y(row);T.X(row)+4 T.Y(row)];
for addFirst=[true false]
    s=r;
    if addFirst, [s,id]=add_missed_colonies(s,tc.TestData.Point,"AD24",5); end
    [s,children]=mark_colony_group(s,'replace',parent,points,["AD9","AD9"]);
    if ~addFirst, [s,id]=add_missed_colonies(s,tc.TestData.Point,"AD24",5); end
    [t,carried,lost]=prepare_colony_app_result(r,s);
    verifyEqual(tc,[carried lost],[3 0]); verifyEqual(tc,t.Summary.Total,r.Summary.Total+2);
    s=mark_colony_group(s,'restore',children(1));
    verifyTrue(tc,any(s.Colonies.ID==id)); verifyTrue(tc,any(s.Colonies.ID==parent));
    verifyEqual(tc,s.Summary.Total,r.Summary.Total+1);
end
end

function testExportsMatchAddedLabelsAndRadii(tc)
fixture=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[r,ids]=add_missed_colonies(tc.TestData.Result,[tc.TestData.Point;205 205;255 255], ...
    ["AD9","AD24","Need review"],[4 6 5]);
files=save_colony_app_results(r,fixture.Folder);
T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
S=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
rows=ismember(T.ID,ids);
verifyEqual(tc,T.Label(rows),["AD9";"AD24";"Need review"]);
verifyEqual(tc,T.AnnotationColor(rows),["Cyan";"Orange";"White / black"]);
verifyEqual(tc,T.MarkerRadiusPixels(rows),[4;6;5]);
verifyEqual(tc,S.Count(S.Label=="Total included"),r.Summary.Total);
verifyEqual(tc,string(sheetnames(files.Workbook)),["Colonies";"Summary"]);
listing=dir(fixture.Folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(tc,numel(listing),2); verifyFalse(tc,any([listing.isdir]));
fig=plot_colonies(r,true,'off'); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
annotations=findobj(fig,'Tag','ColonyID'); data=[annotations.UserData];
verifyTrue(tc,all(ismember(ids,[data.ID])));
for k=1:numel(annotations)
    d=annotations(k).UserData; verifyEqual(tc,d.Label,T.Label(T.ID==d.ID));
end
end

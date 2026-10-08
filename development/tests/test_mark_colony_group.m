function tests=test_mark_colony_group
tests=functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
[file,cleanup]=marking_fixture(); %#ok<ASGLU>
options=colony_defaults(); options.PlateEllipse=[300 300 255 255 0];
r=prepare_colony_app_result(count_colonies(file,options));
[~,row]=max(r.Colonies.EnclosingRadiusPixels); id=r.Colonies.ID(row);
% Two arbitrary points inside a detected object test manual counting semantics.
centers=[r.Colonies.X(row)-4 r.Colonies.Y(row);r.Colonies.X(row)+4 r.Colonies.Y(row)];
validate_colony_centers(r,id,centers);
r=edit_colony(r,'classify',id,'Uncertain');
tc.TestData.Result=r; tc.TestData.ID=id; tc.TestData.Centers=centers;
end

function testTwoSameAndTwoDifferentLabels(tc)
r=tc.TestData.Result; id=tc.TestData.ID; points=tc.TestData.Centers;
for labels={["AD9";"AD9"],["AD9";"AD24"],["AD24";"Need review"]}
    [s,ids]=mark_colony_group(r,'replace',id,points,labels{1});
    verifyEqual(tc,s.Summary.Total,r.Summary.Total+1);
    verifyEqual(tc,s.Summary.AD9,r.Summary.AD9+sum(labels{1}=="AD9"));
    verifyEqual(tc,s.Summary.AD24,r.Summary.AD24+sum(labels{1}=="AD24"));
    verifyEqual(tc,s.Summary.FlaggedForReview,r.Summary.FlaggedForReview-1+sum(labels{1}=="Need review"));
    verifyFalse(tc,any(s.Colonies.ID==id)); verifyEqual(tc,numel(unique(ids)),2);
    verifyEqual(tc,s.Labels>0,r.Labels>0);
    verifyEqual(tc,s.Labels(r.Labels~=id),r.Labels(r.Labels~=id));
    children=s.Colonies(ismember(s.Colonies.ID,ids),:);
    verifyEqual(tc,[children.X children.Y],points); verifyEqual(tc,children.MarkedFromID,[id;id]);
    verifyTrue(tc,all(children.Reviewed)); verifyTrue(tc,all(isnan(children.DiameterPixels)));
    verifyTrue(tc,all(isnan(children.AreaPixels))); verifyTrue(tc,all(isnan(children.EnclosingRadiusPixels)));
    verifyTrue(tc,all(children.MarkerRadiusPixels>0));
    for k=1:2
        xy=(points(k,:)-0.5)*s.Scale+0.5;
        verifyEqual(tc,colony_at_point(s,xy),ids(k));
    end
end
end

function testUndoAndUniqueIDsAfterReplacement(tc)
r=tc.TestData.Result; id=tc.TestData.ID;
[s,ids]=mark_colony_group(r,'replace',id,tc.TestData.Centers,["AD9","AD24"]);
s=edit_colony(s,'classify',ids(1),'Not a colony');
verifyEqual(tc,s.Summary.Total,r.Summary.Total);
[s,parent]=mark_colony_group(s,'restore',ids(2));
verifyEqual(tc,parent,id); verifyEqual(tc,s.Labels,r.Labels); verifyEmpty(tc,s.ManualGroups);
verifyEqual(tc,s.Colonies(:,r.Colonies.Properties.VariableNames),sortrows(r.Colonies,'ID'));
verifyEqual(tc,s.Summary,r.Summary);
[s,newIDs]=mark_colony_group(s,'replace',id,tc.TestData.Centers,["AD9","AD9"]);
verifyTrue(tc,all(newIDs>max(ids)));
verifyError(tc,@()mark_colony_group(s,'replace',newIDs(1),tc.TestData.Centers,["AD9","AD9"]),'CFU:ManualGroup');
end

function testInvalidMarksAreRejectedBeforeCommit(tc)
r=tc.TestData.Result; id=tc.TestData.ID; points=tc.TestData.Centers;
verifyError(tc,@()mark_colony_group(r,'replace',id,points(1,:),"AD9"),'CFU:TooFewMarks');
verifyError(tc,@()mark_colony_group(r,'replace',id,points([1 1],:),["AD9","AD9"]),'CFU:DuplicateCenter');
verifyError(tc,@()mark_colony_group(r,'replace',id,[points(1,:);1 1],["AD9","AD9"]),'CFU:OutsideROI');
verifyError(tc,@()mark_colony_group(r,'replace',id,[points(1,:);300 300],["AD9","AD9"]),'CFU:OutsideObject');
verifyError(tc,@()mark_colony_group(r,'replace',id,points,["AD9","bad"]),'CFU:InvalidClass');
verifyError(tc,@()mark_colony_group(r,'restore',id),'CFU:NoManualGroup');
work=round((points(2,:)-0.5)*r.Scale+0.5); r.Labels(work(2),work(1))=999;
verifyError(tc,@()mark_colony_group(r,'replace',id,points,["AD9","AD9"]),'CFU:OtherColony');
end

function testCarryGroupAndEditedLabelsOnlyAcrossUnchangedMask(tc)
r=tc.TestData.Result; id=tc.TestData.ID;
[s,ids]=mark_colony_group(r,'replace',id,tc.TestData.Centers,["AD9","AD24"]);
s=edit_colony(s,'classify',ids(1),'Not a colony');
[t,carried,lost]=prepare_colony_app_result(r,s);
verifyEqual(tc,carried,2); verifyEqual(tc,lost,0);
verifyEqual(tc,t.Summary.AD24,s.Summary.AD24); verifyEqual(tc,t.Summary.NotAColony,s.Summary.NotAColony);
verifyEqual(tc,t.Colonies.Class(t.Colonies.Source=="manual_mark"),["Not a colony";"AD24"]);
verifyFalse(tc,any(t.Colonies.ID==id)); verifyEqual(tc,numel(t.ManualGroups),1);
restored=mark_colony_group(t,'restore',t.ManualGroups(1).ChildIDs(1));
verifyEqual(tc,restored.Colonies.Class(restored.Colonies.ID==id),r.Colonies.Class(r.Colonies.ID==id));
verifyTrue(tc,restored.Colonies.Reviewed(restored.Colonies.ID==id));
changed=r; pixel=find(r.Labels==id,1); changed.Labels(pixel)=0;
[t,carried,lost]=prepare_colony_app_result(changed,s);
verifyEqual(tc,carried,0); verifyEqual(tc,lost,2); verifyFalse(tc,any(t.Colonies.Source=="manual_mark"));
verifyTrue(tc,any(t.Colonies.ID==id));
changed=r; changed.Scale=r.Scale/2;
[~,carried,lost]=prepare_colony_app_result(changed,s);
verifyEqual(tc,[carried lost],[0 2]);
end

function testMultipleGroupsRestoreIndependently(tc)
r=tc.TestData.Result; id=tc.TestData.ID;
[s,ids]=mark_colony_group(r,'replace',id,tc.TestData.Centers,["AD9","AD24"]);
T=r.Colonies; row=find(T.ID~=id & T.EnclosingRadiusPixels>8,1); other=T.ID(row);
points=[T.X(row)-4 T.Y(row);T.X(row)+4 T.Y(row)];
[s,others]=mark_colony_group(s,'replace',other,points,["AD9","AD9"]);
verifyEqual(tc,numel(unique([ids;others])),4);
[t,carried,lost]=prepare_colony_app_result(r,s);
verifyEqual(tc,[carried lost],[4 0]); verifyEqual(tc,numel(t.ManualGroups),2);
verifyEqual(tc,t.Summary.AD9,s.Summary.AD9); verifyEqual(tc,t.Summary.AD24,s.Summary.AD24);
s=mark_colony_group(s,'restore',ids(1));
verifyTrue(tc,all(ismember(others,s.Colonies.ID))); verifyTrue(tc,any(s.Colonies.ID==id));
verifyEqual(tc,numel(s.ManualGroups),1);
end

function testWorkbookAndAnnotationUseIndividualMarks(tc)
fixture=tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[r,ids]=mark_colony_group(tc.TestData.Result,'replace',tc.TestData.ID,tc.TestData.Centers,["AD9","AD24"]);
files=save_colony_app_results(r,fixture.Folder);
T=readtable(files.Workbook,'Sheet','Colonies','TextType','string');
S=readtable(files.Workbook,'Sheet','Summary','Range','A1:C6','TextType','string');
verifyFalse(tc,any(T.ID==tc.TestData.ID));
verifyEqual(tc,T.Label(ismember(T.ID,ids)),["AD9";"AD24"]);
verifyEqual(tc,T.AnnotationColor(ismember(T.ID,ids)),["Cyan";"Orange"]);
verifyEqual(tc,T.MarkedFromID(ismember(T.ID,ids)),repmat(tc.TestData.ID,2,1));
verifyEqual(tc,S.Count(S.Label=="AD9"),r.Summary.AD9);
verifyEqual(tc,S.Count(S.Label=="AD24"),r.Summary.AD24);
listing=dir(fixture.Folder); listing=listing(~ismember({listing.name},{'.','..'}));
verifyEqual(tc,numel(listing),2); verifyFalse(tc,any([listing.isdir]));
fig=plot_colonies(r,true,'off'); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
marks=findobj(fig,'Tag','ColonyID'); data=[marks.UserData];
verifyTrue(tc,all(ismember(ids,[data.ID]))); verifyFalse(tc,any([data.ID]==tc.TestData.ID));
for k=1:numel(marks)
    d=marks(k).UserData; row=find(T.ID==d.ID);
    verifyEqual(tc,d.Label,T.Label(row));
end
end

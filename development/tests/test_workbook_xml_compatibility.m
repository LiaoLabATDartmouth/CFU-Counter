function tests=test_workbook_xml_compatibility
% Native DOM regression cases for compact and differently structured XLSX XML.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function testEmptyViewAndNoFollowingSibling(tc)
% Both former insertBefore reference arguments are empty in this fixture.
[book,T,S,cleanup]=fixture('empty',false); %#ok<ASGLU>
format_colony_workbook(book,T,S);
verifyWorkbook(tc,book,T,S);
end

function testMissingViewsAndExistingFollowingSibling(tc)
[book,T,S,cleanup]=fixture('missing',true); %#ok<ASGLU>
format_colony_workbook(book,T,S);
verifyWorkbook(tc,book,T,S);
end

function testExistingViewChildrenAndUnicodePath(tc)
[book,T,S,cleanup]=fixture('selection',true); %#ok<ASGLU>
renamed=fullfile(fileparts(book),'plate café α & sample.xlsx');
movefile(book,renamed); book=renamed;
format_colony_workbook(book,T,S);
verifyWorkbook(tc,book,T,S);
folder=tempname; unzip(book,folder); remove=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
parser=matlab.io.xml.dom.Parser();
for n=1:2
    doc=parser.parseFile(fullfile(folder,'xl','worksheets',sprintf('sheet%d.xml',n)));
    view=doc.getElementsByTagName('sheetView').item(0);
    verifyEqual(tc,string(view.getFirstChild().getNodeName()),"pane");
    verifyEqual(tc,view.getElementsByTagName('selection').getLength(),1);
end
end

function [book,T,S,cleanup]=fixture(viewMode,following)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
book=fullfile(folder,'colonies.xlsx');
labels=["Need review";"AD9";"AD24";"Not a colony"];
T=table((1:4)',labels,["White / black";"Cyan";"Orange";"None"], ...
    repmat("A&B <control> ""mixed"" μ",4,1), ...
    'VariableNames',{'ID','Label','AnnotationColor','Notes'});
S=table(labels,ones(4,1),T.AnnotationColor,'VariableNames',{'Label','Count','AnnotationColor'});
writetable(T,book,'Sheet','Colonies','UseExcel',false);
writetable(S,book,'Sheet','Summary','UseExcel',false);
stage=fullfile(folder,'xml'); unzip(book,stage);
parser=matlab.io.xml.dom.Parser(); writer=matlab.io.xml.dom.DOMWriter();
ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
for n=1:2
    file=fullfile(stage,'xl','worksheets',sprintf('sheet%d.xml',n));
    doc=parser.parseFile(file); root=doc.getDocumentElement();
    oldData=doc.getElementsByTagName('sheetData').item(0);
    data=oldData.cloneNode(true);
    while root.hasChildNodes(), root.removeChild(root.getFirstChild()); end
    if ~strcmp(viewMode,'missing')
        views=doc.createElementNS(ns,'sheetViews'); view=doc.createElementNS(ns,'sheetView');
        view.setAttribute('workbookViewId','0');
        if strcmp(viewMode,'selection')
            selection=doc.createElementNS(ns,'selection');
            selection.setAttribute('activeCell','A1'); selection.setAttribute('sqref','A1');
            view.appendChild(selection);
        end
        views.appendChild(view); root.appendChild(views);
    end
    root.appendChild(data);
    if following
        margins=doc.createElementNS(ns,'pageMargins');
        for name={'left','right','top','bottom','header','footer'}
            margins.setAttribute(name{1},'0.5');
        end
        root.appendChild(margins);
    end
    writer.writeToFile(doc,file);
end
archive=fullfile(folder,'rewritten.zip');
contents=dir(stage); contents=contents(~ismember({contents.name},{'.','..'}));
zip(archive,{contents.name},stage); copyfile(archive,book,'f');
end

function verifyWorkbook(tc,book,T,S)
verifyEqual(tc,string(sheetnames(book)),["Colonies";"Summary"]);
verifyEqual(tc,readtable(book,'Sheet','Colonies','TextType','string'),T);
actual=readtable(book,'Sheet','Summary','TextType','string');
verifyEqual(tc,actual,S);
folder=tempname; unzip(book,folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
parser=matlab.io.xml.dom.Parser();
ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main";
for file=["xl/styles.xml","xl/worksheets/sheet1.xml","xl/worksheets/sheet2.xml"]
    doc=parser.parseFile(fullfile(folder,file));
    all=doc.getElementsByTagName('*');
    for k=0:all.getLength()-1
        verifyEqual(tc,string(all.item(k).getNamespaceURI()),ns);
    end
    if contains(file,'sheet')
        verifyEqual(tc,doc.getElementsByTagName('pane').getLength(),1);
        verifyEqual(tc,doc.getElementsByTagName('cols').getLength(),1);
        pane=doc.getElementsByTagName('pane').item(0);
        verifyEqual(tc,string(pane.getAttribute('state')),"frozen");
        nodes=doc.getDocumentElement().getChildNodes(); names=strings(0,1);
        for k=0:nodes.getLength()-1
            node=nodes.item(k);
            if isa(node,'matlab.io.xml.dom.Element'), names(end+1)=string(node.getNodeName()); end %#ok<AGROW>
        end
        verifyLessThan(tc,find(names=="sheetViews"),find(names=="cols"));
        verifyLessThan(tc,find(names=="cols"),find(names=="sheetData"));
        if endsWith(file,'sheet1.xml')
            verifyEqual(tc,doc.getElementsByTagName('autoFilter').getLength(),1);
            verifyEqual(tc,find(names=="autoFilter"),find(names=="sheetData")+1);
        end
    end
end
end

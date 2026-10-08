function write_colony_session(workbook,result,state)
%WRITE_COLONY_SESSION Embed resumable data inside the existing two-sheet XLSX.
% The source photo is copied byte-for-byte; review uses the saved work image.
if nargin<3, state=struct(); end
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
unzip(workbook,folder);
session=fullfile(folder,'cfuSession'); mkdir(session);
[~,name,ext]=fileparts(char(result.ImageFile));
sourceName=[name ext]; embedded=isfile(result.ImageFile);
if embedded, copyfile(result.ImageFile,fullfile(session,'source.bin')); end
payload=struct('Result',result,'State',state,'SourceName',sourceName,'EmbeddedSource',embedded);
colony_session_data('write',session,payload);
% Register the custom package part without adding a worksheet.
parser=matlab.io.xml.dom.Parser(); writer=matlab.io.xml.dom.DOMWriter();
file=fullfile(folder,'[Content_Types].xml'); doc=parser.parseFile(file); root=doc.getDocumentElement();
for pair={'json','application/json';'bin','application/octet-stream'}'
    node=doc.createElementNS(root.getNamespaceURI(),'Default');
    node.setAttribute('Extension',pair{1}); node.setAttribute('ContentType',pair{2}); root.appendChild(node);
end
writer.writeToFile(doc,file);
file=fullfile(folder,'_rels','.rels'); doc=parser.parseFile(file); root=doc.getDocumentElement();
node=doc.createElementNS(root.getNamespaceURI(),'Relationship');
node.setAttribute('Id','cfuSession');
node.setAttribute('Type','https://github.com/LiaoLabATDartmouth/CFU-Counter/session');
node.setAttribute('Target','cfuSession/manifest.json'); root.appendChild(node); writer.writeToFile(doc,file);
archive=fullfile(folder,'session-output.zip');
contents=dir(folder); contents=contents(~ismember({contents.name},{'.','..'}));
zip(archive,{contents.name},folder);
[ok,message]=copyfile(archive,workbook,'f');
if ~ok, error('CFU:SessionWrite','Cannot embed session: %s',message); end
end

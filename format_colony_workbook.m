function format_colony_workbook(workbook,colonies,summary)
%FORMAT_COLONY_WORKBOOK Format native MATLAB XLSX output without Excel/add-ons.
% Uses standard Open XML styles; labels share the figure's annotation palette.
% Use MATLAB's native XML API explicitly (R2021a+) so the DOM implementation
% does not depend on the release-specific xmlread/xmlwrite defaults.
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
unzip(workbook,folder);
parser=matlab.io.xml.dom.Parser(); writer=matlab.io.xml.dom.DOMWriter();
styleFile=fullfile(folder,'xl','styles.xml'); styles=parser.parseFile(styleFile);
palette=colony_annotation_styles();
header=addStyle(styles,[0.12 0.21 0.29],[1 1 1],true);
labelStyle=zeros(1,4);
for k=1:4
    fill=palette.Colors(k,:); textColor=[0 0 0];
    if k==3, fill=palette.ReviewOutlineColor; textColor=palette.Colors(k,:); end
    labelStyle(k)=addStyle(styles,fill,textColor,false);
end
for sheet=1:2
    file=fullfile(folder,'xl','worksheets',sprintf('sheet%d.xml',sheet));
    doc=parser.parseFile(file); root=doc.getDocumentElement();
    if sheet==1
        T=colonies; coloredColumns={'B','C'};
        widths=[8 19 22 13 13 20 25 17 13 20 24 18 18 22];
    else
        T=summary; coloredColumns={'A','C'};
        widths=[38 46 24];
    end
    cells=doc.getElementsByTagName('c');
    for n=0:cells.getLength()-1
        cellNode=cells.item(n); reference=char(cellNode.getAttribute('r'));
        row=str2double(regexp(reference,'[0-9]+','match','once'));
        column=regexp(reference,'[A-Z]+','match','once');
        if row==1
            cellNode.setAttribute('s',num2str(header));
        elseif row>=2 && row<=height(T)+1 && ismember(column,coloredColumns)
            [found,index]=ismember(T.Label(row-1),palette.Labels);
            if found, cellNode.setAttribute('s',num2str(labelStyle(index))); end
        end
    end
    rows=doc.getElementsByTagName('row');
    for n=0:rows.getLength()-1
        row=rows.item(n); number=str2double(char(row.getAttribute('r')));
        if number==1, heightValue='24'; else, heightValue='20'; end
        row.setAttribute('ht',heightValue); row.setAttribute('customHeight','1');
    end
    % Set widths in schema order before sheetData.
    old=doc.getElementsByTagName('cols');
    if old.getLength()>0, root.removeChild(old.item(0)); end
    cols=element(doc,'cols');
    for n=1:numel(widths)
        col=element(doc,'col',{'min',num2str(n);'max',num2str(n); ...
            'width',num2str(widths(n));'customWidth','1'});
        cols.appendChild(col);
    end
    data=doc.getElementsByTagName('sheetData').item(0); root.insertBefore(cols,data);
    % Freeze the column headings, and make the colony rows filterable.
    views=doc.getElementsByTagName('sheetViews');
    if views.getLength()==0
        viewsNode=element(doc,'sheetViews'); root.insertBefore(viewsNode,cols);
        view=element(doc,'sheetView',{'workbookViewId','0'}); viewsNode.appendChild(view);
    else
        view=views.item(0).getElementsByTagName('sheetView').item(0);
    end
    pane=element(doc,'pane',{'ySplit','1';'topLeftCell','A2';'activePane','bottomLeft';'state','frozen'});
    insertBeforeOrAppend(view,pane,view.getFirstChild());
    if sheet==1
        filter=element(doc,'autoFilter',{'ref',sprintf('A1:%s%d',char('A'+width(T)-1),height(T)+1)});
        insertBeforeOrAppend(root,filter,data.getNextSibling());
    else
        % Metadata is kept inside these two requested sheets, not extra files.
        wrap=addStyle(styles,[1 1 1],[0.22 0.25 0.28],false);
        xfs=styles.getElementsByTagName('cellXfs').item(0);
        xf=xfs.getElementsByTagName('xf').item(wrap);
        xf.appendChild(element(styles,'alignment',{'wrapText','1';'vertical','center'}));
        xf.setAttribute('applyAlignment','1');
        for n=0:cells.getLength()-1
            cellNode=cells.item(n); reference=char(cellNode.getAttribute('r'));
            rowNumber=str2double(regexp(reference,'[0-9]+','match','once'));
            if rowNumber>=9 && (startsWith(reference,'A') || startsWith(reference,'B'))
                cellNode.setAttribute('s',num2str(wrap));
            end
        end
        for n=0:rows.getLength()-1
            row=rows.item(n); number=str2double(char(row.getAttribute('r')));
            if number>=9, row.setAttribute('ht','36'); end
            if number>=13 && number<=14, row.setAttribute('ht','60'); end
            if number>=16, row.setAttribute('ht','30'); end
        end
    end
    writer.writeToFile(doc,file);
end
writer.writeToFile(styles,styleFile);
archive=[tempname '.zip']; zipCleanup=onCleanup(@()deleteIfPresent(archive)); %#ok<NASGU>
contents=dir(folder); contents=contents(~ismember({contents.name},{'.','..'}));
zip(archive,{contents.name},folder);
[ok,message]=copyfile(archive,workbook,'f');
if ~ok, error('CFU:WriteFailed','Could not format workbook: %s',message); end
end

function index=addStyle(doc,fillColor,fontColor,bold)
fonts=doc.getElementsByTagName('fonts').item(0);
fontId=fonts.getElementsByTagName('font').getLength();
font=element(doc,'font');
font.appendChild(element(doc,'sz',{'val','11'}));
font.appendChild(element(doc,'name',{'val','Calibri'}));
font.appendChild(element(doc,'color',{'rgb',rgbHex(fontColor)}));
if bold, font.appendChild(element(doc,'b')); end
fonts.appendChild(font); fonts.setAttribute('count',num2str(fontId+1));
fills=doc.getElementsByTagName('fills').item(0); fillId=fills.getElementsByTagName('fill').getLength();
fill=element(doc,'fill'); pattern=element(doc,'patternFill',{'patternType','solid'});
pattern.appendChild(element(doc,'fgColor',{'rgb',rgbHex(fillColor)}));
pattern.appendChild(element(doc,'bgColor',{'indexed','64'}));
fill.appendChild(pattern); fills.appendChild(fill); fills.setAttribute('count',num2str(fillId+1));
xfs=doc.getElementsByTagName('cellXfs').item(0); index=xfs.getElementsByTagName('xf').getLength();
xf=element(doc,'xf',{'numFmtId','0';'fontId',num2str(fontId);'fillId',num2str(fillId); ...
    'borderId','0';'xfId','0';'applyFont','1';'applyFill','1'});
xfs.appendChild(xf); xfs.setAttribute('count',num2str(index+1));
end

function node=element(doc,name,attributes)
if nargin<3, attributes=cell(0,2); end
% Keep new style/worksheet elements in the SpreadsheetML namespace.
root=doc.getDocumentElement();
node=doc.createElementNS(root.getNamespaceURI(),name);
for n=1:size(attributes,1), node.setAttribute(attributes{n,1},attributes{n,2}); end
end

function insertBeforeOrAppend(parent,node,reference)
% MAXP rejects an empty reference; Java's insertBefore used to append for it.
if isempty(reference)
    parent.appendChild(node);
else
    parent.insertBefore(node,reference);
end
end

function value=rgbHex(rgb)
value=['FF' sprintf('%02X',round(255*rgb))];
end

function deleteIfPresent(file)
if isfile(file), delete(file); end
end

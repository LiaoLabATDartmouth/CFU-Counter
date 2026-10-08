# XML export compatibility fix — 8 October 2026

The reported Save results error was reproduced exactly in MATLAB's native XML
engine:

```text
Error using matlab.io.xml.dom.Element/insertBefore
Invalid input for argument 3 (p1):
Value must be 'matlab.io.xml.dom.Node'.
```

The workbook formatter used `insertBefore` with `getFirstChild` or
`getNextSibling` as its reference. These can return empty when a sheet view has
no children or sheetData is the final worksheet child. Java DOM accepts an empty
reference as append; the native MATLAB DOM requires a Node. The prior R2025b
export tests used the default Java engine, so they did not catch this difference.

## Correction

- Use `matlab.io.xml.dom.Parser` and `DOMWriter` explicitly, avoiding changes to
  the default `xmlread`/`xmlwrite` engine between releases.
- Append when the insertion reference is empty; otherwise insert before it.
- Create new worksheet/style elements in the SpreadsheetML namespace so the
  native writer preserves valid workbook XML.

Only `format_colony_workbook.m` changes at runtime. Counts, classification,
review labels, color choices and the two-file export contract are unchanged.
No Excel installation or additional XML add-on is required.

## Verification

14 targeted checks passed in MATLAB R2025b on macOS: three new native DOM cases,
five workbook/PNG export cases, three existing audit cases and three batch cases.
The new cases exercise empty sheetView children, terminal sheetData, missing
sheetViews, existing children/siblings, Unicode paths, XML special characters,
namespace preservation, element order, and read-back of unchanged table values.
Existing tests verify all label colors, disjoint summaries, empty exports,
paired filename suffixes, rollback/preflight errors and exactly two output files.

An additional native app Save results smoke check passed, including complete
export while view filters were active and recovery from a missing-folder error.
The refreshed ZIP was checked byte-for-byte against the current source.

The native DOM failure is reproducible locally without installing a different
MATLAB release. Direct execution on Windows or R2026b is still unverified. The
full photo regression suite was not repeated because detection/classification
code did not change.

## Updating an open app without losing review edits

Replace `format_colony_workbook.m` in the folder containing the running app,
then enter `clear format_colony_workbook` in the MATLAB Command Window and retry
Save results. This clears only the helper, not the app object or review data.
The rebuilt `ColonyCounterApp.zip` also contains the fix.

## API references

[MathWorks xmlread documentation](https://www.mathworks.com/help/matlab/ref/xmlread.html)
describes the engine selection and default change.
[MathWorks native XML parser](https://www.mathworks.com/help/matlab/ref/matlab.io.xml.dom.parser-class.html)
and [writer](https://www.mathworks.com/help/matlab/ref/matlab.io.xml.dom.domwriter-class.html)
are available from R2021a.

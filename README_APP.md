# Colony Counter — user guide

## Open the app

Open **`launch_colony_app.m`** in MATLAB and click **Run**, or enter
`launch_colony_app` from this folder. If you received `ColonyCounterApp.zip`,
extract it first and keep its `.m` files together.

The app is a MATLAB programmatic app, written for R2021a or later and tested
in R2025b on macOS. Older MATLAB releases and other operating systems have not
received the same runtime audit. Install the required components below first.
After installation, App Designer, MATLAB Compiler, Python and internet access
are not required to run it.

## Requirements and first-time setup

Open **Home → Add-Ons** in MATLAB and search for these exact names:

| Component | Requirement |
|---|---|
| **[Image Processing Toolbox](https://www.mathworks.com/products/image-processing.html)** | Required for detecting/classifying colonies and finding/editing the plate boundary. It must be installed and available under your MATLAB license. |
| **[MATLAB Support for HEIF/HEIC Image Format](https://www.mathworks.com/matlabcentral/fileexchange/176918-matlab-support-for-heif-heic-image-format)** | Needed for MATLAB to decode HEIC/HEIF originals on Windows/Linux (R2025a or later). PNG/JPEG images do not need this add-on. On macOS, the app can also use the system converter. |
| **[MATLAB Support for OpenJDK](https://www.mathworks.com/matlabcentral/fileexchange/180823-matlab-support-for-openjdk)** | Needed if MATLAB has no working Java runtime. This app uses Java when opening saved workbooks and for its macOS HEIC conversion fallback. A compatible Java runtime that is already configured is sufficient. |

### Check Image Processing Toolbox

Run `ver('images')` in the Command Window. Image Processing Toolbox should be
listed. If it is missing, install it through Add-Ons or your MATLAB installer.
If your license does not include it, contact your institution's MATLAB license
administrator.

### Set up OpenJDK and fix the missing-Java error

The OpenJDK add-on is available for R2026a and later. After installing it, run:

```matlab
jenv("-clear")
```

**Restart MATLAB**, then check:

```matlab
usejava('jvm')  % Must return 1 for Open saved results
version -java  % Displays the active Java runtime
```

If Open saved results says it is attempting to execute Java code but no runtime
was found, install/configure this add-on and restart MATLAB before retrying.
The saved workbook itself does not need to be recreated for this error.

For earlier releases, use MATLAB's bundled Java (where provided) or configure a
supported OpenJDK version. R2026b and later Windows/Linux installations do not
bundle Java. See the [release compatibility table](https://www.mathworks.com/support/requirements/openjdk.html)
and [MathWorks setup instructions](https://www.mathworks.com/help/matlab/matlab_external/configure-your-system-to-use-java.html).
The `jenv("-clear")` option is available starting in R2026a; see
[`jenv` documentation](https://www.mathworks.com/help/matlab/ref/jenv.html) for older releases.

### HEIC alternatives

If your MATLAB release cannot use the HEIC add-on, export a copy of the photo
as PNG or JPEG before opening it. On macOS, the app's system-converter fallback
also works when Java is available. Reopening a new saved workbook for review
uses its embedded working image, so HEIC decoding is only needed when opening
or reclassifying the HEIC original.

## Images and the yellow boundary

**Open image** accepts JPEG, PNG, TIFF, BMP, HEIC and HEIF, including uppercase
extensions. Color is required. Indexed PNGs are converted to RGB, transparent
PNGs are composited on white, and the first image/page of a multi-image file is
used. Coordinates refer to the upright original-resolution photograph.

On macOS, HEIC uses MATLAB's decoder if available, otherwise the built-in macOS
converter; the temporary conversion is removed and the original is untouched.
On Windows/Linux, HEIC requires MATLAB R2025a or later and **MATLAB Support for
HEIF/HEIC Image Format**, as described above. If the decoder is unavailable,
convert a copy to PNG/JPEG first.

A yellow outline appears immediately after loading. It is locked until you use
one of the boundary controls:

- **Choose plate boundary** unlocks the existing outline. Move, resize or rotate
  it around the plate and counting area you want. This also selects which plate
  to count in a multi-plate photo.
- **Fit to rim** fits the current outline to visible rim evidence on the first
  click, then leaves it editable. Check it before accepting, especially when
  the image contains adjacent plates, reflections, or cropped rims. If there
  is insufficient evidence, it leaves the existing outline unchanged.
- **Done boundary** accepts the outline and locks it. Anything outside is
  excluded. The accepted region is not extrapolated to an entire plate.
- **Show whole plate** returns from a close-up to the current plate view. It
  changes only zoom, not the counting boundary or labels.
- The **split section control**, beside Show whole plate, has two equal halves:
  click the left half for the **previous section** and the right half for the
  **next section**. The labels stay **< Prev section** and **Next section >**;
  the current section number appears in the status line and tooltips. The nine views form a
  3-by-3 grid, numbered left to right across the top, middle and bottom rows.
  They cover the entire visible plate without gaps and overlap slightly so
  colonies at section edges remain easy to inspect. Navigation wraps between
  sections 1 and 9 in either direction.
  Click circles, edit labels, mark individual colonies, add missed colonies and
  save results as usual; counts and saved outputs still cover the whole plate.
  Show whole plate restarts the sequence: the right half opens section 1 and
  the left half opens section 9. Colony close-ups and manual pan/zoom keep your
  place, so either half continues from the last section. Loading a photo/workbook
  or reclassifying starts a fresh sequence.

If automatic plate detection fails, the app shows a centered initial ellipse
and says that no plate was found. Position it manually or use Fit to rim; the
fallback ellipse is not silently accepted as the counting area.

Save the current plate's results before opening another image or selecting a
different plate. Each save keeps a new pair of files rather than replacing an
existing pair.

## Settings and classification

Settings are estimated from image pixels on load, and after accepting a changed
plate boundary. The app uses the same rule for every image. It does not look up
filenames or use a table of memorized photo settings.

Local color ratios compensate for gradual illumination and channel gains.
Reliable colony sizes, background noise and spacing determine bounded initial
settings. Size-related values are fractions of plate diameter. Clipping,
strong glare, blur, and lost resolution cannot be recovered by normalization.

Change controls in **Detection**, **Classification**, or **Advanced**, then
click **Apply and classify**. This one button uses the displayed values to
rerun detection and classification. The counts are never silently updated from
partially changed settings. **Reset to defaults** restores the estimates for
this image/plate; it changes controls only, and still requires Apply and
classify. Manual edits persist while adjusting the same image's boundary.
Opening a new image resets edits and estimates fresh values.

| Control | Effect |
|---|---|
| Pink color / pale colony threshold | Lower values can retain fainter colonies, with more possible artifacts |
| Minimum / maximum diameter | Size range of retained objects, in percent of plate diameter |
| Separation peak | Lower values separate touching objects more readily |
| Separate attached colonies | Additional refinement of mixed or multi-lobed objects |
| AD9 / AD24 size reference | Shared initial size reference and fallback when clean references are limited |
| Review sensitivity | Higher values flag more borderline composite classifications |
| Size review margin | Higher values flag more objects near the size fallback's cutoff |
| Background scale | Spatial scale of local illumination normalization |
| Ink / reflection rejection | Higher values reject more weak artifacts; zero disables the extra filter |
| Shape limits | Control acceptance of irregular or elongated objects |
| Processing image size | Higher values retain detail but use more time and memory |
| Automatic plate inset | Used when there is no manually accepted boundary |

The composite classifier learns feature weights from clean size-seeded
references; it does not use a fixed 40/40/15/5 weighting. With too few reliable
examples of both groups, it uses the size reference and leaves ambiguous
objects for review. A single appearance population does not force an invented
second class.

## Review and corrections

The counters are disjoint: **Need review**, **AD9**, and **AD24**. Table rows
start with Need review, followed by AD9, AD24 and Not a colony; IDs remain stable
when sorting or editing. The Review panel is independent of settings tabs.
Drag the thin divider between Review and Counting settings to resize both.

Click an image circle to locate its table row. Click a row to zoom to that
colony. Use **Show whole plate** to return to the global view. Double-click a
label to assign:

| Label | Count and annotation |
|---|---|
| Need review | Review count; white dashed circle with a black outline |
| AD9 | AD9 count; cyan circle |
| AD24 | AD24 count; orange circle |
| Not a colony | Excluded from colony counts and circles; row retained for correction |

Edits update counts and circles immediately. **Review only**, **Show circles**,
and **Colony IDs** affect the on-screen view; exports always include every
included colony and its ID.

### An object contains several colonies

1. Select the merged object in the image or table.
2. Click **Mark individual colonies**.
3. Click each individual center and choose its label. Labels start as Need review
   unless you select another default for new marks.
4. Edit/remove draft marks in the small editor if necessary.
5. Click **Confirm marks**. The merged object's contribution is replaced by the
   individual entries; it is not counted again.

Two AD9 marks add two AD9 counts. One AD9 plus one AD24 adds one to each count.
Select a resulting mark and use **Undo marks** to restore the original object.
Cancel leaves counts unchanged. A marked center is a manual annotation, not an
invented segmented colony shape; unavailable measurements stay blank.

### A colony was missed

Zoom to it, click **Add missed colony**, and click its center. Assign a label
and adjust its circle radius if needed, then **Confirm additions**. You may add
several centers together. The app rejects duplicates inside an existing detected
object; use Mark individual colonies when multiple colonies share that object.
Use Not a colony to exclude a mistaken addition later.

When Apply and classify reruns detection, manual corrections are retained only
when the corresponding segmented objects are unchanged. Missed-center additions
are carried only when still inside the plate and still undetected. The status
reports corrections that could not be retained; review the new detections.

## Save results

**Save results** writes exactly two files directly into an existing folder:

- `<image>_colonies.xlsx`: **Colonies** holds IDs, current labels, annotation
  colors, original-pixel positions and available measurements; **Summary**
  holds counts and the settings/boundary used.
- `<image>_annotated.png`: all included circles and colony IDs, using the same
  current labels and colors as the workbook. Not a colony entries are not drawn.

These files do not depend on the current zoom or Review only filter. Existing
files are never overwritten: both names receive the same `_2`, `_3`, etc.
suffix when needed. No separate ZIP, CSV, mask, MAT or diagnostic files are created by saving results.
Resume data and a copy of the source photo are stored inside the workbook, which
still has only the Colonies and Summary tabs. This makes the workbook larger.

The workbook's OriginalSuggestion column records the original classifier
suggestion, which can differ from the current Label. **Label** controls the
summary and annotated image. Manual marks record their source and parent ID.

### Continue working on saved results

Click **Open saved results** at the top right and select `<image>_colonies.xlsx`.
Workbooks saved with this version reopen the saved image, boundary, settings,
labels, excluded objects, added colonies and individually marked groups. Counts
and circles appear immediately; detection is not rerun. The annotated PNG is
not needed for reopening.

Continue editing labels, add missed colonies, or undo previous individual marks.
To tune the analysis, adjust settings and click **Apply and classify**. The
existing rule for retaining corrections still applies: corrections are retained
only when the relevant detected regions remain unchanged. Save again to create
a new pair of files; the earlier pair is retained.

The workbook includes the source photo, so new saves can move between computers
without separately copying it. Reclassification of HEIC originals still requires
the HEIC support described above. The embedded working image can be reviewed
without decoding HEIC again. If the source photo was already unavailable when a
workbook was saved, the app asks you to locate it.

**Older workbooks:** the app asks for the original photo if it cannot find it
beside the workbook or in Examples. It restores saved IDs, labels, circles and
available settings, using the existing detector to recover matching regions.
Unmatched saved circles become manual annotations. Older exports do not contain
the full original segmentation, merge undo history or every setting, so those
cannot be recovered exactly. The app reports this limitation after import.

Keep the original app-generated workbook for resuming. Editing labels in its
Colonies sheet is supported while the embedded session remains intact; changing
IDs, positions or row counts is rejected. Other spreadsheet programs may remove
embedded session data when they rewrite the file, making it an older-style import.

### Updating an older copy with the XML save error

If Save results reports `Invalid input for argument 3 (p1)` and mentions
`matlab.io.xml.dom.Node`, update to the current app. The Excel formatter now
uses a consistent native XML reader/writer and handles empty insertion points.

To keep unsaved review edits in an app that is already open, replace only
`format_colony_workbook.m` in the app folder you are using with the current
GitHub version. Then run this in the MATLAB Command Window and retry Save results:

```matlab
clear format_colony_workbook
```

This clears the helper function from memory, not your open app or its counts.
For a fresh installation, download and extract the updated app ZIP as usual.

## Files and sharing

All root `.m` files belong to the runnable source package; keep them together.
`Examples` contains original photographs. The local `development` folder holds
tests, reports and optional tools; `archive` holds recoverable older material.
Neither is needed to run the app.

`ColonyCounterApp.zip` is a clean shareable copy containing the source, these
instructions and one original JPEG example. It is optional for local use. The
19 additional HEIC originals, development files, history archive, and unrelated
Word document are not bundled.

## Limits of the audit

Tests cover all 20 supplied originals, blank/sparse/dense plates, image
normalization, plate selection, manual edits and export consistency. Those
photos informed development and are not independent validation. There is no
complete manual ground-truth count or label set.

AD9/AD24 are appearance labels here, not an independent strain identification.
For example, the photo named `AD24 0.125% 10(-6).HEIC` contains mostly small,
pale objects that the current rule labels AD9. Verified controls are needed to
resolve that discrepancy. Dense overlaps, glare, printing and rim colonies can
still cause missed or merged objects, including errors without review flags.
Review frequency is not a measure of classification accuracy.

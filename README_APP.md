# Colony Counter — user guide

## Open the app

Open **`launch_colony_app.m`** in MATLAB and click **Run**, or enter
`launch_colony_app` from this folder. If you received `ColonyCounterApp.zip`,
extract it first and keep its `.m` files together.

The app is a MATLAB programmatic app. It requires Image Processing Toolbox,
was tested in R2025b on macOS, and is written for R2021a or later. Older MATLAB
releases and other operating systems have not received the same runtime audit.
App Designer, MATLAB Compiler, Python and internet access are not required.

## Images and the yellow boundary

**Open image** accepts JPEG, PNG, TIFF, BMP, HEIC and HEIF, including uppercase
extensions. Color is required. Indexed PNGs are converted to RGB, transparent
PNGs are composited on white, and the first image/page of a multi-image file is
used. Coordinates refer to the upright original-resolution photograph.

On macOS, HEIC uses MATLAB's decoder if available, otherwise the built-in macOS
converter; the temporary conversion is removed and the original is untouched.
On Windows/Linux, HEIC requires a MATLAB release with HEIC support and its image
format add-on. If the decoder is unavailable, convert a copy to PNG/JPEG first.

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
suffix when needed. The ZIP, CSV files, masks, MAT data and diagnostic images
are not created by saving results.

The workbook's OriginalSuggestion column records the original classifier
suggestion, which can differ from the current Label. **Label** controls the
summary and annotated image. Manual marks record their source and parent ID.

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

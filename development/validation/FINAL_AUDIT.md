# Final software and project audit — 8 October 2026

Subsequent compatibility correction: [XML_EXPORT_FIX.md](XML_EXPORT_FIX.md) documents the native XML save failure, its fix, and targeted verification. The earlier audit below tested the then-current MATLAB configuration.

**100 regression checks passed; 0 failed; 0 incomplete.** The suite included
all 20 original photographs. A separate native UI smoke check passed from a
freshly extracted portable ZIP. No remaining software failures were found in
these checks. This is not a claim of error-free biological classification.

## Changes made

1. Renamed `Example/` to `Examples/`, updated the app/demo/test paths, and removed
   generated results from that folder. All 20 original files match their
   pre-cleanup SHA-256 hashes.
2. Moved tests into `development/tests`, current audit material into
   `development/validation`, and optional diagnostics/package building into
   `development/tools`. The app has no runtime dependency on these folders.
3. Preserved older screenshots, diagnostic outputs, generated example exports,
   earlier source/docs/tests, and the unrelated fecal-metabolite Word document
   in `archive/2026-10-08-before-final-audit.zip`. Verified all 143 archived
   files against the embedded hash manifest before removing their old copies.
4. Replaced the older multi-file `save_colony_results` implementation with a
   compatibility wrapper for the same two-file exporter used by the app.
5. Updated `count_folder` to estimate settings afresh for each original, respect
   explicit overrides, return its summary in MATLAB, and save only a workbook
   and annotated PNG per image in an existing folder. It skips generated
   `*_annotated.png` files, including on subsequent runs in the same folder.
6. Changed packaging to build a fresh ZIP so obsolete files cannot remain from
   older packages. Verified its exact file list and byte equality to the active
   source. The clean package has 44 files and is approximately 2.08 MiB.
7. Replaced the long, partly historical user documentation with current startup,
   review, export and file-retention instructions.

The segmentation, feature estimation, classification and rim-fitting algorithms
were not changed by this audit. The two runtime app/demo path edits only locate
the renamed Examples folder. The numerical photo audit in VALIDATION.md remains
applicable.

## Validation performed on the final layout

Environment: MATLAB R2025b on macOS. Dependency analysis identified MATLAB and
Image Processing Toolbox only for the runnable app/demo/batch workflow.

- All 100 checks in `development/tests/test_*.m`: settings estimation and
  normalization; known synthetic counts; blank, sparse, dense and single-group
  cases; touching/merged colonies; manual edits, exclusions, missed additions,
  undo and correction retention; table ordering and circle selection; pending
  settings; plate selection and locked outlines; exports and error recovery.
- All 20 originals: image loading, fresh settings, visible locked boundary,
  first-click rim fit, selected-plate counting, count/ID/mask consistency and
  safe overlay rendering. Selected visually blank plates remain zero; the
  sparse three-colony plate remains three. These checks do not assert a complete
  ground-truth count for every photo.
- Rim tests: three initial placements, repeat fits, darkening, color/shading
  changes, nonlinear intensity, blur/noise, and false-rim rejection on tabletop
  patches. Fixtures are test geometry and are not production photo presets.
- New batch tests: fresh estimates, override precedence, two files per input,
  paired suffixes on rerun, exclusion of generated overlays, missing-folder
  rejection, and the compatibility save function.
- Fresh ZIP in a separate MATLAB process: resolved source and dependencies
  entirely from the extracted package; opened the original JPEG; verified locked
  outline, first-click Fit to rim, Done boundary, Apply, manual label edit,
  return to whole-plate view, and a two-sheet workbook plus one PNG. No tests,
  previews, archive or old results folder was present in the extracted package.
- Inspected the actual packaged-app screenshot and annotated PNG. Counts, edited
  label colors, all included IDs, and review markers agreed with the workbook.
- Verified the recovery archive, original-image hashes, active documentation
  links and exact release contents. Code Analyzer found only advisory style/
  allocation/version-compatibility notices, with no syntax errors.

The earlier 100 transformed-image classification checks are recorded in
VALIDATION.md. They were not repeated during this cleanup because no image
analysis algorithm changed. The full current photo/rim regression suite was
rerun as described above.

## File decisions

| Location | Retain for |
|---|---|
| Root `.m` files | Running the app and command-line entry points; keep together |
| `Examples/` | 20 unchanged original photos; no generated annotations/results |
| `development/` | Future maintenance, repeatable tests, algorithm notes and reports |
| `archive/` | Recovery of earlier outputs/source and the unrelated Word document |
| `ColonyCounterApp.zip` | Sharing or reinstalling; optional when running local source |

The shareable ZIP contains the 41 root MATLAB sources, two user guides, and one
original JPEG example. It does not include the additional 19 HEIC photos,
development material, old outputs, the history archive, or the Word document.

## Remaining limitations

A complete manual count/strain-label set is unavailable, and the example photos
were used during development. The audit does not establish strain identity or
universal camera robustness. The `AD24 0.125% 10(-6).HEIC` image has mostly small,
pale objects classified by appearance as AD9; verified controls are needed to
resolve that discrepancy. Low review frequency is not an accuracy measure.

Dense overlaps, resolution loss, glare, printing and rim objects can still
produce missed/merged detections; an error does not always have a review marker.
Dense exported ID labels can overlap and require zooming. Use the manual review,
individual-center and missed-colony tools as needed. Other MATLAB releases and
operating systems were not runtime-tested in this audit.

After the folder reorganization, close an already running app and relaunch
`launch_colony_app.m` so it loads the new Examples path.

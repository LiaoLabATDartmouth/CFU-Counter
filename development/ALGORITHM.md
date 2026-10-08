# Algorithm map

`ColonyCounterApp.m` handles the UI, accepted boundary, pending settings,
review table, manual marks and exports. `count_colonies.m` is the fixed-options
analysis function. Image-specific estimation is explicit in
`estimate_colony_settings.m` and `derive_colony_settings.m`.

## Image-derived settings

A fixed pilot runs on the image/selected plate with the additional artifact
filter, internal lobe refinement and classification resolver disabled. The
rule uses clean interior references: solidity at least 0.90, circularity at
least 0.75, at least 30 clean background pixels, core pink signal at least
max(0.12, three times annular noise), and core red signal above 0.03.

Robust signal and noise summaries set color thresholds and artifact rejection.
Plate-relative size quantiles set the accepted size range and background scale.
Nearest-neighbor spacing and occupied area inform separation. Sparse plates
keep bounded conservative values; no reference objects retain a six-pixel size
target within the allowed range. Full bounds are in `derive_colony_settings`.
No filename, hash, stored photo settings, or target review percentage is used.

## Detection and classification

`read_plate_image` reads upright RGB data without modifying originals.
Automatic plate detection proposes a pink region on the background; accepted
manual boundaries override it. `fit_plate_boundary` searches rim evidence near
the selected ellipse and refuses unreliable fits.

Local ratios in linear RGB compensate for gradual exposure/color gain changes.
Pink and pale foreground masks are filtered by plate-relative size and shape.
Distance-map watershed separates touching objects. Additional mixed-lobe
refinement, if enabled, partitions existing foreground rather than expanding it.

Features include normalized log size, local color contrasts, pixel color
differences, circularity, solidity, eccentricity, boundary gradients and
brightness texture. With sufficient clean small/large references,
`fit_colony_classifier` learns a regularized Fisher direction maximizing
between-group separation relative to within-group spread. Reference selection
starts from appearance/size and is not independent biological truth.

A common plate-relative size reference is used when two-group reference
learning is unreliable. Ambiguous size/composite calls and merged-looking
shapes retain review flags. The optional resolver uses clean core/background
color evidence to corroborate borderline classifications.

## Review, state and export

`prepare_colony_app_result` makes AD9, AD24 and Need review disjoint and carries
safe manual corrections only when object correspondence is retained.
`mark_colony_group` replaces a merged object with individual labeled centers;
`add_missed_colonies` adds validated missed centers. Both preserve audit fields
and do not invent segmented measurements for manual centers.

`colony_export_tables` builds one label snapshot for the workbook and figure.
`save_colony_app_results` stages the two files before publishing them, uses
paired suffixes for collisions and rolls back a partial failed save. The older
`save_colony_results` name forwards to this same export. `count_folder` estimates
each original independently, applies explicit overrides, skips generated
annotation PNGs, and saves only the same two files per input.

See `validation/VALIDATION.md` for measured stress results and remaining limits.
The 20 development photos are not held-out accuracy validation.

The XLSX formatter uses `matlab.io.xml.dom.Parser` and `DOMWriter` explicitly,
with SpreadsheetML namespaces on inserted elements. Empty insertion references
use `appendChild`, because native DOM `insertBefore` requires an actual node.
This avoids differences in the default `xmlread` engine across MATLAB releases.

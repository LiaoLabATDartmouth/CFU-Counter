# Adaptive settings validation — 8 October 2026

Subsequent compatibility correction: [XML_EXPORT_FIX.md](XML_EXPORT_FIX.md) documents the native XML save failure, its fix, and targeted verification. The earlier audit below tested the then-current MATLAB configuration.

Final cleanup and regression audit: **100 checks passed**, plus a clean-ZIP native UI check. See [FINAL_AUDIT.md](FINAL_AUDIT.md) for current file locations, export fixes, and validation scope. The image-analysis algorithms and photo results below were unchanged by that cleanup.

MATLAB R2025b on macOS, Image Processing Toolbox. This report supersedes the previous saved-photo-preset audit. No preset lookup remains in the app or counter. The same image-content rule was applied to all 20 originals (19 HEIC, one JPEG), selecting one main plate per image. The derived annotated PNG is excluded.

## Boundary display and first-click fitting

The app now displays the automatically proposed plate boundary on image load.
It is a yellow, non-interactive outline until Choose plate boundary or a
successful Fit to rim opens the editor. Both actions use that same starting
ellipse. Fit to rim performs the fit on the first click; Done boundary locks
it again. An image without a detected plate gets a clearly labeled initial
outline that can be positioned manually.

31 targeted app, estimator, and boundary-state checks passed. The strengthened
all-photo loading test also passed: every one of the 20 originals showed a
locked outline and fitted the intended main plate after a single Fit to rim
click, before classification. Native JPEG and cropped-HEIC button checks
verified initial rendering, the first fit, relocking, and Apply.

The detector/classifier and the numerical photo audit below are unchanged by
this display correction.

## Current before-review results

| Image | AD9 | AD24 | Need review | Total | Min diameter % | Separation % | Artifact strength |
|---|---:|---:|---:|---:|---:|---:|---:|
| AD24 0.125% 10(-4).HEIC | 17 | 97 | 28 | 142 | 0.743 | 0.07 | 1.05 |
| AD24 0.125% 10(-6).HEIC | 145 | 1 | 17 | 163 | 0.553 | 0.0691 | 1.28 |
| AD24 10% 10(-4).HEIC | 1 | 65 | 10 | 76 | 0.8 | 0.07 | 1.5 |
| AD24 10% 10(-6).HEIC | 0 | 15 | 2 | 17 | 0.8 | 0.07 | 1.5 |
| AD24 MM 10(-4).HEIC | 5 | 52 | 9 | 66 | 0.8 | 0.07 | 1.5 |
| AD24 MM 10(-6).HEIC | 0 | 0 | 0 | 0 | 0.526 | 0.07 | 2 |
| AD9 + AD24 0.125% 10(-4).HEIC | 875 | 47 | 122 | 1044 | 0.319 | 0.0358 | 0.943 |
| AD9 + AD24 0.125% 10(-6).HEIC | 0 | 3 | 0 | 3 | 0.8 | 0.07 | 1.5 |
| AD9 + AD24 10% 10(-4).HEIC | 892 | 51 | 103 | 1046 | 0.329 | 0.037 | 1.08 |
| AD9 + AD24 10% 10(-6).HEIC | 47 | 0 | 1 | 48 | 0.566 | 0.07 | 1.5 |
| AD9 + AD24 MM 10(-4).HEIC | 13 | 25 | 5 | 43 | 0.577 | 0.07 | 1.5 |
| AD9 + AD24 MM 10(-6).HEIC | 0 | 0 | 0 | 0 | 0.554 | 0.07 | 2 |
| AD9 0.125% 10(-4).HEIC | 818 | 1 | 190 | 1009 | 0.322 | 0.0363 | 1.06 |
| AD9 0.125% 10(-6).HEIC | 83 | 0 | 16 | 99 | 0.524 | 0.0656 | 1.46 |
| AD9 10% 10(-4).HEIC | 1448 | 2 | 355 | 1805 | 0.3 | 0.0296 | 0.969 |
| AD9 10% 10(-6).HEIC | 572 | 1 | 59 | 632 | 0.404 | 0.0455 | 1.23 |
| AD9 MM 10(-4).HEIC | 35 | 0 | 8 | 43 | 0.596 | 0.07 | 1.5 |
| AD9 MM 10(-6).HEIC | 14 | 0 | 2 | 16 | 0.524 | 0.0655 | 1.29 |
| No bacteria MM.HEIC | 0 | 0 | 0 | 0 | 0.538 | 0.07 | 2 |
| IMG_7489.jpeg | 248 | 46 | 19 | 313 | 0.478 | 0.0598 | 0.5 |

Median review fraction on populated plates: 11.8%; maximum 19.7%. These are workload measures, not accuracy. No review-rate target was used to choose parameters.

## Shared rule and app behavior

- Fixed pilot; robust local contrast/noise; reliable size quantiles and nearest-neighbor spacing. No photo names, hashes, lookup table, or per-image stored boundary.
- Color uses local linear-RGB ratios and sizes use fractions of plate diameter. Sparse unreliable references retain conservative bounds, including a six-pixel size target within the allowed range if no reliable colonies are available.
- Estimates load into editable controls. Accepting a changed plate boundary re-estimates unedited fields. Manual overrides persist within that image; a new image resets them. Apply uses displayed values. Reset restores current plate estimates without running classification.
- The common 1.8% class size reference is retained. Composite feature weights are learned from sufficient small/large references. One population does not force an invented second class.

## Checks

90 analysis/app/export regression checks passed on the final code, including all 20 selected original plates. An additional app-loading check passed on all 20 original files. Native Apply, reset, label editing, resize and HEIC boundary workflows passed. The original all-review case now displayed 35 AD9, 0 AD24 and 8 reviews; increasing its review margin changed warnings without changing detection. The default demonstration app showed 236 AD9, 47 AD24 and 18 reviews inside its automatic boundary (301 total); the larger selected audit boundary produces 313 total. The portable app still writes exactly one two-tab workbook and one annotated PNG per save.

100 transformed files were re-estimated from their pixels, rather than using original-image settings:

| Variant | Maximum relative total change (populated plates) | Maximum absolute total change | Maximum total on initially blank plates |
|---|---:|---:|---:|
| reencoded | 0.00% | 0 | 0 |
| dimmer | 0.00% | 0 | 0 |
| white_balance | 0.10% | 1 | 0 |
| smooth_shadow | 1.01% | 3 | 0 |
| rotated_resized | 14.58% | 176 | 0 |

Re-encoding, 45% linear exposure, unequal channel gains, a smooth illumination gradient, and 90-degree rotation with 20% downsampling were tested. Boundary coordinates transformed with each image. The unchanged/renamed and transformed images had fresh settings computed by the same estimator.

## Limits

Visual inspection covered every original overlay. There is no complete manual ground-truth count or class annotation. These photos informed algorithm development and are not held-out validation. Estimated settings are bounded statistical starting points, not a proven optimum.

Reduced resolution can lose small colonies and change separation in dense growth. Clipping, glare, cropped plates, ambiguous pigment, printing, and merged objects remain limitations. Some rim colonies can still be missed; not every error necessarily receives a review circle. The sparse large-colony image AD24 10% 10(-6) has a possible missed upper-rim object. Use manual additions/splits and verify counts before analysis.

The AD24-named 0.125% 10(-6) image has mostly small/pale appearance labels (AD9). Filename identity is not used as classifier truth. Verified controls and representative manual labels are needed to establish biological identity.

The offline HTML provides current overlays, raw previews, each estimated setting, and individual stress counts. Browser rendering was not verified in this environment; the HTML controls were checked with a static DOM harness. Report previews omit IDs for readability; exported PNGs retain all annotations and IDs.

# Development files

This folder is optional for running the app and is excluded from the shareable
ZIP. Keep it for maintenance and reproducibility.

- `tests/`: automated regression tests and native UI smoke checks.
- `validation/`: current photo audit, validation limits, original image hashes,
  and the final audit report. `PHOTO_AUDIT.html` is self-contained and can be
  opened offline in a browser.
- `tools/`: package builder, diagnostic plots, lighting check, and older optional
  figure-based reviewer. These are not called by the main app.
- `ALGORITHM.md`: short guide to the processing and estimation functions.

From the project root in MATLAB:

```matlab
addpath(fullfile(pwd,'development','tests'));
t = runtests(fullfile(pwd,'development','tests'));
assert(all([t.Passed]));
```

The full-photo checks need all 20 originals in `Examples/`. Synthetic tests use
and clean up temporary files. The regression suite does not write results into
Examples. Native UI checks are optional and can save screenshots in a temporary
folder supplied as an argument:

```matlab
smoke_initial_boundary_ui(tempname);
smoke_colony_app_ui(tempname);
smoke_marking_ui(tempname);
smoke_missed_colony_ui(tempname);
smoke_panel_resize_ui(tempname);
smoke_export_ui(tempname);
```

The larger image-variation audit can be repeated separately:

```matlab
report = check_adaptive_photo_variants();
```

It estimates fresh settings for every transformed image and returns a table;
it does not create permanent per-image files. The selected main-plate ellipses
in test fixtures are validation geometry, never production photo presets.

To rebuild the portable ZIP:

```matlab
addpath(fullfile(pwd,'development','tools'));
package_colony_app;
```

To verify an extracted release, run `smoke_portable_install` in a fresh MATLAB
session with the tests folder on the path. It checks that all runtime sources
resolve from the ZIP and exercises loading, fitting, review and export.

The builder stages a fresh archive to exclude obsolete files from earlier ZIPs.
The root source, user guides and one original JPEG example are included. Tests,
audit reports, diagnostic tools, old exports and unrelated documents are not.

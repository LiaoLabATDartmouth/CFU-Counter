# CFU Counter — AD9 / AD24

Open **`launch_colony_app.m`** in MATLAB and click **Run**. Keep the `.m` helper
files beside it. The app requires MATLAB and Image Processing Toolbox; it was
tested with MATLAB R2025b on macOS. No Python, Statistics Toolbox, App Designer,
MATLAB Compiler, or internet connection is needed to run it.

1. Open a color photograph. A locked yellow plate outline appears immediately.
2. Use **Choose plate boundary** to adjust it, or **Fit to rim** to fit it.
   Click **Done boundary** to lock it again.
3. Review the settings estimated from that image, then **Apply and classify**.
4. Correct labels in **Review colonies**. Use **Mark individual colonies** for
   a merged object and **Add missed colony** for an undetected colony.
5. **Save results** writes `<image>_colonies.xlsx` and `<image>_annotated.png`
   directly into the folder you choose. It creates no per-image folder.
6. To continue later, click **Open saved results** and select the saved `.xlsx`.
   New workbooks contain the photo and review state; older ones may ask for the original photo.

See [README_APP.md](README_APP.md) for the full guide.

## Download

For the lightweight runnable app, download [ColonyCounterApp.zip](ColonyCounterApp.zip)
and extract it. To obtain all original examples, tests and development reports,
clone this repository or use GitHub’s **Code → Download ZIP**.

## What to keep

| Item | Purpose | Needed to run? |
|---|---|---|
| `launch_colony_app.m`, `ColonyCounterApp.m`, other root `.m` files | App, processing functions, and command-line entry points | Keep these together |
| `Examples/` | Original, unannotated photographs; 20 in the development copy | Optional; includes the startup example |
| `README.md`, `README_APP.md` | Instructions | Recommended |
| `ColonyCounterApp.zip` | Shareable copy of the runnable app and one original JPEG example | No; use it to share or reinstall |
| `development/` | Tests, algorithm notes, audit reports, optional diagnostic tools | No; keep for maintenance |
| `archive/` (local only) | Recovery ZIP with old outputs/screenshots/source and an unrelated literature document | No; excluded from GitHub |

`development/` is included in the GitHub repository for maintenance. `archive/`
is local recovery material and is excluded from Git. Neither is included
in the shareable app ZIP. The ZIP contains only one original example
(`IMG_7489.jpeg`); the other 19 HEIC originals remain in the local `Examples/`
folder. The old `Example`, `app_preview`, `results`, and root `tests` folders
have been consolidated as described above.

The document `Fecal_tryptophan_metabolite_concentrations.docx` is unrelated to
the app. It is preserved unchanged in the local recovery ZIP under `archive/` and is not uploaded to GitHub.

## Command-line use

From this folder in MATLAB:

```matlab
run_example % Counts the original JPEG; saves the same two files here
```

To estimate settings for another image:

```matlab
[opts, info] = estimate_colony_settings('my_plate.png');
r = prepare_colony_app_result(count_colonies('my_plate.png', opts));
r.EstimationInfo = info;
files = save_colony_app_results(r, pwd);
```

To process a folder, using fresh pixel-derived settings for each image:

```matlab
summary = count_folder('my_images', struct(), 'existing_output_folder');
```

The batch function returns its summary in MATLAB and saves just the same two
files per image. It skips generated `*_annotated.png` images. Choose an existing
output folder; no output folder is created automatically. For photos with
multiple plates, use the app to select the intended plate. The lower-level
`count_colonies` function uses supplied options, or shared defaults when they
are omitted; call the estimator first when automatic adjustment is wanted.

## Interpretation

AD9 means the smaller/paler appearance group; AD24 means the larger/deeper-pink
group. The app uses local color normalization, size, shape, and boundary
features, with a size fallback when there are too few clean examples of both
groups. It does not identify strains independently. Check merged objects,
missed colonies, glare, and printing before using the counts. Counts refer only
to the selected area; they are not CFU/mL.

The development copy contains validation and limitations in
`development/validation/VALIDATION.md`, an offline photo audit in
`development/validation/PHOTO_AUDIT.html`, and maintenance instructions in
`development/README.md`. These optional files are not bundled in the runnable ZIP.

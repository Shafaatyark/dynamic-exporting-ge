# Public disclosure manifest

This manifest records the exact source material approved for migration from the private research repository. The source repository remains read-only and its Git history is not present here.

## Approved source-to-public mapping

| Source path | Public path | Public treatment |
|---|---|---|
| `OptTar_01_initialize_model.m` | `model/dege_01_initialize_model.m` | Renamed; public inputs retained |
| `OptTar_02_SymmetricSS.m` | `model/dege_02_symmetric_ss.m` | Renamed; obsolete commented guess removed |
| `OptTar_03_SolveSymmetricSS.m` | `model/dege_03_solve_symmetric_ss.m` | Renamed |
| `OptTar_04_AsymmetricSS.m` | `model/dege_04_asymmetric_ss.m` | Renamed; non-two-country empirical branch removed |
| `OptTar_05_SolveAsymmetricSS.m` | `model/dege_05_solve_asymmetric_ss.m` | Renamed |
| `OptTar_06_ExtractFromY.m` | `model/dege_06_extract_from_y.m` | Renamed |
| `OptTar_07_GetMacros.m` | `model/dege_07_write_dynare_macros.m` | Renamed; writes only to job scratch space |
| `api/matlab/dege_web_run_from_json.m` | `model/dege_run_from_json.m` | Refactored portable bridge; no source-tree generation |
| `DynareCodes/OptTarPathDynare.mod` | `model/dege_transition.mod` | Renamed; include names updated |
| `DynareCodes/dynareSetup.mod` | `model/dege_dynare_setup.mod` | Renamed; include names updated |
| `DynareCodes/Params.mod` | `model/dege_params.mod` | Renamed |
| `DynareCodes/Vars_Params.mod` | `model/dege_vars_params.mod` | Renamed |
| `DynareCodes/Locals.mod` | `model/dege_locals.mod` | Renamed |
| `DynareCodes/Locals2.mod` | `model/dege_locals_trade.mod` | Descriptive rename |
| `DynareCodes/Model.mod` | `model/dege_equations.mod` | Descriptive rename |
| `DynareCodes/InitVals.mod` | `model/dege_initial_values.mod` | Descriptive rename |
| `DynareCodes/EndVals.mod` | `model/dege_terminal_values.mod` | Descriptive rename |
| `api/__init__.py` | `api/__init__.py` | Documentation cleanup |
| `api/dege_api.py` | `api/app.py` | Rebuilt without mock endpoints; saved/live split and jobs added |
| `api/dege_runner.py` | `api/runner.py` | Rebuilt without synthetic model; Octave-first engine boundary |
| `api/requirements.txt` | `api/requirements.txt` | Bounded runtime dependencies |
| `scripts/generate_web_saved_results.py` | `scripts/generate_saved_examples.py` | Renamed; always invokes real solver |
| `tests/test_dege_runner.py` | `tests/test_runner.py` | Replaced with focused public-scope tests |
| `web/.nojekyll` | `web/.nojekyll` | Retained |
| `web/index.html` | `web/index.html` | Academic UI revised |
| `web/app.js` | `web/app.js` | Rebuilt; no custom fallback to unrelated saved data |
| `web/styles.css` | `web/styles.css` | Revised public interface styles |
| `web/data/sample_unilateral_10.json` | `web/data/saved_unilateral_10.json` | Approved example slot; stale sample replaced by a fresh public/source-equivalent solve |
| `web/data/sample_bilateral_10.json` | `web/data/saved_bilateral_10.json` | Approved example slot; replaced by a fresh successful public solve |
| `.github/workflows/pages.yml` | `.github/workflows/pages.yml` | Deploys only `web/` from `main` |

## Public-only files

These 17 files were authored for the new repository rather than copied from the source:

| Public path | Purpose |
|---|---|
| `.gitattributes` | Portable text line endings |
| `.gitignore` | Excludes local environments and MATLAB/Octave/Dynare output |
| `.github/workflows/tests.yml` | Public-scope validation CI |
| `LICENSE` | MIT license selected for the teaching repository |
| `README.md` | Scope, setup, validation, and deployment guide |
| `THIRD_PARTY_NOTICES.md` | External dependency licenses and attribution |
| `model/dege_configure_dynare.m` | Environment-variable-based Dynare discovery |
| `scripts/validate_saved_examples.py` | Saved-result completeness and tariff audit |
| `scripts/compare_reference_results.py` | All-series numerical comparison utility |
| `tests/test_api.py` | Saved/API and custom-path boundary tests |
| `tests/test_frontend_labels.js` | Complete economic-label and dropdown-label audit |
| `web/series-labels.js` | Human-readable economic names for every solver series |
| `docs/architecture.md` | Dependency graph and runtime boundary |
| `docs/backend-deployment.md` | Optional live-solver service deployment |
| `docs/disclosure-manifest.md` | This realized disclosure record |
| `docs/model-api.md` | Request, job, and result contract |
| `docs/validation.md` | Numerical and interface validation record |

Together with the 30 approved mappings above, the realized public tree contains 47 files. The two additional public-only files were added after initial publication for the approved economic-name and chart-tile interface revision.

## Intentionally disclosed model content

Publication of this manifest discloses the baseline calibration defaults, symmetric and asymmetric steady-state systems, Dynare variables/parameters/local definitions/equations/initial and terminal conditions, solver behavior, and the complete 132-series outputs for two benchmark transitions. These are substantive model details, not merely interface code.

The source Git log contains contributions under the identities `Shafaatyark`, `cmixer48`, and `jxmding`. Before public release, the repository owner should confirm that all relevant copyright holders authorize distribution of the copied model code under MIT and replace the collective copyright line with the agreed legal names if desired.

Formal project citation metadata is deferred until the accompanying paper details are available.

## Excluded material

The migration excludes:

- the source `.git` directory and all prior Git history;
- optimal-tariff, optimal-path, one-shot, and sequence-space routines;
- `fminunc`, parallel-pool, `parfor`, and optimization-only helpers;
- paper figures, tables, optimal-policy result directories, and unrelated model variants;
- empirical calibration inputs for country counts other than two;
- temporary `tWEB_*`, macro-expanded, logs, MAT files, and generated Dynare folders;
- machine-specific Dynare setup code and absolute paths;
- any source untracked results.

## Publication gate

This repository must not be committed, pushed, made public, or deployed until the owner reviews this realized manifest, confirms licensing authority and attribution names, and approves the final `git status` audit.

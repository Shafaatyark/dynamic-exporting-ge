# Architecture

The economics stay in the MATLAB/Octave and Dynare runtime. Saved results can be viewed on GitHub Pages; new simulations are preferably solved on the user's own computer.

```text
GitHub Pages frontend
  └─ loads saved_unilateral_10.json or saved_bilateral_10.json

Local browser at 127.0.0.1
  └─ submits a validated request to local FastAPI
       └─ api/runner.py creates an isolated temporary job
            └─ Octave or MATLAB calls model/dege_run_from_json.m
                 ├─ dege_01_initialize_model.m
                 ├─ dege_02_symmetric_ss.m
                 │    └─ dege_03_solve_symmetric_ss.m
                 │         └─ dege_06_extract_from_y.m
                 ├─ dege_04_asymmetric_ss.m
                 │    └─ dege_05_solve_asymmetric_ss.m
                 │         └─ dege_06_extract_from_y.m
                 ├─ dege_07_write_dynare_macros.m
                 └─ dege_transition.mod
                      └─ dege_dynare_setup.mod
                           ├─ generated dege_macros.txt
                           ├─ dege_params.mod
                           ├─ dege_vars_params.mod
                           ├─ dege_locals.mod
                           ├─ dege_locals_trade.mod
                           ├─ dege_equations.mod
                           ├─ dege_initial_values.mod
                           └─ dege_terminal_values.mod
```

`start_windows.ps1` and `start_mac_linux.sh` detect the local runtime, create an isolated Python environment when needed, and bind the combined frontend/API service only to `127.0.0.1`. The local workflow does not transmit model requests or results to GitHub Pages.

## Stability boundary

`api/runner.py` owns the public request schema. It accepts only the documented model parameters and categorical switches, constructs or validates positive gross tariff paths, and always asks the bridge for all variables unless a programmatic client explicitly requests a subset.

The Python code contains no economic equations. It writes a normalized JSON request, starts one model process, reads one JSON result, verifies dimensions and finite values, and caches only successful results under a hash of the request and public model files.

`model/dege_run_from_json.m` owns the runtime boundary. It creates a job-local Dynare directory, copies only the nine authored `.mod` inputs, generates job-local macros and a transition file, runs perfect foresight, and serializes Dynare's exogenous and endogenous catalogs. Generated Dynare files do not enter `model/` or version control.

## Result timing

A request with `T` transition periods returns `T + 2` series observations: initial steady state, `T` transition observations, and terminal steady state. `tariffPaths` records the initial gross tariff plus the `T` prescribed values; the `tau21` and `tau12` solver series additionally contain the terminal observation.

## Saved versus live state

Saved JSON is loaded directly by the frontend and is labeled `saved model result`. Live responses are labeled `live simulation` and include the selected runtime engine. The frontend does not transform a failed solve into a demonstration result.

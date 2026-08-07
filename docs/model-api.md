# Model-to-website API

## Request

`POST /api/jobs` validates and queues a live solve. The same object can be sent to the synchronous `POST /api/simulate` endpoint.

```json
{
  "scenario": {
    "preset": "unilateral_10",
    "horizon": 80,
    "initialTau21": 1.0,
    "initialTau12": 1.0,
    "targetRatePercent": 10.0,
    "pathProfile": "step",
    "rebateType": "lumpsum"
  },
  "parameters": {
    "gam": 4.0,
    "th": 6.0
  },
  "variables": ["*"]
}
```

Presets are `unilateral_10`, `bilateral_10`, and `custom_path`. There is intentionally no free-trade transition preset. The solution horizon is fixed at 80 transition periods. A custom request replaces the target/profile fields with `tau21Path` and `tau12Path`, each containing exactly 80 positive gross tariffs.

`rebateType` accepts `lumpsum`, `invsub`, `labtax`, or `captax`. Categorical model settings accept only values returned by `GET /api/metadata`.

## Asynchronous lifecycle

1. `POST /api/jobs` returns HTTP 202 with a public job ID.
2. Poll `GET /api/jobs/{id}`.
3. Status progresses through `queued`, `running`, then `complete` or `failed`.
4. A completed job contains `result`; a failed job contains a safe message and may include a diagnostic ID.

Progress phases distinguish validation, cache lookup, solver execution, serialization, and completion. Diagnostic artifacts stay under `DEGE_JOB_ROOT`; local filesystem paths are not returned in successful public results.

## Result

The result includes:

- `scenario`, full initialized `parameters`, and `periods`;
- `variables`, the complete Dynare catalog with labels, type, and default transform;
- `series`, keyed by exact Dynare names;
- `raw`, `level`, `log_change`, `percent_change`, and `rate_percent` arrays for each series;
- summary `metrics`, prescribed `tariffPaths`, and `missingVariables`;
- `mode`, runtime `engine`, model fingerprint, and cache status for live solves.

The runner rejects missing variables, mismatched dimensions, and non-finite values. Welfare-equivalent metrics are reported only for the preference specification for which the source formula is defined.

## Read-only endpoints

- `GET /api/health` — API and solver availability;
- `GET /api/metadata` — controls and complete saved variable catalog;
- `GET /api/saved/unilateral_10` and `/api/saved/bilateral_10` — genuine stored model results;
- `POST /api/validate` — normalized request without running the model.

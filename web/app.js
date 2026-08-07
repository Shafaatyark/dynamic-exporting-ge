"use strict";

const CORE_VARIABLES = ["tau21", "tau12", "c1", "l1", "y1", "im1", "ex12", "k1"];
const COLORS = ["#0b5d5e", "#9a4f1f", "#435b8c", "#7c3f72", "#557a38", "#a23b3b", "#3b7f91", "#76532f"];
const DASHES = ["solid", "dash", "dot", "dashdot", "longdash", "longdashdot"];
const MARKERS = ["circle", "square", "diamond", "cross", "triangle-up", "triangle-down", "x", "star"];

const PARAMETER_SPECS = [
  ["gam", "Source substitution elasticity (γ)", 4],
  ["th", "Within-source variety elasticity (θ)", 6],
  ["bet", "Discount factor (β)", 0.96],
  ["del", "Capital depreciation rate (δ)", 0.1],
  ["sig", "Risk aversion (σ)", 1.001],
  ["frisch", "Frisch labor-supply elasticity (φ)", 2],
  ["bk", "Boppart–Krusell parameter (κ)", 0.2],
  ["v", "Fixed-cost distribution shape (ν)", 0.6494047],
  ["ns", "Firm survival rate (nₛ)", 0.98],
  ["Nx", "Exporter participation target (Nₓ)", 0.2],
  ["churnx", "Exporter churn target (χₓ)", 0.05],
  ["churnn", "Potential-exporter churn target (χₙ)", 0.15],
  ["GOVA", "Gross output to value added (GO/VA)", 2],
  ["GOVAc", "Consumption gross output to value added (GOᶜ/VA)", 2],
  ["WLVA", "Labor share of value added (wL/VA)", 0.6],
  ["RKVA", "Capital share target (rK/VA)", 0.165],
  ["gdp", "Relative GDP target (Y)", 1],
  ["Lbar", "Time endowment (L̄)", 1],
  ["IMY", "Imports-to-GDP target (IM/Y)", 0.15],
  ["Xshare", "Investment-goods export share (Xᵢ/X)", 0.2],
  ["Mshare", "Materials export share (Xₘ/X)", 0.6],
  ["Cshare", "Consumption-goods export share (X꜀/X)", 0.2],
  ["ttL", "Labor income tax rate (τₗ)", 0.272],
  ["ttK", "Capital income tax rate (τₖ)", 0.147],
  ["sI", "Investment subsidy rate (sᵢ)", 0],
  ["psi_fric", "Investment adjustment cost (ψ)", 0.4],
];

const STRUCTURE_SPECS = [
  ["dynamic", "Firm dynamics", 1, [[1, "1 — Heterogeneous firms with exporter dynamics"], [0, "0 — Representative firm"]]],
  ["trade_bal", "Trade-balance regime", 0, [[0, "0 — Bonds with steady-state imbalances (benchmark)"], [1, "1 — Bonds with balanced steady state"], [2, "2 — Financial autarky with balanced trade"], [3, "3 — Financial autarky with steady-state imbalances"]]],
  ["free_entry", "Firm entry", 1, [[1, "1 — Free entry (benchmark)"], [0, "0 — Fixed entry"]]],
  ["trade_comp", "Trade composition", 1, [[1, "1 — Match trade composition targets"], [0, "0 — Equal trade intensity across goods"]]],
  ["elast_labor", "Labor supply", 1, [[1, "1 — Elastic labor supply (benchmark)"], [0, "0 — Nearly inelastic labor supply"]]],
  ["pref", "Household preferences", 0, [[0, "0 — Cobb–Douglas consumption and leisure (benchmark)"], [1, "1 — MaCurdy preferences"], [2, "2 — Boppart–Krusell preferences"]]],
  ["revsub", "Markup treatment", 0, [[0, "0 — Standard markups (benchmark)"], [1, "1 — Revenue subsidy offsets markups"]]],
];

const state = {
  result: null,
  catalog: [],
  selected: new Set(CORE_VARIABLES),
  axes: {},
  running: false,
};

const el = Object.fromEntries([
  "runStatus", "apiBase", "scenarioPreset", "horizon", "targetRate", "initialTau21",
  "initialTau12", "pathProfile", "rebateType", "customPathWrap", "customPath",
  "parameterGrid", "structureGrid", "resetParams", "transformMode", "plotPeriods",
  "customVariable", "addVariable", "loadSaved", "runButton", "downloadCsv",
  "downloadFigure", "errorBox", "metricWelfare", "metricSsUtil", "metricRevenue",
  "metricMode", "plot", "variableSearch", "selectCore", "clearSeries", "variableSelector",
].map((id) => [id, document.getElementById(id)]));

function renderControls() {
  el.parameterGrid.replaceChildren();
  PARAMETER_SPECS.forEach(([name, label, value]) => {
    const row = document.createElement("div");
    row.className = "parameter-row";
    const caption = document.createElement("label");
    caption.htmlFor = `param-${name}`;
    caption.textContent = label;
    const input = document.createElement("input");
    input.id = `param-${name}`;
    input.dataset.parameter = name;
    input.type = "number";
    input.step = "any";
    input.value = String(value);
    row.append(caption, input);
    el.parameterGrid.append(row);
  });

  el.structureGrid.replaceChildren();
  STRUCTURE_SPECS.forEach(([name, label, value, options]) => {
    const row = document.createElement("div");
    row.className = "parameter-row categorical";
    const caption = document.createElement("label");
    caption.htmlFor = `param-${name}`;
    caption.textContent = label;
    const select = document.createElement("select");
    select.id = `param-${name}`;
    select.dataset.parameter = name;
    options.forEach(([optionValue, optionLabel]) => {
      const option = document.createElement("option");
      option.value = String(optionValue);
      option.textContent = optionLabel;
      option.selected = optionValue === value;
      select.append(option);
    });
    row.append(caption, select);
    el.structureGrid.append(row);
  });
}

function resetParameters() {
  [...PARAMETER_SPECS, ...STRUCTURE_SPECS].forEach(([name, , value]) => {
    document.getElementById(`param-${name}`).value = String(value);
  });
  showStatus("Parameters reset; displayed data are unchanged", "notice");
}

function collectParameters() {
  const parameters = {};
  document.querySelectorAll("[data-parameter]").forEach((input) => {
    const value = Number(input.value);
    if (!Number.isFinite(value)) throw new Error(`${input.dataset.parameter} must be numeric.`);
    parameters[input.dataset.parameter] = value;
  });
  return parameters;
}

function parseCustomPaths(horizon) {
  const rows = el.customPath.value.split(/\r?\n/).map((row) => row.trim()).filter(Boolean);
  if (rows.length && /tau/i.test(rows[0])) rows.shift();
  const tau21Path = [];
  const tau12Path = [];
  rows.forEach((row, index) => {
    const values = row.split(/[;,\t]/).map((value) => Number(value.trim()));
    if (values.length !== 2 || !values.every((value) => Number.isFinite(value) && value > 0)) {
      throw new Error(`Custom-path row ${index + 1} must contain two positive gross tariffs.`);
    }
    tau21Path.push(values[0]);
    tau12Path.push(values[1]);
  });
  if (rows.length !== horizon) {
    throw new Error(`Custom paths require exactly ${horizon} data rows (one per transition period).`);
  }
  return { tau21Path, tau12Path };
}

function buildRequest() {
  const horizon = Number(el.horizon.value);
  if (!Number.isInteger(horizon) || horizon < 1 || horizon > 600) {
    throw new Error("Transition periods must be an integer from 1 to 600.");
  }
  const scenario = {
    preset: el.scenarioPreset.value,
    horizon,
    targetRatePercent: Number(el.targetRate.value),
    initialTau21: Number(el.initialTau21.value),
    initialTau12: Number(el.initialTau12.value),
    pathProfile: el.pathProfile.value,
    rebateType: el.rebateType.value,
  };
  if (scenario.preset === "custom_path") Object.assign(scenario, parseCustomPaths(horizon));
  return { scenario, parameters: collectParameters(), variables: ["*"] };
}

function updateScenarioControls() {
  const custom = el.scenarioPreset.value === "custom_path";
  el.customPathWrap.classList.toggle("hidden", !custom);
  el.targetRate.disabled = custom;
  el.pathProfile.disabled = custom;
  el.loadSaved.disabled = custom || state.running;
  if (custom) showStatus("Custom paths require a live solver", "notice");
}

function apiBase() {
  const configured = el.apiBase.value.trim().replace(/\/$/, "");
  if (configured) return configured;
  if (["localhost", "127.0.0.1", "::1"].includes(window.location.hostname)) return window.location.origin;
  throw new Error("Enter the live-solver API URL. GitHub Pages cannot execute Octave, MATLAB, or Dynare.");
}

async function responseJson(response) {
  let body = null;
  try { body = await response.json(); } catch (_) { /* handled below */ }
  if (!response.ok) {
    const detail = body?.detail;
    const message = typeof detail === "string" ? detail : detail?.message || body?.message;
    throw new Error(message || `Request failed with HTTP ${response.status}.`);
  }
  return body;
}

async function runLiveSimulation() {
  clearError();
  setRunning(true);
  try {
    const base = apiBase();
    const request = buildRequest();
    showStatus("Validating and queuing live simulation", "running");
    const created = await responseJson(await fetch(`${base}/api/jobs`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request),
    }));
    let job = created;
    while (!['complete', 'failed'].includes(job.status)) {
      showStatus(job.message || `Solver ${job.phase || job.status}`, "running");
      await new Promise((resolve) => window.setTimeout(resolve, 1000));
      job = await responseJson(await fetch(`${base}/api/jobs/${encodeURIComponent(job.id)}`));
    }
    if (job.status === "failed") {
      const suffix = job.diagnosticId ? ` Diagnostic ID: ${job.diagnosticId}` : "";
      throw new Error(`${job.message || "The solver failed."}${suffix}`);
    }
    acceptResult(job.result, "live simulation");
    showStatus(job.result.cacheHit ? "Live request: cached solved result" : "Live model result", "ready");
  } catch (error) {
    showError(error.message);
    showStatus("Live simulation failed", "error");
  } finally {
    setRunning(false);
  }
}

async function loadSavedResult() {
  clearError();
  const preset = el.scenarioPreset.value;
  if (preset === "custom_path") {
    showError("There is no saved result for a custom tariff path. Configure a live solver instead.");
    return;
  }
  setRunning(true);
  try {
    const filename = preset === "bilateral_10" ? "saved_bilateral_10.json" : "saved_unilateral_10.json";
    showStatus("Loading saved model result", "running");
    const result = await responseJson(await fetch(`./data/${filename}`));
    acceptResult(result, "saved model result");
    showStatus("Saved model result (not a live solve)", "saved");
  } catch (error) {
    showError(`Could not load the saved model result: ${error.message}`);
    showStatus("Saved result unavailable", "error");
  } finally {
    setRunning(false);
  }
}

function acceptResult(result, displayMode) {
  if (!result || result.status !== "ok" || !Array.isArray(result.periods) || !result.series) {
    throw new Error("The result payload is incomplete.");
  }
  state.result = result;
  state.catalog = Array.isArray(result.variables) ? result.variables : Object.keys(result.series).map((name) => ({ name, label: name, defaultTransform: "raw" }));
  state.selected = new Set([...state.selected].filter((name) => result.series[name]));
  if (!state.selected.size) CORE_VARIABLES.filter((name) => result.series[name]).forEach((name) => state.selected.add(name));
  el.plotPeriods.max = String(result.periods.length);
  el.plotPeriods.value = String(Math.min(Number(el.plotPeriods.value) || 80, result.periods.length));
  el.metricMode.textContent = displayMode;
  updateMetrics(result.metrics || {});
  renderVariableSelector();
  renderPlot();
}

function updateMetrics(metrics) {
  el.metricWelfare.textContent = formatMetric(metrics.welf);
  el.metricSsUtil.textContent = formatMetric(metrics.ssUtil);
  el.metricRevenue.textContent = formatMetric(metrics.revPV1_try ?? metrics.revPV1_raw);
}

function formatMetric(value) {
  return typeof value === "number" && Number.isFinite(value) ? value.toPrecision(6) : "n/a";
}

function renderVariableSelector() {
  const query = el.variableSearch.value.trim().toLowerCase();
  el.variableSelector.replaceChildren();
  state.catalog
    .filter((item) => !query || `${item.name} ${item.label || ""} ${item.type || ""}`.toLowerCase().includes(query))
    .forEach((item) => {
      const row = document.createElement("div");
      row.className = "check-row";
      const label = document.createElement("label");
      label.className = "series-check";
      label.title = `${item.name}${item.type ? ` — ${item.type}` : ""}`;
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = state.selected.has(item.name);
      const text = document.createElement("span");
      text.textContent = item.label || item.name;
      label.append(checkbox, text);
      const axis = document.createElement("select");
      axis.className = "axis-select";
      axis.innerHTML = '<option value="y">Left</option><option value="y2">Right</option>';
      axis.value = state.axes[item.name] || "y";
      axis.disabled = !checkbox.checked;
      checkbox.addEventListener("change", () => {
        if (checkbox.checked) state.selected.add(item.name); else state.selected.delete(item.name);
        axis.disabled = !checkbox.checked;
        renderPlot();
      });
      axis.addEventListener("change", () => {
        state.axes[item.name] = axis.value;
        renderPlot();
      });
      row.append(label, axis);
      el.variableSelector.append(row);
    });
}

function seriesTransform(name) {
  const series = state.result.series[name];
  const selected = el.transformMode.value;
  if (selected !== "auto") return selected;
  const catalogItem = state.catalog.find((item) => item.name === name);
  return catalogItem?.defaultTransform || series.defaultTransform || "raw";
}

function renderPlot() {
  if (!state.result) return;
  const count = Math.max(1, Math.min(state.result.periods.length, Number(el.plotPeriods.value) || state.result.periods.length));
  const periods = state.result.periods.slice(0, count);
  const selected = [...state.selected].filter((name) => state.result.series[name]);
  const traces = selected.map((name, index) => {
    const transform = seriesTransform(name);
    const series = state.result.series[name];
    const values = Array.isArray(series[transform]) ? series[transform] : series.raw;
    return {
      x: periods,
      y: values.slice(0, count),
      name: series.label || name,
      meta: name,
      yaxis: state.axes[name] || "y",
      mode: "lines+markers",
      line: { color: COLORS[index % COLORS.length], dash: DASHES[index % DASHES.length], width: 2.2 },
      marker: { color: COLORS[index % COLORS.length], symbol: MARKERS[index % MARKERS.length], size: 5 },
      hovertemplate: "%{meta}<br>period %{x}<br>%{y:.6g}<extra></extra>",
    };
  });
  const hasRight = selected.some((name) => state.axes[name] === "y2");
  const layout = {
    margin: { l: 66, r: hasRight ? 72 : 32, t: 28, b: 56 },
    paper_bgcolor: "#ffffff",
    plot_bgcolor: "#ffffff",
    hovermode: "x unified",
    legend: { orientation: "h", y: -0.2, x: 0 },
    xaxis: { title: "Period", showline: true, linecolor: "#667085", mirror: false, zeroline: false },
    yaxis: { title: transformLabel(el.transformMode.value), showline: true, linecolor: "#667085", zerolinecolor: "#d8ddd2" },
    annotations: traces.length ? [] : [{ text: "Select at least one series", showarrow: false, x: 0.5, y: 0.5, xref: "paper", yref: "paper" }],
  };
  if (hasRight) {
    layout.yaxis2 = { title: "Secondary axis", overlaying: "y", side: "right", showline: true, linecolor: "#667085", zeroline: false };
  }
  Plotly.react(el.plot, traces, layout, { responsive: true, displaylogo: false, scrollZoom: true });
}

function transformLabel(transform) {
  return ({ auto: "Series-specific transform", level: "Level", log_change: "Log change", percent_change: "Percent change", rate_percent: "Rate (%)", raw: "Raw solver value" })[transform] || transform;
}

function selectCore() {
  if (!state.result) return;
  state.selected = new Set(CORE_VARIABLES.filter((name) => state.result.series[name]));
  renderVariableSelector();
  renderPlot();
}

function addVariable() {
  const name = el.customVariable.value.trim();
  if (!name) return;
  if (!state.result?.series?.[name]) {
    showError(`The current solver result does not contain a series named ${name}.`);
    return;
  }
  clearError();
  state.selected.add(name);
  el.customVariable.value = "";
  renderVariableSelector();
  renderPlot();
}

function downloadCsv() {
  if (!state.result) return;
  const names = [...state.selected].filter((name) => state.result.series[name]);
  if (!names.length) return showError("Select at least one series before downloading CSV.");
  const count = Math.max(1, Math.min(state.result.periods.length, Number(el.plotPeriods.value) || state.result.periods.length));
  const rows = [["period", ...names.map((name) => `${name}__${seriesTransform(name)}`)]];
  for (let index = 0; index < count; index += 1) {
    rows.push([state.result.periods[index], ...names.map((name) => state.result.series[name][seriesTransform(name)][index])]);
  }
  const csv = rows.map((row) => row.map(csvCell).join(",")).join("\r\n");
  downloadBlob(csv, `dege_${state.result.scenario?.preset || "simulation"}.csv`, "text/csv;charset=utf-8");
}

function csvCell(value) {
  const text = String(value ?? "");
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function downloadBlob(content, filename, type) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function downloadFigure() {
  if (!state.result) return;
  Plotly.downloadImage(el.plot, {
    format: "svg",
    filename: `dege_${state.result.scenario?.preset || "simulation"}`,
    width: 1400,
    height: 850,
    scale: 2,
  });
}

function setRunning(running) {
  state.running = running;
  el.runButton.disabled = running;
  el.loadSaved.disabled = running || el.scenarioPreset.value === "custom_path";
}

function showStatus(message, kind) {
  el.runStatus.textContent = message;
  el.runStatus.dataset.kind = kind;
}

function showError(message) {
  el.errorBox.textContent = message;
  el.errorBox.classList.remove("hidden");
}

function clearError() {
  el.errorBox.textContent = "";
  el.errorBox.classList.add("hidden");
}

function bindEvents() {
  el.scenarioPreset.addEventListener("change", updateScenarioControls);
  el.resetParams.addEventListener("click", resetParameters);
  el.runButton.addEventListener("click", runLiveSimulation);
  el.loadSaved.addEventListener("click", loadSavedResult);
  el.transformMode.addEventListener("change", renderPlot);
  el.plotPeriods.addEventListener("change", renderPlot);
  el.variableSearch.addEventListener("input", renderVariableSelector);
  el.selectCore.addEventListener("click", selectCore);
  el.clearSeries.addEventListener("click", () => { state.selected.clear(); renderVariableSelector(); renderPlot(); });
  el.addVariable.addEventListener("click", addVariable);
  el.customVariable.addEventListener("keydown", (event) => { if (event.key === "Enter") addVariable(); });
  el.downloadCsv.addEventListener("click", downloadCsv);
  el.downloadFigure.addEventListener("click", downloadFigure);
  el.apiBase.addEventListener("change", () => localStorage.setItem("degeApiBase", el.apiBase.value.trim()));
}

async function initialize() {
  renderControls();
  bindEvents();
  el.apiBase.value = localStorage.getItem("degeApiBase") || "";
  updateScenarioControls();
  await loadSavedResult();
}

initialize();

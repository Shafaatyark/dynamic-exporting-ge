"use strict";

const CORE_VARIABLES = ["tau21", "tau12", "im1", "im2", "ex12", "ex21"];
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
  tiles: [{ id: 1, series: CORE_VARIABLES.map((name) => ({
    name,
    axis: DEGE_SERIES_LABELS.defaultAxis(name),
  })) }],
  nextTileId: 2,
  running: false,
};

const el = Object.fromEntries([
  "runStatus", "apiBase", "scenarioPreset", "horizon", "targetRate", "initialTau21",
  "initialTau12", "pathProfile", "rebateType", "customPathWrap", "customPath",
  "parameterGrid", "structureGrid", "resetParams", "transformMode", "plotPeriods",
  "seriesSearch", "seriesSelect", "axisChoice", "tileChoice", "addSeries",
  "loadSaved", "runButton", "downloadCsv",
  "downloadFigure", "errorBox", "metricWelfare", "metricSsUtil", "metricRevenue",
  "metricMode", "plotGrid", "selectCore", "clearSeries",
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
  const suppliedCatalog = Array.isArray(result.variables)
    ? result.variables
    : Object.keys(result.series).map((name) => ({ name, defaultTransform: "raw" }));
  state.catalog = suppliedCatalog
    .map((item) => ({ ...item, label: DEGE_SERIES_LABELS.economicLabel(item.name) }))
    .sort((left, right) => left.label.localeCompare(right.label));
  state.tiles.forEach((tile) => {
    tile.series = tile.series.filter((item) => result.series[item.name]);
  });
  if (!selectedSeriesNames().length) {
    state.tiles = [{
      id: 1,
      series: CORE_VARIABLES.filter((name) => result.series[name]).map((name) => ({
        name,
        axis: DEGE_SERIES_LABELS.defaultAxis(name),
      })),
    }];
    state.nextTileId = 2;
  }
  el.plotPeriods.max = String(result.periods.length);
  el.plotPeriods.value = String(Math.min(Number(el.plotPeriods.value) || 80, result.periods.length));
  el.metricMode.textContent = displayMode;
  updateMetrics(result.metrics || {});
  renderSeriesPicker();
  renderPlots();
}

function updateMetrics(metrics) {
  el.metricWelfare.textContent = formatMetric(metrics.welf);
  el.metricSsUtil.textContent = formatMetric(metrics.ssUtil);
  el.metricRevenue.textContent = formatMetric(metrics.revPV1_try ?? metrics.revPV1_raw);
}

function formatMetric(value) {
  return typeof value === "number" && Number.isFinite(value) ? value.toPrecision(6) : "n/a";
}

function selectedSeriesNames() {
  return [...new Set(state.tiles.flatMap((tile) => tile.series.map((item) => item.name)))];
}

function catalogItem(name) {
  return state.catalog.find((item) => item.name === name);
}

function seriesLabel(name) {
  return catalogItem(name)?.label || DEGE_SERIES_LABELS.economicLabel(name);
}

function renderSeriesPicker() {
  const query = el.seriesSearch.value.trim().toLowerCase();
  const previousSeries = el.seriesSelect.value;
  const matching = state.catalog.filter((item) => (
    !query || `${item.label} ${item.name} ${item.type || ""}`.toLowerCase().includes(query)
  ));

  el.seriesSelect.replaceChildren();
  if (!matching.length) {
    const empty = document.createElement("option");
    empty.textContent = "No matching series";
    empty.value = "";
    el.seriesSelect.append(empty);
    el.seriesSelect.disabled = true;
    el.addSeries.disabled = true;
  } else {
    matching.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.name;
      option.textContent = DEGE_SERIES_LABELS.displayLabel(item.name);
      el.seriesSelect.append(option);
    });
    el.seriesSelect.disabled = false;
    el.addSeries.disabled = state.running;
    if (matching.some((item) => item.name === previousSeries)) {
      el.seriesSelect.value = previousSeries;
    } else if (matching.some((item) => item.name === "c1")) {
      el.seriesSelect.value = "c1";
    }
    if (el.seriesSelect.value !== previousSeries) {
      el.axisChoice.value = DEGE_SERIES_LABELS.defaultAxis(el.seriesSelect.value);
    }
  }

  const previousTile = el.tileChoice.value;
  el.tileChoice.replaceChildren();
  state.tiles.forEach((tile, index) => {
    const option = document.createElement("option");
    option.value = String(tile.id);
    option.textContent = `Chart ${index + 1}`;
    el.tileChoice.append(option);
  });
  const newTile = document.createElement("option");
  newTile.value = "new";
  newTile.textContent = "New chart tile";
  el.tileChoice.append(newTile);
  if ([...el.tileChoice.options].some((option) => option.value === previousTile)) {
    el.tileChoice.value = previousTile;
  }
}

function seriesTransform(name) {
  const series = state.result.series[name];
  const selected = el.transformMode.value;
  if (selected !== "auto") return selected;
  const catalogItem = state.catalog.find((item) => item.name === name);
  return catalogItem?.defaultTransform || series.defaultTransform || "raw";
}

function renderPlots() {
  if (!state.result) return;
  el.plotGrid.replaceChildren();
  state.tiles.forEach((tile, tileIndex) => el.plotGrid.append(buildChartTile(tile, tileIndex)));
}

function buildChartTile(tile, tileIndex) {
  const article = document.createElement("article");
  article.className = "chart-tile";
  article.dataset.tileId = String(tile.id);

  const header = document.createElement("div");
  header.className = "chart-tile-header";
  const heading = document.createElement("div");
  const title = document.createElement("h3");
  title.textContent = `Chart ${tileIndex + 1}`;
  const subtitle = document.createElement("p");
  subtitle.textContent = `${tile.series.length} ${tile.series.length === 1 ? "series" : "series"}`;
  heading.append(title, subtitle);

  const actions = document.createElement("div");
  actions.className = "chart-tile-actions";
  const svgButton = document.createElement("button");
  svgButton.type = "button";
  svgButton.className = "secondary small-button";
  svgButton.textContent = "SVG";
  svgButton.addEventListener("click", () => downloadTileFigure(tile.id, tileIndex));
  actions.append(svgButton);
  if (state.tiles.length > 1) {
    const removeTile = document.createElement("button");
    removeTile.type = "button";
    removeTile.className = "secondary small-button";
    removeTile.textContent = "Remove tile";
    removeTile.addEventListener("click", () => {
      state.tiles = state.tiles.filter((candidate) => candidate.id !== tile.id);
      renderSeriesPicker();
      renderPlots();
    });
    actions.append(removeTile);
  }
  header.append(heading, actions);

  const plot = document.createElement("div");
  plot.id = `plot-${tile.id}`;
  plot.className = "plot";

  const seriesBox = document.createElement("div");
  seriesBox.className = "tile-series-box";
  if (!tile.series.length) {
    const empty = document.createElement("p");
    empty.className = "empty-series";
    empty.textContent = "No series in this chart. Use the dropdown above to add one.";
    seriesBox.append(empty);
  } else {
    tile.series.forEach((item) => seriesBox.append(buildSelectedSeriesRow(tile, item)));
  }

  article.append(header, plot, seriesBox);
  window.requestAnimationFrame(() => drawTilePlot(plot, tile));
  return article;
}

function buildSelectedSeriesRow(tile, item) {
  const row = document.createElement("div");
  row.className = "selected-series-row";

  const description = document.createElement("div");
  description.className = "selected-series-name";
  const label = document.createElement("strong");
  label.textContent = seriesLabel(item.name);
  const code = document.createElement("span");
  code.textContent = item.name;
  description.append(label, code);

  const axisLabel = document.createElement("label");
  axisLabel.className = "inline-axis-control";
  const axisText = document.createElement("span");
  axisText.textContent = "Axis";
  const axis = document.createElement("select");
  axis.setAttribute("aria-label", `Axis for ${seriesLabel(item.name)}`);
  axis.innerHTML = '<option value="y">Left</option><option value="y2">Right</option>';
  axis.value = item.axis;
  axis.addEventListener("change", () => {
    item.axis = axis.value;
    renderPlots();
  });
  axisLabel.append(axisText, axis);

  const remove = document.createElement("button");
  remove.type = "button";
  remove.className = "remove-series";
  remove.setAttribute("aria-label", `Remove ${seriesLabel(item.name)} from chart`);
  remove.title = "Remove series";
  remove.textContent = "×";
  remove.addEventListener("click", () => {
    tile.series = tile.series.filter((candidate) => candidate !== item);
    renderPlots();
  });

  row.append(description, axisLabel, remove);
  return row;
}

function drawTilePlot(plot, tile) {
  const count = Math.max(1, Math.min(state.result.periods.length, Number(el.plotPeriods.value) || state.result.periods.length));
  const periods = state.result.periods.slice(0, count);
  const traces = tile.series.map((item, index) => {
    const transform = seriesTransform(item.name);
    const series = state.result.series[item.name];
    const values = Array.isArray(series[transform]) ? series[transform] : series.raw;
    return {
      x: periods,
      y: values.slice(0, count),
      name: seriesLabel(item.name),
      meta: `${seriesLabel(item.name)} (${item.name})`,
      yaxis: item.axis,
      mode: "lines+markers",
      line: { color: COLORS[index % COLORS.length], dash: DASHES[index % DASHES.length], width: 2.2 },
      marker: { color: COLORS[index % COLORS.length], symbol: MARKERS[index % MARKERS.length], size: 5 },
      hovertemplate: "%{meta}<br>period %{x}<br>%{y:.6g}<extra></extra>",
    };
  });
  const hasRight = tile.series.some((item) => item.axis === "y2");
  const layout = {
    margin: { l: 64, r: hasRight ? 72 : 28, t: 18, b: 72 },
    paper_bgcolor: "#ffffff",
    plot_bgcolor: "#ffffff",
    hovermode: "x unified",
    legend: { orientation: "h", y: -0.24, x: 0 },
    xaxis: { title: "Period", showline: true, linecolor: "#667085", mirror: false, zeroline: false },
    yaxis: { title: transformLabel(el.transformMode.value), showline: true, linecolor: "#667085", zerolinecolor: "#d8ddd2" },
    annotations: traces.length ? [] : [{ text: "Add a series to this chart", showarrow: false, x: 0.5, y: 0.5, xref: "paper", yref: "paper" }],
  };
  if (hasRight) {
    layout.yaxis2 = { title: "Right axis", overlaying: "y", side: "right", showline: true, linecolor: "#667085", zeroline: false };
  }
  Plotly.react(plot, traces, layout, { responsive: true, displaylogo: false, scrollZoom: true });
}

function transformLabel(transform) {
  return ({ auto: "Series-specific transform", level: "Level", log_change: "Log change", percent_change: "Percent change", rate_percent: "Rate (%)", raw: "Raw solver value" })[transform] || transform;
}

function selectCore() {
  if (!state.result) return;
  state.tiles = [{
    id: 1,
    series: CORE_VARIABLES.filter((name) => state.result.series[name]).map((name) => ({
      name,
      axis: DEGE_SERIES_LABELS.defaultAxis(name),
    })),
  }];
  state.nextTileId = 2;
  renderSeriesPicker();
  renderPlots();
}

function addSeries() {
  const name = el.seriesSelect.value;
  if (!name) return;
  if (!state.result?.series?.[name]) {
    showError("Choose an available economic series before adding it.");
    return;
  }
  clearError();
  let tile;
  if (el.tileChoice.value === "new") {
    tile = { id: state.nextTileId, series: [] };
    state.nextTileId += 1;
    state.tiles.push(tile);
  } else {
    tile = state.tiles.find((candidate) => candidate.id === Number(el.tileChoice.value));
  }
  if (!tile) return showError("Choose a chart tile before adding the series.");
  const existing = tile.series.find((item) => item.name === name);
  if (existing) {
    existing.axis = el.axisChoice.value;
  } else {
    tile.series.push({ name, axis: el.axisChoice.value });
  }
  renderSeriesPicker();
  el.tileChoice.value = String(tile.id);
  renderPlots();
}

function downloadCsv() {
  if (!state.result) return;
  const names = selectedSeriesNames().filter((name) => state.result.series[name]);
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
  state.tiles.forEach((tile, index) => downloadTileFigure(tile.id, index));
}

function downloadTileFigure(tileId, tileIndex) {
  const plot = document.getElementById(`plot-${tileId}`);
  if (!plot) return;
  Plotly.downloadImage(plot, {
    format: "svg",
    filename: `dege_${state.result.scenario?.preset || "simulation"}_chart_${tileIndex + 1}`,
    width: 1400,
    height: 850,
    scale: 2,
  });
}

function setRunning(running) {
  state.running = running;
  el.runButton.disabled = running;
  el.loadSaved.disabled = running || el.scenarioPreset.value === "custom_path";
  el.addSeries.disabled = running || !el.seriesSelect.value;
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
  el.transformMode.addEventListener("change", renderPlots);
  el.plotPeriods.addEventListener("change", renderPlots);
  el.seriesSearch.addEventListener("input", renderSeriesPicker);
  el.seriesSelect.addEventListener("change", () => {
    el.axisChoice.value = DEGE_SERIES_LABELS.defaultAxis(el.seriesSelect.value);
  });
  el.selectCore.addEventListener("click", selectCore);
  el.clearSeries.addEventListener("click", () => {
    state.tiles = [{ id: 1, series: [] }];
    state.nextTileId = 2;
    renderSeriesPicker();
    renderPlots();
  });
  el.addSeries.addEventListener("click", addSeries);
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

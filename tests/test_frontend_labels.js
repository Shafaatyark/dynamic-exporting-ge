"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { economicLabel, displayLabel, defaultAxis } = require("../web/series-labels.js");

const resultPath = path.join(__dirname, "..", "web", "data", "saved_unilateral_10.json");
const result = JSON.parse(fs.readFileSync(resultPath, "utf8"));
const appSource = fs.readFileSync(path.join(__dirname, "..", "web", "app.js"), "utf8");
const htmlSource = fs.readFileSync(path.join(__dirname, "..", "web", "index.html"), "utf8");
const cssSource = fs.readFileSync(path.join(__dirname, "..", "web", "styles.css"), "utf8");
const names = result.variables.map((item) => item.name);
const labels = names.map(economicLabel);

if (!htmlSource.includes('rel="icon" type="image/svg+xml" href="./favicon.svg"')) {
  throw new Error("The website should load its trade-transition SVG favicon.");
}

if (!htmlSource.includes("<title>Trade Policy Simulator</title>") || !htmlSource.includes("<h1>Trade Policy Simulator</h1>")) {
  throw new Error("The browser tab and page header should use the public Trade Policy Simulator title.");
}

if (!appSource.includes('const CORE_VARIABLES = ["tau21", "im1", "ex12"];')) {
  throw new Error("The initial chart should contain only Home tariff, import, and export series.");
}

if (!appSource.includes('resetZoom.textContent = "Reset zoom";') || !appSource.includes('"xaxis.autorange": true')) {
  throw new Error("Each chart should provide an explicit zoom reset control.");
}

if (!appSource.includes('%{y:.2f}')) {
  throw new Error("Chart hover values should display exactly two decimal places.");
}

if (!appSource.includes("const SOLUTION_HORIZON = 80;") || htmlSource.includes('id="horizon"')) {
  throw new Error("The solver horizon should be fixed and absent from user controls.");
}

if (!htmlSource.includes("Periods plotted") || !htmlSource.includes('id="plotPeriods"')) {
  throw new Error("The plot area should provide an independent period-range control.");
}

if (!htmlSource.includes('id="customPolicyScope"') || !htmlSource.includes('id="customPathPreview"') || htmlSource.includes('id="customPath"')) {
  throw new Error("The custom scenario should use policy points and a preview instead of a CSV textarea.");
}

if (!appSource.includes('b: 86') || !appSource.includes('y: -0.46') || !appSource.includes('standoff: 8')) {
  throw new Error("The custom-path preview should separate its x-axis title from the legend.");
}

if (!htmlSource.includes("Revenue PV / GDP (%)") || !appSource.includes("100 * revenueToGdp")) {
  throw new Error("The revenue summary should display the present-value revenue-to-GDP ratio in percent.");
}

if (!htmlSource.includes("Welfare (%)") || !htmlSource.includes("SS utility (%)")) {
  throw new Error("Welfare and steady-state utility summaries should be explicitly labeled as percentages.");
}

if (!appSource.includes("value.toFixed(2)") || !appSource.includes('tickformat: ".2f"')) {
  throw new Error("Website metrics and chart axes should display no more than two decimal places.");
}

if (htmlSource.includes('option value="raw"') || htmlSource.includes("Raw Dynare value")) {
  throw new Error("Raw Dynare values should not be offered as a plotting or CSV transform.");
}

if (!appSource.includes('return preferred === "raw" ? "level" : preferred;')) {
  throw new Error("Automatic plotting and CSV export should replace internal raw defaults with economic levels.");
}

if (!htmlSource.includes("Initial Home tariff rate (%) (τ₂₁)") || !htmlSource.includes("Initial Foreign tariff rate (%) (τ₁₂)")) {
  throw new Error("Initial Home and Foreign tariff controls should use percent rates.");
}

if (!appSource.includes("grossTariffFromPercent") || !appSource.includes("1 + rate / 100")) {
  throw new Error("Percent tariff inputs should be converted to gross tariffs at the model boundary.");
}

if (!htmlSource.includes('id="resultNotice"') || !appSource.includes("markResultsStale") || !appSource.includes("await loadSavedResult();")) {
  throw new Error("Changed inputs should mark results stale and saved-preset changes should load matching results.");
}

if (!htmlSource.includes('id="downloadAllCsv"') || !htmlSource.includes("Plotted CSV") || !appSource.includes("downloadAllCsv")) {
  throw new Error("The website should distinguish plotted-data and all-series CSV downloads.");
}

if (!appSource.includes("VARIABLE_GROUP_ORDER") || !appSource.includes('document.createElement("optgroup")')) {
  throw new Error("The full variable catalog should be grouped into economic categories.");
}

if (!appSource.includes("scrollZoom: false") || appSource.includes("scrollZoom: true")) {
  throw new Error("Chart wheel zoom should be disabled to protect page scrolling and prevent accidental zooms.");
}

if (!appSource.includes('return "Mixed units (see legend)"') || !appSource.includes('return "Tariff rate (%)"')) {
  throw new Error("Chart axes should use economic unit titles.");
}

if (!htmlSource.includes("mobile-results-link") || !appSource.includes('matchMedia("(max-width: 560px)")')) {
  throw new Error("Mobile users should receive collapsed parameters and a direct results link.");
}

if (!cssSource.includes("max-width: 1320px") || !cssSource.includes(".result-notice")) {
  throw new Error("Intermediate-width overflow and stale-result messaging should have responsive styles.");
}

if ((htmlSource.match(/class="info-tip"/g) || []).length !== 3 || !cssSource.includes(".info-tip:focus::after")) {
  throw new Error("All three economic summary metrics should provide accessible definition tooltips.");
}

if (!htmlSource.includes("Open PowerShell in the downloaded project folder") || !htmlSource.includes("use <code>cd</code>")) {
  throw new Error("Windows startup instructions should explain how to select the project directory.");
}

const fallbackNames = names.filter((name, index) => labels[index] === name || labels[index].startsWith("Model series "));
if (fallbackNames.length) {
  throw new Error(`Missing economic labels for: ${fallbackNames.join(", ")}`);
}

if (new Set(labels).size !== labels.length) {
  throw new Error("Economic series labels must be unique.");
}

names.forEach((name) => {
  if (!displayLabel(name).endsWith(`(${name})`)) {
    throw new Error(`Dropdown label does not retain the model code for ${name}.`);
  }
});

["tau11", "tau12", "tau21", "tau22"].forEach((name) => {
  if (defaultAxis(name) !== "y2") {
    throw new Error(`Tariff series ${name} should default to the right axis.`);
  }
});

["im1", "im2", "ex12", "ex21", "c1"].forEach((name) => {
  if (defaultAxis(name) !== "y") {
    throw new Error(`Non-tariff series ${name} should default to the left axis.`);
  }
});

console.log(`Validated ${names.length} economic series labels.`);

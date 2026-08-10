"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { economicLabel, displayLabel, defaultAxis } = require("../web/series-labels.js");

const resultPath = path.join(__dirname, "..", "web", "data", "saved_unilateral_10.json");
const result = JSON.parse(fs.readFileSync(resultPath, "utf8"));
const appSource = fs.readFileSync(path.join(__dirname, "..", "web", "app.js"), "utf8");
const htmlSource = fs.readFileSync(path.join(__dirname, "..", "web", "index.html"), "utf8");
const names = result.variables.map((item) => item.name);
const labels = names.map(economicLabel);

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

if (!htmlSource.includes("Initial Home gross tariff (τ₂₁)") || !htmlSource.includes("Initial Foreign gross tariff (τ₁₂)")) {
  throw new Error("Initial tariff controls should identify the Home and Foreign tariff separately.");
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

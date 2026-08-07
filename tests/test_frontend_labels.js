"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { economicLabel, displayLabel, defaultAxis } = require("../web/series-labels.js");

const resultPath = path.join(__dirname, "..", "web", "data", "saved_unilateral_10.json");
const result = JSON.parse(fs.readFileSync(resultPath, "utf8"));
const appSource = fs.readFileSync(path.join(__dirname, "..", "web", "app.js"), "utf8");
const names = result.variables.map((item) => item.name);
const labels = names.map(economicLabel);

if (!appSource.includes('const CORE_VARIABLES = ["tau21", "im1", "ex12"];')) {
  throw new Error("The initial chart should contain only Home tariff, import, and export series.");
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

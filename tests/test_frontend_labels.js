"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { economicLabel, displayLabel } = require("../web/series-labels.js");

const resultPath = path.join(__dirname, "..", "web", "data", "saved_unilateral_10.json");
const result = JSON.parse(fs.readFileSync(resultPath, "utf8"));
const names = result.variables.map((item) => item.name);
const labels = names.map(economicLabel);

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

console.log(`Validated ${names.length} economic series labels.`);

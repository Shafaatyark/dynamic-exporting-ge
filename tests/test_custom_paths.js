"use strict";

const assert = require("node:assert/strict");
const { buildPolicyPaths } = require("../web/custom-paths.js");

const step = buildPolicyPaths({
  points: [
    { period: 3, homeRate: 10, foreignRate: "" },
    { period: 5, homeRate: "", foreignRate: "" },
  ],
  scope: "home",
  interpolation: "step",
  initialTau21: 1,
  initialTau12: 1,
  horizon: 80,
});
assert.equal(step.tau21Path.length, 80);
assert.equal(step.tau12Path.length, 80);
assert.deepEqual(step.homeRates.slice(0, 5), [0, 0, 10, 10, 10]);
assert.ok(step.foreignRates.every((rate) => rate === 0));
assert.ok(step.tau21Path.slice(2).every((gross) => Math.abs(gross - 1.1) < 1e-12));

const linear = buildPolicyPaths({
  points: [{ period: 5, homeRate: 10, foreignRate: 20 }],
  scope: "both",
  interpolation: "linear",
  initialTau21: 1,
  initialTau12: 1,
  horizon: 80,
});
assert.deepEqual(linear.homeRates.slice(0, 6), [2, 4, 6, 8, 10, 10]);
assert.deepEqual(linear.foreignRates.slice(0, 6), [4, 8, 12, 16, 20, 20]);
assert.ok(linear.homeRates.slice(4).every((rate) => rate === 10));

const foreignOnly = buildPolicyPaths({
  points: [{ period: 1, homeRate: 50, foreignRate: 7.5 }],
  scope: "foreign",
  interpolation: "step",
  initialTau21: 1.02,
  initialTau12: 1,
  horizon: 80,
});
assert.ok(foreignOnly.homeRates.every((rate) => Math.abs(rate - 2) < 1e-12));
assert.ok(foreignOnly.foreignRates.every((rate) => rate === 7.5));

assert.throws(() => buildPolicyPaths({
  points: [{ period: 2, homeRate: 5 }, { period: 2, homeRate: 10 }],
  scope: "home",
  interpolation: "step",
  initialTau21: 1,
  initialTau12: 1,
  horizon: 80,
}), /different period/);

console.log("Validated custom policy-point path construction.");

(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.DEGE_CUSTOM_PATHS = api;
}(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  function initialRate(grossValue, label) {
    const gross = Number(grossValue);
    if (!Number.isFinite(gross) || gross <= 0) {
      throw new Error(`${label} initial gross tariff must be positive.`);
    }
    return 100 * (gross - 1);
  }

  function policyRate(value, label) {
    if (String(value ?? "").trim() === "") return null;
    const rate = Number(value);
    if (!Number.isFinite(rate) || rate <= -100 || rate > 500) {
      throw new Error(`${label} must be greater than -100% and at most 500%.`);
    }
    return rate;
  }

  function parsePoints(points, horizon) {
    if (!Array.isArray(points) || !points.length) {
      throw new Error("Add at least one policy point.");
    }
    const parsed = points.map((point, index) => {
      const period = Number(point.period);
      if (!Number.isInteger(period) || period < 1 || period > horizon) {
        throw new Error(`Policy point ${index + 1} needs an integer period from 1 to ${horizon}.`);
      }
      return {
        period,
        homeRate: policyRate(point.homeRate, `Home rate at period ${period}`),
        foreignRate: policyRate(point.foreignRate, `Foreign rate at period ${period}`),
      };
    }).sort((left, right) => left.period - right.period);
    if (new Set(parsed.map((point) => point.period)).size !== parsed.length) {
      throw new Error("Each policy point must use a different period.");
    }
    return parsed;
  }

  function interpolate(points, field, initial, selected, interpolation, horizon) {
    if (!selected) return Array(horizon).fill(initial);
    const changes = points
      .filter((point) => point[field] !== null)
      .map((point) => ({ period: point.period, rate: point[field] }));
    if (!changes.length) return Array(horizon).fill(initial);

    const rates = Array(horizon).fill(initial);
    if (interpolation === "step") {
      let current = initial;
      let changeIndex = 0;
      for (let period = 1; period <= horizon; period += 1) {
        if (changeIndex < changes.length && changes[changeIndex].period === period) {
          current = changes[changeIndex].rate;
          changeIndex += 1;
        }
        rates[period - 1] = current;
      }
      return rates;
    }
    if (interpolation !== "linear") throw new Error("Interpolation must be step or linear.");

    let previous = { period: 0, rate: initial };
    changes.forEach((next) => {
      const span = next.period - previous.period;
      for (let period = previous.period + 1; period <= next.period; period += 1) {
        const weight = (period - previous.period) / span;
        rates[period - 1] = previous.rate + weight * (next.rate - previous.rate);
      }
      previous = next;
    });
    for (let period = previous.period + 1; period <= horizon; period += 1) {
      rates[period - 1] = previous.rate;
    }
    return rates;
  }

  function buildPolicyPaths(options) {
    const horizon = Number(options.horizon || 80);
    const scopeValue = options.scope || "home";
    if (!Number.isInteger(horizon) || horizon < 1) throw new Error("Solution horizon must be positive.");
    if (!["home", "foreign", "both"].includes(scopeValue)) throw new Error("Unknown policy scope.");
    const scope = {
      home: scopeValue === "home" || scopeValue === "both",
      foreign: scopeValue === "foreign" || scopeValue === "both",
    };
    const initialHome = initialRate(options.initialTau21, "Home");
    const initialForeign = initialRate(options.initialTau12, "Foreign");
    const points = parsePoints(options.points, horizon);
    const homeRates = interpolate(points, "homeRate", initialHome, scope.home, options.interpolation || "step", horizon);
    const foreignRates = interpolate(points, "foreignRate", initialForeign, scope.foreign, options.interpolation || "step", horizon);
    return {
      tau21Path: homeRates.map((rate) => 1 + rate / 100),
      tau12Path: foreignRates.map((rate) => 1 + rate / 100),
      homeRates,
      foreignRates,
      initialHome,
      initialForeign,
      scope,
    };
  }

  return { buildPolicyPaths };
}));

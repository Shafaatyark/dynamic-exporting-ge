"use strict";

(function exposeSeriesLabels(root, factory) {
  const api = factory();
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.DEGE_SERIES_LABELS = api;
}(typeof globalThis !== "undefined" ? globalThis : window, () => {
  const COUNTRY = { "1": "Home", "2": "Foreign" };

  const COUNTRY_SERIES = {
    bbar: "Steady-state net foreign bond position",
    shockK: "Capital-tax tariff-revenue rebate indicator",
    shockL: "Labor-tax tariff-revenue rebate indicator",
    shockX: "Investment-subsidy tariff-revenue rebate indicator",
    c: "Consumption",
    l: "Labor",
    x: "Investment",
    k: "Capital stock",
    b: "Net foreign bonds",
    t: "Tariff revenue",
    m: "Intermediate-material demand",
    rer: "Real exchange rate",
    lp: "Production labor",
    n: "Mass of active firms",
    vd: "Value of a domestic incumbent firm",
    im: "Nominal imports",
    pc: "Consumption price index",
    px: "Investment price index",
    pm: "Intermediate-material price index",
    w: "Wage",
    r: "Rental rate of capital",
    pd: "Domestic producer price",
    ne: "Mass of entering firms",
    y: "Real output",
    d: "Domestic sales",
    ims: "Nominal import expenditure",
    lambda: "Domestic expenditure share",
    IMD: "Import penetration ratio",
    mu: "Marginal value of installed capital",
    ttL: "Effective labor-income tax rate",
    ttK: "Effective capital-income tax rate",
    s: "Effective investment subsidy rate",
    transfer: "Government transfer",
    edf: "Endogenous discount factor",
    rim: "Real imports",
    Pi_H: "Aggregate profits",
    T_rs_H: "Revenue-subsidy tax",
    lambdac: "Consumption-goods domestic expenditure share",
    Ac: "Consumption-goods trade asymmetry",
    Xc: "Consumption-goods import-weighted tariff",
    lambdax: "Investment-goods domestic expenditure share",
    Ax: "Investment-goods trade asymmetry",
    Xx: "Investment-goods import-weighted tariff",
    lambdam: "Materials domestic expenditure share",
    Am: "Materials trade asymmetry",
    Xm: "Materials import-weighted tariff",
  };

  const BILATERAL_SERIES = {
    n: "Exporter mass",
    nH: "H-state exporter mass",
    nL: "L-state exporter mass",
    n0: "Nonexporter mass",
    ex: "Exports",
    pc: "Consumption-goods export price",
    px: "Investment-goods export price",
    pm: "Materials export price",
    elastc: "Consumption-goods trade elasticity",
    elastx: "Investment-goods trade elasticity",
    elastm: "Materials trade elasticity",
    vx0: "Potential-exporter value",
    dvH: "H-state export value gain",
    dvL: "L-state export value gain",
    kap0: "Nonexporter entry threshold",
    kapH: "H-state continuation threshold",
    kapL: "L-state continuation threshold",
  };

  function economicLabel(name) {
    const tariff = /^tau([12])([12])$/.exec(name);
    if (tariff) {
      const origin = COUNTRY[tariff[1]];
      const destination = COUNTRY[tariff[2]];
      return tariff[1] === tariff[2]
        ? `${destination} tariff on domestic goods`
        : `${destination} tariff on ${origin} goods`;
    }

    for (const [base, description] of Object.entries(COUNTRY_SERIES)) {
      const match = new RegExp(`^${base}([12])$`).exec(name);
      if (match) return `${COUNTRY[match[1]]} ${description}`;
    }

    const importSpending = /^ims([12])([12])$/.exec(name);
    if (importSpending && importSpending[1] !== importSpending[2]) {
      return `${COUNTRY[importSpending[1]]} import spending on ${COUNTRY[importSpending[2]]} goods`;
    }

    for (const [base, description] of Object.entries(BILATERAL_SERIES)) {
      const match = new RegExp(`^${base}([12])([12])$`).exec(name);
      if (match && match[1] !== match[2]) {
        return `${description}: ${COUNTRY[match[1]]} to ${COUNTRY[match[2]]}`;
      }
    }

    return `Model series ${name}`;
  }

  function displayLabel(name) {
    return `${economicLabel(name)} (${name})`;
  }

  return { economicLabel, displayLabel };
}));

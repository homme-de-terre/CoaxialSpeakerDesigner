import test from 'node:test';
import assert from 'node:assert/strict';

// Helper function modeling project document serialization (matching App.jsx handleSaveDesign)
function createDesignDocument({
  driverName = "Custom Coaxial Driver",
  manufacturer = "AudioLabs",
  datasheetURL = "https://example.com/datasheet.pdf",
  ts = {
    fs: 48.0,
    qes: 0.38,
    qms: 4.8,
    qts: 0.35,
    vas: 45.0,
    re: 6.2,
    le: 0.85,
    sd: 215.0,
    xmax: 4.5,
    spl: 93.0,
    pe: 150.0
  },
  tweeter = {
    fs: 1500,
    re: 6.8,
    le: 0.08,
    spl: 96.0,
    nominalImpedance: 8.0
  },
  wooferCurve = [{ frequency: 100, magnitude: 92.5, phase: -12.0 }],
  tweeterCurve = [{ frequency: 2000, magnitude: 96.0, phase: -45.0 }],
  enclosureType = 'vented',
  alignment = 'qb3',
  customQtc = 0.707,
  targetF3 = 45.0,
  stuffingGain = 1.10,
  manualVbOverride = true,
  manualVbLiters = 35.0,
  ventedAlignment = 'qb3',
  tuningFb = 42.0,
  portDiameterCm = 8.0,
  portCount = 1,
  fx = 2200,
  wooferOrder = 'secondOrderLR',
  tweeterOrder = 'thirdOrderBW',
  enableIndependentFx = true,
  wooferFx = 2000,
  tweeterFx = 2400,
  enableZobel = true,
  enableLPad = true,
  lpadAttenDB = 4.5,
  acousticDelayMM = 30.0,
  invertTweeterPolarity = true,
  snapToE12 = true,
  enableAllpass = false,
  wooferFRDText = "20 75 0\n100 92 0",
  tweeterFRDText = "1000 95 0\n10000 96 0"
} = {}) {
  const stuffingLevels = {
    1.0: 'none',
    1.1: 'light',
    1.18: 'medium',
    1.25: 'heavy'
  };
  const currentStuffing = stuffingLevels[stuffingGain] || (stuffingGain >= 1.2 ? 'heavy' : (stuffingGain >= 1.15 ? 'medium' : (stuffingGain >= 1.05 ? 'light' : 'none')));

  return {
    version: 1,
    timestamp: new Date().toISOString(),
    name: driverName || "Custom Speaker Design",
    driver: {
      name: driverName,
      manufacturer: manufacturer,
      datasheetURL: datasheetURL,
      wooferTS: { ...ts },
      tweeter: { ...tweeter },
      wooferAcousticCurve: wooferCurve || [],
      tweeterAcousticCurve: tweeterCurve || []
    },
    cabinet: {
      enclosureType,
      alignment,
      targetQtc: customQtc,
      targetF3,
      stuffing: currentStuffing,
      isManualVolumeOverride: manualVbOverride,
      manualNetVolumeLiters: manualVbLiters,
      ventedAlignment,
      tuningFrequencyFb: tuningFb,
      portDiameterCm,
      numberOfPorts: portCount,
      portLossQl: 15.0
    },
    crossover: {
      crossoverFrequency: fx,
      wooferOrder,
      tweeterOrder,
      enableIndependentFrequencies: enableIndependentFx,
      wooferCrossoverFrequency: enableIndependentFx ? wooferFx : null,
      tweeterCrossoverFrequency: enableIndependentFx ? tweeterFx : null,
      enableZobelNetwork: enableZobel,
      enableLPadAttenuator: enableLPad,
      userTargetAttenuationdB: lpadAttenDB,
      acousticCenterOffsetMM: acousticDelayMM,
      invertTweeterPolarity,
      snapToStandardValues: snapToE12,
      enableAllpassFilter: enableAllpass
    },
    wooferFRDText: wooferFRDText || "",
    tweeterFRDText: tweeterFRDText || ""
  };
}

// Helper simulating processJSONDesignFile from App.jsx
function restoreDesignDocument(jsonString) {
  const doc = JSON.parse(jsonString);
  const state = {};

  if (doc.driver) {
    if (doc.driver.name) state.driverName = doc.driver.name;
    if (doc.driver.manufacturer) state.manufacturer = doc.driver.manufacturer;
    if (doc.driver.datasheetURL) state.datasheetURL = doc.driver.datasheetURL;
    if (doc.driver.wooferTS) state.ts = { ...doc.driver.wooferTS };
    if (doc.driver.tweeter) state.tweeter = { ...doc.driver.tweeter };
    if (Array.isArray(doc.driver.wooferAcousticCurve)) state.wooferCurve = doc.driver.wooferAcousticCurve;
    if (Array.isArray(doc.driver.tweeterAcousticCurve)) state.tweeterCurve = doc.driver.tweeterAcousticCurve;
  }

  if (doc.cabinet) {
    if (doc.cabinet.enclosureType) state.enclosureType = doc.cabinet.enclosureType;
    if (doc.cabinet.alignment) state.alignment = doc.cabinet.alignment;
    if (doc.cabinet.targetQtc !== undefined) state.customQtc = doc.cabinet.targetQtc;
    if (doc.cabinet.targetF3 !== undefined) state.targetF3 = doc.cabinet.targetF3;
    if (doc.cabinet.isManualVolumeOverride !== undefined) state.manualVbOverride = doc.cabinet.isManualVolumeOverride;
    if (doc.cabinet.manualNetVolumeLiters !== undefined) state.manualVbLiters = doc.cabinet.manualNetVolumeLiters;
    if (doc.cabinet.ventedAlignment) state.ventedAlignment = doc.cabinet.ventedAlignment;
    if (doc.cabinet.tuningFrequencyFb !== undefined) state.tuningFb = doc.cabinet.tuningFrequencyFb;
    if (doc.cabinet.portDiameterCm !== undefined) state.portDiameterCm = doc.cabinet.portDiameterCm;
    if (doc.cabinet.numberOfPorts !== undefined) state.portCount = doc.cabinet.numberOfPorts;
    if (doc.cabinet.stuffing) {
      const sMap = { 'none': 1.0, 'light': 1.10, 'medium': 1.18, 'heavy': 1.25 };
      state.stuffingGain = sMap[doc.cabinet.stuffing] || 1.0;
    }
  }

  if (doc.crossover) {
    if (doc.crossover.crossoverFrequency !== undefined) state.fx = doc.crossover.crossoverFrequency;
    if (doc.crossover.wooferOrder) state.wooferOrder = doc.crossover.wooferOrder;
    if (doc.crossover.tweeterOrder) state.tweeterOrder = doc.crossover.tweeterOrder;
    if (doc.crossover.enableIndependentFrequencies !== undefined) {
      state.enableIndependentFx = doc.crossover.enableIndependentFrequencies;
    }
    if (doc.crossover.wooferCrossoverFrequency) state.wooferFx = doc.crossover.wooferCrossoverFrequency;
    if (doc.crossover.tweeterCrossoverFrequency) state.tweeterFx = doc.crossover.tweeterCrossoverFrequency;
    if (doc.crossover.enableZobelNetwork !== undefined) state.enableZobel = doc.crossover.enableZobelNetwork;
    if (doc.crossover.enableLPadAttenuator !== undefined) state.enableLPad = doc.crossover.enableLPadAttenuator;
    if (doc.crossover.userTargetAttenuationdB !== undefined) state.lpadAttenDB = doc.crossover.userTargetAttenuationdB;
    if (doc.crossover.acousticCenterOffsetMM !== undefined) state.acousticDelayMM = doc.crossover.acousticCenterOffsetMM;
    if (doc.crossover.invertTweeterPolarity !== undefined) state.invertTweeterPolarity = doc.crossover.invertTweeterPolarity;
    if (doc.crossover.snapToStandardValues !== undefined) state.snapToE12 = doc.crossover.snapToStandardValues;
    if (doc.crossover.enableAllpassFilter !== undefined) state.enableAllpass = doc.crossover.enableAllpassFilter;
  }

  if (doc.wooferFRDText) state.wooferFRDText = doc.wooferFRDText;
  if (doc.tweeterFRDText) state.tweeterFRDText = doc.tweeterFRDText;

  return state;
}

test('Design Project File - Complete Serialization and Schema Conformance', () => {
  const doc = createDesignDocument();
  assert.equal(doc.version, 1);
  assert.equal(typeof doc.timestamp, 'string');
  assert.ok(!isNaN(Date.parse(doc.timestamp)), 'Timestamp must be ISO8601 parsable');
  assert.equal(doc.name, 'Custom Coaxial Driver');

  // Driver validation
  assert.equal(doc.driver.name, 'Custom Coaxial Driver');
  assert.equal(doc.driver.wooferTS.fs, 48.0);
  assert.equal(doc.driver.wooferTS.spl, 93.0);
  assert.equal(doc.driver.tweeter.spl, 96.0);

  // Cabinet validation
  assert.equal(doc.cabinet.enclosureType, 'vented');
  assert.equal(doc.cabinet.stuffing, 'light');
  assert.equal(doc.cabinet.manualNetVolumeLiters, 35.0);

  // Crossover validation
  assert.equal(doc.crossover.crossoverFrequency, 2200);
  assert.equal(doc.crossover.enableIndependentFrequencies, true);
  assert.equal(doc.crossover.wooferCrossoverFrequency, 2000);
  assert.equal(doc.crossover.tweeterCrossoverFrequency, 2400);
  assert.equal(doc.crossover.invertTweeterPolarity, true);
});

test('Design Project File - Full Roundtrip Serialization and Deserialization', () => {
  const original = createDesignDocument({
    driverName: "Altec 604-8K Studio Monitor",
    manufacturer: "Altec Lansing",
    ts: {
      fs: 30.0,
      qes: 0.28,
      qms: 7.2,
      qts: 0.27,
      vas: 450.0,
      re: 6.8,
      le: 1.15,
      sd: 855.0,
      xmax: 5.0,
      spl: 99.0,
      pe: 200.0
    },
    tweeter: {
      fs: 1200,
      re: 7.2,
      le: 0.15,
      spl: 105.0,
      nominalImpedance: 8.0
    },
    fx: 1500,
    wooferOrder: 'secondOrderLR',
    tweeterOrder: 'thirdOrderBW',
    lpadAttenDB: 6.0,
    acousticDelayMM: 55.0,
    invertTweeterPolarity: true
  });

  const jsonString = JSON.stringify(original, null, 2);
  const restored = restoreDesignDocument(jsonString);

  assert.equal(restored.driverName, "Altec 604-8K Studio Monitor");
  assert.equal(restored.manufacturer, "Altec Lansing");
  assert.equal(restored.ts.fs, 30.0);
  assert.equal(restored.ts.qts, 0.27);
  assert.equal(restored.ts.vas, 450.0);
  assert.equal(restored.tweeter.spl, 105.0);
  assert.equal(restored.fx, 1500);
  assert.equal(restored.lpadAttenDB, 6.0);
  assert.equal(restored.acousticDelayMM, 55.0);
  assert.equal(restored.invertTweeterPolarity, true);
});

test('Design Project File - Swift Interoperability with SpeakerDesignDocument JSON', () => {
  // Test JSON format identical to what Swift SpeakerDesignDocument encodes
  const swiftExportedJSON = JSON.stringify({
    version: 1,
    timestamp: "2026-11-20T10:00:00Z",
    name: "Beyma 12XA30Nd",
    driver: {
      name: "12XA30Nd",
      manufacturer: "Beyma",
      datasheetURL: "local",
      wooferTS: {
        fs: 45.0,
        qes: 0.32,
        qms: 6.5,
        qts: 0.305,
        vas: 85.0,
        re: 5.6,
        le: 0.70,
        sd: 530.0,
        xmax: 6.0,
        spl: 98.0,
        pe: 350.0
      },
      tweeter: {
        fs: 1100.0,
        re: 6.0,
        le: 0.06,
        spl: 104.0,
        nominalImpedance: 8.0
      },
      wooferAcousticCurve: [{ frequency: 50, magnitude: 90, phase: 0 }],
      tweeterAcousticCurve: [{ frequency: 1500, magnitude: 104, phase: 0 }]
    },
    cabinet: {
      enclosureType: "vented",
      alignment: "qb3",
      targetQtc: 0.707,
      targetF3: 45.0,
      stuffing: "light",
      isManualVolumeOverride: false,
      manualNetVolumeLiters: 65.0,
      ventedAlignment: "qb3",
      tuningFrequencyFb: 45.0,
      portDiameterCm: 10.0,
      numberOfPorts: 1,
      portLossQl: 15.0
    },
    crossover: {
      crossoverFrequency: 1800.0,
      wooferOrder: "secondOrderLR",
      tweeterOrder: "secondOrderLR",
      enableIndependentFrequencies: false,
      enableZobelNetwork: true,
      enableLPadAttenuator: true,
      userTargetAttenuationdB: 5.5,
      acousticCenterOffsetMM: 40.0,
      invertTweeterPolarity: true,
      snapToStandardValues: false,
      enableAllpassFilter: false
    },
    wooferFRDText: "50 90 0\n100 95 0",
    tweeterFRDText: "1500 104 0\n10000 102 0"
  });

  const restored = restoreDesignDocument(swiftExportedJSON);
  assert.equal(restored.driverName, "12XA30Nd");
  assert.equal(restored.manufacturer, "Beyma");
  assert.equal(restored.ts.fs, 45.0);
  assert.equal(restored.ts.qts, 0.305);
  assert.equal(restored.enclosureType, "vented");
  assert.equal(restored.fx, 1800.0);
  assert.equal(restored.enableZobel, true);
  assert.equal(restored.lpadAttenDB, 5.5);
  assert.equal(restored.invertTweeterPolarity, true);
  assert.equal(restored.stuffingGain, 1.10);
});

test('Design Project File - Robust Handling of Corrupted JSON', () => {
  assert.throws(() => {
    restoreDesignDocument("{ invalid json string ]");
  }, SyntaxError);

  // Empty JSON should restore cleanly without throwing
  const emptyState = restoreDesignDocument("{}");
  assert.deepEqual(emptyState, {});
});

test('Design Project File - Filename Sanitization for File Download', () => {
  const testNames = [
    { input: "Custom Speaker / Monitor #1", expected: "Custom_Speaker_/_Monitor_#1_Design.json" },
    { input: "  Altec  604-8K  ", expected: "Altec_604-8K_Design.json" },
    { input: "", expected: "Speaker_Design.json" },
    { input: null, expected: "Speaker_Design.json" }
  ];

  for (const { input, expected } of testNames) {
    const sanitizedName = (input || "Speaker").trim().replace(/\s+/g, '_');
    const filename = `${sanitizedName}_Design.json`;
    assert.equal(filename, expected);
  }
});

test('Design Project File - Partial Document Restoration', () => {
  // Only driver provided
  const partialDoc = JSON.stringify({
    version: 1,
    name: "Partial Test",
    driver: {
      name: "Woofer Only",
      wooferTS: { fs: 42.0, qts: 0.35 }
    }
  });

  const restored = restoreDesignDocument(partialDoc);
  assert.equal(restored.driverName, "Woofer Only");
  assert.equal(restored.ts.fs, 42.0);
  assert.equal(restored.ts.qts, 0.35);
  assert.equal(restored.cabinet, undefined);
  assert.equal(restored.crossover, undefined);
});

test('Design Project File - E12 Value Snapping Algorithm', () => {
  function snapE12(val) {
    if (!val || val <= 0) return 0;
    const e12Base = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2, 10.0];
    const exponent = Math.floor(Math.log10(val));
    const norm = val / Math.pow(10, exponent);
    let closest = norm;
    let minDiff = Infinity;
    for (const b of e12Base) {
      const diff = Math.abs(b - norm);
      if (diff < minDiff) {
        minDiff = diff;
        closest = b;
      }
    }
    return closest * Math.pow(10, exponent);
  }

  assert.equal(snapE12(4.6), 4.7);
  assert.equal(snapE12(0.31), 0.33);
  assert.equal(snapE12(14.8), 15.0);
  assert.equal(snapE12(0), 0);
  assert.equal(snapE12(-5), 0);
});

test('Design Project File - Complex Number Physics Math', () => {
  class Complex {
    constructor(re, im = 0) {
      this.re = re;
      this.im = im;
    }
    static polar(r, thetaRad) {
      return new Complex(r * Math.cos(thetaRad), r * Math.sin(thetaRad));
    }
    add(c) {
      return c instanceof Complex 
        ? new Complex(this.re + c.re, this.im + c.im)
        : new Complex(this.re + c, this.im);
    }
    sub(c) {
      return c instanceof Complex 
        ? new Complex(this.re - c.re, this.im - c.im)
        : new Complex(this.re - c, this.im);
    }
    mul(c) {
      return c instanceof Complex 
        ? new Complex(this.re * c.re - this.im * c.im, this.re * c.im + this.im * c.re)
        : new Complex(this.re * c, this.im * c);
    }
    div(c) {
      if (typeof c === 'number') return new Complex(this.re / c, this.im / c);
      const denom = c.re * c.re + c.im * c.im;
      if (denom === 0) return new Complex(0, 0);
      return new Complex(
        (this.re * c.re + this.im * c.im) / denom,
        (this.im * c.re - this.re * c.im) / denom
      );
    }
    get mag() { return Math.hypot(this.re, this.im); }
    get phaseDeg() { return Math.atan2(this.im, this.re) * (180 / Math.PI); }
  }

  const c1 = new Complex(3, 4);
  assert.equal(c1.mag, 5.0);
  assert.equal(Math.round(c1.phaseDeg), 53);

  const c2 = new Complex(1, -2);
  const sum = c1.add(c2);
  assert.equal(sum.re, 4);
  assert.equal(sum.im, 2);

  const prod = c1.mul(c2);
  // (3 + 4i)(1 - 2i) = 3 - 6i + 4i - 8i^2 = 11 - 2i
  assert.equal(prod.re, 11);
  assert.equal(prod.im, -2);

  const quot = c1.div(c2);
  // (3+4i)/(1-2i) = (3+4i)(1+2i)/5 = (3+6i+4i-8)/5 = (-5+10i)/5 = -1 + 2i
  assert.equal(quot.re, -1);
  assert.equal(quot.im, 2);
});


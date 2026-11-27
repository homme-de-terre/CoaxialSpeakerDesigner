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
  snapToE24 = false,
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
      snapToStandardValues: snapToE24 ? false : snapToE12,
      snapToE24Values: snapToE24,
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
    if (doc.crossover.snapToE24Values !== undefined) {
      state.snapToE24 = doc.crossover.snapToE24Values;
      if (doc.crossover.snapToE24Values) {
        state.snapToE12 = false;
      } else if (doc.crossover.snapToStandardValues !== undefined) {
        state.snapToE12 = doc.crossover.snapToStandardValues;
      }
    } else if (doc.crossover.snapToStandardValues !== undefined) {
      state.snapToE12 = doc.crossover.snapToStandardValues;
      if (doc.crossover.snapToStandardValues) state.snapToE24 = false;
    }
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

test('Design Project File - E24 Value Snapping Algorithm and Mutual Exclusivity', () => {
  function snapE24(val) {
    if (!val || val <= 0) return 0;
    const e24Base = [
      1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0,
      2.2, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.3,
      4.7, 5.1, 5.6, 6.2, 6.8, 7.5, 8.2, 9.1, 10.0
    ];
    const exponent = Math.floor(Math.log10(val));
    const norm = val / Math.pow(10, exponent);
    let closest = norm;
    let minDiff = Infinity;
    for (const b of e24Base) {
      const diff = Math.abs(b - norm);
      if (diff < minDiff) {
        minDiff = diff;
        closest = b;
      }
    }
    return closest * Math.pow(10, exponent);
  }

  // Test intermediate E24 values not present in E12 (1.1, 1.3, 1.6, 2.0, 2.4, 3.0, 3.6, 4.3, 5.1, 6.2, 7.5, 9.1)
  assert.ok(Math.abs(snapE24(1.11) - 1.1) < 1e-6);
  assert.ok(Math.abs(snapE24(1.32) - 1.3) < 1e-6);
  assert.ok(Math.abs(snapE24(1.62) - 1.6) < 1e-6);
  assert.ok(Math.abs(snapE24(2.04) - 2.0) < 1e-6);
  assert.ok(Math.abs(snapE24(24.2) - 24.0) < 1e-6);
  assert.ok(Math.abs(snapE24(0.362) - 0.36) < 1e-6);
  assert.ok(Math.abs(snapE24(4.32) - 4.3) < 1e-6);
  assert.ok(Math.abs(snapE24(51.4) - 51.0) < 1e-6);
  assert.ok(Math.abs(snapE24(6.18) - 6.2) < 1e-6);
  assert.ok(Math.abs(snapE24(75.3) - 75.0) < 1e-6);
  assert.ok(Math.abs(snapE24(9.08) - 9.1) < 1e-6);
  assert.equal(snapE24(0), 0);
  assert.equal(snapE24(-10), 0);

  // Verify JSON serialization & restoration with E24 snap enabled
  const docE24 = createDesignDocument({ snapToE12: true, snapToE24: true });
  assert.equal(docE24.crossover.snapToE24Values, true);
  assert.equal(docE24.crossover.snapToStandardValues, false, 'E24 must override E12 when active');

  const restoredE24 = restoreDesignDocument(JSON.stringify(docE24));
  assert.equal(restoredE24.snapToE24, true);
  assert.equal(restoredE24.snapToE12, false);
});

test('Design Project File - 3-Tier Green/Yellow/Red RMS Phase Alignment Warning Logic', () => {
  function getPhaseAlignmentStatus(rmsErrorDeg) {
    if (rmsErrorDeg <= 10.0) {
      return { level: 'green', label: 'Phase Aligned (Optimal)' };
    } else if (rmsErrorDeg <= 20.0) {
      return { level: 'yellow', label: 'Acceptable Alignment - Minor Phase Offset' };
    } else {
      return { level: 'red', label: 'Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx' };
    }
  }

  // Green tier: <= 10.0°
  for (const val of [0, 3.2, 5.0, 7.8, 10.0]) {
    const res = getPhaseAlignmentStatus(val);
    assert.equal(res.level, 'green');
    assert.equal(res.label, 'Phase Aligned (Optimal)');
  }

  // Yellow tier: 10.0° - 20.0°
  for (const val of [10.01, 12.5, 15.0, 19.99, 20.0]) {
    const res = getPhaseAlignmentStatus(val);
    assert.equal(res.level, 'yellow');
    assert.equal(res.label, 'Acceptable Alignment - Minor Phase Offset');
  }

  // Red tier: > 20.0°
  for (const val of [20.01, 25.4, 42.0, 90.0]) {
    const res = getPhaseAlignmentStatus(val);
    assert.equal(res.level, 'red');
    assert.equal(res.label, 'Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx');
  }
});

test('Crossover Component Calculation with Exact, E12, and E24 Snapping', () => {
  function snapSeries(val, base) {
    if (!val || val <= 0) return 0;
    const exponent = Math.floor(Math.log10(val));
    const norm = val / Math.pow(10, exponent);
    let closest = norm;
    let minDiff = Infinity;
    for (const b of base) {
      const diff = Math.abs(b - norm);
      if (diff < minDiff) {
        minDiff = diff;
        closest = b;
      }
    }
    return closest * Math.pow(10, exponent);
  }
  const e12Base = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2, 10.0];
  const e24Base = [
    1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0,
    2.2, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.3,
    4.7, 5.1, 5.6, 6.2, 6.8, 7.5, 8.2, 9.1, 10.0
  ];

  function computeCrossover({ fx = 2200, reW = 6.2, leW = 0.85, reT = 5.8, snapMode = 'none' }) {
    const w = 2.0 * Math.PI * fx;
    const Zw = Math.max(reW, 4.0);
    const Zt = Math.max(reT, 4.0);
    const comp = {
      L1: (Zw / (w * Math.PI)) * 1000.0 * 2.0,
      C1: (1.0 / (2.0 * Math.PI * fx * Zw)) * 1e6,
      C_HP1: (1.0 / (w * Zt)) * 1e6,
      L_HP1: (Zt / w) * 1000.0,
      R_zobel: 1.25 * reW,
      C_zobel: ((leW / 1000.0) / Math.pow(1.25 * reW, 2)) * 1e6
    };
    if (snapMode === 'e24') {
      for (const k of Object.keys(comp)) comp[k] = snapSeries(comp[k], e24Base);
    } else if (snapMode === 'e12') {
      for (const k of Object.keys(comp)) comp[k] = snapSeries(comp[k], e12Base);
    }
    return comp;
  }

  const exact = computeCrossover({ snapMode: 'none' });
  const snappedE12 = computeCrossover({ snapMode: 'e12' });
  const snappedE24 = computeCrossover({ snapMode: 'e24' });

  // E24 must always be at least as close to exact values as E12
  for (const key of Object.keys(exact)) {
    const errE12 = Math.abs(snappedE12[key] - exact[key]);
    const errE24 = Math.abs(snappedE24[key] - exact[key]);
    assert.ok(errE24 <= errE12 + 1e-9, `E24 error for ${key} (${errE24}) must be <= E12 error (${errE12})`);
  }
});

test('Detached Live Curve Windows State and 2x2 Monitor Grid Lifecycle', () => {
  let detachedPlots = {
    amplitude: false,
    phase: false,
    delay: false,
    step: false,
    impedance: false
  };

  const toggleDetachedPlot = (key) => {
    detachedPlots = { ...detachedPlots, [key]: !detachedPlots[key] };
  };
  const openLiveMonitorGrid = () => {
    detachedPlots = {
      ...detachedPlots,
      amplitude: true,
      phase: true,
      delay: true,
      impedance: true
    };
  };
  const closeAllDetachedPlots = () => {
    detachedPlots = {
      amplitude: false,
      phase: false,
      delay: false,
      step: false,
      impedance: false
    };
  };

  // Initially none detached
  assert.equal(Object.values(detachedPlots).some(Boolean), false);

  // Detach Step Response individually
  toggleDetachedPlot('step');
  assert.equal(detachedPlots.step, true);
  assert.equal(detachedPlots.amplitude, false);

  // Open 2x2 Live Monitor Grid (opens Amplitude, Phase & Delay, Group Delay, Impedance while preserving Step)
  openLiveMonitorGrid();
  assert.equal(detachedPlots.amplitude, true);
  assert.equal(detachedPlots.phase, true);
  assert.equal(detachedPlots.delay, true);
  assert.equal(detachedPlots.impedance, true);
  assert.equal(detachedPlots.step, true);

  // Toggle Phase off
  toggleDetachedPlot('phase');
  assert.equal(detachedPlots.phase, false);
  assert.equal(detachedPlots.amplitude, true);

  // Close all detached plots
  closeAllDetachedPlots();
  assert.equal(Object.values(detachedPlots).some(Boolean), false);
});

test('Auto-Scaling Y-Axis for Impedance and Group Delay Plots', () => {
  function computeImpedanceScale(points, { showWoofer = true, showTweeter = true, showTotalSystem = true } = {}) {
    let maxObservedZ = 0.0;
    for (const p of points) {
      if (showWoofer && Number.isFinite(p.zWooferMag)) maxObservedZ = Math.max(maxObservedZ, p.zWooferMag);
      if (showTweeter && Number.isFinite(p.zTweeterMag)) maxObservedZ = Math.max(maxObservedZ, p.zTweeterMag);
      if (showTotalSystem && Number.isFinite(p.zTotalMag)) maxObservedZ = Math.max(maxObservedZ, p.zTotalMag);
    }
    const targetMaxZ = maxObservedZ > 0 ? Math.max(8.0, maxObservedZ * 1.08) : 50.0;
    let stepZ = 10.0;
    if (targetMaxZ <= 16.0) stepZ = 2.0;
    else if (targetMaxZ <= 45.0) stepZ = 5.0;
    else if (targetMaxZ <= 120.0) stepZ = 10.0;
    else stepZ = 20.0;
    const maxZ = Math.ceil(targetMaxZ / stepZ) * stepZ;
    return { minZ: 0.0, maxZ, stepZ };
  }

  function computeGroupDelayScale(points, { showWoofer = true, showTweeter = true, showTotalSystem = true } = {}) {
    let maxObserved = -Infinity;
    let minObserved = Infinity;
    for (const p of points) {
      if (showWoofer && Number.isFinite(p.wooferGD)) {
        maxObserved = Math.max(maxObserved, p.wooferGD);
        minObserved = Math.min(minObserved, p.wooferGD);
      }
      if (showTweeter && Number.isFinite(p.tweeterGD)) {
        maxObserved = Math.max(maxObserved, p.tweeterGD);
        minObserved = Math.min(minObserved, p.tweeterGD);
      }
      if (showTotalSystem && Number.isFinite(p.totalGD)) {
        maxObserved = Math.max(maxObserved, p.totalGD);
        minObserved = Math.min(minObserved, p.totalGD);
      }
    }
    if (!Number.isFinite(maxObserved) || !Number.isFinite(minObserved)) {
      maxObserved = 5.0;
      minObserved = 0.0;
    }
    const rawMax = Math.max(0.4, maxObserved * 1.08);
    const rawMin = minObserved < -0.05 ? (minObserved * 1.08) : 0.0;
    const rawSpan = Math.max(0.4, rawMax - rawMin);
    let stepMs = 1.0;
    if (rawSpan <= 1.2) stepMs = 0.2;
    else if (rawSpan <= 3.0) stepMs = 0.5;
    else if (rawSpan <= 10.0) stepMs = 1.0;
    else if (rawSpan <= 25.0) stepMs = 2.0;
    else stepMs = 5.0;
    const minMs = rawMin < 0 ? (Math.floor(rawMin / stepMs) * stepMs) : 0.0;
    const maxMs = Math.max(minMs + stepMs, Math.ceil(rawMax / stepMs) * stepMs);
    return { minMs, maxMs, stepMs };
  }

  const samplePoints = [
    { zWooferMag: 34.2, zTweeterMag: 11.5, zTotalMag: 12.1, wooferGD: 3.4, tweeterGD: 0.45, totalGD: 1.8 },
    { zWooferMag: 7.5, zTweeterMag: 6.2, zTotalMag: 6.4, wooferGD: 0.8, tweeterGD: 0.12, totalGD: 0.6 }
  ];

  // Impedance: Tweeter only (peak 11.5 -> maxZ = 14, stepZ = 2) vs All (peak 34.2 -> maxZ = 40, stepZ = 5)
  const zTw = computeImpedanceScale(samplePoints, { showWoofer: false, showTweeter: true, showTotalSystem: false });
  assert.equal(zTw.maxZ, 14.0);
  assert.equal(zTw.stepZ, 2.0);

  const zAll = computeImpedanceScale(samplePoints, { showWoofer: true, showTweeter: true, showTotalSystem: true });
  assert.equal(zAll.maxZ, 40.0);
  assert.equal(zAll.stepZ, 5.0);

  // Group Delay: Tweeter only (peak 0.45 -> maxMs = 0.6, stepMs = 0.2) vs All (peak 3.4 -> maxMs = 4.0, stepMs = 1.0)
  const gdTw = computeGroupDelayScale(samplePoints, { showWoofer: false, showTweeter: true, showTotalSystem: false });
  assert.ok(Math.abs(gdTw.maxMs - 0.6) < 1e-6);
  assert.equal(gdTw.stepMs, 0.2);

  const gdAll = computeGroupDelayScale(samplePoints, { showWoofer: true, showTweeter: true, showTotalSystem: true });
  assert.equal(gdAll.maxMs, 4.0);
  assert.equal(gdAll.stepMs, 1.0);
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

test('FRD Import/Export - Multi-Delimiter Parser, European Decimals, and 3-Column Export Roundtrip', () => {
  function parseFRDText(text) {
    if (!text || typeof text !== 'string') return [];
    const points = [];
    const lines = text.split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('*') || trimmed.startsWith('//') || trimmed.startsWith('#')) {
        continue;
      }
      let components;
      if (trimmed.includes(';')) {
        components = trimmed.split(';').map(s => s.trim().replace(',', '.')).filter(Boolean);
      } else {
        const wsTokens = trimmed.split(/\s+/).filter(Boolean);
        if (wsTokens.length >= 2 && !trimmed.includes(', ')) {
          components = wsTokens.map(s => s.replace(/,+$/, '').replace(',', '.'));
        } else {
          components = trimmed.split(/[\s,]+/).filter(Boolean);
        }
      }
      if (components.length >= 2) {
        const freq = parseFloat(components[0]);
        const mag = parseFloat(components[1]);
        if (Number.isFinite(freq) && freq > 0 && Number.isFinite(mag)) {
          const rawPhase = components.length >= 3 ? parseFloat(components[2]) : 0.0;
          const phase = Number.isFinite(rawPhase) ? rawPhase : 0.0;
          points.push({ frequency: freq, magnitude: mag, phase });
        }
      }
    }
    return points.sort((a, b) => a.frequency - b.frequency);
  }

  function exportToFRD(points, comment = "Exported from CoaxialSpeakerDesigner") {
    let result = `* ${comment}\n* Freq(Hz)\tMag(dB)\tPhase(Deg)\n`;
    for (const p of points) {
      const freq = (p.frequency ?? 0).toFixed(2);
      const mag = (p.magnitude ?? 0).toFixed(3);
      const phase = (p.phase ?? 0).toFixed(2);
      result += `${freq}\t${mag}\t${phase}\n`;
    }
    return result;
  }

  // 1. Standard tab/space separated 3-column FRD with comments
  const standardFRD = `* Measured Woofer FRD\n# Freq SPL Phase\n100.0\t92.5\t-12.4\n20.0  81.0  45.2\n1000.0 95.1 -35.0`;
  const parsedStd = parseFRDText(standardFRD);
  assert.equal(parsedStd.length, 3);
  assert.equal(parsedStd[0].frequency, 20.0);
  assert.equal(parsedStd[0].magnitude, 81.0);
  assert.equal(parsedStd[0].phase, 45.2);
  assert.equal(parsedStd[1].frequency, 100.0);
  assert.equal(parsedStd[2].frequency, 1000.0);

  // 2. European comma-decimal with whitespace or semicolon delimiters
  const euFRD = `20,0\t84,25\t10,5\n200,0; 96,40; -5,25\n2000,0\t94,00`;
  const parsedEU = parseFRDText(euFRD);
  assert.equal(parsedEU.length, 3);
  assert.equal(parsedEU[0].magnitude, 84.25);
  assert.equal(parsedEU[0].phase, 10.5);
  assert.equal(parsedEU[1].frequency, 200.0);
  assert.equal(parsedEU[1].magnitude, 96.40);
  assert.equal(parsedEU[1].phase, -5.25);
  assert.equal(parsedEU[2].phase, 0.0);

  // 3. Export to FRD and re-import roundtrip
  const exported = exportToFRD(parsedStd, "Altec Lansing 604-8K - Closed Cabinet");
  assert.ok(exported.includes("* Altec Lansing 604-8K - Closed Cabinet"));
  assert.ok(exported.includes("* Freq(Hz)\tMag(dB)\tPhase(Deg)"));
  const roundtrip = parseFRDText(exported);
  assert.equal(roundtrip.length, 3);
  assert.equal(roundtrip[0].frequency, 20.0);
  assert.equal(roundtrip[1].magnitude, 92.5);
  assert.equal(roundtrip[2].phase, -35.0);
});

test('Altec 604-8K Preset - Hilbert Minimum Phase, Curve Interpolation, and Graph Reflection', async () => {
  const {
    altec604WooferTS,
    altec604Tweeter,
    altec604RecommendedCrossover,
    altec604WooferCurve,
    altec604TweeterCurve
  } = await import('../src/utils/altec604Data.js');

  assert.equal(altec604WooferTS.fs, 24.0);
  assert.equal(altec604WooferTS.qts, 0.287);
  assert.equal(altec604WooferTS.vas, 510.0);
  assert.equal(altec604WooferTS.spl, 98.0);
  assert.equal(altec604Tweeter.spl, 105.0);
  assert.equal(altec604RecommendedCrossover, 1500.0);
  assert.equal(altec604WooferCurve.length, 100);
  assert.equal(altec604TweeterCurve.length, 100);

  // Discrete Hilbert Transform minimum phase synthesis
  function computeMinimumPhase(points) {
    if (!points || points.length < 4) return points || [];
    const n = points.length;
    const result = points.map(p => ({ ...p }));
    for (let i = 0; i < n; i++) {
      const f0 = points[i].frequency;
      let phaseRad = 0.0;
      for (let j = 0; j < n - 1; j++) {
        const f1 = points[j].frequency;
        const f2 = points[j + 1].frequency;
        const mag1 = points[j].magnitude;
        const mag2 = points[j + 1].magnitude;
        if (f1 === f2 || f1 <= 0 || f2 <= 0) continue;
        const dLnA = Math.log(Math.max(Math.pow(10.0, mag2 / 20.0), 1e-6)) - Math.log(Math.max(Math.pow(10.0, mag1 / 20.0), 1e-6));
        const dLnF = Math.log(f2 / f1);
        const slope = dLnA / dLnF;
        const fAvg = Math.sqrt(f1 * f2);
        const diff = Math.abs(fAvg - f0);
        if (diff > 1e-4) {
          const ratio = (fAvg + f0) / diff;
          if (ratio > 1e-6) {
            const kernel = Math.log(ratio);
            const term = (1.0 / Math.PI) * slope * kernel * dLnF;
            if (Number.isFinite(term)) phaseRad -= term;
          }
        }
      }
      let phaseDeg = (phaseRad * (180.0 / Math.PI)) % 360.0;
      if (phaseDeg > 180.0) phaseDeg -= 360.0;
      if (phaseDeg < -180.0) phaseDeg += 360.0;
      result[i].phase = phaseDeg;
    }
    return result;
  }

  const minPhaseWoofer = computeMinimumPhase(altec604WooferCurve);
  const minPhaseTweeter = computeMinimumPhase(altec604TweeterCurve);

  // Verify non-zero minimum phase is synthesized from the Altec 604-8K CLIO amplitude curves
  assert.ok(minPhaseWoofer.some(p => Math.abs(p.phase) > 5.0), 'Hilbert transform must synthesize non-zero minimum phase for Altec 604-8K woofer');
  assert.ok(minPhaseTweeter.some(p => Math.abs(p.phase) > 5.0), 'Hilbert transform must synthesize non-zero minimum phase for Altec 604-8K tweeter');

  // Verify SPL reference shift when user edits Sensitivity after loading Altec preset
  const userEditedSPL = 95.0; // -3 dB from 98.0 dB preset
  const shift = userEditedSPL - altec604WooferTS.spl;
  assert.equal(shift, -3.0);
  const shiftedWoofer = minPhaseWoofer.map(p => ({ ...p, magnitude: p.magnitude + shift }));
  assert.ok(Math.abs(shiftedWoofer[50].magnitude - (altec604WooferCurve[50].magnitude - 3.0)) < 1e-6);
});

test('UI Verification - Cabinet Closed/Ported Title, FRD Import/Export Dialog, and Altec Preset Wiring', async () => {
  const fs = await import('node:fs');
  const appJSX = fs.readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8');
  const mainSplitSwift = fs.readFileSync(new URL('../CoaxialSpeakerDesigner/Sources/CoaxialSpeakerDesigner/Views/MainSplitView.swift', import.meta.url), 'utf8');
  const cabinetSwift = fs.readFileSync(new URL('../CoaxialSpeakerDesigner/Sources/CoaxialSpeakerDesigner/Views/CabinetInspectorView.swift', import.meta.url), 'utf8');
  const frdEditorSwift = fs.readFileSync(new URL('../CoaxialSpeakerDesigner/Sources/CoaxialSpeakerDesigner/Views/CurveDigitizerEditorView.swift', import.meta.url), 'utf8');
  const viewModelSwift = fs.readFileSync(new URL('../CoaxialSpeakerDesigner/Sources/CoaxialSpeakerDesigner/ViewModels/MainDesignerViewModel.swift', import.meta.url), 'utf8');

  // 1. Cabinet title changed to "Cabinet Closed/Ported" in both Swift and React
  assert.ok(mainSplitSwift.includes('Label("Cabinet Closed/Ported"'), 'MainSplitView.swift must use "Cabinet Closed/Ported"');
  assert.ok(!mainSplitSwift.includes('Label("Closed Cabinet"'), 'MainSplitView.swift must not use "Closed Cabinet"');
  assert.ok(cabinetSwift.includes('Text("Cabinet Closed/Ported")'), 'CabinetInspectorView.swift must use "Cabinet Closed/Ported"');
  assert.ok(appJSX.includes('<span>Cabinet Closed/Ported</span>'), 'App.jsx cabinet dialog must use "Cabinet Closed/Ported"');
  assert.ok(appJSX.includes('>Cabinet Closed/Ported</button>'), 'App.jsx navigation tab must use "Cabinet Closed/Ported"');

  // 2. FRD Import/Export dialog buttons exist and are wired in both Swift and React
  assert.ok(frdEditorSwift.includes('viewModel.importWooferFRDText'), 'CurveDigitizerEditorView must wire Import Woofer FRD');
  assert.ok(frdEditorSwift.includes('viewModel.importTweeterFRDText'), 'CurveDigitizerEditorView must wire Import Tweeter FRD');
  assert.ok(frdEditorSwift.includes('viewModel.chooseWooferFRDFile'), 'CurveDigitizerEditorView must wire Choose Woofer FRD File');
  assert.ok(frdEditorSwift.includes('viewModel.chooseTweeterFRDFile'), 'CurveDigitizerEditorView must wire Choose Tweeter FRD File');
  assert.ok(frdEditorSwift.includes('viewModel.exportSystemFRDToFile'), 'CurveDigitizerEditorView must wire Export System Simulated FRD File');
  assert.ok(frdEditorSwift.includes('viewModel.copySystemFRDToClipboard'), 'CurveDigitizerEditorView must wire Copy System Simulated FRD to Clipboard');
  assert.ok(appJSX.includes('handleImportWooferFRDText'), 'App.jsx must wire Import Woofer FRD');
  assert.ok(appJSX.includes('handleImportTweeterFRDText'), 'App.jsx must wire Import Tweeter FRD');
  assert.ok(appJSX.includes('handleExportSystemFRDFile'), 'App.jsx must wire Export System Simulated FRD File');
  assert.ok(appJSX.includes('handleCopySystemFRD'), 'App.jsx must wire Copy System Simulated FRD to Clipboard');

  // 3. Altec 604-8K preset preserves custom curves across recalculateSimulation
  assert.ok(viewModelSwift.includes('!driver.hasCustomWooferCurve && self.wooferFRDText.isEmpty'), 'recalculateSimulation must not overwrite custom/preset woofer curve');
  assert.ok(viewModelSwift.includes('!driver.hasCustomTweeterCurve && self.tweeterFRDText.isEmpty'), 'recalculateSimulation must not overwrite custom/preset tweeter curve');
});

test('End-to-End Simulation - Altec 604-8K Preset and Custom FRD Import Reflect in All 5 Graphs', async () => {
  const {
    altec604WooferTS,
    altec604Tweeter,
    altec604RecommendedCrossover,
    altec604WooferCurve,
    altec604TweeterCurve
  } = await import('../src/utils/altec604Data.js');

  class Complex {
    constructor(re, im = 0) { this.re = re; this.im = im; }
    static polar(r, thetaRad) { return new Complex(r * Math.cos(thetaRad), r * Math.sin(thetaRad)); }
    add(c) { return c instanceof Complex ? new Complex(this.re + c.re, this.im + c.im) : new Complex(this.re + c, this.im); }
    mul(c) { return c instanceof Complex ? new Complex(this.re * c.re - this.im * c.im, this.re * c.im + this.im * c.re) : new Complex(this.re * c, this.im * c); }
    div(c) {
      if (typeof c === 'number') return new Complex(this.re / c, this.im / c);
      const d = c.re * c.re + c.im * c.im;
      return d === 0 ? new Complex(0, 0) : new Complex((this.re * c.re + this.im * c.im) / d, (this.im * c.re - this.re * c.im) / d);
    }
    scale(s) { return new Complex(this.re * s, this.im * s); }
    get mag() { return Math.hypot(this.re, this.im); }
    get phaseDeg() { return Math.atan2(this.im, this.re) * (180 / Math.PI); }
  }

  function computeMinimumPhase(points) {
    if (!points || points.length < 4) return points || [];
    const n = points.length;
    const result = points.map(p => ({ ...p }));
    for (let i = 0; i < n; i++) {
      const f0 = points[i].frequency;
      let phaseRad = 0.0;
      for (let j = 0; j < n - 1; j++) {
        const f1 = points[j].frequency, f2 = points[j + 1].frequency;
        const mag1 = points[j].magnitude, mag2 = points[j + 1].magnitude;
        if (f1 === f2 || f1 <= 0 || f2 <= 0) continue;
        const dLnA = Math.log(Math.max(Math.pow(10.0, mag2 / 20.0), 1e-6)) - Math.log(Math.max(Math.pow(10.0, mag1 / 20.0), 1e-6));
        const dLnF = Math.log(f2 / f1);
        const slope = dLnA / dLnF;
        const fAvg = Math.sqrt(f1 * f2);
        const diff = Math.abs(fAvg - f0);
        if (diff > 1e-4) {
          const ratio = (fAvg + f0) / diff;
          if (ratio > 1e-6) {
            const term = (1.0 / Math.PI) * slope * Math.log(ratio) * dLnF;
            if (Number.isFinite(term)) phaseRad -= term;
          }
        }
      }
      let phaseDeg = (phaseRad * (180.0 / Math.PI)) % 360.0;
      if (phaseDeg > 180.0) phaseDeg -= 360.0;
      if (phaseDeg < -180.0) phaseDeg += 360.0;
      result[i].phase = phaseDeg;
    }
    return result;
  }

  function interpolateCurvePoint(freq, curve) {
    if (!curve || curve.length === 0) return null;
    if (freq <= curve[0].frequency) return { magnitude: curve[0].magnitude, phase: curve[0].phase || 0 };
    if (freq >= curve[curve.length - 1].frequency) {
      const last = curve[curve.length - 1];
      return { magnitude: last.magnitude, phase: last.phase || 0 };
    }
    for (let j = 0; j < curve.length - 1; j++) {
      const p1 = curve[j], p2 = curve[j + 1];
      if (freq >= p1.frequency && freq <= p2.frequency) {
        const t = (Math.log10(freq) - Math.log10(p1.frequency)) / (Math.log10(p2.frequency) - Math.log10(p1.frequency));
        return {
          magnitude: p1.magnitude + t * (p2.magnitude - p1.magnitude),
          phase: (p1.phase || 0) + t * ((p2.phase || 0) - (p1.phase || 0))
        };
      }
    }
    return { magnitude: curve[0].magnitude, phase: curve[0].phase || 0 };
  }

  function runSimulation({ ts, tweeter, fx, wooferCurve = [], tweeterCurve = [] }) {
    const prepW = wooferCurve.length > 0 ? computeMinimumPhase(wooferCurve) : [];
    const prepT = tweeterCurve.length > 0 ? computeMinimumPhase(tweeterCurve) : [];
    const ratio = 0.7071 / Math.max(ts.qts, 0.01);
    const alpha = Math.max(ratio * ratio - 1.0, 0.05);
    const fc = ts.fs * Math.sqrt(1 + alpha);
    const qtc = ts.qts * Math.sqrt(1 + alpha);
    const wc = 2 * Math.PI * fc;
    const delaySec = (35.0 / 1000.0) / 343.0;
    const lpadGain = Math.pow(10, -5.0 / 20.0);

    const testFreqs = [30, 100, 200, 462, 1000, 1500, 1865, 2644, 5000, 10000];
    return testFreqs.map(f => {
      const w = 2 * Math.PI * f;
      const wfPt = interpolateCurvePoint(f, prepW);
      const pWComp = wfPt
        ? Complex.polar(Math.pow(10, wfPt.magnitude / 20.0), wfPt.phase * (Math.PI / 180.0))
        : new Complex(Math.pow(10, (ts.spl - (f > 2200 ? 0.003 * (f - 2200) : 0)) / 20.0), 0);
      const hCab = new Complex(-w * w, 0).div(new Complex(wc * wc - w * w, (w * wc) / qtc));
      const xW = f / fx;
      const hLP = new Complex(1, 0).div(new Complex(1 - xW * xW, 2 * xW));
      const pWFinal = pWComp.mul(hCab).mul(hLP);

      const twPt = interpolateCurvePoint(f, prepT);
      const pTComp = twPt
        ? Complex.polar(Math.pow(10, twPt.magnitude / 20.0), twPt.phase * (Math.PI / 180.0))
        : new Complex(Math.pow(10, (tweeter.spl - (f < 1500 ? 18 * Math.log2(1500 / f) : 0)) / 20.0), 0);
      const xT = f / fx;
      const hHP = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, 2 * xT));
      const hDelay = Complex.polar(1.0, -w * delaySec);
      const pTFinal = pTComp.mul(hHP).mul(lpadGain).mul(hDelay);

      const pTotal = pWFinal.add(pTFinal);
      const deltaF = (f / fc) - (fc / f);
      const resW = ts.re * (ts.qms / ts.qes);
      const denomM = 1 + Math.pow(ts.qms * deltaF, 2);
      const zW = new Complex(ts.re + resW / denomM, w * (ts.le / 1000.0) - resW * (ts.qms * deltaF) / denomM);

      return {
        f,
        wooferSPL: 20 * Math.log10(pWFinal.mag),
        tweeterSPL: 20 * Math.log10(pTFinal.mag),
        totalSPL: 20 * Math.log10(pTotal.mag),
        wooferPhase: pWFinal.phaseDeg,
        tweeterPhase: pTFinal.phaseDeg,
        totalPhase: pTotal.phaseDeg,
        zWooferMag: zW.mag
      };
    });
  }

  const defaultSim = runSimulation({
    ts: { fs: 48.0, qes: 0.36, qms: 4.8, qts: 0.335, vas: 28.0, re: 6.2, le: 0.85, spl: 89.0 },
    tweeter: { fs: 1200.0, re: 5.8, le: 0.08, spl: 94.0 },
    fx: 2200
  });

  const altecSim = runSimulation({
    ts: altec604WooferTS,
    tweeter: altec604Tweeter,
    fx: altec604RecommendedCrossover,
    wooferCurve: altec604WooferCurve,
    tweeterCurve: altec604TweeterCurve
  });

  // Verify every simulated graph metric differs between default and Altec 604-8K preset
  const idx200 = 2; // 200 Hz
  const idx462 = 3; // 462 Hz
  const idx2644 = 7; // 2644 Hz
  assert.notEqual(altecSim[idx200].wooferSPL, defaultSim[idx200].wooferSPL);
  // Altec CLIO curve has a dip at 462 Hz (91.50 dB) vs peak at 200 Hz (98.51 dB)
  assert.ok(altecSim[idx200].wooferSPL > altecSim[idx462].wooferSPL + 5.0, 'Altec CLIO curve features (200 Hz peak vs 462 Hz dip) must reflect in Amplitude graph');
  assert.notEqual(altecSim[idx2644].tweeterSPL, defaultSim[idx2644].tweeterSPL);
  assert.notEqual(altecSim[idx200].wooferPhase, defaultSim[idx200].wooferPhase);
  assert.notEqual(altecSim[idx2644].tweeterPhase, defaultSim[idx2644].tweeterPhase);
  assert.notEqual(altecSim[1].zWooferMag, defaultSim[1].zWooferMag);
});




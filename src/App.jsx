import React, { useState, useEffect, useMemo, useRef } from 'react';
import { parseDatasheetFromURL, parseDatasheetFromFile } from './utils/datasheetParser';
import { altec604WooferTS, altec604Tweeter, altec604RecommendedCrossover, altec604WooferCurve, altec604TweeterCurve } from './utils/altec604Data';
import { 
  Speaker, Volume2, Shield, Settings, Sliders, Cpu, FileText, Download, 
  Check, AlertCircle, Copy, RotateCcw, Box, RefreshCw, Zap, Upload, Info,
  FolderOpen
} from 'lucide-react';

// --- Complex Number Physics Math Engine ---
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
  get phaseRad() { return Math.atan2(this.im, this.re); }
  get phaseDeg() { return Math.atan2(this.im, this.re) * (180 / Math.PI); }
}

// --- E12 & E24 Value Snapping ---
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

// --- 3-Tier RMS Phase Alignment Warning & Status Logic ---
function getPhaseAlignmentStatus(rmsErrorDeg) {
  if (rmsErrorDeg <= 10.0) {
    return { level: 'green', label: 'Phase Aligned (Optimal)' };
  } else if (rmsErrorDeg <= 20.0) {
    return { level: 'yellow', label: 'Acceptable Alignment - Minor Phase Offset' };
  } else {
    return { level: 'red', label: 'Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx' };
  }
}

// --- Resilient Decimal Input Component ---
function DecimalInput({ value, onChange, className, isEuropean, placeholder = "0" }) {
  const [localText, setLocalText] = useState(null);

  const formattedValue = value !== undefined && value !== null 
    ? (isEuropean ? String(value).replace('.', ',') : String(value))
    : '';

  const displayValue = localText !== null ? localText : formattedValue;

  const handleChange = (e) => {
    const raw = e.target.value;
    if (/^[-0-9.,]*$/.test(raw)) {
      setLocalText(raw);
      const parsed = parseFloat(raw.replace(',', '.'));
      if (!isNaN(parsed)) {
        onChange(parsed);
      }
    }
  };

  const handleBlur = () => {
    setLocalText(null);
  };

  return (
    <input
      type="text"
      value={displayValue}
      onChange={handleChange}
      onBlur={handleBlur}
      placeholder={placeholder}
      className={className}
    />
  );
}

export default function App() {
  // --- State Variables ---
  const [activeTab, setActiveTab] = useState('amplitude'); // 'amplitude' | 'phase' | 'impedance' | 'cabinet' | 'crossover' | 'bom' | 'frd'

  // Driver Parameters
  const [driverName, setDriverName] = useState("8CX21 Coaxial 8-inch Driver");
  const [manufacturer, setManufacturer] = useState("AudioPro Coaxial");
  const [datasheetURL, setDatasheetURL] = useState("");
  const [isLoadingURL, setIsLoadingURL] = useState(false);
  const [isLoadingFile, setIsLoadingFile] = useState(false);
  const [isDraggingFile, setIsDraggingFile] = useState(false);
  const [selectedFileName, setSelectedFileName] = useState("");
  const [missingParams, setMissingParams] = useState([]);
  const [plausibilityWarnings, setPlausibilityWarnings] = useState([]);
  const [isEuropeanDecimal, setIsEuropeanDecimal] = useState(false);
  const [statusMsg, setStatusMsg] = useState("");
  const fileInputRef = useRef(null);
  const jsonFileInputRef = useRef(null);

  const [ts, setTs] = useState({
    fs: 48.0,
    qes: 0.36,
    qms: 4.8,
    qts: 0.335,
    vas: 28.0,
    re: 6.2,
    le: 0.85,
    sd: 210.0,
    xmax: 5.5,
    spl: 89.0
  });

  const [tweeter, setTweeter] = useState({
    fs: 1200.0,
    re: 5.8,
    le: 0.08,
    spl: 94.0
  });

  // Enclosure Architecture & Cabinet State
  const [enclosureType, setEnclosureType] = useState('sealed'); // 'sealed' | 'vented'
  const [alignment, setAlignment] = useState('butterworth'); // 'butterworth' | 'bessel' | 'critical' | 'custom' | 'targetF3'
  const [ventedAlignment, setVentedAlignment] = useState('qb3'); // 'qb3' | 'b4' | 'sc4' | 'custom'
  const [tuningFb, setTuningFb] = useState(35.0);
  const [portDiameterCm, setPortDiameterCm] = useState(10.2);
  const [portCount, setPortCount] = useState(1);
  const [targetF3, setTargetF3] = useState(58.0);
  const [customQtc, setCustomQtc] = useState(0.707);
  const [stuffingGain, setStuffingGain] = useState(1.00); // 1.00 (Unfilled / Standard Vb), 1.10 (Light), 1.18 (Medium), 1.25 (Heavy)
  const [manualVbOverride, setManualVbOverride] = useState(false);
  const [manualVbLiters, setManualVbLiters] = useState(25.0);

  // Crossover Network State
  const [fx, setFx] = useState(2200);
  const [enableIndependentFx, setEnableIndependentFx] = useState(false);
  const [wooferFx, setWooferFx] = useState(2200);
  const [tweeterFx, setTweeterFx] = useState(2200);
  const [showAboutDialog, setShowAboutDialog] = useState(false);
  const [showHelpDialog, setShowHelpDialog] = useState(false);
  const [wooferOrder, setWooferOrder] = useState('secondOrderLR');
  const [tweeterOrder, setTweeterOrder] = useState('secondOrderLR');
  const [enableZobel, setEnableZobel] = useState(true);
  const [enableLPad, setEnableLPad] = useState(true);
  const [lpadAttenDB, setLpadAttenDB] = useState(5.0);
  const [acousticDelayMM, setAcousticDelayMM] = useState(35.0);
  const [invertTweeterPolarity, setInvertTweeterPolarity] = useState(false);
  const [snapToE12, setSnapToE12] = useState(false);
  const [snapToE24, setSnapToE24] = useState(false);
  const [enableAllpass, setEnableAllpass] = useState(false);

  // Curve Visibility Toggles
  const [showWoofer, setShowWoofer] = useState(true);
  const [showTweeter, setShowTweeter] = useState(true);
  const [showTotalSystem, setShowTotalSystem] = useState(true);
  const [showPhaseDiff, setShowPhaseDiff] = useState(true);
  const [unwrapPhase, setUnwrapPhase] = useState(true);
  const [compensateTweeterDelay, setCompensateTweeterDelay] = useState(false);

  // FRD Custom Data Strings & Digitized Acoustic Curves
  const [wooferCurve, setWooferCurve] = useState([]);
  const [tweeterCurve, setTweeterCurve] = useState([]);
  const [wooferFRDText, setWooferFRDText] = useState("");
  const [tweeterFRDText, setTweeterFRDText] = useState("");

  // Canvas Refs for Bode Plots (Main Tab & Detached Live Monitor Windows)
  const amplitudeCanvasRef = useRef(null);
  const phaseCanvasRef = useRef(null);
  const impedanceCanvasRef = useRef(null);
  const stepCanvasRef = useRef(null);
  const groupDelayCanvasRef = useRef(null);

  const detachedAmplitudeCanvasRef = useRef(null);
  const detachedPhaseCanvasRef = useRef(null);
  const detachedImpedanceCanvasRef = useRef(null);
  const detachedStepCanvasRef = useRef(null);
  const detachedGroupDelayCanvasRef = useRef(null);

  const [detachedPlots, setDetachedPlots] = useState({
    amplitude: false,
    phase: false,
    delay: false,
    step: false,
    impedance: false
  });

  const toggleDetachedPlot = (plotKey) => {
    setDetachedPlots(prev => ({ ...prev, [plotKey]: !prev[plotKey] }));
  };

  const openLiveMonitorGrid = () => {
    setDetachedPlots(prev => ({
      ...prev,
      amplitude: true,
      phase: true,
      delay: true,
      impedance: true
    }));
  };

  const closeAllDetachedPlots = () => {
    setDetachedPlots({
      amplitude: false,
      phase: false,
      delay: false,
      step: false,
      impedance: false
    });
  };

  const hasDetachedPlots = Object.values(detachedPlots).some(Boolean);

  // --- Enclosure & Cabinet Computations (Sealed 2nd-Order & Vented 4th-Order) ---
  const cabinetCalculations = useMemo(() => {
    // Determine effective Qts
    const effectiveQts = (ts.qts && ts.qts > 0)
      ? ts.qts
      : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35);

    // Map stuffing gain to enclosure absorption loss Qb
    let qbVal = 30.0;
    if (stuffingGain >= 1.24) qbVal = 4.0;
    else if (stuffingGain >= 1.17) qbVal = 7.0;
    else if (stuffingGain >= 1.08) qbVal = 15.0;

    let baseAlpha = 1.0;
    let warningMsg = "";

    const minFeasibleF3 = ts.fs * (0.7071 / Math.max(effectiveQts, 0.01));

    if (enclosureType === 'vented') {
      // Vented 4th-Order (Bass-Reflex) Enclosure Calculations
      let ventedAcousticVb = 25.0;
      let fb = tuningFb;

      if (manualVbOverride || ventedAlignment === 'custom') {
        ventedAcousticVb = manualVbLiters * stuffingGain;
        fb = tuningFb;
      } else {
        const vas = Math.max(ts.vas, 10.0);
        const fs = Math.max(ts.fs, 15.0);
        if (ventedAlignment === 'qb3') {
          ventedAcousticVb = Math.max(3.0 * Math.pow(effectiveQts, 2.0) * vas, 5.0);
          fb = Math.min(Math.max(0.42 * Math.pow(Math.max(effectiveQts, 0.1), -0.9) * fs, 18.0), 120.0);
        } else if (ventedAlignment === 'b4') {
          ventedAcousticVb = Math.max(11.0 * Math.pow(effectiveQts, 3.3) * vas, 5.0);
          fb = Math.min(Math.max(0.42 * Math.pow(Math.max(effectiveQts, 0.1), -0.9) * fs, 18.0), 120.0);
        } else if (ventedAlignment === 'sc4') {
          ventedAcousticVb = Math.max(2.0 * Math.pow(effectiveQts, 1.5) * vas, 5.0);
          fb = Math.min(Math.max(0.85 * fs, 18.0), 120.0);
        }
      }

      const physicalVb = manualVbOverride ? manualVbLiters : (ventedAcousticVb / stuffingGain);
      const physicalCuFt = physicalVb / 28.3168;
      const alpha = ts.vas / Math.max(ventedAcousticVb, 0.1);
      const fc = ts.fs * Math.sqrt(1 + alpha);
      const actualQtc = effectiveQts * Math.sqrt(1 + alpha);

      // Port duct length calculation: Lv = (23562.5 * Dv^2 * Np) / (Fb^2 * Vb) - 0.732 * Dv
      const dv = Math.max(portDiameterCm, 2.0);
      const np = Math.max(portCount, 1);
      const numPort = 23562.5 * Math.pow(dv, 2.0) * np;
      const denPort = Math.pow(fb, 2.0) * Math.max(physicalVb, 1.0);
      const portLengthCm = Math.max((numPort / denPort) - (0.732 * dv), 0.5);

      // Minimum port diameter to prevent chuffing:
      const dMin = (0.15 * Math.sqrt(fb * Math.max(ts.sd, 50.0) * Math.max(ts.xmax, 1.0))) / Math.sqrt(np);

      // Vented 4th-order cutoff f3 calculation (root finding where |H(f)| = 1/sqrt(2))
      const fs = Math.max(ts.fs, 1.0);
      const h = fb / fs;
      const ql = 15.0;
      const c0 = h * h;
      const c1 = (h * h) / effectiveQts + h / ql;
      const c2 = 1.0 + h * h + alpha + h / (effectiveQts * ql);
      const c3 = 1.0 / effectiveQts + h / ql;

      const evalVentedMag = (fVal) => {
        const fn = fVal / fs;
        const reD = Math.pow(fn, 4) - c2 * Math.pow(fn, 2) + c0;
        const imD = -c3 * Math.pow(fn, 3) + c1 * fn;
        return Math.pow(fn, 4) / Math.hypot(reD, imD);
      };

      let lowF = 0.25 * fs, highF = 3.5 * fs;
      const targetMag = 1.0 / Math.SQRT2;
      for (let iter = 0; iter < 25; iter++) {
        const midF = (lowF + highF) / 2.0;
        if (evalVentedMag(midF) < targetMag) lowF = midF;
        else highF = midF;
      }
      const actualF3 = (lowF + highF) / 2.0;

      return {
        enclosureType: 'vented',
        vb: physicalVb,
        acousticVb: ventedAcousticVb,
        physicalCuFt,
        fc,
        fb,
        alpha,
        actualQtc,
        actualF3,
        portLengthCm,
        minPortDiameterCm: Math.max(parseFloat(dMin.toFixed(1)), 3.0),
        effectiveQts,
        qbVal,
        minFeasibleF3,
        warningMsg
      };
    }

    // Sealed Box 2nd-Order Calculations
    if (manualVbOverride) {
      baseAlpha = ts.vas / Math.max(manualVbLiters, 0.1);
    } else if (alignment === 'targetF3') {
      const minF3 = ts.fs * (0.70710678 / Math.max(effectiveQts, 0.01));
      const effectiveF3 = Math.max(targetF3, minF3);
      const r = Math.pow(effectiveF3 / Math.max(ts.fs, 1.0), 2);
      const q2 = Math.pow(effectiveQts, 2);
      const disc = 2.0 * r * r - (r / Math.max(q2, 1e-4));
      if (disc <= 0 || targetF3 < minF3) {
        const ratio = 0.70710678 / Math.max(effectiveQts, 0.01);
        baseAlpha = Math.max(Math.pow(ratio, 2) - 1.0, 0.05);
        if (targetF3 < minF3) {
          warningMsg = `Target f3 (${targetF3} Hz) is below the physical sealed-box limit (${minF3.toFixed(1)} Hz) for Qts = ${effectiveQts.toFixed(3)}. Enclosure aligned to Butterworth B2 (f3 = ${minF3.toFixed(1)} Hz). Switch to Vented (Bass-Reflex) mode to extend bass down to 35–45 Hz.`;
        }
      } else {
        const y = r + Math.sqrt(disc);
        baseAlpha = Math.max(y - 1.0, 0.05);
      }
    } else {
      let activeQtc = 0.7071;
      if (alignment === 'bessel') activeQtc = 0.5774;
      else if (alignment === 'critical') activeQtc = 0.500;
      else if (alignment === 'custom') activeQtc = customQtc;

      if (activeQtc <= effectiveQts) {
        warningMsg = `Target Qtc (${activeQtc.toFixed(3)}) is <= driver Qts (${effectiveQts.toFixed(3)}). A sealed enclosure cannot reduce driver Q. Minimum possible Qtc is ${effectiveQts.toFixed(3)}.`;
        baseAlpha = 0.05;
      } else {
        const ratio = activeQtc / effectiveQts;
        baseAlpha = Math.pow(ratio, 2) - 1.0;
      }
    }

    // Required acoustic volume Vb_acoustic and physical box volume Vb_physical
    const acousticVb = manualVbOverride ? (manualVbLiters * stuffingGain) : (ts.vas / baseAlpha);
    const physicalVb = manualVbOverride ? manualVbLiters : (acousticVb / stuffingGain);
    const physicalCuFt = physicalVb / 28.3168;

    const alpha = manualVbOverride ? (ts.vas / Math.max(acousticVb, 0.01)) : baseAlpha;

    // System resonance Fc inside box
    const fc = ts.fs * Math.sqrt(1 + alpha);

    // Target Qtc directly follows effectiveQts * sqrt(1 + alpha)
    const actualQtc = effectiveQts * Math.sqrt(1 + alpha);

    // Exact f3 formula for 2nd order closed box
    const B = (1.0 / Math.pow(actualQtc, 2)) - 2.0;
    const x = (B + Math.sqrt(B * B + 4.0)) / 2.0;
    const actualF3 = fc * Math.sqrt(x);

    return {
      enclosureType: 'sealed',
      vb: physicalVb,
      acousticVb,
      physicalCuFt,
      fc,
      fb: fc,
      alpha,
      actualQtc,
      actualF3,
      portLengthCm: 0,
      minPortDiameterCm: 0,
      effectiveQts,
      qbVal,
      minFeasibleF3,
      warningMsg
    };
  }, [ts, enclosureType, alignment, ventedAlignment, tuningFb, portDiameterCm, portCount, targetF3, customQtc, stuffingGain, manualVbOverride, manualVbLiters]);

  // --- Interpolate Raw Acoustic SPL from Digitized Curve Points ---
  function interpolateCurveSPL(freq, curve) {
    if (!curve || curve.length === 0) return null;
    if (freq <= curve[0].frequency) return curve[0].magnitude;
    if (freq >= curve[curve.length - 1].frequency) return curve[curve.length - 1].magnitude;
    for (let j = 0; j < curve.length - 1; j++) {
      const p1 = curve[j];
      const p2 = curve[j + 1];
      if (freq >= p1.frequency && freq <= p2.frequency) {
        const logF = Math.log10(freq);
        const logF1 = Math.log10(p1.frequency);
        const logF2 = Math.log10(p2.frequency);
        const t = (logF - logF1) / (logF2 - logF1);
        return p1.magnitude + t * (p2.magnitude - p1.magnitude);
      }
    }
    return curve[0].magnitude;
  }

  // --- Nelder-Mead All-Pass Filter Phase Alignment Optimizer ---
  const apfOptimization = useMemo(() => {
    const actualWooferFx = enableIndependentFx ? wooferFx : fx;
    const actualTweeterFx = enableIndependentFx ? tweeterFx : fx;
    const centerFx = Math.round(Math.sqrt(actualWooferFx * actualTweeterFx));

    if (!enableAllpass || acousticDelayMM <= 0) {
      return { f0: centerFx, q: 0.707, rmsErrorDeg: 0, isGoalAchieved: true, alignmentStatus: getPhaseAlignmentStatus(0), warnings: [] };
    }

    const fLow = Math.max(20.0, Math.min(actualWooferFx, actualTweeterFx) / 2.0);
    const fHigh = Math.min(20000.0, Math.max(actualWooferFx, actualTweeterFx) * 2.0);
    const sampleCount = 31;
    const freqs = [];
    const logLow = Math.log(fLow);
    const logHigh = Math.log(fHigh);
    const logStep = (logHigh - logLow) / (sampleCount - 1);
    for (let i = 0; i < sampleCount; i++) {
      freqs.push(Math.exp(logLow + i * logStep));
    }

    const speedOfSound = 343.0;
    const delaySec = (acousticDelayMM / 1000.0) / speedOfSound;
    const polarityMult = invertTweeterPolarity ? -1.0 : 1.0;
    const gLpad = (enableLPad && lpadAttenDB > 0) ? Math.pow(10, -lpadAttenDB / 20.0) : 1.0;

    const fc = cabinetCalculations.fc;
    const qtc = cabinetCalculations.actualQtc;
    const wc = 2.0 * Math.PI * fc;

    const pTweeterFixed = [];
    const pWooferBase = [];

    freqs.forEach(f => {
      const w = 2.0 * Math.PI * f;
      let pTweeterRawSPL = interpolateCurveSPL(f, tweeterCurve);
      if (pTweeterRawSPL === null) {
        pTweeterRawSPL = tweeter.spl;
        if (f < 1500) pTweeterRawSPL -= 18 * Math.log2(1500 / Math.max(f, 10));
      }
      const pTweeterRawComp = new Complex(Math.pow(10, pTweeterRawSPL / 20.0), 0);

      const xT = f / actualTweeterFx;
      let hHP = new Complex(1, 0);
      if (tweeterOrder === 'firstOrder') {
        hHP = new Complex(0, xT).div(new Complex(1, xT));
      } else if (tweeterOrder === 'secondOrderLR') {
        hHP = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, 2 * xT));
      } else if (tweeterOrder === 'secondOrderBW') {
        hHP = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, Math.SQRT2 * xT));
      } else if (tweeterOrder === 'fourthOrderLR') {
        const h2 = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, Math.SQRT2 * xT));
        hHP = h2.mul(h2);
      }
      const hDelay = Complex.polar(polarityMult, -w * delaySec);
      pTweeterFixed.push(pTweeterRawComp.mul(hHP).mul(gLpad).mul(hDelay));

      let pWooferRawSPL = interpolateCurveSPL(f, wooferCurve);
      if (pWooferRawSPL === null) {
        pWooferRawSPL = ts.spl;
        if (f < ts.fs) pWooferRawSPL -= 12 * Math.log2(ts.fs / Math.max(f, 10));
      }
      const pWooferRawComp = new Complex(Math.pow(10, pWooferRawSPL / 20.0), 0);

      const s = new Complex(0, w);
      const s2 = s.mul(s);
      const denomCab = s2.add(s.mul(wc / qtc)).add(wc * wc);
      const hCab = s2.div(denomCab);

      const xW = f / actualWooferFx;
      let hLP = new Complex(1, 0);
      if (wooferOrder === 'firstOrder') {
        hLP = new Complex(1, 0).div(new Complex(1, xW));
      } else if (wooferOrder === 'secondOrderLR') {
        hLP = new Complex(1, 0).div(new Complex(1 - xW * xW, 2 * xW));
      } else if (wooferOrder === 'secondOrderBW') {
        hLP = new Complex(1, 0).div(new Complex(1 - xW * xW, Math.SQRT2 * xW));
      } else if (wooferOrder === 'fourthOrderLR') {
        const h2 = new Complex(1, 0).div(new Complex(1 - xW * xW, Math.SQRT2 * xW));
        hLP = h2.mul(h2);
      }
      pWooferBase.push(pWooferRawComp.mul(hCab).mul(hLP));
    });

    function evalCost(f0, q) {
      if (f0 < 0.1 * centerFx || f0 > 10.0 * centerFx || q < 0.05 || q > 25.0) return 1e8;
      const deltas = [];
      for (let i = 0; i < sampleCount; i++) {
        const f = freqs[i];
        const x = f / f0;
        const num = new Complex(1.0 - x * x, -x / q);
        const denom = new Complex(1.0 - x * x, x / q);
        const hAP = num.div(denom);
        const pWooferFinal = pWooferBase[i].mul(hAP);
        deltas.push(pWooferFinal.phaseDeg - pTweeterFixed[i].phaseDeg);
      }
      for (let i = 1; i < sampleCount; i++) {
        while (deltas[i] - deltas[i - 1] > 180.0) deltas[i] -= 360.0;
        while (deltas[i] - deltas[i - 1] < -180.0) deltas[i] += 360.0;
      }
      const mean = deltas.reduce((a, b) => a + b, 0) / sampleCount;
      let sse = 0;
      for (let i = 0; i < sampleCount; i++) {
        const diff = deltas[i] - mean;
        sse += diff * diff;
      }
      return sse;
    }

    const tau = delaySec;
    const qInit = Math.max(0.5, Math.min(2.5, 2.0 / (2.0 * Math.PI * centerFx * Math.max(tau, 1e-6))));
    let simplex = [
      { f0: centerFx, q: qInit, cost: evalCost(centerFx, qInit) },
      { f0: centerFx * 1.2, q: qInit, cost: evalCost(centerFx * 1.2, qInit) },
      { f0: centerFx, q: qInit * 1.25, cost: evalCost(centerFx, qInit * 1.25) }
    ];

    for (let it = 0; it < 120; it++) {
      simplex.sort((a, b) => a.cost - b.cost);
      if (Math.abs(simplex[2].cost - simplex[0].cost) < 1e-5) break;
      const cF0 = (simplex[0].f0 + simplex[1].f0) / 2.0;
      const cQ = (simplex[0].q + simplex[1].q) / 2.0;

      const xrF0 = cF0 + (cF0 - simplex[2].f0);
      const xrQ = cQ + (cQ - simplex[2].q);
      const xrCost = evalCost(xrF0, xrQ);

      if (xrCost < simplex[1].cost && xrCost >= simplex[0].cost) {
        simplex[2] = { f0: xrF0, q: xrQ, cost: xrCost };
        continue;
      }
      if (xrCost < simplex[0].cost) {
        const xeF0 = cF0 + 2.0 * (xrF0 - cF0);
        const xeQ = cQ + 2.0 * (xrQ - cQ);
        const xeCost = evalCost(xeF0, xeQ);
        simplex[2] = xeCost < xrCost ? { f0: xeF0, q: xeQ, cost: xeCost } : { f0: xrF0, q: xrQ, cost: xrCost };
        continue;
      }
      if (xrCost < simplex[2].cost) {
        const xcF0 = cF0 + 0.5 * (xrF0 - cF0);
        const xcQ = cQ + 0.5 * (xrQ - cQ);
        const xcCost = evalCost(xcF0, xcQ);
        if (xcCost < xrCost) {
          simplex[2] = { f0: xcF0, q: xcQ, cost: xcCost };
          continue;
        }
      } else {
        const xcF0 = cF0 - 0.5 * (cF0 - simplex[2].f0);
        const xcQ = cQ - 0.5 * (cQ - simplex[2].q);
        const xcCost = evalCost(xcF0, xcQ);
        if (xcCost < simplex[2].cost) {
          simplex[2] = { f0: xcF0, q: xcQ, cost: xcCost };
          continue;
        }
      }
      for (let i = 1; i <= 2; i++) {
        const sf0 = simplex[0].f0 + 0.5 * (simplex[i].f0 - simplex[0].f0);
        const sq = simplex[0].q + 0.5 * (simplex[i].q - simplex[0].q);
        simplex[i] = { f0: sf0, q: sq, cost: evalCost(sf0, sq) };
      }
    }

    simplex.sort((a, b) => a.cost - b.cost);
    const opt = simplex[0];
    const rmsErrorDeg = Math.sqrt(opt.cost / sampleCount);
    const alignmentStatus = getPhaseAlignmentStatus(rmsErrorDeg);
    const isGoalAchieved = rmsErrorDeg <= 10.0;

    const warnings = [];
    if (!enableZobel) {
      warnings.push('All-Pass Filter Warning: Zobel network is disabled. All-pass filter requires resistive woofer termination to prevent inductive detuning.');
    }

    return {
      f0: opt.f0,
      q: opt.q,
      rmsErrorDeg,
      isGoalAchieved,
      alignmentStatus,
      warnings
    };
  }, [enableAllpass, acousticDelayMM, fx, enableIndependentFx, wooferFx, tweeterFx, wooferOrder, tweeterOrder, enableLPad, lpadAttenDB, invertTweeterPolarity, cabinetCalculations, ts, tweeter, enableZobel, wooferCurve, tweeterCurve]);

  // --- Passive Crossover Component Calculations ---
  const crossoverComponents = useMemo(() => {
    const actualWooferFx = enableIndependentFx ? wooferFx : fx;
    const actualTweeterFx = enableIndependentFx ? tweeterFx : fx;
    const wW = 2.0 * Math.PI * actualWooferFx;
    const wT = 2.0 * Math.PI * actualTweeterFx;
    const Zw = Math.max(ts.re, 4.0);
    const Zt = Math.max(tweeter.re, 4.0);

    let comp = {
      L1: null, C1: null, L2: null, C2: null,
      C_HP1: null, L_HP1: null, C_HP2: null, L_HP2: null,
      R_zobel: null, C_zobel: null,
      R1_lpad: null, R2_lpad: null,
      L_AP: null, C_AP: null
    };

    // Woofer Low-Pass
    if (wooferOrder === 'firstOrder') {
      comp.L1 = (Zw / wW) * 1000.0;
    } else if (wooferOrder === 'secondOrderLR') {
      comp.L1 = (Zw / (wW * Math.PI)) * 1000.0 * 2.0;
      comp.C1 = (1.0 / (2.0 * Math.PI * actualWooferFx * Zw)) * 1e6;
    } else if (wooferOrder === 'secondOrderBW') {
      comp.L1 = ((Math.SQRT2 * Zw) / wW) * 1000.0;
      comp.C1 = (1.0 / (Math.SQRT2 * wW * Zw)) * 1e6;
    } else if (wooferOrder === 'fourthOrderLR') {
      comp.L1 = ((1.2 * Zw) / wW) * 1000.0;
      comp.C1 = (0.33 / (wW * Zw)) * 1e6;
      comp.L2 = ((0.4 * Zw) / wW) * 1000.0;
      comp.C2 = (0.75 / (wW * Zw)) * 1e6;
    }

    // Tweeter High-Pass
    if (tweeterOrder === 'firstOrder') {
      comp.C_HP1 = (1.0 / (wT * Zt)) * 1e6;
    } else if (tweeterOrder === 'secondOrderLR') {
      comp.C_HP1 = (1.0 / (wT * Zt)) * 1e6;
      comp.L_HP1 = (Zt / wT) * 1000.0;
    } else if (tweeterOrder === 'secondOrderBW') {
      comp.C_HP1 = (1.0 / (Math.SQRT2 * wT * Zt)) * 1e6;
      comp.L_HP1 = ((Math.SQRT2 * Zt) / wT) * 1000.0;
    } else if (tweeterOrder === 'fourthOrderLR') {
      comp.C_HP1 = (1.0 / (1.2 * wT * Zt)) * 1e6;
      comp.L_HP1 = (Zt / (0.33 * wT)) * 1000.0;
      comp.C_HP2 = (1.0 / (0.4 * wT * Zt)) * 1e6;
      comp.L_HP2 = (Zt / (0.75 * wT)) * 1000.0;
    }

    // Zobel
    if (enableZobel && ts.le > 0) {
      const rz = 1.25 * ts.re;
      const czF = (ts.le / 1000.0) / (rz * rz);
      comp.R_zobel = rz;
      comp.C_zobel = czF * 1e6;
    }

    // L-Pad
    if (enableLPad && lpadAttenDB > 0) {
      const k = Math.pow(10, -lpadAttenDB / 20.0);
      if (k < 1.0) {
        comp.R1_lpad = Zt * (1.0 - k);
        comp.R2_lpad = Zt * (k / (1.0 - k));
      }
    }

    // All-Pass Delay Compensation Network (using Nelder-Mead optimized F0 & Q)
    if (enableAllpass && acousticDelayMM > 0) {
      const f0 = apfOptimization.f0 || Math.round(Math.sqrt(actualWooferFx * actualTweeterFx));
      const qAP = apfOptimization.q || 0.707;
      const w0 = 2.0 * Math.PI * f0;
      comp.L_AP = (Zw / (w0 * qAP)) * 1000.0;
      comp.C_AP = (1.0 / (w0 * qAP * Zw)) * 1e6;
    }

    // Snap if requested (E24 or E12)
    if (snapToE24) {
      for (const key of Object.keys(comp)) {
        if (comp[key]) comp[key] = snapE24(comp[key]);
      }
    } else if (snapToE12) {
      for (const key of Object.keys(comp)) {
        if (comp[key]) comp[key] = snapE12(comp[key]);
      }
    }

    return comp;
  }, [fx, enableIndependentFx, wooferFx, tweeterFx, wooferOrder, tweeterOrder, enableZobel, enableLPad, lpadAttenDB, snapToE12, snapToE24, ts, tweeter, enableAllpass, acousticDelayMM, apfOptimization]);

  // --- Complete Simulation Engine Calculations ---
  const simulationData = useMemo(() => {
    const points = [];
    const minF = 20.0;
    const maxF = 20000.0;
    const logMin = Math.log10(minF);
    const logMax = Math.log10(maxF);
    const steps = 200;

    const fc = cabinetCalculations.fc;
    const qtc = cabinetCalculations.actualQtc;
    const wc = 2.0 * Math.PI * fc;
    const speedOfSound = 343.0; // m/s
    const delaySec = (acousticDelayMM / 1000.0) / speedOfSound;
    const lpadGain = (enableLPad && lpadAttenDB > 0) ? Math.pow(10, -lpadAttenDB / 20.0) : 1.0;
    const polarityMult = invertTweeterPolarity ? -1.0 : 1.0;
    const actualWooferFx = enableIndependentFx ? wooferFx : fx;
    const actualTweeterFx = enableIndependentFx ? tweeterFx : fx;

    for (let i = 0; i <= steps; i++) {
      const logF = logMin + (i / steps) * (logMax - logMin);
      const f = Math.pow(10, logF);
      const w = 2.0 * Math.PI * f;

      // 1. Raw Woofer Passband SPL & Sealed Cabinet Transfer Function H_cab(s)
      let pWooferRawSPL = interpolateCurveSPL(f, wooferCurve);
      if (pWooferRawSPL === null) {
        pWooferRawSPL = ts.spl;
        if (f > 2200) pWooferRawSPL -= 0.003 * (f - 2200);
      }

      const pWooferRawLinear = Math.pow(10, pWooferRawSPL / 20.0);
      const pWooferRawComp = new Complex(pWooferRawLinear, 0);

      // Cabinet H_cab(s)
      let hCab;
      if (cabinetCalculations.enclosureType === 'vented') {
        const fs = Math.max(ts.fs, 1.0);
        const fb = cabinetCalculations.fb;
        const fn = f / fs;
        const h = fb / fs;
        const ql = 15.0;
        const qts = Math.max(cabinetCalculations.effectiveQts, 0.05);
        const alpha = Math.max(cabinetCalculations.alpha, 0.01);
        const c0 = h * h;
        const c1 = (h * h) / qts + h / ql;
        const c2 = 1.0 + h * h + alpha + h / (qts * ql);
        const c3 = 1.0 / qts + h / ql;
        const reD = Math.pow(fn, 4) - c2 * Math.pow(fn, 2) + c0;
        const imD = -c3 * Math.pow(fn, 3) + c1 * fn;
        const denCab = new Complex(reD, imD);
        const numCab = new Complex(Math.pow(fn, 4), 0);
        hCab = numCab.div(denCab);
      } else {
        // Sealed box H_cab(s) = s^2 / (s^2 + (wc/Qtc)s + wc^2)
        const numCab = new Complex(-w * w, 0);
        const denCab = new Complex(wc * wc - w * w, (w * wc) / qtc);
        hCab = numCab.div(denCab);
      }

      const pWooferCab = pWooferRawComp.mul(hCab);

      // Woofer Low-Pass Electrical Filter H_LP
      const xW = f / actualWooferFx;
      let hLP = new Complex(1, 0);
      if (wooferOrder === 'firstOrder') {
        hLP = new Complex(1, 0).div(new Complex(1, xW));
      } else if (wooferOrder === 'secondOrderLR') {
        hLP = new Complex(1, 0).div(new Complex(1 - xW * xW, 2 * xW));
      } else if (wooferOrder === 'secondOrderBW') {
        hLP = new Complex(1, 0).div(new Complex(1 - xW * xW, Math.SQRT2 * xW));
      } else if (wooferOrder === 'fourthOrderLR') {
        const h2 = new Complex(1, 0).div(new Complex(1 - xW * xW, Math.SQRT2 * xW));
        hLP = h2.mul(h2);
      }

      // Woofer All-Pass Delay Compensation Network H_AP
      let hAP = new Complex(1, 0);
      if (enableAllpass && acousticDelayMM > 0) {
        const f0 = apfOptimization.f0 || Math.round(Math.sqrt(actualWooferFx * actualTweeterFx));
        const qAP = apfOptimization.q || 0.707;
        const xAP = f / f0;
        const num = new Complex(1.0 - xAP * xAP, -xAP / qAP);
        const denom = new Complex(1.0 - xAP * xAP, xAP / qAP);
        hAP = num.div(denom);
      }

      const pWooferFinal = (pWooferCab.mul(hLP)).mul(hAP);

      // 2. Raw Tweeter SPL & High-Pass Electrical Filter
      let pTweeterRawSPL = interpolateCurveSPL(f, tweeterCurve);
      if (pTweeterRawSPL === null) {
        pTweeterRawSPL = tweeter.spl;
        if (f < 1500) pTweeterRawSPL -= 18 * Math.log2(1500 / Math.max(f, 10));
      }
      const pTweeterRawComp = new Complex(Math.pow(10, pTweeterRawSPL / 20.0), 0);

      const xT = f / actualTweeterFx;
      let hHP = new Complex(1, 0);
      if (tweeterOrder === 'firstOrder') {
        hHP = new Complex(0, xT).div(new Complex(1, xT));
      } else if (tweeterOrder === 'secondOrderLR') {
        hHP = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, 2 * xT));
      } else if (tweeterOrder === 'secondOrderBW') {
        hHP = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, Math.SQRT2 * xT));
      } else if (tweeterOrder === 'fourthOrderLR') {
        const h2 = new Complex(-xT * xT, 0).div(new Complex(1 - xT * xT, Math.SQRT2 * xT));
        hHP = h2.mul(h2);
      }

      const hDelay = Complex.polar(polarityMult, -w * delaySec);
      const pTweeterFinal = pTweeterRawComp.mul(hHP).mul(lpadGain).mul(hDelay);
      const pTweeterDelayComp = pTweeterRawComp.mul(hHP).mul(lpadGain).scale(polarityMult);

      // 3. Acoustic Summation
      const pTotal = pWooferFinal.add(pTweeterFinal);

      const wooferFinalSPL = 20.0 * Math.log10(Math.max(pWooferFinal.mag, 1e-6));
      const tweeterFinalSPL = 20.0 * Math.log10(Math.max(pTweeterFinal.mag, 1e-6));
      const totalSPL = 20.0 * Math.log10(Math.max(pTotal.mag, 1e-6));

      const wooferPhase = pWooferFinal.phaseDeg;
      const tweeterPhase = pTweeterFinal.phaseDeg;
      const tweeterDelayCompPhase = pTweeterDelayComp.phaseDeg;
      const totalPhase = pTotal.phaseDeg;
      let deltaPhase = Math.abs(wooferPhase - tweeterPhase) % 360;
      if (deltaPhase > 180) deltaPhase = 360 - deltaPhase;

      // 4. Electrical Load Impedance
      const reW = ts.re;
      const leW = ts.le / 1000.0;
      let zWooferRaw;

      if (cabinetCalculations.enclosureType === 'vented') {
        const fs = Math.max(ts.fs, 1.0);
        const qms = Math.max(ts.qms, 0.5);
        const qes = Math.max(ts.qes, 0.05);
        const fb = cabinetCalculations.fb;
        const h = fb / fs;
        const ql = 15.0;
        const alpha = Math.max(cabinetCalculations.alpha, 0.01);
        const res = reW * (qms / qes);
        const fn = Math.max(f / fs, 1e-4);

        const sn = new Complex(0, fn);
        const denPort = sn.add(new Complex(h / ql, 0));
        const zPort = new Complex(h * h, 0).div(denPort);
        const denCab = sn.add(zPort);
        const zCab = new Complex(alpha, 0).div(denCab);

        const invSn = new Complex(1, 0).div(sn);
        const zMech = new Complex(1 / qms, 0).add(sn).add(invSn).add(zCab);
        const zMotional = new Complex(res / qms, 0).div(zMech);
        zWooferRaw = new Complex(reW, w * leW).add(zMotional);
      } else {
        const qb = cabinetCalculations.qbVal;
        const effectiveQms = ts.qms > 0 ? ts.qms : 4.5;
        const qmsBox = effectiveQms * Math.sqrt(1 + cabinetCalculations.alpha);
        const qmc = (qmsBox * qb) / (qmsBox + qb);
        const resW = reW * (effectiveQms / Math.max(ts.qes, 0.01)) * (qb / (qmsBox + qb));
        const deltaF = (f / fc) - (fc / f);
        const denomMotional = 1.0 + Math.pow(qmc * deltaF, 2);
        const rMotional = resW / denomMotional;
        const xMotional = -resW * (qmc * deltaF) / denomMotional;
        zWooferRaw = new Complex(reW + rMotional, w * leW + xMotional);
      }

      let zWooferVoiceCoil = zWooferRaw;
      if (enableZobel) {
        const rz = 1.25 * reW;
        const czF = (ts.le / 1000.0) / (rz * rz);
        const zZobel = new Complex(rz, -1.0 / (w * czF));
        zWooferVoiceCoil = (zWooferVoiceCoil.mul(zZobel)).div(zWooferVoiceCoil.add(zZobel));
      }

      // Woofer Low-Pass Input Impedance
      let zWooferInput = zWooferVoiceCoil;
      if (crossoverComponents.L1 && crossoverComponents.C1) {
        const zL1 = new Complex(0.05, w * (crossoverComponents.L1 / 1000.0));
        const zC1 = new Complex(0.0, -1.0 / (w * (crossoverComponents.C1 / 1e6)));
        const zParallel = (zWooferVoiceCoil.mul(zC1)).div(zWooferVoiceCoil.add(zC1));
        zWooferInput = zL1.add(zParallel);
      } else if (crossoverComponents.L1) {
        const zL1 = new Complex(0.05, w * (crossoverComponents.L1 / 1000.0));
        zWooferInput = zL1.add(zWooferVoiceCoil);
      }

      // Tweeter High-Pass Input Impedance
      const fsTw = tweeter.fs;
      const qmsTw = 3.5;
      const resTw = tweeter.re * 1.8;
      const deltaFTw = (f / fsTw) - (fsTw / f);
      const denomTw = 1.0 + Math.pow(qmsTw * deltaFTw, 2);
      const rMotionalTw = resTw / denomTw;
      const xMotionalTw = -resTw * (qmsTw * deltaFTw) / denomTw;

      const zTweeterRaw = new Complex(tweeter.re + rMotionalTw, w * (tweeter.le / 1000.0) + xMotionalTw);
      let zTweeterVoiceCoil = zTweeterRaw;

      if (enableLPad && lpadAttenDB > 0) {
        const k = Math.pow(10, -lpadAttenDB / 20.0);
        if (k < 1.0) {
          const r1 = 8.0 * (1.0 - k);
          const r2 = 8.0 * (k / (1.0 - k));
          const zR2 = new Complex(r2, 0);
          const zParallel = (zTweeterVoiceCoil.mul(zR2)).div(zTweeterVoiceCoil.add(zR2));
          zTweeterVoiceCoil = new Complex(r1, 0).add(zParallel);
        }
      }

      let zTweeterInput = zTweeterVoiceCoil;
      if (crossoverComponents.C_HP1 && crossoverComponents.L_HP1) {
        const zC1 = new Complex(0.0, -1.0 / (w * (crossoverComponents.C_HP1 / 1e6)));
        const zL1 = new Complex(0.05, w * (crossoverComponents.L_HP1 / 1000.0));
        const zParallel = (zTweeterVoiceCoil.mul(zL1)).div(zTweeterVoiceCoil.add(zL1));
        zTweeterInput = zC1.add(zParallel);
      } else if (crossoverComponents.C_HP1) {
        const zC1 = new Complex(0.0, -1.0 / (w * (crossoverComponents.C_HP1 / 1e6)));
        zTweeterInput = zC1.add(zTweeterVoiceCoil);
      }

      const zTotal = (zWooferInput.mul(zTweeterInput)).div(zWooferInput.add(zTweeterInput));

      points.push({
        frequency: f,
        wooferFinalSPL,
        tweeterFinalSPL,
        totalSPL,
        wooferPhase,
        tweeterPhase,
        totalPhase,
        deltaPhase,
        tweeterDelayCompPhase,
        zWooferMag: zWooferVoiceCoil.mag,
        zTweeterMag: zTweeterRaw.mag,
        zTotalMag: zTotal.mag
      });
    }

    function unwrapPhaseArray(phases) {
      if (!phases || phases.length === 0) return [];
      const unwrapped = [...phases];
      for (let i = 1; i < unwrapped.length; i++) {
        let diff = unwrapped[i] - unwrapped[i - 1];
        while (diff > 180) diff -= 360;
        while (diff < -180) diff += 360;
        unwrapped[i] = unwrapped[i - 1] + diff;
      }
      return unwrapped;
    }

    const freqs = points.map(p => p.frequency);
    const wooferUnwrapped = unwrapPhaseArray(points.map(p => p.wooferPhase));
    const tweeterUnwrapped = unwrapPhaseArray(points.map(p => p.tweeterPhase));
    const totalUnwrapped = unwrapPhaseArray(points.map(p => p.totalPhase));

    function computeGDArray(frequencies, unwrappedPhases) {
      const n = frequencies.length;
      if (!frequencies || n === 0) return [];
      const gd = new Float64Array(n);
      const scale = -1000.0 / 360.0;
      for (let i = 0; i < n; i++) {
        let dPhiDf;
        if (i === 0) {
          const df = frequencies[1] - frequencies[0];
          dPhiDf = df !== 0 ? (unwrappedPhases[1] - unwrappedPhases[0]) / df : 0;
        } else if (i === n - 1) {
          const df = frequencies[n - 1] - frequencies[n - 2];
          dPhiDf = df !== 0 ? (unwrappedPhases[n - 1] - unwrappedPhases[n - 2]) / df : 0;
        } else {
          const df = frequencies[i + 1] - frequencies[i - 1];
          dPhiDf = df !== 0 ? (unwrappedPhases[i + 1] - unwrappedPhases[i - 1]) / df : 0;
        }
        gd[i] = scale * dPhiDf;
      }
      return gd;
    }

    const wooferGD = computeGDArray(freqs, wooferUnwrapped);
    const tweeterGD = computeGDArray(freqs, tweeterUnwrapped);
    const totalGD = computeGDArray(freqs, totalUnwrapped);

    for (let i = 0; i < points.length; i++) {
      points[i].wooferUnwrappedPhase = wooferUnwrapped[i];
      points[i].tweeterUnwrappedPhase = tweeterUnwrapped[i];
      points[i].totalUnwrappedPhase = totalUnwrapped[i];
      points[i].wooferGD = wooferGD[i];
      points[i].tweeterGD = tweeterGD[i];
      points[i].totalGD = totalGD[i];
    }

    return points;
  }, [ts, tweeter, cabinetCalculations, fx, enableIndependentFx, wooferFx, tweeterFx, wooferOrder, tweeterOrder, enableZobel, enableLPad, lpadAttenDB, acousticDelayMM, invertTweeterPolarity, enableAllpass, apfOptimization, wooferCurve, tweeterCurve]);

  // --- Render Bode Amplitude Plot ---
  useEffect(() => {
    if (simulationData.length === 0) return;
    const renderAmplitudeToCanvas = (canvas) => {
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;

      ctx.clearRect(0, 0, width, height);

      const minF = 20.0;
      const maxF = 20000.0;
      const logMin = Math.log10(minF);
      const logMax = Math.log10(maxF);
      const minSPL = 40.0;
      const maxSPL = 110.0;

      // Gridlines
      const freqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
      ctx.lineWidth = 1;
      ctx.fillStyle = '#94a3b8';
      ctx.font = '10px sans-serif';

      freqs.forEach(f => {
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
        const label = f >= 1000 ? `${f / 1000}k` : `${f}`;
        const textX = f === 20000 ? x - 26 : x + 4;
        ctx.fillText(label, textX, height - 8);
      });

      for (let spl = minSPL; spl <= maxSPL; spl += 10) {
        const y = height * (1 - (spl - minSPL) / (maxSPL - minSPL));
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
        if (spl > minSPL) {
          const textY = y <= 2 ? 12 : y - 4;
          ctx.fillText(`${spl} dB`, 8, textY);
        }
      }

      function toCanvas(f, spl) {
        const clampedSPL = Math.max(Math.min(spl, maxSPL), minSPL);
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        const y = height * (1 - (clampedSPL - minSPL) / (maxSPL - minSPL));
        return [x, y];
      }

      // Woofer Curve (Blue)
      if (showWoofer) {
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 2;
        ctx.beginPath();
        simulationData.forEach((p, i) => {
          const [x, y] = toCanvas(p.frequency, p.wooferFinalSPL);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }

      // Tweeter Curve (Red)
      if (showTweeter) {
        ctx.strokeStyle = '#ef4444';
        ctx.lineWidth = 2;
        ctx.beginPath();
        simulationData.forEach((p, i) => {
          const [x, y] = toCanvas(p.frequency, p.tweeterFinalSPL);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }

      // Summed Total Curve (Green)
      if (showTotalSystem) {
        ctx.strokeStyle = '#22c55e';
        ctx.lineWidth = 3;
        ctx.beginPath();
        simulationData.forEach((p, i) => {
          const [x, y] = toCanvas(p.frequency, p.totalSPL);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }
    };

    renderAmplitudeToCanvas(amplitudeCanvasRef.current);
    renderAmplitudeToCanvas(detachedAmplitudeCanvasRef.current);
  }, [simulationData, activeTab, detachedPlots, showWoofer, showTweeter, showTotalSystem]);

  // --- Render Bode Phase Plot ---
  useEffect(() => {
    if (simulationData.length === 0) return;
    const renderPhaseToCanvas = (canvas) => {
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;

      ctx.clearRect(0, 0, width, height);

      const minF = 20.0;
      const maxF = 20000.0;
      const logMin = Math.log10(minF);
      const logMax = Math.log10(maxF);

      // Determine phase range (unwrap vs wrapped)
      let minDeg = -180.0;
      let maxDeg = 180.0;
      if (unwrapPhase) {
        let minVal = 0.0, maxVal = 180.0;
        simulationData.forEach(p => {
          if (showWoofer && Number.isFinite(p.wooferUnwrappedPhase)) {
            minVal = Math.min(minVal, p.wooferUnwrappedPhase);
            maxVal = Math.max(maxVal, p.wooferUnwrappedPhase);
          }
          if (showTweeter) {
            const twP = compensateTweeterDelay ? p.tweeterDelayCompPhase : p.tweeterUnwrappedPhase;
            if (Number.isFinite(twP)) {
              minVal = Math.min(minVal, twP);
              maxVal = Math.max(maxVal, twP);
            }
          }
          if (showTotalSystem && Number.isFinite(p.totalUnwrappedPhase)) {
            minVal = Math.min(minVal, p.totalUnwrappedPhase);
            maxVal = Math.max(maxVal, p.totalUnwrappedPhase);
          }
        });
        minDeg = Math.min(-180, Math.floor((minVal - 15) / 90) * 90);
        maxDeg = Math.max(180, Math.ceil((maxVal + 15) / 90) * 90);
      }
      const spanDeg = maxDeg - minDeg;

      // Gridlines for frequency
      const freqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
      ctx.lineWidth = 1;
      ctx.fillStyle = '#94a3b8';
      ctx.font = '10px sans-serif';

      // Crossover highlight band [fx/2, 2*fx]
      const f1 = Math.max(minF, fx / 2.0);
      const f2 = Math.min(maxF, fx * 2.0);
      const x1 = width * ((Math.log10(f1) - logMin) / (logMax - logMin));
      const x2 = width * ((Math.log10(f2) - logMin) / (logMax - logMin));
      ctx.fillStyle = 'rgba(20, 184, 166, 0.08)';
      ctx.fillRect(x1, 0, x2 - x1, height);

      ctx.fillStyle = '#94a3b8';
      freqs.forEach(f => {
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
        const label = f >= 1000 ? `${f / 1000}k` : `${f}`;
        const textX = f === 20000 ? x - 26 : x + 4;
        ctx.fillText(label, textX, height - 8);
      });

      const stepDeg = spanDeg > 540 ? 180 : (spanDeg > 360 ? 90 : 45);
      for (let d = minDeg; d <= maxDeg + 0.1; d += stepDeg) {
        const y = height * (1 - (d - minDeg) / spanDeg);
        ctx.strokeStyle = Math.abs(d) < 0.01 ? 'rgba(255, 255, 255, 0.35)' : 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = Math.abs(d) < 0.01 ? 1.5 : 1;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
        if (d > minDeg + 0.01) {
          const textY = y <= 2 ? 12 : y - 4;
          ctx.fillText(`${Math.round(d)}°`, 8, textY);
        }
      }

      function toCanvas(f, deg) {
        const clamped = Math.max(Math.min(deg, maxDeg), minDeg);
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        const y = height * (1 - (clamped - minDeg) / spanDeg);
        return [x, y];
      }

      function drawCurve(dataKey, color, lineWidth = 2, isDashed = false) {
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        if (isDashed) ctx.setLineDash([4, 4]);
        else ctx.setLineDash([]);
        ctx.beginPath();
        let started = false;
        let prevDeg = 0;

        simulationData.forEach(p => {
          const deg = p[dataKey];
          if (deg === undefined || !Number.isFinite(deg)) return;
          const [x, y] = toCanvas(p.frequency, deg);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else if (!unwrapPhase && Math.abs(deg - prevDeg) > 170) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
          prevDeg = deg;
        });
        ctx.stroke();
        ctx.setLineDash([]);
      }

      if (showWoofer) {
        drawCurve(unwrapPhase ? 'wooferUnwrappedPhase' : 'wooferPhase', '#3b82f6', 2);
      }
      if (showTweeter) {
        const twKey = compensateTweeterDelay ? 'tweeterDelayCompPhase' : (unwrapPhase ? 'tweeterUnwrappedPhase' : 'tweeterPhase');
        drawCurve(twKey, '#ef4444', 2);
      }
      if (showPhaseDiff) {
        drawCurve('deltaPhase', '#f97316', 1.5, true);
      }
      if (showTotalSystem) {
        drawCurve(unwrapPhase ? 'totalUnwrappedPhase' : 'totalPhase', '#22c55e', 2.5);
      }
    };

    renderPhaseToCanvas(phaseCanvasRef.current);
    renderPhaseToCanvas(detachedPhaseCanvasRef.current);
  }, [simulationData, activeTab, detachedPlots, showWoofer, showTweeter, showTotalSystem, showPhaseDiff, unwrapPhase, compensateTweeterDelay, fx]);

  // --- Render Group Delay Plot ---
  useEffect(() => {
    if (simulationData.length === 0) return;
    const renderGDToCanvas = (canvas) => {
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;

      ctx.clearRect(0, 0, width, height);

      const minF = 20.0;
      const maxF = 20000.0;
      const logMin = Math.log10(minF);
      const logMax = Math.log10(maxF);

      let maxObserved = -Infinity;
      let minObserved = Infinity;
      simulationData.forEach(p => {
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
      });

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
      const spanMs = Math.max(maxMs - minMs, 0.1);

      // Gridlines for frequency
      const freqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
      ctx.lineWidth = 1;
      ctx.fillStyle = '#94a3b8';
      ctx.font = '10px sans-serif';

      // Crossover highlight band [fx/2, 2*fx]
      const f1 = Math.max(minF, fx / 2.0);
      const f2 = Math.min(maxF, fx * 2.0);
      const x1 = width * ((Math.log10(f1) - logMin) / (logMax - logMin));
      const x2 = width * ((Math.log10(f2) - logMin) / (logMax - logMin));
      ctx.fillStyle = 'rgba(20, 184, 166, 0.08)';
      ctx.fillRect(x1, 0, x2 - x1, height);

      ctx.fillStyle = '#94a3b8';
      freqs.forEach(f => {
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
        const label = f >= 1000 ? `${f / 1000}k` : `${f}`;
        const textX = f === 20000 ? x - 26 : x + 4;
        ctx.fillText(label, textX, height - 8);
      });

      for (let ms = minMs; ms <= maxMs + 0.001; ms += stepMs) {
        const y = height * (1 - (ms - minMs) / spanMs);
        ctx.strokeStyle = Math.abs(ms) < 0.01 ? 'rgba(255, 255, 255, 0.35)' : 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = Math.abs(ms) < 0.01 ? 1.5 : 1;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
        if (ms > minMs + 0.001) {
          const textY = y <= 2 ? 12 : y - 4;
          const labelStr = stepMs < 1.0 ? `${ms.toFixed(1)} ms` : `${Math.round(ms)} ms`;
          ctx.fillText(labelStr, 8, textY);
        }
      }

      function toCanvas(f, ms) {
        const clamped = Math.max(Math.min(ms, maxMs), minMs);
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        const y = height * (1 - (clamped - minMs) / spanMs);
        return [x, y];
      }

      function drawGDCurve(dataKey, color, lineWidth = 2) {
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.beginPath();
        let started = false;
        simulationData.forEach(p => {
          const ms = p[dataKey];
          if (ms === undefined || !Number.isFinite(ms)) return;
          const [x, y] = toCanvas(p.frequency, ms);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        });
        ctx.stroke();
      }

      if (showWoofer) drawGDCurve('wooferGD', '#3b82f6', 2);
      if (showTweeter) drawGDCurve('tweeterGD', '#ef4444', 2);
      if (showTotalSystem) drawGDCurve('totalGD', '#22c55e', 2.5);
    };

    renderGDToCanvas(groupDelayCanvasRef.current);
    renderGDToCanvas(detachedGroupDelayCanvasRef.current);
  }, [simulationData, activeTab, detachedPlots, showWoofer, showTweeter, showTotalSystem, fx]);

  // --- Render System Electrical Load Impedance Plot ---
  useEffect(() => {
    if (simulationData.length === 0) return;
    const renderImpedanceToCanvas = (canvas) => {
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;

      ctx.clearRect(0, 0, width, height);

      const minF = 20.0;
      const maxF = 20000.0;
      const logMin = Math.log10(minF);
      const logMax = Math.log10(maxF);

      // Auto-scale Impedance Y-axis to maximize vertical resolution
      let maxObservedZ = 0.0;
      simulationData.forEach(p => {
        if (showWoofer && Number.isFinite(p.zWooferMag)) {
          maxObservedZ = Math.max(maxObservedZ, p.zWooferMag);
        }
        if (showTweeter && Number.isFinite(p.zTweeterMag)) {
          maxObservedZ = Math.max(maxObservedZ, p.zTweeterMag);
        }
        if (showTotalSystem && Number.isFinite(p.zTotalMag)) {
          maxObservedZ = Math.max(maxObservedZ, p.zTotalMag);
        }
      });

      const targetMaxZ = maxObservedZ > 0 ? Math.max(8.0, maxObservedZ * 1.08) : 50.0;
      let stepZ = 10.0;
      if (targetMaxZ <= 16.0) stepZ = 2.0;
      else if (targetMaxZ <= 45.0) stepZ = 5.0;
      else if (targetMaxZ <= 120.0) stepZ = 10.0;
      else stepZ = 20.0;
      const maxZ = Math.ceil(targetMaxZ / stepZ) * stepZ;

      // Crossover handover band highlight
      const actualWooferFx = enableIndependentFx ? wooferFx : fx;
      const actualTweeterFx = enableIndependentFx ? tweeterFx : fx;
      const f1 = Math.max(minF, Math.min(actualWooferFx, actualTweeterFx) / 2.0);
      const f2 = Math.min(maxF, Math.max(actualWooferFx, actualTweeterFx) * 2.0);
      const x1 = width * ((Math.log10(f1) - logMin) / (logMax - logMin));
      const x2 = width * ((Math.log10(f2) - logMin) / (logMax - logMin));
      ctx.fillStyle = 'rgba(20, 184, 166, 0.08)';
      ctx.fillRect(x1, 0, x2 - x1, height);

      // Vertical Frequency Gridlines
      const freqs = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
      ctx.lineWidth = 1;
      ctx.fillStyle = '#94a3b8';
      ctx.font = '10px sans-serif';

      freqs.forEach(f => {
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();
        const label = f >= 1000 ? `${f / 1000}k` : `${f}`;
        const textX = f === 20000 ? x - 26 : x + 4;
        ctx.fillText(label, textX, height - 8);
      });

      // Auto-scaled Horizontal Impedance Gridlines
      for (let z = 0; z <= maxZ + 0.01; z += stepZ) {
        const y = height * (1 - z / maxZ);
        ctx.strokeStyle = z === 0 ? 'rgba(255, 255, 255, 0.35)' : 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = z === 0 ? 1.5 : 1;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
        if (z > 0.01) {
          const textY = y <= 2 ? 12 : y - 4;
          ctx.fillText(`${Math.round(z)} Ω`, 8, textY);
        }
      }

      function toCanvas(f, zVal) {
        const clamped = Math.max(Math.min(zVal, maxZ), 0.0);
        const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
        const y = height * (1 - clamped / maxZ);
        return [x, y];
      }

      function drawZCurve(dataKey, color, lineWidth = 2) {
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.beginPath();
        let started = false;
        simulationData.forEach(p => {
          const val = p[dataKey];
          if (val === undefined || !Number.isFinite(val)) return;
          const [x, y] = toCanvas(p.frequency, val);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        });
        ctx.stroke();
      }

      if (showWoofer) drawZCurve('zWooferMag', '#3b82f6', 1.8);
      if (showTweeter) drawZCurve('zTweeterMag', '#ef4444', 1.8);
      if (showTotalSystem) drawZCurve('zTotalMag', '#a855f7', 2.5);
    };

    renderImpedanceToCanvas(impedanceCanvasRef.current);
    renderImpedanceToCanvas(detachedImpedanceCanvasRef.current);
  }, [simulationData, activeTab, detachedPlots, showWoofer, showTweeter, showTotalSystem, enableIndependentFx, wooferFx, tweeterFx, fx]);

  // --- Step Response Transient Simulation Engine ---
  const stepResponseData = useMemo(() => {
    const N = 1024;
    const fs = 48000;
    const durationMs = 6.0;

    const rw = new Float64Array(N);
    const iw = new Float64Array(N);
    const rt = new Float64Array(N);
    const it = new Float64Array(N);
    const rTot = new Float64Array(N);
    const iTot = new Float64Array(N);

    const delaySec = (acousticDelayMM / 1000.0) / 343.0;
    const polaritySign = invertTweeterPolarity ? -1.0 : 1.0;
    const lpadGain = (enableLPad && lpadAttenDB > 0) ? Math.pow(10, -lpadAttenDB / 20.0) : 1.0;
    const actualWooferFx = enableIndependentFx ? wooferFx : fx;
    const actualTweeterFx = enableIndependentFx ? tweeterFx : fx;

    for (let k = 1; k < N / 2; k++) {
      const f = (k * fs) / N;
      const sW = f / Math.max(actualWooferFx, 1.0);
      const sT = f / Math.max(actualTweeterFx, 1.0);

      let hCabR, hCabI;
      if (cabinetCalculations.enclosureType === 'vented') {
        const fs = Math.max(ts.fs, 1.0);
        const fb = cabinetCalculations.fb;
        const fn = f / fs;
        const h = fb / fs;
        const ql = 15.0;
        const qts = Math.max(cabinetCalculations.effectiveQts, 0.05);
        const alpha = Math.max(cabinetCalculations.alpha, 0.01);
        const c0 = h * h;
        const c1 = (h * h) / qts + h / ql;
        const c2 = 1.0 + h * h + alpha + h / (qts * ql);
        const c3 = 1.0 / qts + h / ql;
        const reD = Math.pow(fn, 4) - c2 * Math.pow(fn, 2) + c0;
        const imD = -c3 * Math.pow(fn, 3) + c1 * fn;
        const denM2 = reD * reD + imD * imD;
        const num = Math.pow(fn, 4);
        hCabR = (num * reD) / denM2;
        hCabI = (-num * imD) / denM2;
      } else {
        const fRatio = f / Math.max(cabinetCalculations.fc, 1.0);
        const sCab = Math.pow(fRatio, 2);
        const denomCabR = 1.0 - sCab;
        const denomCabI = fRatio / Math.max(cabinetCalculations.actualQtc, 0.1);
        const dCabMag2 = denomCabR * denomCabR + denomCabI * denomCabI;
        hCabR = (-sCab * denomCabR) / dCabMag2;
        hCabI = (sCab * denomCabI) / dCabMag2;
      }

      let hLPR = 1.0, hLPI = 0.0;
      if (wooferOrder === 'firstOrder') {
        const d = 1.0 + sW * sW;
        hLPR = 1.0 / d;
        hLPI = -sW / d;
      } else {
        const dR = 1.0 - sW * sW;
        const dI = Math.SQRT2 * sW;
        const dM2 = dR * dR + dI * dI;
        hLPR = dR / dM2;
        hLPI = -dI / dM2;
      }

      // All-pass delay compensation on woofer branch
      let hAPR = 1.0, hAPI = 0.0;
      if (enableAllpass && acousticDelayMM > 0) {
        const f0 = apfOptimization.f0 || Math.round(Math.sqrt(actualWooferFx * actualTweeterFx));
        const qAP = apfOptimization.q || 0.707;
        const sAP = f / f0;
        const dR = 1.0 - sAP * sAP;
        const dI = sAP / qAP;
        const dM2 = dR * dR + dI * dI;
        hAPR = (dR * dR - dI * dI) / dM2;
        hAPI = (-2.0 * dR * dI) / dM2;
      }

      let pWooferLinear = 1.0;
      if (wooferCurve && wooferCurve.length > 0) {
        const spl = interpolateCurveSPL(f, wooferCurve);
        if (spl !== null) pWooferLinear = Math.pow(10, (spl - 90.0) / 20.0);
      }
      let pTweeterLinear = 1.0;
      if (tweeterCurve && tweeterCurve.length > 0) {
        const spl = interpolateCurveSPL(f, tweeterCurve);
        if (spl !== null) pTweeterLinear = Math.pow(10, (spl - 90.0) / 20.0);
      }

      const pW_raw_R = (hCabR * hLPR - hCabI * hLPI) * pWooferLinear;
      const pW_raw_I = (hCabR * hLPI + hCabI * hLPR) * pWooferLinear;
      const pWR = pW_raw_R * hAPR - pW_raw_I * hAPI;
      const pWI = pW_raw_R * hAPI + pW_raw_I * hAPR;

      let hHPR = 1.0, hHPI = 0.0;
      if (tweeterOrder === 'firstOrder') {
        const d = 1.0 + sT * sT;
        hHPR = (sT * sT) / d;
        hHPI = sT / d;
      } else {
        const num = -sT * sT;
        const dR = 1.0 - sT * sT;
        const dI = Math.SQRT2 * sT;
        const dM2 = dR * dR + dI * dI;
        hHPR = (num * dR) / dM2;
        hHPI = (-num * dI) / dM2;
      }

      const phaseDelay = -2.0 * Math.PI * f * delaySec;
      const cosD = Math.cos(phaseDelay) * polaritySign;
      const sinD = Math.sin(phaseDelay) * polaritySign;

      const pTR = (hHPR * cosD - hHPI * sinD) * lpadGain * pTweeterLinear;
      const pTI = (hHPR * sinD + hHPI * cosD) * lpadGain * pTweeterLinear;

      const rollOff = Math.exp(-Math.pow(f / 21000.0, 4.0));

      rw[k] = pWR * rollOff;
      iw[k] = pWI * rollOff;
      rw[N - k] = rw[k];
      iw[N - k] = -iw[k];

      rt[k] = pTR * rollOff;
      it[k] = pTI * rollOff;
      rt[N - k] = rt[k];
      it[N - k] = -it[k];

      rTot[k] = (pWR + pTR) * rollOff;
      iTot[k] = (pWI + pTI) * rollOff;
      rTot[N - k] = rTot[k];
      iTot[N - k] = -iTot[k];
    }

    const ifft = (real, imag) => {
      const n = real.length;
      for (let i = 0; i < n; i++) imag[i] = -imag[i];
      let j = 0;
      for (let i = 0; i < n - 1; i++) {
        if (i < j) {
          let tr = real[i]; real[i] = real[j]; real[j] = tr;
          let ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
        }
        let k = n >> 1;
        while (k <= j) { j -= k; k >>= 1; }
        j += k;
      }
      for (let len = 2; len <= n; len <<= 1) {
        const half = len >> 1;
        const angle = -2.0 * Math.PI / len;
        const wStepR = Math.cos(angle);
        const wStepI = Math.sin(angle);
        for (let i = 0; i < n; i += len) {
          let wr = 1.0, wi = 0.0;
          for (let m = 0; m < half; m++) {
            const idx1 = i + m;
            const idx2 = i + m + half;
            const tr = wr * real[idx2] - wi * imag[idx2];
            const ti = wr * imag[idx2] + wi * real[idx2];
            real[idx2] = real[idx1] - tr;
            imag[idx2] = imag[idx1] - ti;
            real[idx1] += tr;
            imag[idx1] += ti;
            const nextWr = wr * wStepR - wi * wStepI;
            wi = wr * wStepI + wi * wStepR;
            wr = nextWr;
          }
        }
      }
      const scale = 1.0 / n;
      for (let i = 0; i < n; i++) {
        real[i] *= scale;
        imag[i] = -imag[i] * scale;
      }
    };

    ifft(rw, iw);
    ifft(rt, it);
    ifft(rTot, iTot);

    const stepW = new Float64Array(N);
    const stepT = new Float64Array(N);
    const stepTot = new Float64Array(N);

    stepW[0] = rw[0];
    stepT[0] = rt[0];
    stepTot[0] = rTot[0];

    for (let i = 1; i < N; i++) {
      stepW[i] = stepW[i - 1] + rw[i];
      stepT[i] = stepT[i - 1] + rt[i];
      stepTot[i] = stepTot[i - 1] + rTot[i];
    }

    let maxPeak = 0.001;
    for (let i = 0; i < N; i++) {
      const p = Math.abs(stepTot[i]);
      if (p > maxPeak) maxPeak = p;
    }
    const norm = 1.0 / maxPeak;

    const stepCount = 200;
    const points = [];
    for (let i = 0; i <= stepCount; i++) {
      const tMs = (i * durationMs) / stepCount;
      const idx = Math.min(N - 1, Math.max(0, Math.round((tMs / 1000.0) * fs)));
      points.push({
        timeMs: tMs,
        woofer: stepW[idx] * norm,
        tweeter: stepT[idx] * norm,
        total: stepTot[idx] * norm
      });
    }

    return points;
  }, [cabinetCalculations, fx, enableIndependentFx, wooferFx, tweeterFx, wooferOrder, tweeterOrder, acousticDelayMM, invertTweeterPolarity, enableAllpass, apfOptimization, enableLPad, lpadAttenDB, wooferCurve, tweeterCurve, ts.fs]);

  // --- Render Step Response Plot ---
  useEffect(() => {
    if (stepResponseData.length === 0) return;
    const renderStepToCanvas = (canvas) => {
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;

      ctx.clearRect(0, 0, width, height);

      const maxTimeMs = 6.0;
      const minAmp = -0.6;
      const maxAmp = 1.4;

      const toCanvas = (tMs, a) => {
        const x = width * (tMs / maxTimeMs);
        const y = height * (1.0 - (a - minAmp) / (maxAmp - minAmp));
        return [x, y];
      };

      ctx.lineWidth = 1;
      for (let t = 0; t <= maxTimeMs; t += 0.5) {
        const [x] = toCanvas(t, 0);
        const isMajor = Math.round(t * 10) % 10 === 0;
        ctx.strokeStyle = isMajor ? 'rgba(100, 116, 139, 0.35)' : 'rgba(100, 116, 139, 0.15)';
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, height);
        ctx.stroke();

        if (isMajor) {
          ctx.fillStyle = '#94a3b8';
          ctx.font = '10px monospace';
          const textX = t >= maxTimeMs - 0.01 ? x - 32 : x + 4;
          ctx.fillText(`${t} ms`, textX, height - 8);
        }
      }

      for (let a = minAmp; a <= maxAmp; a += 0.25) {
        const [, y] = toCanvas(0, a);
        const isZero = Math.abs(a) < 0.01;
        ctx.strokeStyle = isZero ? 'rgba(148, 163, 184, 0.6)' : 'rgba(100, 116, 139, 0.2)';
        ctx.lineWidth = isZero ? 1.5 : 0.8;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();

        if (a > minAmp + 0.01) {
          ctx.fillStyle = isZero ? '#f1f5f9' : '#64748b';
          ctx.font = '10px monospace';
          const textY = y <= 2 ? 12 : y - 4;
          ctx.fillText(a.toFixed(2), 6, textY);
        }
      }

      // Woofer (Blue)
      if (showWoofer) {
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 2;
        ctx.beginPath();
        stepResponseData.forEach((p, i) => {
          const [x, y] = toCanvas(p.timeMs, p.woofer);
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }

      // Tweeter (Red)
      if (showTweeter) {
        ctx.strokeStyle = '#ef4444';
        ctx.lineWidth = 2;
        ctx.beginPath();
        stepResponseData.forEach((p, i) => {
          const [x, y] = toCanvas(p.timeMs, p.tweeter);
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }

      // Total System (Green)
      if (showTotalSystem) {
        ctx.strokeStyle = '#22c55e';
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        stepResponseData.forEach((p, i) => {
          const [x, y] = toCanvas(p.timeMs, p.total);
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.stroke();
      }
    };

    renderStepToCanvas(stepCanvasRef.current);
    renderStepToCanvas(detachedStepCanvasRef.current);
  }, [stepResponseData, activeTab, detachedPlots, showWoofer, showTweeter, showTotalSystem]);

  // --- Shared Datasheet Application Helper ---
  const applyParsedDatasheet = (parsed, sourceName) => {
    if (parsed && parsed.ts) {
      setTs(prev => {
        const computedQts = parsed.ts.qts || (parsed.ts.qes && parsed.ts.qms ? (parsed.ts.qes * parsed.ts.qms) / (parsed.ts.qes + parsed.ts.qms) : prev.qts);
        return {
          ...prev,
          fs: parsed.ts.fs || prev.fs,
          qes: parsed.ts.qes || prev.qes,
          qms: parsed.ts.qms || prev.qms,
          qts: parseFloat(computedQts.toFixed(3)),
          vas: parsed.ts.vas || prev.vas,
          re: parsed.ts.re || prev.re,
          le: parsed.ts.le || prev.le,
          sd: parsed.ts.sd || prev.sd,
          xmax: parsed.ts.xmax || prev.xmax,
          spl: parsed.ts.spl || prev.spl
        };
      });
      if (parsed.driverName) {
        setDriverName(parsed.driverName);
      }
      if (parsed.tweeter) {
        setTweeter(prev => ({
          ...prev,
          fs: parsed.tweeter.fs || prev.fs,
          re: parsed.tweeter.re || prev.re,
          le: parsed.tweeter.le || prev.le,
          spl: parsed.tweeter.spl || prev.spl
        }));
      }
      if (parsed.recommendedCrossover && parsed.recommendedCrossover >= 500 && parsed.recommendedCrossover <= 8000) {
        setFx(parsed.recommendedCrossover);
      }

      if (parsed.wooferCurve && parsed.wooferCurve.length > 0) {
        setWooferCurve(parsed.wooferCurve);
      }
      if (parsed.tweeterCurve && parsed.tweeterCurve.length > 0) {
        setTweeterCurve(parsed.tweeterCurve);
      }

      setMissingParams(parsed.missingParams || []);
      setPlausibilityWarnings(parsed.warnings || []);

      if (parsed.warnings && parsed.warnings.length > 0) {
        setStatusMsg(`Warning: ${parsed.warnings.join(' | ')}`);
      } else if (parsed.missingParams && parsed.missingParams.length > 0) {
        setStatusMsg(`Datasheet ingested. Missing: ${parsed.missingParams.join(', ')} — please enter manually.`);
      } else {
        const xoInfo = parsed.recommendedCrossover ? ` (fx: ${parsed.recommendedCrossover} Hz)` : '';
        setStatusMsg(`Successfully extracted specs for ${parsed.driverName || sourceName}${xoInfo}`);
      }
    } else {
      setStatusMsg(`Could not parse parameters from ${sourceName || 'datasheet'}.`);
    }
  };

  const loadAltec604Preset = () => {
    setDriverName('Altec Lansing 604-8K');
    setTs({ ...altec604WooferTS });
    setTweeter({ ...altec604Tweeter });
    setFx(altec604RecommendedCrossover);
    setWooferCurve(altec604WooferCurve);
    setTweeterCurve(altec604TweeterCurve);
    setMissingParams([]);
    setPlausibilityWarnings([]);
    setStatusMsg('Loaded Altec Lansing 604-8K factory specs & digitized CLIO frequency response curves.');
  };

  const validateManualField = (paramName, value) => {
    if (value && value > 0) {
      setMissingParams(prev => prev.filter(p => p !== paramName));
    }
  };

  // --- Local File Datasheet Handler ---
  const processLocalPDF = async (file) => {
    setSelectedFileName(file.name);
    setIsLoadingFile(true);
    setStatusMsg(`Parsing local PDF: ${file.name}...`);
    try {
      const parsed = await parseDatasheetFromFile(file);
      applyParsedDatasheet(parsed, file.name);
    } catch (err) {
      console.error(err);
      setStatusMsg(`Failed to parse local PDF: ${err.message || 'Invalid format'}`);
    } finally {
      setIsLoadingFile(false);
    }
  };

  const handleSaveDesign = async () => {
    const stuffingLevels = {
      1.0: 'none',
      1.1: 'light',
      1.18: 'medium',
      1.25: 'heavy'
    };
    const currentStuffing = stuffingLevels[stuffingGain] || (stuffingGain >= 1.2 ? 'heavy' : (stuffingGain >= 1.15 ? 'medium' : (stuffingGain >= 1.05 ? 'light' : 'none')));

    const doc = {
      version: 1,
      timestamp: new Date().toISOString(),
      name: driverName || "Custom Speaker Design",
      driver: {
        name: driverName,
        manufacturer: manufacturer,
        datasheetURL: datasheetURL,
        wooferTS: {
          fs: ts.fs,
          qes: ts.qes,
          qms: ts.qms,
          qts: ts.qts,
          vas: ts.vas,
          re: ts.re,
          le: ts.le,
          sd: ts.sd,
          xmax: ts.xmax,
          spl: ts.spl,
          pe: ts.pe || 150.0
        },
        tweeter: {
          fs: tweeter.fs,
          re: tweeter.re,
          le: tweeter.le,
          spl: tweeter.spl,
          nominalImpedance: tweeter.nominalImpedance || 8.0
        },
        wooferAcousticCurve: wooferCurve || [],
        tweeterAcousticCurve: tweeterCurve || []
      },
      cabinet: {
        enclosureType: enclosureType,
        alignment: alignment,
        targetQtc: customQtc,
        targetF3: targetF3,
        stuffing: currentStuffing,
        isManualVolumeOverride: manualVbOverride,
        manualNetVolumeLiters: manualVbLiters,
        ventedAlignment: ventedAlignment,
        tuningFrequencyFb: tuningFb,
        portDiameterCm: portDiameterCm,
        numberOfPorts: portCount,
        portLossQl: 15.0
      },
      crossover: {
        crossoverFrequency: fx,
        wooferOrder: wooferOrder,
        tweeterOrder: tweeterOrder,
        enableIndependentFrequencies: enableIndependentFx,
        wooferCrossoverFrequency: enableIndependentFx ? wooferFx : null,
        tweeterCrossoverFrequency: enableIndependentFx ? tweeterFx : null,
        enableZobelNetwork: enableZobel,
        enableLPadAttenuator: enableLPad,
        userTargetAttenuationdB: lpadAttenDB,
        acousticCenterOffsetMM: acousticDelayMM,
        invertTweeterPolarity: invertTweeterPolarity,
        snapToStandardValues: snapToE12,
        snapToE24Values: snapToE24,
        enableAllpassFilter: enableAllpass
      },
      wooferFRDText: wooferFRDText || "",
      tweeterFRDText: tweeterFRDText || ""
    };

    const jsonString = JSON.stringify(doc, null, 2);
    const sanitizedName = (driverName || "Speaker").trim().replace(/\s+/g, '_');
    const filename = `${sanitizedName}_Design.json`;

    // Modern File System Access API if available
    if (typeof window !== 'undefined' && 'showSaveFilePicker' in window) {
      try {
        const handle = await window.showSaveFilePicker({
          suggestedName: filename,
          types: [{
            description: 'JSON Design File',
            accept: { 'application/json': ['.json'] }
          }]
        });
        const writable = await handle.createWritable();
        await writable.write(jsonString);
        await writable.close();
        setStatusMsg(`Saved design '${driverName}' to ${filename}`);
        return;
      } catch (pickerErr) {
        if (pickerErr.name === 'AbortError') return;
      }
    }

    // Direct Blob download fallback
    const blob = new Blob([jsonString], { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.rel = "noopener";
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      if (a.parentNode) document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 5000);
    setStatusMsg(`Saved design '${driverName}' to ${filename}`);
  };

  const handleLoadDesignClick = async (e) => {
    if (typeof window !== 'undefined' && 'showOpenFilePicker' in window) {
      e.preventDefault();
      try {
        const [handle] = await window.showOpenFilePicker({
          types: [{
            description: 'JSON Design File',
            accept: { 'application/json': ['.json'] }
          }],
          multiple: false
        });
        const file = await handle.getFile();
        await processJSONDesignFile(file);
        return;
      } catch (err) {
        if (err.name === 'AbortError') return;
        console.error(err);
      }
    }
  };

  const processJSONDesignFile = async (file) => {
    try {
      const text = await file.text();
      const doc = JSON.parse(text);

      if (doc.driver) {
        if (doc.driver.name) setDriverName(doc.driver.name);
        if (doc.driver.manufacturer) setManufacturer(doc.driver.manufacturer);
        if (doc.driver.datasheetURL) setDatasheetURL(doc.driver.datasheetURL);
        if (doc.driver.wooferTS) {
          setTs(prev => ({ ...prev, ...doc.driver.wooferTS }));
        }
        if (doc.driver.tweeter) {
          setTweeter(prev => ({ ...prev, ...doc.driver.tweeter }));
        }
        if (Array.isArray(doc.driver.wooferAcousticCurve) && doc.driver.wooferAcousticCurve.length > 0) {
          setWooferCurve(doc.driver.wooferAcousticCurve);
        }
        if (Array.isArray(doc.driver.tweeterAcousticCurve) && doc.driver.tweeterAcousticCurve.length > 0) {
          setTweeterCurve(doc.driver.tweeterAcousticCurve);
        }
      }

      if (doc.cabinet) {
        if (doc.cabinet.enclosureType) setEnclosureType(doc.cabinet.enclosureType);
        if (doc.cabinet.alignment) setAlignment(doc.cabinet.alignment);
        if (doc.cabinet.targetQtc !== undefined) setCustomQtc(doc.cabinet.targetQtc);
        if (doc.cabinet.targetF3 !== undefined) setTargetF3(doc.cabinet.targetF3);
        if (doc.cabinet.isManualVolumeOverride !== undefined) setManualVbOverride(doc.cabinet.isManualVolumeOverride);
        if (doc.cabinet.manualNetVolumeLiters !== undefined) setManualVbLiters(doc.cabinet.manualNetVolumeLiters);
        if (doc.cabinet.ventedAlignment) setVentedAlignment(doc.cabinet.ventedAlignment);
        if (doc.cabinet.tuningFrequencyFb !== undefined) setTuningFb(doc.cabinet.tuningFrequencyFb);
        if (doc.cabinet.portDiameterCm !== undefined) setPortDiameterCm(doc.cabinet.portDiameterCm);
        if (doc.cabinet.numberOfPorts !== undefined) setPortCount(doc.cabinet.numberOfPorts);
        if (doc.cabinet.stuffing) {
          const sMap = { 'none': 1.0, 'light': 1.10, 'medium': 1.18, 'heavy': 1.25 };
          setStuffingGain(sMap[doc.cabinet.stuffing] || 1.0);
        }
      }

      if (doc.crossover) {
        if (doc.crossover.crossoverFrequency !== undefined) setFx(doc.crossover.crossoverFrequency);
        if (doc.crossover.wooferOrder) setWooferOrder(doc.crossover.wooferOrder);
        if (doc.crossover.tweeterOrder) setTweeterOrder(doc.crossover.tweeterOrder);
        if (doc.crossover.enableIndependentFrequencies !== undefined) {
          setEnableIndependentFx(doc.crossover.enableIndependentFrequencies);
        }
        if (doc.crossover.wooferCrossoverFrequency) setWooferFx(doc.crossover.wooferCrossoverFrequency);
        if (doc.crossover.tweeterCrossoverFrequency) setTweeterFx(doc.crossover.tweeterCrossoverFrequency);
        if (doc.crossover.enableZobelNetwork !== undefined) setEnableZobel(doc.crossover.enableZobelNetwork);
        if (doc.crossover.enableLPadAttenuator !== undefined) setEnableLPad(doc.crossover.enableLPadAttenuator);
        if (doc.crossover.userTargetAttenuationdB !== undefined) setLpadAttenDB(doc.crossover.userTargetAttenuationdB);
        if (doc.crossover.acousticCenterOffsetMM !== undefined) setAcousticDelayMM(doc.crossover.acousticCenterOffsetMM);
        if (doc.crossover.invertTweeterPolarity !== undefined) setInvertTweeterPolarity(doc.crossover.invertTweeterPolarity);
        if (doc.crossover.snapToE24Values !== undefined) {
          setSnapToE24(doc.crossover.snapToE24Values);
          if (doc.crossover.snapToE24Values) {
            setSnapToE12(false);
          } else if (doc.crossover.snapToStandardValues !== undefined) {
            setSnapToE12(doc.crossover.snapToStandardValues);
          }
        } else if (doc.crossover.snapToStandardValues !== undefined) {
          setSnapToE12(doc.crossover.snapToStandardValues);
          if (doc.crossover.snapToStandardValues) setSnapToE24(false);
        }
        if (doc.crossover.enableAllpassFilter !== undefined) setEnableAllpass(doc.crossover.enableAllpassFilter);
      }

      if (doc.wooferFRDText) setWooferFRDText(doc.wooferFRDText);
      if (doc.tweeterFRDText) setTweeterFRDText(doc.tweeterFRDText);

      setMissingParams([]);
      setPlausibilityWarnings([]);
      setStatusMsg(`Successfully loaded design '${doc.name || file.name}' with all parameters.`);
    } catch (err) {
      console.error(err);
      setStatusMsg(`Failed to load design JSON file: ${err.message || 'Invalid format'}`);
    }
  };

  const handleJSONFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    await processJSONDesignFile(file);
    if (jsonFileInputRef.current) jsonFileInputRef.current.value = '';
  };

  const handleLocalFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.name.toLowerCase().endsWith('.json')) {
      await processJSONDesignFile(file);
    } else {
      await processLocalPDF(file);
    }
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDraggingFile(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDraggingFile(false);
  };

  const handleDrop = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDraggingFile(false);
    const file = e.dataTransfer.files?.[0];
    if (!file) return;
    if (file.name.toLowerCase().endsWith('.json')) {
      await processJSONDesignFile(file);
    } else {
      await processLocalPDF(file);
    }
  };

  // --- URL Datasheet Parser Handler ---
  const handleFetchDatasheet = async () => {
    if (!datasheetURL) return;
    setIsLoadingURL(true);
    setStatusMsg("Fetching and parsing PDF/datasheet...");
    try {
      const parsed = await parseDatasheetFromURL(datasheetURL);
      applyParsedDatasheet(parsed, datasheetURL);
    } catch (err) {
      console.error(err);
      setStatusMsg("Failed to fetch or parse URL datasheet.");
    } finally {
      setIsLoadingURL(false);
    }
  };

  return (
    <div className="flex h-screen bg-slate-900 text-slate-100 font-sans overflow-hidden">
      {/* --- Sidebar Inspector Panel --- */}
      <aside className="w-96 bg-slate-800 border-r border-slate-700 flex flex-col h-full overflow-y-auto p-4 space-y-6">
        <div className="flex items-center space-x-3 border-b border-slate-700 pb-4">
          <Speaker className="w-8 h-8 text-blue-400" />
          <div>
            <h1 className="font-bold text-lg text-white">Coaxial Designer</h1>
            <p className="text-xs text-slate-400">Native macOS Audio Engine</p>
          </div>
        </div>

        {/* Design Project File (Save / Load) */}
        <div className="p-3.5 rounded-lg border bg-slate-900/60 border-slate-700/80 space-y-3">
          <div className="flex items-center justify-between">
            <label className="text-xs font-semibold text-slate-300 flex items-center space-x-2">
              <FolderOpen className="w-3.5 h-3.5 text-emerald-400" />
              <span>Design Project File</span>
            </label>
            <span className="text-[10px] text-slate-400">JSON Format</span>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={handleSaveDesign}
              className="bg-emerald-600 hover:bg-emerald-500 text-white font-medium text-xs py-2 px-3 rounded transition flex items-center justify-center space-x-1.5 cursor-pointer shadow-sm"
              title="Save complete project parameters to .json"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Save Design</span>
            </button>

            <label
              htmlFor="jsonFileInput"
              onClick={handleLoadDesignClick}
              className="bg-slate-800 hover:bg-slate-700 border border-slate-600 hover:border-slate-400 text-slate-200 font-medium text-xs py-2 px-3 rounded transition flex items-center justify-center space-x-1.5 cursor-pointer"
              title="Load project parameters from .json"
            >
              <Upload className="w-3.5 h-3.5 text-emerald-400" />
              <span>Load Design</span>
              <input
                id="jsonFileInput"
                type="file"
                ref={jsonFileInputRef}
                onChange={handleJSONFileUpload}
                onClick={(e) => { e.target.value = ''; }}
                accept=".json,application/json"
                className="sr-only"
                tabIndex={-1}
                aria-hidden="true"
              />
            </label>
          </div>
        </div>

        {/* Datasheet Ingestion (Local File or URL) */}
        <div 
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          className={`p-3.5 rounded-lg border transition-colors space-y-3 ${
            isDraggingFile 
              ? 'bg-blue-950/60 border-blue-400 ring-2 ring-blue-500/30' 
              : 'bg-slate-900/60 border-slate-700/80'
          }`}
        >
          <div className="flex items-center justify-between">
            <label className="text-xs font-semibold text-slate-300 flex items-center space-x-2">
              <FileText className="w-3.5 h-3.5 text-blue-400" />
              <span>Datasheet Ingestion</span>
            </label>
            {selectedFileName && (
              <span className="text-[10px] text-slate-400 truncate max-w-[140px]" title={selectedFileName}>
                {selectedFileName}
              </span>
            )}
          </div>

          {/* Hidden File Input */}
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleLocalFileUpload}
            accept=".pdf,application/pdf"
            className="sr-only"
            tabIndex={-1}
            aria-hidden="true"
          />

          {/* Local File Ingestion Button & Drop Zone */}
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={isLoadingFile || isLoadingURL}
            className="w-full bg-slate-800 hover:bg-slate-700/80 border border-dashed border-slate-600 hover:border-blue-400 text-slate-200 font-medium text-xs py-2 px-3 rounded transition flex items-center justify-center space-x-2 cursor-pointer disabled:opacity-50"
          >
            {isLoadingFile ? (
              <RefreshCw className="w-3.5 h-3.5 animate-spin text-blue-400" />
            ) : (
              <Upload className="w-3.5 h-3.5 text-blue-400" />
            )}
            <span>{isLoadingFile ? 'Parsing Local PDF...' : 'Choose Local PDF File / Drop Here'}</span>
          </button>

          {/* Quick Preset for Altec 604-8K */}
          <button
            type="button"
            onClick={loadAltec604Preset}
            className="w-full bg-slate-800/80 hover:bg-slate-700 border border-slate-700 hover:border-slate-500 text-slate-200 font-medium text-xs py-1.5 px-3 rounded transition flex items-center justify-center space-x-2 cursor-pointer"
          >
            <Speaker className="w-3.5 h-3.5 text-indigo-400" />
            <span>Load Altec 604-8K Preset (CLIO)</span>
          </button>

          <div className="flex items-center space-x-2 text-[10px] text-slate-500">
            <div className="flex-1 h-px bg-slate-700/80"></div>
            <span>OR ENTER URL</span>
            <div className="flex-1 h-px bg-slate-700/80"></div>
          </div>

          {/* URL Input */}
          <div className="space-y-2">
            <div className="flex space-x-2">
              <input
                type="text"
                placeholder="https://example.com/datasheet.pdf"
                value={datasheetURL}
                onChange={(e) => setDatasheetURL(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
              />
            </div>
            <button
              type="button"
              onClick={handleFetchDatasheet}
              disabled={isLoadingURL || isLoadingFile || !datasheetURL.trim()}
              className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium text-xs py-1.5 rounded transition flex items-center justify-center space-x-2 cursor-pointer"
            >
              {isLoadingURL ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
              <span>Fetch & Parse URL</span>
            </button>
          </div>

          {statusMsg && (
            <p className={`text-xs ${statusMsg.toLowerCase().includes('fail') || statusMsg.toLowerCase().includes('could not') || statusMsg.toLowerCase().includes('error') ? 'text-red-400' : 'text-emerald-400'}`}>
              {statusMsg}
            </p>
          )}

          {/* Missing Parameters Notification Banner */}
          {missingParams.length > 0 && (
            <div className="p-2 bg-amber-950/40 border border-amber-500/50 rounded text-[11px] text-amber-200 flex items-start space-x-1.5">
              <AlertCircle className="w-3.5 h-3.5 mt-0.5 shrink-0 text-amber-400" />
              <div>
                <span className="font-semibold text-amber-300">Missing from datasheet:</span> {missingParams.join(', ')}.
                <p className="text-[10px] text-amber-300/80 mt-0.5">Please check and enter the values manually in the fields below.</p>
              </div>
            </div>
          )}

          {/* Plausibility Warning Banner */}
          {plausibilityWarnings.length > 0 && (
            <div className="p-2 bg-red-950/40 border border-red-500/50 rounded text-[11px] text-red-200 flex items-start space-x-1.5">
              <AlertCircle className="w-3.5 h-3.5 mt-0.5 shrink-0 text-red-400" />
              <div>
                <span className="font-semibold text-red-300">Implausible parameter:</span>
                <ul className="list-disc list-inside mt-0.5 space-y-0.5 text-[10px]">
                  {plausibilityWarnings.map((w, i) => (
                    <li key={i}>{w}</li>
                  ))}
                </ul>
              </div>
            </div>
          )}
        </div>

        {/* Driver Identity */}
        <div className="space-y-2">
          <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Driver Model Name</label>
          <input
            type="text"
            value={driverName}
            onChange={(e) => setDriverName(e.target.value)}
            className="w-full bg-slate-900 border border-slate-700 rounded px-2.5 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500 font-medium"
            placeholder="Driver Name"
          />
        </div>

        {/* Decimal Separator Toggle */}
        <div className="flex items-center justify-between text-xs bg-slate-900/60 p-2.5 rounded-lg border border-slate-700/80">
          <span className="text-[11px] font-semibold text-slate-300">Decimal Separator</span>
          <div className="flex bg-slate-800 rounded p-0.5 border border-slate-700">
            <button
              type="button"
              onClick={() => setIsEuropeanDecimal(false)}
              className={`px-2 py-0.5 rounded text-[10px] font-medium transition cursor-pointer ${!isEuropeanDecimal ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}
            >
              US ( . )
            </button>
            <button
              type="button"
              onClick={() => setIsEuropeanDecimal(true)}
              className={`px-2 py-0.5 rounded text-[10px] font-medium transition cursor-pointer ${isEuropeanDecimal ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}
            >
              EU ( , )
            </button>
          </div>
        </div>

        {/* Crossover Frequency Spec */}
        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Crossover Frequency (fx)</label>
            <span className="text-xs font-mono text-blue-400 font-bold">{isEuropeanDecimal ? String(fx).replace('.', ',') : fx} Hz</span>
          </div>
          <div className="relative">
            <DecimalInput
              value={fx}
              onChange={(v) => setFx(v)}
              isEuropean={isEuropeanDecimal}
              className="w-full bg-slate-900 border border-slate-700 rounded pl-2.5 pr-8 py-1 text-xs text-white focus:outline-none focus:border-blue-500"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">Hz</span>
          </div>
        </div>

        {/* Driver TS Parameters */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Woofer T/S Parameters</h2>
            <div className="flex items-center space-x-2">
              {missingParams.some(p => ['Fs', 'Qes', 'Qms', 'Qts', 'Vas', 'Re', 'Le', 'Sd', 'Xmax', 'Sensitivity'].includes(p)) && (
                <span className="text-[10px] text-amber-400 font-medium">entry needed</span>
              )}
              <button
                type="button"
                onClick={() => {
                  setTs({ fs: 48.0, qes: 0.36, qms: 4.8, qts: 0.335, vas: 28.0, re: 6.2, le: 0.85, sd: 210.0, xmax: 5.5, spl: 89.0 });
                  setTweeter({ fs: 1200.0, re: 5.8, le: 0.08, spl: 94.0 });
                  setFx(2200);
                  setDriverName("8CX21 Coaxial 8-inch Driver");
                  setMissingParams([]);
                  setPlausibilityWarnings([]);
                  setStatusMsg("Reset specifications to standard defaults.");
                }}
                className="text-[10px] text-slate-400 hover:text-slate-200 underline cursor-pointer"
                title="Reset driver parameters to template defaults"
              >
                Reset
              </button>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Fs</span>
                {missingParams.includes('Fs') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.fs} 
                  onChange={(v) => {
                    setTs(prev => ({ ...prev, fs: v }));
                    validateManualField('Fs', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded pl-2 pr-7 py-1 text-white text-xs ${missingParams.includes('Fs') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">Hz</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Qes</span>
                {missingParams.includes('Qes') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="mt-1">
                <DecimalInput 
                  value={ts.qes} 
                  onChange={(v) => {
                    const newQts = (v > 0 && ts.qms > 0) ? (v * ts.qms) / (v + ts.qms) : ts.qts;
                    setTs(prev => ({ ...prev, qes: v, qts: parseFloat(newQts.toFixed(3)) }));
                    validateManualField('Qes', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded px-2 py-1 text-white text-xs ${missingParams.includes('Qes') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Qms</span>
                {missingParams.includes('Qms') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="mt-1">
                <DecimalInput 
                  value={ts.qms} 
                  onChange={(v) => {
                    const newQts = (ts.qes > 0 && v > 0) ? (ts.qes * v) / (ts.qes + v) : ts.qts;
                    setTs(prev => ({ ...prev, qms: v, qts: parseFloat(newQts.toFixed(3)) }));
                    validateManualField('Qms', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded px-2 py-1 text-white text-xs ${missingParams.includes('Qms') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Qts (Total Q)</span>
                {missingParams.includes('Qts') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="mt-1">
                <DecimalInput 
                  value={ts.qts} 
                  onChange={(v) => {
                    setTs(prev => ({ ...prev, qts: v }));
                    validateManualField('Qts', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded px-2 py-1 text-white text-xs ${missingParams.includes('Qts') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Vas</span>
                {missingParams.includes('Vas') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.vas} 
                  onChange={(v) => {
                    setTs(prev => ({ ...prev, vas: v }));
                    validateManualField('Vas', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded pl-2 pr-6 py-1 text-white text-xs ${missingParams.includes('Vas') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">L</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>Re</span>
                {missingParams.includes('Re') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.re} 
                  onChange={(v) => {
                    setTs(prev => ({ ...prev, re: v }));
                    validateManualField('Re', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded pl-2 pr-6 py-1 text-white text-xs ${missingParams.includes('Re') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">Ω</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">Le</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.le} 
                  onChange={(v) => setTs(prev => ({ ...prev, le: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-8 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">mH</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">Sd</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.sd} 
                  onChange={(v) => setTs(prev => ({ ...prev, sd: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-9 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">cm²</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">Xmax</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.xmax} 
                  onChange={(v) => setTs(prev => ({ ...prev, xmax: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-8 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">mm</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 flex items-center justify-between text-[11px]">
                <span>SPL</span>
                {missingParams.includes('Sensitivity') && <span className="text-amber-400 text-[10px]">required</span>}
              </label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={ts.spl} 
                  onChange={(v) => {
                    setTs(prev => ({ ...prev, spl: v }));
                    validateManualField('Sensitivity', v);
                  }} 
                  isEuropean={isEuropeanDecimal}
                  className={`w-full bg-slate-900 border rounded pl-2 pr-7 py-1 text-white text-xs ${missingParams.includes('Sensitivity') ? 'border-amber-500 ring-1 ring-amber-500/30' : 'border-slate-700'}`} 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">dB</span>
              </div>
            </div>
          </div>
        </div>

        {/* Tweeter Parameters */}
        <div className="space-y-3">
          <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Tweeter / HF Specs</h2>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div>
              <label className="text-slate-400 text-[11px]">Fs</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={tweeter.fs} 
                  onChange={(v) => setTweeter(prev => ({ ...prev, fs: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-7 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">Hz</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">Re</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={tweeter.re} 
                  onChange={(v) => setTweeter(prev => ({ ...prev, re: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-6 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">Ω</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">Le</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={tweeter.le} 
                  onChange={(v) => setTweeter(prev => ({ ...prev, le: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-8 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">mH</span>
              </div>
            </div>
            <div>
              <label className="text-slate-400 text-[11px]">SPL</label>
              <div className="relative mt-1">
                <DecimalInput 
                  value={tweeter.spl} 
                  onChange={(v) => setTweeter(prev => ({ ...prev, spl: v }))} 
                  isEuropean={isEuropeanDecimal}
                  className="w-full bg-slate-900 border border-slate-700 rounded pl-2 pr-7 py-1 text-white text-xs" 
                />
                <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-mono pointer-events-none">dB</span>
              </div>
            </div>
          </div>
        </div>
      </aside>

      {/* --- Main Content View Workspace --- */}
      <main className="flex-1 flex flex-col h-full bg-slate-950 overflow-hidden">
        {/* Navigation Bar */}
        <header className="h-14 bg-slate-800 border-b border-slate-700 flex items-center justify-between px-6">
          <div className="flex items-center space-x-1">
            <button onClick={() => setActiveTab('amplitude')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'amplitude' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Amplitude Plot</button>
            <button onClick={() => setActiveTab('phase')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'phase' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Phase & Delay</button>
            <button onClick={() => setActiveTab('delay')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'delay' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Group Delay</button>
            <button onClick={() => setActiveTab('step')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'step' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Step Response</button>
            <button onClick={() => setActiveTab('impedance')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'impedance' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>System Impedance</button>
            <button onClick={() => setActiveTab('cabinet')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'cabinet' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Sealed Cabinet</button>
            <button onClick={() => setActiveTab('crossover')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'crossover' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Crossover Designer</button>
            <button onClick={() => setActiveTab('bom')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'bom' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Schematic & BOM</button>
          </div>
          <div className="flex items-center space-x-2">
            <button
              onClick={() => setShowHelpDialog(true)}
              className="flex items-center space-x-1.5 px-3 py-1.5 text-xs font-medium text-slate-300 hover:text-white bg-slate-700/60 hover:bg-slate-700 rounded-md transition cursor-pointer"
            >
              <span>?</span>
              <span>Help</span>
            </button>
            <button
              onClick={() => setShowAboutDialog(true)}
              className="flex items-center space-x-1.5 px-3 py-1.5 text-xs font-medium text-slate-300 hover:text-white bg-slate-700/60 hover:bg-slate-700 rounded-md transition cursor-pointer"
            >
              <Info className="w-3.5 h-3.5" />
              <span>About</span>
            </button>
          </div>
        </header>

        {/* View Workspace Content */}
        <div className="flex-1 p-6 overflow-y-auto">
          {activeTab === 'amplitude' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-bold text-white">Acoustic Amplitude Frequency Response (dB SPL vs Log Hz)</h2>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setShowWoofer(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showWoofer ? 'bg-blue-950/60 border-blue-500 text-blue-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showWoofer ? 'bg-blue-500' : 'bg-slate-600'}`}></span>
                    <span>Woofer (LP)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTweeter(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTweeter ? 'bg-red-950/60 border-red-500 text-red-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTweeter ? 'bg-red-500' : 'bg-slate-600'}`}></span>
                    <span>Tweeter (HP)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTotalSystem(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTotalSystem ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTotalSystem ? 'bg-emerald-500' : 'bg-slate-600'}`}></span>
                    <span>Total System</span>
                  </button>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={amplitudeCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'phase' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">Acoustic Phase & Driver Alignment (Degrees vs Log Hz)</h2>
                  <p className={`text-xs mt-0.5 ${
                    enableAllpass
                      ? (apfOptimization?.alignmentStatus?.level === 'green'
                          ? 'text-emerald-400'
                          : (apfOptimization?.alignmentStatus?.level === 'yellow' ? 'text-amber-400' : 'text-red-400'))
                      : 'text-slate-400'
                  }`}>
                    {enableAllpass
                      ? `All-Pass Optimization: F0 = ${Math.round(apfOptimization?.f0 || fx)} Hz, Q = ${(apfOptimization?.q || 0.7).toFixed(2)} • Residual RMS: ${(apfOptimization?.rmsErrorDeg || 0).toFixed(1)}° • ${apfOptimization?.alignmentStatus?.label || 'Phase Aligned (Optimal)'}`
                      : (compensateTweeterDelay
                          ? `Acoustic Center Depth Delay (${acousticDelayMM.toFixed(1)} mm / ${((acousticDelayMM / 1000.0) / 343.0 * 1000.0).toFixed(2)} ms) Compensated`
                          : `Acoustic Delay Offset: ${acousticDelayMM} mm • Tweeter Polarity: ${invertTweeterPolarity ? 'Inverted (-)' : 'Normal (+)'}`
                        )
                    }
                  </p>
                </div>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setShowWoofer(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showWoofer ? 'bg-blue-950/60 border-blue-500 text-blue-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showWoofer ? 'bg-blue-500' : 'bg-slate-600'}`}></span>
                    <span>Woofer</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTweeter(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTweeter ? 'bg-red-950/60 border-red-500 text-red-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTweeter ? 'bg-red-500' : 'bg-slate-600'}`}></span>
                    <span>Tweeter</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTotalSystem(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTotalSystem ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTotalSystem ? 'bg-emerald-500' : 'bg-slate-600'}`}></span>
                    <span>Total System</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowPhaseDiff(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showPhaseDiff ? 'bg-amber-950/60 border-amber-500 text-amber-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showPhaseDiff ? 'bg-amber-500' : 'bg-slate-600'}`}></span>
                    <span>ΔΦ (Diff)</span>
                  </button>
                  <div className="h-4 w-px bg-slate-700 mx-1"></div>
                  <label className="flex items-center space-x-1.5 text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={unwrapPhase}
                      onChange={(e) => setUnwrapPhase(e.target.checked)}
                      className="rounded border-slate-600 text-blue-500 focus:ring-0"
                    />
                    <span>Unwrap Phase</span>
                  </label>
                  <label className="flex items-center space-x-1.5 text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={compensateTweeterDelay}
                      onChange={(e) => setCompensateTweeterDelay(e.target.checked)}
                      className="rounded border-slate-600 text-blue-500 focus:ring-0"
                    />
                    <span>Compensate Delay</span>
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setDetachedPlots(prev => ({ ...prev, phase: true }));
                      setActiveTab('crossover');
                    }}
                    className="flex items-center space-x-1 px-2.5 py-1 rounded-md border border-blue-500/50 bg-blue-950/40 text-blue-300 hover:bg-blue-900/50 transition cursor-pointer"
                    title="Detach Phase & Delay to Live Crossover Monitor"
                  >
                    <span>↗ Detach</span>
                  </button>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={phaseCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'delay' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">Acoustic & Electrical Group Delay (Milliseconds vs Log Hz)</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Tweeter Delay Offset: {acousticDelayMM} mm ({((acousticDelayMM / 1000.0) / 343.0 * 1000.0).toFixed(2)} ms) • Polarity: {invertTweeterPolarity ? 'Inverted (-)' : 'Normal (+)'} {enableAllpass ? `• APF Delay Active (${Math.round(apfOptimization?.f0 || fx)} Hz)` : ''}
                  </p>
                </div>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setShowWoofer(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showWoofer ? 'bg-blue-950/60 border-blue-500 text-blue-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showWoofer ? 'bg-blue-500' : 'bg-slate-600'}`}></span>
                    <span>Woofer GD</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTweeter(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTweeter ? 'bg-red-950/60 border-red-500 text-red-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTweeter ? 'bg-red-500' : 'bg-slate-600'}`}></span>
                    <span>Tweeter GD</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTotalSystem(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTotalSystem ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTotalSystem ? 'bg-emerald-500' : 'bg-slate-600'}`}></span>
                    <span>Total System GD</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setDetachedPlots(prev => ({ ...prev, delay: true }));
                      setActiveTab('crossover');
                    }}
                    className="flex items-center space-x-1 px-2.5 py-1 rounded-md border border-blue-500/50 bg-blue-950/40 text-blue-300 hover:bg-blue-900/50 transition cursor-pointer"
                    title="Detach Group Delay to Live Crossover Monitor"
                  >
                    <span>↗ Detach</span>
                  </button>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={groupDelayCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'step' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">Transient Acoustic Step Response (Normalized Amplitude vs Time)</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Acoustic Delay Offset: {acousticDelayMM} mm ({((acousticDelayMM / 1000.0) / 343.0 * 1000.0).toFixed(2)} ms) • Tweeter Polarity: {invertTweeterPolarity ? 'Inverted (-)' : 'Normal (+)'} • All-Pass Comp: {enableAllpass ? 'Enabled (Active)' : 'Disabled'}
                  </p>
                </div>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setShowWoofer(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showWoofer ? 'bg-blue-950/60 border-blue-500 text-blue-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showWoofer ? 'bg-blue-500' : 'bg-slate-600'}`}></span>
                    <span>Woofer (LP)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTweeter(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTweeter ? 'bg-red-950/60 border-red-500 text-red-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTweeter ? 'bg-red-500' : 'bg-slate-600'}`}></span>
                    <span>Tweeter (HP)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTotalSystem(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTotalSystem ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTotalSystem ? 'bg-emerald-500' : 'bg-slate-600'}`}></span>
                    <span>Total System</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setDetachedPlots(prev => ({ ...prev, step: true }));
                      setActiveTab('crossover');
                    }}
                    className="flex items-center space-x-1 px-2.5 py-1 rounded-md border border-blue-500/50 bg-blue-950/40 text-blue-300 hover:bg-blue-900/50 transition cursor-pointer"
                    title="Detach Step Response to Live Crossover Monitor"
                  >
                    <span>↗ Detach</span>
                  </button>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={stepCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'impedance' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">System Electrical Load Impedance (|Z| in Ohms vs Log Hz)</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Sealed Box Resonance Fc: {cabinetCalculations.fc.toFixed(1)} Hz • Box Alpha: {cabinetCalculations.alpha.toFixed(2)} • Enclosure Qb: {cabinetCalculations.qbVal.toFixed(1)} • Min System Load: {Math.min(...simulationData.map(p => p.zTotalMag || 100)).toFixed(1)} Ω
                  </p>
                </div>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setShowWoofer(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showWoofer ? 'bg-blue-950/60 border-blue-500 text-blue-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showWoofer ? 'bg-blue-500' : 'bg-slate-600'}`}></span>
                    <span>Woofer |Z|</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTweeter(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTweeter ? 'bg-red-950/60 border-red-500 text-red-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTweeter ? 'bg-red-500' : 'bg-slate-600'}`}></span>
                    <span>Tweeter |Z|</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowTotalSystem(prev => !prev)}
                    className={`flex items-center space-x-1.5 px-2.5 py-1 rounded-md border transition cursor-pointer ${showTotalSystem ? 'bg-purple-950/60 border-purple-500 text-purple-300' : 'bg-slate-800/40 border-slate-700 text-slate-500'}`}
                  >
                    <span className={`w-2.5 h-2.5 rounded-full ${showTotalSystem ? 'bg-purple-500' : 'bg-slate-600'}`}></span>
                    <span>System Load |Z|</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setDetachedPlots(prev => ({ ...prev, impedance: true }));
                      setActiveTab('crossover');
                    }}
                    className="flex items-center space-x-1 px-2.5 py-1 rounded-md border border-blue-500/50 bg-blue-950/40 text-blue-300 hover:bg-blue-900/50 transition cursor-pointer"
                    title="Detach System Impedance to Live Crossover Monitor"
                  >
                    <span>↗ Detach</span>
                  </button>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={impedanceCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'cabinet' && (
            <div className="max-w-3xl space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-white flex items-center space-x-2">
                  <Box className="text-blue-400" />
                  <span>{enclosureType === 'sealed' ? 'Closed (Sealed) Cabinet Designer' : '4th-Order Vented (Bass-Reflex) Designer'}</span>
                </h2>
                <button
                  type="button"
                  onClick={() => {
                    const typeStr = enclosureType === 'vented' ? `Vented (Fb = ${cabinetCalculations.fb.toFixed(1)} Hz)` : `Sealed (Qtc = ${cabinetCalculations.actualQtc.toFixed(3)})`;
                    setStatusMsg(`Simulation updated: ${typeStr}, Vb = ${cabinetCalculations.vb.toFixed(1)} L, f3 = ${cabinetCalculations.actualF3.toFixed(1)} Hz.`);
                  }}
                  className="bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs px-3 py-2 rounded-lg flex items-center space-x-2 transition cursor-pointer"
                >
                  <RefreshCw className="w-4 h-4" />
                  <span>Restart Simulation</span>
                </button>
              </div>

              {/* Architecture Selector */}
              <div className="flex items-center space-x-3 p-1.5 bg-slate-900 border border-slate-800 rounded-xl">
                <button
                  type="button"
                  onClick={() => setEnclosureType('sealed')}
                  className={`flex-1 py-2 text-xs font-semibold rounded-lg transition cursor-pointer ${enclosureType === 'sealed' ? 'bg-blue-600 text-white shadow' : 'text-slate-400 hover:text-white'}`}
                >
                  Sealed Enclosure (2nd-Order, 12 dB/oct)
                </button>
                <button
                  type="button"
                  onClick={() => setEnclosureType('vented')}
                  className={`flex-1 py-2 text-xs font-semibold rounded-lg transition cursor-pointer ${enclosureType === 'vented' ? 'bg-teal-600 text-white shadow' : 'text-slate-400 hover:text-white'}`}
                >
                  Vented Bass-Reflex (4th-Order, 24 dB/oct)
                </button>
              </div>

              {enclosureType === 'sealed' && cabinetCalculations.effectiveQts < 0.40 && (
                <div className="bg-blue-500/10 border border-blue-500/30 text-blue-300 p-4 rounded-xl text-xs flex items-start space-x-2.5">
                  <Shield className="w-4 h-4 text-blue-400 shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold text-white mb-0.5">Pro-Audio Coaxial Driver Note (Qts = {cabinetCalculations.effectiveQts.toFixed(3)})</p>
                    <p className="text-slate-300 text-[11px] leading-relaxed">High-efficiency coaxial woofers naturally have low Qts (0.25–0.35) and produce f3 ≈ 90–115 Hz in a sealed cabinet. Switch to <strong>Vented Bass-Reflex</strong> above to extend low-bass extension down to 35–45 Hz.</p>
                  </div>
                </div>
              )}

              {enclosureType === 'vented' && (
                <div className="bg-teal-500/10 border border-teal-500/30 text-teal-300 p-4 rounded-xl text-xs flex items-start space-x-2.5">
                  <Box className="w-4 h-4 text-teal-400 shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold text-white mb-0.5">4th-Order Helmholtz Acoustic Loading Active</p>
                    <p className="text-slate-300 text-[11px] leading-relaxed">Bass-reflex loading controls driver cone excursion at port resonance Fb ({cabinetCalculations.fb.toFixed(1)} Hz) and extends -3 dB cutoff to {cabinetCalculations.actualF3.toFixed(1)} Hz with a 24 dB/oct steep high-pass acoustic slope.</p>
                  </div>
                </div>
              )}

              {cabinetCalculations.warningMsg && (
                <div className="bg-amber-500/10 border border-amber-500/30 text-amber-300 p-4 rounded-xl text-xs flex items-start space-x-2.5">
                  <AlertCircle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                  <span>{cabinetCalculations.warningMsg}</span>
                </div>
              )}

              <div className="bg-slate-900 p-6 rounded-xl border border-slate-800 space-y-4">
                {enclosureType === 'sealed' ? (
                  <>
                    <div>
                      <label className="text-slate-400 text-xs">Sealed Alignment Design Mode</label>
                      <select value={alignment} onChange={(e) => setAlignment(e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-2 text-white mt-1 text-xs">
                        <option value="targetF3">Target Cut-off Frequency (f3)</option>
                        <option value="butterworth">Butterworth B2 (Qtc = 0.707 - Maximally Flat)</option>
                        <option value="bessel">Bessel (Qtc = 0.577 - Best Transient Response)</option>
                        <option value="critical">Critically Damped (Qtc = 0.500 - No Overshoot)</option>
                        <option value="custom">Custom Qtc Alignment</option>
                      </select>
                    </div>

                    {alignment === 'targetF3' && (
                      <div>
                        <div className="flex items-center justify-between text-xs">
                          <label className="font-semibold text-slate-400">
                            Target Lower -3 dB Cut-off Frequency (f3): {targetF3} Hz
                          </label>
                          {targetF3 < cabinetCalculations.minFeasibleF3 && (
                            <span className="text-amber-400 font-semibold text-[11px]">
                              (Sealed Min: {cabinetCalculations.minFeasibleF3.toFixed(1)} Hz)
                            </span>
                          )}
                        </div>
                        <input type="range" min="25" max="250" value={targetF3} onChange={(e) => setTargetF3(+e.target.value)} className="w-full mt-2" />
                      </div>
                    )}

                    {alignment === 'custom' && (
                      <div>
                        <label className="text-xs font-semibold text-slate-400">Target Total System Q (Qtc): {customQtc.toFixed(3)}</label>
                        <input type="range" min="0.35" max="1.20" step="0.01" value={customQtc} onChange={(e) => setCustomQtc(+e.target.value)} className="w-full mt-2" />
                      </div>
                    )}
                  </>
                ) : (
                  <>
                    <div>
                      <label className="text-slate-400 text-xs">Vented Alignment Preset</label>
                      <select value={ventedAlignment} onChange={(e) => setVentedAlignment(e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-2 text-white mt-1 text-xs">
                        <option value="qb3">QB3 (Quasi-Butterworth 3 - Best for Low Qts Pro Transducers)</option>
                        <option value="b4">B4 (Butterworth 4 - Maximally Flat)</option>
                        <option value="sc4">SC4 (Sub-Chebyshev 4 - Compact Enclosure)</option>
                        <option value="custom">Custom Tuning (Fb & Vb)</option>
                      </select>
                    </div>

                    <div>
                      <div className="flex items-center justify-between text-xs">
                        <label className="font-semibold text-teal-300">Port Helmholtz Tuning Frequency (Fb): {cabinetCalculations.fb.toFixed(1)} Hz</label>
                      </div>
                      <input type="range" min="18" max="80" step="0.5" value={tuningFb} onChange={(e) => setTuningFb(+e.target.value)} className="w-full mt-2" />
                    </div>

                    <div className="space-y-3 p-3 bg-slate-800/50 border border-slate-700/60 rounded-lg text-xs">
                      <div className="font-semibold text-slate-200">Port Duct Dimensions & Anti-Chuffing Design</div>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="text-slate-400">Port Duct Diameter (Dv): {portDiameterCm} cm ({(portDiameterCm / 2.54).toFixed(1)} in)</label>
                          <input type="range" min="5" max="20" step="0.5" value={portDiameterCm} onChange={(e) => setPortDiameterCm(+e.target.value)} className="w-full mt-1.5" />
                        </div>
                        <div>
                          <label className="text-slate-400">Number of Ports</label>
                          <select value={portCount} onChange={(e) => setPortCount(+e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-1.5 text-white mt-1">
                            <option value={1}>1 Port Tube</option>
                            <option value={2}>2 Port Tubes</option>
                            <option value={3}>3 Port Tubes</option>
                          </select>
                        </div>
                      </div>

                      <div className="flex items-center justify-between pt-2 border-t border-slate-700/50 text-[11px]">
                        <div>
                          <span className="text-slate-400">Calculated Port Duct Length: </span>
                          <span className="font-bold text-teal-300">{cabinetCalculations.portLengthCm.toFixed(1)} cm ({(cabinetCalculations.portLengthCm / 2.54).toFixed(2)} inches)</span>
                        </div>
                        <div className={portDiameterCm < cabinetCalculations.minPortDiameterCm ? "text-amber-300" : "text-slate-400"}>
                          <span>Min Recommended Port Dia: ≥ {cabinetCalculations.minPortDiameterCm.toFixed(1)} cm</span>
                        </div>
                      </div>
                    </div>
                  </>
                )}

                <div>
                  <label className="text-slate-400 text-xs">Acoustic Polyfill Stuffing Level</label>
                  <select value={stuffingGain} onChange={(e) => setStuffingGain(+e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-2 text-white mt-1 text-xs">
                    <option value={1.00}>Unfilled / Minimal (0% Acoustic Volume Gain)</option>
                    <option value={1.10}>Light Lining (+10% Acoustic Volume Gain)</option>
                    <option value={1.18}>Medium Polyfill (+18% Acoustic Volume Gain)</option>
                    <option value={1.25}>Heavy 100% Polyfill (+25% Acoustic Volume Gain)</option>
                  </select>
                </div>

                <div className="pt-2">
                  <label className="flex items-center space-x-2 text-xs text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={manualVbOverride}
                      onChange={(e) => setManualVbOverride(e.target.checked)}
                      className="rounded border-slate-700 bg-slate-800 text-blue-600 focus:ring-blue-500"
                    />
                    <span>Manual Enclosure Volume Override (Vb)</span>
                  </label>
                  {manualVbOverride && (
                    <div className="mt-2 space-y-2 text-xs">
                      <div className="flex items-center space-x-3">
                        <span className="text-slate-400">Net Internal Volume:</span>
                        <input
                          type="number"
                          step="0.5"
                          min="5"
                          max="300"
                          value={manualVbLiters}
                          onChange={(e) => setManualVbLiters(+e.target.value)}
                          className="bg-slate-800 border border-slate-700 rounded px-2.5 py-1 text-white w-24 font-mono"
                        />
                        <span className="text-slate-400">Liters ({(manualVbLiters / 28.3168).toFixed(2)} ft³)</span>
                      </div>
                      <input
                        type="range"
                        min="5"
                        max="300"
                        step="0.5"
                        value={manualVbLiters}
                        onChange={(e) => setManualVbLiters(+e.target.value)}
                        className="w-full"
                      />
                    </div>
                  )}
                </div>

                <div className="grid grid-cols-2 md:grid-cols-3 gap-3 text-xs pt-4 border-t border-slate-800">
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">Physical Box Volume (Vb)</p>
                    <p className="text-xl font-bold text-blue-400 mt-1">{cabinetCalculations.vb.toFixed(2)} L</p>
                    <p className="text-[10px] text-slate-400 mt-0.5">{cabinetCalculations.physicalCuFt.toFixed(2)} cu ft</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">Effective Acoustic Volume</p>
                    <p className="text-xl font-bold text-teal-400 mt-1">{cabinetCalculations.acousticVb.toFixed(2)} L</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">{enclosureType === 'vented' ? 'Port Tuning (Fb)' : 'System Resonance (Fc)'}</p>
                    <p className="text-xl font-bold text-emerald-400 mt-1">{enclosureType === 'vented' ? cabinetCalculations.fb.toFixed(1) : cabinetCalculations.fc.toFixed(1)} Hz</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">{enclosureType === 'vented' ? 'Required Port Length' : 'Total System Q (Qtc)'}</p>
                    <p className="text-xl font-bold text-purple-400 mt-1">{enclosureType === 'vented' ? `${cabinetCalculations.portLengthCm.toFixed(1)} cm` : cabinetCalculations.actualQtc.toFixed(3)}</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">Cutoff Frequency (f3)</p>
                    <p className="text-xl font-bold text-green-400 mt-1">{cabinetCalculations.actualF3.toFixed(1)} Hz</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">Compliance Ratio (α)</p>
                    <p className="text-xl font-bold text-indigo-400 mt-1">{cabinetCalculations.alpha.toFixed(2)}</p>
                  </div>
                </div>
              </div>

              {/* Sizing Comparison Matrix Table */}
              <div className="bg-slate-900 p-5 rounded-xl border border-slate-800 space-y-3 text-xs">
                <h3 className="font-bold text-slate-200">
                  {enclosureType === 'vented' ? `Vented & Sealed Alignment Comparison for ${driverName}` : `Qtc vs Box Volume Sizing Matrix for ${driverName}`}
                </h3>
                <p className="text-slate-400 text-[11px]">
                  Comparison of required physical box volumes and resulting cutoff frequencies for driver Qts = {cabinetCalculations.effectiveQts.toFixed(3)}:
                </p>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-slate-300">
                    <thead className="text-[11px] text-slate-400 uppercase border-b border-slate-800">
                      <tr>
                        <th className="py-2 px-2">Alignment</th>
                        <th className="py-2 px-2">Type</th>
                        <th className="py-2 px-2">Physical Vb (L)</th>
                        <th className="py-2 px-2">Physical Vb (cu ft)</th>
                        <th className="py-2 px-2">Tuning / Res</th>
                        <th className="py-2 px-2">Cutoff (f3)</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60">
                      {enclosureType === 'vented' ? (
                        [
                          { name: "QB3 (Quasi-Butterworth)", type: "Vented", vb: 3.0 * Math.pow(cabinetCalculations.effectiveQts, 2.0) * ts.vas / stuffingGain, fb: 0.42 * Math.pow(Math.max(cabinetCalculations.effectiveQts, 0.1), -0.9) * ts.fs, f3: 0.26 * Math.pow(Math.max(cabinetCalculations.effectiveQts, 0.1), -1.4) * ts.fs },
                          { name: "B4 (Butterworth 4)", type: "Vented", vb: 11.0 * Math.pow(cabinetCalculations.effectiveQts, 3.3) * ts.vas / stuffingGain, fb: 0.42 * Math.pow(Math.max(cabinetCalculations.effectiveQts, 0.1), -0.9) * ts.fs, f3: ts.fs },
                          { name: "SC4 (Sub-Chebyshev)", type: "Vented", vb: 2.0 * Math.pow(cabinetCalculations.effectiveQts, 1.5) * ts.vas / stuffingGain, fb: 0.85 * ts.fs, f3: 0.35 * Math.pow(Math.max(cabinetCalculations.effectiveQts, 0.1), -1.1) * ts.fs },
                          { name: "Butterworth B2", type: "Sealed", vb: (ts.vas / (Math.pow(0.7071 / Math.max(cabinetCalculations.effectiveQts, 0.01), 2) - 1.0)) / stuffingGain, fb: ts.fs * (0.7071 / Math.max(cabinetCalculations.effectiveQts, 0.01)), f3: ts.fs * (0.7071 / Math.max(cabinetCalculations.effectiveQts, 0.01)) }
                        ].map((row) => (
                          <tr key={row.name}>
                            <td className="py-2 px-2 font-medium text-teal-400">{row.name}</td>
                            <td className="py-2 px-2 text-slate-400">{row.type}</td>
                            <td className="py-2 px-2 font-semibold text-white">{Math.max(row.vb, 5.0).toFixed(1)} L</td>
                            <td className="py-2 px-2">{(Math.max(row.vb, 5.0) / 28.3168).toFixed(2)} ft³</td>
                            <td className="py-2 px-2">{row.fb.toFixed(1)} Hz</td>
                            <td className="py-2 px-2 font-bold text-green-400">{row.f3.toFixed(1)} Hz</td>
                          </tr>
                        ))
                      ) : (
                        [
                          ["Butterworth B2", 0.7071],
                          ["Bessel Alignment", 0.5774],
                          ["Critically Damped", 0.5000],
                          ["Extended Low Q", 0.4500],
                          ["Large Box Low Q", 0.4000]
                        ].map(([name, targetQ]) => {
                          const effQ = cabinetCalculations.effectiveQts;
                          if (targetQ <= effQ) {
                            return (
                              <tr key={name} className="text-slate-500">
                                <td className="py-2 px-2 font-medium">{name}</td>
                                <td className="py-2 px-2">{targetQ.toFixed(4)}</td>
                                <td className="py-2 px-2 italic" colSpan="4">N/A (Target Qtc ≤ Driver Qts {effQ.toFixed(3)})</td>
                              </tr>
                            );
                          }
                          const ratio = targetQ / effQ;
                          const a = Math.pow(ratio, 2) - 1.0;
                          const acVb = ts.vas / a;
                          const physVb = acVb / stuffingGain;
                          const physFt = physVb / 28.3168;
                          const f_c = ts.fs * Math.sqrt(1.0 + a);
                          const b_val = (1.0 / Math.pow(targetQ, 2)) - 2.0;
                          const x_val = (b_val + Math.sqrt(b_val * b_val + 4.0)) / 2.0;
                          const f3_val = f_c * Math.sqrt(x_val);
                          return (
                            <tr key={name}>
                              <td className="py-2 px-2 font-medium text-blue-400">{name}</td>
                              <td className="py-2 px-2">Qtc {targetQ.toFixed(4)}</td>
                              <td className="py-2 px-2 font-semibold text-white">{physVb.toFixed(2)} L</td>
                              <td className="py-2 px-2">{physFt.toFixed(2)} ft³</td>
                              <td className="py-2 px-2">{f_c.toFixed(1)} Hz</td>
                              <td className="py-2 px-2 font-bold text-green-400">{f3_val.toFixed(1)} Hz</td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'crossover' && (
            <div className="space-y-6">
              <div className="flex flex-wrap items-center justify-between gap-3 max-w-6xl">
                <h2 className="text-xl font-bold text-white flex items-center space-x-2"><Sliders className="text-blue-400" /><span>Coaxial Crossover Designer</span></h2>
                <div className="flex items-center space-x-2 text-xs">
                  <button
                    type="button"
                    onClick={openLiveMonitorGrid}
                    className="bg-blue-600 hover:bg-blue-500 text-white font-semibold px-3 py-1.5 rounded-lg transition cursor-pointer shadow-sm"
                  >
                    Open 2×2 Live Monitor Grid
                  </button>
                  {hasDetachedPlots && (
                    <button
                      type="button"
                      onClick={closeAllDetachedPlots}
                      className="bg-slate-800 hover:bg-slate-700 border border-slate-600 text-slate-200 font-medium px-3 py-1.5 rounded-lg transition cursor-pointer"
                    >
                      Close All Windows
                    </button>
                  )}
                </div>
              </div>

              {/* Detached Live Curve Windows Launcher Bar */}
              <div className="max-w-6xl bg-slate-900/90 p-4 rounded-xl border border-slate-800 space-y-2.5">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-200">Detached Live Curve Windows (Real-Time Crossover Monitor)</span>
                  <span className="text-[11px] text-slate-400">Changes in the Crossover Designer reflect immediately in detached plots</span>
                </div>
                <div className="flex flex-wrap items-center gap-2 text-xs">
                  {[
                    { key: 'amplitude', label: 'Amplitude Response' },
                    { key: 'phase', label: 'Phase & Delay' },
                    { key: 'delay', label: 'Group Delay' },
                    { key: 'step', label: 'Step Response' },
                    { key: 'impedance', label: 'System Impedance' }
                  ].map(item => (
                    <button
                      key={item.key}
                      type="button"
                      onClick={() => toggleDetachedPlot(item.key)}
                      className={`px-3 py-1.5 rounded-lg border font-medium transition cursor-pointer flex items-center space-x-1.5 ${
                        detachedPlots[item.key]
                          ? 'bg-blue-600/20 border-blue-500 text-blue-300'
                          : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
                      }`}
                    >
                      <span>{detachedPlots[item.key] ? '✓' : '↗'}</span>
                      <span>{item.label}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Detached Live Plots 2x2 Grid Monitor */}
              {hasDetachedPlots && (
                <div className="max-w-6xl grid grid-cols-1 lg:grid-cols-2 gap-4">
                  {detachedPlots.amplitude && (
                    <div className="bg-slate-900 border border-blue-500/40 rounded-xl p-3.5 shadow-xl space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-white">Amplitude Response (dB SPL vs Log Hz) — Live</span>
                        <button
                          type="button"
                          onClick={() => toggleDetachedPlot('amplitude')}
                          className="text-slate-400 hover:text-white px-1.5 py-0.5 rounded hover:bg-slate-800 cursor-pointer"
                        >
                          ✕
                        </button>
                      </div>
                      <canvas ref={detachedAmplitudeCanvasRef} width={600} height={260} className="w-full h-[240px]" />
                    </div>
                  )}
                  {detachedPlots.phase && (
                    <div className="bg-slate-900 border border-blue-500/40 rounded-xl p-3.5 shadow-xl space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-white">Phase & Delay (Degrees vs Log Hz) — Live</span>
                        <button
                          type="button"
                          onClick={() => toggleDetachedPlot('phase')}
                          className="text-slate-400 hover:text-white px-1.5 py-0.5 rounded hover:bg-slate-800 cursor-pointer"
                        >
                          ✕
                        </button>
                      </div>
                      <canvas ref={detachedPhaseCanvasRef} width={600} height={260} className="w-full h-[240px]" />
                    </div>
                  )}
                  {detachedPlots.delay && (
                    <div className="bg-slate-900 border border-blue-500/40 rounded-xl p-3.5 shadow-xl space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-white">Group Delay (ms vs Log Hz) — Live</span>
                        <button
                          type="button"
                          onClick={() => toggleDetachedPlot('delay')}
                          className="text-slate-400 hover:text-white px-1.5 py-0.5 rounded hover:bg-slate-800 cursor-pointer"
                        >
                          ✕
                        </button>
                      </div>
                      <canvas ref={detachedGroupDelayCanvasRef} width={600} height={260} className="w-full h-[240px]" />
                    </div>
                  )}
                  {detachedPlots.impedance && (
                    <div className="bg-slate-900 border border-blue-500/40 rounded-xl p-3.5 shadow-xl space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-white">System Impedance (|Z| in Ω vs Log Hz) — Live</span>
                        <button
                          type="button"
                          onClick={() => toggleDetachedPlot('impedance')}
                          className="text-slate-400 hover:text-white px-1.5 py-0.5 rounded hover:bg-slate-800 cursor-pointer"
                        >
                          ✕
                        </button>
                      </div>
                      <canvas ref={detachedImpedanceCanvasRef} width={600} height={260} className="w-full h-[240px]" />
                    </div>
                  )}
                  {detachedPlots.step && (
                    <div className="bg-slate-900 border border-blue-500/40 rounded-xl p-3.5 shadow-xl space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-bold text-white">Step Response (Amplitude vs Time) — Live</span>
                        <button
                          type="button"
                          onClick={() => toggleDetachedPlot('step')}
                          className="text-slate-400 hover:text-white px-1.5 py-0.5 rounded hover:bg-slate-800 cursor-pointer"
                        >
                          ✕
                        </button>
                      </div>
                      <canvas ref={detachedStepCanvasRef} width={600} height={260} className="w-full h-[240px]" />
                    </div>
                  )}
                </div>
              )}

              <div className="max-w-3xl bg-slate-900 p-6 rounded-xl border border-slate-800 space-y-5">
                <div className="space-y-4">
                  <label className="flex items-center space-x-2 text-xs text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={enableIndependentFx}
                      onChange={(e) => setEnableIndependentFx(e.target.checked)}
                      className="rounded bg-slate-800 border-slate-700 text-blue-600"
                    />
                    <span className="font-medium">Specify Independent Cut-off Frequencies for Woofer & Tweeter</span>
                  </label>

                  {!enableIndependentFx ? (
                    <div>
                      <div className="flex items-center justify-between">
                        <label className="text-xs font-semibold text-slate-400">Crossover Frequency (fx): {fx} Hz</label>
                      </div>
                      <input type="range" min="800" max="6000" step="25" value={fx} onChange={(e) => setFx(+e.target.value)} className="w-full mt-2" />
                    </div>
                  ) : (
                    <div className="space-y-3 p-3 bg-slate-800/50 border border-slate-700/60 rounded-lg">
                      <div>
                        <div className="flex items-center justify-between text-xs">
                          <label className="font-semibold text-blue-400">Woofer Low-Pass Cut-off (fx,woofer): {wooferFx} Hz</label>
                        </div>
                        <input type="range" min="800" max="6000" step="25" value={wooferFx} onChange={(e) => setWooferFx(+e.target.value)} className="w-full mt-1.5" />
                      </div>
                      <div>
                        <div className="flex items-center justify-between text-xs">
                          <label className="font-semibold text-red-400">Tweeter High-Pass Cut-off (fx,tweeter): {tweeterFx} Hz</label>
                        </div>
                        <input type="range" min="800" max="6000" step="25" value={tweeterFx} onChange={(e) => setTweeterFx(+e.target.value)} className="w-full mt-1.5" />
                      </div>
                      <div className="text-[11px] text-slate-400 pt-1 border-t border-slate-700/40 flex items-center justify-between">
                        <span>Acoustic Handover Center: {Math.round(Math.sqrt(wooferFx * tweeterFx))} Hz</span>
                        <span className={tweeterFx > wooferFx ? "text-amber-300" : (tweeterFx < wooferFx ? "text-indigo-300" : "text-emerald-300")}>
                          {tweeterFx > wooferFx ? `+${tweeterFx - wooferFx} Hz Underlap (Gap)` : (tweeterFx < wooferFx ? `${wooferFx - tweeterFx} Hz Overlap` : 'Synchronous (0 Hz Gap)')}
                        </span>
                      </div>
                    </div>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-4 text-xs">
                  <div>
                    <label className="text-slate-400">Woofer Filter Order</label>
                    <select value={wooferOrder} onChange={(e) => setWooferOrder(e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-2 text-white mt-1">
                      <option value="firstOrder">1st Order (6 dB/oct)</option>
                      <option value="secondOrderLR">2nd Order Linkwitz-Riley (12 dB/oct)</option>
                      <option value="fourthOrderLR">4th Order Linkwitz-Riley (24 dB/oct)</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-slate-400">Tweeter Filter Order</label>
                    <select value={tweeterOrder} onChange={(e) => setTweeterOrder(e.target.value)} className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-2 text-white mt-1">
                      <option value="firstOrder">1st Order (6 dB/oct)</option>
                      <option value="secondOrderLR">2nd Order Linkwitz-Riley (12 dB/oct)</option>
                      <option value="fourthOrderLR">4th Order Linkwitz-Riley (24 dB/oct)</option>
                    </select>
                  </div>
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-400">Coaxial Tweeter Depth Offset: {acousticDelayMM} mm</label>
                  <input type="range" min="0" max="100" value={acousticDelayMM} onChange={(e) => setAcousticDelayMM(+e.target.value)} className="w-full mt-2" />
                </div>
                <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-slate-800 text-xs">
                  <label className="flex items-center space-x-2 text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={invertTweeterPolarity}
                      onChange={(e) => setInvertTweeterPolarity(e.target.checked)}
                      className="rounded bg-slate-800 border-slate-700 text-blue-600"
                    />
                    <span className="font-medium">Invert Tweeter Polarity (+180°)</span>
                  </label>
                  <label className="flex items-center space-x-2 text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={snapToE12}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setSnapToE12(checked);
                        if (checked) setSnapToE24(false);
                      }}
                      className="rounded bg-slate-800 border-slate-700 text-blue-600"
                    />
                    <span className="font-medium">Snap Components to Commercial E12 Series</span>
                  </label>
                  <label className="flex items-center space-x-2 text-slate-300 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={snapToE24}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setSnapToE24(checked);
                        if (checked) setSnapToE12(false);
                      }}
                      className="rounded bg-slate-800 border-slate-700 text-blue-600"
                    />
                    <span className="font-medium">Snap Components to Commercial E24 Series</span>
                  </label>
                </div>
                <div className="pt-2 border-t border-slate-800 space-y-2">
                  <label className="flex items-center space-x-2 text-xs text-slate-300 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={enableAllpass} 
                      onChange={(e) => setEnableAllpass(e.target.checked)} 
                      className="rounded bg-slate-800 border-slate-700 text-blue-600"
                    />
                    <span className="font-medium">Enable All-Pass Woofer Delay Compensation Network</span>
                  </label>
                  <p className="text-[11px] text-slate-400 pl-5">
                    Inserts an optional 2nd-order all-pass delay network on the woofer branch to acoustically align phase with the physically recessed tweeter at {fx} Hz.
                  </p>

                  {enableAllpass && (
                    <div className="p-3 bg-teal-950/30 border border-teal-800/50 rounded-lg space-y-2 text-xs mt-2">
                      <div className="flex items-center justify-between text-teal-300 font-semibold">
                        <span>Nelder-Mead Phase Optimization</span>
                        <span className={
                          apfOptimization.alignmentStatus.level === 'green'
                            ? "text-emerald-400"
                            : (apfOptimization.alignmentStatus.level === 'yellow' ? "text-amber-400" : "text-red-400")
                        }>
                          RMS Phase Error: {apfOptimization.rmsErrorDeg.toFixed(2)}°
                        </span>
                      </div>
                      <div className="text-[11px] text-slate-400">
                        Optimal F0: {Math.round(apfOptimization.f0)} Hz • Optimal Q: {apfOptimization.q.toFixed(2)} • Alignment Window: [{Math.round(fx / 2)} Hz – {Math.round(fx * 2)} Hz]
                      </div>
                      <div className={`flex items-center space-x-2 p-2 rounded border text-[11px] font-semibold ${
                        apfOptimization.alignmentStatus.level === 'green'
                          ? 'bg-emerald-950/40 border-emerald-700/50 text-emerald-300'
                          : (apfOptimization.alignmentStatus.level === 'yellow'
                              ? 'bg-amber-950/40 border-amber-700/50 text-amber-300'
                              : 'bg-red-950/40 border-red-700/50 text-red-300')
                      }`}>
                        {apfOptimization.alignmentStatus.level === 'green' ? (
                          <Check className="w-4 h-4 shrink-0 text-emerald-400" />
                        ) : (
                          <AlertCircle className="w-4 h-4 shrink-0" />
                        )}
                        <span>{apfOptimization.alignmentStatus.label}</span>
                      </div>
                      {apfOptimization.warnings.map((warn, i) => (
                        <div key={i} className="flex items-start space-x-2 p-2 bg-amber-950/40 border border-amber-800/40 rounded text-amber-300 text-[11px]">
                          <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                          <span>{warn}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {activeTab === 'bom' && (
            <div className="max-w-3xl space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-white flex items-center space-x-2"><Cpu className="text-blue-400" /><span>Crossover Component Bill of Materials</span></h2>
                <button
                  onClick={() => window.print()}
                  className="bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs px-3 py-1.5 rounded-lg flex items-center space-x-2 transition"
                >
                  <FileText className="w-4 h-4" />
                  <span>Export PDF Schematic</span>
                </button>
              </div>
              {enableAllpass && (
                <div className={`p-3 rounded-xl border text-xs space-y-1.5 ${
                  apfOptimization.alignmentStatus.level === 'green'
                    ? 'bg-emerald-950/40 border-emerald-700/50 text-emerald-300'
                    : (apfOptimization.alignmentStatus.level === 'yellow'
                        ? 'bg-amber-950/40 border-amber-700/50 text-amber-300'
                        : 'bg-red-950/40 border-red-700/50 text-red-300')
                }`}>
                  <div className="flex items-center justify-between font-semibold">
                    <div className="flex items-center space-x-2">
                      {apfOptimization.alignmentStatus.level === 'green' ? (
                        <Check className="w-4 h-4 shrink-0 text-emerald-400" />
                      ) : (
                        <AlertCircle className="w-4 h-4 shrink-0" />
                      )}
                      <span>RMS Phase Alignment ({apfOptimization.rmsErrorDeg.toFixed(2)}°): {apfOptimization.alignmentStatus.label}</span>
                    </div>
                    <span className="text-[11px] opacity-80">F0 = {Math.round(apfOptimization.f0)} Hz • Q = {apfOptimization.q.toFixed(2)}</span>
                  </div>
                </div>
              )}
              <div className="bg-slate-900 rounded-xl border border-slate-800 p-6 space-y-4">
                <table className="w-full text-xs text-left text-slate-300">
                  <thead className="text-slate-400 border-b border-slate-800 uppercase text-[10px]">
                    <tr>
                      <th className="py-2">Designator</th>
                      <th className="py-2">Component</th>
                      <th className="py-2">Calculated Value</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {crossoverComponents.L1 && <tr><td className="py-2.5 font-bold text-blue-400">L1</td><td>Woofer Series Inductor</td><td>{crossoverComponents.L1.toFixed(2)} mH</td></tr>}
                    {crossoverComponents.C1 && <tr><td className="py-2.5 font-bold text-blue-400">C1</td><td>Woofer Parallel Capacitor</td><td>{crossoverComponents.C1.toFixed(2)} µF</td></tr>}
                    {crossoverComponents.C_HP1 && <tr><td className="py-2.5 font-bold text-red-400">C_HP1</td><td>Tweeter Series Capacitor</td><td>{crossoverComponents.C_HP1.toFixed(2)} µF</td></tr>}
                    {crossoverComponents.L_HP1 && <tr><td className="py-2.5 font-bold text-red-400">L_HP1</td><td>Tweeter Parallel Inductor</td><td>{crossoverComponents.L_HP1.toFixed(2)} mH</td></tr>}
                    {enableAllpass && crossoverComponents.L_AP && <tr><td className="py-2.5 font-bold text-teal-400">L_AP</td><td>Woofer All-Pass Inductor</td><td>{crossoverComponents.L_AP.toFixed(2)} mH</td></tr>}
                    {enableAllpass && crossoverComponents.C_AP && <tr><td className="py-2.5 font-bold text-teal-400">C_AP</td><td>Woofer All-Pass Capacitor</td><td>{crossoverComponents.C_AP.toFixed(2)} µF</td></tr>}
                    {crossoverComponents.R_zobel && <tr><td className="py-2.5 font-bold text-amber-400">R_zobel</td><td>Zobel Resistor</td><td>{crossoverComponents.R_zobel.toFixed(2)} Ω</td></tr>}
                    {crossoverComponents.C_zobel && <tr><td className="py-2.5 font-bold text-amber-400">C_zobel</td><td>Zobel Capacitor</td><td>{crossoverComponents.C_zobel.toFixed(2)} µF</td></tr>}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* About Modal Dialog */}
      {showAboutDialog && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 rounded-xl bg-blue-600/20 border border-blue-500/30 flex items-center justify-center text-blue-400 font-bold text-lg">
                  HP
                </div>
                <div>
                  <h3 className="font-bold text-white text-base">Coaxial Speaker Designer</h3>
                  <p className="text-xs text-blue-400 font-medium">Version 1.3.0 (Build 2026.10)</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setShowAboutDialog(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition cursor-pointer"
              >
                ✕
              </button>
            </div>

            <div className="text-xs text-slate-300 space-y-2.5">
              <p className="leading-relaxed">
                Professional engineering system for coaxial loudspeaker crossovers, phase alignment networks, and acoustic enclosures.
              </p>
              <div className="bg-slate-800/60 p-3 rounded-lg border border-slate-700/50 space-y-1.5 text-[11px] text-slate-300">
                <div className="font-semibold text-white mb-1">Key Features:</div>
                <div>• Independent Woofer & Tweeter Target Cut-Off Frequencies</div>
                <div>• Nelder-Mead All-Pass Filter Phase Alignment Optimizer</div>
                <div>• Phase Unwrapping & Acoustic Center Delay Compensation</div>
                <div>• Acoustic & Electrical Group Delay Analysis</div>
                <div>• Time-Domain Transient Step Response Engine</div>
                <div>• Vector 2-Page Schematic & BOM PDF Exporter</div>
              </div>
              <p className="text-[11px] text-slate-400">
                © 2026 Coaxial Speaker Designer • All rights reserved.
              </p>
            </div>

            <div className="pt-2 flex justify-end">
              <button
                type="button"
                onClick={() => setShowAboutDialog(false)}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold rounded-lg transition cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Help Modal Dialog */}
      {showHelpDialog && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center space-x-2.5">
                <div className="w-8 h-8 rounded-lg bg-blue-600/20 border border-blue-500/30 flex items-center justify-center text-blue-400 font-bold text-sm">
                  ?
                </div>
                <div>
                  <h3 className="font-bold text-white text-sm">Coaxial Speaker Designer — Quick Help Guide</h3>
                  <p className="text-[11px] text-slate-400">Step-by-step loudspeaker & crossover design workflow</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setShowHelpDialog(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition cursor-pointer"
              >
                ✕
              </button>
            </div>

            <div className="text-xs text-slate-300 space-y-3 max-h-[380px] overflow-y-auto pr-1">
              <div className="bg-slate-800/60 p-3 rounded-lg border border-slate-700/50 space-y-1">
                <div className="font-semibold text-white">1. Driver Setup & Datasheet Ingestion</div>
                <p className="text-[11px] text-slate-300 leading-relaxed">
                  Import a local PDF datasheet, paste a web URL, or load the <strong>Altec 604-8K Preset (CLIO)</strong>. T/S parameters (Fs, Qes, Qms, Qts, Vas, Re, Le, Sd, Xmax, SPL) and response curves are extracted automatically.
                </p>
              </div>
              <div className="bg-slate-800/60 p-3 rounded-lg border border-slate-700/50 space-y-1">
                <div className="font-semibold text-white">2. Sealed (2nd-Order) & Vented (4th-Order) Cabinets</div>
                <p className="text-[11px] text-slate-300 leading-relaxed">
                  Use <strong>Sealed</strong> for Qts ≥ 0.40 or <strong>Vented Bass-Reflex</strong> (QB3, B4, SC4) for low-Qts pro coaxial woofers. Keep port duct diameter above the recommended minimum to prevent port chuffing.
                </p>
              </div>
              <div className="bg-slate-800/60 p-3 rounded-lg border border-slate-700/50 space-y-1">
                <div className="font-semibold text-white">3. Crossover Tuning, Phase Optimizer & Live Windows</div>
                <p className="text-[11px] text-slate-300 leading-relaxed">
                  Click <strong>Open 2×2 Live Monitor Grid</strong> in the Crossover tab to watch all curves update live while adjusting sliders. Enable the <strong>All-Pass Network</strong> to phase-align recessed coaxial tweeters: Green (≤ 10° RMS) = Optimal, Yellow (10°–20°) = Acceptable, Red (&gt; 20°) = Invert polarity or adjust fx. Use <strong>E12</strong> or <strong>E24</strong> snapping for commercial component values.
                </p>
              </div>
              <div className="bg-slate-800/60 p-3 rounded-lg border border-slate-700/50 space-y-1">
                <div className="font-semibold text-white">4. Auto-Scaled Plots, Project Save & PDF Export</div>
                <p className="text-[11px] text-slate-300 leading-relaxed">
                  <strong>Group Delay</strong> and <strong>System Impedance</strong> auto-scale their vertical Y-axis to maximize resolution for visible traces. Save/Load complete projects as JSON or export a PDF schematic and BOM.
                </p>
              </div>
            </div>

            <div className="pt-2 flex items-center justify-between border-t border-slate-800">
              <span className="text-[11px] text-slate-400">Complete documentation available in HELP.md</span>
              <button
                type="button"
                onClick={() => setShowHelpDialog(false)}
                className="px-4 py-1.5 bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold rounded-lg transition cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

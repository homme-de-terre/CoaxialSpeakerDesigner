import React, { useState, useEffect, useMemo, useRef } from 'react';
import { parseDatasheetFromURL } from './utils/datasheetParser';
import { 
  Speaker, Volume2, Shield, Settings, Sliders, Cpu, FileText, Download, 
  Link, Check, AlertCircle, Copy, RotateCcw, Box, RefreshCw, Zap
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

// --- E12 Value Snapping ---
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

export default function App() {
  // --- State Variables ---
  const [activeTab, setActiveTab] = useState('amplitude'); // 'amplitude' | 'phase' | 'impedance' | 'cabinet' | 'crossover' | 'bom' | 'frd'

  // Driver Parameters
  const [driverName, setDriverName] = useState("8CX21 Coaxial 8-inch Driver");
  const [manufacturer, setManufacturer] = useState("AudioPro Coaxial");
  const [datasheetURL, setDatasheetURL] = useState("");
  const [isLoadingURL, setIsLoadingURL] = useState(false);
  const [statusMsg, setStatusMsg] = useState("");

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

  // Sealed Cabinet State
  const [alignment, setAlignment] = useState('butterworth'); // 'butterworth' | 'bessel' | 'critical' | 'custom' | 'targetF3'
  const [targetF3, setTargetF3] = useState(58.0);
  const [customQtc, setCustomQtc] = useState(0.707);
  const [stuffingGain, setStuffingGain] = useState(1.00); // 1.00 (Unfilled / Standard Vb), 1.10 (Light), 1.18 (Medium), 1.25 (Heavy)
  const [manualVbOverride, setManualVbOverride] = useState(false);
  const [manualVbLiters, setManualVbLiters] = useState(25.0);

  // Crossover Network State
  const [fx, setFx] = useState(2200);
  const [wooferOrder, setWooferOrder] = useState('secondOrderLR');
  const [tweeterOrder, setTweeterOrder] = useState('secondOrderLR');
  const [enableZobel, setEnableZobel] = useState(true);
  const [enableLPad, setEnableLPad] = useState(true);
  const [lpadAttenDB, setLpadAttenDB] = useState(5.0);
  const [acousticDelayMM, setAcousticDelayMM] = useState(35.0);
  const [invertTweeterPolarity, setInvertTweeterPolarity] = useState(false);
  const [snapToE12, setSnapToE12] = useState(false);

  // FRD Custom Data Strings
  const [wooferFRDText, setWooferFRDText] = useState("");
  const [tweeterFRDText, setTweeterFRDText] = useState("");

  // Canvas Refs for Bode Plots
  const amplitudeCanvasRef = useRef(null);
  const phaseCanvasRef = useRef(null);
  const impedanceCanvasRef = useRef(null);

  // --- Sealed Cabinet Computations ---
  const cabinetCalculations = useMemo(() => {
    // Determine effective Qts, Qes, Qms
    const effectiveQts = (ts.qts && ts.qts > 0)
      ? ts.qts
      : (ts.qes > 0 && ts.qms > 0 ? (ts.qes * ts.qms) / (ts.qes + ts.qms) : 0.35);

    const effectiveQes = ts.qes > 0 ? ts.qes : (effectiveQts * (ts.qms > 0 ? ts.qms : 4.5)) / Math.max((ts.qms > 0 ? ts.qms : 4.5) - effectiveQts, 0.01);
    const effectiveQms = ts.qms > 0 ? ts.qms : 4.5;

    // Map stuffing gain to enclosure absorption loss Qb
    let qbVal = 30.0;
    if (stuffingGain >= 1.24) qbVal = 4.0;
    else if (stuffingGain >= 1.17) qbVal = 7.0;
    else if (stuffingGain >= 1.08) qbVal = 15.0;

    let baseAlpha = 1.0;
    let warningMsg = "";

    const minFeasibleF3 = ts.fs * (0.7071 / Math.max(effectiveQts, 0.01));

    if (manualVbOverride) {
      baseAlpha = ts.vas / Math.max(manualVbLiters, 0.1);
    } else if (alignment === 'targetF3') {
      const r = Math.pow(targetF3 / Math.max(ts.fs, 1.0), 2);
      const q2 = Math.pow(effectiveQts, 2);
      const disc = 2.0 * r * r - (r / Math.max(q2, 1e-4));
      if (disc <= 0) {
        const ratio = 0.70710678 / Math.max(effectiveQts, 0.01);
        baseAlpha = Math.max(Math.pow(ratio, 2) - 1.0, 0.05);
        warningMsg = `Target f3 (${targetF3} Hz) is below the physical closed-box limit (${minFeasibleF3.toFixed(1)} Hz) for Qts = ${effectiveQts.toFixed(3)}. Aligned to Butterworth B2 (Qtc = 0.7071). A sealed enclosure cannot passively extend bass below infinite baffle limits without active EQ.`;
      } else {
        const y = r + Math.sqrt(disc);
        if (y <= 1.0) {
          const ratio = 0.70710678 / Math.max(effectiveQts, 0.01);
          baseAlpha = Math.max(Math.pow(ratio, 2) - 1.0, 0.05);
          warningMsg = `Target f3 (${targetF3} Hz) is below the physical closed-box limit (${minFeasibleF3.toFixed(1)} Hz) for Qts = ${effectiveQts.toFixed(3)}. Aligned to Butterworth B2.`;
        } else {
          baseAlpha = y - 1.0;
        }
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

    // Physical Volume of the enclosure
    const physicalVb = manualVbOverride ? manualVbLiters : (ts.vas / baseAlpha);
    const physicalCuFt = physicalVb / 28.3168;

    // Effective acoustic volume inside physical enclosure with polyfill stuffing
    const acousticVb = physicalVb * stuffingGain;
    const alpha = ts.vas / Math.max(acousticVb, 0.01);

    // System resonance Fc inside stuffed box
    const fc = ts.fs * Math.sqrt(1 + alpha);

    // System Q factors taking stuffing absorption loss Qb into account
    const qmsBox = effectiveQms * Math.sqrt(1 + alpha);
    const qmc = (qmsBox * qbVal) / (qmsBox + qbVal);
    const qec = effectiveQes * Math.sqrt(1 + alpha);
    const actualQtc = (qec * qmc) / (qec + qmc);

    // Exact f3 formula for 2nd order closed box
    const B = (1.0 / Math.pow(actualQtc, 2)) - 2.0;
    const x = (B + Math.sqrt(B * B + 4.0)) / 2.0;
    const actualF3 = fc * Math.sqrt(x);

    return { vb: physicalVb, acousticVb, physicalCuFt, fc, alpha, actualQtc, actualF3, effectiveQts, qbVal, minFeasibleF3, warningMsg };
  }, [ts, alignment, targetF3, customQtc, stuffingGain, manualVbOverride, manualVbLiters]);

  // --- Passive Crossover Component Calculations ---
  const crossoverComponents = useMemo(() => {
    const w = 2.0 * Math.PI * fx;
    const Zw = Math.max(ts.re, 4.0);
    const Zt = Math.max(tweeter.re, 4.0);

    let comp = {
      L1: null, C1: null, L2: null, C2: null,
      C_HP1: null, L_HP1: null, C_HP2: null, L_HP2: null,
      R_zobel: null, C_zobel: null,
      R1_lpad: null, R2_lpad: null
    };

    // Woofer Low-Pass
    if (wooferOrder === 'firstOrder') {
      comp.L1 = (Zw / w) * 1000.0;
    } else if (wooferOrder === 'secondOrderLR') {
      comp.L1 = (Zw / (w * Math.PI)) * 1000.0 * 2.0;
      comp.C1 = (1.0 / (2.0 * Math.PI * fx * Zw)) * 1e6;
    } else if (wooferOrder === 'secondOrderBW') {
      comp.L1 = ((Math.SQRT2 * Zw) / w) * 1000.0;
      comp.C1 = (1.0 / (Math.SQRT2 * w * Zw)) * 1e6;
    } else if (wooferOrder === 'fourthOrderLR') {
      comp.L1 = ((1.2 * Zw) / w) * 1000.0;
      comp.C1 = (0.33 / (w * Zw)) * 1e6;
      comp.L2 = ((0.4 * Zw) / w) * 1000.0;
      comp.C2 = (0.75 / (w * Zw)) * 1e6;
    }

    // Tweeter High-Pass
    if (tweeterOrder === 'firstOrder') {
      comp.C_HP1 = (1.0 / (w * Zt)) * 1e6;
    } else if (tweeterOrder === 'secondOrderLR') {
      comp.C_HP1 = (1.0 / (w * Zt)) * 1e6;
      comp.L_HP1 = (Zt / w) * 1000.0;
    } else if (tweeterOrder === 'secondOrderBW') {
      comp.C_HP1 = (1.0 / (Math.SQRT2 * w * Zt)) * 1e6;
      comp.L_HP1 = ((Math.SQRT2 * Zt) / w) * 1000.0;
    } else if (tweeterOrder === 'fourthOrderLR') {
      comp.C_HP1 = (1.0 / (1.2 * w * Zt)) * 1e6;
      comp.L_HP1 = (Zt / (0.33 * w)) * 1000.0;
      comp.C_HP2 = (1.0 / (0.4 * w * Zt)) * 1e6;
      comp.L_HP2 = (Zt / (0.75 * w)) * 1000.0;
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

    // Snap if requested
    if (snapToE12) {
      for (const key of Object.keys(comp)) {
        if (comp[key]) comp[key] = snapE12(comp[key]);
      }
    }

    return comp;
  }, [fx, wooferOrder, tweeterOrder, enableZobel, enableLPad, lpadAttenDB, snapToE12, ts, tweeter]);

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

    for (let i = 0; i <= steps; i++) {
      const logF = logMin + (i / steps) * (logMax - logMin);
      const f = Math.pow(10, logF);
      const w = 2.0 * Math.PI * f;

      // 1. Raw Woofer Passband SPL & Sealed Cabinet Transfer Function H_cab(s)
      let pWooferRawSPL = ts.spl;
      if (f > 2200) pWooferRawSPL -= 0.003 * (f - 2200);

      const pWooferRawLinear = Math.pow(10, pWooferRawSPL / 20.0);
      const pWooferRawComp = new Complex(pWooferRawLinear, 0);

      // Cabinet H_cab(s) = s^2 / (s^2 + (wc/Qtc)s + wc^2)
      const numCab = new Complex(-w * w, 0);
      const denCab = new Complex(wc * wc - w * w, (w * wc) / qtc);
      const hCab = numCab.div(denCab);

      const pWooferCab = pWooferRawComp.mul(hCab);

      // Woofer Low-Pass Electrical Filter H_LP
      const xW = f / fx;
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

      const pWooferFinal = pWooferCab.mul(hLP);

      // 2. Raw Tweeter SPL & High-Pass Electrical Filter
      let pTweeterRawSPL = tweeter.spl;
      if (f < 1500) pTweeterRawSPL -= 18 * Math.log2(1500 / Math.max(f, 10));
      const pTweeterRawComp = new Complex(Math.pow(10, pTweeterRawSPL / 20.0), 0);

      const xT = f / fx;
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

      // 3. Acoustic Summation
      const pTotal = pWooferFinal.add(pTweeterFinal);

      const wooferFinalSPL = 20.0 * Math.log10(Math.max(pWooferFinal.mag, 1e-6));
      const tweeterFinalSPL = 20.0 * Math.log10(Math.max(pTweeterFinal.mag, 1e-6));
      const totalSPL = 20.0 * Math.log10(Math.max(pTotal.mag, 1e-6));

      const wooferPhase = pWooferFinal.phaseDeg;
      const tweeterPhase = pTweeterFinal.phaseDeg;
      const totalPhase = pTotal.phaseDeg;
      let deltaPhase = Math.abs(wooferPhase - tweeterPhase) % 360;
      if (deltaPhase > 180) deltaPhase = 360 - deltaPhase;

      // 4. Electrical Load Impedance
      const reW = ts.re;
      const leW = ts.le / 1000.0;
      const qb = cabinetCalculations.qbVal;
      const effectiveQms = ts.qms > 0 ? ts.qms : 4.5;
      const qmsBox = effectiveQms * Math.sqrt(1 + cabinetCalculations.alpha);
      const qmc = (qmsBox * qb) / (qmsBox + qb);
      const resW = reW * (effectiveQms / Math.max(ts.qes, 0.01)) * (qb / (qmsBox + qb));
      const deltaF = (f / fc) - (fc / f);
      const denomMotional = 1.0 + Math.pow(qmc * deltaF, 2);
      const rMotional = resW / denomMotional;
      const xMotional = -resW * (qmc * deltaF) / denomMotional;
      const zWooferRaw = new Complex(reW + rMotional, w * leW + xMotional);

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
        zWooferMag: zWooferRaw.mag,
        zTweeterMag: zTweeterRaw.mag,
        zTotalMag: zTotal.mag
      });
    }

    return points;
  }, [ts, tweeter, cabinetCalculations, fx, wooferOrder, tweeterOrder, enableZobel, enableLPad, lpadAttenDB, acousticDelayMM, invertTweeterPolarity]);

  // --- Render Bode Amplitude Plot ---
  useEffect(() => {
    const canvas = amplitudeCanvasRef.current;
    if (!canvas || simulationData.length === 0) return;
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
      ctx.fillText(f >= 1000 ? `${f/1000}k` : `${f}`, x + 4, height - 8);
    });

    for (let spl = minSPL; spl <= maxSPL; spl += 10) {
      const y = height * (1 - (spl - minSPL) / (maxSPL - minSPL));
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
      ctx.fillText(`${spl} dB`, 8, y - 4);
    }

    function toCanvas(f, spl) {
      const clampedSPL = Math.max(Math.min(spl, maxSPL), minSPL);
      const x = width * ((Math.log10(f) - logMin) / (logMax - logMin));
      const y = height * (1 - (clampedSPL - minSPL) / (maxSPL - minSPL));
      return [x, y];
    }

    // Woofer Curve (Blue)
    ctx.strokeStyle = '#3b82f6';
    ctx.lineWidth = 2;
    ctx.beginPath();
    simulationData.forEach((p, i) => {
      const [x, y] = toCanvas(p.frequency, p.wooferFinalSPL);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Tweeter Curve (Red)
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 2;
    ctx.beginPath();
    simulationData.forEach((p, i) => {
      const [x, y] = toCanvas(p.frequency, p.tweeterFinalSPL);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Summed Total Curve (Green)
    ctx.strokeStyle = '#22c55e';
    ctx.lineWidth = 3;
    ctx.beginPath();
    simulationData.forEach((p, i) => {
      const [x, y] = toCanvas(p.frequency, p.totalSPL);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

  }, [simulationData, activeTab]);

  // --- URL Datasheet Parser Handler ---
  const handleFetchDatasheet = async () => {
    if (!datasheetURL) return;
    setIsLoadingURL(true);
    setStatusMsg("Fetching and parsing PDF/datasheet...");
    try {
      const parsed = await parseDatasheetFromURL(datasheetURL);
      if (parsed && parsed.ts) {
        const computedQts = parsed.ts.qts || (parsed.ts.qes && parsed.ts.qms ? (parsed.ts.qes * parsed.ts.qms) / (parsed.ts.qes + parsed.ts.qms) : prev.qts);
        setTs(prev => ({
          ...prev,
          fs: parsed.ts.fs || prev.fs,
          qes: parsed.ts.qes || prev.qes,
          qms: parsed.ts.qms || prev.qms,
          qts: parseFloat(computedQts.toFixed(3)),
          vas: parsed.ts.vas || prev.vas,
          re: parsed.ts.re || prev.re,
          le: parsed.ts.le || prev.le,
          spl: parsed.ts.spl || prev.spl,
          xmax: parsed.ts.xmax || prev.xmax
        }));
        if (parsed.driverName) {
          setDriverName(parsed.driverName);
        }
        if (parsed.tweeter) {
          if (parsed.tweeter.spl) setTweeterSpl(parsed.tweeter.spl);
          if (parsed.tweeter.re) setTweeterRe(parsed.tweeter.re);
        }
        setStatusMsg(`Successfully extracted specs for ${parsed.driverName || 'driver'}`);
      } else {
        setStatusMsg("Could not parse parameters from datasheet.");
      }
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

        {/* Datasheet URL Fetcher */}
        <div className="bg-slate-900/60 p-3.5 rounded-lg border border-slate-700/80 space-y-3">
          <label className="text-xs font-semibold text-slate-300 flex items-center space-x-2">
            <Link className="w-3.5 h-3.5 text-blue-400" />
            <span>Datasheet URL Ingestion</span>
          </label>
          <input
            type="text"
            placeholder="https://example.com/datasheet.pdf"
            value={datasheetURL}
            onChange={(e) => setDatasheetURL(e.target.value)}
            className="w-full bg-slate-800 border border-slate-700 rounded px-2.5 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
          />
          <button
            onClick={handleFetchDatasheet}
            disabled={isLoadingURL}
            className="w-full bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs py-1.5 rounded transition flex items-center justify-center space-x-2"
          >
            {isLoadingURL ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
            <span>Fetch & Parse Specs</span>
          </button>
          {statusMsg && <p className="text-xs text-emerald-400">{statusMsg}</p>}
        </div>

        {/* Driver TS Parameters */}
        <div className="space-y-3">
          <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Woofer T/S Parameters</h2>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div>
              <label className="text-slate-400">Fs (Hz)</label>
              <input type="number" value={ts.fs} onChange={(e) => setTs({ ...ts, fs: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Qes</label>
              <input type="number" step="0.01" value={ts.qes} onChange={(e) => {
                const newQes = +e.target.value;
                const newQts = (newQes > 0 && ts.qms > 0) ? (newQes * ts.qms) / (newQes + ts.qms) : ts.qts;
                setTs({ ...ts, qes: newQes, qts: parseFloat(newQts.toFixed(3)) });
              }} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Qms</label>
              <input type="number" step="0.1" value={ts.qms} onChange={(e) => {
                const newQms = +e.target.value;
                const newQts = (ts.qes > 0 && newQms > 0) ? (ts.qes * newQms) / (ts.qes + newQms) : ts.qts;
                setTs({ ...ts, qms: newQms, qts: parseFloat(newQts.toFixed(3)) });
              }} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Qts (Total Q)</label>
              <input type="number" step="0.01" value={ts.qts} onChange={(e) => setTs({ ...ts, qts: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Vas (Liters)</label>
              <input type="number" step="0.5" value={ts.vas} onChange={(e) => setTs({ ...ts, vas: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Re (Ω)</label>
              <input type="number" step="0.1" value={ts.re} onChange={(e) => setTs({ ...ts, re: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Le (mH)</label>
              <input type="number" step="0.05" value={ts.le} onChange={(e) => setTs({ ...ts, le: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
          </div>
        </div>

        {/* Tweeter Parameters */}
        <div className="space-y-3">
          <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Tweeter / HF Specs</h2>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div>
              <label className="text-slate-400">Fs (Hz)</label>
              <input type="number" value={tweeter.fs} onChange={(e) => setTweeter({ ...tweeter, fs: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
            </div>
            <div>
              <label className="text-slate-400">Re (Ω)</label>
              <input type="number" step="0.1" value={tweeter.re} onChange={(e) => setTweeter({ ...tweeter, re: +e.target.value })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-white mt-1" />
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
            <button onClick={() => setActiveTab('cabinet')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'cabinet' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Sealed Cabinet</button>
            <button onClick={() => setActiveTab('crossover')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'crossover' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Crossover Designer</button>
            <button onClick={() => setActiveTab('bom')} className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${activeTab === 'bom' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}>Schematic & BOM</button>
          </div>
        </header>

        {/* View Workspace Content */}
        <div className="flex-1 p-6 overflow-y-auto">
          {activeTab === 'amplitude' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-bold text-white">Acoustic Amplitude Frequency Response (dB SPL vs Log Hz)</h2>
                <div className="flex items-center space-x-4 text-xs">
                  <span className="flex items-center space-x-1.5"><span className="w-3 h-3 rounded-full bg-blue-500"></span><span className="text-slate-300">Woofer</span></span>
                  <span className="flex items-center space-x-1.5"><span className="w-3 h-3 rounded-full bg-red-500"></span><span className="text-slate-300">Tweeter</span></span>
                  <span className="flex items-center space-x-1.5"><span className="w-3 h-3 rounded-full bg-emerald-500"></span><span className="text-slate-300">Summed System</span></span>
                </div>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 shadow-xl">
                <canvas ref={amplitudeCanvasRef} width={800} height={400} className="w-full h-[400px]" />
              </div>
            </div>
          )}

          {activeTab === 'cabinet' && (
            <div className="max-w-3xl space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-white flex items-center space-x-2"><Box className="text-blue-400" /><span>Closed (Sealed) Cabinet Designer</span></h2>
                <button
                  onClick={() => setTargetF3(prev => prev)}
                  className="bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs px-3 py-2 rounded-lg flex items-center space-x-2 transition"
                >
                  <RefreshCw className="w-4 h-4" />
                  <span>Restart Simulation</span>
                </button>
              </div>

              {cabinetCalculations.effectiveQts < 0.40 && (
                <div className="bg-blue-500/10 border border-blue-500/30 text-blue-300 p-4 rounded-xl text-xs flex items-start space-x-2.5">
                  <Shield className="w-4 h-4 text-blue-400 shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold text-white mb-0.5">Pro-Audio Coaxial Driver Acoustic Note (Qts = {cabinetCalculations.effectiveQts.toFixed(3)})</p>
                    <p className="text-slate-300 text-[11px] leading-relaxed">High-efficiency pro-audio coaxial woofers naturally have low Qts (0.25–0.35) and produce f3 ≈ 100–113 Hz in a sealed cabinet. For full-range bass extension down to 40–50 Hz, a Bass-Reflex (Vented) cabinet alignment or active EQ is standard.</p>
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
                <div>
                  <label className="text-slate-400 text-xs">Alignment Design Mode</label>
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
                    <label className="text-xs font-semibold text-slate-400">Target Lower -3 dB Cut-off Frequency (f3): {targetF3} Hz</label>
                    <input type="range" min="30" max="200" value={targetF3} onChange={(e) => setTargetF3(+e.target.value)} className="w-full mt-2" />
                  </div>
                )}

                {alignment === 'custom' && (
                  <div>
                    <label className="text-xs font-semibold text-slate-400">Target Total System Q (Qtc): {customQtc.toFixed(3)}</label>
                    <input type="range" min="0.35" max="1.20" step="0.01" value={customQtc} onChange={(e) => setCustomQtc(+e.target.value)} className="w-full mt-2" />
                  </div>
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
                    <div className="mt-2 flex items-center space-x-3 text-xs">
                      <span className="text-slate-400">Net Internal Volume:</span>
                      <input
                        type="number"
                        step="0.5"
                        value={manualVbLiters}
                        onChange={(e) => setManualVbLiters(+e.target.value)}
                        className="bg-slate-800 border border-slate-700 rounded px-2.5 py-1 text-white w-24"
                      />
                      <span className="text-slate-400">Liters ({(manualVbLiters / 28.3168).toFixed(2)} ft³)</span>
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
                    <p className="text-slate-400">System Resonance (Fc)</p>
                    <p className="text-xl font-bold text-emerald-400 mt-1">{cabinetCalculations.fc.toFixed(1)} Hz</p>
                  </div>
                  <div className="bg-slate-800 p-3.5 rounded-lg">
                    <p className="text-slate-400">Total System Q (Qtc)</p>
                    <p className="text-xl font-bold text-purple-400 mt-1">{cabinetCalculations.actualQtc.toFixed(3)}</p>
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
                <h3 className="font-bold text-slate-200">Qtc vs Box Volume Sizing Matrix for {driverName}</h3>
                <p className="text-slate-400 text-[11px]">Comparison of required physical box volumes and resulting cutoff frequencies across target alignments for driver Qts = {cabinetCalculations.effectiveQts.toFixed(3)}:</p>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-slate-300">
                    <thead className="text-[11px] text-slate-400 uppercase border-b border-slate-800">
                      <tr>
                        <th className="py-2 px-2">Alignment</th>
                        <th className="py-2 px-2">Target Qtc</th>
                        <th className="py-2 px-2">Physical Vb (L)</th>
                        <th className="py-2 px-2">Physical Vb (cu ft)</th>
                        <th className="py-2 px-2">Resonance (Fc)</th>
                        <th className="py-2 px-2">Cutoff (f3)</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60">
                      {[
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
                            <td className="py-2 px-2">{targetQ.toFixed(4)}</td>
                            <td className="py-2 px-2 font-semibold text-white">{physVb.toFixed(2)} L</td>
                            <td className="py-2 px-2">{physFt.toFixed(2)} ft³</td>
                            <td className="py-2 px-2">{f_c.toFixed(1)} Hz</td>
                            <td className="py-2 px-2 font-bold text-green-400">{f3_val.toFixed(1)} Hz</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'crossover' && (
            <div className="max-w-3xl space-y-6">
              <h2 className="text-xl font-bold text-white flex items-center space-x-2"><Sliders className="text-blue-400" /><span>Coaxial Crossover Designer</span></h2>
              <div className="bg-slate-900 p-6 rounded-xl border border-slate-800 space-y-5">
                <div>
                  <label className="text-xs font-semibold text-slate-400">Crossover Frequency (fx): {fx} Hz</label>
                  <input type="range" min="800" max="5000" step="25" value={fx} onChange={(e) => setFx(+e.target.value)} className="w-full mt-2" />
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
                    {crossoverComponents.R_zobel && <tr><td className="py-2.5 font-bold text-amber-400">R_zobel</td><td>Zobel Resistor</td><td>{crossoverComponents.R_zobel.toFixed(2)} Ω</td></tr>}
                    {crossoverComponents.C_zobel && <tr><td className="py-2.5 font-bold text-amber-400">C_zobel</td><td>Zobel Capacitor</td><td>{crossoverComponents.C_zobel.toFixed(2)} µF</td></tr>}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

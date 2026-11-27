/**
 * High-precision 2-Page Vector PDF Exporter for Coaxial Speaker Crossover Schematic & BOM.
 * Mirrors PDFExporter.swift (A4 Landscape 842 x 595 pt):
 * - Page 1: Full Electrical Circuit Schematic Diagram (including Woofer Low-Pass, APF Delay, Zobel,
 *           Tweeter High-Pass, L-Pad Attenuator R1/R2, and Parallel CD Horn Mass Roll-Off EQ C_eq + R_eq || R1).
 * - Page 2: Crossover Bill of Materials (BOM) Component Table, Phase Alignment Status Banner, and Technical Spec Cards.
 */

function escapePDFText(str) {
  return String(str ?? '')
    .replace(/µ/g, 'u')
    .replace(/Ω/g, 'Ohm')
    .replace(/°/g, ' deg')
    .replace(/±/g, '+/-')
    .replace(/×/g, 'x')
    .replace(/Ø/g, 'Dia ')
    .replace(/≥/g, '>=')
    .replace(/≤/g, '<=')
    .replace(/α/g, 'alpha')
    .replace(/Δ/g, 'Delta ')
    .replace(/•/g, '-')
    .replace(/✓/g, '[OK]')
    .replace(/⚠/g, '[WARN]')
    .replace(/✖/g, '[ALERT]')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)');
}

class PDFPageCanvas {
  constructor(width = 842.0, height = 595.0) {
    this.width = width;
    this.height = height;
    this.ops = [];
  }

  // Convert top-left origin Y (like flipped NSGraphicsContext in PDFExporter.swift) to PDF bottom-left Y
  y(topY) {
    return (this.height - topY).toFixed(2);
  }

  setFillRGB(r, g, b) {
    this.ops.push(`${r.toFixed(3)} ${g.toFixed(3)} ${b.toFixed(3)} rg`);
  }

  setStrokeRGB(r, g, b) {
    this.ops.push(`${r.toFixed(3)} ${g.toFixed(3)} ${b.toFixed(3)} RG`);
  }

  setLineWidth(w) {
    this.ops.push(`${w.toFixed(2)} w`);
  }

  setDash(array = [], phase = 0) {
    if (!array || array.length === 0) {
      this.ops.push('[] 0 d');
    } else {
      this.ops.push(`[${array.map(n => n.toFixed(1)).join(' ')}] ${phase.toFixed(1)} d`);
    }
  }

  fillRect(x, topY, w, h) {
    const pdfY = (this.height - (topY + h)).toFixed(2);
    this.ops.push(`${x.toFixed(2)} ${pdfY} ${w.toFixed(2)} ${h.toFixed(2)} re f`);
  }

  strokeRect(x, topY, w, h) {
    const pdfY = (this.height - (topY + h)).toFixed(2);
    this.ops.push(`${x.toFixed(2)} ${pdfY} ${w.toFixed(2)} ${h.toFixed(2)} re S`);
  }

  fillAndStrokeRect(x, topY, w, h) {
    const pdfY = (this.height - (topY + h)).toFixed(2);
    this.ops.push(`${x.toFixed(2)} ${pdfY} ${w.toFixed(2)} ${h.toFixed(2)} re B`);
  }

  line(x1, y1, x2, y2) {
    this.ops.push(`${x1.toFixed(2)} ${this.y(y1)} m ${x2.toFixed(2)} ${this.y(y2)} l S`);
  }

  fillCircle(cx, cy, r) {
    const k = 0.5522847498 * r;
    const py = this.height - cy;
    this.ops.push(
      `${(cx - r).toFixed(2)} ${py.toFixed(2)} m`,
      `${(cx - r).toFixed(2)} ${(py + k).toFixed(2)} ${(cx - k).toFixed(2)} ${(py + r).toFixed(2)} ${cx.toFixed(2)} ${(py + r).toFixed(2)} c`,
      `${(cx + k).toFixed(2)} ${(py + r).toFixed(2)} ${(cx + r).toFixed(2)} ${(py + k).toFixed(2)} ${(cx + r).toFixed(2)} ${py.toFixed(2)} c`,
      `${(cx + r).toFixed(2)} ${(py - k).toFixed(2)} ${(cx + k).toFixed(2)} ${(py - r).toFixed(2)} ${cx.toFixed(2)} ${(py - r).toFixed(2)} c`,
      `${(cx - k).toFixed(2)} ${(py - r).toFixed(2)} ${(cx - r).toFixed(2)} ${(py - k).toFixed(2)} ${(cx - r).toFixed(2)} ${py.toFixed(2)} c`,
      'f'
    );
  }

  drawText(text, x, topY, { size = 8.5, bold = false, color = [0, 0, 0] } = {}) {
    const safe = escapePDFText(text);
    const font = bold ? '/F2' : '/F1';
    const baselineY = this.height - (topY + size * 0.85);
    this.setFillRGB(color[0], color[1], color[2]);
    this.ops.push(`BT ${font} ${size.toFixed(2)} Tf ${x.toFixed(2)} ${baselineY.toFixed(2)} Td (${safe}) Tj ET`);
  }

  drawBadge(x, topY, text, color = [0.1, 0.25, 0.65]) {
    const raw = String(text ?? '');
    const w = Math.max(36, raw.length * 4.5 + 8);
    const h = 13.0;
    this.setFillRGB(0.99, 0.99, 1.0);
    this.setStrokeRGB(0.75, 0.78, 0.82);
    this.setLineWidth(0.5);
    this.fillAndStrokeRect(x - 3, topY - 2, w, h);
    this.drawText(raw, x + 1, topY, { size: 7.5, bold: true, color });
  }

  drawWire(x1, y1, x2, y2) {
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(x1, y1, x2, y2);
  }

  drawJunctionDot(x, y) {
    this.setFillRGB(0, 0, 0);
    this.fillCircle(x, y, 2.5);
  }

  drawTerminalDot(x, y, label, isPositive) {
    if (isPositive) {
      this.setFillRGB(0.85, 0.15, 0.15);
    } else {
      this.setFillRGB(0, 0, 0);
    }
    this.fillCircle(x, y, 3.5);
    this.drawText(label, x - 36, y - 4, {
      size: 8.0,
      bold: true,
      color: isPositive ? [0.85, 0.15, 0.15] : [0, 0, 0]
    });
  }

  drawInductorSymbol(startX, endX, y, name, valueStr, color) {
    const len = endX - startX;
    const numLoops = 4;
    const loopW = len / numLoops;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    for (let i = 0; i < numLoops; i++) {
      const lx = startX + i * loopW;
      const mx = lx + loopW / 2;
      const rx = lx + loopW;
      const py = this.height - y;
      const peakY = py + 8.0;
      this.ops.push(`${lx.toFixed(2)} ${py.toFixed(2)} m ${(lx + 2).toFixed(2)} ${peakY.toFixed(2)} ${(rx - 2).toFixed(2)} ${peakY.toFixed(2)} ${rx.toFixed(2)} ${py.toFixed(2)} c S`);
      void mx;
    }
    this.drawBadge(startX, y - 18, `${name}: ${valueStr}`, color);
  }

  drawCapacitorSymbol(startX, endX, y, name, valueStr, color, badgeBelow = false) {
    const midX = (startX + endX) / 2.0;
    const capGap = 6.0;
    const capH = 16.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(startX, y, midX - capGap / 2, y);
    this.line(midX - capGap / 2, y - capH / 2, midX - capGap / 2, y + capH / 2);
    this.line(midX + capGap / 2, y - capH / 2, midX + capGap / 2, y + capH / 2);
    this.line(midX + capGap / 2, y, endX, y);
    const badgeY = badgeBelow ? (y + 10.0) : (y - 18.0);
    this.drawBadge(startX, badgeY, `${name}: ${valueStr}`, color);
  }

  drawResistorSymbol(startX, endX, y, name, valueStr, color, badgeBelow = false) {
    const midX = (startX + endX) / 2.0;
    const resW = 24.0;
    const resH = 10.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(startX, y, midX - resW / 2, y);
    this.strokeRect(midX - resW / 2, y - resH / 2, resW, resH);
    this.line(midX + resW / 2, y, endX, y);
    const badgeY = badgeBelow ? (y + 10.0) : (y - 18.0);
    this.drawBadge(startX, badgeY, `${name}: ${valueStr}`, color);
  }

  drawShuntCapacitor(topX, topY, groundY, name, valueStr, color) {
    const midY = (topY + groundY) / 2.0;
    const capGap = 6.0;
    const capW = 16.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(topX, topY, topX, midY - capGap / 2);
    this.line(topX - capW / 2, midY - capGap / 2, topX + capW / 2, midY - capGap / 2);
    this.line(topX - capW / 2, midY + capGap / 2, topX + capW / 2, midY + capGap / 2);
    this.line(topX, midY + capGap / 2, topX, groundY);
    this.drawBadge(topX + 12, midY - 6, `${name}: ${valueStr}`, color);
  }

  drawShuntInductor(topX, topY, groundY, name, valueStr, color) {
    const midY = (topY + groundY) / 2.0;
    const len = 36.0;
    const numLoops = 4;
    const loopH = len / numLoops;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(topX, topY, topX, midY - len / 2);
    for (let i = 0; i < numLoops; i++) {
      const ty = midY - len / 2 + i * loopH;
      const by = ty + loopH;
      const pTy = this.height - ty;
      const pBy = this.height - by;
      this.ops.push(`${topX.toFixed(2)} ${pTy.toFixed(2)} m ${(topX + 7).toFixed(2)} ${pTy.toFixed(2)} ${(topX + 7).toFixed(2)} ${pBy.toFixed(2)} ${topX.toFixed(2)} ${pBy.toFixed(2)} c S`);
    }
    this.line(topX, midY + len / 2, topX, groundY);
    this.drawBadge(topX + 12, midY - 6, `${name}: ${valueStr}`, color);
  }

  drawShuntResistor(topX, topY, groundY, name, valueStr, color) {
    const midY = (topY + groundY) / 2.0;
    const resW = 10.0;
    const resH = 24.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(topX, topY, topX, midY - resH / 2);
    this.strokeRect(topX - resW / 2, midY - resH / 2, resW, resH);
    this.line(topX, midY + resH / 2, topX, groundY);
    this.drawBadge(topX + 12, midY - 6, `${name}: ${valueStr}`, color);
  }

  drawShuntZobelBranch(topX, topY, groundY, rzStr, czStr) {
    const midY = (topY + groundY) / 2.0;
    const rH = 16.0;
    const rW = 10.0;
    const capGap = 5.0;
    const capW = 16.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(topX, topY, topX, midY - 20.0);
    this.strokeRect(topX - rW / 2, midY - 20.0, rW, rH);
    this.line(topX, midY - 4.0, topX, midY + 10.0 - capGap / 2);
    this.line(topX - capW / 2, midY + 10.0 - capGap / 2, topX + capW / 2, midY + 10.0 - capGap / 2);
    this.line(topX - capW / 2, midY + 10.0 + capGap / 2, topX + capW / 2, midY + 10.0 + capGap / 2);
    this.line(topX, midY + 10.0 + capGap / 2, topX, groundY);
    this.drawBadge(topX + 12, midY - 16, `Rz: ${rzStr}`, [0.85, 0.45, 0.05]);
    this.drawBadge(topX + 12, midY + 6, `Cz: ${czStr}`, [0.85, 0.45, 0.05]);
  }

  drawSpeakerSymbol(topX, topY, groundY, title, subTitle, invertPolarity = false) {
    const midY = (topY + groundY) / 2.0;
    const spkW = 16.0;
    const spkH = 34.0;
    const coneDepth = 16.0;
    const coneSpread = 12.0;
    this.setStrokeRGB(0, 0, 0);
    this.setLineWidth(1.5);
    this.line(topX, topY, topX, midY - spkH / 2);
    this.line(topX, midY + spkH / 2, topX, groundY);
    this.strokeRect(topX, midY - spkH / 2, spkW, spkH);
    this.line(topX + spkW, midY - spkH / 2, topX + spkW + coneDepth, midY - spkH / 2 - coneSpread);
    this.line(topX + spkW + coneDepth, midY - spkH / 2 - coneSpread, topX + spkW + coneDepth, midY + spkH / 2 + coneSpread);
    this.line(topX + spkW + coneDepth, midY + spkH / 2 + coneSpread, topX + spkW, midY + spkH / 2);

    this.drawText(invertPolarity ? '-' : '+', topX + 4, midY - spkH / 2 + 2, {
      size: 9.0,
      bold: true,
      color: invertPolarity ? [0.15, 0.15, 0.15] : [0.85, 0.15, 0.15]
    });
    this.drawText(invertPolarity ? '+' : '-', topX + 4, midY + spkH / 2 - 11, {
      size: 9.0,
      bold: true,
      color: invertPolarity ? [0.85, 0.15, 0.15] : [0.15, 0.15, 0.15]
    });
    this.drawText(title, topX + spkW + coneDepth + 8, midY - 8, { size: 8.5, bold: true, color: [0, 0, 0] });
    this.drawText(subTitle, topX + spkW + coneDepth + 8, midY + 4, { size: 8.0, bold: false, color: [0.3, 0.3, 0.3] });
    if (invertPolarity) {
      this.drawBadge(topX + spkW + coneDepth + 8, midY - 24, 'INVERTED POLARITY (-180 deg)', [0.85, 0.35, 0.05]);
    }
  }

  toStream() {
    return this.ops.join('\n');
  }
}

export function generateSchematicPDF({
  driverName = 'Custom Coaxial Driver',
  manufacturer = 'Custom',
  ts = { fs: 48, qes: 0.36, qms: 4.8, qts: 0.335, vas: 28, re: 6.2, le: 0.85, spl: 89 },
  tweeter = { fs: 1200, re: 5.8, le: 0.08, spl: 94, nominalImpedance: 8 },
  cabinetCalculations = {
    enclosureType: 'sealed',
    vb: 25.0,
    fc: 68.0,
    f3: 68.0,
    actualQtc: 0.707,
    qmc: 4.5,
    alpha: 1.1,
    fb: 45.0,
    portLengthCm: 14.0,
    minPortDiaCm: 7.5
  },
  alignment = 'butterworth',
  ventedAlignment = 'qb3',
  portDiameterCm = 8.0,
  portCount = 1,
  fx = 2200,
  enableIndependentFx = false,
  wooferFx = 2200,
  tweeterFx = 2200,
  wooferOrder = 'secondOrderLR',
  tweeterOrder = 'secondOrderLR',
  enableZobel = true,
  enableLPad = true,
  enableCDHornComp = false,
  cdHornCornerHz = 3500,
  cdHornBoostDB = 6.0,
  enableAllpass = false,
  acousticDelayMM = 35.0,
  invertTweeterPolarity = false,
  apfOptimization = {
    f0: 2200,
    q: 0.707,
    rmsErrorDeg: 0.0,
    alignmentStatus: { level: 'green', label: 'Phase Aligned (Optimal)' },
    warnings: []
  },
  crossoverComponents = {}
} = {}) {
  const pageW = 842.0;
  const pageH = 595.0;
  const margin = 36.0;

  const drawHeaderBanner = (page, pageNum, totalPages, subtitle) => {
    const bannerY = 18.0;
    const bannerH = 52.0;
    const bannerW = pageW - margin * 2;
    page.setFillRGB(0.08, 0.12, 0.22);
    page.fillRect(margin, bannerY, bannerW, bannerH);

    page.drawText('COAXIAL SPEAKER CROSSOVER & CABINET REPORT', margin + 14, bannerY + 7, {
      size: 13.0,
      bold: true,
      color: [1, 1, 1]
    });
    page.drawText(`PAGE ${pageNum} OF ${totalPages}`, margin + bannerW - 88, bannerY + 8, {
      size: 8.5,
      bold: true,
      color: [0.5, 0.75, 1.0]
    });

    const apfTag = enableAllpass
      ? ` | APF Delay: Active (F0 = ${Math.round(apfOptimization.f0)} Hz, Q = ${apfOptimization.q.toFixed(2)})`
      : '';
    const cdTag = enableCDHornComp
      ? ` | CD Horn EQ: C_eq + R_eq || R1 (f_eq = ${Math.round(cdHornCornerHz)} Hz, +${cdHornBoostDB.toFixed(1)} dB)`
      : '';
    const xoInfo = enableIndependentFx
      ? `Crossover: Woofer ${Math.round(wooferFx)} Hz (${wooferOrder}) / Tweeter ${Math.round(tweeterFx)} Hz (${tweeterOrder})`
      : `Crossover: ${Math.round(fx)} Hz (${wooferOrder} / ${tweeterOrder})`;
    const line1 = `Driver: ${driverName} (${manufacturer})  |  ${xoInfo}${apfTag}${cdTag}`;

    const line2 = cabinetCalculations.enclosureType === 'vented'
      ? `Vented Enclosure (4th-Order): Vb = ${cabinetCalculations.vb.toFixed(1)} L  |  Fb = ${cabinetCalculations.fb.toFixed(1)} Hz  |  f3 = ${cabinetCalculations.f3.toFixed(1)} Hz  |  Port: ${portCount}x Dia ${portDiameterCm.toFixed(1)}cm  |  ${subtitle}`
      : `Sealed Enclosure: Vb = ${cabinetCalculations.vb.toFixed(2)} L  |  Fc = ${cabinetCalculations.fc.toFixed(1)} Hz  |  f3 = ${cabinetCalculations.f3.toFixed(1)} Hz  |  Qtc = ${cabinetCalculations.actualQtc.toFixed(3)}  |  ${subtitle}`;

    page.drawText(line1, margin + 14, bannerY + 24, { size: 8.2, bold: false, color: [0.78, 0.84, 0.95] });
    page.drawText(line2, margin + 14, bannerY + 36, { size: 8.2, bold: false, color: [0.78, 0.84, 0.95] });
  };

  const drawFooter = (page, pageNum, totalPages) => {
    const footerY = pageH - 22.0;
    page.drawText(
      'Generated by Coaxial Speaker Designer - Nelder-Mead Phase Aligned Crossover & Cabinet Designer',
      margin,
      footerY,
      { size: 7.5, bold: false, color: [0.45, 0.45, 0.45] }
    );
    page.drawText(`Page ${pageNum} of ${totalPages}`, pageW - margin - 55, footerY, {
      size: 7.5,
      bold: false,
      color: [0.45, 0.45, 0.45]
    });
  };

  // ===========================================================================
  // PAGE 1: FULL ELECTRICAL CIRCUIT SCHEMATIC DIAGRAM
  // ===========================================================================
  const p1 = new PDFPageCanvas(pageW, pageH);
  p1.setFillRGB(1, 1, 1);
  p1.fillRect(0, 0, pageW, pageH);
  drawHeaderBanner(p1, 1, 2, 'ELECTRICAL CIRCUIT SCHEMATIC');

  const boxY = 92.0;
  const boxH = pageH - boxY - 32.0;
  const boxW = pageW - margin * 2;
  p1.drawText('FULL ELECTRICAL CIRCUIT SCHEMATIC (CROSSOVER & APF DELAY COMPENSATION)', margin, 78.0, {
    size: 11.0,
    bold: true,
    color: [0.1, 0.25, 0.5]
  });

  p1.setFillRGB(0.98, 0.98, 0.99);
  p1.setStrokeRGB(0.8, 0.82, 0.86);
  p1.setLineWidth(1.0);
  p1.fillAndStrokeRect(margin, boxY, boxW, boxH);

  const ampX = margin + 45.0;
  const signalDropX = ampX + 32.0;
  const speakerX = margin + boxW - 125.0;

  const wooferHeaderY = boxY + 16.0;
  const wooferY = boxY + 65.0;
  const wooferGroundY = boxY + 195.0;
  const branchSeparatorY = boxY + 225.0;
  const tweeterHeaderY = boxY + 242.0;
  const tweeterY = boxY + 305.0;
  const tweeterGroundY = boxY + 435.0;

  p1.drawTerminalDot(ampX, wooferY, 'AMP (+)', true);
  p1.drawTerminalDot(ampX, tweeterGroundY, 'AMP (-)', false);
  p1.drawWire(ampX, wooferY, signalDropX, wooferY);
  p1.drawWire(signalDropX, wooferY, signalDropX, wooferGroundY - 6.0);
  p1.drawWire(signalDropX, wooferGroundY + 6.0, signalDropX, tweeterY);
  p1.drawJunctionDot(signalDropX, wooferY);
  p1.drawJunctionDot(signalDropX, tweeterY);

  p1.drawWire(ampX, tweeterGroundY, ampX, wooferGroundY);
  p1.drawJunctionDot(ampX, tweeterGroundY);
  p1.drawJunctionDot(ampX, wooferGroundY);
  p1.drawWire(ampX, wooferGroundY, speakerX, wooferGroundY);
  p1.drawWire(ampX, tweeterGroundY, speakerX, tweeterGroundY);

  p1.setStrokeRGB(0.85, 0.88, 0.92);
  p1.setLineWidth(0.8);
  p1.setDash([4, 4], 0);
  p1.line(margin + 15, branchSeparatorY, margin + boxW - 15, branchSeparatorY);
  p1.setDash([], 0);

  // Woofer Low-Pass Branch
  let curX = signalDropX;
  const apfBranchTag = enableAllpass
    ? ` + ALL-PASS DELAY (F0 = ${Math.round(apfOptimization.f0)} Hz, Q = ${apfOptimization.q.toFixed(2)})`
    : '';
  p1.drawText(`WOOFER LOW-PASS (${wooferOrder})${apfBranchTag}`, signalDropX + 15, wooferHeaderY, {
    size: 9.5,
    bold: true,
    color: [0.1, 0.35, 0.75]
  });

  if (crossoverComponents.L1) {
    p1.drawWire(curX, wooferY, curX + 30, wooferY);
    curX += 30;
    p1.drawInductorSymbol(curX, curX + 54, wooferY, 'L1', `${crossoverComponents.L1.toFixed(2)} mH`, [0.1, 0.35, 0.75]);
    curX += 54;
  }
  if (crossoverComponents.C1) {
    p1.drawWire(curX, wooferY, curX + 48, wooferY);
    curX += 48;
    p1.drawJunctionDot(curX, wooferY);
    p1.drawShuntCapacitor(curX, wooferY, wooferGroundY, 'C1', `${crossoverComponents.C1.toFixed(2)} uF`, [0.1, 0.35, 0.75]);
    p1.drawJunctionDot(curX, wooferGroundY);
  }
  if (crossoverComponents.L2) {
    p1.drawWire(curX, wooferY, curX + 30, wooferY);
    curX += 30;
    p1.drawInductorSymbol(curX, curX + 54, wooferY, 'L2', `${crossoverComponents.L2.toFixed(2)} mH`, [0.1, 0.35, 0.75]);
    curX += 54;
  }
  if (crossoverComponents.C2) {
    p1.drawWire(curX, wooferY, curX + 48, wooferY);
    curX += 48;
    p1.drawJunctionDot(curX, wooferY);
    p1.drawShuntCapacitor(curX, wooferY, wooferGroundY, 'C2', `${crossoverComponents.C2.toFixed(2)} uF`, [0.1, 0.35, 0.75]);
    p1.drawJunctionDot(curX, wooferGroundY);
  }
  if (enableAllpass && crossoverComponents.L_AP && crossoverComponents.C_AP) {
    p1.drawWire(curX, wooferY, curX + 30, wooferY);
    curX += 30;
    p1.drawInductorSymbol(curX, curX + 54, wooferY, 'L_AP (Delay)', `${crossoverComponents.L_AP.toFixed(2)} mH`, [0.05, 0.55, 0.55]);
    curX += 54;
    p1.drawWire(curX, wooferY, curX + 48, wooferY);
    curX += 48;
    p1.drawJunctionDot(curX, wooferY);
    p1.drawShuntCapacitor(curX, wooferY, wooferGroundY, 'C_AP (Delay)', `${crossoverComponents.C_AP.toFixed(2)} uF`, [0.05, 0.55, 0.55]);
    p1.drawJunctionDot(curX, wooferGroundY);
  }
  if (enableZobel && crossoverComponents.R_zobel && crossoverComponents.C_zobel) {
    p1.drawWire(curX, wooferY, curX + 54, wooferY);
    curX += 54;
    p1.drawJunctionDot(curX, wooferY);
    p1.drawShuntZobelBranch(curX, wooferY, wooferGroundY, `${crossoverComponents.R_zobel.toFixed(2)} Ohm`, `${crossoverComponents.C_zobel.toFixed(2)} uF`);
    p1.drawJunctionDot(curX, wooferGroundY);
  }
  p1.drawWire(curX, wooferY, speakerX, wooferY);
  p1.drawSpeakerSymbol(speakerX, wooferY, wooferGroundY, 'WOOFER', `Re = ${ts.re.toFixed(1)} Ohm`, false);
  p1.drawJunctionDot(speakerX, wooferGroundY);

  // Tweeter High-Pass Branch
  let tCurX = signalDropX;
  const cdBranchTag = enableCDHornComp
    ? ` + CD HORN EQ (C_eq + R_eq || R1 @ f_eq = ${Math.round(cdHornCornerHz)} Hz, +${cdHornBoostDB.toFixed(1)} dB)`
    : '';
  p1.drawText(`TWEETER HIGH-PASS (${tweeterOrder})${cdBranchTag}`, signalDropX + 15, tweeterHeaderY, {
    size: 9.5,
    bold: true,
    color: [0.8, 0.15, 0.15]
  });

  const hpWireLead = enableCDHornComp ? 26.0 : 35.0;
  const hpSymW = enableCDHornComp ? 48.0 : 55.0;
  const hpShuntStep = enableCDHornComp ? 44.0 : 55.0;

  if (crossoverComponents.C_HP1) {
    p1.drawWire(tCurX, tweeterY, tCurX + hpWireLead, tweeterY);
    tCurX += hpWireLead;
    p1.drawCapacitorSymbol(tCurX, tCurX + hpSymW, tweeterY, 'C_HP1', `${crossoverComponents.C_HP1.toFixed(2)} uF`, [0.8, 0.15, 0.15]);
    tCurX += hpSymW;
  }
  if (crossoverComponents.L_HP1) {
    p1.drawWire(tCurX, tweeterY, tCurX + hpShuntStep, tweeterY);
    tCurX += hpShuntStep;
    p1.drawJunctionDot(tCurX, tweeterY);
    p1.drawShuntInductor(tCurX, tweeterY, tweeterGroundY, 'L_HP1', `${crossoverComponents.L_HP1.toFixed(2)} mH`, [0.8, 0.15, 0.15]);
    p1.drawJunctionDot(tCurX, tweeterGroundY);
  }
  if (crossoverComponents.C_HP2) {
    p1.drawWire(tCurX, tweeterY, tCurX + hpWireLead, tweeterY);
    tCurX += hpWireLead;
    p1.drawCapacitorSymbol(tCurX, tCurX + hpSymW, tweeterY, 'C_HP2', `${crossoverComponents.C_HP2.toFixed(2)} uF`, [0.8, 0.15, 0.15]);
    tCurX += hpSymW;
  }
  if (crossoverComponents.L_HP2) {
    p1.drawWire(tCurX, tweeterY, tCurX + hpShuntStep, tweeterY);
    tCurX += hpShuntStep;
    p1.drawJunctionDot(tCurX, tweeterY);
    p1.drawShuntInductor(tCurX, tweeterY, tweeterGroundY, 'L_HP2', `${crossoverComponents.L_HP2.toFixed(2)} mH`, [0.8, 0.15, 0.15]);
    p1.drawJunctionDot(tCurX, tweeterGroundY);
  }

  // L-Pad Attenuator (Series R1 + Shunt R2) & Parallel CD Horn Mass Roll-Off Bypass (Series C_eq + R_eq || R1)
  if ((enableLPad || enableCDHornComp) && crossoverComponents.R1_lpad && crossoverComponents.R2_lpad) {
    if (enableCDHornComp && crossoverComponents.C_cd) {
      const rcd = crossoverComponents.R_cd ?? 0.39;
      p1.drawWire(tCurX, tweeterY, tCurX + 26, tweeterY);
      tCurX += 26;

      const loopStartX = tCurX;
      const loopWidth = 136.0;
      const loopEndX = loopStartX + loopWidth;
      const bypassY = tweeterY - 40.0;

      p1.drawJunctionDot(loopStartX, tweeterY);
      p1.drawJunctionDot(loopEndX, tweeterY);

      const r1SymStart = loopStartX + 36.0;
      const r1SymEnd = loopEndX - 36.0;
      p1.drawWire(loopStartX, tweeterY, r1SymStart, tweeterY);
      p1.drawResistorSymbol(
        r1SymStart,
        r1SymEnd,
        tweeterY,
        'R1 (L-Pad)',
        `${crossoverComponents.R1_lpad.toFixed(2)} Ohm`,
        [0.85, 0.45, 0.05],
        true
      );
      p1.drawWire(r1SymEnd, tweeterY, loopEndX, tweeterY);

      // Upper parallel bypass branch: vertical risers + series C_eq capacitor and R_eq damping resistor
      p1.drawWire(loopStartX, tweeterY, loopStartX, bypassY);
      p1.drawWire(loopEndX, tweeterY, loopEndX, bypassY);

      const capEndX = loopStartX + 64.0;
      const resStartX = capEndX + 8.0;
      p1.drawCapacitorSymbol(
        loopStartX,
        capEndX,
        bypassY,
        'C_eq',
        `${crossoverComponents.C_cd.toFixed(2)} uF`,
        [0.55, 0.2, 0.75]
      );
      p1.drawWire(capEndX, bypassY, resStartX, bypassY);
      p1.drawResistorSymbol(
        resStartX,
        loopEndX,
        bypassY,
        'R_eq',
        `${rcd.toFixed(2)} Ohm`,
        [0.55, 0.2, 0.75]
      );

      tCurX = loopEndX;
    } else {
      p1.drawWire(tCurX, tweeterY, tCurX + 35, tweeterY);
      tCurX += 35;
      p1.drawResistorSymbol(tCurX, tCurX + 55, tweeterY, 'R1 (L-Pad)', `${crossoverComponents.R1_lpad.toFixed(2)} Ohm`, [0.85, 0.45, 0.05]);
      tCurX += 55;
    }

    p1.drawWire(tCurX, tweeterY, tCurX + hpShuntStep, tweeterY);
    tCurX += hpShuntStep;
    p1.drawJunctionDot(tCurX, tweeterY);
    p1.drawShuntResistor(tCurX, tweeterY, tweeterGroundY, 'R2 (L-Pad)', `${crossoverComponents.R2_lpad.toFixed(2)} Ohm`, [0.85, 0.45, 0.05]);
    p1.drawJunctionDot(tCurX, tweeterGroundY);
  }

  p1.drawWire(tCurX, tweeterY, speakerX, tweeterY);
  p1.drawSpeakerSymbol(
    speakerX,
    tweeterY,
    tweeterGroundY,
    invertTweeterPolarity ? 'TWEETER (-180 deg)' : 'TWEETER (+)',
    `Re = ${tweeter.re.toFixed(1)} Ohm`,
    invertTweeterPolarity
  );
  p1.drawJunctionDot(speakerX, tweeterGroundY);
  drawFooter(p1, 1, 2);

  // ===========================================================================
  // PAGE 2: BILL OF MATERIALS & TECHNICAL SPECIFICATIONS
  // ===========================================================================
  const p2 = new PDFPageCanvas(pageW, pageH);
  p2.setFillRGB(1, 1, 1);
  p2.fillRect(0, 0, pageW, pageH);
  drawHeaderBanner(p2, 2, 2, 'BILL OF MATERIALS & TECHNICAL SPECIFICATIONS');

  let startY = 82.0;

  if (enableAllpass) {
    const level = apfOptimization.alignmentStatus?.level || 'green';
    const primaryLine = `RMS Phase Alignment (${apfOptimization.rmsErrorDeg.toFixed(2)} deg): ${apfOptimization.alignmentStatus?.label || 'Phase Aligned (Optimal)'}`;
    const allLines = [primaryLine, ...(apfOptimization.warnings || [])];
    const warnH = allLines.length * 14 + 12;
    const width = pageW - margin * 2;
    if (level === 'green') {
      p2.setFillRGB(0.90, 0.98, 0.92);
      p2.setStrokeRGB(0.15, 0.65, 0.30);
    } else if (level === 'yellow') {
      p2.setFillRGB(1.0, 0.96, 0.86);
      p2.setStrokeRGB(0.90, 0.60, 0.08);
    } else {
      p2.setFillRGB(1.0, 0.91, 0.91);
      p2.setStrokeRGB(0.85, 0.20, 0.20);
    }
    p2.setLineWidth(1.0);
    p2.fillAndStrokeRect(margin, startY, width, warnH);
    const txtColor = level === 'green' ? [0.08, 0.45, 0.18] : (level === 'yellow' ? [0.65, 0.38, 0.02] : [0.68, 0.10, 0.10]);
    allLines.forEach((line, idx) => {
      p2.drawText(line, margin + 12, startY + 6 + idx * 14, { size: 8.0, bold: true, color: txtColor });
    });
    startY += warnH + 10.0;
  }

  // BOM Table
  p2.drawText('CROSSOVER BILL OF MATERIALS (BOM) COMPONENT TABLE', margin, startY, {
    size: 11.0,
    bold: true,
    color: [0.1, 0.25, 0.5]
  });

  const tableY = startY + 15.0;
  const tableW = pageW - margin * 2;
  const colWidths = [88.0, 232.0, 140.0, tableW - 460.0];

  const rows = [];
  if (crossoverComponents.L1) rows.push(['L1', 'Woofer Low-Pass Series Inductor', `${crossoverComponents.L1.toFixed(2)} mH`, '1.2mm OFC Wire, Low DCR']);
  if (crossoverComponents.C1) rows.push(['C1', 'Woofer Low-Pass Shunt Capacitor', `${crossoverComponents.C1.toFixed(2)} uF`, '400V DC Metalized Polypropylene Film Cap, +/-5%']);
  if (crossoverComponents.L2) rows.push(['L2', 'Woofer Low-Pass Series Inductor (Higher Order)', `${crossoverComponents.L2.toFixed(2)} mH`, '1.0mm OFC Wire']);
  if (crossoverComponents.C2) rows.push(['C2', 'Woofer Low-Pass Shunt Capacitor (4th Order)', `${crossoverComponents.C2.toFixed(2)} uF`, '250V DC Film Cap']);
  if (enableAllpass) {
    if (crossoverComponents.L_AP) rows.push(['L_AP', `Woofer All-Pass Delay Inductor (F0 = ${Math.round(apfOptimization.f0)} Hz)`, `${crossoverComponents.L_AP.toFixed(2)} mH`, 'OFC Wire, Low DCR']);
    if (crossoverComponents.C_AP) rows.push(['C_AP', 'Woofer All-Pass Delay Capacitor', `${crossoverComponents.C_AP.toFixed(2)} uF`, '400V DC Polypropylene Film Cap, +/-5%']);
  }
  if (crossoverComponents.C_HP1) rows.push(['C_HP1', 'Tweeter High-Pass Series Capacitor', `${crossoverComponents.C_HP1.toFixed(2)} uF`, '250V DC High Precision Polypropylene Audio Cap']);
  if (crossoverComponents.L_HP1) rows.push(['L_HP1', 'Tweeter High-Pass Shunt Inductor', `${crossoverComponents.L_HP1.toFixed(2)} mH`, '0.8mm Air-Core Wire']);
  if (crossoverComponents.C_HP2) rows.push(['C_HP2', 'Tweeter High-Pass Series Capacitor (Higher Order)', `${crossoverComponents.C_HP2.toFixed(2)} uF`, '250V DC Film Cap']);
  if (crossoverComponents.L_HP2) rows.push(['L_HP2', 'Tweeter High-Pass Shunt Inductor (4th Order)', `${crossoverComponents.L_HP2.toFixed(2)} mH`, '0.8mm Air-Core Wire']);
  if (crossoverComponents.R_zobel) rows.push(['R_zobel', 'Woofer Zobel Impedance Compensation Resistor', `${crossoverComponents.R_zobel.toFixed(2)} Ohm`, '10W Non-Inductive Ceramic Resistor']);
  if (crossoverComponents.C_zobel) rows.push(['C_zobel', 'Woofer Zobel Impedance Compensation Capacitor', `${crossoverComponents.C_zobel.toFixed(2)} uF`, '100V DC Bipolar / Film Cap']);
  if (crossoverComponents.R1_lpad) rows.push(['R1 (L-Pad)', 'Tweeter L-Pad Attenuator (Series Element)', `${crossoverComponents.R1_lpad.toFixed(2)} Ohm`, '10W Power Metal Oxide / Wirewound Resistor']);
  if (crossoverComponents.R2_lpad) rows.push(['R2 (L-Pad)', 'Tweeter L-Pad Attenuator (Shunt Element)', `${crossoverComponents.R2_lpad.toFixed(2)} Ohm`, '10W Power Metal Oxide / Wirewound Resistor']);
  if (enableCDHornComp) {
    if (crossoverComponents.C_cd) {
      rows.push([
        'C_eq (CD Horn)',
        'CD Horn Mass Roll-Off Bypass Capacitor (|| R1)',
        `${crossoverComponents.C_cd.toFixed(2)} uF`,
        `250V DC Polypropylene Film Cap (f_eq = ${Math.round(cdHornCornerHz)} Hz)`
      ]);
    }
    const rcd = crossoverComponents.R_cd ?? 0.39;
    rows.push([
      'R_eq (CD Horn)',
      'CD Horn HF Shelf Damping Resistor (Series w/ C_eq)',
      `${rcd.toFixed(2)} Ohm`,
      `5W Non-Inductive Metal Oxide Resistor (+${cdHornBoostDB.toFixed(1)} dB Shelf)`
    ]);
  }
  if (cabinetCalculations.enclosureType === 'vented') {
    rows.push([
      'Port Duct',
      'Bass-Reflex Helmholtz Port Duct',
      `${portCount}x Dia ${portDiameterCm.toFixed(1)} cm x ${cabinetCalculations.portLengthCm.toFixed(1)} cm`,
      'Rigid Cylindrical Port Tube, Flared Ends'
    ]);
  }

  const rowHeight = rows.length > 12 ? 14.5 : 16.5;
  p2.setFillRGB(0.15, 0.22, 0.35);
  p2.fillRect(margin, tableY, tableW, rowHeight);

  const headers = ['Designator', 'Component Description', 'Calculated / Snapped Value', 'Recommended Specification & Tolerance'];
  let curColX = margin;
  headers.forEach((h, i) => {
    p2.drawText(h, curColX + 6, tableY + 3, { size: 8.2, bold: true, color: [1, 1, 1] });
    curColX += colWidths[i];
  });

  let curRowY = tableY + rowHeight;
  rows.forEach((r, idx) => {
    if (idx % 2 === 1) {
      p2.setFillRGB(0.96, 0.97, 0.98);
      p2.fillRect(margin, curRowY, tableW, rowHeight);
    }
    let cx = margin;
    r.forEach((val, colIdx) => {
      p2.drawText(val, cx + 6, curRowY + 3, {
        size: 8.0,
        bold: colIdx === 0 || colIdx === 2,
        color: colIdx === 0 || colIdx === 2 ? [0, 0, 0] : [0.25, 0.25, 0.25]
      });
      cx += colWidths[colIdx];
    });
    p2.setStrokeRGB(0.88, 0.90, 0.92);
    p2.setLineWidth(0.5);
    p2.line(margin, curRowY + rowHeight, margin + tableW, curRowY + rowHeight);
    curRowY += rowHeight;
  });

  p2.setStrokeRGB(0.7, 0.75, 0.8);
  p2.setLineWidth(1.0);
  p2.strokeRect(margin, tableY, tableW, curRowY - tableY);

  // Technical Spec Cards
  const cardsY = curRowY + 12.0;
  const cardGap = 14.0;
  const cardW = (tableW - cardGap * 2) / 3.0;
  const cardH = Math.min(155.0, pageH - cardsY - 26.0);

  const drawSpecCard = (x, title, headerColor, items) => {
    p2.setFillRGB(0.98, 0.98, 0.99);
    p2.setStrokeRGB(0.82, 0.85, 0.88);
    p2.setLineWidth(1.0);
    p2.fillAndStrokeRect(x, cardsY, cardW, cardH);

    p2.setFillRGB(headerColor[0], headerColor[1], headerColor[2]);
    p2.fillRect(x, cardsY, cardW, 18.0);
    p2.drawText(title, x + 8, cardsY + 4, { size: 8.0, bold: true, color: [1, 1, 1] });

    const stepY = Math.min(17.0, (cardH - 24.0) / Math.max(items.length, 1));
    items.forEach(([k, v], i) => {
      const iy = cardsY + 23.0 + i * stepY;
      p2.drawText(k, x + 8, iy, { size: 7.8, bold: false, color: [0.3, 0.3, 0.3] });
      p2.drawText(v, x + cardW - Math.min(cardW * 0.55, escapePDFText(v).length * 4.2 + 10), iy, {
        size: 7.8,
        bold: true,
        color: [0, 0, 0]
      });
    });
  };

  const card1Items = cabinetCalculations.enclosureType === 'vented'
    ? [
        ['Architecture', 'Vented (Bass-Reflex, 4th-Order)'],
        ['Alignment Preset', ventedAlignment.toUpperCase()],
        ['Net Volume (Vb)', `${cabinetCalculations.vb.toFixed(1)} L`],
        ['Tuning Freq (Fb)', `${cabinetCalculations.fb.toFixed(1)} Hz`],
        ['Cutoff Freq (f3)', `${cabinetCalculations.f3.toFixed(1)} Hz`],
        ['Port Spec', `${portCount}x Dia ${portDiameterCm.toFixed(1)} x ${cabinetCalculations.portLengthCm.toFixed(1)} cm`],
        ['Min Port Dia', `>= ${cabinetCalculations.minPortDiaCm.toFixed(1)} cm`]
      ]
    : [
        ['Target Alignment', alignment],
        ['Net Volume (Vb)', `${cabinetCalculations.vb.toFixed(2)} L`],
        ['Resonance Freq (Fc)', `${cabinetCalculations.fc.toFixed(1)} Hz`],
        ['Cutoff Frequency (f3)', `${cabinetCalculations.f3.toFixed(1)} Hz`],
        ['Total Q (Qtc)', cabinetCalculations.actualQtc.toFixed(3)],
        ['Mechanical Q (Qmc)', (cabinetCalculations.qmc ?? 4.5).toFixed(2)],
        ['Compliance Ratio', (cabinetCalculations.alpha ?? 1.0).toFixed(2)]
      ];

  drawSpecCard(
    margin,
    cabinetCalculations.enclosureType === 'vented' ? '4TH-ORDER VENTED ENCLOSURE' : 'SEALED ENCLOSURE ALIGNMENT',
    [0.1, 0.35, 0.65],
    card1Items
  );

  drawSpecCard(
    margin + cardW + cardGap,
    'COAXIAL DRIVER SPECIFICATIONS',
    [0.2, 0.45, 0.25],
    [
      ['Woofer Model', driverName],
      ['Woofer Re / Le', `${ts.re.toFixed(1)} Ohm / ${ts.le.toFixed(2)} mH`],
      ['Woofer Fs / Qts', `${ts.fs.toFixed(1)} Hz / ${ts.qts.toFixed(2)}`],
      ['Woofer Vas / SPL', `${ts.vas.toFixed(1)} L / ${ts.spl.toFixed(1)} dB`],
      ['Tweeter Re / Le', `${tweeter.re.toFixed(1)} Ohm / ${tweeter.le.toFixed(2)} mH`],
      ['Tweeter Fs / SPL', `${Math.round(tweeter.fs)} Hz / ${tweeter.spl.toFixed(1)} dB`],
      ['CD Horn EQ', enableCDHornComp ? `Active (${cdHornCornerHz} Hz, +${cdHornBoostDB.toFixed(1)} dB)` : 'Off']
    ]
  );

  const delayMs = ((acousticDelayMM / 1000.0) / 343.0) * 1000.0;
  drawSpecCard(
    margin + (cardW + cardGap) * 2,
    'ACOUSTIC DELAY & APF OPTIMIZER',
    [0.1, 0.5, 0.55],
    [
      ['Crossover Point (fx)', enableIndependentFx ? `${wooferFx} / ${tweeterFx} Hz` : `${fx} Hz`],
      ['Tweeter Depth Delay', `${acousticDelayMM.toFixed(1)} mm (${delayMs.toFixed(2)} ms)`],
      ['Tweeter Polarity', invertTweeterPolarity ? 'Inverted (-180 deg)' : 'Normal (+)'],
      ['APF Optimization', enableAllpass ? (apfOptimization.alignmentStatus?.label || 'Active') : 'Off (Disabled)'],
      ['Optimal APF F0', enableAllpass ? `${Math.round(apfOptimization.f0)} Hz` : 'N/A'],
      ['Optimal APF Q', enableAllpass ? apfOptimization.q.toFixed(2) : 'N/A'],
      ['Residual Phase RMS', enableAllpass ? `${apfOptimization.rmsErrorDeg.toFixed(2)} deg` : 'N/A']
    ]
  );

  drawFooter(p2, 2, 2);

  // Assemble valid multi-page PDF 1.4 document
  const s1 = p1.toStream();
  const s2 = p2.toStream();

  const objects = [
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>\nendobj\n',
    `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageW} ${pageH}] /Resources << /Font << /F1 7 0 R /F2 8 0 R >> >> /Contents 4 0 R >>\nendobj\n`,
    `4 0 obj\n<< /Length ${s1.length} >>\nstream\n${s1}\nendstream\nendobj\n`,
    `5 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageW} ${pageH}] /Resources << /Font << /F1 7 0 R /F2 8 0 R >> >> /Contents 6 0 R >>\nendobj\n`,
    `6 0 obj\n<< /Length ${s2.length} >>\nstream\n${s2}\nendstream\nendobj\n`,
    '7 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '8 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n'
  ];

  let pdf = '%PDF-1.4\n';
  const offsets = [0];
  for (const obj of objects) {
    offsets.push(pdf.length);
    pdf += obj;
  }
  const xrefOffset = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += '0000000000 65535 f \n';
  for (let i = 1; i < offsets.length; i++) {
    pdf += `${String(offsets[i]).padStart(10, '0')} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return pdf;
}

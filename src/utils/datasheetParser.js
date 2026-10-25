import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';

// Configure pdfjs worker if in browser
if (typeof window !== 'undefined' && pdfjs.GlobalWorkerOptions && !pdfjs.GlobalWorkerOptions.workerSrc) {
  pdfjs.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjs.version}/pdf.worker.min.mjs`;
}

/**
 * Normalizes acoustic engineering units to standard simulator units:
 * - Volume (Vas): Liters (L) instead of m^3 or cu. ft.
 * - Inductance (Le): millihenries (mH) instead of Henries (H)
 * - Piston area (Sd): cm^2 instead of m^2 or in^2
 */
export function normalizeUnitValue(val, unit) {
  if (!val) return 0;
  const u = (unit || '').toLowerCase().trim();
  // Volume: L instead of m^3
  if (u.includes('m3') || u.includes('m^3') || u.includes('m³')) return parseFloat((val * 1000).toFixed(1));
  if (u.includes('cu') || u.includes('ft')) return parseFloat((val * 28.3168).toFixed(1));
  // Area: cm^2 instead of m^2
  if (u.includes('cm')) return val;
  if (u.includes('m') && (u.includes('2') || u.includes('²'))) return Math.round(val * 10000);
  if (u.includes('in')) return Math.round(val * 6.4516);
  // Inductance: mH instead of H
  if (u === 'h') return parseFloat((val * 1000).toFixed(2));
  return val;
}

/**
 * Parses loudspeaker datasheet text (from PDF or HTML/plain text)
 * and extracts Thiele-Small woofer parameters and tweeter parameters.
 */
export function parseDatasheetText(text, url = '') {
  // Normalize European comma decimals: "6,7 Ω" -> "6.7 Ω", "0,31" -> "0.31"
  const normText = text.replace(/(\d+),(\d+)/g, '$1.$2');

  const ts = { fs: 0, qes: 0, qms: 0, qts: 0, vas: 0, re: 0, le: 0, sd: 0, xmax: 0, spl: 0 };
  const tweeter = { fs: 0, re: 0, le: 0, spl: 0 };
  let recommendedCrossover = 0;
  let driverName = '';

  // 1. Extract Driver Name
  const excludeWords = [
    'COAXIALS', 'SPECIFICATIONS', 'DESCRIPTION', 'PARAMETERS', 'SERVICE', 'FEATURES',
    'THIELE', 'TECHNICAL', 'MOUNTING', 'DIMENSION', 'DRAWINGS', 'FREE', 'IMPEDANCE',
    'FILTERED', 'FREQUENCY', 'RESPONSE', 'CURVE', 'NOTES', 'TRANSDUCER', 'LOUDSPEAKER'
  ];
  const namePatterns = [
    /\b(\d{1,2}[A-Za-z]{1,4}\d{1,4}[A-Za-z0-9]*(?:-[0-9A-Za-z+]+)?)\b/g,
    /\b([A-Z0-9]{4,12}(?:\s+[A-Z0-9]+)?)\b/g
  ];
  for (const regex of namePatterns) {
    let m;
    while ((m = regex.exec(text)) !== null) {
      const cand = m[1].trim();
      const upper = cand.toUpperCase();
      if (!cand.toLowerCase().startsWith('www') && !cand.toLowerCase().endsWith('.com') && !excludeWords.includes(upper)) {
        driverName = cand;
        break;
      }
    }
    if (driverName) break;
  }
  if (!driverName && url) {
    const filename = url.split('/').pop()?.replace(/\.pdf$/i, '')?.replace(/[-_+]/g, ' ');
    if (filename) driverName = filename;
  }
  if (!driverName) driverName = 'Parsed Coaxial Driver';

  // 2. Extract Recommended Crossover Frequency
  const xoRegex = /(?:Recom(?:\.|mended)?\s*(?:HF)?\s*Crossover|Crossover\s+Frequency|Suggested\s+Crossover)[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(k?Hz)?/i;
  const xoMatch = normText.match(xoRegex);
  if (xoMatch) {
    let val = parseFloat(xoMatch[1]);
    if ((xoMatch[2] && xoMatch[2].toLowerCase().startsWith('k')) || val < 20) val *= 1000;
    if (val >= 400 && val <= 8000) recommendedCrossover = val;
  }
  if (!recommendedCrossover) {
    const khzHigher = normText.match(/(\d+(?:\.\d+)?)\s*kHz\s*(?:or\s+higher|min(?:\.|\s+slope)?)/i);
    if (khzHigher) {
      let val = parseFloat(khzHigher[1]) * 1000;
      if (val >= 400 && val <= 8000) recommendedCrossover = val;
    }
  }

  // 3. Extract Woofer SPL / Sensitivity & Tweeter SPL
  const dbValues = [];
  const dbRegex = /\b(\d{2,3}(?:\.\d+)?)\s*dB/gi;
  let dbMatch;
  while ((dbMatch = dbRegex.exec(normText)) !== null) {
    const v = parseFloat(dbMatch[1]);
    if (v >= 80 && v <= 125 && !dbValues.includes(v)) {
      dbValues.push(v);
    }
  }
  if (dbValues.length >= 1) ts.spl = dbValues[0];
  if (dbValues.length >= 2) tweeter.spl = dbValues[1];

  // Fallback explicit matches for SPL
  const lfSplMatch = normText.match(/(?:LF\s+Sensitivity|(?:Sensitivity|SPL)\s*\(\s*LF)[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*dB/i) ||
                     normText.match(/(?:Sensitivity|SPL)\s*[:=.]*\s*([\d.]+)/i);
  if (lfSplMatch) ts.spl = parseFloat(lfSplMatch[1]);

  const hfSplMatch = normText.match(/(?:HF\s+Sensitivity|(?:Sensitivity|SPL)\s*\(\s*HF)[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*dB/i);
  if (hfSplMatch) tweeter.spl = parseFloat(hfSplMatch[1]);

  // 4. Extract Ohm values for Re & HF Re (no \b after non-word symbol Ω!)
  const ohmValues = [];
  const ohmRegex = /\b(\d+(?:\.\d+)?)\s*(?:Ω|Ohm|ohm)/gi;
  let ohmMatch;
  while ((ohmMatch = ohmRegex.exec(normText)) !== null) {
    const v = parseFloat(ohmMatch[1]);
    if (v >= 1.0 && v <= 32.0 && !ohmValues.includes(v)) {
      ohmValues.push(v);
    }
  }

  // 5. Extract Inductance (mH) values
  const mhValues = [];
  const mhRegex = /\b(\d+(?:\.\d+)?)\s*mH/gi;
  let mhMatch;
  while ((mhMatch = mhRegex.exec(normText)) !== null) {
    mhValues.push(parseFloat(mhMatch[1]));
  }

  // 6. Inline regex matching (Fs, Re, Qes, Qms, Qts, Vas, Le, Sd, Xmax)
  const inlineFs = normText.match(/\b(?:Fs|Resonant\s+Frequency)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:Hz)?/i);
  if (inlineFs) {
    const v = parseFloat(inlineFs[1]);
    if (v >= 15 && v <= 200) ts.fs = v;
  }
  const inlineRe = normText.match(/\b(?:Re|DC\s+Resistance|Voice\s+coil\s+resistance)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:Ω|Ohm)?/i);
  if (inlineRe) {
    const v = parseFloat(inlineRe[1]);
    if (v >= 1.0 && v <= 30.0) ts.re = v;
  }
  const inlineQes = normText.match(/\b(?:Qes|Electrical\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)/i);
  if (inlineQes) ts.qes = parseFloat(inlineQes[1]);
  const inlineQms = normText.match(/\b(?:Qms|Mechanical\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)/i);
  if (inlineQms) ts.qms = parseFloat(inlineQms[1]);
  const inlineQts = normText.match(/\b(?:Qts|Total\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)/i);
  if (inlineQts) ts.qts = parseFloat(inlineQts[1]);
  const inlineVas = normText.match(/\b(?:Vas|Equivalent\s+(?:Air\s+)?Volume(?:\s+to\s+Cms)?)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(l|lt|ltr|liters?|litres?|dm[3³]|cu\.?\s*ft\.?|ft[3³])?/i);
  if (inlineVas) {
    let v = parseFloat(inlineVas[1]);
    if (inlineVas[2] && (inlineVas[2].toLowerCase().includes('ft') || inlineVas[2].toLowerCase().includes('cu'))) v *= 28.3168;
    ts.vas = parseFloat(v.toFixed(1));
  }
  const inlineLe = normText.match(/\b(?:Le|Inductance)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:mH)?/i);
  if (inlineLe) ts.le = parseFloat(inlineLe[1]);
  const inlineSd = normText.match(/\b(?:Sd|Surface\s+Area)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(cm[2²]|m[2²])?/i);
  if (inlineSd) {
    let v = parseFloat(inlineSd[1]);
    if (inlineSd[2] && inlineSd[2].toLowerCase().startsWith('m')) v *= 10000;
    ts.sd = parseFloat(v.toFixed(1));
  }
  const inlineXmax = normText.match(/\bX-?max\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:mm)?/i);
  if (inlineXmax) ts.xmax = parseFloat(inlineXmax[1]);

  // 7. Column/Table Layout Fallback Strategy (e.g. B&C, Beyma, 18 Sound, FaitalPRO)
  const numRegex = /\b(\d+(?:\.\d+)?)\b/g;
  const numbers = [];
  let nm;
  while ((nm = numRegex.exec(normText)) !== null) {
    numbers.push({ val: parseFloat(nm[1]), index: nm.index });
  }

  let qFoundIndex = -1;
  if (!ts.qes || !ts.qms || !ts.qts) {
    for (let i = 0; i < numbers.length - 2; i++) {
      const n1 = numbers[i].val;
      const n2 = numbers[i + 1].val;
      const n3 = numbers[i + 2].val;
      const expectedQts = (n1 * n2) / (n1 + n2);
      if (Math.abs(n3 - expectedQts) < 0.08 || Math.abs(n3 - expectedQts) / n3 < 0.15) {
        const large = Math.max(n1, n2);
        const small = Math.min(n1, n2);
        if (large >= 1.0 && large <= 30.0 && small >= 0.05 && small <= 3.0 && n3 >= 0.05 && n3 <= 2.5) {
          if (!ts.qms) ts.qms = large;
          if (!ts.qes) ts.qes = small;
          if (!ts.qts) ts.qts = n3;
          qFoundIndex = numbers[i + 2].index;
          break;
        }
      }
    }
  }

  // Recalculate Q parameters if 2 out of 3 are known
  if (ts.qes > 0 && ts.qms > 0 && !ts.qts) {
    ts.qts = parseFloat(((ts.qes * ts.qms) / (ts.qes + ts.qms)).toFixed(3));
  } else if (ts.qes > 0 && ts.qts > 0 && !ts.qms && ts.qes > ts.qts) {
    ts.qms = parseFloat(((ts.qes * ts.qts) / (ts.qes - ts.qts)).toFixed(2));
  } else if (ts.qms > 0 && ts.qts > 0 && !ts.qes && ts.qms > ts.qts) {
    ts.qes = parseFloat(((ts.qms * ts.qts) / (ts.qms - ts.qts)).toFixed(3));
  }

  // Look before Q for Re and Fs if still 0
  if (qFoundIndex !== -1) {
    const windowBeforeQ = normText.slice(Math.max(0, qFoundIndex - 350), qFoundIndex);
    if (!ts.re) {
      const reM = windowBeforeQ.match(/(\d+(?:\.\d+)?)\s*(?:Ω|Ohm)/i);
      if (reM) ts.re = parseFloat(reM[1]);
    }
    if (!ts.fs) {
      const fsM = windowBeforeQ.match(/(\d+(?:\.\d+)?)\s*Hz/i);
      if (fsM) ts.fs = parseFloat(fsM[1]);
    }
  }

  // Vas fallback near Q parameters in table block (normalized to L)
  if (!ts.vas && qFoundIndex !== -1) {
    const windowAroundQ = normText.slice(Math.max(0, qFoundIndex - 150), Math.min(normText.length, qFoundIndex + 350));
    const vasM = windowAroundQ.match(/(\d+(?:\.\d+)?)\s*(l|lt|ltr|liters?|litres?|dm[3³]|m[3³]|m\^3|cu\.?\s*ft\.?|ft[3³])\b/i);
    if (vasM) {
      ts.vas = normalizeUnitValue(parseFloat(vasM[1]), vasM[2]);
    }
  }
  if (!ts.vas) {
    const globalVas = normText.match(/\b(\d+(?:\.\d+)?)\s*(dm[3³]|liters?|litres?|m[3³]|m\^3)\b/i);
    if (globalVas) ts.vas = normalizeUnitValue(parseFloat(globalVas[1]), globalVas[2]);
  }

  // Re fallback from ohmValues
  if (!ts.re && ohmValues.length > 0) {
    const reCand = ohmValues.filter(o => o >= 3.0 && o <= 10.0);
    if (reCand.length > 0) ts.re = reCand[reCand.length - 1];
    else ts.re = ohmValues[0];
  }

  // Sd fallback near Q (normalized to cm^2)
  if (!ts.sd && qFoundIndex !== -1) {
    const windowAfterQ = normText.slice(qFoundIndex, qFoundIndex + 400);
    const sdM = windowAfterQ.match(/(\d+(?:\.\d+)?)\s*(m\s*[2²]|m\^2|cm\s*[2²]|cm\^2)/i);
    if (sdM) ts.sd = normalizeUnitValue(parseFloat(sdM[1]), sdM[2]);
  }

  // Xmax fallback near Q
  if (!ts.xmax && qFoundIndex !== -1) {
    const windowAfterQ = normText.slice(qFoundIndex, qFoundIndex + 400);
    const xmM = windowAfterQ.match(/(\d+(?:\.\d+)?)\s*mm\b/i);
    if (xmM) ts.xmax = parseFloat(xmM[1]);
  }

  // Le fallback near Q (normalized to mH)
  if (!ts.le && qFoundIndex !== -1) {
    const windowAfterQ = normText.slice(qFoundIndex, qFoundIndex + 500);
    const leM = windowAfterQ.match(/(\d+(?:\.\d+)?)\s*(mH|H)\b/i);
    if (leM) ts.le = normalizeUnitValue(parseFloat(leM[1]), leM[2]);
  }
  if (!ts.le) {
    if (mhValues.length > 0) ts.le = Math.max(...mhValues);
    else {
      const mhMatch = normText.match(/(\d+(?:\.\d+)?)\s*mH/i);
      if (mhMatch) ts.le = parseFloat(mhMatch[1]);
    }
  }

  // Fs fallback
  if (!ts.fs) {
    const hzMatches = [...normText.matchAll(/\b(\d+(?:\.\d+)?)\s*Hz\b/gi)].map(h => parseFloat(h[1]));
    const fsCand = hzMatches.find(f => f >= 20 && f <= 150);
    if (fsCand) ts.fs = fsCand;
  }

  // Tweeter Fs & Re
  if (recommendedCrossover > 0) {
    tweeter.fs = Math.round(recommendedCrossover * 0.75);
  } else if (!tweeter.fs) {
    const twFsM = normText.match(/(?:Tweeter|HF)\s*(?:Fs|Resonance)[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(k?Hz)?/i);
    if (twFsM) {
      let v = parseFloat(twFsM[1]);
      if ((twFsM[2] && twFsM[2].toLowerCase().startsWith('k')) || v < 20) v *= 1000;
      tweeter.fs = v;
    } else {
      tweeter.fs = 1200;
    }
  }

  if (!tweeter.re) {
    const twOhmCand = ohmValues.filter(o => o >= 4.0 && Math.abs(o - ts.re) > 0.5);
    if (twOhmCand.length > 0) tweeter.re = twOhmCand[0];
    else tweeter.re = 6.0;
  }

  // 8. Plausibility Validation & Missing Parameter Detection
  const missingParams = [];
  const warnings = [];

  if (!ts.fs) missingParams.push('Fs');
  else if (ts.fs < 15 || ts.fs > 250) warnings.push(`Fs (${ts.fs} Hz) is outside typical woofer range (15–200 Hz).`);

  if (!ts.qes) missingParams.push('Qes');
  else if (ts.qes < 0.08 || ts.qes > 2.5) warnings.push(`Qes (${ts.qes}) is outside typical range (0.1–2.0).`);

  if (!ts.qms) missingParams.push('Qms');
  else if (ts.qms < 0.8 || ts.qms > 30.0) warnings.push(`Qms (${ts.qms}) is outside typical range (1.0–25.0).`);

  if (!ts.qts) missingParams.push('Qts');
  else if (ts.qts < 0.08 || ts.qts > 2.0) warnings.push(`Qts (${ts.qts}) is outside typical range (0.1–1.5).`);

  if (!ts.vas) missingParams.push('Vas');
  else if (ts.vas < 1.0 || ts.vas > 900.0) warnings.push(`Vas (${ts.vas} L) is outside typical range (2–800 L).`);

  if (!ts.re) missingParams.push('Re');
  else if (ts.re < 1.0 || ts.re > 25.0) warnings.push(`Woofer Re (${ts.re} Ω) is outside typical range (1.5–20 Ω).`);

  if (!ts.spl) missingParams.push('Sensitivity');
  else if (ts.spl < 75 || ts.spl > 115) warnings.push(`Woofer Sensitivity (${ts.spl} dB) seems implausible.`);

  if (tweeter.spl && (tweeter.spl < 85 || tweeter.spl > 125)) {
    warnings.push(`Tweeter Sensitivity (${tweeter.spl} dB) seems implausible.`);
  }

  if (recommendedCrossover > 0 && (recommendedCrossover < 500 || recommendedCrossover > 8000)) {
    warnings.push(`Recommended Crossover (${recommendedCrossover} Hz) seems outside typical coaxial range.`);
  }

  return { driverName, ts, tweeter, recommendedCrossover, missingParams, warnings, rawText: text };
}

/**
 * Extracts raw textual content across all pages of a PDF given an ArrayBuffer or Uint8Array.
 */
export async function extractTextFromPDF(data) {
  const bytes = data instanceof Uint8Array ? data.slice() : new Uint8Array(data.slice ? data.slice(0) : data);
  const loadingTask = pdfjs.getDocument({ data: bytes });
  const pdf = await loadingTask.promise;

  let extractedText = '';
  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items.map((item) => item.str).join('\n');
    extractedText += pageText + '\n';
  }
  return extractedText;
}

/**
 * Parses datasheet from an ArrayBuffer containing PDF or text data.
 */
export async function parseDatasheetFromArrayBuffer(arrayBuffer, filename = '') {
  const isPDF = filename.toLowerCase().endsWith('.pdf') ||
    (arrayBuffer.byteLength >= 4 && new Uint8Array(arrayBuffer.slice(0, 4)).every((b, i) => b === [0x25, 0x50, 0x44, 0x46][i]));
  let extractedText = '';
  if (isPDF) {
    extractedText = await extractTextFromPDF(arrayBuffer);
  } else {
    extractedText = new TextDecoder().decode(arrayBuffer);
  }
  return parseDatasheetText(extractedText, filename);
}

/**
 * Parses datasheet from a local File or Blob object (e.g. from an <input type="file"> or drag-and-drop).
 */
export async function parseDatasheetFromFile(file) {
  const isPDF = file.type === 'application/pdf' || file.name?.toLowerCase().endsWith('.pdf');
  let extractedText = '';

  if (isPDF) {
    const arrayBuffer = await file.arrayBuffer();
    extractedText = await extractTextFromPDF(arrayBuffer);
  } else {
    extractedText = await file.text();
  }

  return parseDatasheetText(extractedText, file.name || 'Local Datasheet');
}

/**
 * Downloads and parses datasheet from a URL (handles PDF or text/HTML responses).
 */
export async function parseDatasheetFromURL(url) {
  // CORS proxies if direct fetch fails due to CORS
  const fetchWithProxy = async (targetUrl) => {
    const proxies = [
      (u) => u,
      (u) => `https://api.allorigins.win/raw?url=${encodeURIComponent(u)}`,
      (u) => `https://corsproxy.io/?${encodeURIComponent(u)}`
    ];

    for (const proxyFn of proxies) {
      try {
        const proxyUrl = proxyFn(targetUrl);
        const res = await fetch(proxyUrl);
        if (res.ok) return res;
      } catch (_e) {
        // try next proxy
      }
    }
    throw new Error('Unable to download datasheet from provided URL.');
  };

  const response = await fetchWithProxy(url);
  const contentType = response.headers.get('content-type') || '';
  const isPDF = contentType.includes('application/pdf') || url.toLowerCase().endsWith('.pdf');

  let extractedText = '';

  if (isPDF) {
    const arrayBuffer = await response.arrayBuffer();
    extractedText = await extractTextFromPDF(arrayBuffer);
  } else {
    extractedText = await response.text();
  }

  return parseDatasheetText(extractedText, url);
}

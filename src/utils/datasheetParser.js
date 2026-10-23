import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';

// Configure pdfjs worker if in browser
if (typeof window !== 'undefined' && pdfjs.GlobalWorkerOptions && !pdfjs.GlobalWorkerOptions.workerSrc) {
  pdfjs.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjs.version}/pdf.worker.min.mjs`;
}

/**
 * Parses loudspeaker datasheet text (from PDF or HTML/plain text)
 * and extracts Thiele-Small woofer parameters and tweeter parameters.
 */
export function parseDatasheetText(text, url = '') {
  const ts = { fs: 0, qes: 0, qms: 0, qts: 0, vas: 0, re: 0, le: 0, sd: 0, xmax: 0, spl: 0 };
  const tweeter = { fs: 0, re: 0, spl: 0 };
  let driverName = '';

  // 1. Extract Driver Name
  const namePatterns = [
    /\b(\d{1,2}[A-Z]{2,4}\d{2,4}(?:-[0-9\+]+)?)\b/i,
    /\b([A-Z0-9]{3,12}(?:\s+[A-Z0-9]+)?)\b/i
  ];
  for (const regex of namePatterns) {
    const m = text.match(regex);
    if (m && m[1] && !['COAXIALS', 'SPECIFICATIONS', 'DESCRIPTION', 'PARAMETERS', 'SERVICE'].includes(m[1].toUpperCase())) {
      driverName = m[1].trim();
      break;
    }
  }
  if (!driverName && url) {
    const filename = url.split('/').pop()?.replace(/\.pdf$/i, '')?.replace(/[-_+]/g, ' ');
    if (filename) driverName = filename;
  }
  if (!driverName) driverName = 'Parsed Coaxial Driver';

  // 2. Extract Woofer SPL / Sensitivity & Tweeter SPL
  const dbValues = [];
  const dbRegex = /\b(\d{2,3}(?:\.\d+)?)\s*dB\b/gi;
  let dbMatch;
  while ((dbMatch = dbRegex.exec(text)) !== null) {
    const v = parseFloat(dbMatch[1]);
    if (v >= 80 && v <= 120 && !dbValues.includes(v)) {
      dbValues.push(v);
    }
  }
  if (dbValues.length >= 1) ts.spl = dbValues[0];
  if (dbValues.length >= 2) tweeter.spl = dbValues[1];

  // Fallback explicit matches for SPL
  if (!ts.spl) {
    const splMatch = text.match(/LF\s+Sensitivity[^\n]*\n*[\s\S]*?(\d+(?:\.\d+)?)\s*dB/i) ||
                     text.match(/(?:Sensitivity|SPL)\s*[:=.]*\s*([\d.]+)/i);
    if (splMatch) ts.spl = parseFloat(splMatch[1]);
  }
  if (!tweeter.spl) {
    const hfSplMatch = text.match(/HF\s+Sensitivity[^\n]*\n*[\s\S]*?(\d+(?:\.\d+)?)\s*dB/i) ||
                       text.match(/HF\s+(?:Sensitivity|SPL)\s*[:=.]*\s*([\d.]+)/i);
    if (hfSplMatch) tweeter.spl = parseFloat(hfSplMatch[1]);
  }

  // 3. Extract Tweeter Crossover Frequency / Fs
  const kHzMatch = text.match(/(\d+(?:\.\d+)?)\s*kHz/i);
  if (kHzMatch) {
    tweeter.fs = parseFloat(kHzMatch[1]) * 1000;
  } else {
    const hfXoMatch = text.match(/(?:Recommended\s+Crossover|HF\s+Fs)[^\n]*\n*[\s\S]*?(\d+(?:\.\d+)?)\s*(k?Hz)/i);
    if (hfXoMatch) {
      let val = parseFloat(hfXoMatch[1]);
      if (hfXoMatch[2] && hfXoMatch[2].toLowerCase() === 'khz') val *= 1000;
      else if (val < 20) val *= 1000;
      if (val >= 200) tweeter.fs = val;
    }
  }
  if (!tweeter.fs) tweeter.fs = 1200;

  // 4. Extract Ohm values for Re & HF Re
  const ohmValues = [];
  const ohmRegex = /\b(\d+(?:\.\d+)?)\s*(?:Ω|Ohm)\b/gi;
  let ohmMatch;
  while ((ohmMatch = ohmRegex.exec(text)) !== null) {
    const v = parseFloat(ohmMatch[1]);
    if (v >= 2 && v <= 32 && !ohmValues.includes(v)) {
      ohmValues.push(v);
    }
  }

  // 5. Extract Inductance (mH) values
  const mhValues = [];
  const mhRegex = /\b(\d+(?:\.\d+)?)\s*mH\b/gi;
  let mhMatch;
  while ((mhMatch = mhRegex.exec(text)) !== null) {
    mhValues.push(parseFloat(mhMatch[1]));
  }

  // 6. Single-line inline regex matching (Fs, Re, Qes, Qms, Qts, Vas, Le, Sd, Xmax)
  const inlinePatterns = {
    fs: [/\bFs\b\s*[:=.]*\s*([\d.]+)/i, /Resonance\s+Frequency\s*[:=.]*\s*([\d.]+)\s*Hz/i],
    re: [/\bRe\b\s*[:=.]*\s*([\d.]+)/i, /DC\s+Resistance\s*[:=.]*\s*([\d.]+)/i],
    qes: [/\bQes\b\s*[:=.]*\s*([\d.]+)/i],
    qms: [/\bQms\b\s*[:=.]*\s*([\d.]+)/i],
    qts: [/\bQts\b\s*[:=.]*\s*([\d.]+)/i],
    vas: [/\bVas\b\s*[:=.]*\s*([\d.]+)/i, /Equivalent\s+Control\s+Volume\s*[:=.]*\s*([\d.]+)/i],
    le: [/\bLe\b\s*(?:\([^)]*\))?\s*[:=.]*\s*([\d.]+)/i, /Voice\s+Coil\s+Inductance\s*[:=.]*\s*([\d.]+)/i],
    sd: [/\bSd\b\s*[:=.]*\s*([\d.]+)/i],
    xmax: [/\bX-?max\b\s*[:=.]*\s*([\d.]+)/i]
  };

  for (const [key, patterns] of Object.entries(inlinePatterns)) {
    for (const pat of patterns) {
      const m = text.match(pat);
      if (m) {
        ts[key] = parseFloat(m[1]);
        break;
      }
    }
  }

  // 7. Column/Table Layout Fallback Strategy (e.g. B&C, Beyma, 18 Sound, FaitalPRO)
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  const paramIdx = lines.findIndex(l => /^PARAMETERS$/i.test(l) || /THIELE-SMALL/i.test(l));

  if (paramIdx !== -1) {
    const block = lines.slice(Math.max(0, paramIdx - 35), Math.min(lines.length, paramIdx + 35)).join('\n');

    if (!ts.fs) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*Hz/i);
      if (m) ts.fs = parseFloat(m[1]);
    }
    if (!ts.re) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*Ω/i);
      if (m) ts.re = parseFloat(m[1]);
    }
    if (!ts.vas) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*(?:dm|L|liters)/i);
      if (m) ts.vas = parseFloat(m[1]);
    }
    if (!ts.sd) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*cm/i);
      if (m) ts.sd = parseFloat(m[1]);
    }
    if (!ts.xmax) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*mm/i);
      if (m) ts.xmax = parseFloat(m[1]);
    }
    if (!ts.le) {
      const m = block.match(/(\d+(?:\.\d+)?)\s*mH/i);
      if (m) ts.le = parseFloat(m[1]);
    }

    // Sequence check for Qes, Qms, Qts from numbers in the table block
    if (!ts.qes || !ts.qms || !ts.qts) {
      const numbers = [];
      const numRegex = /\b(\d+(?:\.\d+)?)\b/g;
      let match;
      while ((match = numRegex.exec(block)) !== null) {
        numbers.push(parseFloat(match[1]));
      }

      for (let i = 0; i < numbers.length - 2; i++) {
        const n1 = numbers[i];
        const n2 = numbers[i + 1];
        const n3 = numbers[i + 2];
        if (n1 >= 0.05 && n1 <= 2.0 && n2 >= 1.0 && n2 <= 30.0 && n3 >= 0.05 && n3 <= 2.0) {
          const expectedQts = (n1 * n2) / (n1 + n2);
          if (Math.abs(n3 - expectedQts) < 0.08) {
            if (!ts.qes) ts.qes = n1;
            if (!ts.qms) ts.qms = n2;
            if (!ts.qts) ts.qts = n3;
            break;
          }
        }
      }
    }
  }

  // Set Woofer Le if missing from mH values
  if (!ts.le && mhValues.length > 0) {
    ts.le = Math.max(...mhValues);
  }

  // Set Tweeter Re if missing
  if (!tweeter.re) {
    const hfReMatch = text.match(/Minimum\s+Impedance\s+HF[^\n]*\n*[\s\S]*?(\d+(?:\.\d+)?)\s*Ω/i) ||
                      text.match(/HF\s+Re\s*[:=.]*\s*([\d.]+)/i);
    if (hfReMatch) {
      tweeter.re = parseFloat(hfReMatch[1]);
    } else if (ohmValues.length > 0) {
      const twOhm = ohmValues.find(o => o !== ts.re && o >= 4);
      tweeter.re = twOhm || 6.0;
    }
  }

  // Recalculate Qts if missing
  if (ts.qes > 0 && ts.qms > 0 && !ts.qts) {
    ts.qts = parseFloat(((ts.qes * ts.qms) / (ts.qes + ts.qms)).toFixed(3));
  }

  return { driverName, ts, tweeter, rawText: text };
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
      } catch (e) {
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
    const loadingTask = pdfjs.getDocument({ data: new Uint8Array(arrayBuffer) });
    const pdf = await loadingTask.promise;

    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      const pageText = content.items.map((item) => item.str).join('\n');
      extractedText += pageText + '\n';
    }
  } else {
    extractedText = await response.text();
  }

  return parseDatasheetText(extractedText, url);
}

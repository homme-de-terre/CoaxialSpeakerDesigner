import React, { useState } from 'react';
import { Keyboard, X, BookOpen, Globe, Cpu, Calculator, CheckCircle2, AlertCircle, Layers } from 'lucide-react';

export default function KeyboardGuide({ isOpen, onClose }) {
  const [activeTab, setActiveTab] = useState('shortcuts');

  if (!isOpen) return null;

  const shortcuts = [
    { key: '0 – 9, .', label: 'Enter Digits & Decimal Point', group: 'Basic' },
    { key: 'Enter / Space', label: 'ENTER ↑ (Push & duplicate X)', group: 'Stack' },
    { key: 'Backspace', label: 'CL X (Clear display X register)', group: 'Clear' },
    { key: 'Escape / Delete', label: 'CLR (Clear entire stack X, Y, Z, T)', group: 'Clear' },
    { key: '+  –  *  /', label: 'Basic Operations (+, –, ×, ÷)', group: 'Math' },
    { key: '^  or  ^°  or  Y', label: 'x^y (Power function – handles Dead key)', group: 'Math' },
    { key: 'V', label: '√x (Square Root)', group: 'Math' },
    { key: 'U', label: '1/x (Reciprocal)', group: 'Math' },
    { key: 'G', label: 'LOG (Base 10 Logarithm)', group: 'Math' },
    { key: 'H', label: 'LN (Natural Logarithm)', group: 'Math' },
    { key: 'D', label: 'e^x (Exponential e^x)', group: 'Math' },
    { key: 'R / Q', label: 'R↓ (Roll stack down X←Y←Z←T←X)', group: 'Stack' },
    { key: 'X / W', label: 'x≷y (Swap X and Y registers)', group: 'Stack' },
    { key: 'S', label: 'SIN (Sine or arcSIN in ARC mode)', group: 'Trig' },
    { key: 'C', label: 'COS (Cosine or arcCOS in ARC mode)', group: 'Trig' },
    { key: 'T', label: 'TAN (Tangent or arcTAN in ARC mode)', group: 'Trig' },
    { key: 'A / I', label: 'ARC (Toggle Inverse Trigonometric mode)', group: 'Trig' },
    { key: 'M', label: 'STO (Store X into Memory)', group: 'Memory' },
    { key: 'L / K', label: 'RCL (Recall Memory into X)', group: 'Memory' },
    { key: 'E', label: 'EEX (Enter Scientific Exponent)', group: 'Entry' },
    { key: 'P', label: 'π (Enter Pi constant = 3.14159...)', group: 'Entry' },
    { key: 'N / ~', label: 'CH S (Change Sign + / –)', group: 'Entry' },
  ];

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-3 sm:p-4 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-2xl w-full flex flex-col max-h-[90vh] shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-lg bg-amber-500/20 border border-amber-500/30 flex items-center justify-center">
              <Calculator className="w-4 h-4 text-amber-400" />
            </div>
            <div>
              <h2 className="font-extrabold text-slate-100 text-base sm:text-lg tracking-tight">
                HP-35 User Guide & Technical Manual
              </h2>
              <p className="text-xs text-slate-400">Reverse Polish Notation & Keyboard Shortcuts Reference</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Tabs */}
        <div className="flex border-b border-slate-800 bg-slate-950/40 px-3 sm:px-5 gap-1 sm:gap-2 overflow-x-auto text-xs font-semibold scrollbar-none">
          <button
            onClick={() => setActiveTab('shortcuts')}
            className={`py-3 px-3 border-b-2 flex items-center space-x-1.5 whitespace-nowrap transition-colors ${
              activeTab === 'shortcuts'
                ? 'border-amber-500 text-amber-400 bg-amber-950/20'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Keyboard className="w-3.5 h-3.5" />
            <span>Shortcuts Map</span>
          </button>

          <button
            onClick={() => setActiveTab('deadkey')}
            className={`py-3 px-3 border-b-2 flex items-center space-x-1.5 whitespace-nowrap transition-colors ${
              activeTab === 'deadkey'
                ? 'border-amber-500 text-amber-400 bg-amber-950/20'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Globe className="w-3.5 h-3.5 text-sky-400" />
            <span>Dead Key '^°' Guide</span>
          </button>

          <button
            onClick={() => setActiveTab('rpn')}
            className={`py-3 px-3 border-b-2 flex items-center space-x-1.5 whitespace-nowrap transition-colors ${
              activeTab === 'rpn'
                ? 'border-amber-500 text-amber-400 bg-amber-950/20'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>RPN Stack Manual</span>
          </button>

          <button
            onClick={() => setActiveTab('examples')}
            className={`py-3 px-3 border-b-2 flex items-center space-x-1.5 whitespace-nowrap transition-colors ${
              activeTab === 'examples'
                ? 'border-amber-500 text-amber-400 bg-amber-950/20'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            <BookOpen className="w-3.5 h-3.5" />
            <span>Examples</span>
          </button>
        </div>

        {/* Tab Content */}
        <div className="p-4 sm:p-6 overflow-y-auto flex-1 space-y-4">
          {/* TAB 1: SHORTCUTS MAP */}
          {activeTab === 'shortcuts' && (
            <div className="space-y-3">
              <p className="text-xs text-slate-300 leading-relaxed bg-slate-950/60 p-3 rounded-lg border border-slate-800">
                You can operate every single function of the HP-35 using your physical keyboard! Simply focus anywhere on the calculator page and press keys.
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {shortcuts.map((item, idx) => (
                  <div
                    key={idx}
                    className="bg-slate-950/70 p-2.5 rounded-lg border border-slate-800/80 flex items-center justify-between text-xs hover:border-slate-700 transition-colors"
                  >
                    <kbd className="font-mono font-bold bg-slate-800 text-amber-300 px-2 py-1 rounded border border-slate-700 shadow-sm shrink-0">
                      {item.key}
                    </kbd>
                    <span className="text-slate-300 text-right font-medium ml-2">{item.label}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 2: DEAD KEY '^°' GUIDE */}
          {activeTab === 'deadkey' && (
            <div className="space-y-4 text-xs text-slate-300 leading-relaxed">
              <div className="bg-amber-950/40 border border-amber-600/40 p-4 rounded-xl flex items-start space-x-3">
                <AlertCircle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
                <div>
                  <h3 className="font-bold text-amber-300 text-sm mb-1">
                    European & International Keyboard Dead Key Resolution
                  </h3>
                  <p className="text-slate-300">
                    On QWERTZ (German), AZERTY (French), Swiss, and Spanish layouts, the <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 rounded font-mono font-bold">^°</kbd> key is a <em>dead key</em> used for composition accents.
                  </p>
                </div>
              </div>

              <div className="space-y-3 bg-slate-950/80 p-4 rounded-xl border border-slate-800">
                <h4 className="font-bold text-slate-100 text-sm flex items-center space-x-2">
                  <Cpu className="w-4 h-4 text-amber-400" />
                  <span>Why standard web key handlers fail on '^'</span>
                </h4>
                <p>
                  When you press the physical <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 rounded font-mono font-bold">^°</kbd> key on European keyboards, web browsers emit a KeyboardEvent with:
                </p>
                <ul className="list-disc list-inside space-y-1 font-mono text-[11px] text-amber-200/90 bg-slate-900 p-3 rounded border border-slate-800">
                  <li><span className="text-slate-400">event.key:</span> <span className="text-red-400">'Dead'</span> (or empty string)</li>
                  <li><span className="text-slate-400">event.code:</span> <span className="text-emerald-400">'Backquote'</span></li>
                </ul>
                <p>
                  Standard calculators listening only for <code className="text-amber-400 font-mono">e.key === '^'</code> will completely miss key presses on European computers!
                </p>
              </div>

              <div className="space-y-2 bg-slate-950/80 p-4 rounded-xl border border-slate-800">
                <h4 className="font-bold text-slate-100 text-sm flex items-center space-x-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  <span>How our simulator handles '^°' seamlessly</span>
                </h4>
                <p>
                  Our simulator intercepts keyboard events across layout standards:
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-2">
                  <div className="bg-slate-900 p-2.5 rounded-lg border border-slate-800">
                    <span className="font-bold text-amber-400 block mb-1">1. Dead Key Normalization</span>
                    <span>Intercepts <code className="text-sky-300 font-mono">key === 'Dead'</code> or <code className="text-sky-300 font-mono">code === 'Backquote'</code> and triggers <strong className="text-amber-300">x^y</strong> directly.</span>
                  </div>
                  <div className="bg-slate-900 p-2.5 rounded-lg border border-slate-800">
                    <span className="font-bold text-amber-400 block mb-1">2. Multi-Shortcut Aliasing</span>
                    <span>Accepts <kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">^</kbd>, <kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">Y</kbd> (for x^y), or <kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">**</kbd> for maximum convenience.</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* TAB 3: RPN STACK MANUAL */}
          {activeTab === 'rpn' && (
            <div className="space-y-4 text-xs text-slate-300 leading-relaxed">
              <div className="bg-slate-950/80 p-4 rounded-xl border border-slate-800 space-y-2">
                <h3 className="font-bold text-amber-300 text-sm">About the 1972 Hewlett-Packard HP-35</h3>
                <p>
                  Introduced in 1972, the HP-35 was the world's first hand-held scientific calculator. It revolutionized engineering by replacing slide rules and log tables.
                </p>
              </div>

              <div className="bg-slate-950/80 p-4 rounded-xl border border-slate-800 space-y-3">
                <h3 className="font-bold text-amber-300 text-sm">The 4-Level Operational Stack (X, Y, Z, T)</h3>
                <p>
                  The HP-35 uses Reverse Polish Notation (RPN) with an automatic 4-register memory stack:
                </p>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 font-mono text-[11px] text-center">
                  <div className="bg-indigo-950/60 border border-indigo-800/60 p-2 rounded-lg">
                    <span className="block font-bold text-indigo-300">Register T</span>
                    <span className="text-[10px] text-slate-400">Top Stack</span>
                  </div>
                  <div className="bg-blue-950/60 border border-blue-800/60 p-2 rounded-lg">
                    <span className="block font-bold text-blue-300">Register Z</span>
                    <span className="text-[10px] text-slate-400">Third Level</span>
                  </div>
                  <div className="bg-emerald-950/60 border border-emerald-800/60 p-2 rounded-lg">
                    <span className="block font-bold text-emerald-300">Register Y</span>
                    <span className="text-[10px] text-slate-400">Second Level</span>
                  </div>
                  <div className="bg-amber-950/60 border border-amber-600/60 p-2 rounded-lg">
                    <span className="block font-bold text-amber-300">Register X</span>
                    <span className="text-[10px] text-slate-400">LED Display</span>
                  </div>
                </div>
              </div>

              <div className="bg-slate-950/80 p-4 rounded-xl border border-slate-800 space-y-2">
                <h3 className="font-bold text-amber-300 text-sm">Key Principles of RPN Logic</h3>
                <ul className="list-disc list-inside space-y-1.5 text-slate-300">
                  <li><strong className="text-slate-100">No Parentheses Necessary:</strong> Operands are entered before the operator. E.g., for <code className="text-amber-400 font-mono">(3 + 4) × 5</code>, press <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 font-mono rounded">3</kbd> <kbd className="px-1.5 py-0.5 bg-amber-700 text-white font-mono rounded">ENTER↑</kbd> <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 font-mono rounded">4</kbd> <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 font-mono rounded">+</kbd> <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 font-mono rounded">5</kbd> <kbd className="px-1.5 py-0.5 bg-slate-800 text-amber-300 font-mono rounded">×</kbd>.</li>
                  <li><strong className="text-slate-100">Automatic Stack Lift:</strong> Typing a new number after an operation automatically pushes current values up (<code className="text-amber-400 font-mono">X→Y, Y→Z, Z→T</code>).</li>
                  <li><strong className="text-slate-100">Binary Operations Stack Drop:</strong> Operators like <code className="text-amber-400 font-mono">+ - × ÷ x^y</code> combine Y and X, replacing X with result and dropping the stack (<code className="text-amber-400 font-mono">Y←Z, Z←T</code>).</li>
                  <li><strong className="text-slate-100">Stack Rolling (R↓):</strong> Rotates all 4 registers downward: <code className="text-amber-400 font-mono">X←Y, Y←Z, Z←T, T←X</code>.</li>
                  <li><strong className="text-slate-100">Swap (x≷y):</strong> Exchanges the values in registers X and Y.</li>
                </ul>
              </div>
            </div>
          )}

          {/* TAB 4: EXAMPLES */}
          {activeTab === 'examples' && (
            <div className="space-y-3 text-xs">
              <div className="bg-slate-950/80 p-3.5 rounded-xl border border-slate-800 space-y-1.5">
                <span className="font-bold text-amber-300 text-sm block">1. Power Calculation: 2^10 = 1024</span>
                <p className="text-slate-400">Calculate 2 to the power of 10 using the power key (<kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">x^y</kbd> / <kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">^°</kbd> / <kbd className="px-1 bg-slate-800 text-amber-300 font-mono rounded">Y</kbd>):</p>
                <div className="font-mono bg-slate-900 p-2.5 rounded border border-slate-800 text-amber-300 font-bold">
                  2 ➔ ENTER↑ ➔ 10 ➔ x^y ➔ Result: 1024.
                </div>
              </div>

              <div className="bg-slate-950/80 p-3.5 rounded-xl border border-slate-800 space-y-1.5">
                <span className="font-bold text-amber-300 text-sm block">2. Hypotenuse: √(3² + 4²) = 5</span>
                <p className="text-slate-400">Pythagorean theorem calculation:</p>
                <div className="font-mono bg-slate-900 p-2.5 rounded border border-slate-800 text-amber-300 font-bold">
                  3 ➔ ENTER↑ ➔ × ➔ 4 ➔ ENTER↑ ➔ × ➔ + ➔ √x ➔ Result: 5.
                </div>
              </div>

              <div className="bg-slate-950/80 p-3.5 rounded-xl border border-slate-800 space-y-1.5">
                <span className="font-bold text-amber-300 text-sm block">3. Inverse Trigonometry: arcsin(0.5) = 30°</span>
                <p className="text-slate-400">Toggle ARC mode, then press SIN:</p>
                <div className="font-mono bg-slate-900 p-2.5 rounded border border-slate-800 text-amber-300 font-bold">
                  0.5 ➔ ARC (or A key) ➔ SIN ➔ Result: 30°
                </div>
              </div>

              <div className="bg-slate-950/80 p-3.5 rounded-xl border border-slate-800 space-y-1.5">
                <span className="font-bold text-amber-300 text-sm block">4. Circle Area: π × 5² ≈ 78.5398</span>
                <p className="text-slate-400">Radius = 5:</p>
                <div className="font-mono bg-slate-900 p-2.5 rounded border border-slate-800 text-amber-300 font-bold">
                  5 ➔ ENTER↑ ➔ × ➔ π ➔ × ➔ Result: 78.5398
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 bg-slate-950/80 flex items-center justify-between">
          <span className="text-[11px] text-slate-500 hidden sm:inline">
            Press <kbd className="px-1.5 py-0.5 bg-slate-800 text-slate-300 font-mono rounded">Esc</kbd> anytime to close this manual
          </span>
          <button
            onClick={onClose}
            className="w-full sm:w-auto bg-amber-600 hover:bg-amber-500 text-slate-950 font-bold text-xs px-6 py-2 rounded-lg transition-colors shadow-md ml-auto"
          >
            Close Guide
          </button>
        </div>
      </div>
    </div>
  );
}

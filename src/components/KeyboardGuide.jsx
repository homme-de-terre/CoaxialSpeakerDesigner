import React from 'react';
import { Keyboard, X, Info } from 'lucide-react';

export default function KeyboardGuide({ isOpen, onClose }) {
  if (!isOpen) return null;

  const shortcuts = [
    { key: '0 – 9, .', label: 'Enter Digits & Decimal Point' },
    { key: 'Enter / Space', label: 'ENTER ↑ (Push stack)' },
    { key: 'Backspace', label: 'CL X (Clear display register)' },
    { key: 'Escape', label: 'CLR (Clear entire stack X, Y, Z, T)' },
    { key: '+  –  *  /', label: 'Basic Operations (+, –, ×, ÷)' },
    { key: '^', label: 'x^y (Power function)' },
    { key: 'R / Q', label: 'R↓ (Roll stack down)' },
    { key: 'X / W', label: 'x≷y (Swap X and Y)' },
    { key: 'S / C / T', label: 'SIN / COS / TAN' },
    { key: 'A', label: 'ARC (Inverse trigonometric mode)' },
    { key: 'M', label: 'STO (Store X to Memory)' },
    { key: 'L', label: 'RCL (Recall Memory to X)' },
    { key: 'E', label: 'EEX (Enter Scientific Exponent)' },
    { key: 'P', label: 'π (Enter Pi constant)' },
    { key: 'N', label: 'CH S (Change Sign + / -)' },
  ];

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-5 sm:p-6 shadow-2xl space-y-4">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center space-x-2">
            <Keyboard className="w-5 h-5 text-amber-400" />
            <h2 className="font-bold text-slate-100 text-base sm:text-lg">Physical Keyboard Bindings</h2>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <p className="text-xs text-slate-400 leading-relaxed">
          You can use your computer's physical keyboard to operate the HP-35 calculator seamlessly!
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-[360px] overflow-y-auto pr-1">
          {shortcuts.map((item, idx) => (
            <div
              key={idx}
              className="bg-slate-950/70 p-2.5 rounded-lg border border-slate-800/80 flex items-center justify-between text-xs"
            >
              <kbd className="font-mono font-bold bg-slate-800 text-amber-300 px-2 py-1 rounded border border-slate-700 shadow-sm">
                {item.key}
              </kbd>
              <span className="text-slate-300 text-right font-medium">{item.label}</span>
            </div>
          ))}
        </div>

        <div className="pt-2 text-center">
          <button
            onClick={onClose}
            className="bg-amber-600 hover:bg-amber-500 text-slate-950 font-bold text-xs px-5 py-2 rounded-lg transition-colors shadow-md"
          >
            Got it, let's calculate!
          </button>
        </div>
      </div>
    </div>
  );
}

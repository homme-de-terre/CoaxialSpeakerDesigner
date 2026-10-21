import React from 'react';
import { Layers, Database, ArrowDown, ArrowUp, RefreshCw } from 'lucide-react';

export default function StackVisualizer({ stack, memory, angleMode, liftEnabled, isEnteringNumber }) {
  const registers = [
    { name: 'T', label: 'Top Register', val: stack.T, bg: 'bg-indigo-950/40 border-indigo-800/40 text-indigo-200' },
    { name: 'Z', label: 'Third Register', val: stack.Z, bg: 'bg-blue-950/40 border-blue-800/40 text-blue-200' },
    { name: 'Y', label: 'Second Register', val: stack.Y, bg: 'bg-emerald-950/40 border-emerald-800/40 text-emerald-200' },
    { name: 'X', label: 'Display Register', val: stack.X, bg: 'bg-amber-950/50 border-amber-600/60 text-amber-300 font-bold' },
  ];

  return (
    <div className="bg-slate-900/90 rounded-xl p-4 sm:p-5 border border-slate-800 shadow-xl flex flex-col h-full">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800 mb-4">
        <div className="flex items-center space-x-2">
          <Layers className="w-5 h-5 text-amber-400" />
          <h2 className="font-bold text-slate-100 text-sm sm:text-base">RPN Operational Stack</h2>
        </div>
        <div className="flex items-center space-x-2 text-xs">
          <span className="px-2 py-0.5 rounded-full bg-slate-800 text-slate-400 border border-slate-700 font-mono">
            4-Level Stack
          </span>
        </div>
      </div>

      <p className="text-xs text-slate-400 mb-4 leading-relaxed">
        RPN uses an operational stack. Numbers pushed onto the stack flow up through registers <code className="text-amber-400">X → Y → Z → T</code>.
      </p>

      {/* Stack Registers Flow */}
      <div className="flex-1 flex flex-col justify-center space-y-2.5">
        {registers.map((reg, idx) => (
          <div
            key={reg.name}
            className={`flex items-center justify-between p-3 rounded-lg border transition-all duration-200 ${reg.bg}`}
          >
            <div className="flex items-center space-x-3">
              <span className="w-7 h-7 rounded-md bg-slate-900 flex items-center justify-center font-mono font-bold text-xs text-amber-400 border border-slate-700 shadow-inner">
                {reg.name}
              </span>
              <span className="text-xs text-slate-300 hidden sm:inline">{reg.label}</span>
            </div>

            <div className="font-mono text-sm sm:text-base font-semibold truncate max-w-[180px] sm:max-w-[220px] text-right">
              {reg.val}
            </div>
          </div>
        ))}
      </div>

      {/* Bottom Info: Memory and Lift State */}
      <div className="mt-4 pt-3 border-t border-slate-800 grid grid-cols-2 gap-2 text-xs font-mono">
        <div className="bg-slate-950/60 p-2.5 rounded-lg border border-slate-800 flex items-center justify-between">
          <div className="flex items-center space-x-1.5 text-slate-400">
            <Database className="w-3.5 h-3.5 text-emerald-400" />
            <span>Memory (M):</span>
          </div>
          <span className="text-emerald-300 font-bold">{memory}</span>
        </div>

        <div className="bg-slate-950/60 p-2.5 rounded-lg border border-slate-800 flex items-center justify-between">
          <span className="text-slate-400">Stack Lift:</span>
          <span className={liftEnabled ? 'text-sky-400 font-bold' : 'text-slate-500'}>
            {liftEnabled ? 'ENABLED' : 'DISABLED'}
          </span>
        </div>
      </div>
    </div>
  );
}

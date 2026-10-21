import React from 'react';
import { History, Trash2, ArrowRight } from 'lucide-react';

export default function HistoryLog({ history, onClear, onRestoreStack }) {
  return (
    <div className="bg-slate-900/90 rounded-xl p-4 sm:p-5 border border-slate-800 shadow-xl flex flex-col h-full">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800 mb-3">
        <div className="flex items-center space-x-2">
          <History className="w-5 h-5 text-amber-400" />
          <h2 className="font-bold text-slate-100 text-sm sm:text-base">Calculation History</h2>
        </div>
        {history.length > 0 && (
          <button
            onClick={onClear}
            className="text-xs text-slate-400 hover:text-red-400 flex items-center space-x-1 px-2 py-1 rounded hover:bg-slate-800 transition-colors"
            title="Clear calculation log"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Clear</span>
          </button>
        )}
      </div>

      {history.length === 0 ? (
        <div className="flex-1 flex flex-col items-center justify-center text-slate-500 py-8 text-xs text-center space-y-2">
          <History className="w-8 h-8 stroke-1 text-slate-600" />
          <p>No calculations performed yet.</p>
          <p className="text-[11px] text-slate-600">Press keys or enter equations to log operational steps.</p>
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto max-h-[320px] space-y-2 pr-1">
          {history.map((item) => (
            <div
              key={item.id}
              onClick={() => onRestoreStack(item.stackAfter)}
              className="bg-slate-950/70 hover:bg-slate-800/80 p-3 rounded-lg border border-slate-800/80 transition-colors cursor-pointer group"
              title="Click to restore stack state"
            >
              <div className="flex items-center justify-between mb-1.5">
                <span className="font-mono font-bold text-xs bg-amber-500/20 text-amber-300 px-2 py-0.5 rounded border border-amber-500/30">
                  {item.op}
                </span>
                <span className="text-[10px] text-slate-500 font-mono group-hover:text-amber-400 transition-colors">
                  Restore state ↵
                </span>
              </div>

              {item.note && (
                <p className="text-xs text-slate-300 mb-2 font-sans font-medium">
                  {item.note}
                </p>
              )}

              {/* Stack Snapshot */}
              <div className="grid grid-cols-4 gap-1 text-[11px] font-mono bg-slate-900/90 p-1.5 rounded border border-slate-800 text-center">
                <div>
                  <span className="text-slate-500 block text-[9px]">T</span>
                  <span className="text-slate-300">{item.stackAfter.T}</span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[9px]">Z</span>
                  <span className="text-slate-300">{item.stackAfter.Z}</span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[9px]">Y</span>
                  <span className="text-slate-300">{item.stackAfter.Y}</span>
                </div>
                <div>
                  <span className="text-amber-500 block text-[9px]">X</span>
                  <span className="text-amber-300 font-bold">{item.stackAfter.X}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

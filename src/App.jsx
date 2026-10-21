import React, { useReducer, useState, useEffect, useCallback } from 'react';
import { INITIAL_STATE, rpnReducer } from './utils/rpnEngine';
import HP35Calculator from './components/HP35Calculator';
import StackVisualizer from './components/StackVisualizer';
import HistoryLog from './components/HistoryLog';
import RPNTutorial from './components/RPNTutorial';
import KeyboardGuide from './components/KeyboardGuide';
import { Calculator, RefreshCw } from 'lucide-react';

export default function App() {
  const [state, dispatch] = useReducer(rpnReducer, INITIAL_STATE);
  const [activePressedKey, setActivePressedKey] = useState(null);
  const [isKeyGuideOpen, setIsKeyGuideOpen] = useState(false);

  const triggerKeyHighlight = useCallback((keyId) => {
    setActivePressedKey(keyId);
    setTimeout(() => setActivePressedKey(null), 150);
  }, []);

  // Keyboard Event Listener
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (!state.powerOn) return;
      // Ignore if user is typing into input or textarea
      if (['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) return;

      const key = e.key;

      if (/^[0-9\.]$/.test(key)) {
        e.preventDefault();
        dispatch({ type: 'DIGIT', payload: key });
        triggerKeyHighlight(key === '.' ? 'dot' : key);
      } else if (key === 'Enter' || key === ' ') {
        e.preventDefault();
        dispatch({ type: 'ENTER' });
        triggerKeyHighlight('enter');
      } else if (key === 'Backspace') {
        e.preventDefault();
        dispatch({ type: 'CL_X' });
        triggerKeyHighlight('clx');
      } else if (key === 'Escape') {
        e.preventDefault();
        dispatch({ type: 'CLR' });
        triggerKeyHighlight('clr');
      } else if (key === '+') {
        e.preventDefault();
        dispatch({ type: 'BINARY_OP', payload: '+' });
        triggerKeyHighlight('add');
      } else if (key === '-') {
        e.preventDefault();
        dispatch({ type: 'BINARY_OP', payload: '-' });
        triggerKeyHighlight('sub');
      } else if (key === '*') {
        e.preventDefault();
        dispatch({ type: 'BINARY_OP', payload: '*' });
        triggerKeyHighlight('mul');
      } else if (key === '/') {
        e.preventDefault();
        dispatch({ type: 'BINARY_OP', payload: '/' });
        triggerKeyHighlight('div');
      } else if (key === '^') {
        e.preventDefault();
        dispatch({ type: 'BINARY_OP', payload: 'pow' });
        triggerKeyHighlight('pow');
      } else if (key.toLowerCase() === 'r') {
        e.preventDefault();
        dispatch({ type: 'ROLL_DOWN' });
        triggerKeyHighlight('roll');
      } else if (key.toLowerCase() === 'x') {
        e.preventDefault();
        dispatch({ type: 'SWAP' });
        triggerKeyHighlight('swap');
      } else if (key.toLowerCase() === 's') {
        e.preventDefault();
        dispatch({ type: 'UNARY_OP', payload: 'sin' });
        triggerKeyHighlight('sin');
      } else if (key.toLowerCase() === 'c') {
        e.preventDefault();
        dispatch({ type: 'UNARY_OP', payload: 'cos' });
        triggerKeyHighlight('cos');
      } else if (key.toLowerCase() === 't') {
        e.preventDefault();
        dispatch({ type: 'UNARY_OP', payload: 'tan' });
        triggerKeyHighlight('tan');
      } else if (key.toLowerCase() === 'a') {
        e.preventDefault();
        dispatch({ type: 'ARC_TOGGLE' });
        triggerKeyHighlight('arc');
      } else if (key.toLowerCase() === 'm') {
        e.preventDefault();
        dispatch({ type: 'STO' });
        triggerKeyHighlight('sto');
      } else if (key.toLowerCase() === 'l') {
        e.preventDefault();
        dispatch({ type: 'RCL' });
        triggerKeyHighlight('rcl');
      } else if (key.toLowerCase() === 'e') {
        e.preventDefault();
        dispatch({ type: 'EEX' });
        triggerKeyHighlight('eex');
      } else if (key.toLowerCase() === 'p') {
        e.preventDefault();
        dispatch({ type: 'PI' });
        triggerKeyHighlight('pi');
      } else if (key.toLowerCase() === 'n') {
        e.preventDefault();
        dispatch({ type: 'CH_S' });
        triggerKeyHighlight('chs');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [state.powerOn, triggerKeyHighlight]);

  const handleRestoreStack = (stackState) => {
    dispatch({ type: 'SET_STACK', payload: stackState });
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-amber-500 selection:text-slate-950">
      {/* Top Navigation Bar */}
      <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur-md sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3.5 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-amber-500 to-amber-700 flex items-center justify-center shadow-lg border border-amber-400/40">
              <Calculator className="w-5 h-5 text-slate-950" />
            </div>
            <div>
              <h1 className="font-extrabold text-base sm:text-lg text-slate-100 tracking-tight leading-none flex items-center gap-2">
                HP 35 <span className="text-amber-400 font-serif italic text-sm font-normal">RPN Simulator</span>
              </h1>
              <p className="text-[11px] text-slate-400 hidden sm:block">
                The Iconic 1972 Handheld Scientific Calculator
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-3 text-xs font-semibold">
            <button
              onClick={() => setIsKeyGuideOpen(true)}
              className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-amber-300 border border-slate-700 transition-colors flex items-center space-x-1.5"
            >
              <span>Shortcuts Guide</span>
            </button>
            <button
              onClick={() => dispatch({ type: 'CLR' })}
              className="px-3 py-1.5 rounded-lg bg-red-950/60 hover:bg-red-900/80 text-red-300 border border-red-800/80 transition-colors flex items-center space-x-1.5"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Reset Stack</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Layout */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-6 sm:py-8 grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Column: Authentic HP 35 Calculator Body */}
        <section className="lg:col-span-5 flex justify-center">
          <HP35Calculator
            state={state}
            dispatch={dispatch}
            activePressedKey={activePressedKey}
            onOpenKeyGuide={() => setIsKeyGuideOpen(true)}
          />
        </section>

        {/* Right Column: Live Stack Visualizer & History */}
        <section className="lg:col-span-7 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <StackVisualizer
              stack={state.stack}
              memory={state.memory}
              angleMode={state.angleMode}
              liftEnabled={state.liftEnabled}
              isEnteringNumber={state.isEnteringNumber}
            />

            <HistoryLog
              history={state.history}
              onClear={() => dispatch({ type: 'CLEAR_HISTORY' })}
              onRestoreStack={handleRestoreStack}
            />
          </div>

          {/* RPN Tutorial Walkthrough & Example Presets */}
          <RPNTutorial
            dispatch={dispatch}
            onTriggerKeyHighlight={triggerKeyHighlight}
          />
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-900 bg-slate-950 py-4 text-center text-xs text-slate-500">
        <p>HP 35 RPN Scientific Web Calculator Simulator • Modeled after the 1972 Hewlett-Packard HP-35</p>
      </footer>

      {/* Keyboard Shortcuts Modal */}
      <KeyboardGuide
        isOpen={isKeyGuideOpen}
        onClose={() => setIsKeyGuideOpen(false)}
      />
    </div>
  );
}

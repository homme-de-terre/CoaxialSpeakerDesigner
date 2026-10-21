import React, { useState } from 'react';
import { BookOpen, Play, CheckCircle2, ArrowRight, HelpCircle, Lightbulb } from 'lucide-react';

const TUTORIAL_PRESETS = [
  {
    id: 'basic_eval',
    title: 'Basic Arithmetic: (3 + 4) × 5',
    category: 'Fundamentals',
    description: 'In standard infix notation, parentheses dictate order of operations. In RPN, you place operands before the operator without parentheses!',
    steps: [
      { key: '3', action: 'DIGIT', payload: '3', desc: 'Type 3 into register X' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 3 into register Y, X remains 3' },
      { key: '4', action: 'DIGIT', payload: '4', desc: 'Type 4 into register X' },
      { key: '+', action: 'BINARY_OP', payload: '+', desc: 'Compute 3 + 4 = 7 in X' },
      { key: '5', action: 'DIGIT', payload: '5', desc: 'Type 5 into X (lifts 7 to Y)' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 7 × 5 = 35' }
    ]
  },
  {
    id: 'pythagoras',
    title: 'Pythagorean Theorem: √(3² + 4²)',
    category: 'Geometry',
    description: 'Calculate the hypotenuse of a right triangle with legs a=3 and b=4 using square and square root functions.',
    steps: [
      { key: '3', action: 'DIGIT', payload: '3', desc: 'Type leg a = 3' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 3 to stack' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 3 × 3 = 9 (a²)' },
      { key: '4', action: 'DIGIT', payload: '4', desc: 'Type leg b = 4' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 4 to stack' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 4 × 4 = 16 (b²)' },
      { key: '+', action: 'BINARY_OP', payload: '+', desc: 'Compute 9 + 16 = 25 (a² + b²)' },
      { key: '√x', action: 'UNARY_OP', payload: 'sqrt', desc: 'Take square root: √25 = 5' }
    ]
  },
  {
    id: 'chain_div',
    title: 'Chain Division: 100 / (2 × 5)',
    category: 'Algebra',
    description: 'Evaluate fraction where denominator is a product without storing temporary variables.',
    steps: [
      { key: '100', action: 'DIGIT', payload: '100', desc: 'Type numerator 100' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 100 to Y' },
      { key: '2', action: 'DIGIT', payload: '2', desc: 'Type 2' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 2 to Y' },
      { key: '5', action: 'DIGIT', payload: '5', desc: 'Type 5' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 2 × 5 = 10 in denominator' },
      { key: '÷', action: 'BINARY_OP', payload: '/', desc: 'Compute 100 ÷ 10 = 10' }
    ]
  },
  {
    id: 'trig_circle',
    title: 'Circle Area: π × r² (r = 7)',
    category: 'Geometry',
    description: 'Calculate the area of a circle with radius 7 using the dedicated π key.',
    steps: [
      { key: '7', action: 'DIGIT', payload: '7', desc: 'Type radius r = 7' },
      { key: 'ENTER ↑', action: 'ENTER', desc: 'Push 7' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 7² = 49' },
      { key: 'π', action: 'PI', desc: 'Push π constant' },
      { key: '×', action: 'BINARY_OP', payload: '*', desc: 'Compute 49 × π ≈ 153.938' }
    ]
  }
];

export default function RPNTutorial({ dispatch, onTriggerKeyHighlight }) {
  const [selectedPreset, setSelectedPreset] = useState(TUTORIAL_PRESETS[0]);
  const [currentStepIndex, setCurrentStepIndex] = useState(-1);

  const startTutorial = (preset) => {
    setSelectedPreset(preset);
    setCurrentStepIndex(-1);
    dispatch({ type: 'CLR' });
  };

  const executeNextStep = () => {
    if (!selectedPreset) return;
    const nextIdx = currentStepIndex + 1;
    if (nextIdx >= selectedPreset.steps.length) return;

    const step = selectedPreset.steps[nextIdx];
    setCurrentStepIndex(nextIdx);

    // If payload is multi-digit string (like '100'), handle as digits
    if (step.action === 'DIGIT' && step.payload.length > 1) {
      for (const char of step.payload) {
        dispatch({ type: 'DIGIT', payload: char });
      }
    } else {
      dispatch({ type: step.action, payload: step.payload });
    }

    if (onTriggerKeyHighlight) {
      onTriggerKeyHighlight(step.key);
    }
  };

  const autoRunAll = () => {
    dispatch({ type: 'CLR' });
    let delay = 0;
    selectedPreset.steps.forEach((step, idx) => {
      setTimeout(() => {
        setCurrentStepIndex(idx);
        if (step.action === 'DIGIT' && step.payload.length > 1) {
          for (const char of step.payload) {
            dispatch({ type: 'DIGIT', payload: char });
          }
        } else {
          dispatch({ type: step.action, payload: step.payload });
        }
      }, delay);
      delay += 500;
    });
  };

  return (
    <div className="bg-slate-900/90 rounded-xl p-4 sm:p-5 border border-slate-800 shadow-xl space-y-4">
      <div className="flex items-center justify-between pb-3 border-b border-slate-800">
        <div className="flex items-center space-x-2">
          <BookOpen className="w-5 h-5 text-amber-400" />
          <h2 className="font-bold text-slate-100 text-sm sm:text-base">Interactive RPN Walkthrough</h2>
        </div>
      </div>

      {/* Preset Selector Tabs */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        {TUTORIAL_PRESETS.map((preset) => (
          <button
            key={preset.id}
            onClick={() => startTutorial(preset)}
            className={`p-2.5 rounded-lg border text-left text-xs transition-all ${
              selectedPreset.id === preset.id
                ? 'bg-amber-950/60 border-amber-600 text-amber-200 shadow'
                : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-200'
            }`}
          >
            <span className="block font-bold truncate">{preset.title.split(':')[0]}</span>
            <span className="text-[10px] text-slate-500">{preset.category}</span>
          </button>
        ))}
      </div>

      {/* Active Preset Card */}
      {selectedPreset && (
        <div className="bg-slate-950/80 p-4 rounded-xl border border-slate-800 space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <h3 className="font-bold text-amber-300 text-sm sm:text-base">{selectedPreset.title}</h3>
              <p className="text-xs text-slate-400 mt-1 leading-relaxed">{selectedPreset.description}</p>
            </div>
            <div className="flex items-center space-x-2 shrink-0">
              <button
                onClick={executeNextStep}
                disabled={currentStepIndex >= selectedPreset.steps.length - 1}
                className="bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-slate-950 font-bold text-xs px-3 py-1.5 rounded-lg flex items-center space-x-1 transition-colors shadow"
              >
                <span>Step Next</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={autoRunAll}
                className="bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold text-xs px-3 py-1.5 rounded-lg flex items-center space-x-1 border border-slate-700 transition-colors"
              >
                <Play className="w-3.5 h-3.5 text-emerald-400 fill-emerald-400" />
                <span>Auto Play</span>
              </button>
            </div>
          </div>

          {/* Steps Progress */}
          <div className="space-y-2 pt-2 border-t border-slate-900">
            {selectedPreset.steps.map((step, idx) => {
              const isCompleted = idx <= currentStepIndex;
              const isCurrent = idx === currentStepIndex;

              return (
                <div
                  key={idx}
                  className={`p-2.5 rounded-lg border flex items-center justify-between text-xs transition-colors ${
                    isCurrent
                      ? 'bg-amber-950/80 border-amber-500 text-amber-200'
                      : isCompleted
                      ? 'bg-slate-900/90 border-slate-800 text-slate-300'
                      : 'bg-slate-950/40 border-slate-900 text-slate-500'
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    <span className="w-5 h-5 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center font-mono text-[10px]">
                      {idx + 1}
                    </span>
                    <span className="font-mono font-bold px-2 py-0.5 rounded bg-slate-900 text-amber-400 border border-slate-800">
                      {step.key}
                    </span>
                    <span>{step.desc}</span>
                  </div>

                  {isCompleted && (
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

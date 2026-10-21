import React, { useState, useEffect, useCallback } from 'react';
import { formatDisplayValue } from '../utils/rpnEngine';
import { sound } from '../utils/audio';
import { Volume2, VolumeX, Sparkles, HelpCircle } from 'lucide-react';

export default function HP35Calculator({ state, dispatch, activePressedKey, onOpenKeyGuide }) {
  const [arcActive, setArcActive] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState(true);

  useEffect(() => {
    sound.enabled = soundEnabled;
  }, [soundEnabled]);

  const handleKeyPress = useCallback((type, payload = null, keyId = '') => {
    sound.playKeyClick(type === 'ENTER');

    if (type === 'ARC_TOGGLE') {
      setArcActive(prev => !prev);
      return;
    }

    if (arcActive && type === 'UNARY_OP') {
      let arcOp = payload;
      if (payload === 'sin') arcOp = 'asin';
      if (payload === 'cos') arcOp = 'acos';
      if (payload === 'tan') arcOp = 'atan';
      dispatch({ type: 'UNARY_OP', payload: arcOp });
      setArcActive(false);
      return;
    }

    dispatch({ type, payload });
    if (arcActive) setArcActive(false);
  }, [arcActive, dispatch]);

  const togglePower = () => {
    sound.playSwitchSound();
    dispatch({ type: 'TOGGLE_POWER' });
  };

  const toggleAngleMode = () => {
    sound.playSwitchSound();
    dispatch({ type: 'TOGGLE_ANGLE' });
  };

  const displayString = state.powerOn
    ? state.error
      ? state.error
      : formatDisplayValue(
          state.stack.X,
          state.isEnteringNumber,
          state.entryBuffer,
          state.eexMode,
          state.eexBuffer
        )
    : '';

  // Helper for rendering HP-35 Key
  const renderKey = ({ id, label, subLabel, type, payload, variant = 'key-func', colSpan = 1, rowSpan = 1 }) => {
    const isKeyPressed = activePressedKey === id;

    return (
      <button
        key={id}
        onClick={() => handleKeyPress(type, payload, id)}
        disabled={!state.powerOn}
        className={`hp-key ${variant} ${isKeyPressed ? 'key-pressed' : ''} ${
          colSpan > 1 ? `col-span-${colSpan}` : ''
        } ${rowSpan > 1 ? `row-span-${rowSpan}` : ''} ${
          !state.powerOn ? 'opacity-50 cursor-not-allowed' : ''
        } min-h-[44px] sm:min-h-[48px] px-1 py-1 text-xs sm:text-sm font-semibold tracking-tight`}
        title={subLabel || label}
      >
        {subLabel && (
          <span className="text-[10px] text-amber-400 leading-none mb-0.5 select-none font-sans">
            {subLabel}
          </span>
        )}
        <span className="leading-tight select-none">{label}</span>
      </button>
    );
  };

  return (
    <div className="hp-case w-full max-w-[380px] sm:max-w-[410px] mx-auto p-4 sm:p-6 flex flex-direction-col space-y-4 sm:space-y-5 select-none border border-slate-700">
      {/* Top Metallic Header Badge */}
      <div className="brushed-aluminum rounded-md px-4 py-2.5 flex items-center justify-between border border-slate-400">
        <div className="flex items-center space-x-2">
          <div className="w-3 h-3 rounded-full bg-amber-500 shadow-sm border border-amber-600"></div>
          <span className="font-extrabold tracking-wider text-xs sm:text-sm text-slate-900 uppercase font-serif">
            HEWLETT · PACKARD
          </span>
        </div>
        <div className="flex items-center space-x-3">
          <span className="font-mono font-bold text-xs sm:text-sm bg-slate-900 text-amber-400 px-2 py-0.5 rounded shadow-inner">
            35
          </span>
          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            className="text-slate-900 hover:text-black transition-colors"
            title={soundEnabled ? "Mute audio clicks" : "Unmute audio clicks"}
          >
            {soundEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
          </button>
          <button
            onClick={onOpenKeyGuide}
            className="text-slate-900 hover:text-black transition-colors"
            title="Keyboard Shortcuts Map"
          >
            <HelpCircle size={16} />
          </button>
        </div>
      </div>

      {/* Switches Panel (Power ON/OFF and DEG/RAD) */}
      <div className="bg-slate-900/80 rounded-lg p-2.5 flex items-center justify-between text-xs text-slate-300 font-semibold border border-slate-800">
        {/* Power Switch */}
        <div className="flex items-center space-x-2">
          <span className="text-[11px] text-slate-400">OFF</span>
          <button
            onClick={togglePower}
            className={`w-12 h-6 rounded-full p-1 transition-colors relative focus:outline-none ${
              state.powerOn ? 'bg-emerald-600' : 'bg-slate-700'
            }`}
          >
            <div
              className={`w-4 h-4 rounded-full bg-white shadow-md transform transition-transform ${
                state.powerOn ? 'translate-x-6' : 'translate-x-0'
              }`}
            />
          </button>
          <span className="text-[11px] text-emerald-400 font-bold">ON</span>
        </div>

        {/* ARC Indicator */}
        {arcActive && (
          <span className="animate-pulse text-amber-400 text-[10px] font-mono uppercase bg-amber-950/80 px-2 py-0.5 rounded border border-amber-600/50">
            ARC ACTIVE
          </span>
        )}

        {/* Angle Mode Switch */}
        <div className="flex items-center space-x-2">
          <span className="text-[11px] text-slate-400">MODE</span>
          <button
            onClick={toggleAngleMode}
            disabled={!state.powerOn}
            className="bg-slate-800 hover:bg-slate-700 text-amber-300 font-mono text-[11px] px-2.5 py-1 rounded border border-slate-700 shadow"
          >
            {state.angleMode}
          </button>
        </div>
      </div>

      {/* LED Display Box */}
      <div className="led-display-container rounded-lg p-3 sm:p-4 min-h-[76px] flex flex-col justify-between">
        <div className="flex justify-between items-center text-[10px] font-mono text-red-900 tracking-widest uppercase">
          <span>{state.powerOn ? `HP-35 RPN [${state.angleMode}]` : 'POWER OFF'}</span>
          <span>{state.memory !== 0 ? 'M' : ''}</span>
        </div>

        {/* LED Red Digits */}
        <div className="w-full text-right overflow-x-auto whitespace-nowrap font-led text-xl sm:text-2xl tracking-wider py-1">
          {state.powerOn ? (
            <span className="led-text-active">{displayString}</span>
          ) : (
            <span className="led-text-bg opacity-20">888888888888888</span>
          )}
        </div>
      </div>

      {/* Keyboard Grid */}
      <div className="grid grid-cols-5 gap-1.5 sm:gap-2">
        {/* Row 1 */}
        {renderKey({ id: 'pow', label: 'x^y', type: 'BINARY_OP', payload: 'pow', variant: 'key-func' })}
        {renderKey({ id: 'log', label: 'LOG', type: 'UNARY_OP', payload: 'log', variant: 'key-func' })}
        {renderKey({ id: 'ln', label: 'LN', type: 'UNARY_OP', payload: 'ln', variant: 'key-func' })}
        {renderKey({ id: 'exp', label: 'e^x', type: 'UNARY_OP', payload: 'exp', variant: 'key-func' })}
        {renderKey({ id: 'clr', label: 'CLR', type: 'CLR', variant: 'key-accent' })}

        {/* Row 2 */}
        {renderKey({ id: 'sqrt', label: '√x', type: 'UNARY_OP', payload: 'sqrt', variant: 'key-func' })}
        {renderKey({ 
          id: 'arc', 
          label: 'ARC', 
          type: 'ARC_TOGGLE', 
          variant: arcActive ? 'key-accent' : 'key-func',
          subLabel: arcActive ? 'ACTIVE' : 'INV'
        })}
        {renderKey({ 
          id: 'sin', 
          label: arcActive ? 'arcSIN' : 'SIN', 
          type: 'UNARY_OP', 
          payload: 'sin', 
          variant: 'key-func' 
        })}
        {renderKey({ 
          id: 'cos', 
          label: arcActive ? 'arcCOS' : 'COS', 
          type: 'UNARY_OP', 
          payload: 'cos', 
          variant: 'key-func' 
        })}
        {renderKey({ 
          id: 'tan', 
          label: arcActive ? 'arcTAN' : 'TAN', 
          type: 'UNARY_OP', 
          payload: 'tan', 
          variant: 'key-func' 
        })}

        {/* Row 3 */}
        {renderKey({ id: 'inv', label: '1/x', type: 'UNARY_OP', payload: 'inv', variant: 'key-func' })}
        {renderKey({ id: 'swap', label: 'x≷y', type: 'SWAP', variant: 'key-func' })}
        {renderKey({ id: 'roll', label: 'R↓', type: 'ROLL_DOWN', variant: 'key-func' })}
        {renderKey({ id: 'sto', label: 'STO', type: 'STO', variant: 'key-func' })}
        {renderKey({ id: 'rcl', label: 'RCL', type: 'RCL', variant: 'key-func' })}

        {/* Row 4: ENTER ↑ (spanning 2 columns), CH S, EEX, CL X */}
        {renderKey({ id: 'enter', label: 'ENTER ↑', type: 'ENTER', variant: 'key-enter', colSpan: 2 })}
        {renderKey({ id: 'chs', label: 'CH S', type: 'CH_S', variant: 'key-func' })}
        {renderKey({ id: 'eex', label: 'EEX', type: 'EEX', variant: 'key-func' })}
        {renderKey({ id: 'clx', label: 'CL X', type: 'CL_X', variant: 'key-accent' })}

        {/* Row 5 */}
        {renderKey({ id: 'sub', label: '–', type: 'BINARY_OP', payload: '-', variant: 'key-func' })}
        {renderKey({ id: '7', label: '7', type: 'DIGIT', payload: '7', variant: 'key-digit' })}
        {renderKey({ id: '8', label: '8', type: 'DIGIT', payload: '8', variant: 'key-digit' })}
        {renderKey({ id: '9', label: '9', type: 'DIGIT', payload: '9', variant: 'key-digit' })}
        {renderKey({ id: 'add', label: '+', type: 'BINARY_OP', payload: '+', variant: 'key-func' })}

        {/* Row 6 */}
        {renderKey({ id: 'mul', label: '×', type: 'BINARY_OP', payload: '*', variant: 'key-func' })}
        {renderKey({ id: '4', label: '4', type: 'DIGIT', payload: '4', variant: 'key-digit' })}
        {renderKey({ id: '5', label: '5', type: 'DIGIT', payload: '5', variant: 'key-digit' })}
        {renderKey({ id: '6', label: '6', type: 'DIGIT', payload: '6', variant: 'key-digit' })}
        {renderKey({ id: 'div', label: '÷', type: 'BINARY_OP', payload: '/', variant: 'key-func' })}

        {/* Row 7 */}
        {renderKey({ id: '1', label: '1', type: 'DIGIT', payload: '1', variant: 'key-digit' })}
        {renderKey({ id: '2', label: '2', type: 'DIGIT', payload: '2', variant: 'key-digit' })}
        {renderKey({ id: '3', label: '3', type: 'DIGIT', payload: '3', variant: 'key-digit' })}
        {renderKey({ id: 'pi', label: 'π', type: 'PI', variant: 'key-func', colSpan: 2 })}

        {/* Row 8 */}
        {renderKey({ id: '0', label: '0', type: 'DIGIT', payload: '0', variant: 'key-digit', colSpan: 2 })}
        {renderKey({ id: 'dot', label: '.', type: 'DIGIT', payload: '.', variant: 'key-digit', colSpan: 3 })}
      </div>
    </div>
  );
}

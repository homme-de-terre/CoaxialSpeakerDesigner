/**
 * HP-35 Reverse Polish Notation (RPN) Engine State Machine
 */

export const ANGLE_MODES = {
  DEG: 'DEG',
  RAD: 'RAD'
};

export const INITIAL_STATE = {
  stack: {
    X: 0,
    Y: 0,
    Z: 0,
    T: 0
  },
  memory: 0,
  angleMode: ANGLE_MODES.DEG,
  entryBuffer: '0',
  isEnteringNumber: false,
  liftEnabled: true,
  eexMode: false,
  eexBuffer: '',
  error: null,
  powerOn: true,
  history: []
};

// Format numbers for display clean of IEEE 754 float artifacts
export function formatDisplayValue(val, isEntering, entryBuf, eexActive, eexBuf) {
  if (eexActive) {
    const main = entryBuf || '0';
    const exp = eexBuf || '0';
    return `${main} E ${exp.padStart(2, ' ')}`;
  }
  if (isEntering) {
    return entryBuf;
  }
  if (typeof val !== 'number' || isNaN(val)) {
    return '  ERROR';
  }
  if (!isFinite(val)) {
    return val > 0 ? '  9.99999 E 99' : ' -9.99999 E 99';
  }

  // Pure zero
  if (val === 0) return '0.';

  const absVal = Math.abs(val);
  if (absVal >= 1e10 || absVal < 1e-7) {
    // Scientific notation representation
    const expStr = val.toExponential(7);
    const [mantissa, exp] = expStr.split('e');
    const formattedExp = parseInt(exp, 10) >= 0 
      ? `${parseInt(exp, 10)}`.padStart(2, ' ')
      : `-${Math.abs(parseInt(exp, 10))}`.padStart(2, ' ');
    return `${parseFloat(mantissa)} E ${formattedExp}`;
  }

  // Standard fixed precision display without trailing zeroes after decimal
  let str = val.toPrecision(10);
  if (str.includes('.')) {
    str = str.replace(/0+$/, '').replace(/\.$/, '.0');
  } else {
    str = str + '.';
  }
  
  // Clean up float rounding like 0.30000000000000004
  const num = parseFloat(str);
  return `${num}`;
}

export function rpnReducer(state, action) {
  if (action.type === 'TOGGLE_POWER') {
    if (state.powerOn) {
      return { ...INITIAL_STATE, powerOn: false };
    } else {
      return { ...INITIAL_STATE, powerOn: true };
    }
  }

  if (!state.powerOn) return state;

  const { stack, memory, angleMode, entryBuffer, isEnteringNumber, liftEnabled, eexMode, eexBuffer, history } = state;
  const currentX = stack.X;

  // Helper to add history item
  const logStep = (opName, newStack, note = '') => {
    return [
      {
        id: Date.now() + Math.random(),
        op: opName,
        note,
        stackBefore: { ...stack },
        stackAfter: { ...newStack }
      },
      ...history.slice(0, 49) // keep last 50
    ];
  };

  // Helper to push value onto stack with automatic stack lift
  const liftStack = (newX) => {
    return {
      X: newX,
      Y: stack.X,
      Z: stack.Y,
      T: stack.Z
    };
  };

  switch (action.type) {
    case 'DIGIT': {
      const digit = action.payload; // '0'-'9' or '.'
      if (state.error) {
        return {
          ...state,
          error: null,
          entryBuffer: digit === '.' ? '0.' : digit,
          isEnteringNumber: true,
          stack: { ...stack, X: parseFloat(digit === '.' ? '0.' : digit) }
        };
      }

      if (eexMode) {
        let newEexBuf = eexBuffer;
        if (digit === '.') return state; // invalid in exponent
        if (newEexBuf.length < 2) {
          newEexBuf += digit;
        }
        const mainVal = parseFloat(entryBuffer || '0');
        const expVal = parseInt(newEexBuf || '0', 10);
        const newX = mainVal * Math.pow(10, expVal);
        return {
          ...state,
          eexBuffer: newEexBuf,
          stack: { ...stack, X: newX }
        };
      }

      if (!isEnteringNumber) {
        // Need to check lift
        let newStack = stack;
        if (liftEnabled) {
          newStack = liftStack(0);
        }
        const newBuf = digit === '.' ? '0.' : digit;
        return {
          ...state,
          stack: { ...newStack, X: parseFloat(newBuf) },
          entryBuffer: newBuf,
          isEnteringNumber: true,
          liftEnabled: true
        };
      } else {
        // Appending to entry buffer
        if (digit === '.' && entryBuffer.includes('.')) return state;
        const newBuf = entryBuffer === '0' && digit !== '.' ? digit : entryBuffer + digit;
        return {
          ...state,
          entryBuffer: newBuf,
          stack: { ...stack, X: parseFloat(newBuf) }
        };
      }
    }

    case 'CH_S': { // Change Sign
      if (eexMode) {
        const currentExp = parseInt(eexBuffer || '0', 10);
        const newExp = -currentExp;
        const newEexBuf = `${newExp}`;
        const mainVal = parseFloat(entryBuffer || '0');
        const newX = mainVal * Math.pow(10, newExp);
        return {
          ...state,
          eexBuffer: newEexBuf,
          stack: { ...stack, X: newX }
        };
      }
      
      const newX = -stack.X;
      let newBuf = entryBuffer;
      if (isEnteringNumber) {
        newBuf = entryBuffer.startsWith('-') ? entryBuffer.slice(1) : '-' + entryBuffer;
      } else {
        newBuf = `${newX}`;
      }
      return {
        ...state,
        stack: { ...stack, X: newX },
        entryBuffer: newBuf
      };
    }

    case 'EEX': { // Enter Exponent
      if (eexMode) return state;
      return {
        ...state,
        eexMode: true,
        eexBuffer: '',
        entryBuffer: isEnteringNumber ? entryBuffer : `${stack.X}`
      };
    }

    case 'ENTER': {
      // HP-35 ENTER ↑ duplicates X into Y, Y->Z, Z->T, T stays T
      const newStack = {
        X: stack.X,
        Y: stack.X,
        Z: stack.Y,
        T: stack.Z
      };
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: false, // next digit keypress overwrites X without lifting!
        eexMode: false,
        eexBuffer: '',
        history: logStep('ENTER ↑', newStack, 'Lifted stack & duplicated X to Y')
      };
    }

    case 'BINARY_OP': {
      const op = action.payload; // '+', '-', '*', '/', 'pow'
      let res = 0;
      let err = null;
      const x = stack.X;
      const y = stack.Y;

      switch (op) {
        case '+': res = y + x; break;
        case '-': res = y - x; break;
        case '*': res = y * x; break;
        case '/': 
          if (x === 0) {
            err = 'DIV BY ZERO';
            res = 0;
          } else {
            res = y / x; 
          }
          break;
        case 'pow': // y^x
          if (y < 0 && !Number.isInteger(x)) {
            err = 'INVALID POW';
            res = 0;
          } else {
            res = Math.pow(y, x);
          }
          break;
        default: break;
      }

      if (err) {
        return { ...state, error: err };
      }

      // Stack drop behavior for binary operations:
      // X = res, Y = Z, Z = T, T = T
      const newStack = {
        X: res,
        Y: stack.Z,
        Z: stack.T,
        T: stack.T
      };

      const symbolMap = { '+': '+', '-': '-', '*': '×', '/': '÷', 'pow': 'x^y' };

      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        eexMode: false,
        eexBuffer: '',
        history: logStep(`${symbolMap[op] || op}`, newStack, `${y} ${symbolMap[op] || op} ${x} = ${res}`)
      };
    }

    case 'UNARY_OP': {
      const op = action.payload;
      let res = 0;
      let err = null;
      const x = stack.X;

      // Degree conversion helpers
      const toRad = (val) => angleMode === ANGLE_MODES.DEG ? (val * Math.PI) / 180 : val;
      const toAngle = (rad) => angleMode === ANGLE_MODES.DEG ? (rad * 180) / Math.PI : rad;

      switch (op) {
        case 'sqrt':
          if (x < 0) err = 'NEG SQRT';
          else res = Math.sqrt(x);
          break;
        case 'inv': // 1/x
          if (x === 0) err = 'DIV BY ZERO';
          else res = 1 / x;
          break;
        case 'ln':
          if (x <= 0) err = 'LN DOMAIN';
          else res = Math.log(x);
          break;
        case 'log':
          if (x <= 0) err = 'LOG DOMAIN';
          else res = Math.log10(x);
          break;
        case 'exp': // e^x
          res = Math.exp(x);
          break;
        case 'pow10': // 10^x
          res = Math.pow(10, x);
          break;
        case 'sin':
          res = Math.sin(toRad(x));
          break;
        case 'cos':
          res = Math.cos(toRad(x));
          break;
        case 'tan': {
          const rad = toRad(x);
          if (Math.abs(Math.cos(rad)) < 1e-12) err = 'TAN UNDEF';
          else res = Math.tan(rad);
          break;
        }
        case 'asin':
          if (x < -1 || x > 1) err = 'ARCSIN DOMAIN';
          else res = toAngle(Math.asin(x));
          break;
        case 'acos':
          if (x < -1 || x > 1) err = 'ARCCOS DOMAIN';
          else res = toAngle(Math.acos(x));
          break;
        case 'atan':
          res = toAngle(Math.atan(x));
          break;
        default: break;
      }

      if (err) {
        return { ...state, error: err };
      }

      // Unary ops do NOT alter Y, Z, T
      const newStack = { ...stack, X: res };

      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        eexMode: false,
        eexBuffer: '',
        history: logStep(`${op}(X)`, newStack, `${op}(${x}) = ${res}`)
      };
    }

    case 'PI': {
      let newStack = stack;
      if (liftEnabled && isEnteringNumber) {
        newStack = liftStack(Math.PI);
      } else {
        newStack = { ...stack, X: Math.PI };
      }
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        eexMode: false,
        history: logStep('π', newStack, 'Entered π (3.14159...)')
      };
    }

    case 'ROLL_DOWN': { // R↓
      const newStack = {
        X: stack.Y,
        Y: stack.Z,
        Z: stack.T,
        T: stack.X
      };
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        history: logStep('R↓', newStack, 'Rolled stack down: X←Y, Y←Z, Z←T, T←X')
      };
    }

    case 'SWAP': { // x≷y
      const newStack = {
        ...stack,
        X: stack.Y,
        Y: stack.X
      };
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        history: logStep('x≷y', newStack, `Swapped X (${stack.X}) and Y (${stack.Y})`)
      };
    }

    case 'CL_X': { // Clear X
      const newStack = { ...stack, X: 0 };
      return {
        ...state,
        stack: newStack,
        entryBuffer: '0',
        isEnteringNumber: false,
        eexMode: false,
        eexBuffer: '',
        error: null,
        history: logStep('CL X', newStack, 'Cleared X display to 0')
      };
    }

    case 'CLR': { // Clear all stack
      const newStack = { X: 0, Y: 0, Z: 0, T: 0 };
      return {
        ...state,
        stack: newStack,
        entryBuffer: '0',
        isEnteringNumber: false,
        eexMode: false,
        eexBuffer: '',
        error: null,
        history: logStep('CLR', newStack, 'Cleared entire stack X, Y, Z, T to 0')
      };
    }

    case 'STO': { // Store X to Memory
      return {
        ...state,
        memory: stack.X,
        history: logStep('STO', stack, `Stored ${stack.X} into memory register`)
      };
    }

    case 'RCL': { // Recall Memory into X
      let newStack = stack;
      if (liftEnabled && isEnteringNumber) {
        newStack = liftStack(memory);
      } else {
        newStack = { ...stack, X: memory };
      }
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        history: logStep('RCL', newStack, `Recalled ${memory} from memory into X`)
      };
    }

    case 'TOGGLE_ANGLE': {
      const nextMode = angleMode === ANGLE_MODES.DEG ? ANGLE_MODES.RAD : ANGLE_MODES.DEG;
      return {
        ...state,
        angleMode: nextMode
      };
    }

    case 'SET_STACK': { // Used by tutorials / presets
      const newStack = action.payload;
      return {
        ...state,
        stack: newStack,
        isEnteringNumber: false,
        liftEnabled: true,
        history: logStep('LOAD PRESET', newStack, 'Preset state loaded into stack')
      };
    }

    case 'CLEAR_HISTORY': {
      return { ...state, history: [] };
    }

    default:
      return state;
  }
}

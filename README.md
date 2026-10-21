# HP-35 RPN Scientific Web Calculator Simulator

An authentic, modern web-based simulator of the iconic **1972 Hewlett-Packard HP-35** handheld scientific calculator. Built with React, Vite, and Tailwind CSS, featuring full Reverse Polish Notation (RPN) operational stack mechanics, vintage audio clicks, interactive visual stack inspector, calculation history log, and comprehensive physical keyboard shortcuts (including seamless handling for European dead keys like `^°`).

---

## Features

- 📟 **Authentic HP-35 Keypad & Chassis**: Modeled after the 1972 original, complete with metallic header badge, red 15-segment LED digital display, toggle switches for Power and Angle Mode (`DEG`/`RAD`), and signature keycap coloring (`ENTER ↑`, functional, accent, and digit keys).
- 🥞 **4-Level RPN Operational Stack ($X, Y, Z, T$)**: Real-time visualizer showing stack registers, automatic stack lift on numeric entry, stack drop on binary operations, stack rolling ($R\downarrow$), and swapping ($x \gtrless y$).
- ⌨️ **Physical Keyboard Shortcuts with European Dead Key (`^°`) Support**:
  - Full keyboard control mapping every function on the calculator.
  - Intercepts European QWERTZ/AZERTY dead key events (`key === 'Dead'`, `code === 'Backquote'`) for the `^°` power key ($x^y$), as well as accepting `^`, `Y`, and `**`.
- 📖 **Built-in Interactive User Guide**: Multi-tab in-app manual detailing keyboard shortcuts, dead key technical resolution, RPN stack theory, and step-by-step math examples.
- 🔊 **Authentic Audio Feedback**: Realistic key clicks and switch toggle sounds (can be muted anytime from the calculator top bar).
- 📜 **Calculation History & State Restoration**: Log of past operations with one-click stack state restoration.
- 🎓 **Interactive RPN Walkthrough**: Step-by-step guided tutorials for evaluating complex expressions without parentheses.

---

## Operating Guide & RPN Mechanics

### Understanding Reverse Polish Notation (RPN)
Unlike traditional algebraic calculators that require parentheses and an equals sign (`=`), the HP-35 uses **Reverse Polish Notation (RPN)**:
1. Operands are typed first and pushed onto the stack using <kbd>ENTER ↑</kbd>.
2. Operator keys ($+$, $-$, $\times$, $\div$, $x^y$, etc.) perform immediate calculations on values in the stack registers.

### The 4-Level Stack ($X, Y, Z, T$)
- **$X$ (Display Register)**: The active register shown on the LED display.
- **$Y$ (Second Register)**: Holds the second operand for binary calculations ($Y \text{ op } X$).
- **$Z$ (Third Register)**: Drops down to $Y$ when a binary operation is performed.
- **$T$ (Top Register)**: Holds top stack value and duplicates itself on stack drops.

---

## Keyboard Shortcuts Reference

You can operate the calculator using your computer's physical keyboard:

| Function | Physical Keyboard Shortcuts | Description |
|---|---|---|
| **Digits & Decimal** | <kbd>0</kbd> – <kbd>9</kbd>, <kbd>.</kbd> | Enter numbers |
| **ENTER ↑** | <kbd>Enter</kbd> / <kbd>Space</kbd> | Push number onto stack / duplicate $X$ into $Y$ |
| **CL X** | <kbd>Backspace</kbd> | Clear display ($X$ register) |
| **CLR** | <kbd>Escape</kbd> / <kbd>Delete</kbd> | Clear entire stack ($X, Y, Z, T$) |
| **Arithmetic** | <kbd>+</kbd>, <kbd>-</kbd>, <kbd>*</kbd>, <kbd>/</kbd> | Basic math operations ($+$, $-$, $\times$, $\div$) |
| **Power ($x^y$)** | <kbd>^</kbd> / <kbd>^°</kbd> (Dead key) / <kbd>Y</kbd> / <kbd>**</kbd> | Compute $Y^X$ (handles European dead keys) |
| **$\sqrt{x}$** | <kbd>V</kbd> | Square root of $X$ |
| **$1/x$** | <kbd>U</kbd> | Reciprocal of $X$ |
| **LOG** | <kbd>G</kbd> | Base-10 logarithm |
| **LN** | <kbd>H</kbd> | Natural logarithm |
| **$e^x$** | <kbd>D</kbd> | Exponential function |
| **Roll Down ($R\downarrow$)** | <kbd>R</kbd> / <kbd>Q</kbd> | Rotate stack downward ($X \leftarrow Y \leftarrow Z \leftarrow T \leftarrow X$) |
| **Swap ($x \gtrless y$)** | <kbd>X</kbd> / <kbd>W</kbd> | Exchange values in $X$ and $Y$ registers |
| **Trigonometry** | <kbd>S</kbd> (SIN), <kbd>C</kbd> (COS), <kbd>T</kbd> (TAN) | Sine, Cosine, Tangent (or arcsin, arccos, arctan in ARC mode) |
| **ARC** | <kbd>A</kbd> / <kbd>I</kbd> | Toggle Inverse Trigonometric mode |
| **Memory** | <kbd>M</kbd> (STO), <kbd>L</kbd> / <kbd>K</kbd> (RCL) | Store $X$ into Memory register / Recall Memory into $X$ |
| **EEX** | <kbd>E</kbd> | Enter scientific exponent |
| **$\pi$** | <kbd>P</kbd> | Enter $\pi$ constant ($3.14159265...$) |
| **CH S** | <kbd>N</kbd> / <kbd>~</kbd> | Change sign ($+$ / $-$) |

---

## European Dead Key (`^°`) Handling

On QWERTZ (German), AZERTY (French), Spanish, and Swiss keyboards, the <kbd>^°</kbd> key is physically located at the top-left (below <kbd>Esc</kbd> / left of <kbd>1</kbd>). 

In web browsers, pressing a dead key emits a `KeyboardEvent` with:
- `event.key === 'Dead'`
- `event.code === 'Backquote'`

Standard web applications looking solely for `event.key === '^'` fail to trigger on European computers.

### How this simulator resolves it:
1. **Dead Key Interception**: The keyboard event listener checks for `key === 'Dead'` or `code === 'Backquote'` and routes it directly to the power function ($x^y$).
2. **Buffer Prevention**: Calls `e.preventDefault()` on dead key press to prevent character composition buffers from lingering in the browser.
3. **Multi-Key Aliasing**: Users can also press <kbd>Y</kbd> (for $x^y$), <kbd>^</kbd> (<kbd>Shift</kbd> + <kbd>6</kbd>), or <kbd>**</kbd>.

---

## Local Development & Build

### Prerequisites
- Node.js 18+ and npm

### Commands
```bash
# Install dependencies
npm install

# Start local development server
npm run dev

# Build production bundle
npm run build

# Preview production build
npm run preview
```

---

## License

MIT License. Designed and created as an accurate web simulator of the 1972 Hewlett-Packard HP-35 calculator.

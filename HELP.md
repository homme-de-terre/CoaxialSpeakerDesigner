# Coaxial Speaker Designer — Quick User & Engineering Help Guide

This guide covers the step-by-step workflow for designing a coaxial loudspeaker enclosure and phase-aligned passive crossover network.

---

## 1. Driver Setup & Datasheet Ingestion (Left Sidebar)
1. **Import a PDF Datasheet or Preset:**
   * Click **Choose Local PDF Datasheet...** to parse a local manufacturer PDF (e.g., B&C, Beyma, FaitalPRO, P.Audio, Altec), or paste a datasheet URL and click **Fetch & Parse URL**.
   * Or click **Load Altec 604-8K Preset (CLIO)** to load factory specs and 100-point digitized acoustic curves.
2. **Review & Complete Parameters:**
   * Any parameter missing from a datasheet is highlighted in amber (**Missing from datasheet**). Enter or refine Woofer Thiele-Small specs ($F_s, Q_{es}, Q_{ms}, Q_{ts}, V_{as}, R_e, L_e, S_d, X_{\max}, \text{SPL}$) and Tweeter specs ($F_s, R_e, L_e, \text{SPL}$) manually.
   * Use the **US ( `.` ) / EU ( `,` )** toggle if your datasheet or locale uses comma decimal separators.

---

## 2. Cabinet Design (Cabinet Closed/Ported Tab)
1. **Choose Enclosure Architecture:**
   * **Sealed (Closed Box, 2nd-Order, $12\text{ dB/oct}$):** Best for drivers with $Q_{ts} \ge 0.40$ or compact studio monitors with subwoofer support. Choose **Butterworth B2** ($Q_{tc}=0.707$, maximally flat), **Bessel** ($Q_{tc}=0.577$, best transient response), **Critically Damped** ($Q_{tc}=0.500$), or **Target Cut-off Frequency ($f_3$)**.
   * **Vented (Bass-Reflex, 4th-Order, $24\text{ dB/oct}$):** Recommended for high-efficiency pro-audio coaxial drivers with low $Q_{ts}$ ($0.25–0.38$). Choose **QB3**, **B4**, or **SC4**, adjust port tuning ($F_b$), and set port duct diameter ($D_v$) above the **Min Recommended Dia** to prevent port chuffing.
2. **Polyfill Stuffing:**
   * Select **Unfilled**, **Light (+10%)**, **Medium (+18%)**, or **Heavy (+25%)** to account for isothermal acoustic volume gain and damping loss ($Q_b$).

---

## 3. Crossover Network & Live Curve Monitoring
1. **Open Detached Live Curve Windows:**
   * In the **Crossover Network** tab, click **Open 2×2 Live Monitor Grid** (or click individual plot buttons: **Amplitude**, **Phase & Delay**, **Group Delay**, **Step Response**, **Impedance**) to float the response charts alongside your crossover controls.
   * Every slider or toggle change in the Crossover tab updates all detached curve windows in real time.
2. **Set Crossover Frequency & Slopes:**
   * Use a single unified crossover frequency ($f_x$) or check **Specify Independent Cut-off Frequencies** to set separate Woofer Low-Pass ($f_{x,\text{woofer}}$) and Tweeter High-Pass ($f_{x,\text{tweeter}}$) frequencies (creating a handover overlap or underlap gap).
   * Select filter orders ($6, 12, 18,$ or $24\text{ dB/oct}$) and adjust the **Tweeter L-Pad Attenuator** to level-match the high-frequency horn/tweeter to the woofer passband.
3. **Coaxial Time/Phase Alignment (All-Pass Optimizer):**
   * Enter the physical **Coaxial Tweeter Acoustic Center Delay Offset ($\Delta d$ in mm)** (typically $20–45\text{ mm}$ for coaxial compression drivers recessed behind the woofer cone).
   * Enable **All-Pass Woofer Delay Compensation Network**. The **Nelder-Mead Simplex Optimizer** automatically computes optimal $F_0$ and $Q$ so the woofer and tweeter phase curves track in parallel across $[f_x/2, 2f_x]$:
     * **Green ($\le 10.0^\circ$ RMS):** *Phase Aligned (Optimal)* — deep, symmetric acoustic summation.
     * **Yellow ($10.0^\circ - 20.0^\circ$ RMS):** *Acceptable Alignment - Minor Phase Offset* — minor phase ripple (< $0.5\text{ dB}$ loss).
     * **Red ($> 20.0^\circ$ RMS):** *Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx* — toggle **Invert Tweeter Polarity (+180°)** or shift $f_x$.
   * Keep **Enable Zobel Network** active when using the All-Pass filter so the woofer voice-coil inductance ($L_e$) is resistively terminated.
4. **Commercial Component Value Snapping:**
   * Toggle **Snap Components to Commercial E12 Series** ($\pm 10\%$) or **E24 Series** ($\pm 5\%$) to round ideal inductors, capacitors, and resistors to off-the-shelf standard values and immediately observe the real-world response in the live plots.

---

## 4. Reading the Auto-Scaled Engineering Plots
* **Amplitude Response:** Verify smooth summation (green trace) across the crossover region without dips or peaks.
* **Phase & Delay:** Enable **Unwrap Phase** for continuous phase slopes or view **Phase Diff ($\Delta\Phi$)** (orange dashed curve) — aim for $\Delta\Phi$ near $0^\circ$ across the crossover zone.
* **Group Delay & System Impedance (Auto-Scaled Y-Axis):** Both plots automatically scale their vertical Y-axis and grid step to the active visible curves to maximize vertical resolution. Toggle individual traces (**Woofer**, **Tweeter**, **Total System**) on/off to zoom into specific branches.
* **Step Response:** Inspect time-domain arrival alignment between the tweeter spike and woofer rise.

---

## 5. Saving Projects & Exporting CAD Reports
* **Save / Load Project (`⌘S` / `⌘O`):** Saves all driver specs, digitized curves, cabinet parameters, and crossover settings into a portable `.json` design file.
* **Export 2-Page Vector PDF Report:** Open the **Schematic & BOM** tab and click **Export Schematic to PDF** to generate a 2-page vector engineering report containing the full electrical schematic (Page 1), Bill of Materials table, enclosure summary, and color-coded Green/Yellow/Red APF phase alignment report (Page 2).

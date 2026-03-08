# Shell Eco-Marathon Vehicle Simulation

A MATLAB/Simulink physics-based vehicle dynamics and energy modeling
framework developed for Shell Eco-Marathon efficiency analysis and
design optimization. The model has evolved through eight versions from
a basic force-balance model into a Stateflow-controlled burn-coast
simulation with dyno-calibrated engine modeling and competition-scored
parameter sweeps.

---

## Version History

| Version | Key Development |
|---------|----------------|
| V1 | Baseline longitudinal dynamics, constant throttle |
| V2 | Modular Simulink architecture, parameter sweeps |
| V3–V5 | PID cruise control, dyno torque map integration |
| V6 | Burn-coast driver strategy, threshold switching |
| **V8** | **Stateflow hysteresis, corrected powertrain geometry, shaft-power fuel accounting, km/L sweep optimization** |

---

## V8 Model Overview

The simulation models a Shell Eco-Marathon prototype vehicle operating
under a burn-coast driver strategy. The engine fires at full throttle
until the vehicle reaches an upper speed threshold, then coasts until
a lower threshold is reached, repeating continuously.

### Subsystem Architecture

```
DriverStrat (Stateflow)
    └── Throttle_CMD (0/1)
            │
            ▼
        Powertrain
            │   Vehicle Speed → Wheel RPM → Engine RPM
            │   RPM Saturation (2708–8708 RPM)
            │   1D Torque Map Lookup (engine_mapV4)
            │   Throttle × Torque × G × effic_drive / r_w
            └── F_Engine, T_Engine, omega_engine
                    │
                    ▼
            Vehicle Dynamics
                    │   F_Net = F_Engine − F_Drag − F_Roll
                    │   v = ∫(F_Net / m) dt
                    └── x = ∫v dt
                            │
                            ▼
                    EnergyModeling
                            │   Path 1: F_Net × v → E_mech (J/m)
                            └── Path 2: T_eng × ω_eng → m_fuel (kg)
```

### Driver Strategy — Stateflow Hysteresis

```
State: BURN  → throttle = 1
State: COAST → throttle = 0

BURN  → COAST when v_actual >= v_high_on
COAST → BURN  when v_actual <= v_low_on
```

Holds previous state between thresholds — no chattering.

---

## Key Corrections in V8

- **Wheel radius** — corrected from 0.508 m (diameter) to 0.254 m (radius).
  Previous value halved engine RPM, pushing operation below the valid
  engine map range and producing NaN torque values.
- **RPM idle limit** — updated from 1800 to 2708 RPM to match engine
  map lower bound.
- **Fuel accounting** — rebuilt on shaft power (`T_engine × ω_engine`)
  rather than net vehicle force (`F_net × v`). Net force had drag and
  rolling losses already removed before the fuel calculation, producing
  underestimates.
- **LHV constant** — corrected from 4.4 × 10⁶ to 44 × 10⁶ J/kg in
  EnergyModeling block.
- **Sweep metric** — updated to km/L (Shell scoring) from J/m.

---

## Parameter Sweep Results (SweepV8b)

Evaluated over 1000s simulation window using middle-80% averaging
to eliminate startup and end-cycle artifacts.

| Parameter | Optimum | Best Score | Sensitivity |
|-----------|---------|------------|-------------|
| Drag coefficient | Cd = 0.10 | 933 km/L | **86.5%** |
| Vehicle mass | m = 80 kg | 735 km/L | **75.3%** |
| Speed band | v_low=5.5, v_high=7.0 | 705 km/L | 26.0% |
| Gear ratio | G = 13.0 | 659 km/L | 3.3% |

**Design priority ranking: aero reduction and mass minimization
have far greater impact than drivetrain tuning.**

---

## Repository Structure

```
shell-eco-simulink/
│
├── model/
│   ├── shell_eco_mainV8c.slx     — Current Simulink model (V8)
│   └── shell_eco_mainV7.slx      — Previous version
│
├── params/
│   ├── shell_eco_paramsV8.m      — Current parameters (V8)
│   └── shell_eco_paramsV6.m      — Previous version
│
├── analysis/
│   ├── analyzeV8_shell_eco.m     — Post-processing and diagnostics
│   ├── SweepV8b.m                — Four-parameter km/L sweep
│   ├── analyzeV4.m               — Legacy analysis script
│   └── SweepV7.m                 — Legacy sweep script
│
├── engine_map/
│   ├── engine_mapV4.mat          — Dyno-calibrated torque lookup table
│   └── build_engine_mapV4.m      — Map processing script
│
└── outputs/                      — Generated figures (gitignored)
```

---

## Requirements

- MATLAB R2023+ with Simulink
- Stateflow (required for DriverStrat V8)
- Statistics and Machine Learning Toolbox (optional, not required)

---

## Basic Workflow

```matlab
% 1. Load parameters
run('params/shell_eco_paramsV8.m')

% 2. Run simulation
out = sim('model/shell_eco_mainV8c');

% 3. Analyze results
run('analysis/analyzeV8_shell_eco.m')

% 4. Run parameter sweep (takes several minutes)
run('analysis/SweepV8b.m')
```

---

## Pending Updates

- **BSFC map** — engine efficiency currently fixed at 20%. A 2D
  brake-specific fuel consumption map will replace this once the senior
  team completes dyno runs on the assembled vehicle.
- **Extended engine map** — current dyno data starts at 2708 RPM.
  At v_target = 7 m/s with G = 10, operating RPM is ~2632, just below
  the map minimum. Data below 2708 RPM needed.
- **Confirmed vehicle mass** — driver + vehicle mass pending senior
  team hardware assembly.
- **Final gear ratio** — motocross 3-speed transmission gear
  combinations to be confirmed from assembled drivetrain.
- **Track profile** — elevation and corner speed inputs for lap
  simulation replacing fixed time window.
- **Burn-coast vs cruise control comparison** — parallel PID model
  to be compared against burn-coast strategy across track segments.

---

## Project Website

Full simulation documentation, version history, sweep results, and
signal plots are available at the project GitHub Pages site:

[View Project Documentation](https://canfieldmason.github.io/projects/shell-eco-simulink/)

# Shell Eco-Marathon Vehicle Simulation (V2)

This repository contains a MATLAB/Simulink-based one-dimensional vehicle
dynamics and energy modeling framework developed for Shell Eco-Marathon
efficiency analysis and design optimization.

The project evolved from an initial longitudinal dynamics model (V1)
into a modular simulation and analysis platform (V2) with automated
post-processing and parameter sweep capabilities.

---

## Project Features

- Physics-based longitudinal vehicle dynamics model
- Modular Simulink subsystem architecture
- Centralized parameter management
- Automated performance analysis and reporting
- 1D and 2D design-space parameter sweeps
- Heatmap visualization with constraint filtering
- Energy-to-fuel conversion using LHV

---


### Requirements

- MATLAB R2023+ (recommended)
- Simulink

### Basic Workflow

1. Open the Simulink model in `/model`
2. Load parameters from `/params`
3. Run the simulation
4. Execute analysis scripts from `/analysis`

Example:

```matlab
run('params/shell_eco_paramsV2.m')
sim('model/shell_eco_v2.slx')
run('analysis/analyze_shell_eco.m')

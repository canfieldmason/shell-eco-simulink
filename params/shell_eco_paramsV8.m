%% Shell Eco-Marathon Parameters
% Author: Mason Canfield
% Version: V8 (03-07-2026)
%
% Changelog V6 → V8:
%   - r_w corrected from 0.508m (diameter) to 0.254m (radius)
%   - RPM_idle updated from 1800 to 2708 to match engine map minimum
%   - DriverStrat replaced with Stateflow hysteresis (v_low_on/v_high_on)
%   - EnergyModeling rebuilt: shaft power fuel path replaces F_net path
%   - LHV constant block corrected from 4.4e6 to 44e6 J/kg
%   - Sweep metric updated to km/L (Shell scoring)
%   - G theoretical optimum for map-valid RPM: 10.29
%
% Pending Updates (awaiting senior team hardware):
%   - Confirmed vehicle mass (driver + vehicle)
%   - Final gear ratio from assembled drivetrain
%   - Extended engine map below 2708 RPM
%   - BSFC map to replace fixed effic_engine = 0.20

%% ================================
% DESIGN / TUNABLE PARAMETERS
% (Primary study variables)
% ================================

% Vehicle Mass
m = 100;              % kg — UPDATE from senior team (driver + vehicle)

% Aerodynamics
Cd = 0.30;            % Drag coefficient
A  = 0.3985;          % Frontal area (m^2)

% Rolling Resistance
Crr = 0.005;          % Rolling resistance coefficient

% Drivetrain
effic_drive = 0.88;   % Drivetrain efficiency

% Engine / Powertrain
effic_engine = 0.20;  % Engine thermal efficiency (fixed est. — pending BSFC)

r_w = 0.254;          % Wheel radius (m) — corrected V8 (20in diameter / 2)
                      % V6 error: was set to 0.508 (diameter not radius)

G   = 10;             % Total gear reduction ratio
                      % G = G_transmission * G_final_drive * G_chain
                      % Theoretical optimum for map-valid RPM: G = 10.29
                      % Motocross 3-speed — confirm ratio from senior team

%% ================================
% ENGINE MAP (V4 Dyno-Calibrated)
% ================================

% Load processed torque map
load engine_mapV4.mat

% Expose to Simulink
EngineRPM_map    = EngineRPM;      % RPM breakpoints (2708-8708 RPM)
EngineTorque_map = EngineTmax;     % Max torque (Nm)

clear EngineRPM EngineTmax         % keep workspace clean

%% ================================
% DRIVER STRATEGY (Stateflow V8)
% ================================
% Hysteresis burn-coast controller
% BURN  when v_actual <= v_low_on
% COAST when v_actual >= v_high_on
% No chattering at thresholds — state held between bounds

v_target  = 7;        % m/s — desired average speed

v_low     = 6.5;      % m/s — lower speed bound
v_high    = 7.5;      % m/s — upper speed bound
v_dead    = 0.3;      % m/s — hysteresis deadband

v_low_on  = v_low  + v_dead;    % 6.8 m/s — Stateflow BURN  threshold
v_high_on = v_high + v_dead;    % 7.8 m/s — Stateflow COAST threshold

% Sweep 1 optimum (SweepV8b): v_low=5.5, v_high=7.0 → 704.5 km/L
% Note: verify minimum average speed requirement for Shell class

%% ================================
% PHYSICAL CONSTANTS
% ================================

g   = 9.81;           % Gravity (m/s^2)
rho = 1.225;          % Air density (kg/m^3)

LHV = 44e6;           % Fuel lower heating value (J/kg) — gasoline
                      % Note: confirm fuel type with Shell rules
                      % Gasoline density: 0.745 kg/L (used in km/L scoring)

%% ================================
% ENGINE OPERATING LIMITS
% ================================

RPM_idle = 2708;      % rpm — corrected V8, matches engine map minimum
                      % V6 value was 1800 (below map range, caused NaN torque)
RPM_max  = 8708;      % rpm — matches engine map maximum

%% ================================
% SWEEP RESULTS SUMMARY (SweepV8b)
% ================================
% Parameter sensitivity ranking (higher = more design impact):
%   Drag coeff:  86.5% — highest priority
%   Mass:        75.3% — high priority
%   Speed band:  26.0% — strategy optimization
%   Gear ratio:   3.3% — low priority, keep RPM in map range
%
% Optimum values from sweep:
%   v_low=5.5, v_high=7.0 → 704.5 km/L
%   G=10.25-11.50          → keeps RPM in valid map range at v_target
%   m=80 kg                → lightest feasible (physical lower bound)
%   Cd=0.10                → best achievable aero target

%% ================================
% SIMULATION SETTINGS
% ================================

t_end = 200;          % Simulation time (s) — standard single run
                      % SweepV8b uses t_end=1000 for statistical stability

% Initial Conditions
v0 = 0;               % Initial velocity (m/s)
x0 = 0;               % Initial position (m)
E0 = 0;               % Initial energy (J)
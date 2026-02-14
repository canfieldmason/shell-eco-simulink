%% Shell Eco-Marathon Parameters
% Author: Mason Canfield
% Version: V2 (02-13-2026)

%% ================================
% DESIGN / TUNABLE PARAMETERS
% (Primary study variables)
% ================================

% Vehicle Mass
m = 95;              % kg (Update from senior team)

% Aerodynamics
Cd = 0.18;           % Drag coefficient
A  = 0.50;           % Frontal area (m^2)

% Rolling Resistance
Crr = 0.0025;        % Rolling resistance coefficient

% Drivetrain
effic_drive = 0.88;  % Drivetrain efficiency

% Engine / Powertrain
effic_engine = 0.25; % Engine efficiency (est.)

r_w = 0.23;          % Wheel radius (m)
G   = 8.5;           % Total Speed Reduction (Gear Ratio)
                        % G = (Transm Gear)*(Final Drive)*(Belts&Chains)


%% ================================
% PHYSICAL CONSTANTS
% (Rarely changed)
% ================================

g   = 9.81;          % Gravity (m/s^2)
rho = 1.225;         % Air density (kg/m^3)

LHV = 44e6;          % Fuel lower heating value (J/kg), 
                        % needs stronger reference


%% ================================
% ENGINE OPERATING LIMITS
% (Available for Update Pending ECU/Dyno)
% ================================

RPM_idle = 1800;     % rpm
RPM_max  = 8000;     % rpm


%% ================================
% SIMULATION SETTINGS
% ================================

t_end = 600;         % Simulation time (s)

% Initial Conditions
v0 = 0;              % Initial velocity (m/s)
x0 = 0;              % Initial position (m)
E0 = 0;              % Initial energy (J)

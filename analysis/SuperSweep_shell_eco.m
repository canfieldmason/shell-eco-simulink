%% Shell Eco Parameter Sweep
% Author: Mason Canfield
% Purpose: 1D Sensitivity Studies

clear; clc; close all;

%% User Options
EXPORT_EXCEL = false;   % Set true when export needed

%% Load Base Parameters
run shell_eco_paramsV2


%% ==============================
% Sweep 1: Aerodynamic Drag (Cd)
% ==============================

Cd_vals = 0.14:0.01:0.22;
N = length(Cd_vals);

Fuel_Cd = zeros(N,1);
Dist_Cd = zeros(N,1);

for i = 1:N

    run shell_eco_paramsV2
    Cd = Cd_vals(i);

    out = sim('shell_eco_mainV2');

    fuel = out.logsout.get('m_Fuel').Values.Data;
    x    = out.logsout.get('x_Vehicle').Values.Data;

    Fuel_Cd(i) = fuel(end);
    Dist_Cd(i) = x(end);

end


%% Plot: Cd

figure;
plot(Cd_vals, Fuel_Cd, '-o');
xlabel('Cd');
ylabel('Fuel Used (kg)');
title('Fuel vs Drag');
grid on;

figure;
plot(Cd_vals, Dist_Cd, '-o');
xlabel('Cd');
ylabel('Distance (m)');
title('Distance vs Drag');
grid on;


%% Export Cd (Optional)

if EXPORT_EXCEL

    T_Cd = table(Cd_vals(:), Fuel_Cd(:), Dist_Cd(:), ...
        'VariableNames', {'Cd','Fuel_kg','Distance_m'});

    writetable(T_Cd,'Sweep_Cd.xlsx');

end


%% ==========================
% Sweep 2: Vehicle Mass (m)
% ==========================

m_vals = 80:5:120;
N = length(m_vals);

Fuel_m = zeros(N,1);

for i = 1:N

    run shell_eco_paramsV2
    m = m_vals(i);

    out = sim('shell_eco_mainV2');

    fuel = out.logsout.get('m_Fuel').Values.Data;

    Fuel_m(i) = fuel(end);

end


%% Plot: Mass

figure;
plot(m_vals, Fuel_m,'-o');
xlabel('Mass (kg)');
ylabel('Fuel Used (kg)');
title('Fuel vs Mass');
grid on;


%% Export Mass (Optional)

if EXPORT_EXCEL

    T_m = table(m_vals(:), Fuel_m(:), ...
        'VariableNames', {'Mass_kg','Fuel_kg'});

    writetable(T_m,'Sweep_Mass.xlsx');

end

%% For later
%Crr_vals = 0.001:0.0005:0.004;

%G_vals = 6:0.5:12;

%eff_vals = 0.80:0.02:0.95;
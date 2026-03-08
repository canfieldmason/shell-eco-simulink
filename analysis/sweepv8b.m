%% Shell Eco Parameter Sweep — V8b
% Author: Mason Canfield
% Updated: km/L as primary metric, middle-window efficiency to remove
%          end-cycle artifacts, t_end=1000s for statistical stability,
%          fuel used as secondary metric throughout
% Note: effic_engine = 0.20 fixed pending BSFC dyno data
%       Engine map valid 2708-8708 RPM

clear; clc; close all;

EXPORT_EXCEL = false;

run shell_eco_paramsV6

% Override simulation time for sweep stability
t_end = 1000;

%% =========================================================================
% Sweep 1 — Burn Coast Speed Band
% =========================================================================

fprintf('Running Sweep 1: Burn-Coast Speed Band...\n')

vLow_vals  = 5.5:0.3:7.5;
vHigh_vals = 7.0:0.3:9.5;

kmL_map    = zeros(length(vLow_vals), length(vHigh_vals));
Fuel_map   = zeros(length(vLow_vals), length(vHigh_vals));

for i = 1:length(vLow_vals)
    for j = 1:length(vHigh_vals)

        if vLow_vals(i) >= vHigh_vals(j)
            kmL_map(i,j)  = NaN;
            Fuel_map(i,j) = NaN;
            continue
        end

        run shell_eco_paramsV6
        t_end     = 1000;
        v_low     = vLow_vals(i);
        v_high    = vHigh_vals(j);
        v_low_on  = v_low  + v_dead;
        v_high_on = v_high + v_dead;

        out = sim('shell_eco_mainV8c');
        [kmL_map(i,j), ~, Fuel_map(i,j)] = extractMetrics(out, t_end);

    end
    fprintf('  v_low = %.1f complete\n', vLow_vals(i))
end

% Find optimum
kmL_map_clean = kmL_map;
kmL_map_clean(isinf(kmL_map_clean)) = 0;
[maxVal, maxIdx] = max(kmL_map_clean(:));
[ri, ci] = ind2sub(size(kmL_map), maxIdx);

figure
imagesc(vHigh_vals, vLow_vals, kmL_map)
xlabel('v_{high} (m/s)')
ylabel('v_{low} (m/s)')
title('Burn-Coast Efficiency Map (km/L) — higher is better')
colorbar; axis xy
hold on
plot(vHigh_vals(ci), vLow_vals(ri), 'r*', 'MarkerSize', 12, ...
     'DisplayName', 'Optimum')
legend('Location','best')

figure
imagesc(vHigh_vals, vLow_vals, Fuel_map)
xlabel('v_{high} (m/s)')
ylabel('v_{low} (m/s)')
title('Burn-Coast Fuel Map (g per 800s window) — lower is better')
colorbar; axis xy

fprintf('Sweep 1 optimum: v_low=%.1f, v_high=%.1f → %.1f km/L\n', ...
        vLow_vals(ri), vHigh_vals(ci), maxVal)

%% =========================================================================
% Sweep 2 — Gear Ratio
% =========================================================================

fprintf('\nRunning Sweep 2: Gear Ratio...\n')

G_vals = 7:0.25:14;

kmL_G  = zeros(length(G_vals), 1);
Fuel_G = zeros(length(G_vals), 1);
Eff_G  = zeros(length(G_vals), 1);
RPM_G  = zeros(length(G_vals), 1);

for i = 1:length(G_vals)

    run shell_eco_paramsV6
    t_end = 1000;
    G     = G_vals(i);

    omega_w   = v_target / r_w;
    RPM_G(i)  = omega_w * G * 60 / (2*pi);

    out = sim('shell_eco_mainV8c');
    [kmL_G(i), Eff_G(i), Fuel_G(i)] = extractMetrics(out, t_end);

    fprintf('  G=%.2f → RPM=%.0f, %.1f km/L, %.3f g\n', ...
            G_vals(i), RPM_G(i), kmL_G(i), Fuel_G(i))
end

figure
yyaxis left
plot(G_vals, kmL_G, '-o', 'LineWidth', 2)
ylabel('Shell Score (km/L)')
yyaxis right
plot(G_vals, RPM_G, '--s', 'LineWidth', 1.5)
yline(2708, 'r:', 'Map Min RPM')
yline(8708, 'r:', 'Map Max RPM')
ylabel('Engine RPM at v_{target}')
xlabel('Gear Ratio G')
title('Gear Ratio Optimization')
legend('km/L Score', 'RPM at v_{target}', 'Location','best')
grid on

figure
plot(G_vals, Fuel_G, '-o', 'LineWidth', 2, 'Color', [0.47 0.67 0.19])
xlabel('Gear Ratio G')
ylabel('Fuel Consumed (g per 800s window)')
title('Fuel Consumption vs Gear Ratio')
grid on

%% =========================================================================
% Sweep 3 — Mass
% =========================================================================

fprintf('\nRunning Sweep 3: Mass...\n')

m_vals = 80:10:200;

kmL_m  = zeros(length(m_vals), 1);
Fuel_m = zeros(length(m_vals), 1);

for i = 1:length(m_vals)

    run shell_eco_paramsV6
    t_end = 1000;
    m     = m_vals(i);

    out = sim('shell_eco_mainV8c');
    [kmL_m(i), ~, Fuel_m(i)] = extractMetrics(out, t_end);

    fprintf('  m=%.0f kg → %.1f km/L, %.3f g\n', ...
            m_vals(i), kmL_m(i), Fuel_m(i))
end

figure
plot(m_vals, kmL_m, '-o', 'LineWidth', 2, 'Color', [0 0.45 0.74])
xlabel('Mass (kg)')
ylabel('Shell Score (km/L)')
title('Efficiency vs Vehicle Mass')
grid on

figure
plot(m_vals, Fuel_m, '-o', 'LineWidth', 2, 'Color', [0.85 0.33 0.10])
xlabel('Mass (kg)')
ylabel('Fuel Consumed (g per 800s window)')
title('Fuel Consumption vs Mass')
grid on

%% =========================================================================
% Sweep 4 — Drag Coefficient
% =========================================================================

fprintf('\nRunning Sweep 4: Drag Coefficient...\n')

Cd_vals = 0.10:0.05:0.50;

kmL_Cd  = zeros(length(Cd_vals), 1);
Fuel_Cd = zeros(length(Cd_vals), 1);

for i = 1:length(Cd_vals)

    run shell_eco_paramsV6
    t_end = 1000;
    Cd    = Cd_vals(i);

    out = sim('shell_eco_mainV8c');
    [kmL_Cd(i), ~, Fuel_Cd(i)] = extractMetrics(out, t_end);

    fprintf('  Cd=%.2f → %.1f km/L, %.3f g\n', ...
            Cd_vals(i), kmL_Cd(i), Fuel_Cd(i))
end

figure
plot(Cd_vals, kmL_Cd, '-o', 'LineWidth', 2, 'Color', [0.49 0.18 0.56])
xlabel('Drag Coefficient C_d')
ylabel('Shell Score (km/L)')
title('Efficiency vs Drag Coefficient')
xline(0.30, 'k--', 'Current C_d', 'LabelVerticalAlignment','bottom')
grid on

figure
plot(Cd_vals, Fuel_Cd, '-o', 'LineWidth', 2, 'Color', [0.93 0.69 0.13])
xlabel('Drag Coefficient C_d')
ylabel('Fuel Consumed (g per 800s window)')
title('Fuel Consumption vs Drag Coefficient')
xline(0.30, 'k--', 'Current C_d', 'LabelVerticalAlignment','bottom')
grid on

%% =========================================================================
% Summary
% =========================================================================

[~, gi]  = max(kmL_G);
[~, mi]  = max(kmL_m);
[~, cdi] = max(kmL_Cd);

fprintf('\n============ Sweep Summary (V8b) ============\n')
fprintf('Metric: km/L (Shell scoring) — higher is better\n')
fprintf('---------------------------------------------\n')
fprintf('Sweep 1 — Speed band:   v_low=%.1f, v_high=%.1f → %.1f km/L\n', ...
        vLow_vals(ri), vHigh_vals(ci), maxVal)
fprintf('Sweep 2 — Gear ratio:   G=%.2f (RPM=%.0f) → %.1f km/L\n', ...
        G_vals(gi), RPM_G(gi), kmL_G(gi))
fprintf('Sweep 3 — Mass:         m=%.0f kg → %.1f km/L\n', ...
        m_vals(mi), kmL_m(mi))
fprintf('Sweep 4 — Drag coeff:   Cd=%.2f → %.1f km/L\n', ...
        Cd_vals(cdi), kmL_Cd(cdi))
fprintf('=============================================\n')
fprintf('Note: Results pending BSFC data and confirmed gear ratios\n')
fprintf('      Engine map valid 2708-8708 RPM — verify G keeps\n')
fprintf('      operating RPM within map bounds at v_target\n')

% ── Parameter Sensitivity ─────────────────────────────────────────────────
sens_G    = (max(kmL_G)  - min(kmL_G))  / min(kmL_G)  * 100;
sens_m    = (max(kmL_m)  - min(kmL_m))  / min(kmL_m)  * 100;
sens_Cd   = (max(kmL_Cd) - min(kmL_Cd)) / min(kmL_Cd) * 100;

% For speed band, exclude NaN and inf values
kmL_band_clean = kmL_map(~isnan(kmL_map) & ~isinf(kmL_map));
sens_band = (max(kmL_band_clean) - min(kmL_band_clean)) / min(kmL_band_clean) * 100;

fprintf('\n--- Parameter Sensitivity (best vs worst in sweep range) ---\n')
fprintf('Speed band:   %.1f%% improvement potential\n', sens_band)
fprintf('Gear ratio:   %.1f%% improvement potential\n', sens_G)
fprintf('Mass:         %.1f%% improvement potential\n', sens_m)
fprintf('Drag coeff:   %.1f%% improvement potential\n', sens_Cd)
fprintf('------------------------------------------------------------\n')
fprintf('Ranking: higher %% = higher design priority\n')

%% =========================================================================
% Helper Function
% =========================================================================

function [kmL, eff_Jpm, fuel_g] = extractMetrics(out, t_end)
% extractMetrics  Extract Shell scoring metrics from sim output
% Uses middle 80% of run to avoid startup and end-cycle artifacts

    E    = out.logsout.get('E_mech').Values.Data;
    x    = out.logsout.get('x_Vehicle').Values.Data;
    fuel = out.logsout.get('m_fuel').Values.Data;

    % Middle 80% window
    n       = length(x);
    i_start = max(1, round(0.10 * n));
    i_end   = min(n, round(0.90 * n));

    delta_E    = E(i_end)    - E(i_start);
    delta_x    = x(i_end)    - x(i_start);
    delta_fuel = fuel(i_end) - fuel(i_start);

    eff_Jpm = delta_E / delta_x;                  % J/m (mechanical)
    fuel_g  = delta_fuel * 1000;                  % grams in window
    fuel_L  = delta_fuel / 0.745;                 % liters (gasoline density)
    dist_km = delta_x / 1000;                     % km in window

    if fuel_L > 0
        kmL = dist_km / fuel_L;
    else
        kmL = inf;
    end
end
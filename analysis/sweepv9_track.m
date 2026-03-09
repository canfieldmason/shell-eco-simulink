%% Shell Eco Parameter Sweep — V9
% Author: Mason Canfield
% Version: V9 (03-09-2026)
%
% Changelog V8b → V9:
%   - All sims use lap-based stop (4 laps × 3832.5m) instead of t_end
%   - Pass/fail filter: results where t_total > 2100s marked NaN (disqualified)
%   - extractMetrics updated: returns t_total + valid flag
%   - Sweep 1 speed band: lower bound constrained so avg speed > v_min_avg
%   - Grade force active in VehicleDynamics (uses track_grade lookup)
%   - Competition comparison line added to each plot
%
% Sweep overview:
%   1. Burn-coast speed band (v_low × v_high) — primary strategy sweep
%   2. Gear ratio — drivetrain sizing validation
%   3. Mass — design target sensitivity
%   4. Drag coefficient — aero priority confirmation

clear; clc; close all;

EXPORT_EXCEL = false;

run shell_eco_paramsV9_track

%% =========================================================================
% Sweep 1 — Burn-Coast Speed Band
% =========================================================================
% Note: v_low lower bound set at 7.0 m/s to ensure avg speed stays
%       comfortably above the 7.30 m/s disqualification threshold.
%       Bands producing t_total > 2100s are marked NaN (DQ).

fprintf('Running Sweep 1: Burn-Coast Speed Band...\n')

vLow_vals  = 7.0:0.2:8.0;
vHigh_vals = 7.5:0.2:9.5;

nL = length(vLow_vals);
nH = length(vHigh_vals);

kmL_map   = nan(nL, nH);
tTot_map  = nan(nL, nH);
valid_map = false(nL, nH);

for i = 1:nL
    for j = 1:nH

        if vLow_vals(i) >= vHigh_vals(j)
            continue
        end

        run shell_eco_paramsV9_track
        v_low     = vLow_vals(i);
        v_high    = vHigh_vals(j);
        v_low_on  = v_low  + v_dead;
        v_high_on = v_high + v_dead;

        out = sim('shell_eco_mainV9_track');
        [kmL_map(i,j), tTot_map(i,j), valid_map(i,j)] = extractMetricsV9(out);

        % Mark DQ attempts
        if ~valid_map(i,j)
            kmL_map(i,j) = NaN;
        end

    end
    fprintf('  v_low = %.1f  complete\n', vLow_vals(i))
end

% Best valid result
kmL_clean = kmL_map;
kmL_clean(isnan(kmL_clean)) = 0;
[maxVal, maxIdx] = max(kmL_clean(:));
[ri, ci] = ind2sub([nL nH], maxIdx);

fprintf('\nSweep 1 Optimum:\n')
fprintf('  v_low  = %.1f m/s\n', vLow_vals(ri))
fprintf('  v_high = %.1f m/s\n', vHigh_vals(ci))
fprintf('  Score  = %.1f km/L\n', maxVal)
fprintf('  t_total = %.1f s (margin %+.0fs)\n\n', tTot_map(ri,ci), t_max-tTot_map(ri,ci))

figure('Name','Sweep 1 — Speed Band')
imagesc(vHigh_vals, vLow_vals, kmL_map)
set(gca,'YDir','normal')
colorbar
xlabel('v_{high} (m/s)'); ylabel('v_{low} (m/s)')
title('Burn-Coast Efficiency Map (km/L)   |   Grey = DQ (t > 35 min)')
colormap(parula)
hold on
plot(vHigh_vals(ci), vLow_vals(ri), 'r*', 'MarkerSize', 14, 'LineWidth', 2)
text(vHigh_vals(ci)+0.05, vLow_vals(ri), sprintf(' %.0f km/L', maxVal), ...
     'Color','r','FontWeight','bold')

%% =========================================================================
% Sweep 2 — Gear Ratio
% =========================================================================

fprintf('Running Sweep 2: Gear Ratio...\n')

G_vals = 7:0.5:14;
kmL_G  = nan(length(G_vals), 1);
tTot_G = nan(length(G_vals), 1);

for i = 1:length(G_vals)
    run shell_eco_paramsV9_track
    G   = G_vals(i);
    out = sim('shell_eco_mainV9_track');
    [kmL_G(i), tTot_G(i), valid_G] = extractMetricsV9(out);
    if ~valid_G; kmL_G(i) = NaN; end
    fprintf('  G = %.1f  →  %.1f km/L  (t=%.0fs)\n', G_vals(i), kmL_G(i), tTot_G(i))
end

figure('Name','Sweep 2 — Gear Ratio')
plot(G_vals, kmL_G, '-o', 'LineWidth', 2, 'MarkerFaceColor','auto')
xlabel('Total Gear Ratio G'); ylabel('km/L')
title('Gear Ratio Optimisation')
yline(718, 'r--', 'Mater Dei 2025 (718)', 'LineWidth', 1)
yline(995, 'b--', 'BYU 2025 (995)',        'LineWidth', 1)
grid on

[~, idx_best_G] = max(kmL_G);
hold on
plot(G_vals(idx_best_G), kmL_G(idx_best_G), 'r*', 'MarkerSize', 14, 'LineWidth', 2)
fprintf('\nBest G: %.1f  →  %.1f km/L\n\n', G_vals(idx_best_G), kmL_G(idx_best_G))

%% =========================================================================
% Sweep 3 — Mass
% =========================================================================

fprintf('Running Sweep 3: Mass...\n')

m_vals = 80:10:180;
kmL_m  = nan(length(m_vals), 1);
tTot_m = nan(length(m_vals), 1);

for i = 1:length(m_vals)
    run shell_eco_paramsV9_track
    m   = m_vals(i);
    out = sim('shell_eco_mainV9_track');
    [kmL_m(i), tTot_m(i), valid_m] = extractMetricsV9(out);
    if ~valid_m; kmL_m(i) = NaN; end
    fprintf('  m = %3d kg  →  %.1f km/L  (t=%.0fs)\n', m_vals(i), kmL_m(i), tTot_m(i))
end

figure('Name','Sweep 3 — Mass')
plot(m_vals, kmL_m, '-o', 'LineWidth', 2, 'MarkerFaceColor','auto')
xlabel('Total Mass (kg)'); ylabel('km/L')
title('Efficiency vs Mass')
yline(718, 'r--', 'Mater Dei 2025 (718)', 'LineWidth', 1)
yline(995, 'b--', 'BYU 2025 (995)',        'LineWidth', 1)
xline(140, 'k--', 'Max vehicle mass (Art.39)', 'LineWidth', 1)
grid on

[~, idx_best_m] = max(kmL_m);
hold on
plot(m_vals(idx_best_m), kmL_m(idx_best_m), 'r*', 'MarkerSize', 14)
fprintf('\nBest mass: %d kg  →  %.1f km/L\n\n', m_vals(idx_best_m), kmL_m(idx_best_m))

%% =========================================================================
% Sweep 4 — Drag Coefficient
% =========================================================================

fprintf('Running Sweep 4: Drag Coefficient...\n')

Cd_vals = 0.05:0.05:0.55;
kmL_Cd  = nan(length(Cd_vals), 1);

for i = 1:length(Cd_vals)
    run shell_eco_paramsV9_track
    Cd  = Cd_vals(i);
    out = sim('shell_eco_mainV9_track');
    [kmL_Cd(i), ~, valid_Cd] = extractMetricsV9(out);
    if ~valid_Cd; kmL_Cd(i) = NaN; end
    fprintf('  Cd = %.2f  →  %.1f km/L\n', Cd_vals(i), kmL_Cd(i))
end

figure('Name','Sweep 4 — Drag Coefficient')
plot(Cd_vals, kmL_Cd, '-o', 'LineWidth', 2, 'MarkerFaceColor','auto')
xlabel('Drag Coefficient C_d'); ylabel('km/L')
title('Efficiency vs Aerodynamic Drag')
xline(0.30, 'k--', 'Current C_d = 0.30', 'LineWidth', 1)
yline(718, 'r--', 'Mater Dei 2025 (718)', 'LineWidth', 1)
yline(995, 'b--', 'BYU 2025 (995)',        'LineWidth', 1)
grid on

fprintf('\n')

%% =========================================================================
% Sweep 5 — Engine Efficiency (sensitivity to BSFC uncertainty)
% =========================================================================

fprintf('Running Sweep 5: Engine Efficiency (BSFC sensitivity)...\n')

eff_vals = 0.08:0.02:0.35;
kmL_eff  = nan(length(eff_vals), 1);

for i = 1:length(eff_vals)
    run shell_eco_paramsV9_track
    effic_engine = eff_vals(i);
    out = sim('shell_eco_mainV9_track');
    [kmL_eff(i), ~, valid_eff] = extractMetricsV9(out);
    if ~valid_eff; kmL_eff(i) = NaN; end
    fprintf('  eta_eng = %.0f%%  →  %.1f km/L\n', eff_vals(i)*100, kmL_eff(i))
end

figure('Name','Sweep 5 — Engine Efficiency')
plot(eff_vals*100, kmL_eff, '-o', 'LineWidth', 2, 'MarkerFaceColor','auto')
xlabel('Engine Thermal Efficiency (%)'); ylabel('km/L')
title('Efficiency vs Engine Thermal Efficiency   |   BSFC Sensitivity')
xline(20, 'k--', 'Current assumption 20%', 'LineWidth', 1)
xline(27, 'g--', 'Grom estimate 27%',      'LineWidth', 1)
xline(12, 'r--', 'Z50 realistic 12%',      'LineWidth', 1)
yline(718, 'r--', 'Mater Dei 2025',        'LineWidth', 1)
yline(995, 'b--', 'BYU 2025',              'LineWidth', 1)
grid on

%% =========================================================================
% Summary Table
% =========================================================================

fprintf('=== Sweep Summary ===\n')
fprintf('%-30s %-12s %-12s\n', 'Parameter', 'Optimum', 'Best km/L')
fprintf('%-30s %-12s %-12.1f\n', 'Speed band v_low',  ...
        sprintf('%.1f m/s', vLow_vals(ri)),  maxVal)
fprintf('%-30s %-12s %-12.1f\n', 'Speed band v_high', ...
        sprintf('%.1f m/s', vHigh_vals(ci)), maxVal)
fprintf('%-30s %-12s %-12.1f\n', 'Gear ratio',        ...
        sprintf('%.1f', G_vals(idx_best_G)),  max(kmL_G,[],'omitnan'))
fprintf('%-30s %-12s %-12.1f\n', 'Mass',               ...
        sprintf('%d kg', m_vals(idx_best_m)), max(kmL_m,[],'omitnan'))
fprintf('%-30s %-12s %-12.1f\n', 'Drag coeff',         ...
        sprintf('%.2f', Cd_vals(1)),           max(kmL_Cd,[],'omitnan'))

% Sensitivity ranking (range normalised)
ranges = [range(kmL_map(:),'all','omitnan'), ...
          range(kmL_G,'omitnan'), ...
          range(kmL_m,'omitnan'), ...
          range(kmL_Cd,'omitnan'), ...
          range(kmL_eff,'omitnan')];
labels = {'Speed band','Gear ratio','Mass','Drag coeff','Engine efficiency'};
[~, ord] = sort(ranges, 'descend');
fprintf('\nSensitivity ranking (km/L range across sweep):\n')
for k = 1:length(labels)
    fprintf('  %d. %-22s  Δ = %.1f km/L\n', k, labels{ord(k)}, ranges(ord(k)))
end

%% =========================================================================
% Local helper — must be at END of script
% =========================================================================

function [kmL, t_total, valid] = extractMetricsV9(out)
% Extract race metrics from V9 simulation output.
% Returns km/L score, total 4-lap time, and pass/fail validity.
%
% Inputs:
%   out  — Simulink simulation output (logsout)
%
% Outputs:
%   kmL      — Shell km/L score (NaN if lap never completed)
%   t_total  — Time to complete 4 laps (s), or sim end time if incomplete
%   valid    — true if t_total < 2100s AND all 4 laps completed

    fuel_density = 0.745;   % kg/L gasoline
    lap_distance = 3832.5;  % m
    n_laps       = 4;
    t_max        = 2100;    % s (35 min)
    total_dist   = n_laps * lap_distance;

    x    = out.logsout.get('x_Vehicle').Values.Data;
    tv   = out.logsout.get('x_Vehicle').Values.Time;
    fuel = out.logsout.get('m_fuel').Values.Data;

    % Find index when total_dist first reached
    idx = find(x >= total_dist, 1, 'first');

    if isempty(idx)
        % Never completed — sim ended before 4 laps
        kmL     = NaN;
        t_total = tv(end);
        valid   = false;
        return
    end

    t_total  = tv(idx);
    fuel_kg  = fuel(idx);
    dist_km  = x(idx) / 1000;
    fuel_L   = fuel_kg / fuel_density;
    kmL      = dist_km / fuel_L;
    valid    = (t_total < t_max);
end
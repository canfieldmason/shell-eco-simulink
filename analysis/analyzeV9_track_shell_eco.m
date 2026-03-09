%% Analyze Shell Eco Run — V9
% Author: Mason Canfield
% Version: V9 (03-09-2026)
%
% Changelog V8 → V9:
%   - Lap-based metrics replace time-based (4 laps × 3832.5m = 15330m)
%   - Pass/fail check: total time must be < 2100s (Article 226)
%   - Per-lap breakdown: time, fuel, avg speed, km/L
%   - Zone-aware plots: burn-coast vs cruise vs corner regions shown
%   - Grade force included in force balance diagnostic
%   - Competition context: score vs 2025 field shown in summary

clc
clearvars -except out
close all

%% ── Load Params ──────────────────────────────────────────────────────────
run shell_eco_paramsV9_track

%% ── Extract Signals ──────────────────────────────────────────────────────
v       = out.logsout.get('v_Vehicle').Values.Data;
tv      = out.logsout.get('v_Vehicle').Values.Time;
x       = out.logsout.get('x_Vehicle').Values.Data;
E       = out.logsout.get('E_mech').Values.Data;
eta     = out.logsout.get('eta_Jpm').Values.Data;
fuel    = out.logsout.get('m_fuel').Values.Data;
P_shaft = out.logsout.get('P_shaft').Values.Data;
tP      = out.logsout.get('P_shaft').Values.Time;
RPM     = out.logsout.get('RPM').Values.Data;
tRPM    = out.logsout.get('RPM').Values.Time;
thr     = out.logsout.get('Throttle_CMD').Values.Data;
tThr    = out.logsout.get('Throttle_CMD').Values.Time;
F_eng   = out.logsout.get('F_Engine').Values.Data;
tF      = out.logsout.get('F_Engine').Values.Time;

%% ── Race-Level Metrics ───────────────────────────────────────────────────

% Find index when each lap completes
lap_ends = zeros(1, n_laps);
for lap = 1:n_laps
    target = lap * lap_distance;
    idx = find(x >= target, 1, 'first');
    if isempty(idx)
        warning('Lap %d never completed — simulation ended early', lap)
        lap_ends(lap) = length(x);
    else
        lap_ends(lap) = idx;
    end
end

% Total race metrics at 4-lap completion
idx_finish  = lap_ends(end);
t_total     = tv(idx_finish);
x_total     = x(idx_finish);
fuel_total  = fuel(idx_finish);
fuel_L      = fuel_total / fuel_density;
dist_km     = x_total / 1000;
score_kmL   = dist_km / fuel_L;
avg_speed   = x_total / t_total;

% Pass / fail
attempt_valid = t_total < t_max;
time_margin   = t_max - t_total;

fprintf('=== Shell Eco Run Results (V9) ===\n')
fprintf('Total distance:    %.1f m (target %.0f m)\n', x_total, total_dist)
fprintf('Total time:        %.1f s  (%.1f min)\n',    t_total,  t_total/60)
fprintf('Time limit:        %.0f s  (%.0f min)\n',    t_max,    t_max/60)
fprintf('Time margin:       %+.1f s\n',               time_margin)
if attempt_valid
    fprintf('Attempt valid:     YES ✓\n')
else
    fprintf('Attempt valid:     NO  ✗  (DISQUALIFIED — exceeded 35 min)\n')
end
fprintf('\n')
fprintf('Avg speed:         %.3f m/s  (min required %.3f m/s)\n', avg_speed, v_min_avg)
fprintf('Fuel consumed:     %.4f kg  (%.2f g)\n',   fuel_total, fuel_total*1000)
fprintf('Fuel consumed:     %.4f L\n',               fuel_L)
fprintf('Shell Score:       %.1f km/L\n',             score_kmL)
fprintf('\n')

% Competition context
fprintf('--- 2025 Field Comparison ---\n')
ref = [995, 718, 629, 323, 315, 177, 92];
names = {'BYU (rank 1)', 'Mater Dei (2)', 'IFRS Erechim (3)', ...
         'Michigan Tech (4)', 'Cedarville (5)', 'Penn St Behrend (6)', 'Schurr HS (7)'};
for k = 1:length(ref)
    pct = (score_kmL / ref(k)) * 100;
    fprintf('  vs %-22s %6.1f km/L  → you are %5.1f%%\n', names{k}, ref(k), pct)
end
fprintf('\n')

%% ── Per-Lap Breakdown ────────────────────────────────────────────────────
fprintf('--- Per-Lap Breakdown ---\n')
fprintf('%-6s %-10s %-10s %-10s %-10s %-10s\n', ...
        'Lap', 'Time(s)', 'LapTime(s)', 'AvgSpd', 'Fuel(g)', 'km/L')

t_prev    = 0;
x_prev    = 0;
fuel_prev = 0;

for lap = 1:n_laps
    idx = lap_ends(lap);
    t_lap     = tv(idx) - t_prev;
    x_lap     = x(idx)  - x_prev;
    f_lap     = fuel(idx) - fuel_prev;
    spd_lap   = x_lap / t_lap;
    kmL_lap   = (x_lap/1000) / (f_lap/fuel_density);
    fprintf('%-6d %-10.1f %-10.1f %-10.3f %-10.3f %-10.1f\n', ...
            lap, tv(idx), t_lap, spd_lap, f_lap*1000, kmL_lap)
    t_prev    = tv(idx);
    x_prev    = x(idx);
    fuel_prev = fuel(idx);
end
fprintf('\n')

%% ── Force Balance Diagnostic ─────────────────────────────────────────────
% At v_target on flat (grade = 0)
F_drag_th  = 0.5 * rho * Cd * A * v_target^2;
F_roll_th  = Crr * m * g;
F_grade_th = 0;   % flat section reference
F_resist   = F_drag_th + F_roll_th + F_grade_th;
a_coast    = -F_resist / m;

% Worst uphill grade on track
max_grade_val = max(track_grade);
F_grade_max   = m * g * max_grade_val;

fprintf('--- Force Balance at v_target = %.1f m/s (flat) ---\n', v_target)
fprintf('F_drag:            %.2f N\n',    F_drag_th)
fprintf('F_roll:            %.2f N\n',    F_roll_th)
fprintf('F_resist (flat):   %.2f N\n',    F_resist)
fprintf('Coast decel:       %.4f m/s²\n', a_coast)
fprintf('Coast band time (%.1f→%.1f m/s): %.1f s\n', ...
        v_high_on, v_low_on, (v_high_on - v_low_on) / abs(a_coast))
fprintf('Max uphill grade:  %.2f%%  → F_grade = %.2f N  (%.1f%% of F_resist)\n', ...
        max_grade_val*100, F_grade_max, 100*F_grade_max/F_resist)
fprintf('\n')

%% ── F_Engine Leak Check During Coast ─────────────────────────────────────
thr_interp = interp1(tThr, thr, tF, 'linear', 'extrap');
coast_mask = thr_interp < 0.1;
coast_F    = F_eng(coast_mask);

if isempty(coast_F) || max(abs(coast_F)) < 1.0
    fprintf('F_Engine check:    CLEAN — no leakage during coast\n\n')
else
    fprintf('WARNING: F_Engine leak during coast — %.2f N max, %.2f N avg\n\n', ...
            max(abs(coast_F)), mean(abs(coast_F)))
end

%% ── Coast Shape Diagnostic ───────────────────────────────────────────────
% Find first clean coast window after lap 1 completes
t_search_start = tv(lap_ends(1));
t_skip         = find(tv >= t_search_start, 1, 'first');
idx_start      = find(v(t_skip:end) >= v_high_on, 1, 'first') + t_skip - 1;

if ~isempty(idx_start)
    idx_end = find(v(idx_start:end) <= v_low_on, 1, 'first') + idx_start - 1;

    if ~isempty(idx_end)
        t_coast = tv(idx_start:idx_end) - tv(idx_start);
        v_coast = v(idx_start:idx_end);

        p_lin    = polyfit(t_coast, v_coast, 1);
        v_lin    = polyval(p_lin, t_coast);
        rmse_lin = sqrt(mean((v_coast - v_lin).^2));

        p_exp    = polyfit(t_coast, log(v_coast), 1);
        v_exp    = exp(polyval(p_exp, t_coast));
        rmse_exp = sqrt(mean((v_coast - v_exp).^2));

        fprintf('--- Coast Shape ---\n')
        fprintf('Linear RMSE:       %.5f m/s\n', rmse_lin)
        fprintf('Exponential RMSE:  %.5f m/s\n', rmse_exp)
        if rmse_exp < rmse_lin
            fprintf('Result:            CURVED (exponential) — physics correct\n\n')
        else
            fprintf('Result:            LINEAR — check F_Engine leakage\n\n')
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════════
% FIGURES
% ═══════════════════════════════════════════════════════════════════════

% Build zone shading arrays from track profile (for x-axis annotation)
% Map x_Vehicle position to zone during run
x_in_lap_run = mod(x, lap_distance);
zone_run     = interp1(track_x_breaks, double(track_zone), x_in_lap_run, ...
                       'nearest', 'extrap');

% Helper: shade background by zone
% Zone 1 = white (burn-coast), Zone 2 = light grey, Zone 3 = light red
zone_colors = {[1 1 1], [0.93 0.93 0.93], [1 0.88 0.88]};

%% Fig 1: Speed vs Time (full race, lap markers, zone shading)
figure('Name','V9 Speed vs Time','Position',[100 100 1100 420])
plot(tv(1:idx_finish), v(1:idx_finish), 'LineWidth', 1.8, 'Color', [0 0.45 0.74])
hold on
for lap = 1:n_laps
    xline(tv(lap_ends(lap)), 'k--', sprintf('Lap %d', lap), ...
          'LabelVerticalAlignment','bottom', 'LineWidth', 1)
end
yline(v_high_on, 'r:',  'v\_high\_on', 'LineWidth', 1)
yline(v_low_on,  'b:',  'v\_low\_on',  'LineWidth', 1)
yline(v_target,  'g--', 'v\_target',   'LineWidth', 1)
yline(v_min_avg, 'm--', 'min avg req', 'LineWidth', 1)
xlabel('Time (s)'); ylabel('Speed (m/s)')
title(sprintf('V9 Vehicle Speed — 4 Laps  |  Avg: %.2f m/s  |  Score: %.0f km/L  |  %s', ...
              avg_speed, score_kmL, ...
              char(attempt_valid*89 + ~attempt_valid*78) + "  " + ...
              sprintf('(margin %+.0fs)', time_margin)))
grid on; ylim([0 max(v(1:idx_finish))*1.1])

%% Fig 2: Speed vs Distance (1 lap overlay — all 4 laps)
figure('Name','V9 Lap Overlay','Position',[100 560 1100 420])
lap_colors = lines(n_laps);
t_prev = 0; x_prev = 0;
for lap = 1:n_laps
    if lap == 1
        idx0 = 1;
    else
        idx0 = lap_ends(lap-1);
    end
    idx1 = lap_ends(lap);
    x_lap_rel = x(idx0:idx1) - x_prev;
    v_lap     = v(idx0:idx1);
    plot(x_lap_rel, v_lap, 'LineWidth', 1.5, 'Color', lap_colors(lap,:), ...
         'DisplayName', sprintf('Lap %d', lap))
    hold on
    x_prev = x(lap_ends(lap));
    t_prev = tv(lap_ends(lap));
end

% Shade zones on lap plot (use track_zone directly)
ax = gca;
yl = ylim;
for k = 1:length(track_x_breaks)-1
    z = track_zone(k);
    if z == 3
        fill([track_x_breaks(k) track_x_breaks(k+1) ...
              track_x_breaks(k+1) track_x_breaks(k)], ...
             [yl(1) yl(1) yl(2) yl(2)], [1 0.88 0.88], ...
             'EdgeColor','none','FaceAlpha',0.3)
    elseif z == 2
        fill([track_x_breaks(k) track_x_breaks(k+1) ...
              track_x_breaks(k+1) track_x_breaks(k)], ...
             [yl(1) yl(1) yl(2) yl(2)], [0.93 0.93 0.93], ...
             'EdgeColor','none','FaceAlpha',0.4)
    end
end
% Re-plot lines on top of shading
x_prev = 0;
for lap = 1:n_laps
    if lap == 1
        idx = 1;
    else
        idx0 = lap_ends(lap-1);
    end
    idx1 = lap_ends(lap);
    x_lap_rel = x(idx0:idx1) - x_prev;
    plot(x_lap_rel, v(idx0:idx1), 'LineWidth', 1.5, 'Color', lap_colors(lap,:))
    x_prev = x(lap_ends(lap));
end

yline(v_high_on, 'r:', 'LineWidth',1); yline(v_low_on,'b:','LineWidth',1)
yline(v_target,  'g--','LineWidth',1)
xlabel('Distance in Lap (m)'); ylabel('Speed (m/s)')
title('Speed vs Lap Distance — All 4 Laps Overlaid  |  Pink=Turn  Grey=Short Straight  White=Burn-Coast')
legend('Location','best'); grid on

%% Fig 3: Fuel & Efficiency vs Distance
figure('Name','V9 Fuel & Efficiency','Position',[100 100 1100 600])

subplot(2,1,1)
plot(x(1:idx_finish), fuel(1:idx_finish)*1000, 'LineWidth', 1.8, 'Color', [0.47 0.67 0.19])
hold on
for lap = 1:n_laps
    xline(x(lap_ends(lap)), 'k--', sprintf('Lap %d', lap), ...
          'LabelVerticalAlignment','bottom')
end
xlabel('Distance (m)'); ylabel('Fuel (g)')
title(sprintf('Cumulative Fuel vs Distance   Total: %.2f g', fuel_total*1000))
grid on

subplot(2,1,2)
% Rolling km/L — recalculate from fuel signal
dist_km_sig  = x(1:idx_finish) / 1000;
fuel_L_sig   = fuel(1:idx_finish) / fuel_density;
kmL_live     = dist_km_sig ./ max(fuel_L_sig, 1e-9);
plot(x(1:idx_finish), kmL_live, 'LineWidth', 1.8, 'Color', [0.49 0.18 0.56])
hold on
yline(score_kmL, 'k--', sprintf('Final: %.0f km/L', score_kmL), 'LineWidth', 1.5)
for lap = 1:n_laps
    xline(x(lap_ends(lap)), 'k--')
end
xlabel('Distance (m)'); ylabel('km/L')
title('Rolling Shell Score (km/L) vs Distance')
grid on; ylim([0 max(kmL_live(50:end))*1.3])

%% Fig 4: Throttle & RPM
figure('Name','V9 Throttle & RPM','Position',[100 100 1100 500])

subplot(2,1,1)
plot(tThr(1:find(tThr>=tv(idx_finish),1)), thr(1:find(tThr>=tv(idx_finish),1)), ...
     'LineWidth', 1.5, 'Color', [0.30 0.75 0.93])
ylim([-0.1 1.1]); yticks([0 1]); yticklabels({'Coast','Burn'})
xlabel('Time (s)'); ylabel('Throttle')
title('Throttle Command — Burn=1  Coast=0')
for lap = 1:n_laps; xline(tv(lap_ends(lap)),'k--'); end
grid on

subplot(2,1,2)
idx_rpm_end = find(tRPM >= tv(idx_finish), 1);
plot(tRPM(1:idx_rpm_end), RPM(1:idx_rpm_end), ...
     'LineWidth', 1.5, 'Color', [0.49 0.18 0.56])
yline(RPM_idle, 'r--', 'RPM\_idle', 'LineWidth', 1)
yline(RPM_max,  'r--', 'RPM\_max',  'LineWidth', 1)
xlabel('Time (s)'); ylabel('RPM')
title('Engine RPM vs Time')
for lap = 1:n_laps; xline(tv(lap_ends(lap)),'k--'); end
grid on

%% Fig 5: Track Grade + Elevation Profile
figure('Name','V9 Track Profile','Position',[100 100 1100 400])

yyaxis left
plot(track_x_breaks, track_grade*100, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2)
yline(0, 'k-')
ylabel('Grade (%)')

yyaxis right
% Reconstruct elevation from grade (starts at 0)
elev_reconstructed = cumsum([0; diff(track_x_breaks) .* track_grade(1:end-1)]);
plot(track_x_breaks, elev_reconstructed, 'Color', [0 0.45 0.74], 'LineWidth', 1.5)
ylabel('Relative Elevation (m)')

% Mark turn zones
ax2 = gca; yl = ylim;
for k = 1:length(track_x_breaks)-1
    if track_zone(k) == 3
        fill([track_x_breaks(k) track_x_breaks(k+1) ...
              track_x_breaks(k+1) track_x_breaks(k)], ...
             [yl(1) yl(1) yl(2) yl(2)], [1 0.88 0.88], ...
             'EdgeColor','none','FaceAlpha',0.5)
    end
end
xlabel('Position in Lap (m)')
title('Track Grade & Elevation Profile   |   Pink = Turn Zones')
grid on
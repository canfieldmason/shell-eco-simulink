%% Analyze Shell Eco Run — V8
% Author: Mason Canfield
% Updated: signal names match V8 logsout, fixed coast diagnostic,
%          fixed F_Engine leak check, fuel from shaft power path
clc
clearvars -except out
close all

%% ── Extract Signals ──────────────────────────────────────────────────────
E       = out.logsout.get('E_mech').Values.Data;
tE      = out.logsout.get('E_mech').Values.Time;
eta     = out.logsout.get('eta_Jpm').Values.Data;
tEta    = out.logsout.get('eta_Jpm').Values.Time;
fuel    = out.logsout.get('m_fuel').Values.Data;
P_shaft = out.logsout.get('P_shaft').Values.Data;
tP      = out.logsout.get('P_shaft').Values.Time;
RPM     = out.logsout.get('RPM').Values.Data;
tRPM    = out.logsout.get('RPM').Values.Time;
thr     = out.logsout.get('Throttle_CMD').Values.Data;
tThr    = out.logsout.get('Throttle_CMD').Values.Time;
v       = out.logsout.get('v_Vehicle').Values.Data;
tv      = out.logsout.get('v_Vehicle').Values.Time;
x       = out.logsout.get('x_Vehicle').Values.Data;
F_eng   = out.logsout.get('F_Engine').Values.Data;
tF      = out.logsout.get('F_Engine').Values.Time;

%% ── Load Params ──────────────────────────────────────────────────────────
run shell_eco_paramsV6

%% ── Performance Metrics ──────────────────────────────────────────────────
x_end      = x(end);
E_total    = E(end);
fuel_used  = fuel(end);
avg_speed  = mean(v);
max_speed  = max(v);
efficiency = E_total / x_end;

% Shell scoring conversion (gasoline: LHV = 44 MJ/kg, density = 0.745 kg/L)
fuel_L     = fuel_used / 0.745;                    % liters consumed
dist_km    = x_end / 1000;                         % km covered
if fuel_L > 0
    score_kmL = dist_km / fuel_L;                  % km/L
else
    score_kmL = inf;
end

fprintf('=== Shell Eco Run Results (V8) ===\n');
fprintf('Distance:          %.1f m\n',     x_end);
fprintf('Energy (mech):     %.1f kJ\n',    E_total/1000);
fprintf('Fuel consumed:     %.4f kg\n',    fuel_used);
fprintf('Fuel consumed:     %.2f g\n',     fuel_used*1000);
fprintf('Avg Speed:         %.2f m/s\n',   avg_speed);
fprintf('Max Speed:         %.2f m/s\n',   max_speed);
fprintf('Energy per meter:  %.4f J/m\n',   efficiency);
fprintf('Live eta (final):  %.4f J/m\n',   eta(end));
fprintf('Shell Score:       %.1f km/L\n',  score_kmL);

%% ── Diagnostic 1: Force Balance at v_target ─────────────────────────────
v_check   = v_target;
F_drag_th = 0.5 * rho * Cd * A * v_check^2;
F_roll_th = Crr * m * g;
F_resist  = F_drag_th + F_roll_th;
a_coast   = -F_resist / m;

fprintf('\n--- Force Balance at %.1f m/s ---\n', v_check);
fprintf('F_drag:            %.2f N\n',   F_drag_th);
fprintf('F_roll:            %.2f N\n',   F_roll_th);
fprintf('F_resist total:    %.2f N\n',   F_resist);
fprintf('Coast decel:       %.4f m/s^2\n', a_coast);
fprintf('Coast band time (%.1f to %.1f m/s): %.1f s\n', ...
        v_high_on, v_low_on, (v_high_on - v_low_on) / abs(a_coast));

%% ── Diagnostic 2: F_Engine leak check during coast ──────────────────────
thr_interp   = interp1(tThr, thr, tF, 'linear', 'extrap');
coast_mask   = thr_interp < 0.1;
coast_F      = F_eng(coast_mask);

if isempty(coast_F) || max(abs(coast_F)) < 1.0
    fprintf('\nF_Engine check:    CLEAN — no leakage during coast\n');
else
    fprintf('\nWARNING: F_Engine leak during coast — %.2f N max, %.2f N avg\n', ...
            max(abs(coast_F)), mean(abs(coast_F)));
end

%% ── Diagnostic 3: Coast shape — linear vs exponential ───────────────────
t_skip    = find(tv >= 10, 1, 'first');
idx_start = find(v(t_skip:end) >= v_high_on, 1, 'first') + t_skip - 1;

if ~isempty(idx_start)
    idx_start = idx_start(1);
    idx_end   = find(v(idx_start:end) <= v_low_on, 1, 'first') + idx_start - 1;

    if ~isempty(idx_end)
        idx_end = idx_end(1);

        t_coast  = tv(idx_start:idx_end) - tv(idx_start);
        v_coast  = v(idx_start:idx_end);

        % Linear fit
        p_lin    = polyfit(t_coast, v_coast, 1);
        v_lin    = polyval(p_lin, t_coast);
        rmse_lin = sqrt(mean((v_coast - v_lin).^2));

        % Exponential fit
        p_exp    = polyfit(t_coast, log(v_coast), 1);
        v_exp    = exp(polyval(p_exp, t_coast));
        rmse_exp = sqrt(mean((v_coast - v_exp).^2));

        fprintf('\n--- Coast Shape Fit ---\n');
        fprintf('Linear RMSE:       %.5f m/s\n', rmse_lin);
        fprintf('Exponential RMSE:  %.5f m/s\n', rmse_exp);
        if rmse_exp < rmse_lin
            fprintf('Result:            CURVED (exponential) — physics correct\n');
        else
            fprintf('Result:            LINEAR — check F_Engine leakage or params\n');
        end

        figure
        plot(t_coast, v_coast, 'k-',  'LineWidth', 2, 'DisplayName', 'Simulated'); hold on
        plot(t_coast, v_lin,   'r--', 'LineWidth', 1.5, ...
             'DisplayName', sprintf('Linear (RMSE=%.5f)', rmse_lin));
        plot(t_coast, v_exp,   'b--', 'LineWidth', 1.5, ...
             'DisplayName', sprintf('Exponential (RMSE=%.5f)', rmse_exp));
        xlabel('Time in Coast Window (s)')
        ylabel('Speed (m/s)')
        title('Coast Phase Shape Diagnostic')
        legend; grid on
    end
else
    fprintf('\nCould not isolate coast window — check v_high_on threshold\n');
end

%% ── Standard Plots ───────────────────────────────────────────────────────

% Speed vs Time
figure
plot(tv, v, 'LineWidth', 2, 'Color', [0 0.45 0.74])
if exist('idx_start','var') && exist('idx_end','var')
    xline(tv(idx_start), 'g--', 'Coast Start', 'LabelVerticalAlignment', 'bottom');
    xline(tv(idx_end),   'r--', 'Burn Start',  'LabelVerticalAlignment', 'bottom');
end
yline(v_high_on, 'k:', 'v\_high\_on');
yline(v_low_on,  'k:', 'v\_low\_on');
xlabel('Time (s)'); ylabel('Speed (m/s)')
title('Vehicle Speed vs Time'); grid on

% Energy vs Distance
figure
plot(x, E/1000, 'LineWidth', 2, 'Color', [0.85 0.33 0.10])
xlabel('Distance (m)'); ylabel('Energy (kJ)')
title('Mechanical Energy vs Distance'); grid on

% Fuel vs Distance
figure
plot(x, fuel*1000, 'LineWidth', 2, 'Color', [0.47 0.67 0.19])
xlabel('Distance (m)'); ylabel('Fuel Consumed (g)')
title('Fuel Consumption vs Distance'); grid on

% RPM vs Time
figure
plot(tRPM, RPM, 'LineWidth', 2, 'Color', [0.49 0.18 0.56])
yline(RPM_idle, 'r--', 'RPM\_idle');
yline(RPM_max,  'r--', 'RPM\_max');
xlabel('Time (s)'); ylabel('Engine RPM')
title('Engine RPM vs Time'); grid on

% Shaft Power vs Time
figure
plot(tP, P_shaft/1000, 'LineWidth', 2, 'Color', [0.93 0.69 0.13])
yline(0, 'k--');
xlabel('Time (s)'); ylabel('P_{shaft} (kW)')
title('Engine Shaft Power vs Time'); grid on

% Efficiency (J/m) vs Distance — live from Simulink
figure
plot(x, eta, 'LineWidth', 2, 'Color', [0.47 0.18 0.56])
xlabel('Distance (m)'); ylabel('\eta (J/m)')
title('Rolling Efficiency vs Distance'); grid on

% F_Engine vs Time
figure
plot(tF, F_eng, 'LineWidth', 2, 'Color', [0.64 0.08 0.18])
yline(0, 'k--');
xlabel('Time (s)'); ylabel('F_{Engine} (N)')
title('Engine Force vs Time'); grid on

% Throttle vs Time
figure
plot(tThr, thr, 'LineWidth', 2, 'Color', [0.30 0.75 0.93])
ylim([-0.1 1.1])
xlabel('Time (s)'); ylabel('Throttle (0/1)')
title('Throttle Command vs Time'); grid on

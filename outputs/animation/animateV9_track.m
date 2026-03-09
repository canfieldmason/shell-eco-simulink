%% Shell Eco-Marathon — 2D Track Animation
% Author: Mason Canfield
% Version: V9 (03-09-2026)
%
% Plays back lap 1 of the simulation as a live animation.
% Car position is interpolated from x_Vehicle signal back to GPS lat/lon.
% Speed is shown by dot color (blue=slow, red=fast).
%
% Requirements:
%   - sim output 'out' must be in workspace (run shell_eco_mainV9_track first)
%   - sem-us-2022-track_coordinates.csv must be on MATLAB path

%% ── Load track coordinates ───────────────────────────────────────────────
coords = readtable('sem-us-2022-track_coordinates.csv');
lat    = coords.Latitude;
lon    = coords.Longitude;

% Convert lat/lon to local XY metres (flat earth approximation — fine for 3.8km)
lat0   = lat(1);
lon0   = lon(1);
R_earth = 6371000;

track_x_m = deg2rad(lon - lon0) * R_earth * cos(deg2rad(lat0));  % East  (m)
track_y_m = deg2rad(lat - lat0) * R_earth;                        % North (m)

% Cumulative distance along track (matches x_Vehicle signal)
n = length(track_x_m);
cum_dist = zeros(n, 1);
for i = 2:n
    dx = track_x_m(i) - track_x_m(i-1);
    dy = track_y_m(i) - track_y_m(i-1);
    cum_dist(i) = cum_dist(i-1) + sqrt(dx^2 + dy^2);
end

%% ── Extract simulation signals ───────────────────────────────────────────
x_sig  = out.logsout.get('x_Vehicle').Values.Data;
tv_sig = out.logsout.get('x_Vehicle').Values.Time;
v_sig  = out.logsout.get('v_Vehicle').Values.Data;
tv_v   = out.logsout.get('v_Vehicle').Values.Time;

% Interpolate velocity onto x_Vehicle time base
v_interp = interp1(tv_v, v_sig, tv_sig, 'linear', 'extrap');

% Isolate lap 1 only (x = 0 to lap_distance)
run shell_eco_paramsV9_track
lap1_mask  = x_sig <= lap_distance;
x_lap1     = x_sig(lap1_mask);
tv_lap1    = tv_sig(lap1_mask);
v_lap1     = v_interp(lap1_mask);

% Map x_Vehicle distance → track XY position
% x_Vehicle is cumulative distance, cum_dist is distance along GPS points
car_x = interp1(cum_dist, track_x_m, x_lap1, 'linear', 'extrap');
car_y = interp1(cum_dist, track_y_m, x_lap1, 'linear', 'extrap');

%% ── Animation setup ──────────────────────────────────────────────────────
fig = figure('Name', 'Shell Eco Track Animation', ...
             'Position', [100 100 900 700], ...
             'Color', [0.12 0.12 0.12]);

ax = axes('Parent', fig, 'Color', [0.12 0.12 0.12], ...
          'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
hold(ax, 'on'); axis(ax, 'equal');

% Draw track outline
plot(ax, track_x_m, track_y_m, '-', ...
     'Color', [0.35 0.35 0.35], 'LineWidth', 8)

% Draw track centre line
plot(ax, track_x_m, track_y_m, '--', ...
     'Color', [0.55 0.55 0.55], 'LineWidth', 1)

% Mark start/finish
plot(ax, track_x_m(1), track_y_m(1), 's', ...
     'Color', [0.2 0.9 0.2], 'MarkerSize', 14, ...
     'MarkerFaceColor', [0.2 0.9 0.2])
text(ax, track_x_m(1)+3, track_y_m(1)+3, 'S/F', ...
     'Color', [0.2 0.9 0.2], 'FontWeight', 'bold', 'FontSize', 10)

% Mark turn 18 (tightest corner)
turn18_x = interp1(cum_dist, track_x_m, 3154);
turn18_y = interp1(cum_dist, track_y_m, 3154);
plot(ax, turn18_x, turn18_y, 'o', ...
     'Color', [1 0.5 0], 'MarkerSize', 10, 'LineWidth', 2)
text(ax, turn18_x+3, turn18_y+3, 'T18', ...
     'Color', [1 0.5 0], 'FontSize', 9)

% Colourmap: blue (slow) → red (fast)
v_min = min(v_lap1); v_max = max(v_lap1);
cmap  = cool(256);

% Car dot — will be updated each frame
car_dot = plot(ax, car_x(1), car_y(1), 'o', ...
               'MarkerSize', 14, 'MarkerFaceColor', [1 1 0], ...
               'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);

% Speed trail — last N positions coloured by speed
trail_len = 80;
trail_dots = gobjects(trail_len, 1);
for k = 1:trail_len
    trail_dots(k) = plot(ax, NaN, NaN, '.', 'MarkerSize', 6);
end

% Labels and formatting
xlabel(ax, 'East (m)');  ylabel(ax, 'North (m)')
title(ax, 'Shell Eco-Marathon — IMS Infield Course', ...
      'Color', [0.9 0.9 0.9], 'FontSize', 13)

% Info text boxes
time_txt  = text(ax, 0.02, 0.97, '', 'Units', 'normalized', ...
                 'Color', [0.9 0.9 0.9], 'FontSize', 11, ...
                 'VerticalAlignment', 'top', 'FontName', 'Courier');
speed_txt = text(ax, 0.02, 0.88, '', 'Units', 'normalized', ...
                 'Color', [0.9 0.9 0.9], 'FontSize', 11, ...
                 'VerticalAlignment', 'top', 'FontName', 'Courier');
dist_txt  = text(ax, 0.02, 0.79, '', 'Units', 'normalized', ...
                 'Color', [0.9 0.9 0.9], 'FontSize', 11, ...
                 'VerticalAlignment', 'top', 'FontName', 'Courier');

% Throttle indicator
thr_sig  = out.logsout.get('Throttle_CMD').Values.Data;
tv_thr   = out.logsout.get('Throttle_CMD').Values.Time;
thr_lap1 = interp1(tv_thr, thr_sig, tv_lap1, 'nearest', 'extrap');

thr_txt  = text(ax, 0.02, 0.70, '', 'Units', 'normalized', ...
                'FontSize', 11, 'VerticalAlignment', 'top', ...
                'FontName', 'Courier', 'FontWeight', 'bold');

% Speed colorbar
colormap(ax, cmap)
clim(ax, [v_min v_max])
cb = colorbar(ax);
cb.Color = [0.8 0.8 0.8];
cb.Label.String = 'Speed (m/s)';
cb.Label.Color  = [0.8 0.8 0.8];

axis(ax, 'tight')
pad = 20;
xl = xlim(ax); yl = ylim(ax);
xlim(ax, [xl(1)-pad xl(2)+pad])
ylim(ax, [yl(1)-pad yl(2)+pad])

%% ── Animation loop ───────────────────────────────────────────────────────
% Playback speed: SPEED_FACTOR = 1 → real time
%                 SPEED_FACTOR = 5 → 5x faster
SPEED_FACTOR = 16;

fprintf('Starting animation (%.0fx speed)... close figure to stop\n', SPEED_FACTOR)
fprintf('Lap 1 duration: %.1f s\n', tv_lap1(end))

n_frames  = length(tv_lap1);
t_prev_wall = tic;
t_prev_sim  = tv_lap1(1);

for i = 1:n_frames

    if ~ishandle(fig); break; end  % stop if figure closed

    % Speed → colour index
    v_norm  = (v_lap1(i) - v_min) / (v_max - v_min + 1e-6);
    c_idx   = max(1, min(256, round(v_norm * 255) + 1));
    dot_col = cmap(c_idx, :);

    % Update car dot
    set(car_dot, 'XData', car_x(i), 'YData', car_y(i), ...
                 'MarkerFaceColor', dot_col)

    % Update speed trail
    for k = 1:trail_len
        idx_trail = i - k;
        if idx_trail >= 1
            v_t   = (v_lap1(idx_trail) - v_min) / (v_max - v_min + 1e-6);
            c_t   = max(1, min(256, round(v_t*255)+1));
            alpha = 1 - k/trail_len;   % fade out older points
            col_t = cmap(c_t,:) * alpha + [0.12 0.12 0.12] * (1-alpha);
            set(trail_dots(k), 'XData', car_x(idx_trail), ...
                               'YData', car_y(idx_trail), ...
                               'Color', col_t)
        else
            set(trail_dots(k), 'XData', NaN, 'YData', NaN)
        end
    end

    % Update text
    set(time_txt,  'String', sprintf('Time:  %6.1f s', tv_lap1(i)))
    set(speed_txt, 'String', sprintf('Speed: %5.2f m/s', v_lap1(i)))
    set(dist_txt,  'String', sprintf('Dist:  %6.1f m',  x_lap1(i)))

    % Throttle state indicator
    if thr_lap1(i) > 0.5
        set(thr_txt, 'String', '[ BURN  ]', 'Color', [1 0.4 0.2])
    else
        set(thr_txt, 'String', '[ COAST ]', 'Color', [0.3 0.7 1.0])
    end

    drawnow limitrate

    % Timing — advance to next frame at correct wall-clock rate
    if i < n_frames
        dt_sim  = tv_lap1(i+1) - tv_lap1(i);
        dt_wall = dt_sim / SPEED_FACTOR;
        elapsed = toc(t_prev_wall);
        pause_t = max(0, dt_wall - elapsed);
        if pause_t > 0; pause(pause_t); end
        t_prev_wall = tic;
    end

end

fprintf('Animation complete.\n')
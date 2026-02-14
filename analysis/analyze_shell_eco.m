%% Analyze Shell Eco Run
clc
clearvars -except out   % keep sim output
close all

%% Extract Signals

E = out.logsout.get('E_used').Values.Data;
tE = out.logsout.get('E_used').Values.Time;

fuel = out.logsout.get('m_Fuel').Values.Data;

RPM = out.logsout.get('RPM').Values.Data;
tRPM = out.logsout.get('RPM').Values.Time;

v = out.logsout.get('v_Vehicle').Values.Data;
tv = out.logsout.get('v_Vehicle').Values.Time;

x = out.logsout.get('x_Vehicle').Values.Data;

%% Performance Metrics

x_end = x(end);
E_total = E(end);
fuel_used = fuel(end);

avg_speed = mean(v);
max_speed = max(v);

fprintf('--- Shell Eco Run Results ---\n');
fprintf('Distance: %.1f m\n', x_end);
fprintf('Energy: %.1f kJ\n', E_total/1000);
fprintf('Fuel: %.4f kg\n', fuel_used);
fprintf('Avg Speed: %.2f m/s\n', avg_speed);
fprintf('Max Speed: %.2f m/s\n', max_speed);

%% Plots

figure
plot(tv, v, 'LineWidth', 2)
xlabel('Time (s)')
ylabel('Speed (m/s)')
title('Vehicle Speed vs Time')
grid on

figure
plot(x, E/1000, 'LineWidth', 2)
xlabel('Distance (m)')
ylabel('Energy (kJ)')
title('Energy vs Distance')
grid on

figure
plot(tRPM, RPM, 'LineWidth', 2)
xlabel('Time (s)')
ylabel('Engine RPM')
title('Engine Speed')
grid on


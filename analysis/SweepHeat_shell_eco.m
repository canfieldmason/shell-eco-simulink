%% Shell Eco 2D Heatmap: Cd vs Mass (Constrained, V2 Final)
% SweepHeat V2 Final
% Author: Mason Canfield
% Purpose: Constrained Design Space Visualization with optional Excel export

clear; clc; close all;

%% =========================
% User Settings
% =========================

EXPORT_TO_EXCEL = false;   % Set to true to export sweep results
D_min = 500;              % Minimum required distance (m)
v_min = 4;                % Minimum average speed (m/s)

%% =========================
% Load Base Parameters
% =========================

run shell_eco_paramsV2

%% =========================
% Sweep Ranges
% =========================

Cd_vals = 0.14:0.01:0.22;
m_vals  = 80:5:120;

Nc = length(Cd_vals);
Nm = length(m_vals);

%% =========================
% Storage
% =========================

Eff_2D  = nan(Nc, Nm);   % Fuel per distance (kg/m)
Dist_2D = nan(Nc, Nm);   % Distance (m)

%% =========================
% 2D Sweep
% =========================

for i = 1:Nc
    for j = 1:Nm

        % Reset parameters for each run
        run shell_eco_paramsV2

        % Apply sweep values
        Cd = Cd_vals(i);
        m  = m_vals(j);

        % Run model
        out = sim('shell_eco_mainV2');

        % Extract signals
        fuel = out.logsout.get('m_Fuel').Values.Data;
        x    = out.logsout.get('x_Vehicle').Values.Data;
        v    = out.logsout.get('v_Vehicle').Values.Data;

        finalFuel = fuel(end);
        finalDist = x(end);
        v_avg     = mean(v);

        % Apply constraints
        if finalDist >= D_min && v_avg >= v_min
            Eff_2D(i,j)  = finalFuel / finalDist;
            Dist_2D(i,j) = finalDist;
        end

    end
end

%% =========================
% Auto-Pick Best Design
% =========================

Eff_vec = Eff_2D(:);
validIdx = ~isnan(Eff_vec);
Eff_valid = Eff_vec(validIdx);

[minEff, localIdx] = min(Eff_valid);

fullIdx = find(validIdx);
idx = fullIdx(localIdx);

[row, col] = ind2sub(size(Eff_2D), idx);

bestCd = Cd_vals(row);
bestM  = m_vals(col);

fprintf('\n=== OPTIMAL DESIGN (CONSTRAINED) ===\n');
fprintf('Cd        = %.3f\n', bestCd);
fprintf('Mass      = %.1f kg\n', bestM);
fprintf('Fuel/Dist = %.6e kg/m\n\n', minEff);

%% =========================
% Heatmap: Efficiency
% =========================

figure;
imagesc(m_vals, Cd_vals, Eff_2D);
colorbar;
clim([nanmin(Eff_2D(:)) nanmax(Eff_2D(:))]);   % Use clim instead of caxis
set(gca,'YDir','normal');
xlabel('Mass (kg)');
ylabel('Cd');
title('Fuel per Distance (kg/m)');

% Add marker for best design
hold on;
plot(bestM, bestCd,'kp','MarkerSize',12,'MarkerFaceColor','r');
text(bestM, bestCd, sprintf('  Optimal'), 'Color','w','FontWeight','bold');

%% =========================
% Heatmap: Distance
% =========================

figure;
imagesc(m_vals, Cd_vals, Dist_2D);
colorbar;
clim([nanmin(Dist_2D(:)) nanmax(Dist_2D(:))]);
set(gca,'YDir','normal');
xlabel('Mass (kg)');
ylabel('Cd');
title('Distance (m)');

% Marker for same best design
hold on;
plot(bestM, bestCd,'kp','MarkerSize',12,'MarkerFaceColor','r');
text(bestM, bestCd, sprintf('  Optimal'), 'Color','w','FontWeight','bold');

%% =========================
% Optional Excel Export
% =========================

if EXPORT_TO_EXCEL
    [Mgrid, Cgrid] = meshgrid(m_vals, Cd_vals);
    T_Eff = table(Cgrid(:), Mgrid(:), Eff_2D(:), Dist_2D(:), ...
                  'VariableNames', {'Cd','Mass','FuelPerDistance_kgpm','Distance_m'});
    writetable(T_Eff,'SweepHeat_2D_Results.xlsx');
    fprintf('Excel export complete: SweepHeat_2D_Results.xlsx\n');
end

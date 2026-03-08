%% Build Engine Map for V4
% Uses Dyno Data

clear; clc;

%% Load Data
T = readtable('Run2.xlsx');

time = T{:,1};
hp   = T{:,2};   % <-- REAL horsepower
rpm  = T{:,3};

%% Clean Raw Data FIRST

valid = rpm > 1500 & hp > 0 & rpm < 9000;

rpm = rpm(valid);
hp  = hp(valid);

%% Unit Conversion (After Filtering)

P = hp * 745.7;            % W
omega = 2*pi*rpm/60;      % rad/s

%% Torque Calculation (Now Safe)

Torque = P ./ omega;

%% Average Duplicate RPM Points

% Combine duplicate RPMs
[rpm_u,~,idx] = unique(rpm);

Torque_avg = accumarray(idx, Torque, [], @mean);

%% Create Smooth RPM Grid

rpm_bins = min(rpm_u):250:max(rpm_u);

T_avg = interp1(rpm_u, Torque_avg, rpm_bins, 'pchip');

%% Enforce Realistic Torque Envelope

rpm_peak = 6000;    % peak torque RPM
rpm_red  = 8500;    % redline

T_peak = max(T_avg);

T_env = zeros(size(rpm_bins));

for i = 1:length(rpm_bins)

    r = rpm_bins(i);

    if r <= rpm_peak
        % Rising torque (quadratic)
        T_env(i) = T_peak*(r/rpm_peak)^1.2;

    elseif r <= rpm_red
        % Falling torque
        T_env(i) = T_peak*(1 - 0.6*(r-rpm_peak)/(rpm_red-rpm_peak));

    else
        T_env(i) = 0;
    end

end

% Blend measured + envelope
alpha = 0.6;  % trust factor

T_avg = alpha*T_avg + (1-alpha)*T_env;


%% Plot

figure;
plot(rpm, Torque,'.', 'DisplayName','Raw');
hold on;
plot(rpm_bins, T_avg,'-o','LineWidth',2,'DisplayName','Avg');
grid on;

xlabel('RPM');
ylabel('Torque (Nm)');
title('Engine Torque Map (V4)');
legend;

%% Save For Params File

EngineRPM = rpm_bins;
EngineTmax = T_avg;

save engine_mapV4.mat EngineRPM EngineTmax

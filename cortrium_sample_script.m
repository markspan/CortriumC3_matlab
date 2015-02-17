%%% Cortrium sample script %%%
% Script showing how to load data and use the toolbox

% Define path to the files
path_to_data_files = fullfile(pwd, 'sample_data');
%path_to_data_files = fullfile(pwd, 'sample_data_sleep_supine_1h');

% Create a new C3 object
C3 = cortrium_c3(path_to_data_files);

% Initialise components and load data
C3.initialize;

% Clean accelerometer and temperature data for jitter
C3.clean_sensor_data;

% Smoothen respiration data
C3.resp.smoothen;

% Find peaks and plot for at small segment of respiration data
C3.respiration_test;

% Plot sample of unfiltered ECG data
figure, plot(C3.ecg.data);
title('ECG data');


%% Create figures of sensor data from accelerometer and thermometers
time_format = 'HH:MM:SS';
xData_25hz = linspace(C3.date_start,C3.date_end,C3.accel.samplenum);

figure;
subplot(5,1,1)
plot(xData_25hz, C3.accel.data(:,1)) %x axis
title('Accelerometer X-axis');
datetick('x', time_format, 'keeplimits', 'keepticks');

subplot(5,1,2)
plot(xData_25hz, C3.accel.data(:,2)) %y axis
title('Accelerometer Y-axis');
datetick('x', time_format, 'keeplimits', 'keepticks');

subplot(5,1,3)
plot(xData_25hz, C3.accel.data(:,3)) %z axis
title('Accelerometer Z-axis');
datetick('x', time_format, 'keeplimits', 'keepticks');

subplot(5,1,4)
plot(xData_25hz, sqrt(sum(C3.accel.data.^2,2))) %magnitude
title('Accelerometer magnitude');
datetick('x', time_format, 'keeplimits', 'keepticks');

subplot(5,1,5)
plot(xData_25hz, C3.temp.data) %temp
title('Surface and Ambient Temperature (Celcius)');
datetick('x', time_format, 'keeplimits', 'keepticks');

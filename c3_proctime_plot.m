%% Script for plotting c3 process times

% To close all plot windows in one go, type: close all
% in Matlab console

clear;

% % (MATLAB R2014b+) turn off graphics smoothing on graphics root object
% set(groot,'DefaultFigureGraphicsSmoothing','off')

ble_fullpath = 'C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\55B9FA9E\55B9FA9E.BLE';

% calling c3_read_ble_processTimes.m to load the data
[serialNumber, ~, ~, ~, proctime] = c3_read_ble_processTimes(ble_fullpath);
% % alternative, if you want more data
%[serialNumber, leadoff, acc, temp, proctime] = c3_read_ble_processTimes(ble_fullpath);

[~,ble_filename_wo_extension,ble_extension] = fileparts(ble_fullpath);

% get screen size
screenSize = get(0,'screensize');
% define position and size of plot windows
winXpos = round(screenSize(3)*0.05);
winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.1);
winWidth = round(screenSize(3)*0.5);
winHeight = round(screenSize(4)*0.5);

% maximum proctime. Will be used to set an y-axis limit, shared by all plots.
yMax = nanmax(nanmax(proctime));

%%
%--- PLOTS WITH PACKET SERIAL NUMBER ON X-AXIS ---%

% plot each column of proctime in separate windows
for ii=1:size(proctime,2)
    FigTitleStr = sprintf('Process %d     %s',ii,[ble_filename_wo_extension ble_extension]);
    hProctimeFig = figure('Numbertitle','off','Name',FigTitleStr,'OuterPosition', [winXpos winYpos winWidth winHeight],'Visible','off'); %,'Visible','off'
    hAxesProctime = axes('Parent',hProctimeFig);
    hAxesProctime.XLim = [1 length(serialNumber)];
    hAxesProctime.YLim = [0 yMax]; % y-axis limits
    hold on;
    % NOTE: missed bluetooth packets all have serial number = 0.
    % Here, (1:length(serialNumber)) is used as x-axis data.
    % Optionally, x-axis ticks could be replaced by actual serial number.
    plot(hAxesProctime,(1:length(serialNumber)),proctime(:,ii),'Color','r'); % plot as line
%     plot(hAxesProctime,(1:length(serialNumber)),proctime(:,ii),'Color','r','LineStyle','none','Marker','.','MarkerSize',1); % plot as discrete points
    title(hAxesProctime,FigTitleStr,'FontSize',12,'FontWeight','bold');
    xlabel(hAxesProctime,'packet serial number','FontSize',10);
    ylabel(hAxesProctime,'process time (ms)','FontSize',10);
    set(hAxesProctime,'FontSize',10);
    hProctimeFig.Visible = 'on';
end

%%
%--- PLOTS WITH DURATION TIMESTAMPS ON X-AXIS (uncomment code below) ---%

% % calculate timestamps as duration
% timeStart.duration = days(0);
% secondsPerDay = 24*60*60;
% timeEnd.duration = days(length(serialNumber)/25/secondsPerDay);
% xAxisTimeStamps.duration = linspace(timeStart.duration,timeEnd.duration,length(serialNumber));
% 
% % plot each column of proctime in separate windows
% for ii=1:size(proctime,2)
%     FigTitleStr = sprintf('Process %d     %s',ii,[ble_filename_wo_extension ble_extension]);
%     hProctimeFig = figure('Numbertitle','off','Name',FigTitleStr,'OuterPosition', [winXpos winYpos winWidth winHeight],'Visible','off'); %,'Visible','off'
%     hAxesProctime = axes('Parent',hProctimeFig);
%     hAxesProctime.YLim = [0 yMax]; % y-axis limits
%     hold on;
%     plot(hAxesProctime,xAxisTimeStamps.duration,proctime(:,ii),'Color','r','DurationTickFormat','hh:mm:ss.SSS');
%     title(hAxesProctime,FigTitleStr,'FontSize',12,'FontWeight','bold');
%     xlabel(hAxesProctime,'recording time (hrs:min:sec.millisec)','FontSize',10);
%     ylabel(hAxesProctime,'process time (ms)','FontSize',10);
%     set(hAxesProctime,'FontSize',10);
%     hAxesProctime.XLim = [datenum(xAxisTimeStamps.duration(1)) datenum(xAxisTimeStamps.duration(end))];
%     hProctimeFig.Visible = 'on';
% end

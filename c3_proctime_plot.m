%% Script for plotting c3 process times

% Process times are plotted in blue color.
% Missed packets are plotted in red.

% To close all plot windows in one go, type: close all
% in Matlab console

clear;

% % (MATLAB R2014b+) turn off graphics smoothing on graphics root object
% set(groot,'DefaultFigureGraphicsSmoothing','off')

ble_fullpath = 'D:\Matlab\Cortrium\C3_recordings\ProcessTimes\56350B9D\56350B9D.BLE';

% calling c3_read_ble_processTimes.m to load the data
[serialNumber, ~, ~, ~, proctime, missedPackets] = c3_read_ble_processTimes(ble_fullpath);
% % alternative, if you want more data
%[serialNumber, leadoff, acc, temp, proctime] = c3_read_ble_processTimes(ble_fullpath);

[ble_path,ble_filename_wo_extension,ble_extension] = fileparts(ble_fullpath);

% get screen size
screenSize = get(0,'screensize');
% define position and size of plot windows
winXpos = round(screenSize(3)*0.05);
winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.1);
winWidth = round(screenSize(3)*0.8);
winHeight = round(screenSize(4)*0.5);
% some useful dimensions for saving images og the plot figures
paperSize = [(winWidth/72)*2.54 (winHeight/72)*2.54];
paperPosition = [0 0 (winWidth/72)*2.54 (winHeight/72)*2.54];

% maximum proctime. Will be used to set an y-axis limit, shared by all plots.
yMax = 170; % nanmax(nanmax(proctime));

% min and max x-index (serial number) to plot
idxMin = 1;
idxMax = length(serialNumber); %length(serialNumber)

%%
%--- PLOTS WITH PACKET SERIAL NUMBER ON X-AXIS ---%

% path for image files
packetsStr = sprintf('Packets %d - %d',idxMin,idxMax);
imgFiles_path = [ble_path filesep ble_filename_wo_extension '.BLE - process time - ' packetsStr ' - packet serial on X-axis'];
if ~exist(imgFiles_path,'dir')
    mkdir(imgFiles_path);
end

% plot each column of proctime in separate windows
for ii=1:size(proctime,2)
    FigTitleStr = sprintf('Process: %d      Packets: %d - %d     File: %s',ii-1,idxMin,idxMax,[ble_filename_wo_extension ble_extension]);
    hProctimeFig = figure('Numbertitle','off','Name',FigTitleStr,...
        'Units', 'pixels',...
        'Position', [winXpos winYpos winWidth winHeight],...
        'PaperUnits','centimeters',...
        'PaperSize',paperSize,...
        'PaperPosition',paperPosition,...
        'Visible','off'); %,'Visible','off'
    hAxesProctime = axes('Parent',hProctimeFig,'Position',[0.05,0.08,0.9,0.85]);
    % NOTE: missed bluetooth packets all have serial number = 0.
    % Here, (1:idxMax) is used as x-axis data.
    % Optionally, x-axis ticks could be replaced by actual serial number.
    plot(hAxesProctime,(idxMin:idxMax),proctime(idxMin:idxMax,ii),'Color','b'); % plot as line
%     stem(hAxesProctime,(idxMin:idxMax),proctime((idxMin:idxMax),ii),'Color','b','Marker','none'); % plot as stems
    hold on;
    % Plot missed packets as red dots
    if ~isempty(missedPackets)
        idxMinMissed = find(missedPackets >= idxMin,1);
        if ~isempty(idxMinMissed)
            idxMaxMissed = find(missedPackets <= idxMax,1,'last');
            plot(hAxesProctime,missedPackets(idxMinMissed:idxMaxMissed),proctime(missedPackets(idxMinMissed:idxMaxMissed),ii),'Color','r','LineStyle','none','Marker','*','MarkerSize',2);
        end
    end
    title(hAxesProctime,FigTitleStr,'FontSize',14,'FontWeight','bold');
    xlabel(hAxesProctime,'packet serial number','FontSize',10);
    ylabel(hAxesProctime,'process time (ms)','FontSize',10);
    set(hAxesProctime,'FontSize',10);
    hAxesProctime.XLim = [idxMin idxMax];
    hAxesProctime.YLim = [0 yMax]; % y-axis limits
    hAxesProctime.Box = 'on';
    grid(hAxesProctime,'on');
    hProctimeFig.Visible = 'on';
    imgTitleStr = sprintf('Process %.2d, packets %d - %d, %s',ii-1,idxMin,idxMax,[ble_filename_wo_extension ble_extension]);
    print(hProctimeFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng','-r72');
end

%%
%--- PLOTS WITH DURATION TIMESTAMPS ON X-AXIS (uncomment code below) ---%

% calculate timestamps as duration
timeStart.duration = days(0);
secondsPerDay = 24*60*60;
timeEnd.duration = days(length(serialNumber)/25/secondsPerDay);
xAxisTimeStamps.duration = linspace(timeStart.duration,timeEnd.duration,length(serialNumber));

% path for image files
packetsStr = sprintf('Packets %d - %d',idxMin,idxMax);
imgFiles_path = [ble_path filesep ble_filename_wo_extension '.BLE - process time - ' packetsStr ' - recording duration on X-axis'];
if ~exist(imgFiles_path,'dir')
    mkdir(imgFiles_path);
end

% plot each column of proctime in separate windows
for ii=1:size(proctime,2)
    FigTitleStr = sprintf('Process: %d      Packets: %d - %d     File: %s',ii-1,idxMin,idxMax,[ble_filename_wo_extension ble_extension]);
    hProctimeFig = figure('Numbertitle','off','Name',FigTitleStr,...
        'Units', 'pixels',...
        'Position', [winXpos winYpos winWidth winHeight],...
        'PaperUnits','centimeters',...
        'PaperSize',paperSize,...
        'PaperPosition',paperPosition,...
        'Visible','off'); %,'Visible','off'
    hAxesProctime = axes('Parent',hProctimeFig,'Position',[0.05,0.08,0.9,0.85]);
    plot(hAxesProctime,xAxisTimeStamps.duration(idxMin:idxMax),proctime(idxMin:idxMax,ii),'Color','b','DurationTickFormat','mm:ss.SSS');
    hold on;
    % Plot missed packets as red dots
    if ~isempty(missedPackets)
        idxMinMissed = find(missedPackets >= idxMin,1);
        if ~isempty(idxMinMissed)
            idxMaxMissed = find(missedPackets <= idxMax,1,'last');
            plot(hAxesProctime,xAxisTimeStamps.duration(missedPackets(idxMinMissed:idxMaxMissed)),proctime(missedPackets(idxMinMissed:idxMaxMissed),ii),'Color','r','LineStyle','none','Marker','*','MarkerSize',2,'DurationTickFormat','mm:ss.SSS');
        end
    end
    title(hAxesProctime,FigTitleStr,'FontSize',14,'FontWeight','bold');
    xlabel(hAxesProctime,'recording time (min:sec.millisec)','FontSize',10);
    ylabel(hAxesProctime,'process time (ms)','FontSize',10);
    set(hAxesProctime,'FontSize',10);
    hAxesProctime.YLim = [0 yMax]; % y-axis limits
    hAxesProctime.XLim = [datenum(xAxisTimeStamps.duration(idxMin)) datenum(xAxisTimeStamps.duration(idxMax))];
    grid(hAxesProctime,'on');
    %hAxesProctime.XTick = linspace(datenum(xAxisTimeStamps.duration(idxMin)), datenum(xAxisTimeStamps.duration(idxMax)),10);
    hProctimeFig.Visible = 'on';
    imgTitleStr = sprintf('Process %.2d, packets %d - %d, %s',ii-1,idxMin,idxMax,[ble_filename_wo_extension ble_extension]);
    print(hProctimeFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng','-r72');
end

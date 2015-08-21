function c3_gui()
% WORK IN PROGRESS! Needs cleanup from old code, etc.

%% Initialize variables

% create new C3 object, empty until a sensor data directory has been selected
C3 = cortrium_c3('');
dirName = '';

% Set a temporary screen resolution of 1920x1080 pixels while we construct GUI.
% Will be modified to actual screen resolution before GUI is displayed.
% Currently the GUI doesn't scale well to resolutions much smaller than
% 1920x1080.
screenWidth = 1920;
screenHeight = 1080;

panelColor = [0.9 0.9 0.9]; % color of panel background
editColor = [1.0 1.0 1.0]; % color of text edit boxes
panelBorderColor = [1.0 1.0 1.0]; % color of the line between panels
global colGreen;
global colBlue;
global colRed;
colGreen = [0.0 0.85 0.0];
colBlue = [0 0 1];
colRed = [1 0 0];

global xAxisTimeStamps;
xAxisTimeStamps.world.ECG = 0;
xAxisTimeStamps.duration.ECG = 0;
xAxisTimeStamps.world.Resp = 0;
xAxisTimeStamps.duration.Resp = 0;
xAxisTimeStamps.world.Accel = 0;
xAxisTimeStamps.duration.Accel = 0;
xAxisTimeStamps.world.Temp = 0;
xAxisTimeStamps.duration.Temp = 0;
global timeBase;
global timeStart;
timeStart.world = 0;
timeStart.duration = 0;
global timeEnd;
timeEnd.world = 0;
timeEnd.duration = 0;
global rangeStartIndex;
rangeStartIndex = 0;
global rangeEndIndex;
rangeEndIndex = 0;

% (CLEAN UP) global variable for median filtered Accel data
global data_accel_medfilt;
data_accel_medfilt = 0;
global data_accel_magnitude_medfilt;
data_accel_magnitude_medfilt = 0;

plotDefaultRangeX = 6000; % 6000 samples = one minute
plotRangeX = plotDefaultRangeX;

%% GUI

% (MATLAB R2014b+) turn off graphics smoothing on graphics root object
set(groot,'DefaultFigureGraphicsSmoothing','off')

% Create GUI window, visibility is turned off while the GUI elements are added
hFig = figure('Name','C3 sensor data',...
    'Numbertitle','off',...
    'OuterPosition', [1 1 screenWidth screenHeight],...
    'MenuBar', 'None',...
    'Toolbar','figure',...
    'Visible','off',...
    'ResizeFcn',@resizeFcn,...
    'CloseRequestFcn',@closeRequestFcn);

% create a parent panel for sub-panels in the figure window
hPanelMain = uipanel('BorderType','none',...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

%-----Panel: Load Data-----%

% create a panel for "Load Sensor Data" button
hPanelLoad = uipanel('Parent',hPanelMain,...
    'Title','Load Sensor Data',...
    'BorderType','line',... % 'BackgroundColor',editColor,...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.89 0.15 0.1],...
    'BackgroundColor',panelColor);

% Button to open dialog box, to select a folder with sensor data
uicontrol('Parent',hPanelLoad,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.1,0.9,0.8],...
    'String','Load Sensor Data',...
    'FontSize',12,...
    'Callback',@(~,~)loadButtonFcn);

%-----Panel: Directory Info-----%

% create a panel for directory (folder) info
hPanelDirInfo = uipanel('Parent',hPanelMain,...
    'Title','Directory Info',...
    'BorderType','line',... % 'BackgroundColor',editColor,...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.77 0.15 0.11],...
    'BackgroundColor',panelColor);

% Text, directory info
hTextDirInfo = uicontrol('Parent',hPanelDirInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.05,0.9,0.85],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

%-----Panel: Navigate Sensor Data-----%

% create a panel for buttons to navigate the data
hPanelNavigateData = uipanel('Parent',hPanelMain,...
    'Title','Navigate Sensor Data',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.4 0.15 0.36],...
    'BackgroundColor',panelColor);

% Button, Reset Range
uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.85,0.9,0.12],...
    'String','Reset Range',...
    'FontSize',12,...
    'Callback',@ResetRangeFcn);

% Text label, Start
uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.73,0.16,0.07],...
    'HorizontalAlignment','left',...
    'String','Start:',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% Text label, End
uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.65,0.16,0.07],...
    'HorizontalAlignment','left',...
    'String','End:',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% % Text label, range start time
% uicontrol('Parent',hPanelNavigateData,...
%     'Style','text',...
%     'Units','normalized',...
%     'Position',[0.2,0.68,0.75,0.05],...
%     'HorizontalAlignment','right',...
%     'String','yyyy-mm-dd HH:MM:SS',...
%     'FontSize',8,...
%     'ForegroundColor',editColor*0.5,...
%     'BackgroundColor',panelColor);
%
% % Text label, range end time
% uicontrol('Parent',hPanelNavigateData,...
%     'Style','text',...
%     'Units','normalized',...
%     'Position',[0.2,0.55,0.75,0.05],...
%     'HorizontalAlignment','right',...
%     'String','yyyy-mm-dd HH:MM:SS',...
%     'FontSize',8,...
%     'ForegroundColor',editColor*0.5,...
%     'BackgroundColor',panelColor);

% Text, display range start time
hEditStartTime = uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.21,0.73,0.74,0.07],...
    'HorizontalAlignment','left',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% Text, display range end time
hEditEndTime = uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.21,0.65,0.74,0.07],...
    'HorizontalAlignment','left',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

hRangeSlider = uicontrol('Parent',hPanelNavigateData,...
    'Style','slider',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.55,0.9,0.08],...
    'Min',0,'Max',20000,...
    'Value',plotRangeX,...
    'SliderStep',[0.005 0.05],...
    'BackgroundColor',panelColor,...
    'Callback',@rangeSliderFcn);

% Button, First 1 Second
hFirst1SecButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.4,0.42,0.08],...
    'String','First 1 sec',...
    'FontSize',10);
%'Callback',@First1SecFcn);

% Button, First 10 Seconds
hFirst10SecButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.4,0.42,0.08],...
    'String','First 10 sec',...
    'FontSize',10);
%'Callback',@First10SecFcn);

% Radio buttons group, duration-based time vs. world time
hTimebaseButtonGroup = uibuttongroup('Parent',hPanelNavigateData,...
    'Units','normalized',...
    'Position',[0.05,0.05,0.9,0.12],...
    'BackgroundColor',panelColor,...
    'Title','Time base',...
    'SelectionChangedFcn',@timebaseSelectionFcn);

% Radio button, zero based time
hTimeButton1 = uicontrol(hTimebaseButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Duration',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, world based time
hTimeButton2 = uicontrol(hTimebaseButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','World',...
    'Units','normalized',...
    'Position',[0.53,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hTimebaseButtonGroup,'selectedobject',hTimeButton2);
timeBase = get(get(hTimebaseButtonGroup,'selectedobject'),'String');

%-----Panel: Filter Sensor Data-----%

% create a panel for buttons to navigate and export features from the data
hPanelFilterData = uipanel('Parent',hPanelMain,...
    'Title','Filter Sensor Data',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.38],...
    'BackgroundColor',panelColor);

%-----Panel: Sensor Samples Display-----%

% create a panel for data visualization
hPanelSensorDisplay = uipanel('Parent',hPanelMain,...
    'Title','Sensor Data Display',...
    'BorderType','line',...
    'HighlightColor',panelBorderColor,...
    'Position',[0.01 0.01 0.82 0.98],...
    'BackgroundColor',panelColor);

% Text label, for ECG plot
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.2,0.965,0.6,0.025],...
    'HorizontalAlignment','center',...
    'String','ECG',...
    'FontWeight','bold',...
    'FontSize',12,...
    'BackgroundColor',panelColor);

% Axes object for ECG plot
hAxesECG = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.79,0.9,0.175]);
%xlim('manual');
%ylim('manual');
% set(gca, 'YLimMode', 'manual');
%xlim(hAxesECG,[minXsensorData,maxXsensorData]);
%ylim(hAxesECG,[minYsensorData,maxYsensorData]);
hold on;

% Button, Create ECG plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.945,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback',@ecgWinFunc);

% Button, toggles ECG_1 plot
hECG1Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.92,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@ecgPlotFunc);

% Text label, for ECG_1 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.92,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','ECG_1',...
    'FontWeight','normal',...
    'ForegroundColor',[1.0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles ECG_2 plot
hECG2Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.899,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@ecgPlotFunc);

% Text label, for ECG_2 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.899,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','ECG_2',...
    'FontWeight','normal',...
    'ForegroundColor',colGreen,...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles ECG_3 plot
hECG3Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.878,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@ecgPlotFunc);

% Text label, for ECG_3 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.878,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','ECG_3',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 1.0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for Respiration plot (impedance)
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.2,0.71,0.6,0.025],...
    'HorizontalAlignment','center',...
    'String','Respiration',...
    'FontWeight','bold',...
    'FontSize',12,...
    'BackgroundColor',panelColor);

% Axes object for Respiration plot (impedance)
hAxesResp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.535,0.9,0.175]);
% xlim('manual');
% ylim('manual');
% set(gca, 'YLimMode', 'manual');
% xlim(hAxesResp,[minXsensorData,maxXsensorData]);
% ylim(hAxesResp,[minYsensorData,maxYsensorData]);
hold on;

% Button, Create Respiration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.69,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @respWinFunc);

% Text label, for Acceleration plot
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.2,0.455,0.6,0.025],...
    'HorizontalAlignment','center',...
    'String','Acceleration',...
    'FontWeight','bold',...
    'FontSize',12,...
    'BackgroundColor',panelColor);

% Axes object for Acceleration plot
hAxesAccel = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.28,0.9,0.175]);
% xlim('manual');
% ylim('manual');
% xlim(hAxesAccel,[minXhr,maxXhr]);
% ylim(hAxesAccel,[minYhr,maxYhr]);
hold on;

% Button, Create Acceleration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.435,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @accelWinFunc);

% Button, toggles Accel_X plot
hAccelXCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.41,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_X toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.41,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Accel_X',...
    'FontWeight','normal',...
    'ForegroundColor',[1.0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Accel_Y plot
hAccelYCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.389,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_Y toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.389,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Accel_Y',...
    'FontWeight','normal',...
    'ForegroundColor',colGreen,...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Accel_Z plot
hAccelZCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.368,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_Z toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.368,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Accel_Z',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 1.0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Accel_magnitude plot
hAccelMagnitudeCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.347,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_magnitude toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.347,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','magnitude',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Accel median filtered plot
hAccelMedfiltCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.326,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel median filtered toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.326,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Medfilt',...
    'FontWeight','normal',...
    'ForegroundColor',[0.4 0.4 0.4],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for Temperature plot
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.2,0.215,0.6,0.025],...
    'HorizontalAlignment','center',...
    'String','Temperature',...
    'FontWeight','bold',...
    'FontSize',12,...
    'BackgroundColor',panelColor);

% Axes object for Temperature plot
hAxesTemp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.04,0.9,0.175]);
% xlim('manual');
% ylim('manual');
% xlim(hAxesTemp,[minXhr,maxXhr]);
% ylim(hAxesTemp,[minYhr,maxYhr]);
hold on;

% Button, Create Temperature plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.195,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @tempWinFunc);

% Button, toggles Temperature_1 plot
hTemp1Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.17,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@tempPlotFunc);

% Text label, for Temperature_1 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.17,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Device',...
    'FontWeight','normal',...
    'ForegroundColor',[1.0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Temperature_2 plot
hTemp2Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.149,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@tempPlotFunc);

% Text label, for Temperature_2 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.149,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Surface',...
    'FontWeight','normal',...
    'ForegroundColor',colGreen,...
    'FontSize',8,...
    'BackgroundColor',panelColor);

%% get actual screen size and set figure window accordingly

% get screen size
screenSize = get(0,'screensize');
screenWidth = screenSize(3);
screenHeight = screenSize(4);
set(hFig,'OuterPosition', [1 1 screenWidth screenHeight]);

%% Make the GUI visible

set(hFig,'Visible','on');
grid(hAxesECG,'on');
grid(hAxesResp,'on');
grid(hAxesAccel,'on');
grid(hAxesTemp,'on');

%% Functions (inline)

    function loadButtonFcn()
        dirName = uigetdir();
        if dirName % if a directory was selected
            % resetting axes so that any zooming is reset before displaying the new data
            set([hAxesECG hAxesResp hAxesAccel hAxesTemp],'xlim',[0 1]);
            set([hAxesECG hAxesResp hAxesAccel hAxesTemp],'ylim',[0 1]);
            axis([hAxesECG hAxesResp hAxesAccel hAxesTemp],'auto');
            updateDirectoryInfo;
            loadAndFormatData;
            calcTimeStamps(C3);
            setRange(C3,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
            plotSensorData;
        end
    end

    function loadAndFormatData()
        % Create a new C3 object
        C3 = cortrium_c3(dirName);
        
        % Initialise components and load data
        C3.initialize;
        
        % Clean accelerometer and temperature data for jitter
        C3.clean_sensor_data;
        
        % Smoothen respiration data
        if ~isempty(C3.resp)
            C3.resp.smoothen;
        end
        
        %plot(xData_25hz, sqrt(sum(C3.accel.data.^2,2))) %magnitude
        
        % median filtering of Accel data
        data_accel_medfilt = medfilt1(C3.accel.data,C3.accel.fs); % remove impulse noise
        
        % calculating Accel magnitude
        C3.accel.magnitude = sqrt(sum(C3.accel.data.^2,2));
        
        % median filtering of Accel magnitude
        data_accel_magnitude_medfilt = medfilt1(C3.accel.magnitude,C3.accel.fs);
    end

    function plotSensorData()
        linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'off');
        plotECG(C3,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox)
        if ~isempty(C3.resp)
            plotResp(C3,hAxesResp);
        end
        plotAccel(C3,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox);
        plotTemp(C3,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
        linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'x');
    end

    function ResetRangeFcn(varargin)
        
    end

    function rangeSliderFcn(varargin)
        
    end

    function timebaseSelectionFcn(varargin)
        % For now we just plot the data again, and let the plot functions
        % ask for the x-axis data. Would be more optimal to just replace
        % x-axis ticks.
        timeBase = get(get(hTimebaseButtonGroup,'selectedobject'),'String');
        %if the C3 object is not empty
        if ~isempty(C3.date_start)
            if strcmp(timeBase,'World')
                rangeStartIndex = timeStart.world;
                rangeEndIndex = timeEnd.world;
            else
                rangeStartIndex = timeStart.duration;
                rangeEndIndex = timeEnd.duration;
            end
            setRange(C3,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
            plotSensorData;
        end
    end

    function updateDirectoryInfo()
        dirNameParts = strsplit(dirName,filesep);
        set(hTextDirInfo,'String',strcat('..', filesep, dirNameParts(length(dirNameParts)-2), filesep, dirNameParts(length(dirNameParts)-1), filesep, dirNameParts(length(dirNameParts))));
    end

%% Functions for updating plots, based on checkbox selections
% (CLEAN UP) The callback from the buttons should be modified so they call
% the plot functions directly - not using this intermediate function.

    function ecgPlotFunc(varargin)
        plotECG(C3,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox);
    end

    function accelPlotFunc(varargin)
        %display(varargin);
        plotAccel(C3,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox);
    end

    function tempPlotFunc(varargin)
        %         yLimits = get(hAxesTemp,'YLim');
        %         xLimits = get(hAxesTemp,'XLim');
        %         fprintf('ylimits %f  %f\n', yLimits(1), yLimits(2));
        %         fprintf('xlimits %f  %f\n', xLimits(1), xLimits(2));
        plotTemp(C3,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
    end

%% Functions for creating separate, floating plot windows

    function ecgWinFunc(varargin)
        %--- creates a new, floating window for the ECG plot ---%
        xAxisTimeStamp = getTimeStamps('ECG');
        plotOptions = getPlotOptions;
        hECGFig = figure('Numbertitle','off','Name','ECG');
        hAxesECGWindow = axes;
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,1),'Color','r',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_1'};
            end
            if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,2),'Color','g',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_2'};
            end
            if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,3),'Color','b',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_3'};
            end
        else
            if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_1'};
            end
            if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_2'};
            end
            if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
                plot(hAxesECGWindow,xAxisTimeStamp,C3.ecg.data(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_3'};
            end
        end
        title('ECG','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',12);
        ylabel('sample value','FontSize',12);
        legend(hAxesECGWindow,legendList,'Location','northoutside','Orientation','horizontal');
        set(hAxesECGWindow,'FontSize',11);
    end

    function respWinFunc(varargin)
        %--- creates a new, floating window for the ECG plot ---%
        xAxisTimeStamp = getTimeStamps('Resp');
        plotOptions = getPlotOptions;
        hRespFig = figure('Numbertitle','off','Name','Respiration');
        hAxesRespWindow = axes;
        hold on;
        if strcmp(timeBase,'World')
            plot(hAxesRespWindow,xAxisTimeStamp,C3.resp.data,'Color','r',plotOptions);
        else
            plot(hAxesRespWindow,xAxisTimeStamp,C3.resp.data,'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
        end
        title('Respiration','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',12);
        ylabel('sample value','FontSize',12);
        legend(hAxesRespWindow,'Respiration','Location','northoutside','Orientation','horizontal');
        set(hAxesRespWindow,'FontSize',11);
    end

    function accelWinFunc(varargin)
        %--- creates a new, floating window for the Acceleration plot ---%
        xAxisTimeStamp = getTimeStamps('Accel');
        plotOptions = getPlotOptions;
        hAccelFig = figure('Numbertitle','off','Name','Acceleration');
        hAxesAccelWindow = axes;
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,1),'Color','r',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,1),'Color','r',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,2),'Color','g',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,2),'Color','g',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,3),'Color','b',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,3),'Color','b',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_magnitude_medfilt,'Color','k',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.magnitude,'Color','k',plotOptions);
                end
                legendList(length(legendList)+1) = {'magnitude'};
            end
        else
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_medfilt(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.data(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp,data_accel_magnitude_medfilt,'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp,C3.accel.magnitude,'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'magnitude'};
            end
        end
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON, include 'median filtered' in title
            title('Acceleration, median filtered','FontSize',12,'FontWeight','bold');
        else
            title('Acceleration','FontSize',12,'FontWeight','bold');
        end
        xlabel(['time (' timeBase ')'],'FontSize',12);
        ylabel('sample value','FontSize',12);
        legend(hAxesAccelWindow,legendList,'Location','northoutside','Orientation','horizontal');
        set(hAxesAccelWindow,'FontSize',11);
    end

    function tempWinFunc(varargin)
        %--- creates a new, floating window for the Temperature plot ---%
        xAxisTimeStamp = getTimeStamps('Temp');
        plotOptions = getPlotOptions;
        hTempFig = figure('Numbertitle','off','Name','Temperature');
        hAxesTempWindow = axes;
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp,C3.temp.data(:,1),'Color','r',plotOptions);
                legendList(length(legendList)+1) = {'Device'};
            end
            if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp,C3.temp.data(:,2),'Color','g',plotOptions);
                legendList(length(legendList)+1) = {'Surface'};
            end
        else
            if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp,C3.temp.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Device'};
            end
            if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp,C3.temp.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Surface'};
            end
        end
        title('Temperature','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',12);
        ylabel('sample value','FontSize',12);
        legend(hAxesTempWindow,legendList,'Location','northoutside','Orientation','horizontal');
        set(hAxesTempWindow,'FontSize',11);
    end

    function resizeFcn(varargin)
        % Is called when the GUI window is created, and when resized.
        % Might be used later to implement changing font size depending on
        % GUI window size, since all other elements are relatively sized.
        currFigPos = get(hFig,'Position');
        figWidth = currFigPos(3);
        figHeight = currFigPos(4);
        %disp(['Figure pos: ' num2str(currFigPos(1)) ' ' num2str(currFigPos(2)) ' ' num2str(figWidth) ' ' num2str(figHeight)]);
    end

    function closeRequestFcn(varargin)
        fclose all;
        closereq; % Close the GUI Window
    end
end

%% Functions (Work in progress... starting to move inline functions outside of main function.)

function plotECG(C3,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox)
global colRed;
global colGreen;
global colBlue;
global timeBase;
xAxisTimeStamp = getTimeStamps('ECG');
plotOptions = getPlotOptions;
% clear the plot, then create new plot
cla(hAxesECG);
if strcmp(timeBase,'World')
    if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,1),'Color','r',plotOptions);
    end
    if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,2),'Color','g',plotOptions);
    end
    if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,3),'Color','b',plotOptions);
    end
else
    if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
    end
    if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
    end
    if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
        plot(hAxesECG,xAxisTimeStamp,C3.ecg.data(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
    end
end
%     xlim('manual');
%     xlim(hAxesECG,[0.000012,0.000116]);
end

function plotResp(C3,hAxesResp)
global timeBase;
xAxisTimeStamp = getTimeStamps('Resp');
plotOptions = getPlotOptions;
cla(hAxesResp);
if strcmp(timeBase,'World')
    plot(hAxesResp,xAxisTimeStamp,C3.resp.data,'Color','r',plotOptions);
else
    plot(hAxesResp,xAxisTimeStamp,C3.resp.data,'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
end
%     xlim('manual');
%     xlim(hAxesECG,[0.000012,0.000116]);

end

function plotAccel(C3,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox)
global data_accel_medfilt;
global data_accel_magnitude_medfilt;
global timeBase;
xAxisTimeStamp = getTimeStamps('Accel');
plotOptions = getPlotOptions;
cla(hAxesAccel);
if strcmp(timeBase,'World')
    if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,1),'Color','r',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,1),'Color','r',plotOptions);
        end
    end
    if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,2),'Color','g',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,2),'Color','g',plotOptions);
        end
    end
    if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,3),'Color','b',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,3),'Color','b',plotOptions);
        end
    end
    if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_magnitude_medfilt,'Color','k',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.magnitude,'Color','k',plotOptions);
        end
    end
else
    if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
        end
    end
    if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
        end
    end
    if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_medfilt(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.data(:,3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
        end
    end
    if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp,data_accel_magnitude_medfilt,'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp,C3.accel.magnitude,'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
        end
    end
end
%     xlim('manual');
%     xlim(hAxesAccel,[0.000012,0.000116]);
end

function plotTemp(C3,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox)
global colRed;
global colGreen;
global colBlue;
global timeBase;
xAxisTimeStamp = getTimeStamps('Temp');
plotOptions = getPlotOptions;
cla(hAxesTemp);
if strcmp(timeBase,'World')
    if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
        plot(hAxesTemp,xAxisTimeStamp,C3.temp.data(:,1),'Color','r',plotOptions);
    end
    if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_2 is ON
        plot(hAxesTemp,xAxisTimeStamp,C3.temp.data(:,2),'Color','g',plotOptions);
    end
else
    if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
        plot(hAxesTemp,xAxisTimeStamp,C3.temp.data(:,1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
    end
    if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_2 is ON
        plot(hAxesTemp,xAxisTimeStamp,C3.temp.data(:,2),'Color','g','DurationTickFormat','hh:mm:ss',plotOptions);
    end
end
xlabel(hAxesTemp,['time (' timeBase ')'],'FontSize',10);
%display(get(hAxesTemp,'XTick'));
%     xlim('manual');
%     xlim(hAxesTemp,[0.000012,0.000116]);
end

function calcTimeStamps(C3)
global xAxisTimeStamps;
global timeBase;
global timeStart;
global timeEnd;
global rangeStartIndex;
global rangeEndIndex;

timeStart.world = datetime(C3.date_start, 'ConvertFrom', 'datenum');
timeEnd.world = datetime(C3.date_end, 'ConvertFrom', 'datenum');

deltaTime = timeEnd.world - timeStart.world;
timeStart.duration = days(0);
timeEnd.duration = days(deltaTime);

% creating ECG timestamps, world and duration-based
xAxisTimeStamps.world.ECG = linspace(timeStart.world,timeEnd.world,C3.ecg.samplenum);
xAxisTimeStamps.duration.ECG = linspace(timeStart.duration,timeEnd.duration,C3.ecg.samplenum);

% creating Resp timestamps, world and duration-based
if ~isempty(C3.resp)
    xAxisTimeStamps.world.Resp = linspace(timeStart.world,timeEnd.world,C3.resp.samplenum);
    xAxisTimeStamps.duration.Resp = linspace(timeStart.duration,timeEnd.duration,C3.resp.samplenum);
end
% creating Accel timestamps, world and duration-based
xAxisTimeStamps.world.Accel = linspace(timeStart.world,timeEnd.world,C3.accel.samplenum);
xAxisTimeStamps.duration.Accel = linspace(timeStart.duration,timeEnd.duration,C3.accel.samplenum);

% creating Temp timestamps, world and duration-based
xAxisTimeStamps.world.Temp = linspace(timeStart.world,timeEnd.world,length(C3.temp.data));
xAxisTimeStamps.duration.Temp = linspace(timeStart.duration,timeEnd.duration,length(C3.temp.data));

if strcmp(timeBase,'World')
    rangeStartIndex = timeStart.world;
    rangeEndIndex = timeEnd.world;
else
    rangeStartIndex = timeStart.duration;
    rangeEndIndex = timeEnd.duration;
end
end

function xAxisTimeStamp = getTimeStamps(signalName)
global xAxisTimeStamps;
global timeBase;
if strcmp(timeBase,'World')
    if strcmp(signalName,'ECG')
        xAxisTimeStamp = xAxisTimeStamps.world.ECG;
    elseif strcmp(signalName,'Resp')
        xAxisTimeStamp = xAxisTimeStamps.world.Resp;
    elseif strcmp(signalName,'Accel')
        xAxisTimeStamp = xAxisTimeStamps.world.Accel;
    elseif strcmp(signalName,'Temp')
        xAxisTimeStamp = xAxisTimeStamps.world.Temp;
    end
else
    if strcmp(signalName,'ECG')
        xAxisTimeStamp = xAxisTimeStamps.duration.ECG;
    elseif strcmp(signalName,'Resp')
        xAxisTimeStamp = xAxisTimeStamps.duration.Resp;
    elseif strcmp(signalName,'Accel')
        xAxisTimeStamp = xAxisTimeStamps.duration.Accel;
    elseif strcmp(signalName,'Temp')
        xAxisTimeStamp = xAxisTimeStamps.duration.Temp;
    end
end
end

function setRangeIndices(startTime,endTime)
% this function finds the index numbers that correspond to datetime numbers (x-axis)
global xAxisTimeStamps;
global timeBase;
global rangeStartIndex;
global rangeEndIndex;

end

function setRange(C3,startTime,endTime,hEditStartTime,hEditEndTime)
global timeBase;
if strcmp(timeBase,'World')
    set(hEditStartTime,'String',datestr(startTime, 'yyyy-mm-dd  HH:MM:SS'));
    set(hEditEndTime,'String',datestr(endTime, 'yyyy-mm-dd  HH:MM:SS'));
else
    [h,m,s] = hms([startTime endTime]);
    set(hEditStartTime,'String',sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))));
    set(hEditEndTime,'String',sprintf('%02i:%02i:%02i',h(2),m(2),round(s(2))));
end
end

function plotOptions = getPlotOptions()
global timeBase;
if strcmp(timeBase,'World')
    plotOptions.LineWidth = 1;
else
    plotOptions.LineWidth = 1;
    %plotOptions.DurationTickFormat = 'hh:mm:ss'; % NO GO
end
end
function c3_gui()
% WORK IN PROGRESS! Needs cleanup from old code, etc.

%% Initialize variables
hTic_buildingGUI = tic;
% create new C3 object, empty until a sensor data directory has been selected
C3 = cortrium_c3('');
dirName = '';
folderName = '';
sourceFileName = '';

% Set a temporary screen resolution of 1920x1080 pixels while we construct GUI.
% Will be modified to actual screen resolution before GUI is displayed.
% Currently the GUI doesn't scale well to resolutions much smaller than
% 1920x1080.
screenWidth = 1920;
screenHeight = 1080;

panelColor = [0.9 0.9 0.9]; % color of panel background
whiteTransp = [1.0 1.0 1.0 0.0];
editColor = [1.0 1.0 1.0]; % color of text edit boxes
panelBorderColor = [1.0 1.0 1.0]; % color of the line between panels
colGreen = [0.0 0.85 0.0];

rangeStartIndex.ECG = 0;
rangeEndIndex.ECG = 0;
rangeStartIndex.Resp = 0;
rangeEndIndex.Resp = 0;
rangeStartIndex.Accel = 0;
rangeEndIndex.Accel = 0;
rangeStartIndex.Temp = 0;
rangeEndIndex.Temp = 0;

timeStart.world = 0;
timeStart.duration = 0;
timeEnd.world = [];
timeEnd.duration = [];

xAxisTimeStamps.world.ECG = 0;
xAxisTimeStamps.duration.ECG = 0;
xAxisTimeStamps.world.Resp = 0;
xAxisTimeStamps.duration.Resp = 0;
xAxisTimeStamps.world.Accel = 0;
xAxisTimeStamps.duration.Accel = 0;
xAxisTimeStamps.world.Temp = 0;
xAxisTimeStamps.duration.Temp = 0;

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
    'Position',[0.84 0.34 0.15 0.42],...
    'BackgroundColor',panelColor);

% Button, Reset Range
hResetButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.88,0.9,0.10],...
    'String','Reset Range',...
    'FontSize',12,...
    'Callback',@rangeButtonFcn);

% Popup menu, for selecting a range (how many samples are plotted)
hPopupRange = uicontrol('Parent',hPanelNavigateData,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.79,0.415,0.07],...
    'String', {'1 sec','2 sec','5 sec','10 sec','30 sec','1 min'},...
    'FontSize',10);
hPopupRange.Value = 4;

% Button, Set the range chosen in the popup menu next to this button
hRangeButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.795,0.42,0.07],... %[0.21,0.74,0.74,0.07]
    'String','Set Range',...
    'FontSize',10,...
    'Callback',@rangeButtonFcn);

hRangeSlider = uicontrol('Parent',hPanelNavigateData,...
    'Style','slider',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.67,0.9,0.055],...
    'Min',1,'Max',1000,...
    'Value',500,...
    'SliderStep',[0.1 1],...
    'BackgroundColor',panelColor,...
    'Callback',@rangeSliderFcn);

% Button, Navigate left
hNavLeftButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.58,0.42,0.07],...
    'String','<',...
    'FontSize',10,...
    'Callback',@navLeftButtonFcn);

% Button, Navigate right
hNavRightButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.58,0.42,0.07],...
    'String','>',...
    'FontSize',10,...
    'Callback',@navRightButtonFcn);

% Button, Navigate Event left
hNavEventLeftButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.44,0.42,0.07],...
    'String','< Event',...
    'FontSize',10,...
    'FontWeight','bold',...
    'Callback',@navEventLeftButtonFcn);

% Button, Navigate Event right
hNavEventRightButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.44,0.42,0.07],...
    'String','Event >',...
    'FontSize',10,...
    'FontWeight','bold',...
    'Callback',@navEventRightButtonFcn);

% Popup menu, for selecting an event to navigate to
hPopupEvent = uicontrol('Parent',hPanelNavigateData,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.055,0.355,0.89,0.07],...
    'String', {'Select event for navigation:',...
    'ECG Error Code (any error)',...
    'ECG Sample max value (ecg = 32767)',...
    'ECG Sample min value (ecg = -32765)',...
    'ECG Filter error (ecg = -32766)',...
    'ECG Lead off (ecg = -32767)',...
    'ECG Comm error (ecg = -32768)',...
    'ECG abs(ecg) >= 5000 & < 10000',...
    'ECG abs(ecg) >= 10000 & < 20000',...
    'ECG abs(ecg) >= 20000 & < 32765'},...
    'FontSize',10);
hPopupEvent.Value = 1;

% Text label, Start
uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.23,0.16,0.07],...
    'HorizontalAlignment','left',...
    'String','Start:',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% Text label, End
uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.165,0.16,0.07],...
    'HorizontalAlignment','left',...
    'String','End:',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

%[0.53,0.21,0.42,0.08]
% Text, display range start time
hEditStartTime = uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.21,0.23,0.74,0.07],...
    'HorizontalAlignment','left',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% Text, display range end time
hEditEndTime = uicontrol('Parent',hPanelNavigateData,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.21,0.165,0.74,0.07],...
    'HorizontalAlignment','left',...
    'FontSize',10,...
    'BackgroundColor',panelColor);

% Radio buttons group, duration-based time vs. world time
hTimebaseButtonGroup = uibuttongroup('Parent',hPanelNavigateData,...
    'Units','normalized',...
    'Position',[0.05,0.03,0.9,0.12],...
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
timeBase = getTimeBase(hTimebaseButtonGroup);

%-----Panel: Filter Sensor Data-----%

% create a panel for buttons to navigate and export features from the data
hPanelFilterData = uipanel('Parent',hPanelMain,...
    'Title','Filter Sensor Data',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.32],...
    'BackgroundColor',panelColor);

%-----Panel: Sensor Samples Display-----%

% create a panel for data visualization
hPanelSensorDisplay = uipanel('Parent',hPanelMain,...
    'Title','Sensor Data Display',...
    'BorderType','line',...
    'HighlightColor',panelBorderColor,...
    'Position',[0.01 0.01 0.82 0.98],...
    'BackgroundColor',panelColor);

% Axes object for ECG plot
hAxesECG = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.79,0.9,0.185]);
xlim(hAxesECG,'manual');
%ylim(hAxesECG,'manual');
hold(hAxesECG,'on');
set(hAxesECG,'ButtonDownFcn',@onClickAxes);

% Axes for Text overlay on ECG plot
hAxesECGText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.9525,0.025,0.0175], 'Visible', 'off');
hTxtECG = text(0.992, 0.98, 'ECG', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesECGText);
hTxtECG.BackgroundColor = whiteTransp;

% Button, Create ECG plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.95,0.015,0.022],...
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

% Button, toggles ECG_leadoff plot
hECGleadoffCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.857,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@ecgPlotFunc);

% Text label, for ECG_leadoff toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.857,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Lead off',...
    'FontWeight','normal',...
    'ForegroundColor',[0.5 0.5 0.5],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Axes object for Respiration plot (impedance)
hAxesResp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.535,0.9,0.185]);
xlim(hAxesResp,'manual');
% ylim(hAxesResp,'manual');
hold(hAxesResp,'on');
set(hAxesResp,'ButtonDownFcn',@onClickAxes);

% Axes for Text overlay on Resp plot
hAxesRespText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.6975,0.025,0.0175], 'Visible', 'off');
hTxtResp = text(0.992, 0.98, 'Resp', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesRespText);
hTxtResp.BackgroundColor = whiteTransp;

% Button, Create Respiration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.695,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @respWinFunc);

% Axes object for Acceleration plot
hAxesAccel = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.28,0.9,0.185]);
xlim(hAxesAccel,'manual');
% ylim(hAxesAccel,'manual');
hold(hAxesAccel,'on');
set(hAxesAccel,'ButtonDownFcn',@onClickAxes);

% Axes for Text overlay on Accel plot
hAxesAccelText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.4425,0.025,0.0175], 'Visible', 'off');
hTxtAccel = text(0.992, 0.98, 'Accel', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesAccelText);
hTxtAccel.BackgroundColor = whiteTransp;

% Button, Create Acceleration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.44,0.015,0.022],...
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

% Axes object for Temperature plot
hAxesTemp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.04,0.9,0.185]);
xlim(hAxesTemp,'manual');
% ylim(hAxesTemp,'manual');
hold(hAxesTemp,'on');
set(hAxesTemp,'ButtonDownFcn',@onClickAxes);

% Axes for Text overlay on Temp plot
hAxesTempText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.2025,0.025,0.0175], 'Visible', 'off');
hTxtTemp = text(0.992, 0.98, 'Temp', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesTempText);
hTxtTemp.BackgroundColor = whiteTransp;

% dummy axes, bug fix for Temp Axes text disappearing when plotting
axes('Parent', hPanelSensorDisplay, 'Position', [0.001,0.001,0.01,0.01], 'Visible', 'off');

% Button, Create Temperature plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.2,0.015,0.022],...
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
% linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'x');
grid(hAxesECG,'on');
grid(hAxesResp,'on');
grid(hAxesAccel,'on');
grid(hAxesTemp,'on');
set(hFig,'Visible','on');
fprintf('buildingGUI: %f seconds\n',toc(hTic_buildingGUI));

%% Functions (inline)

    function loadButtonFcn()
        dirName = uigetdir();
        if dirName % if a directory was selected
            % resetting end times
            timeEnd.world = [];
            timeEnd.duration = [];
            % clear axes before displaying new data
            cla([hAxesECG hAxesResp hAxesAccel hAxesTemp]);
            loadAndFormatData;
            folderName = updateDirectoryInfo;
            timeBase = getTimeBase(hTimebaseButtonGroup);
            [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd);
            [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hNavLeftButton,hNavRightButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
            outputRecordingStats;
            plotSensorData;
            enableButtons(hPopupRange,hRangeButton);
        end
    end

    function loadAndFormatData()
        hTic_loadAndFormatData = tic;
        % Create a new C3 object
        C3 = cortrium_c3(dirName);
        
        % Is a .BLE file or a set of .bin files file present in this directory
        listBLE = dir([dirName '\*.BLE']);
        listBin = dir([dirName '\*.bin']);
        if size(listBLE,1) == 1
            hTic_readBLE = tic;
            % Initialise components
            C3.initializeForBLE;
            % load and assign data from .BLE files
            [C3.serialNumber, C3.leadoff, C3.accel.data, C3.temp.data, C3.resp.data, C3.ecg.data] = c3_read_ble(fullfile(dirName,listBLE(1).name));
            C3.accel.samplenum = length(C3.accel.data);
            C3.temp.samplenum = length(C3.temp.data);
            C3.resp.samplenum = length(C3.resp.data);
            C3.ecg.samplenum = length(C3.ecg.data);
            [~,ble_filename_wo_extension,~] = fileparts(listBLE(1).name);
            sourceFileName = listBLE(1).name;
            C3.date_start = datenum(datetime(hex2dec(ble_filename_wo_extension), 'ConvertFrom', 'posixtime', 'TimeZone', 'Europe/Zurich'));
            C3.date_end = addtodate(C3.date_start, C3.ecg.samplenum*1000/C3.ecg.fs, 'millisecond');
            
            C3.missingSerials = setdiff(1:max(C3.serialNumber),C3.serialNumber)';
            fprintf('Read BLE file: %f seconds\n',toc(hTic_readBLE));
        elseif size(listBin,1) > 1
            % Initialise components and load data from .bin files
            C3.initialize;
            C3.leadoff = zeros(1, C3.temp.samplenum);
            sourceFileName = '*.bin';
        end
        
        % Prepare lead-off for GUI view
        C3.ecg.leadoff = double(C3.leadoff);
        C3.ecg.leadoff(C3.ecg.leadoff == 0) = NaN;
        C3.ecg.leadoff = (C3.ecg.leadoff-10000);
        % "upsample" to match ecg signal with 10 ecg samples per packet
        C3.ecg.leadoff = reshape(repmat(C3.ecg.leadoff', 10, 1), [], 1);
        
        % Clean accelerometer and temperature data for jitter
        C3.clean_sensor_data;
        
        %         fprintf('\n');
        %         fprintf('ECG samplenum: %d\n',C3.ecg.samplenum);
        %         fprintf('Resp samplenum: %d\n',C3.resp.samplenum);
        %         fprintf('Accel samplenum: %d\n',C3.accel.samplenum);
        %         fprintf('Temp samplenum: %d\n',C3.temp.samplenum);
        %         fprintf('\n');
        
        if (C3.ecg.samplenum ~= C3.accel.samplenum*10) && (C3.accel.samplenum == C3.temp.samplenum)
            warndlg(sprintf('Sample count mismatch!\nECG and Resp should be x10 the sample count of Accel and Temp.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
        elseif (C3.accel.samplenum ~= C3.temp.samplenum) && (C3.ecg.samplenum == C3.accel.samplenum*10)
            warndlg(sprintf('Sample count mismatch!\nAccel and Temp sample count should be identical.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
        elseif (C3.accel.samplenum ~= C3.temp.samplenum) && (C3.ecg.samplenum ~= C3.accel.samplenum*10)
            warndlg(sprintf('Sample count mismatch!\nECG and Resp should be x10 the sample count of Accel and Temp,\nand Accel and Temp sample count should be identical.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
        end
        
        % Smoothen respiration data
        if ~isempty(C3.resp)
            C3.resp.smoothen;
        end
        if isempty(C3.resp.data)
            % fill in 'NaN' if there was no Respiration data
            C3.resp.data(1:C3.ecg.samplenum,1) = NaN;
            C3.resp.samplenum = C3.ecg.samplenum;
            C3.resp.fs = C3.ecg.fs;
        end
        
        % median filtering of Accel data
        C3.accel.dataFiltered = medfilt1(C3.accel.data,C3.accel.fs); % remove impulse noise
        
        % calculating Accel magnitude
        C3.accel.magnitude = sqrt(sum(C3.accel.data.^2,2));
        
        % median filtering of Accel magnitude
        C3.accel.magnitudeFiltered = medfilt1(C3.accel.magnitude,C3.accel.fs);
        fprintf('loadAndFormatData: %f seconds\n',toc(hTic_loadAndFormatData));
    end

    function outputRecordingStats()
        fprintf('==========================================================\n');
        fprintf('== Recording stats                                      ==\n');
        fprintf('==========================================================\n');
        fprintf('Filename: %s\n', cell2mat(folderName)); 
        fprintf('Device ID: %s\n', 'Unknown');
        fprintf('Recording duration: %s\n', 'Unknown');
        fprintf('Recording start: %s\n', 'Unknown');
        fprintf('Recording end: %s\n', 'Unknown');
        fprintf('==========================================================\n');
        fprintf('Total packets (max serial): %i Missing packets: %i\n', max(C3.serialNumber),length(C3.missingSerials));
        fprintf('Number of packets flagged as "Lead off": %i\n', sum(C3.leadoff ~= 0));
        fprintf('==========================================================\n');
        fprintf('Error code stats for all channels (total samples: %i)\n', length(C3.ecg.data'));
        fprintf('ECG Error Code (any error)         : %i\n',               length(find(abs(C3.ecg.data') >= 32765))),
        fprintf('ECG Sample max value (ecg = 32767) : %i\n',               length(find(C3.ecg.data' == 32767)))
        fprintf('ECG Sample min value (ecg = -32765): %i\n',               length(find(C3.ecg.data' == -32765)))
        fprintf('ECG Filter error (ecg = -32766)    : %i\n',               length(find(C3.ecg.data' == -32766)))
        fprintf('ECG Lead off (ecg = -32767)        : %i\n',               length(find(C3.ecg.data' == -32767)))
        fprintf('ECG Comm error (ecg = -32768)      : %i\n',               length(find(C3.ecg.data' == -32768)))
        fprintf('==========================================================\n');
        table(unique(C3.leadoff), histc(C3.leadoff(:),unique(C3.leadoff)), round(double(histc(C3.leadoff(:),unique(C3.leadoff))./double(length(C3.leadoff))*100)), 'VariableNames',{'Lead_off_val' 'Count' 'Percent'})
        
    end

    function plotSensorData()
        %         linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'off');
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox, hECGleadoffCheckbox)
        if ~isempty(C3.resp)
            plotResp(C3,rangeStartIndex.Resp,rangeEndIndex.Resp,xAxisTimeStamps,timeBase,hAxesResp);
        end
        plotAccel(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox);
        plotTemp(C3,rangeStartIndex.Temp,rangeEndIndex.Temp,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
        %         linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'x');
        %         fprintf('PLOT:\n');
        %         fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
        %         fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
        %         fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
        %         fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
    end

    function onClickAxes(hAx, ~)
        point1 = get(hAx,'CurrentPoint'); % corner where rectangle starts ( initial mouse down point )
        rbbox
        point2 = get(hAx,'CurrentPoint'); % corner where rectangle stops ( when user lets go of mouse )
        % Define min and max x and y values
        xMin = min([point1(1,1), point2(1,1)]);
        xMax = max([point1(1,1), point2(1,1)]);
        yMin = min([point1(1,2), point2(1,2)]);
        yMax = max([point1(1,2), point2(1,2)]);
        % find corresponding data indices
        [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,xMin,xMax);
        updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
        setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
        enableButtons(hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
        % update range info text
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
        plotSensorData;
    end

    function rangeSliderFcn(hRangeSlider, ~)
        currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
        rangeStartIndex.Accel = round(hRangeSlider.Value) - round(currentRange * 0.5);
        rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
        [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
        rangeStartIndex.Accel = startIdx;
        rangeEndIndex.Accel = endIdx;
        rangeStartIndex.Temp = rangeStartIndex.Accel;
        rangeEndIndex.Temp = rangeEndIndex.Accel;
        rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
        rangeEndIndex.ECG = min(C3.ecg.samplenum, rangeEndIndex.Accel * 10);
        rangeStartIndex.Resp = rangeStartIndex.ECG;
        rangeEndIndex.Resp = rangeEndIndex.ECG;
        % update buttons, range info text, and plot range
        updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
        plotSensorData;
        %         fprintf('Slider value: %f\n', hRangeSlider.Value);
    end

    function navLeftButtonFcn(varargin)
        % ECG, navigate left
        [rangeStartIndex.ECG, rangeEndIndex.ECG] = navLeft(rangeStartIndex.ECG, rangeEndIndex.ECG, C3.ecg.samplenum);
        % Resp, navigate left
        [rangeStartIndex.Resp, rangeEndIndex.Resp] = navLeft(rangeStartIndex.Resp, rangeEndIndex.Resp, C3.resp.samplenum);
        % Accel, navigate left
        [rangeStartIndex.Accel, rangeEndIndex.Accel] = navLeft(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
        % Temp, navigate left
        [rangeStartIndex.Temp, rangeEndIndex.Temp] = navLeft(rangeStartIndex.Temp, rangeEndIndex.Temp, C3.temp.samplenum);
        % update buttons, range info text, and plot range
        updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
        setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
        plotSensorData;
    end

    function navRightButtonFcn(varargin)
        % ECG, navigate right
        [rangeStartIndex.ECG, rangeEndIndex.ECG] = navRight(rangeStartIndex.ECG, rangeEndIndex.ECG, C3.ecg.samplenum);
        % Resp, navigate right
        [rangeStartIndex.Resp, rangeEndIndex.Resp] = navRight(rangeStartIndex.Resp, rangeEndIndex.Resp, C3.resp.samplenum);
        % Accel, navigate right
        [rangeStartIndex.Accel, rangeEndIndex.Accel] = navRight(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
        % Temp, navigate right
        [rangeStartIndex.Temp, rangeEndIndex.Temp] = navRight(rangeStartIndex.Temp, rangeEndIndex.Temp, C3.temp.samplenum);
        % update buttons, range info text, and plot range
        updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
        setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
        plotSensorData;
    end

    function navEventLeftButtonFcn(varargin)
        % if no event type has been selected
        if hPopupEvent.Value == 1
            warndlg(sprintf('Please select an event type\nfrom the popup menu!'),'Select an event!');
        else
            [eventECG_rowIdx, ~] = getECGeventIndex(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,hPopupEvent,'left');
            if isempty(eventECG_rowIdx)
                warndlg(sprintf('No occurences of the selected event,\nto the left of the plotted data.'),'No events to navigate to!');
            else
                %                 fprintf('eventECGidx: %d\n',eventECG_rowIdx(1));
                %                 C3.ecg.data(eventECG_rowIdx(1),:)
                currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
                rangeStartIndex.Accel = round(eventECG_rowIdx(1)*0.1) - round(currentRange * 0.5);
                rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
                [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
                rangeStartIndex.Accel = startIdx;
                rangeEndIndex.Accel = endIdx;
                rangeStartIndex.Temp = rangeStartIndex.Accel;
                rangeEndIndex.Temp = rangeEndIndex.Accel;
                rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
                rangeEndIndex.ECG = min(C3.ecg.samplenum, rangeEndIndex.Accel * 10);
                rangeStartIndex.Resp = rangeStartIndex.ECG;
                rangeEndIndex.Resp = rangeEndIndex.ECG;
                % update buttons, range info text, and plot range
                updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
                plotSensorData;
            end
        end
    end

    function navEventRightButtonFcn(varargin)
        % if no event type has been selected
        if hPopupEvent.Value == 1
            warndlg(sprintf('Please select an event type\nfrom the popup menu!'),'Select an event!');
        else
            [eventECG_rowIdx, ~] = getECGeventIndex(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,hPopupEvent,'right');
            if isempty(eventECG_rowIdx)
                warndlg(sprintf('No occurences of the selected event,\nto the right of the plotted data.'),'No events to navigate to!');
            else
                %                 fprintf('eventECGidx: %d\n',eventECG_rowIdx(1));
                %                 C3.ecg.data(eventECG_rowIdx(1),:)
                currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
                rangeStartIndex.Accel = round(eventECG_rowIdx(1)*0.1) - round(currentRange * 0.5);
                rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
                [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
                rangeStartIndex.Accel = startIdx;
                rangeEndIndex.Accel = endIdx;
                rangeStartIndex.Temp = rangeStartIndex.Accel;
                rangeEndIndex.Temp = rangeEndIndex.Accel;
                rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
                rangeEndIndex.ECG = min(C3.ecg.samplenum, rangeEndIndex.Accel * 10);
                rangeStartIndex.Resp = rangeStartIndex.ECG;
                rangeEndIndex.Resp = rangeEndIndex.ECG;
                % update buttons, range info text, and plot range
                updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton);
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
                plotSensorData;
            end
        end
    end

    function rangeButtonFcn(hButton, ~)
        %if the 'Reset Range' button was clicked
        if strcmp(hButton.String,'Reset Range')
            [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hNavLeftButton,hNavRightButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            % if not, then assume we want to set a specific range
        else
            % if item 1 ('1 sec') is selected
            if hPopupRange.Value == 1
                [rangeStartIndex, rangeEndIndex] = setRange(1, rangeStartIndex, rangeEndIndex, C3);
                % if item 2 ('2 sec') is selected
            elseif hPopupRange.Value == 2
                [rangeStartIndex, rangeEndIndex] = setRange(2, rangeStartIndex, rangeEndIndex, C3);
                % if item 3 ('5 sec') is selected
            elseif hPopupRange.Value == 3
                [rangeStartIndex, rangeEndIndex] = setRange(5, rangeStartIndex, rangeEndIndex, C3);
                % if item 4 ('10 sec') is selected
            elseif hPopupRange.Value == 4
                [rangeStartIndex, rangeEndIndex] = setRange(10, rangeStartIndex, rangeEndIndex, C3);
                % if item 5 ('30 sec') is selected
            elseif hPopupRange.Value == 5
                [rangeStartIndex, rangeEndIndex] = setRange(30, rangeStartIndex, rangeEndIndex, C3);
                % if item 6 ('1 min') is selected
            elseif hPopupRange.Value == 6
                [rangeStartIndex, rangeEndIndex] = setRange(60, rangeStartIndex, rangeEndIndex, C3);
            end
            setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
            enableButtons(hResetButton,hNavLeftButton,hNavRightButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
        end
        % update range info text, and plot range
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
        plotSensorData;
    end

    function timebaseSelectionFcn(varargin)
        % For now we just plot the data again, and let the plot functions
        % ask for the x-axis data. Would be more optimal to just replace
        % x-axis ticks.
        timeBase = getTimeBase(hTimebaseButtonGroup);
        %if the C3 object is not empty
        if ~isempty(C3.date_start)
            if strcmp(timeBase,'World')
                if isempty(timeEnd.world)
                    [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd);
                end
            else
                if isempty(timeEnd.duration)
                    [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd);
                end
            end
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime);
            plotSensorData;
        end
    end

    function folderName = updateDirectoryInfo()
        dirNameParts = strsplit(dirName,filesep);
        folderName = dirNameParts(length(dirNameParts));
        set(hTextDirInfo,'String',strcat('..', filesep, dirNameParts(length(dirNameParts)-2), filesep, dirNameParts(length(dirNameParts)-1), filesep, dirNameParts(length(dirNameParts)), filesep, sourceFileName));
    end

%% Functions for updating plots, based on checkbox selections
% (CLEAN UP) The callback from the buttons should be modified so they call
% the plot functions directly - not using this intermediate function.

    function ecgPlotFunc(varargin)
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox, hECGleadoffCheckbox);
    end

    function accelPlotFunc(varargin)
        %display(varargin);
        plotAccel(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox);
    end

    function tempPlotFunc(varargin)
        plotTemp(C3,rangeStartIndex.Temp,rangeEndIndex.Temp,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
    end

%% Functions for creating separate, floating plot windows

    function ecgWinFunc(varargin)
        %--- creates a new, floating window for the ECG plot ---%
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.1);
        winWidth = round(screenSize(3)*0.5);
        winHeight = round(screenSize(4)*0.5);
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'ECG');
        plotOptions = getPlotOptions(timeBase);
        hECGFig = figure('Numbertitle','off','Name',['ECG   Folder name: ' char(folderName)],'OuterPosition', [winXpos winYpos winWidth winHeight]); %,'Visible','off'
        hAxesECGWindow = axes('Parent',hECGFig);
        hAxesECGWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.ECG)) datenum(xAxisTimeStamp(rangeEndIndex.ECG))];
        hold(hAxesECGWindow,'on');
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,1),'Color','r',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_1'};
            end
            if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,2),'Color', [0.0 0.85 0.0],plotOptions);
                legendList(length(legendList)+1) = {'ECG\_2'};
            end
            if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,3),'Color','b',plotOptions);
                legendList(length(legendList)+1) = {'ECG\_3'};
            end
        else
            durTickForm = getDurationTickFormat(rangeStartIndex.ECG, rangeEndIndex.ECG, C3.ecg.fs);
            if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
                legendList(length(legendList)+1) = {'ECG\_1'};
            end
            if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
                legendList(length(legendList)+1) = {'ECG\_2'};
            end
            if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.data(rangeStartIndex.ECG:rangeEndIndex.ECG,3),'Color','b','DurationTickFormat',durTickForm,plotOptions);
                legendList(length(legendList)+1) = {'ECG\_3'};
            end
            if get(hECGleadoffCheckbox, 'Value') == 1 % if checkbox for ECGleadoff is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.leadoff(rangeStartIndex.ECG:rangeEndIndex.ECG),'Color','b','DurationTickFormat',durTickForm,plotOptions);
                legendList(length(legendList)+1) = {'ECG\_3'};
            end
        end
        title('ECG','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',10);
        ylabel('sample value','FontSize',10);
        set(hAxesECGWindow,'FontSize',10);
        legend(hAxesECGWindow,legendList);
        hAxesECGWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.ECG)) datenum(xAxisTimeStamp(rangeEndIndex.ECG))];
    end

    function respWinFunc(varargin)
        %--- creates a new, floating window for the ECG plot ---%
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.2);
        winWidth = round(screenSize(3)*0.5);
        winHeight = round(screenSize(4)*0.5);
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Resp');
        plotOptions = getPlotOptions(timeBase);
        hRespFig = figure('Numbertitle','off','Name',['Respiration   Folder name: ' char(folderName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesRespWindow = axes('Parent',hRespFig);
        hold on;
        if strcmp(timeBase,'World')
            plot(hAxesRespWindow,xAxisTimeStamp(rangeStartIndex.Resp:rangeEndIndex.Resp),C3.resp.data(rangeStartIndex.Resp:rangeEndIndex.Resp),'Color','r',plotOptions);
        else
            plot(hAxesRespWindow,xAxisTimeStamp(rangeStartIndex.Resp:rangeEndIndex.Resp),C3.resp.data(rangeStartIndex.Resp:rangeEndIndex.Resp),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
        end
        hAxesRespWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.Resp)) datenum(xAxisTimeStamp(rangeEndIndex.Resp))];
        title('Respiration','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',10);
        ylabel('sample value','FontSize',10);
        legend(hAxesRespWindow,'Respiration');
        set(hAxesRespWindow,'FontSize',10);
        %hRespFig.Visible = 'on';
    end

    function accelWinFunc(varargin)
        %--- creates a new, floating window for the Acceleration plot ---%
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.3);
        winWidth = round(screenSize(3)*0.5);
        winHeight = round(screenSize(4)*0.5);
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Accel');
        plotOptions = getPlotOptions(timeBase);
        hAccelFig = figure('Numbertitle','off','Name',['Acceleration   Folder name: ' char(folderName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesAccelWindow = axes('Parent',hAccelFig);
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.magnitudeFiltered(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.magnitude(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k',plotOptions);
                end
                legendList(length(legendList)+1) = {'magnitude'};
            end
        else
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],'DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],'DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.dataFiltered((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.magnitudeFiltered(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
                else
                    plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.magnitude(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
                end
                legendList(length(legendList)+1) = {'magnitude'};
            end
        end
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON, include 'median filtered' in title
            title('Acceleration, median filtered','FontSize',12,'FontWeight','bold');
        else
            title('Acceleration','FontSize',12,'FontWeight','bold');
        end
        hAxesAccelWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.Accel)) datenum(xAxisTimeStamp(rangeEndIndex.Accel))];
        xlabel(['time (' timeBase ')'],'FontSize',10);
        ylabel('sample value','FontSize',10);
        legend(hAxesAccelWindow,legendList);
        set(hAxesAccelWindow,'FontSize',10);
        %hAccelFig.Visible = 'on';
    end

    function tempWinFunc(varargin)
        %--- creates a new, floating window for the Temperature plot ---%
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.4);
        winWidth = round(screenSize(3)*0.5);
        winHeight = round(screenSize(4)*0.5);
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Temp');
        plotOptions = getPlotOptions(timeBase);
        hTempFig = figure('Numbertitle','off','Name',['Temperature   Folder name: ' char(folderName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesTempWindow = axes('Parent',hTempFig);
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp(rangeStartIndex.Temp:rangeEndIndex.Temp),C3.temp.data((rangeStartIndex.Temp:rangeEndIndex.Temp),1),'Color','r',plotOptions);
                legendList(length(legendList)+1) = {'Device'};
            end
            if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp(rangeStartIndex.Temp:rangeEndIndex.Temp),C3.temp.data((rangeStartIndex.Temp:rangeEndIndex.Temp),2),'Color', [0.0 0.85 0.0],plotOptions);
                legendList(length(legendList)+1) = {'Surface'};
            end
        else
            if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp(rangeStartIndex.Temp:rangeEndIndex.Temp),C3.temp.data((rangeStartIndex.Temp:rangeEndIndex.Temp),1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Device'};
            end
            if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
                plot(hAxesTempWindow,xAxisTimeStamp(rangeStartIndex.Temp:rangeEndIndex.Temp),C3.temp.data((rangeStartIndex.Temp:rangeEndIndex.Temp),2),'Color', [0.0 0.85 0.0],'DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Surface'};
            end
        end
        hAxesTempWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.Temp)) datenum(xAxisTimeStamp(rangeEndIndex.Temp))];
        title('Temperature','FontSize',12,'FontWeight','bold');
        xlabel(['time (' timeBase ')'],'FontSize',10);
        ylabel('sample value','FontSize',10);
        legend(hAxesTempWindow,legendList);
        set(hAxesTempWindow,'FontSize',10);
        %hTempFig.Visible = 'on';
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

function plotECG(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox, hECGleadoffCheckbox)
xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'ECG');
plotOptions = getPlotOptions(timeBase);
% clear the plot, then create new plot
cla(hAxesECG);
if strcmp(timeBase,'World')
    if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,1),'Color','r',plotOptions);
    end
    if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],plotOptions);
    end
    if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,3),'Color','b',plotOptions);
    end
    if get(hECGleadoffCheckbox, 'Value') == 1 % if checkbox for ECG_leadoff is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.leadoff(startIdx:endIdx),'Color',[0.5 0.5 0.5],plotOptions, 'LineWidth', 10);
    end
else
    durTickForm = getDurationTickFormat(startIdx, endIdx, C3.ecg.fs);
    if get(hECG1Checkbox, 'Value') == 1 % if checkbox for ECG_1 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
    end
    if get(hECG2Checkbox, 'Value') == 1 % if checkbox for ECG_2 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
    end
    if get(hECG3Checkbox, 'Value') == 1 % if checkbox for ECG_3 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.data(startIdx:endIdx,3),'Color','b','DurationTickFormat',durTickForm,plotOptions);
    end
    if get(hECGleadoffCheckbox, 'Value') == 1 % if checkbox for ECG_3 is ON
        plot(hAxesECG,xAxisTimeStamp(startIdx:endIdx),C3.ecg.leadoff(startIdx:endIdx),'Color',[0.5 0.5 0.5],'DurationTickFormat',durTickForm, 'LineWidth', 10);
    end
end
hAxesECG.XLim = [datenum(xAxisTimeStamp(startIdx)) datenum(xAxisTimeStamp(endIdx))];
%     hAxesECG.YLim = [nanmin(C3.ecg.data(startIdx:endIdx)) nanmax(C3.ecg.data(startIdx:endIdx))];
end

function plotResp(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesResp)
xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Resp');
plotOptions = getPlotOptions(timeBase);
cla(hAxesResp);
if strcmp(timeBase,'World')
    plot(hAxesResp,xAxisTimeStamp(startIdx:endIdx),C3.resp.data(startIdx:endIdx),'Color','r',plotOptions);
else
    durTickForm = getDurationTickFormat(startIdx, endIdx, C3.resp.fs);
    plot(hAxesResp,xAxisTimeStamp(startIdx:endIdx),C3.resp.data(startIdx:endIdx),'Color','r','DurationTickFormat',durTickForm,plotOptions);
end
hAxesResp.XLim = [datenum(xAxisTimeStamp(startIdx)) datenum(xAxisTimeStamp(endIdx))];
end

function plotAccel(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox,hAccelMedfiltCheckbox)
xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Accel');
plotOptions = getPlotOptions(timeBase);
cla(hAxesAccel);
if strcmp(timeBase,'World')
    if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,1),'Color','r',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,1),'Color','r',plotOptions);
        end
    end
    if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],plotOptions);
        end
    end
    if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,3),'Color','b',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,3),'Color','b',plotOptions);
        end
    end
    if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.magnitudeFiltered(startIdx:endIdx),'Color','k',plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.magnitude(startIdx:endIdx),'Color','k',plotOptions);
        end
    end
else
    durTickForm = getDurationTickFormat(startIdx, endIdx, C3.accel.fs);
    if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
        end
    end
    if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
        end
    end
    if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.dataFiltered(startIdx:endIdx,3),'Color','b','DurationTickFormat',durTickForm,plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,3),'Color','b','DurationTickFormat',durTickForm,plotOptions);
        end
    end
    if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
        if get(hAccelMedfiltCheckbox, 'Value') == 1 % if checkbox for Medfilt ON
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.magnitudeFiltered(startIdx:endIdx),'Color','k','DurationTickFormat',durTickForm,plotOptions);
        else
            plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.magnitude(startIdx:endIdx),'Color','k','DurationTickFormat',durTickForm,plotOptions);
        end
    end
end
hAxesAccel.XLim = [datenum(xAxisTimeStamp(startIdx)) datenum(xAxisTimeStamp(endIdx))];
end

function plotTemp(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox)
xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Temp');
plotOptions = getPlotOptions(timeBase);
cla(hAxesTemp);
if strcmp(timeBase,'World')
    if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
        plot(hAxesTemp,xAxisTimeStamp(startIdx:endIdx),C3.temp.data(startIdx:endIdx,1),'Color','r',plotOptions);
    end
    if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_2 is ON
        plot(hAxesTemp,xAxisTimeStamp(startIdx:endIdx),C3.temp.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],plotOptions);
    end
else
    durTickForm = getDurationTickFormat(startIdx, endIdx, C3.temp.fs);
    if get(hTemp1Checkbox, 'Value') == 1 % if checkbox for Temp_1 is ON
        plot(hAxesTemp,xAxisTimeStamp(startIdx:endIdx),C3.temp.data(startIdx:endIdx,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
    end
    if get(hTemp2Checkbox, 'Value') == 1 % if checkbox for Temp_2 is ON
        plot(hAxesTemp,xAxisTimeStamp(startIdx:endIdx),C3.temp.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
    end
end
hAxesTemp.XLim = [datenum(xAxisTimeStamp(startIdx)) datenum(xAxisTimeStamp(endIdx))];
xlabel(hAxesTemp,['time (' timeBase ')'],'FontSize',10);
end

function [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd)
hTic_calcTimeStamps = tic;
if strcmp(timeBase,'World')
    timeStart.world = datetime(C3.date_start, 'ConvertFrom', 'datenum');
    timeEnd.world = datetime(C3.date_end, 'ConvertFrom', 'datenum');
    xAxisTimeStamps.world.ECG = linspace(timeStart.world,timeEnd.world,C3.ecg.samplenum);
    xAxisTimeStamps.world.Resp = linspace(timeStart.world,timeEnd.world,C3.resp.samplenum);
    xAxisTimeStamps.world.Accel = linspace(timeStart.world,timeEnd.world,C3.accel.samplenum);
    xAxisTimeStamps.world.Temp = linspace(timeStart.world,timeEnd.world,length(C3.temp.data));
else
    deltaTime = datetime(C3.date_end, 'ConvertFrom', 'datenum') - datetime(C3.date_start, 'ConvertFrom', 'datenum');
    timeStart.duration = days(0);
    timeEnd.duration = days(deltaTime);
    xAxisTimeStamps.duration.ECG = linspace(timeStart.duration,timeEnd.duration,C3.ecg.samplenum);
    xAxisTimeStamps.duration.Resp = linspace(timeStart.duration,timeEnd.duration,C3.resp.samplenum);
    xAxisTimeStamps.duration.Accel = linspace(timeStart.duration,timeEnd.duration,C3.accel.samplenum);
    xAxisTimeStamps.duration.Temp = linspace(timeStart.duration,timeEnd.duration,length(C3.temp.data));
end
fprintf('calcTimeStamps: %f seconds\n',toc(hTic_calcTimeStamps));
end

function xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,signalName)
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

function [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,startTime,endTime)
% This function finds the index numbers that most closely corresponds
% to the given datetime input. This is to handle output from rbbox
% (rubber band box selections), which does not return actual plot point
% values, but interpolated values from the plot figure.
hTic_setRangeIndices = tic;
if strcmp(timeBase,'World')
    % search for index of value closest to given time, in the Accel data,
    % which has 10 times lower sampling rate than the ECG and Resp channels.
    startIdx = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(startTime), 1)) - 1;
    endIdx = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(endTime), 1));
    rangeStartIndex.Accel = max(1,startIdx);
    if isempty(endIdx)
        rangeEndIndex.Accel = length(xAxisTimeStamps.world.Accel);
    else
        rangeEndIndex.Accel = endIdx - 1;
    end
    % Now use this index for the remaining channels.
    % There should be an exact match, since ECG and Resp
    % is sampled at exactly 10 times the rate of Accel.
    rangeStartIndex.Temp = rangeStartIndex.Accel;
    rangeEndIndex.Temp = rangeEndIndex.Accel;
    rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
    rangeEndIndex.ECG = min(length(xAxisTimeStamps.world.ECG), rangeEndIndex.Accel * 10);
    rangeStartIndex.Resp = rangeStartIndex.ECG;
    rangeEndIndex.Resp = rangeEndIndex.ECG;
    %         fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
    %         fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
    %         fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
    %         fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
else
    % search for index of value closest to given time, in the Accel data,
    % which has 10 times lower sampling rate than the ECG and Resp channels.
    startIdx = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(startTime), 1)) - 1;
    endIdx = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(endTime), 1));
    rangeStartIndex.Accel = max(1,startIdx);
    if isempty(endIdx)
        rangeEndIndex.Accel = length(xAxisTimeStamps.duration.Accel);
    else
        rangeEndIndex.Accel = endIdx - 1;
    end
    % Now use this index for the remaining channels.
    % There should be an exact match, since ECG and Resp
    % is sampled at exactly 10 times the rate of Accel.
    rangeStartIndex.Temp = rangeStartIndex.Accel;
    rangeEndIndex.Temp = rangeEndIndex.Accel;
    rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
    rangeEndIndex.ECG = min(length(xAxisTimeStamps.duration.ECG), rangeEndIndex.Accel * 10);
    rangeStartIndex.Resp = rangeStartIndex.ECG;
    rangeEndIndex.Resp = rangeEndIndex.ECG;
    %         fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
    %         fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
    %         fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
    %         fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
end
fprintf('getRangeIndices: %f seconds\n',toc(hTic_setRangeIndices));
end

function setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hEditStartTime,hEditEndTime)
% Update the info-text that displays range start and end time
%     hTic_setRangeInfo = tic;
if strcmp(timeBase,'World')
    set(hEditStartTime,'String',datestr(xAxisTimeStamps.world.Accel(rangeStartIndex.Accel), 'yyyy-mm-dd  HH:MM:SS'));
    set(hEditEndTime,'String',datestr(xAxisTimeStamps.world.Accel(rangeEndIndex.Accel), 'yyyy-mm-dd  HH:MM:SS'));
else
    [h,m,s] = hms([xAxisTimeStamps.duration.Accel(rangeStartIndex.Accel) xAxisTimeStamps.duration.Accel(rangeEndIndex.Accel)]);
    set(hEditStartTime,'String',sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))));
    set(hEditEndTime,'String',sprintf('%02i:%02i:%02i',h(2),m(2),round(s(2))));
end
%     fprintf('setRangeInfo: %f seconds\n',toc(hTic_setRangeInfo));
end

function plotOptions = getPlotOptions(timeBase)
if strcmp(timeBase,'World')
    plotOptions.LineWidth = 1;
else
    plotOptions.LineWidth = 1;
    %plotOptions.DurationTickFormat = 'hh:mm:ss'; % NO GO
end
end

function durTickForm = getDurationTickFormat(startIdx, endIdx, fs)
% if the plot range is greater than 2 seconds
if (endIdx - startIdx)/fs > 5
    durTickForm = 'hh:mm:ss';
else
    durTickForm = 'hh:mm:ss.SSS';
end
end

function timeBase = getTimeBase(hTimebaseButtonGroup)
timeBase = get(get(hTimebaseButtonGroup,'selectedobject'),'String');
end

function [startIdx, endIdx] = navLeft(startIdx, endIdx, numSamples)
numIndices = endIdx - startIdx + 1;
startIdx = startIdx - numIndices;
endIdx = endIdx - numIndices;
if startIdx < 1
    [startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, numSamples);
end
end

function [startIdx, endIdx] = navRight(startIdx, endIdx, numSamples)
numIndices = endIdx - startIdx + 1;
startIdx = startIdx + numIndices;
endIdx = endIdx + numIndices;
if endIdx > numSamples
    [startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, numSamples);
end
end

function [rangeStartIndex, rangeEndIndex] = setRange(rangeSecs, rangeStartIndex, rangeEndIndex, C3)
centerIndex = round(rangeStartIndex.Accel + (rangeEndIndex.Accel - rangeStartIndex.Accel)*0.5);
startIdx  = round(centerIndex - (C3.accel.fs * rangeSecs * 0.5));
endIdx  = round(centerIndex + (C3.accel.fs * rangeSecs * 0.5)) - 1;
[startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, C3.accel.samplenum);
rangeStartIndex.Accel = startIdx;
rangeEndIndex.Accel = endIdx;
rangeStartIndex.Temp = rangeStartIndex.Accel;
rangeEndIndex.Temp = rangeEndIndex.Accel;
rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * 10) + 1;
rangeEndIndex.ECG = min(C3.ecg.samplenum, rangeEndIndex.Accel * 10);
rangeStartIndex.Resp = rangeStartIndex.ECG;
rangeEndIndex.Resp = rangeEndIndex.ECG;
end

function [startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, numSamples)
if startIdx < 1
    endIdx = endIdx + abs(startIdx) + 1;
    startIdx = 1;
end
if endIdx > numSamples
    startIdx = startIdx - (endIdx - numSamples);
    endIdx = endIdx - (endIdx - numSamples);
end
end

function [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hNavLeftButton,hNavRightButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton)
% ECG, reset to full range
rangeStartIndex.ECG  = 1;
rangeEndIndex.ECG  = C3.ecg.samplenum;
% Resp, reset to full range
rangeStartIndex.Resp  = 1;
rangeEndIndex.Resp  = C3.resp.samplenum;
% Accel, reset to full range
rangeStartIndex.Accel  = 1;
rangeEndIndex.Accel  = C3.accel.samplenum;
% Temp, reset to full range
rangeStartIndex.Temp  = 1;
rangeEndIndex.Temp  = C3.temp.samplenum;
hResetButton.Enable = 'off';
hNavLeftButton.Enable = 'off';
hNavRightButton.Enable = 'off';
hRangeSlider.Enable = 'off';
hPopupEvent.Enable = 'off';
hNavEventLeftButton.Enable = 'off';
hNavEventRightButton.Enable = 'off';
end

function enableButtons(varargin)
for i=1:length(varargin)
    varargin{i}.Enable = 'on';
end
end

function disableButtons(varargin)
for i=1:length(varargin)
    varargin{i}.Enable = 'off';
end
end

function updateNavLeftRightButtons(C3,rangeStartIndex,rangeEndIndex,hNavLeftButton,hNavRightButton)
if rangeStartIndex.ECG <= 1
    hNavLeftButton.Enable = 'off';
else
    hNavLeftButton.Enable = 'on';
end
if rangeEndIndex.ECG >= C3.ecg.samplenum
    hNavRightButton.Enable = 'off';
else
    hNavRightButton.Enable = 'on';
end
end

function setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider)
currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
halfRange = round(currentRange * 0.5);
hRangeSlider.Min = halfRange;
hRangeSlider.Max = C3.accel.samplenum - halfRange;
minorstep = max(0.00002, (currentRange + 1) / double(C3.accel.samplenum)); % slider minorstep must be > 0.000001
majorstep = minorstep * 10;
hRangeSlider.SliderStep = [minorstep majorstep];
sliderVal = rangeStartIndex.Accel + halfRange;
%     fprintf('Slider min: %d  max: %d  val: %d   minStep: %f  maxStep: %f\n',hRangeSlider.Min, hRangeSlider.Max, sliderVal, hRangeSlider.SliderStep(1), hRangeSlider.SliderStep(2));
if sliderVal > hRangeSlider.Max
    sliderVal = hRangeSlider.Max;
end
if sliderVal < hRangeSlider.Min
    sliderVal = hRangeSlider.Min;
end
hRangeSlider.Value = sliderVal;
end

function [eventECG_rowIdx, eventECG_colIdx] = getECGeventIndex(C3,rangeStartIdx,rangeEndIdx,hPopupEvent,searchDir)
% NOTE: notice the transpose (') in the arguments to the find function.
eventECG_rowIdx = [];
eventECG_colIdx = [];
% if search to the right side of the currently displayed data
if strcmp(searchDir,'right')
    % if search for 'ECG Error Code (any error)'
    if hPopupEvent.Value == 2
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') >= 32765, 1);
        % if search for 'ECG Sample max value (ecg = 32767)'
    elseif hPopupEvent.Value == 3
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)' == 32767, 1);
        % if search for 'ECG Sample min value (ecg = -32765)'
    elseif hPopupEvent.Value == 4
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)' == -32765, 1);
        % if search for 'ECG Filter error (ecg = -32766)'
    elseif hPopupEvent.Value == 5
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)' == -32766, 1);
        % if search for 'ECG Lead off (ecg = -32767)'
    elseif hPopupEvent.Value == 6
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)' == -32767, 1);
        % if search for 'ECG Comm error (ecg = -32768)'
    elseif hPopupEvent.Value == 7
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)' == -32768, 1);
        % if search for 'ECG abs(ecg) >= 5000 & < 10000'
    elseif hPopupEvent.Value == 8
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') >= 5000 & abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') < 10000, 1);
        % if search for 'ECG abs(ecg) >= 10000 & < 20000'
    elseif hPopupEvent.Value == 9
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') >= 10000 & abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') < 20000, 1);
        % if search for 'ECG abs(ecg) >= 20000 & < 32765''
    elseif hPopupEvent.Value == 10
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') >= 20000 & abs(C3.ecg.data(rangeEndIdx:C3.ecg.samplenum,:)') < 32765, 1);
    end
    if ~isempty(eventECG_rowIdx)
        eventECG_rowIdx = eventECG_rowIdx + rangeEndIdx - 1;
        if rangeEndIdx == C3.ecg.samplenum
            eventECG_rowIdx = [];
            eventECG_colIdx = [];
        end
    end
    % else, search to the left side of the currently displayed data
else
    % if search for 'ECG Error Code (any error)'
    if hPopupEvent.Value == 2
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(1:rangeStartIdx,:)') >= 32765, 1, 'last');
        % if search for 'ECG Sample max value (ecg = 32767)'
    elseif hPopupEvent.Value == 3
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(1:rangeStartIdx,:)' == 32767, 1, 'last');
        % if search for 'ECG Sample min value (ecg = -32765)'
    elseif hPopupEvent.Value == 4
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(1:rangeStartIdx,:)' == -32765, 1, 'last');
        % if search for 'ECG Filter error (ecg = -32766)'
    elseif hPopupEvent.Value == 5
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(1:rangeStartIdx,:)' == -32766, 1, 'last');
        % if search for 'ECG Lead off (ecg = -32767)'
    elseif hPopupEvent.Value == 6
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(1:rangeStartIdx,:)' == -32767, 1, 'last');
        % if search for 'ECG Comm error (ecg = -32768)'
    elseif hPopupEvent.Value == 7
        [eventECG_colIdx, eventECG_rowIdx] = find(C3.ecg.data(1:rangeStartIdx,:)' == -32768, 1, 'last');
        % if search for 'ECG abs(ecg) >= 5000 & < 10000'
    elseif hPopupEvent.Value == 8
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(1:rangeStartIdx,:)') >= 5000 & abs(C3.ecg.data(1:rangeStartIdx,:)') < 10000, 1, 'last');
        % if search for 'ECG abs(ecg) >= 10000 & < 20000'
    elseif hPopupEvent.Value == 9
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(1:rangeStartIdx,:)') >= 10000 & abs(C3.ecg.data(1:rangeStartIdx,:)') < 20000, 1, 'last');
        % if search for 'ECG abs(ecg) >= 20000 & < 32765''
    elseif hPopupEvent.Value == 10
        [eventECG_colIdx, eventECG_rowIdx] = find(abs(C3.ecg.data(1:rangeStartIdx,:)') >= 20000 & abs(C3.ecg.data(1:rangeStartIdx,:)') < 32765, 1, 'last');
    end
    if rangeStartIdx == 1
        eventECG_rowIdx = [];
        eventECG_colIdx = [];
    end
end
end

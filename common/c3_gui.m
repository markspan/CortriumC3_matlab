function c3_gui()
% WORK IN PROGRESS! Needs cleanup from old code, etc.

%% Initialize variables
hTic_buildingGUI = tic;

% Root path to Cortrium Matlab scripts
cortrium_matlab_scripts_root_path = getCortriumScriptsRoot;
    
% create new C3 object, empty until a sensor data directory has been selected
C3 = cortrium_c3('');
jsondata = struct([]);
reportIOmarkers = struct([]);
eventMarkers = struct([]);
pathName = '';
sourceName = '';
fileName = '';
full_path = '';
json_fullpath = '';
% gS - a struct to keep track of various options in the GUI, such as whether to flip ecg channels, etc.
gS = struct('dataLoaded',false,...
            'flipEcg1',false,...
            'flipEcg2',false,...
            'flipEcg3',false,...
            'ecgMarkerMode',false,...
            'ecgMarkerDisplay',false,...
            'ecgInpointSet',false,...
            'eventMarkerMode',false,...
            'eventMarkerDisplay',false,...
            'colors',[]);
        
gS.colors.col = {[1 0 0],...
                 [0 0.8 0],...
                 [0 0 1],...
                 [0 0 0],...
                 [1 1 1],...
                 [0.5 0.5 0.5],...
                 [1.0 0.68 0.1],...
                 [0.7451 0.2078 0.8588]};

% Set a temporary screen resolution of 1920x1080 pixels while we construct GUI.
% Will be modified to actual screen resolution before GUI is displayed.
% Currently the GUI doesn't scale well to resolutions much smaller than
% 1920x1080.
screenWidth = 1920;
screenHeight = 1080;

panelColor = [0.9 0.9 0.9]; % color of panel background
whiteTransp = [1.0 1.0 1.0 0.0];
editColor = [1.0 1.0 1.0]; % color of text edit boxes
editColorGreen = [0.5 1 0.5]; % color of buttons when in edit mode
dimmedTextColor = [0.4 0.4 0.4];
panelBorderColor = [1.0 1.0 1.0]; % color of the line between panels
colorGreen = [0.0 0.8 0.0];

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

sampleRateFactor.ECG = 0;
sampleRateFactor.Resp = 0;
sampleRateFactor.Accel = 0;
sampleRateFactor.Temp = 0;

%% GUI

% (MATLAB R2014b+) turn off graphics smoothing on graphics root object
set(groot,'DefaultFigureGraphicsSmoothing','off')

% Create GUI window, visibility is turned off while the GUI elements are added
hFig = figure('Name','Cortrium C3 sensor data',...
    'Numbertitle','off',...
    'OuterPosition', [1 1 screenWidth screenHeight],...
    'MenuBar', 'figure',...
    'Toolbar','none',...
    'Visible','off',...
    'ResizeFcn',@resizeFcn,...
    'CloseRequestFcn',@closeRequestFcn);

% create a parent panel for sub-panels in the figure window
hPanelMain = uipanel('BorderType','none',...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

%% -----Panel: Load Data-----

% create a panel for "Load Sensor Data" button
hPanelLoad = uipanel('Parent',hPanelMain,...
    'Title','Load Sensor Data',...
    'BorderType','line',... % 'BackgroundColor',editColor,...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.88 0.15 0.11],...
    'BackgroundColor',panelColor);

% Button to open dialog box, to select a folder with sensor data
uicontrol('Parent',hPanelLoad,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.53,0.9,0.4],...
    'String','Load Sensor Data',...
    'FontSize',12,...
    'Callback',@(~,~)loadButtonFcn);

% Radio buttons group, file format
hFileFormatButtonGroup = uibuttongroup('Parent',hPanelLoad,...
    'Units','normalized',...
    'Position',[0.05,0.07,0.9,0.4],...
    'BackgroundColor',panelColor,...
    'Title','Select file format to load',...
    'SelectionChangedFcn',@fileFormatSelectionFcn);

% Radio button, BLE 24bit (dialog, when clicking Load, will want a BLE file)
hFileFormatButton1 = uicontrol(hFileFormatButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','BLE 24bit',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, BLE 16bit (dialog, when clicking Load, will want a BLE file)
hFileFormatButton2 = uicontrol(hFileFormatButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','BLE 16bit',...
    'Units','normalized',...
    'Position',[0.35,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, BIN files (dialog, when clicking Load, will want a folder)
hFileFormatButton3 = uicontrol(hFileFormatButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','BIN (folder)',...
    'Units','normalized',...
    'Position',[0.68,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hFileFormatButtonGroup,'selectedobject',hFileFormatButton1);
fileFormat = getFileFormat(hFileFormatButtonGroup);

%% -----Panel: Time Info-----

% create a panel for time info
hPanelTimeInfo = uipanel('Parent',hPanelMain,...
    'Title','Time',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.735 0.15 0.14],...
    'BackgroundColor',panelColor);

% text label for time info, world time of recording
uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.85 0.9 0.14],...
    'HorizontalAlignment','left',...
    'String','Recording:',...
    'FontSize',8,...
    'ForegroundColor',dimmedTextColor,...
    'BackgroundColor',panelColor);

hTextTimeRecording = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.73 0.9 0.14],...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% text label for time info, displayed time
hLabelTimeDisplayed = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.53 0.9 0.14],...
    'HorizontalAlignment','left',...
    'String','Displayed:',...
    'FontSize',8,...
    'ForegroundColor',dimmedTextColor,...
    'BackgroundColor',panelColor);

hTextTimeDisplayed = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.41,0.9,0.14],...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio buttons group, duration-based time vs. world time
hTimebaseButtonGroup = uibuttongroup('Parent',hPanelTimeInfo,...
    'Units','normalized',...
    'Position',[0.05,0.05,0.9,0.3],...
    'BackgroundColor',panelColor,...
    'Title','Axis time',...
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
    'Position',[0.35,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hTimebaseButtonGroup,'selectedobject',hTimeButton1);

timeBase = getTimeBase(hTimebaseButtonGroup,hLabelTimeDisplayed);

%% -----Panel: Navigate Sensor Data-----

% create a panel for buttons to navigate the data
hPanelNavigateData = uipanel('Parent',hPanelMain,...
    'Title','Navigate Sensor Data',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.84 0.555 0.15 0.17],...
    'BackgroundColor',panelColor);

% Button, Reset Range
hResetButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.77,0.9,0.2],...
    'String','Reset Range',...
    'FontSize',12,...
    'Callback',@rangeButtonFcn);

% Popup menu, for selecting a range (how many samples are plotted)
hPopupRange = uicontrol('Parent',hPanelNavigateData,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.552,0.415,0.17],...
    'String', {'Select range...','1 sec','2 sec','5 sec','10 sec','30 sec','1 min'},...
    'FontSize',10);
hPopupRange.Value = 1;

% Button, Set the range chosen in the popup menu next to this button
hRangeButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.56,0.42,0.17],... %[0.21,0.74,0.74,0.07]
    'String','Set Range',...
    'FontSize',10,...
    'Callback',@rangeButtonFcn);

hRangeSlider = uicontrol('Parent',hPanelNavigateData,...
    'Style','slider',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.31,0.9,0.17],...
    'Min',1,'Max',1000,...
    'Value',500,...
    'SliderStep',[0.1 1],...
    'BackgroundColor',panelColor,...
    'Callback',@rangeSliderFcn);

% Button, Navigate Event left
hNavEventLeftButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.038,0.25,0.17],...
    'String','< Event',...
    'FontSize',10,...
    'Callback',@navEventLeftButtonFcn);

% Button, Navigate Event right
hNavEventRightButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.7,0.038,0.25,0.17],...
    'String','Event >',...
    'FontSize',10,...
    'Callback',@navEventRightButtonFcn);

% Popup menu, for selecting an event to navigate to
hPopupEvent = uicontrol('Parent',hPanelNavigateData,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.35,0.028,0.3,0.17],...
    'String', {'Select...',...
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

%% -----Panel: Filtering-----

% create a parent panel for filter functionality sub-panels
hPanelParentFiltering = uipanel('Parent',hPanelMain,...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons to navigate and export features from the data
hPanelFilterData = uipanel('Parent',hPanelParentFiltering,...
    'Title','Filtering',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Sub-panel for flipping ECG channels
hPanelFlipECG = uipanel('Parent',hPanelFilterData,...
    'Title','ECG - flip channels',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.91 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG1 flip
hFlipEcg1Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,1});

% Text label, for ECG1 flip
uicontrol('Parent',hPanelFlipECG,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.1,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 1',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG2 flip
hFlipEcg2Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,2});

% Text label, for ECG2 flip
uicontrol('Parent',hPanelFlipECG,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.43,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 2',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG3 flip
hFlipEcg3Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,3});

% Text label, for ECG3 flip
uicontrol('Parent',hPanelFlipECG,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 3',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for ECG filters
hPanelFilterECG = uipanel('Parent',hPanelFilterData,...
    'Title','ECG',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.74 0.9 0.16],...
    'BackgroundColor',panelColor);

% Popup menu, for selecting ECG Highpass filter
hPopupEcgHighPass = uicontrol('Parent',hPanelFilterECG,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.02,0.5,0.96,0.45],...
    'String',  {'Highpass OFF',...
                'Highpass, (forward) IIR, butterw, N 1, fc 0.32Hz, fs 250Hz',...
                'Highpass, (forward) IIR, butterw, N 2, fc 0.32Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 2, fc 0.32Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 1, fc 0.5Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 2, fc 0.5Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 6, fc 0.5Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 12, fc 0.5Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 1, fc 0.67Hz, fs 250Hz',...
                'Highpass, (forward+reverse) IIR, butterw, N 2, fc 0.67Hz, fs 250Hz'},...
    'FontSize',8,...
    'Value',5,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Popup menu, for selecting ECG Lowpass filter
hPopupEcgLowPass = uicontrol('Parent',hPanelFilterECG,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.96,0.45],...
    'String',  {'Lowpass OFF',...
                'Lowpass, FIR, max flat, N 10, fc 40Hz, fs 250Hz',...
                'Lowpass, FIR, max flat, N 20, fc 40Hz, fs 250Hz',...
                'Lowpass, FIR, max flat, N 40, fc 40Hz, fs 250Hz',...
                'Lowpass, FIR, max flat, N 72, fc 40Hz, fs 250Hz',...
                'Lowpass, FIR, win chebyshev, N 100, fc 40Hz, fs 250Hz',...
                'Lowpass, FIR, win bartlet-hanning, N 100, fc 40Hz, fs 250Hz',...
                'Lowpass, (forward) IIR, butterw, N 12, fc 40Hz, fs 250Hz',...
                'Lowpass, (forward+reverse) IIR, butterw, N 12, fc 40Hz, fs 250Hz'},...
    'FontSize',8,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Sub-panel for ECG NaN filters
hPanelEcgNan = uipanel('Parent',hPanelFilterData,...
    'Title','ECG - replace with NaN',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.43 0.9 0.3],...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG NaN missing packets
hEcgNanMissPackCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.84,0.075,0.14],...
    'Value',1,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN missing packets
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.84,0.65,0.11],...
    'HorizontalAlignment','left',...
    'String','Missing packets',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG NaN error codes
hEcgNanErrCodesCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.68,0.075,0.14],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN error codes
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.685,0.65,0.11],...
    'HorizontalAlignment','left',...
    'String','Error codes (16bit)',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG NaN for abs(ecg) >
hEcgNanAbsEcgCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.52,0.075,0.14],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN abs(ecg) >
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.52,0.3,0.11],...
    'HorizontalAlignment','left',...
    'String','Abs(ECG) >',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for entering absolute value for setting ECG to NaN
hEcgNanAbsEcg = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.355,0.51,0.14,0.14],...
    'String','25000',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG abs value window size
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.35,0.5,0.13],...
    'HorizontalAlignment','left',...
    'String','Abs(ECG) window size:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for entering ECG abs value window size
hEcgAbsValWinSize = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.6,0.36,0.14,0.14],...
    'String','250',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG abs value window size, indicating the number refers to samples"
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.75,0.35,0.5,0.13],...
    'HorizontalAlignment','left',...
    'String','samples',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG NaN Accel mag
hEcgNanAccMagCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.17,0.075,0.17],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.16,0.3,0.14],...
    'HorizontalAlignment','left',...
    'String','Accel mag <',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for entering min Accel mag criteria for setting ECG to NaN
hEcgNanMinAccMag = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.355,0.18,0.14,0.14],...
    'String','0.95',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag, between fields for min/max Accel mag
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.51,0.16,0.1,0.14],...
    'HorizontalAlignment','left',...
    'String','or >',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for entering max Accel mag criteria for setting ECG to NaN
hEcgNanMaxAccMag = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.6,0.18,0.14,0.14],...
    'String','1.05',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag window size
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.02,0.5,0.13],...
    'HorizontalAlignment','left',...
    'String','Accel mag window size:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for entering Accel mag window size
hEcgNanAccMagWinSize = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.6,0.02,0.14,0.14],...
    'String','50',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag window size, indicating the numbers refers to packets
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.75,0.02,0.5,0.13],...
    'HorizontalAlignment','left',...
    'String','packets',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for Resp filters
hPanelFilterResp = uipanel('Parent',hPanelFilterData,...
    'Title','Resp',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.3 0.9 0.12],...
    'BackgroundColor',panelColor);

% Checkbox, toggles Resp highpass filter (only for 24bit data)
hRespHighpassCheckbox = uicontrol('Parent',hPanelFilterResp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.55,0.075,0.4],...
    'Value',1,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'resp'});

% Text label, for Resp Highpass checkbox
uicontrol('Parent',hPanelFilterResp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.55,0.65,0.35],...
    'HorizontalAlignment','left',...
    'String','Highpass',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles Resp Lowpass filter
hRespLowpassCheckbox = uicontrol('Parent',hPanelFilterResp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.08,0.075,0.4],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'resp'});

% Text label, for Resp Lowpass checkbox
uicontrol('Parent',hPanelFilterResp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.08,0.65,0.35],...
    'HorizontalAlignment','left',...
    'String','Lowpass',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for Accel filters
hPanelFilterAccel = uipanel('Parent',hPanelFilterData,...
    'Title','Accel',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.17 0.9 0.12],...
    'BackgroundColor',panelColor);

% Checkbox, toggles Accel remove-jitter filter
hAccelJitterCheckbox = uicontrol('Parent',hPanelFilterAccel,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.55,0.075,0.4],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'accel'});

% Text label, for Accel remove-jitter checkbox
uicontrol('Parent',hPanelFilterAccel,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.55,0.65,0.35],...
    'HorizontalAlignment','left',...
    'String','Remove Jitter',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles Accel median filter
hAccelMedianCheckbox = uicontrol('Parent',hPanelFilterAccel,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.08,0.075,0.4],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'accel'});

% Text label, for Accel median checkbox
uicontrol('Parent',hPanelFilterAccel,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.08,0.65,0.35],...
    'HorizontalAlignment','left',...
    'String','Median',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for Temp filters
hPanelFilterTemp = uipanel('Parent',hPanelFilterData,...
    'Title','Temp',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.08 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, toggles Temp remove-jitter filter
hTempJitterCheckbox = uicontrol('Parent',hPanelFilterTemp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'temp'});

% Text label, for Temp remove-jitter checkbox
uicontrol('Parent',hPanelFilterTemp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.08,0.65,0.7],...
    'HorizontalAlignment','left',...
    'String','Remove Jitter',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

%% -----Panel: Event Markers-----

% create a parent panel for filter functionality sub-panels
hPanelParentEventAnnotation = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons to navigate and export features from the data
hPanelEventAnnotation = uipanel('Parent',hPanelParentEventAnnotation,...
    'Title','Event Markers',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Sub-panel for adding and editing ECGkit analysis-markers
hPanelEventMarkers = uipanel('Parent',hPanelEventAnnotation,...
    'Title','',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.77 0.9 0.22],...
    'BackgroundColor',panelColor);

% Checkbox, toggles display of In-Out markers
hEventMarkersCheckbox = uicontrol('Parent',hPanelEventMarkers,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.55,0.075,0.36],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@eventsShowMarkersFcn);

% Text label, for display of event markers
uicontrol('Parent',hPanelEventMarkers,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.51,0.85,0.28],...
    'HorizontalAlignment','left',...
    'String','Display',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for adding event markers, On/Off button
hPanelEventMarkerAdd = uipanel('Parent',hPanelEventMarkers,...
    'Title','Add markers',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.02 0.51 0.40 0.42],...
    'BackgroundColor',panelColor);

% Button, Add event markers, On/Off
hButtonEventMarkerAddToggle = uicontrol('Parent',hPanelEventMarkerAdd,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.1,0.9,0.8],...
    'String','Off',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@eventAddMarkersToggleFunc);

% Sub-panel for event markers, description
hPanelEventMarkerDescription = uipanel('Parent',hPanelEventMarkers,...
    'Title','Description',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.02 0.02 0.96 0.42],...
    'BackgroundColor',panelColor);

% Text-edit for marker description
hEventMarkerDescription = uicontrol('Parent',hPanelEventMarkerDescription,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.75],...
    'String','',...
    'HorizontalAlignment','left',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',@eventMarkerDescriptionFcn);

% List of events, stored in the JSON file
hEventListBox = uicontrol('Parent',hPanelEventAnnotation,...
    'Style','listbox',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.05,0.555,0.9,0.205],...
    'Min',1,'Max',3,...
    'Value',[],...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',@eventsListBoxFcn);

% Sub-panel for editing and saving marker list
hPanelEventMarkerEditSave = uipanel('Parent',hPanelEventAnnotation,...
    'Title','Delete/Edit a marker, Save list',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.46 0.9 0.085],...
    'BackgroundColor',panelColor);

% Button, Delete selected marker from list
hButtonEventMarkerDel = uicontrol('Parent',hPanelEventMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.30,0.8],...
    'String','Delete',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@eventMarkerDelFunc);

% Button, Edit selected marker from list
hButtonEventMarkerEdit = uicontrol('Parent',hPanelEventMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.345,0.1,0.30,0.8],...
    'String','Edit',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@eventMarkerEditFunc);

% Button, Save marker list
hButtonEventMarkerSave = uicontrol('Parent',hPanelEventMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.67,0.1,0.30,0.8],...
    'String','Save',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@eventMarkerSaveFunc);

%% -----Panel: ECGkit Analysis-----

% create a parent panel for filter functionality sub-panels
hPanelParentECGkitAnalysis = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons to navigate and export features from the data
hPanelECGkitAnalysis = uipanel('Parent',hPanelParentECGkitAnalysis,...
    'Title','ECGkit Analysis',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Sub-panel for adding and editing ECGkit analysis-markers
hPanelECGkitMarkers = uipanel('Parent',hPanelECGkitAnalysis,...
    'Title','In-Out markers',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.67 0.9 0.32],...
    'BackgroundColor',panelColor);

% Checkbox, toggles display of In-Out markers
hAnalysisMarkersCheckbox = uicontrol('Parent',hPanelECGkitMarkers,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.745,0.075,0.25],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitShowMarkersFcn);

% Text label, for display of In-Out markers
uicontrol('Parent',hPanelECGkitMarkers,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.73,0.85,0.19],...
    'HorizontalAlignment','left',...
    'String','Display',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for In-Out markers, On/Off button
hPanelECGkitMarkerAdd = uipanel('Parent',hPanelECGkitMarkers,...
    'Title','Add markers',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.02 0.68 0.40 0.29],...
    'BackgroundColor',panelColor);

% Button, Add In-Out markers, On/Off
hButtonECGkitMarkerAddToggle = uicontrol('Parent',hPanelECGkitMarkerAdd,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.1,0.9,0.8],...
    'String','Off',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitAddMarkersToggleFunc);

% Sub-panel for In-Out markers, description
hPanelECGkitMarkerDescription = uipanel('Parent',hPanelECGkitMarkers,...
    'Title','Description',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.02 0.35 0.96 0.29],...
    'BackgroundColor',panelColor);

% Text-edit for marker description
hECGkitMarkerDescription = uicontrol('Parent',hPanelECGkitMarkerDescription,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.75],...
    'String','',...
    'HorizontalAlignment','left',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',@ecgkitMarkerDescriptionFcn);

% Sub-panel for In-Out markers, Out-marker
hPanelECGkitMarkerOut = uipanel('Parent',hPanelECGkitMarkers,...
    'Title','Out-marker (+ h,m,s from In-marker)',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.02 0.03 0.96 0.29],...
    'BackgroundColor',panelColor);

% Button, Add Out-marker
hButtonECGkitMarkerOut = uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.37,0.8],...
    'String','Out',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitOutMarkerFunc);

% Text-edit for Out-marker hours
hECGkitMarkerOutHrs = uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.48,0.1,0.10,0.8],...
    'String','',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, Marker-out hours
uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.59,0.09,0.05,0.7],...
    'HorizontalAlignment','left',...
    'String','h',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Out-marker minutes
hECGkitMarkerOutMin = uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.65,0.1,0.10,0.8],...
    'String','',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, Marker-out minutes
uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.09,0.05,0.7],...
    'HorizontalAlignment','left',...
    'String','m',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Out-marker seconds
hECGkitMarkerOutSec = uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.82,0.1,0.10,0.8],...
    'String','',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, Marker-out seconds
uicontrol('Parent',hPanelECGkitMarkerOut,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.93,0.09,0.05,0.7],...
    'HorizontalAlignment','left',...
    'String','s',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% List of marker in-out points. A default 'Displayed range' will always
% appear in the list (and is not a saved/editable in-out marker)
hECGkitListBox = uicontrol('Parent',hPanelECGkitAnalysis,...
    'Style','listbox',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.05,0.445,0.9,0.205],...
    'Min',1,'Max',3,...
    'String',{'Displayed range'},...
    'Value',1,...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',@ecgkitListBoxFcn);

% Sub-panel for editing and saving marker list
hPanelECGkitMarkerEditSave = uipanel('Parent',hPanelECGkitAnalysis,...
    'Title','Delete/Edit a range, Save list',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.35 0.9 0.085],...
    'BackgroundColor',panelColor);

% Button, Delete selected In-Out-marker from list
hButtonECGkitMarkerDel = uicontrol('Parent',hPanelECGkitMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.30,0.8],...
    'String','Delete',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitMarkerDelFunc);

% Button, Edit selected In-Out-marker from list
hButtonECGkitMarkerEdit = uicontrol('Parent',hPanelECGkitMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.345,0.1,0.30,0.8],...
    'String','Edit',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitMarkerEditFunc);

% Button, Save In-Out-marker list
hButtonECGkitMarkerSave = uicontrol('Parent',hPanelECGkitMarkerEditSave,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.67,0.1,0.30,0.8],...
    'String','Save',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitMarkerSaveFunc);

% Sub-panel for selecting ECG channels to analyse
hPanelECGanalysis = uipanel('Parent',hPanelECGkitAnalysis,...
    'Title','ECG channels',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.26 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG1 analysis
hAnalyseEcg1Checkbox = uicontrol('Parent',hPanelECGanalysis,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG1 analysis
uicontrol('Parent',hPanelECGanalysis,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.1,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 1',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG2 analysis
hAnalyseEcg2Checkbox = uicontrol('Parent',hPanelECGanalysis,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG2 analysis
uicontrol('Parent',hPanelECGanalysis,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.43,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 2',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG3 analysis
hAnalyseEcg3Checkbox = uicontrol('Parent',hPanelECGanalysis,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG3 analysis
uicontrol('Parent',hPanelECGanalysis,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 3',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for generating ECGkit analysis and report of currently displayed data
hPanelECGkitGenReport = uipanel('Parent',hPanelECGkitAnalysis,...
    'Title','Analyse and Report',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.08 0.9 0.17],...
    'BackgroundColor',panelColor);

% Checkbox, make pdf
hECGkitMakePDFCheckbox = uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.03,0.6,0.075,0.26],...
    'Value',1,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, make pdf
uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.11,0.6,0.4,0.23],...
    'HorizontalAlignment','left',...
    'String','Make PDF',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, open pdf
hECGkitOpenPDFCheckbox = uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.6,0.075,0.26],...
    'Value',1,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, open pdf
uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.425,0.6,0.4,0.23],...
    'HorizontalAlignment','left',...
    'String','Open PDF',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, Generate report
hButtonECGkitGenReport = uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.45],...
    'String','Analyse selected',...
    'FontSize',10,...
    'Enable','off',...
    'Callback',@genECGkitAnalyseFunc);

% Text label, informing about the necessity of reportScripts and ECGkit
if ~exist([cortrium_matlab_scripts_root_path filesep 'reportScripts'],'dir')
    uicontrol('Parent',hPanelECGkitAnalysis,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.05,0.01,0.9,0.06],...
    'HorizontalAlignment','left',...
    'String',sprintf('NOTE: Requires report scripts and ECGkit!'),...
    'FontWeight','normal',...
    'ForegroundColor',[0.9 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);
end

%% -----Panel: Miscellaneous Plots-----

% create a parent panel for filter functionality sub-panels
hPanelParentOptionalPlots = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons to navigate and export features from the data
hPanelOptionalPlots = uipanel('Parent',hPanelParentOptionalPlots,...
    'Title','Miscellaneous Plots',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Checkbox, save images
hSaveImagesCheckbox = uicontrol('Parent',hPanelOptionalPlots,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.05,0.95,0.075,0.04],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for Save Images
uicontrol('Parent',hPanelOptionalPlots,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.11,0.95,0.4,0.0325],...
    'HorizontalAlignment','left',...
    'String','Save images',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio buttons group, select whether export will be of displayed range or entire length of recording
hOptPlotRangeButtonGroup = uibuttongroup('Parent',hPanelOptionalPlots,...
    'Units','normalized',...
    'Position',[0.05,0.86,0.9,0.08],...
    'BackgroundColor',panelColor,...
    'Title','Range');

% Radio button, displayed range
hOptPlotRangeButton1 = uicontrol(hOptPlotRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Displayed',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, full length
hOptPlotRangeButton2 = uicontrol(hOptPlotRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Full recording',...
    'Units','normalized',...
    'Position',[0.35,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hOptPlotRangeButtonGroup,'selectedobject',hOptPlotRangeButton1);

% Sub-panel for ECG FFT
hPanelECGFFT = uipanel('Parent',hPanelOptionalPlots,...
    'Title','ECG FFT',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.75 0.9 0.1],...
    'BackgroundColor',panelColor);

% Button, FFT
hButtonFFT = uicontrol('Parent',hPanelECGFFT,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.9],...
    'String','ECG FFT',...
    'FontSize',10,...
    'Enable','on',...
    'Callback',@fftFunc);

% Sub-panel for Histogram of Acceleration magnitude
hPanelAccMag = uipanel('Parent',hPanelOptionalPlots,...
    'Title','Acceleration histograms',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.49 0.9 0.25],...
    'BackgroundColor',panelColor);

% Text label, Bin count for Mag
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.73,0.2,0.18],...
    'HorizontalAlignment','left',...
    'String','Bin count:',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for bin count of Accel mag histogram
hAccMagHistBinCount = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.22,0.76,0.12,0.19],...
    'String','101',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, Mag Lim
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.445,0.73,0.205,0.18],...
    'HorizontalAlignment','right',...
    'String','Mag limit:',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Min Mag Lim of Accel mag histogram
hAccMagHistXLimMin = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.66,0.76,0.12,0.19],...
    'String','0.0',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, -
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.79,0.73,0.04,0.18],...
    'HorizontalAlignment','center',...
    'String','-',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Max Mag Lim of Accel mag histogram
hAccMagHistXLimMax = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.84,0.76,0.12,0.19],...
    'String','2.0',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, Bin count for Mag
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.47,0.2,0.18],...
    'HorizontalAlignment','left',...
    'String','Bin count:',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for bin count of Accel XYZ histogram
hAccXYZHistBinCount = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.22,0.5,0.12,0.19],...
    'String','101',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, XYZ Lim
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.435,0.47,0.215,0.18],...
    'HorizontalAlignment','right',...
    'String','XYZ limit:',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Min XYZ Lim of Accel histogram
hAccXYZHistXLimMin = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.66,0.5,0.12,0.19],...
    'String','-2.0',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, -
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.79,0.47,0.04,0.18],...
    'HorizontalAlignment','center',...
    'String','-',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit for Max XYZ Lim of Accel histogram
hAccXYZHistXLimMax = uicontrol('Parent',hPanelAccMag,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.84,0.5,0.12,0.19],...
    'String','2.0',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Button, Accel mag histogram
hButtonAccMag = uicontrol('Parent',hPanelAccMag,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.04,0.96,0.31],...
    'String','Accel histograms',...
    'FontSize',10,...
    'Enable','on',...
    'Callback',@accMagFunc);


%% -----Panel: Export-----

% create a parent panel for export sub-panels
hPanelParentExport = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);


% create a panel for buttons to navigate and export features from the data
hPanelExport = uipanel('Parent',hPanelParentExport,...
    'Title','Export',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Sub-panel for selecting ECG channels to export
hPanelECGexport = uipanel('Parent',hPanelExport,...
    'Title','ECG channels',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.91 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG1 export
hExportEcg1Checkbox = uicontrol('Parent',hPanelECGexport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG1 export
uicontrol('Parent',hPanelECGexport,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.1,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 1',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG2 export
hExportEcg2Checkbox = uicontrol('Parent',hPanelECGexport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG2 export
uicontrol('Parent',hPanelECGexport,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.43,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 2',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG3 export
hExportEcg3Checkbox = uicontrol('Parent',hPanelECGexport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.075,0.9],...
    'Value',0,...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text label, for ECG3 export
uicontrol('Parent',hPanelECGexport,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.76,0.08,0.15,0.7],...
    'HorizontalAlignment','left',...
    'String','ECG 3',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio buttons group, select whether export will be of displayed range or entire length of recording
hExportRangeButtonGroup = uibuttongroup('Parent',hPanelExport,...
    'Units','normalized',...
    'Position',[0.05,0.82,0.9,0.08],...
    'BackgroundColor',panelColor,...
    'Title','Range');

% Radio button, displayed range
hExportRangeButton1 = uicontrol(hExportRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Displayed',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, full length
hExportRangeButton2 = uicontrol(hExportRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Full recording',...
    'Units','normalized',...
    'Position',[0.35,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hExportRangeButtonGroup,'selectedobject',hExportRangeButton1);

% Sub-panel for exporting ECG to MIT-BIH format (.dat, .hea)
hPanelECGMITexport = uipanel('Parent',hPanelExport,...
    'Title','ECG to MIT-BIH (.dat, .hea)',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.71 0.9 0.1],...
    'BackgroundColor',panelColor);

% Button, Export
hButtonExportECGtoMIT = uicontrol('Parent',hPanelECGMITexport,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.85],...
    'String','Export ECG to MIT',...
    'FontSize',10,...
    'Enable','off',...
    'Callback',@exportECGtoMITfilesFunc);

% Sub-panel for exporting ECG to CSV
hPanelECGCSVexport = uipanel('Parent',hPanelExport,...
    'Title','ECG to CSV',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.6 0.9 0.1],...
    'BackgroundColor',panelColor);

% Button, Export
hButtonExportECGtoCSV = uicontrol('Parent',hPanelECGCSVexport,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.85],...
    'String','Export ECG to CSV',...
    'FontSize',10,...
    'Enable','off',...
    'Callback',@exportECGtoCSVfileFunc);

%% -----Popup menu, for selecting functionality panels-----

hParentPanels = [hPanelParentFiltering,hPanelParentEventAnnotation,hPanelParentECGkitAnalysis,hPanelParentOptionalPlots,hPanelParentExport];

% Popup menu, for selecting functionality panels
hPopupPanel = uicontrol('Parent',hPanelMain,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.84,0.49,0.15,0.05],...
    'String',  {'Filtering',...
                'Event Markers',...
                'ECGkit Analysis',...
                'Miscellaneous Plots',...
                'Export'},...
    'FontSize',10,...
    'Callback',{@functionalityPopup,hParentPanels});
hPopupPanel.Value = 1;

%% -----Panel: Sensor Samples Display-----

% create a panel for data visualization
hPanelSensorDisplay = uipanel('Parent',hPanelMain,...
    'Title','Sensor Data Display',...
    'BorderType','line',...
    'HighlightColor',panelBorderColor,...
    'Position',[0.01 0.01 0.82 0.98],...
    'BackgroundColor',panelColor);

% Axes object for Event Markers plot, behind of ECG axes
% object, otherwise exact same position.
hAxesEventMarkers = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19]);
xlim(hAxesEventMarkers,'manual');
ylim(hAxesEventMarkers,'manual');
hold(hAxesEventMarkers,'on');
set(hAxesEventMarkers,'Xticklabel',[]);
set(hAxesEventMarkers,'Yticklabel',[]);
hAxesEventMarkers.TickLength = [0 0];
hAxesEventMarkers.YLim = [0 1];

% Axes object for Report Markers plot, behind of ECG axes
% object, otherwise exact same position.
hAxesECGMarkers = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none');
xlim(hAxesECGMarkers,'manual');
ylim(hAxesECGMarkers,'manual');
hold(hAxesECGMarkers,'on');
set(hAxesECGMarkers,'Xticklabel',[]);
set(hAxesECGMarkers,'Yticklabel',[]);
hAxesECGMarkers.TickLength = [0 0];
hAxesECGMarkers.YLim = [0 1];

% Axes object for ECG plot
hAxesECG = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none');
xlim(hAxesECG,'manual');
%ylim(hAxesECG,'manual');
hold(hAxesECG,'on');
set(hAxesECG,'FontSize',8);
set(hAxesECG,'ButtonDownFcn',@onClickAxes);
hAxesECG.TickLength = [0.005 0.025];

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
    'ForegroundColor',colorGreen,...
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
    'Position',[0.045,0.535,0.9,0.19]);
xlim(hAxesResp,'manual');
% ylim(hAxesResp,'manual');
hold(hAxesResp,'on');
set(hAxesResp,'FontSize',8);
set(hAxesResp,'ButtonDownFcn',@onClickAxes);
hAxesResp.TickLength = [0.005 0.025];

% Axes for Text overlay on Resp plot
hAxesRespText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.7025,0.025,0.0175], 'Visible', 'off');
hTxtResp = text(0.992, 0.98, 'Resp', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesRespText);
hTxtResp.BackgroundColor = whiteTransp;

% Button, Create Respiration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.7,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @respWinFunc);

% Button, toggles Respiration plot
hRespCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.67,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@respPlotFunc);

% Text label, for Respiration toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.67,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Resp',...
    'FontWeight','normal',...
    'ForegroundColor',[1.0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Axes object for Acceleration plot
hAxesAccel = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.285,0.9,0.19]);
xlim(hAxesAccel,'manual');
% ylim(hAxesAccel,'manual');
hold(hAxesAccel,'on');
set(hAxesAccel,'FontSize',8);
set(hAxesAccel,'ButtonDownFcn',@onClickAxes);
hAxesAccel.TickLength = [0.005 0.025];

% Axes for Text overlay on Accel plot
hAxesAccelText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.4525,0.025,0.0175], 'Visible', 'off');
hTxtAccel = text(0.992, 0.98, 'Accel', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesAccelText);
hTxtAccel.BackgroundColor = whiteTransp;

% Button, Create Acceleration plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.45,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @accelWinFunc);

% Button, toggles Accel_X plot
hAccelXCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.42,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_X toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.42,0.04,0.018],...
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
    'Position',[0.946,0.399,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_Y toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.399,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Accel_Y',...
    'FontWeight','normal',...
    'ForegroundColor',colorGreen,...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, toggles Accel_Z plot
hAccelZCheckbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.378,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_Z toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.378,0.04,0.018],...
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
    'Position',[0.946,0.357,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@accelPlotFunc);

% Text label, for Accel_magnitude toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.357,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Magnitude',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Axes object for Temperature plot
hAxesTemp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.04,0.9,0.19]);
xlim(hAxesTemp,'manual');
% ylim(hAxesTemp,'manual');
hold(hAxesTemp,'on');
set(hAxesTemp,'FontSize',8);
set(hAxesTemp,'ButtonDownFcn',@onClickAxes);
hAxesTemp.TickLength = [0.005 0.025];

% Axes for Text overlay on Temp plot
hAxesTempText = axes('Parent', hPanelSensorDisplay, 'Position', [0.915,0.2075,0.025,0.0175], 'Visible', 'off');
hTxtTemp = text(0.992, 0.98, 'Temp', 'Units','normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', 'Parent', hAxesTempText);
hTxtTemp.BackgroundColor = whiteTransp;

% dummy axes, bug fix for Temp Axes text disappearing when plotting
axes('Parent', hPanelSensorDisplay, 'Position', [0.001,0.001,0.01,0.01], 'Visible', 'off');

% Button, Create Temperature plot in a new window
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.205,0.015,0.022],...
    'String','^',...
    'FontSize',12,...
    'Callback', @tempWinFunc);

% Button, toggles Temperature_1 plot
hTemp1Checkbox = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.946,0.175,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@tempPlotFunc);

% Text label, for Temperature_1 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.175,0.04,0.018],...
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
    'Position',[0.946,0.154,0.015,0.022],...
    'Value',1,...
    'BackgroundColor',panelColor,...
    'Callback',@tempPlotFunc);

% Text label, for Temperature_2 toggle button
uicontrol('Parent',hPanelSensorDisplay,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.957,0.154,0.04,0.018],...
    'HorizontalAlignment','left',...
    'String','Surface',...
    'FontWeight','normal',...
    'ForegroundColor',colorGreen,...
    'FontSize',8,...
    'BackgroundColor',panelColor);

%% -----Cortrium logo-----

% create a panel for Cortrium logo
hPanelLogo = uipanel('Parent',hPanelMain,...
    'BorderType','none',... %
    'Units','normalized',...
    'Position',[0.766 0.966 0.055 0.031],...
    'BackgroundColor',panelColor);

% load Cortrium logo image
logo_cortrium_path = [cortrium_matlab_scripts_root_path filesep 'bin' filesep 'Cortrium_logo_w_pod_187x55px.png'];
if exist(logo_cortrium_path, 'file') == 2
    [logoCortriumImgData.img, logoCortriumImgData.map, logoCortriumImgData.alpha] = imread(logo_cortrium_path);
else
    warning(['No Cortrium logo file at: ' logo_cortrium_path]);
    logoCortriumImgData = [];
end

% create axes object for Cortrium logo image
imgHeightToWidthRatio = double(size(logoCortriumImgData.img,1))/double(size(logoCortriumImgData.img,2));
imgWidth = 3.2; % normalized units
imgHeight = imgWidth * imgHeightToWidthRatio;
hAxImg = axes('Parent', hPanelLogo, 'Units', 'normalized', 'Position', [-1.08, 0.02, imgWidth, imgHeight]);
% show the image and set alpha for transparent background
hImg = imshow(logoCortriumImgData.img, logoCortriumImgData.map, 'InitialMagnification', 'fit', 'Parent', hAxImg);
hImg.AlphaData = logoCortriumImgData.alpha;
% hAxImg.Visible = 'off';

%% get actual screen size and set figure window accordingly

% get screen size
screenSize = get(0,'screensize');
screenWidth = screenSize(3);
screenHeight = screenSize(4);
set(hFig,'Position', [1 1 screenWidth screenHeight]);

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
        switch fileFormat
            % if selected file format is BIN, open dialog to select a folder
            case 'BIN (folder)'
                pathName = uigetdir;
            % if selected file format is BLE (24bit or 16bit), open dialog to select a .BLE file
            otherwise
                [fileName,pathName] = uigetfile('*.BLE');
        end
        
        if pathName % if a directory was selected
            switch fileFormat
                case 'BIN (folder)'
                    full_path = [pathName filesep '*.bin'];
                otherwise
                    full_path = [pathName fileName];
            end
            % clear axes before displaying new data
            clearAxes([hAxesEventMarkers,hAxesECGMarkers,hAxesECG hAxesResp hAxesAccel hAxesTemp]);
            drawnow;
            eventAddMarkersOffOnLoad;
            ecgkitAddMarkersOffOnLoad;
            reportIOmarkers = [];
            eventMarkers = [];
            if hParentPanels(3).Visible
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,0);
            end
            if hParentPanels(2).Visible
                updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
            end
            disableButtons(hButtonEventMarkerAddToggle,hButtonECGkitMarkerAddToggle,hButtonECGkitMarkerOut,hButtonECGkitMarkerDel,hButtonECGkitMarkerEdit,hButtonECGkitMarkerSave);
            gS.dataLoaded = loadAndFormatData;
            if gS.dataLoaded
                % resetting end times
                timeEnd.world = [];
                timeEnd.duration = [];
                % resetting ECG flip checkboxes
                deselectButtons(hFlipEcg1Checkbox,hFlipEcg2Checkbox,hFlipEcg3Checkbox);
                gS.flipEcg1 = false;
                gS.flipEcg2 = false;
                gS.flipEcg3 = false;
                sourceName = updateDirectoryInfo(full_path,jsondata);
                setRecordingTimeInfo(C3,hTextTimeRecording);
                timeBase = getTimeBase(hTimebaseButtonGroup,hLabelTimeDisplayed);
                [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd);
                [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
                outputRecordingStats;
                if hParentPanels(3).Visible
                    updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,0);
                end
                if hParentPanels(2).Visible
                    updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
                end
                plotSensorData;
                enableButtons(hPopupRange,hRangeButton,hButtonExportECGtoMIT,hButtonExportECGtoCSV,hButtonECGkitGenReport);
                enableButtons(hButtonEventMarkerAddToggle,hButtonEventMarkerDel,hButtonEventMarkerEdit,hButtonEventMarkerSave,hButtonECGkitMarkerAddToggle,hButtonECGkitMarkerOut,hButtonECGkitMarkerDel,hButtonECGkitMarkerEdit,hButtonECGkitMarkerSave);
            end
        end
    end

    function dataLoaded = loadAndFormatData()
        hTic_loadAndFormatData = tic;
        % load JSON file, if any
        json_fullpath = '';
        jsondata = struct([]);
        switch fileFormat
            case 'BIN (folder)'
                listjson = dir([pathName filesep '*.JSON']);
                % if only one JSON file exist in this directory, load it
                if size(listjson,1) == 1
                    json_fullpath = [pathName filesep listjson(1).name];
                    jsondata = loadjson(json_fullpath);
                % else,if more than 1 JSON file is present, warn
                elseif size(listjson,1) > 1
                    warndlg(sprintf('More than one JSON file present in folder!\nAuto-loading of JSON was skipped.'));
                end
            otherwise
                [~,filename_wo_extension,~] = fileparts(fileName);
                if exist([pathName filename_wo_extension '.JSON'], 'file') == 2
                    json_fullpath = [pathName filename_wo_extension '.JSON'];
                    jsondata = loadjson(json_fullpath);
                end
        end
        eventMarkers = initializEventMarkers(jsondata,eventMarkers);
        reportIOmarkers = initializeReportIOmarkers(jsondata,reportIOmarkers);
        
        dataLoaded = false;
        % Create a new C3 object
        C3 = cortrium_c3(pathName);
        switch fileFormat
            % if selected file format is BLE 24bit
            case 'BLE 24bit'
                hTic_readFile = tic;
                % Initialise components
                C3.initializeForBLE24bit;
                % load and assign data from .BLE file, 24bit version
                [C3.serialNumber, conf, serial_ADS, C3.leadoff, C3.accel.dataRaw, C3.temp.dataRaw,  C3.resp.dataRaw, C3.ecg.dataRaw, ecg_serials] = c3_read_ble_24bit(full_path);
                C3.accel.samplenum = length(C3.accel.dataRaw);
                C3.temp.samplenum = length(C3.temp.dataRaw);
                C3.resp.samplenum = length(C3.resp.dataRaw);
                C3.ecg.samplenum = length(C3.ecg.dataRaw);
                [~,ble_filename_wo_extension,~] = fileparts([pathName filesep fileName]);
                % if there's jsondata available and there's a 'start' field, then that is prioritised to indicate start of recording
                if ~isempty(jsondata) && isfield(jsondata,'start') && ~isempty(jsondata.start)
                    C3.date_start = datenum(datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC'));
                % if no jsondata, then try using the filename to indicate start of recording, with the assumption that the filename is a HEX posixtime value
                elseif all(ismember(ble_filename_wo_extension, '1234567890abcdefABCDEF')) && length(ble_filename_wo_extension) < 9
                    C3.date_start = datenum(datetime(hex2dec(ble_filename_wo_extension), 'ConvertFrom', 'posixtime', 'TimeZone', 'local'));
                % if none of the above were an option, then set the start time as follows
                else
                    C3.date_start = datenum(datetime('0001-01-01T00:00:00.000+0000','InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC'));
                end
                C3.date_end = addtodate(C3.date_start, C3.ecg.samplenum*1000/C3.ecg.fs, 'millisecond');
                C3.missingSerials = find(C3.serialNumber == 0);
                dataLoaded = true;
                fprintf('Read BLE 24bit file: %f seconds\n',toc(hTic_readFile));
            % if selected file format is BLE 16bit
            case 'BLE 16bit'
                hTic_readFile = tic;
                % Initialise components
                C3.initializeForBLE16bit;
                % load and assign data from .BLE file, 16bit version
                [C3.serialNumber, C3.leadoff, C3.accel.dataRaw, C3.temp.dataRaw, C3.resp.dataRaw, C3.ecg.dataRaw] = c3_read_ble(full_path);
                C3.accel.samplenum = length(C3.accel.dataRaw);
                C3.temp.samplenum = length(C3.temp.dataRaw);
                C3.resp.samplenum = length(C3.resp.dataRaw);
                C3.ecg.samplenum = length(C3.ecg.dataRaw);
                [~,ble_filename_wo_extension,~] = fileparts([pathName filesep fileName]);
                % if there's jsondata available and there's a 'start' field, then that is prioritised to indicate start of recording
                if ~isempty(jsondata) && isfield(jsondata,'start') && ~isempty(jsondata.start)
                    C3.date_start = datenum(datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC'));
                % if no jsondata, then try using the filename to indicate start of recording, with the assumption that the filename is a HEX posixtime value
                elseif all(ismember(ble_filename_wo_extension, '1234567890abcdefABCDEF')) && length(ble_filename_wo_extension) < 9
                    C3.date_start = datenum(datetime(hex2dec(ble_filename_wo_extension), 'ConvertFrom', 'posixtime', 'TimeZone', 'local'));
                % if none of the above were an option, then set the start time as follows
                else
                    C3.date_start = datenum(datetime('0001-01-01T00:00:00.000+0000','InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC'));
                end
                C3.date_end = addtodate(C3.date_start, C3.ecg.samplenum*1000/C3.ecg.fs, 'millisecond');
                C3.missingSerials = find(C3.serialNumber == 0);
                dataLoaded = true;
                fprintf('Read BLE 16bit file: %f seconds\n',toc(hTic_readFile));
            % if selected file format is BIN
            otherwise
                if ~isempty(dir([pathName '\*.bin']))
                    hTic_readFile = tic;
                    % Initialise components and load data from .bin files
                    C3.initialize;
                    C3.leadoff = zeros(1, C3.temp.samplenum);
                    fileName = '*.bin';
                    C3.ecg.dataRaw = C3.ecg.data;
                    C3.accel.dataRaw = C3.accel.data;
                    C3.resp.dataRaw = C3.resp.data;
                    C3.temp.dataRaw = C3.temp.data;
                    dataLoaded = true;
                    fprintf('Read BIN files: %f seconds\n',toc(hTic_readFile));
                else
                    warndlg('No .bin files in this directory!');
                    return;
                end
        end
        
        % Set samplingRateFactor. The base frequency is assumed to be that of the Accelerometer signal.
        switch fileFormat
            case 'BLE 24bit'
                sampleRateFactor.ECG = 6;
                sampleRateFactor.Resp = 1;
                sampleRateFactor.Accel = 1;
                sampleRateFactor.Temp = 0.5;
            otherwise
                sampleRateFactor.ECG = 10;
                sampleRateFactor.Resp = 10;
                sampleRateFactor.Accel = 1;
                sampleRateFactor.Temp = 1;
        end
        
        % Warn about sample count mismatch
        switch fileFormat
            % if selected file format is BLE 24bit
            case 'BLE 24bit'
                if (C3.ecg.samplenum ~= C3.accel.samplenum*sampleRateFactor.ECG) && (abs(C3.accel.samplenum - 2*C3.temp.samplenum) <= 1)
                    warndlg(sprintf('Sample count mismatch!\nECG should be x6 the sample count of Accel.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                elseif (abs(C3.accel.samplenum - 2*C3.temp.samplenum) > 1) && (C3.ecg.samplenum == C3.accel.samplenum*sampleRateFactor.ECG)
                    warndlg(sprintf('Sample count mismatch!\nAccel should be x2 the sample count of Temp.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                elseif (C3.accel.samplenum ~= C3.resp.samplenum) && (C3.resp.samplenum ~= 0)
                    warndlg(sprintf('Sample count mismatch!\nAccel and Resp sample count should be identical.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                end
            otherwise
                if (C3.ecg.samplenum ~= C3.accel.samplenum*sampleRateFactor.ECG) && (C3.accel.samplenum == C3.temp.samplenum)
                    warndlg(sprintf('Sample count mismatch!\nECG and Resp should be x10 the sample count of Accel and Temp.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                elseif (C3.accel.samplenum ~= C3.temp.samplenum) && (C3.ecg.samplenum == C3.accel.samplenum*sampleRateFactor.ECG)
                    warndlg(sprintf('Sample count mismatch!\nAccel and Temp sample count should be identical.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                elseif (C3.accel.samplenum ~= C3.temp.samplenum) && (C3.ecg.samplenum ~= C3.accel.samplenum*sampleRateFactor.ECG)
                    warndlg(sprintf('Sample count mismatch!\nECG and Resp should be x10 the sample count of Accel and Temp,\nand Accel and Temp sample count should be identical.\n\nECG: %d\nResp: %d\nAccel: %d\nTemp: %d',C3.ecg.samplenum, C3.resp.samplenum, C3.accel.samplenum, C3.temp.samplenum));
                end
        end
        
        % disable checkboxes for missing ecg channels
        if isempty(C3.ecg.dataRaw)
            numEcgChannels = 0;
        else
            numEcgChannels = size(C3.ecg.dataRaw,2);
        end
        if numEcgChannels == 3
            enableButtons(hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,hFlipEcg1Checkbox,hFlipEcg2Checkbox,hFlipEcg3Checkbox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox);
        elseif numEcgChannels == 2
            enableButtons(hECG1Checkbox,hECG2Checkbox,hExportEcg1Checkbox,hExportEcg2Checkbox,hFlipEcg1Checkbox,hFlipEcg2Checkbox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox);
            disableButtons(hECG3Checkbox,hExportEcg3Checkbox,hFlipEcg3Checkbox,hAnalyseEcg3Checkbox);
            deselectButtons(hECG3Checkbox,hExportEcg3Checkbox,hAnalyseEcg3Checkbox);
        elseif numEcgChannels == 1
            enableButtons(hECG1Checkbox,hExportEcg1Checkbox,hFlipEcg1Checkbox,hAnalyseEcg1Checkbox);
            disableButtons(hECG2Checkbox,hECG3Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,hFlipEcg2Checkbox,hFlipEcg3Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox);
            deselectButtons(hECG2Checkbox,hECG3Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox);
        else
            disableButtons(hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,hFlipEcg1Checkbox,hFlipEcg2Checkbox,hFlipEcg3Checkbox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox);
            deselectButtons(hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox);
        end
        
        % disable checkbox for Resp plot, if no data
        if isempty(C3.resp.dataRaw)
            hRespCheckbox.Value = 0;
            hRespCheckbox.Enable = 'off';
            set(hAxesResp,'Xticklabel',[]);
        else
            hRespCheckbox.Enable = 'on';
        end
        
        % calculate Accel magnitude
        C3.accelmag.dataRaw = sqrt(sum(C3.accel.dataRaw.^2,2));
        
        % Prepare lead-off for GUI view
        C3.ecg.leadoff = double(C3.leadoff);
        C3.ecg.leadoff(C3.ecg.leadoff == 0) = NaN;
        C3.ecg.leadoff = (C3.ecg.leadoff-10000);
        % "upsample" to match ecg signal with 10 ecg samples per packet
        C3.ecg.leadoff = reshape(repmat(C3.ecg.leadoff', round(C3.ecg.fs/C3.accel.fs), 1), [], 1);
        
        % Initialize filtering checkboxes, based on what options the
        % current fileFormat offers (e.g. 16bit ECG and Resp data from C3 
        % already has highpass filtering, therefore it can not be disabled).
        initializeFilterSelections(fileFormat, hPopupEcgHighPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox);
        
        %----- FILTERING -----%        
        % Filter the data (or leave raw) depending on the selected filter checkboxes
        initializeFiltering(C3, fileFormat, hPopupEcgHighPass, hPopupEcgLowPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox, hEcgNanAccMagCheckbox, hEcgNanMinAccMag, hEcgNanMaxAccMag, hEcgNanAbsEcgCheckbox, hEcgNanAbsEcg, hEcgNanAccMagWinSize, hEcgAbsValWinSize);
        
        fprintf('loadAndFormatData: %f seconds\n',toc(hTic_loadAndFormatData));
    end

    function outputRecordingStats()
        fprintf('==========================================================\n');
        fprintf('== Recording stats                                      ==\n');
        fprintf('==========================================================\n');
        fprintf('Filename: %s\n', fileName);
        if ~isempty(jsondata)
            if isfield(jsondata, 'softwareversion')
                fprintf('FW ver: %s\n', jsondata.softwareversion);
            end
            if isfield(jsondata, 'hardwareversion')
                fprintf('HW ver: %s\n', jsondata.hardwareversion);
            end
            if isfield(jsondata, 'deviceid')
                fprintf('Device ID: %s\n', jsondata.deviceid);
            end
            if isfield(jsondata, 'start')
                fprintf('Recording start: %s\n', jsondata.start);
            end
            fprintf('Recording end: %s\n', 'Unknown');
            fprintf('Recording duration: %s\n', 'Unknown');
        end
        fprintf('==========================================================\n');
        fprintf('Total packets (length serial): %i Missing packets: %i\n', length(C3.serialNumber),length(C3.missingSerials));
        fprintf('Number of packets flagged as "Lead off": %i\n', sum(C3.leadoff ~= 0));
        fprintf('==========================================================\n');
        % this part only makes sense if we are dealing with 16bit ECG samples
        if ~strcmp(fileFormat,'BLE 24bit')
            fprintf('Error code stats for all channels (total samples: %i)\n', length(C3.ecg.data'));
            fprintf('ECG Error Code (any error)         : %i\n',               length(find(abs(C3.ecg.data') >= 32765))),
            fprintf('ECG Sample max value (ecg = 32767) : %i\n',               length(find(C3.ecg.data' == 32767)))
            fprintf('ECG Sample min value (ecg = -32765): %i\n',               length(find(C3.ecg.data' == -32765)))
            fprintf('ECG Filter error (ecg = -32766)    : %i\n',               length(find(C3.ecg.data' == -32766)))
            fprintf('ECG Lead off (ecg = -32767)        : %i\n',               length(find(C3.ecg.data' == -32767)))
            fprintf('ECG Comm error (ecg = -32768)      : %i\n',               length(find(C3.ecg.data' == -32768)))
            fprintf('==========================================================\n');
        end
        table(unique(C3.leadoff), histc(C3.leadoff(:),unique(C3.leadoff)), round(double(histc(C3.leadoff(:),unique(C3.leadoff))./double(length(C3.leadoff))*100)), 'VariableNames',{'Lead_off_val' 'Count' 'Percent'})
    end

    function plotSensorData()
        %         linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'off');
        plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
        plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox)
        plotResp(C3,rangeStartIndex.Resp,rangeEndIndex.Resp,xAxisTimeStamps,timeBase,hAxesResp,hRespCheckbox);
        plotAccel(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox);
        plotTemp(C3,rangeStartIndex.Temp,rangeEndIndex.Temp,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
        %         linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'x');
%                 fprintf('PLOT:\n');
%                 fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
%                 fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
%                 fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
%                 fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
    end

    function onClickAxes(hAx, ~)
        point1 = get(hAx,'CurrentPoint'); % corner where rectangle starts ( initial mouse down point )
        rbbox
        point2 = get(hAx,'CurrentPoint'); % corner where rectangle stops ( when user lets go of mouse )
%         fprintf('point1:\n%f %f %f\n%f %f %f\n',point1(1,1),point1(1,2),point1(1,3),point1(2,1),point1(2,2),point1(2,3));
%         fprintf('point2:\n%f %f %f\n%f %f %f\n',point2(1,1),point2(1,2),point2(1,3),point2(2,1),point2(2,2),point2(2,3));
%         fprintf('xMin, xMax, yMin, yMax:\n%f %f\n%f %f\n',xMin,xMax,yMin,yMax);
        % if single click
        if point1(1,1) == point2(1,1)
            if gS.dataLoaded && gS.ecgMarkerMode
                [gS,reportIOmarkers] = addReportMarker(C3,point1(1,1),xAxisTimeStamps,timeBase,gS,reportIOmarkers,hECGkitMarkerDescription,hECGkitListBox,hButtonECGkitMarkerSave,editColorGreen);
                if ~gS.ecgInpointSet
                    plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
                end
            elseif gS.dataLoaded && gS.eventMarkerMode
                [gS,eventMarkers] = addEventMarker(point1(1,1),xAxisTimeStamps,timeBase,gS,eventMarkers,hEventMarkerDescription,hEventListBox,hButtonEventMarkerSave,editColorGreen,sampleRateFactor);
                plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
            end
        % if click and drag
        else
            % Define min and max x and y values
            xMin = min([point1(1,1), point2(1,1)]);
            xMax = max([point1(1,1), point2(1,1)]);
%             yMin = min([point1(1,2), point2(1,2)]);
%             yMax = max([point1(1,2), point2(1,2)]);
            % find corresponding data indices
            [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,xMin,xMax,sampleRateFactor);
            setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
            enableButtons(hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            % update range info text
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            plotSensorData;
        end
    end

    function rangeSliderFcn(hRangeSlider, ~)
        currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
        rangeStartIndex.Accel = round(hRangeSlider.Value) - round(currentRange * 0.5);
        rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
        [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
        rangeStartIndex.Accel = startIdx;
        rangeEndIndex.Accel = endIdx;
        rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
        rangeEndIndex.Temp = min(length(C3.temp.data), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
        rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
        rangeEndIndex.ECG = min(length(C3.ecg.data), rangeEndIndex.Accel * sampleRateFactor.ECG);
        rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
        rangeEndIndex.Resp = min(length(C3.resp.data), rangeEndIndex.Accel * sampleRateFactor.Resp);
        % update range info text, and plot range
        setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
        plotSensorData;
        %         fprintf('Slider value: %f\n', hRangeSlider.Value);
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
                rangeStartIndex.Accel = round(eventECG_rowIdx(1)*(1/sampleRateFactor.ECG)) - round(currentRange * 0.5);
                rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
                [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
                rangeStartIndex.Accel = startIdx;
                rangeEndIndex.Accel = endIdx;
                rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
                rangeEndIndex.Temp = min(length(C3.temp.data), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
                rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
                rangeEndIndex.ECG = min(length(C3.ecg.data), rangeEndIndex.Accel * sampleRateFactor.ECG);
                rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
                rangeEndIndex.Resp = min(length(C3.resp.data), rangeEndIndex.Accel * sampleRateFactor.Resp);
                % update range info text, and plot range
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
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
                rangeStartIndex.Accel = round(eventECG_rowIdx(1)*(1/sampleRateFactor.ECG)) - round(currentRange * 0.5);
                rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
                [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.Accel, rangeEndIndex.Accel, C3.accel.samplenum);
                rangeStartIndex.Accel = startIdx;
                rangeEndIndex.Accel = endIdx;
                rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
                rangeEndIndex.Temp = min(length(C3.temp.data), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
                rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
                rangeEndIndex.ECG = min(length(C3.ecg.data), rangeEndIndex.Accel * sampleRateFactor.ECG);
                rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
                rangeEndIndex.Resp = min(length(C3.resp.data), rangeEndIndex.Accel * sampleRateFactor.Resp);
                % update range info text, and plot range
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
                plotSensorData;
            end
        end
    end

    function rangeButtonFcn(hButton, ~)
        takeAction = true;
        %if the 'Reset Range' button was clicked
        if strcmp(hButton.String,'Reset Range')
            [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            hPopupRange.Value = 1;
        % if not, then assume we want to set a specific range
        else
            % if item 2 ('1 sec') is selected
            if hPopupRange.Value == 2
                [rangeStartIndex, rangeEndIndex] = setRange(1, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % if item 3 ('2 sec') is selected
            elseif hPopupRange.Value == 3
                [rangeStartIndex, rangeEndIndex] = setRange(2, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % if item 4 ('5 sec') is selected
            elseif hPopupRange.Value == 4
                [rangeStartIndex, rangeEndIndex] = setRange(5, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % if item 5 ('10 sec') is selected
            elseif hPopupRange.Value == 5
                [rangeStartIndex, rangeEndIndex] = setRange(10, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % if item 6 ('30 sec') is selected
            elseif hPopupRange.Value == 6
                [rangeStartIndex, rangeEndIndex] = setRange(30, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % if item 7 ('1 min') is selected
            elseif hPopupRange.Value == 7
                [rangeStartIndex, rangeEndIndex] = setRange(60, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            else
                takeAction = false;
            end
            if takeAction
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                enableButtons(hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            end
        end
        % update range info text, and plot range
        if takeAction
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            plotSensorData;
        end
    end

    function timebaseSelectionFcn(varargin)
        % For now we just plot the data again, and let the plot functions
        % ask for the x-axis data. Would be more optimal to just replace
        % x-axis ticks.
        timeBase = getTimeBase(hTimebaseButtonGroup,hLabelTimeDisplayed);
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
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            if hParentPanels(3).Visible
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,hECGkitListBox.Value);
            end
            if hParentPanels(2).Visible
                updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
            end
            plotSensorData;
        end
    end

    function functionalityPopup(~,~,hParentPanels)
        % if item 1 ('Filtering') is selected
        if hPopupPanel.Value == 1
            hParentPanels(1).Visible = 'on';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
        % if item 2 ('Event Annotation') is selected
        elseif hPopupPanel.Value == 2
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'on';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
        % if item 3 ('ECGkit Analysis') is selected
        elseif hPopupPanel.Value == 3
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'on';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
        elseif hPopupPanel.Value == 4
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'on';
            hParentPanels(5).Visible = 'off';
        elseif hPopupPanel.Value == 5
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'on';
        end
    end

    function fileFormatSelectionFcn(varargin)
        fileFormat = getFileFormat(hFileFormatButtonGroup);
    end

    function sourceName = updateDirectoryInfo(full_path,jsondata)
        if isempty(jsondata)
            jsonDataAvailable = '';
        else
            jsonDataAvailable = ' (+JSON)';
        end
        dirNameParts = strsplit(full_path,filesep);
        switch fileFormat
            case 'BIN (folder)'
                sourceName = dirNameParts(length(dirNameParts)-1);
            otherwise
                sourceName = dirNameParts(length(dirNameParts));
        end
        set(hPanelSensorDisplay,'Title',strcat('File: ...', filesep, {' '}, dirNameParts(length(dirNameParts)-2), {' '}, filesep, {' '}, dirNameParts(length(dirNameParts)-1), {' '}, filesep, {' '}, dirNameParts(length(dirNameParts)), jsonDataAvailable));
    end

%% Functions for updating plots, based on checkbox selections
% (CLEAN UP) The callback from the buttons should be modified so they call
% the plot functions directly - not using this intermediate function.

    function ecgPlotFunc(varargin)
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox);
    end

    function respPlotFunc(varargin)
        plotResp(C3,rangeStartIndex.Resp,rangeEndIndex.Resp,xAxisTimeStamps,timeBase,hAxesResp,hRespCheckbox);
    end

    function accelPlotFunc(varargin)
        plotAccel(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox);
    end

    function tempPlotFunc(varargin)
        plotTemp(C3,rangeStartIndex.Temp,rangeEndIndex.Temp,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
    end

    % Intermediate callback function for filter checkboxes.
    % Apparently it was no trivial matter to pass a struct (C3) directly
    % from the calling uicontrol. Investigate further.
    function filterIntermediateToggleFunc(hUiCtrl, uiEventData, signalName)
        % if we have Accel data, then we have at least some other data too, and can proceed to filtering
        if size(C3.accel,1) ~= 0
            filterToggleFunc(hUiCtrl, uiEventData, C3, fileFormat, signalName, gS, hPopupEcgHighPass, hPopupEcgLowPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox, hEcgNanAccMagCheckbox, hEcgNanMinAccMag, hEcgNanMaxAccMag, hEcgNanAbsEcgCheckbox, hEcgNanAbsEcg, hEcgNanAccMagWinSize, hEcgAbsValWinSize);
            switch signalName
                case 'ecg'
                    ecgPlotFunc;
                case 'resp'
                    respPlotFunc;
                case 'accel'
                    accelPlotFunc;
                case 'temp'
                    tempPlotFunc;
            end
        end
    end

    function eventsShowMarkersFcn(~,~)
        if hEventMarkersCheckbox.Value == 1
            plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
        else
            cla(hAxesEventMarkers);
        end
    end

    function eventsListBoxFcn(~,~)
        plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
    end

    function eventAddMarkersToggleFunc(~,~)
        if strcmp(hButtonEventMarkerAddToggle.String,'On')
            gS.eventMarkerMode = false;
            hButtonEventMarkerAddToggle.String = 'Off';
            hButtonEventMarkerAddToggle.BackgroundColor = panelColor;
            hEventMarkerDescription.BackgroundColor = editColor;
        else
            gS.eventMarkerMode = true;
            hButtonEventMarkerAddToggle.String = 'On';
            hButtonEventMarkerAddToggle.BackgroundColor = editColorGreen;
            hEventMarkerDescription.BackgroundColor = editColorGreen;
            hButtonEventMarkerSave.BackgroundColor = editColorGreen;
            % trun ECGkit marker mode off, if Event marker mode is turned on
            if gS.ecgMarkerMode
                ecgkitAddMarkersToggleFunc;
            end
            if ~isempty(jsondata)
                if ~isfield(jsondata,'events')
                    jsondata.events = [];
                end
            else
                warndlg(sprintf(['No JSON data loaded! Can not save markers.\n\n',...
                'Event markers can still be  set in the current session.\n\n',...
                'If you want to be able to save markers, make sure\n',...
                'that an appropriate JSON file is present in the same directory\nas the sensor data file when loading.\n',...
                'For BLE-files the JSON should have the same name as the BLE.\nFor BIN-files the name can be arbitrary.']));
            end
        end
    end

    function eventMarkerDescriptionFcn(~,~)
        
    end

    function eventMarkerDelFunc(~,~)
        if ~isempty(eventMarkers) && ~isempty(hEventListBox.Value)
            % if the selection includes number 1 (the default 'Display range', then remove it from the deletion process.
            entriesForDeletion = hEventListBox.Value;
            deleteCount = length(entriesForDeletion);
            % if only one entry selected for deletion
            if deleteCount == 1
                eventMarkers(entriesForDeletion(1)) = [];
            % if multiple entry selected for deletion
            elseif deleteCount > 1
                for ii=1:deleteCount
                    % deleting from the buttom up
                    eventMarkers(entriesForDeletion(deleteCount+1-ii)) = [];
                end
            end
            updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,entriesForDeletion(1)-1);
            plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
            hButtonEventMarkerSave.BackgroundColor = editColorGreen;
        end
    end

    function eventMarkerEditFunc(~,~)
        if ~isempty(eventMarkers) && ~isempty(hEventListBox.Value)
            % Edit only one selection at a time.
            if length(hEventListBox.Value) == 1
                existingStr = eventMarkers(hEventListBox.Value).description;
                options.Resize='on';
                answer = inputdlg('Enter new description:','Edit selected entry',1,{existingStr},options);
                if ~isempty(answer)
                    eventMarkers(hEventListBox.Value).description = answer{1,1};
                    updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
                    hButtonEventMarkerSave.BackgroundColor = editColorGreen;
                end
            else
                warndlg('For editing, select only one entry from the list!');
            end
        end
    end

    function eventMarkerSaveFunc(~,~)
        if ~isempty(json_fullpath)
            % load the JSON again, so any recent saves (e.g. of report markers) are preserved
            jsondata = loadjson(json_fullpath);
            numMarkers = size(eventMarkers,2);
            jsondata.events = cell(1,numMarkers);
            for ii=1:numMarkers
                jsondata.events{1,ii}.eventid = eventMarkers(ii).eventid;
                jsondata.events{1,ii}.serial = eventMarkers(ii).serial;
                jsondata.events{1,ii}.eventname = eventMarkers(ii).description;
            end
            savejson('',jsondata,'FileName',json_fullpath,'ParseLogical',1);
            hButtonEventMarkerSave.BackgroundColor = panelColor;
        else
            warndlg('No JSON file was loaded! Can not save markers.');
        end
    end

    function eventAddMarkersOffOnLoad
            gS.eventMarkerMode = false;
            hButtonEventMarkerAddToggle.String = 'Off';
            hButtonEventMarkerAddToggle.BackgroundColor = panelColor;
            hEventMarkerDescription.BackgroundColor = editColor;
            hButtonEventMarkerSave.BackgroundColor = panelColor;
    end

    function ecgkitShowMarkersFcn(~,~)
        if hAnalysisMarkersCheckbox.Value == 1
            plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
        else
            cla(hAxesECGMarkers);
        end
    end

    function ecgkitAddMarkersToggleFunc(~,~)
        if strcmp(hButtonECGkitMarkerAddToggle.String,'On')
            gS.ecgMarkerMode = false;
            hButtonECGkitMarkerAddToggle.String = 'Off';
            hButtonECGkitMarkerAddToggle.BackgroundColor = panelColor;
            hECGkitMarkerDescription.BackgroundColor = editColor;
            hButtonECGkitMarkerOut.BackgroundColor = panelColor;
            hECGkitMarkerOutHrs.BackgroundColor = editColor;
            hECGkitMarkerOutMin.BackgroundColor = editColor;
            hECGkitMarkerOutSec.BackgroundColor = editColor;
            % make sure there's no In-point hanging, when turning off Add-markers mode
            if gS.ecgInpointSet
                numMarkers = size(reportIOmarkers,2);
                reportIOmarkers(numMarkers) = [];
                gS.ecgInpointSet = false;
            end
        else
            gS.ecgMarkerMode = true;
            hButtonECGkitMarkerAddToggle.String = 'On';
            hButtonECGkitMarkerAddToggle.BackgroundColor = editColorGreen;
            hECGkitMarkerDescription.BackgroundColor = editColorGreen;
            hButtonECGkitMarkerOut.BackgroundColor = editColorGreen;
            hECGkitMarkerOutHrs.BackgroundColor = editColorGreen;
            hECGkitMarkerOutMin.BackgroundColor = editColorGreen;
            hECGkitMarkerOutSec.BackgroundColor = editColorGreen;
            hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
            % trun Event marker mode off, if ECGkit marker mode is turned on
            if gS.eventMarkerMode
                eventAddMarkersToggleFunc;
            end
            if ~isempty(jsondata)
                if ~isfield(jsondata,'reportmarkers')
                    jsondata.reportmarkers = [];
                end
            else
                warndlg(sprintf(['No JSON data loaded! Can not save markers.\n\n',...
                'ECGkit analysis can still be performed within the markers you set\nin the current session.\n\n',...
                'If you want to be able to save markers, make sure\n',...
                'that an appropriate JSON file is present in the same directory\nas the sensor data file.\n',...
                'For BLE-files the JSON should have the same name as the BLE.\nFor BIN-files the name can be arbitrary.']));
            end
        end
    end

    function ecgkitAddMarkersOffOnLoad
            gS.ecgMarkerMode = false;
            hButtonECGkitMarkerAddToggle.String = 'Off';
            hButtonECGkitMarkerAddToggle.BackgroundColor = panelColor;
            hECGkitMarkerDescription.BackgroundColor = editColor;
            hButtonECGkitMarkerOut.BackgroundColor = panelColor;
            hECGkitMarkerOutHrs.BackgroundColor = editColor;
            hECGkitMarkerOutMin.BackgroundColor = editColor;
            hECGkitMarkerOutSec.BackgroundColor = editColor;
            hButtonECGkitMarkerSave.BackgroundColor = panelColor;
    end

    function ecgkitMarkerDescriptionFcn(~,~)
        
    end

    function ecgkitOutMarkerFunc(~,~)
        if all(ismember(hECGkitMarkerOutHrs.String, '1234567890')) && all(ismember(hECGkitMarkerOutMin.String, '1234567890')) && all(ismember(hECGkitMarkerOutSec.String, '1234567890'))
            if isempty(hECGkitMarkerOutHrs.String)
                deltaHMS(1) = 0;
            else
                deltaHMS(1) = str2double(hECGkitMarkerOutHrs.String);
            end
            if isempty(hECGkitMarkerOutMin.String)
                deltaHMS(2) = 0;
            else
                deltaHMS(2) = str2double(hECGkitMarkerOutMin.String);
            end
            if isempty(hECGkitMarkerOutSec.String)
                deltaHMS(3) = 0;
            else
                deltaHMS(3) = str2double(hECGkitMarkerOutSec.String);
            end
            [gS,reportIOmarkers] = addReportOutMarker(C3,deltaHMS,xAxisTimeStamps,timeBase,gS,reportIOmarkers,hECGkitMarkerDescription,hECGkitListBox,hButtonECGkitMarkerSave,editColorGreen);
            if ~gS.ecgInpointSet
                plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
            end
        else
            warndlg('Only integer numerical input accepted!');
        end        
    end

    function ecgkitListBoxFcn(~,~)
        plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
    end

    function ecgkitMarkerDelFunc(~,~)
        if ~isempty(reportIOmarkers) && ~isempty(hECGkitListBox.Value)
            % if the selection includes number 1 (the default 'Display range', then remove it from the deletion process.
            entriesForDeletion = hECGkitListBox.Value;
            entriesForDeletion(find(entriesForDeletion == 1,1)) = [];
            deleteCount = length(entriesForDeletion);
            % if only one entry selected for deletion
            if deleteCount == 1
                % remember, the indices of reportIOmarkers are offset by -1, relative to the listbox indices
                reportIOmarkers(entriesForDeletion(1)-1) = [];
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,entriesForDeletion(1)-1);
                plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
                hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
            % if multiple entry selected for deletion
            elseif deleteCount > 1
                for ii=1:deleteCount
                    % remember, the indices of reportIOmarkers are offset by -1, relative to the listbox indices
                    reportIOmarkers(entriesForDeletion(deleteCount+1-ii)-1) = [];
                end
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,entriesForDeletion(1)-1);
                plotECGMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
                hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
            end
        end
    end

    function ecgkitMarkerEditFunc(~,~)
        if ~isempty(reportIOmarkers) && ~isempty(hECGkitListBox.Value)
            % Edit only one selection at a time. The top entry, 'Displayed range', can not be edited.
            if length(hECGkitListBox.Value) == 1 && hECGkitListBox.Value(1) ~= 1
                existingStr = reportIOmarkers(hECGkitListBox.Value-1).description;
                options.Resize='on';
                answer = inputdlg('Enter new description:','Edit selected entry',1,{existingStr},options);
                if ~isempty(answer)
                    reportIOmarkers(hECGkitListBox.Value-1).description = answer{1,1};
                    updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,hECGkitListBox.Value);
                    hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
                end
            elseif length(hECGkitListBox.Value) == 1 && hECGkitListBox.Value(1) == 1
                warndlg('''Displayed range'' is a default, non-editable entry!');
            else
                warndlg('For editing, select only one entry from the list!');
            end
        end
    end

    function ecgkitMarkerSaveFunc(~,~)
        if ~isempty(json_fullpath)
            % load the JSON again, so any recent saves (e.g. of event markers) are preserved
            jsondata = loadjson(json_fullpath);
            numMarkers = size(reportIOmarkers,2);
            jsondata.reportmarkers = cell(1,numMarkers);
            for ii=1:numMarkers
                jsondata.reportmarkers{1,ii}.inecgindex = reportIOmarkers(ii).inEcgIndex;
                jsondata.reportmarkers{1,ii}.outecgindex = reportIOmarkers(ii).outEcgIndex;
                jsondata.reportmarkers{1,ii}.name = reportIOmarkers(ii).description;
            end
            savejson('',jsondata,'FileName',json_fullpath,'ParseLogical',1);
            hButtonECGkitMarkerSave.BackgroundColor = panelColor;
        else
            warndlg('No JSON file was loaded! Can not save markers.');
        end
    end

    function genECGkitAnalyseFunc(~,~)
        genECGkitReport(C3,sampleRateFactor,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,reportIOmarkers,jsondata,hECGkitListBox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,hECGkitMakePDFCheckbox,hECGkitOpenPDFCheckbox,full_path,fileFormat);
    end

    function exportECGtoMITfilesFunc(~,~)
        if strcmp(get(get(hExportRangeButtonGroup,'selectedobject'),'String'),'Displayed')
            rangeStr = 'displayed';
        else
            rangeStr = 'full';
        end
        exportECGtoMITfiles(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path,rangeStr,'export',fileFormat);
    end

    function exportECGtoCSVfileFunc(~,~)
        exportECGtoCSVfile(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hExportRangeButtonGroup,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path);
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
        hECGFig = figure('Numbertitle','off','Name',['ECG   Source: ' char(sourceName)],'OuterPosition', [winXpos winYpos winWidth winHeight]); %,'Visible','off'
        hAxesECGWindow = axes('Parent',hECGFig,'Position',[0.06,0.09,0.9,0.85], 'Box', 'on');
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
            if get(hECGleadoffCheckbox, 'Value') == 1 % if checkbox for ECGleadoff is ON
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.leadoff(rangeStartIndex.ECG:rangeEndIndex.ECG),'Color',[0.5 0.5 0.5],'LineWidth',7);
                legendList(length(legendList)+1) = {' Lead off'};
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
                plot(hAxesECGWindow,xAxisTimeStamp(rangeStartIndex.ECG:rangeEndIndex.ECG),C3.ecg.leadoff(rangeStartIndex.ECG:rangeEndIndex.ECG),'Color',[0.5 0.5 0.5],'DurationTickFormat',durTickForm,'LineWidth',7);
                legendList(length(legendList)+1) = {' Lead off'};
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
        hRespFig = figure('Numbertitle','off','Name',['Respiration   Source: ' char(sourceName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesRespWindow = axes('Parent',hRespFig,'Position',[0.06,0.09,0.9,0.85], 'Box', 'on');
        hold on;
        if strcmp(timeBase,'World')
            if get(hRespCheckbox, 'Value') == 1 % if checkbox for Resp is ON
                plot(hAxesRespWindow,xAxisTimeStamp(rangeStartIndex.Resp:rangeEndIndex.Resp),C3.resp.data(rangeStartIndex.Resp:rangeEndIndex.Resp),'Color','r',plotOptions);
            end
        else
            if get(hRespCheckbox, 'Value') == 1 % if checkbox for Resp is ON
                plot(hAxesRespWindow,xAxisTimeStamp(rangeStartIndex.Resp:rangeEndIndex.Resp),C3.resp.data(rangeStartIndex.Resp:rangeEndIndex.Resp),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
            end
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
        winXpos = 0;%round(screenSize(3)*0.05)
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.3);
        winWidth = round(screenSize(3));%*0.5
        winHeight = round(screenSize(4)*0.5);
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Accel');
        plotOptions = getPlotOptions(timeBase);
        hAccelFig = figure('Numbertitle','off','Name',['Acceleration   Source: ' char(sourceName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesAccelWindow = axes('Parent',hAccelFig,'Position',[0.025,0.09,0.96,0.85], 'Box', 'on'); % [0.025,0.09,0.96,0.85]  %[0.06,0.09,0.9,0.85]
        hold on;
        % build a cell array for the plot legend, and plot according to selected checkboxes
        legendList = cell(0);
        if strcmp(timeBase,'World')
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r',plotOptions);
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],plotOptions);
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b',plotOptions);
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accelmag.data(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k',plotOptions);
                legendList(length(legendList)+1) = {'magnitude'};
            end
        else
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),1),'Color','r','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Accel\_X'};
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),2),'Color', [0.0 0.85 0.0],'DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Accel\_Y'};
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accel.data((rangeStartIndex.Accel:rangeEndIndex.Accel),3),'Color','b','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'Accel\_Z'};
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                plot(hAxesAccelWindow,xAxisTimeStamp(rangeStartIndex.Accel:rangeEndIndex.Accel),C3.accelmag.data(rangeStartIndex.Accel:rangeEndIndex.Accel),'Color','k','DurationTickFormat','hh:mm:ss',plotOptions);
                legendList(length(legendList)+1) = {'magnitude'};
            end
        end
        title('Acceleration','FontSize',12,'FontWeight','bold');
        hAxesAccelWindow.XLim = [datenum(xAxisTimeStamp(rangeStartIndex.Accel)) datenum(xAxisTimeStamp(rangeEndIndex.Accel))];
        xlabel(['time (' timeBase ')'],'FontSize',10);
        ylabel('g-force','FontSize',10);
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
        hTempFig = figure('Numbertitle','off','Name',['Temperature   Source: ' char(sourceName)], 'OuterPosition', [winXpos winYpos winWidth winHeight]);
        hAxesTempWindow = axes('Parent',hTempFig,'Position',[0.06,0.09,0.9,0.85], 'Box', 'on');
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
        ylabel('degrees Celsius','FontSize',10);
        legend(hAxesTempWindow,legendList);
        set(hAxesTempWindow,'FontSize',10);
        %hTempFig.Visible = 'on';
    end

    function fftFunc(~,~)
        fftEcgNewWindow(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hOptPlotRangeButtonGroup,gS,full_path);
    end

    function accMagFunc(~,~)
        accHistNewWindow(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hOptPlotRangeButtonGroup,gS,hAccMagHistBinCount,hAccMagHistXLimMin,hAccMagHistXLimMax,hAccXYZHistBinCount,hAccXYZHistXLimMin,hAccXYZHistXLimMax,full_path,jsondata);
    end

    function flipEcgFunc(hUiCtrl, ~, ecgCh)
        if ecgCh == 1 && hUiCtrl.Value == 1
            gS.flipEcg1 = true;
            C3.ecg.data(:,1) = C3.ecg.data(:,1) - (2 * C3.ecg.data(:,1));
        elseif ecgCh == 1 && hUiCtrl.Value == 0
            gS.flipEcg1 = false;
            C3.ecg.data(:,1) = C3.ecg.data(:,1) - (2 * C3.ecg.data(:,1));
        end
        if ecgCh == 2 && hUiCtrl.Value == 1
            gS.flipEcg2 = true;
            C3.ecg.data(:,2) = C3.ecg.data(:,2) - (2 * C3.ecg.data(:,2));
        elseif ecgCh == 2 && hUiCtrl.Value == 0
            gS.flipEcg2 = false;
            C3.ecg.data(:,2) = C3.ecg.data(:,2) - (2 * C3.ecg.data(:,2));
        end
        if ecgCh == 3 && hUiCtrl.Value == 1
            gS.flipEcg3 = true;
            C3.ecg.data(:,3) = C3.ecg.data(:,3) - (2 * C3.ecg.data(:,3));
        elseif ecgCh == 3 && hUiCtrl.Value == 0
            gS.flipEcg3 = false;
            C3.ecg.data(:,3) = C3.ecg.data(:,3) - (2 * C3.ecg.data(:,3));
        end
        ecgPlotFunc;
    end

    function resizeFcn(varargin)
        % Is called when the GUI window is created, and when resized.
        % Might be used later to implement changing font size depending on
        % GUI window size, since all other elements are relatively sized.
        currFigPos = get(hFig,'Position');
        figWidth = currFigPos(3);
        figHeight = currFigPos(4);
%         disp(['Figure pos: ' num2str(currFigPos(1)) ' ' num2str(currFigPos(2)) ' ' num2str(figWidth) ' ' num2str(figHeight)]);
    end

    function closeRequestFcn(varargin)
        fclose all;
        closereq; % Close the GUI Window
    end
end

%% Functions (Work in progress... moving inline functions outside of main function.)
function plotECGMarkers(startIdx,endIdx,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS)
    cla(hAxesECGMarkers);
    if ~isempty(reportIOmarkers)
        if hAnalysisMarkersCheckbox.Value == 1
            if gS.ecgInpointSet
                numMarkers = size(reportIOmarkers,2) - 1;
            else
                numMarkers = size(reportIOmarkers,2);
            end
            selectedMakers = hECGkitListBox.Value - 1;
            if ~isempty(selectedMakers)
                if selectedMakers(1) == 0
                    selectedMakers(1) = [];
                end
            end
            nonSelectedMarkers = 1:numMarkers;
            nonSelectedMarkers(selectedMakers) = [];
            hAxesECGMarkers.XLim = [startIdx endIdx];
            for ii=1:length(selectedMakers)
                plot(hAxesECGMarkers, [reportIOmarkers(selectedMakers(ii)).inEcgIndex reportIOmarkers(selectedMakers(ii)).inEcgIndex], [0 1], 'Color', min(gS.colors.col{8}*1.5,1), 'LineWidth', 1.5, 'LineStyle', ':');
                plot(hAxesECGMarkers, [reportIOmarkers(selectedMakers(ii)).outEcgIndex reportIOmarkers(selectedMakers(ii)).outEcgIndex], [0 1], 'Color', min(gS.colors.col{8}*1.5,1), 'LineWidth', 1.5, 'LineStyle', ':');
            end
            for ii=1:length(nonSelectedMarkers)
                plot(hAxesECGMarkers, [reportIOmarkers(nonSelectedMarkers(ii)).inEcgIndex reportIOmarkers(nonSelectedMarkers(ii)).inEcgIndex], [0 1], 'Color', gS.colors.col{8}, 'LineWidth', 1.5, 'LineStyle', ':');
                plot(hAxesECGMarkers, [reportIOmarkers(nonSelectedMarkers(ii)).outEcgIndex reportIOmarkers(nonSelectedMarkers(ii)).outEcgIndex], [0 1], 'Color', gS.colors.col{8}, 'LineWidth', 1.5, 'LineStyle', ':');
            end
            % add numbers for markers
            outLabelOffset = round((endIdx - startIdx) * 0.009);
            for ii=1:length(selectedMakers)
                text(reportIOmarkers(selectedMakers(ii)).inEcgIndex, 0.075, sprintf('%02d',selectedMakers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', min(gS.colors.col{8}*1.5,1), 'Color', gS.colors.col{5}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesECGMarkers);
                text(reportIOmarkers(selectedMakers(ii)).outEcgIndex-outLabelOffset, 0.075, sprintf('%02d',selectedMakers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', min(gS.colors.col{8}*1.5,1), 'Color', gS.colors.col{5}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesECGMarkers);
            end
            for ii=1:length(nonSelectedMarkers)
                text(reportIOmarkers(nonSelectedMarkers(ii)).inEcgIndex, 0.075, sprintf('%02d',nonSelectedMarkers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', gS.colors.col{8}, 'Color', gS.colors.col{5}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesECGMarkers);
                text(reportIOmarkers(nonSelectedMarkers(ii)).outEcgIndex-outLabelOffset, 0.075, sprintf('%02d',nonSelectedMarkers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', gS.colors.col{8}, 'Color', gS.colors.col{5}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesECGMarkers);
            end

        end
    end
end

function plotEventMarkers(startIdx,endIdx,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS)
    cla(hAxesEventMarkers);
    if hEventMarkersCheckbox.Value == 1 && ~isempty(eventMarkers)
        numMarkers = size(eventMarkers,2);
        selectedMakers = hEventListBox.Value;
        nonSelectedMarkers = 1:numMarkers;
        nonSelectedMarkers(selectedMakers) = [];
        hAxesEventMarkers.XLim = [startIdx endIdx];
        for ii=1:length(selectedMakers)
            plot(hAxesEventMarkers, [eventMarkers(selectedMakers(ii)).serial eventMarkers(selectedMakers(ii)).serial], [0 1], 'Color', min(gS.colors.col{7}*1.3,1), 'LineWidth', 1.5, 'LineStyle', ':');
        end
        for ii=1:length(nonSelectedMarkers)
            plot(hAxesEventMarkers, [eventMarkers(nonSelectedMarkers(ii)).serial eventMarkers(nonSelectedMarkers(ii)).serial], [0 1], 'Color', gS.colors.col{7}, 'LineWidth', 1.5, 'LineStyle', ':');
        end
        % add numbers for markers
        for ii=1:length(selectedMakers)
            text(eventMarkers(selectedMakers(ii)).serial, 0.075, sprintf('%02d',selectedMakers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', min(gS.colors.col{7}*1.3,1), 'Color', gS.colors.col{4}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesEventMarkers);
        end
        for ii=1:length(nonSelectedMarkers)
            text(eventMarkers(nonSelectedMarkers(ii)).serial, 0.075, sprintf('%02d',nonSelectedMarkers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', gS.colors.col{7}, 'Color', gS.colors.col{4}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesEventMarkers);
        end
    end
end

function plotECG(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox)
if sum(size(C3.ecg)) ~= 0
    % clear the plot, then create new plot
    cla(hAxesECG);
    if (hECG1Checkbox.Value == 1) || (hECG2Checkbox.Value == 1) || (hECG3Checkbox.Value == 1) || (hECGleadoffCheckbox.Value == 1)
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'ECG');
        plotOptions = getPlotOptions(timeBase);
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
    end
end
end

function plotResp(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesResp,hRespCheckbox)
if get(hRespCheckbox, 'Value') == 1 % if checkbox for Resp is ON
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
else
    cla(hAxesResp);
end
end

function plotAccel(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox)
if sum(size(C3.accel)) ~= 0
    cla(hAxesAccel);
    if (hAccelXCheckbox.Value == 1) || (hAccelYCheckbox.Value == 1) || (hAccelZCheckbox.Value == 1) || (hAccelMagnitudeCheckbox.Value == 1)
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Accel');
        plotOptions = getPlotOptions(timeBase);
        if strcmp(timeBase,'World')
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,1),'Color','r',plotOptions);
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],plotOptions);
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,3),'Color','b',plotOptions);
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accelmag.data(startIdx:endIdx),'Color','k',plotOptions);
            end
        else
            durTickForm = getDurationTickFormat(startIdx, endIdx, C3.accel.fs);
            if get(hAccelXCheckbox, 'Value') == 1 % if checkbox for Accel_X ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,1),'Color','r','DurationTickFormat',durTickForm,plotOptions);
            end
            if get(hAccelYCheckbox, 'Value') == 1 % if checkbox for Accel_Y ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,2),'Color', [0.0 0.85 0.0],'DurationTickFormat',durTickForm,plotOptions);
            end
            if get(hAccelZCheckbox, 'Value') == 1 % if checkbox for Accel_Z ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accel.data(startIdx:endIdx,3),'Color','b','DurationTickFormat',durTickForm,plotOptions);
            end
            if get(hAccelMagnitudeCheckbox, 'Value') == 1 % if checkbox for magnitude ON
                plot(hAxesAccel,xAxisTimeStamp(startIdx:endIdx),C3.accelmag.data(startIdx:endIdx),'Color','k','DurationTickFormat',durTickForm,plotOptions);
            end
        end
        hAxesAccel.XLim = [datenum(xAxisTimeStamp(startIdx)) datenum(xAxisTimeStamp(endIdx))];
    end
end
end

function plotTemp(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox)
if sum(size(C3.temp)) ~= 0
    cla(hAxesTemp);
    if (hTemp1Checkbox.Value == 1) || (hTemp2Checkbox.Value == 1)
        xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'Temp');
        plotOptions = getPlotOptions(timeBase);
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
    end
    xlabel(hAxesTemp,['time (' timeBase ')'],'FontSize',10);
end
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

function [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,startTime,endTime,sampleRateFactor)
% This function finds the index numbers that most closely corresponds
% to the given datetime input. This is to handle output from rbbox
% (rubber band box selections), which does not return actual plot point
% values, but interpolated values from the plot figure.
% hTic_getRangeIndices = tic;
if strcmp(timeBase,'World')
    % search for index of value closest to given time, in the Accel data,
    % which has a lower sampling rate than the ECG signal.
    startIdx = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(startTime), 1)) - 1;
    endIdx = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(endTime), 1));
    rangeStartIndex.Accel = max(1,startIdx);
    if isempty(endIdx)
        rangeEndIndex.Accel = length(xAxisTimeStamps.world.Accel);
    else
        rangeEndIndex.Accel = endIdx - 1;
    end
    % Now use this index for the remaining channels, by factoring with sampleRateFactor
    rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
    rangeEndIndex.Temp = min(length(xAxisTimeStamps.world.Temp), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
    rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
    rangeEndIndex.ECG = min(length(xAxisTimeStamps.world.ECG), rangeEndIndex.Accel * sampleRateFactor.ECG);
    rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
    rangeEndIndex.Resp = min(length(xAxisTimeStamps.world.Resp), rangeEndIndex.Accel * sampleRateFactor.Resp);
else
    % search for index of value closest to given time, in the Accel data,
    % which has a lower sampling rate than the ECG signal.
    startIdx = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(startTime), 1)) - 1;
    endIdx = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(endTime), 1));
    rangeStartIndex.Accel = max(1,startIdx);
    if isempty(endIdx)
        rangeEndIndex.Accel = length(xAxisTimeStamps.duration.Accel);
    else
        rangeEndIndex.Accel = endIdx - 1;
    end
    % Now use this index for the remaining channels, by factoring with sampleRateFactor
    rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
    rangeEndIndex.Temp = min(length(xAxisTimeStamps.duration.Temp), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
    rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
    rangeEndIndex.ECG = min(length(xAxisTimeStamps.duration.ECG), rangeEndIndex.Accel * sampleRateFactor.ECG);
    rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
    rangeEndIndex.Resp = min(length(xAxisTimeStamps.duration.Resp), rangeEndIndex.Accel * sampleRateFactor.Resp);
end
% fprintf('\n');
% fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
% fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
% fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
% fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
% fprintf('getRangeIndices: %f seconds\n',toc(hTic_getRangeIndices));
end

function accelIndex = getAccelIndexPoint(xAxisTimeStamps,timeBase,timePoint)
% This function finds the Accel index number that most closely corresponds to the given time input.
if strcmp(timeBase,'World')
    % search for index of value closest to given time, in the ECG data,
    accelIndex = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(timePoint), 1)) - 1;
else
    % search for index of value closest to given time, in the Accel data,
    % which has a lower sampling rate than the ECG signal.
    accelIndex = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(timePoint), 1)) - 1;
end
end

function ecgIndex = getEcgIndexPoint(xAxisTimeStamps,timeBase,timePoint)
% This function finds the ECG index number that most closely corresponds to the given time input.
% hTic_getEcgIndexPoint = tic;
if strcmp(timeBase,'World')
    % search for index of value closest to given time, in the ECG data,
    ecgIndex = (find(datenum(xAxisTimeStamps.world.ECG) > datenum(timePoint), 1)) - 1;
else
    % search for index of value closest to given time, in the Accel data,
    % which has a lower sampling rate than the ECG signal.
    ecgIndex = (find(datenum(xAxisTimeStamps.duration.ECG) > datenum(timePoint), 1)) - 1;
end
% fprintf('getEcgPointIndex: %f seconds\n',toc(hTic_getEcgIndexPoint));
end

function setRecordingTimeInfo(C3,hTextTimeRecording)
    timeStart.world = datetime(C3.date_start, 'ConvertFrom', 'datenum');
    timeEnd.world = datetime(C3.date_end, 'ConvertFrom', 'datenum');
    set(hTextTimeRecording,'String',[datestr(timeStart.world, 'yyyy/mm/dd, HH:MM:SS') ' ' char(8211) ' ' datestr(timeEnd.world, 'yyyy/mm/dd, HH:MM:SS')]);
end

function setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed)
% Update the info-text that displays range start and end time
%     hTic_setRangeInfo = tic;
if strcmp(timeBase,'World')
    set(hTextTimeDisplayed,'String',[datestr(xAxisTimeStamps.world.Accel(rangeStartIndex.Accel), 'yyyy/mm/dd, HH:MM:SS') ' - ' datestr(xAxisTimeStamps.world.Accel(rangeEndIndex.Accel), 'yyyy/mm/dd, HH:MM:SS')]);
else
    [h,m,s] = hms([xAxisTimeStamps.duration.Accel(rangeStartIndex.Accel) xAxisTimeStamps.duration.Accel(rangeEndIndex.Accel)]);
    set(hTextTimeDisplayed,'String',[sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))) ' ' char(8211) ' ' sprintf('%02i:%02i:%02i',h(2),m(2),round(s(2)))]);
end
%     fprintf('setRangeInfo: %f seconds\n',toc(hTic_setRangeInfo));
end

function rangeStr = getRangeStrForFileName(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,signalName)
% Update the info-text that displays range start and end time
if strcmp(timeBase,'World')
    if strcmp(signalName,'ECG')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.ECG(rangeStartIndex) xAxisTimeStamps.world.ECG(rangeEndIndex)]);
    elseif strcmp(signalName,'Resp')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Resp(rangeStartIndex) xAxisTimeStamps.world.Resp(rangeEndIndex)]);
    elseif strcmp(signalName,'Accel')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Accel(rangeStartIndex) xAxisTimeStamps.world.Accel(rangeEndIndex)]);
    elseif strcmp(signalName,'Temp')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Temp(rangeStartIndex) xAxisTimeStamps.world.Temp(rangeEndIndex)]);
    end
    rangeStr = sprintf('%04d%02d%02dT%02d%02d%02d-%04d%02d%02dT%02d%02d%02d',Y(1),M(1),D(1),h(1),m(1),round(s(1)),Y(2),M(2),D(2),h(2),m(2),round(s(2)));
else
    if strcmp(signalName,'ECG')
        [h,m,s] = hms([xAxisTimeStamps.duration.ECG(rangeStartIndex) xAxisTimeStamps.duration.ECG(rangeEndIndex)]);
    elseif strcmp(signalName,'Resp')
        [h,m,s] = hms([xAxisTimeStamps.duration.Resp(rangeStartIndex) xAxisTimeStamps.duration.Resp(rangeEndIndex)]);
    elseif strcmp(signalName,'Accel')
        [h,m,s] = hms([xAxisTimeStamps.duration.Accel(rangeStartIndex) xAxisTimeStamps.duration.Accel(rangeEndIndex)]);
    elseif strcmp(signalName,'Temp')
        [h,m,s] = hms([xAxisTimeStamps.duration.Temp(rangeStartIndex) xAxisTimeStamps.duration.Temp(rangeEndIndex)]);
    end
    rangeStr = [sprintf('%02ih%02im%02is',h(1),m(1),round(s(1))) '-' sprintf('%02ih%02im%02is',h(2),m(2),round(s(2)))];
end
%     fprintf('rangeStr = %s\n',rangeStr);
end

function rangeStr = getRangeStrForPlotTitle(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,signalName)
% Update the info-text that displays range start and end time
if strcmp(timeBase,'World')
    if strcmp(signalName,'ECG')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.ECG(rangeStartIndex) xAxisTimeStamps.world.ECG(rangeEndIndex)]);
    elseif strcmp(signalName,'Resp')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Resp(rangeStartIndex) xAxisTimeStamps.world.Resp(rangeEndIndex)]);
    elseif strcmp(signalName,'Accel')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Accel(rangeStartIndex) xAxisTimeStamps.world.Accel(rangeEndIndex)]);
    elseif strcmp(signalName,'Temp')
        [Y,M,D,h,m,s] = datevec([xAxisTimeStamps.world.Temp(rangeStartIndex) xAxisTimeStamps.world.Temp(rangeEndIndex)]);
    end
    rangeStr = sprintf('%04d/%02d/%02d, %02d:%02d:%02d %s %04d/%02d/%02d, %02d:%02d:%02d',Y(1),M(1),D(1),h(1),m(1),round(s(1)),char(hex2dec('2013')),Y(2),M(2),D(2),h(2),m(2),round(s(2)));
else
    if strcmp(signalName,'ECG')
        [h,m,s] = hms([xAxisTimeStamps.duration.ECG(rangeStartIndex) xAxisTimeStamps.duration.ECG(rangeEndIndex)]);
    elseif strcmp(signalName,'Resp')
        [h,m,s] = hms([xAxisTimeStamps.duration.Resp(rangeStartIndex) xAxisTimeStamps.duration.Resp(rangeEndIndex)]);
    elseif strcmp(signalName,'Accel')
        [h,m,s] = hms([xAxisTimeStamps.duration.Accel(rangeStartIndex) xAxisTimeStamps.duration.Accel(rangeEndIndex)]);
    elseif strcmp(signalName,'Temp')
        [h,m,s] = hms([xAxisTimeStamps.duration.Temp(rangeStartIndex) xAxisTimeStamps.duration.Temp(rangeEndIndex)]);
    end
    rangeStr = [sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))) ' - ' sprintf('%02i:%02i:%02i (h:m:s)',h(2),m(2),round(s(2)))];
end
%     fprintf('rangeStr = %s\n',rangeStr);
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

function fileFormat = getFileFormat(hFileFormatButtonGroup)
fileFormat = get(get(hFileFormatButtonGroup,'selectedobject'),'String');
end

function timeBase = getTimeBase(hTimebaseButtonGroup,hLabelTimeDisplayed)
    timeBase = get(get(hTimebaseButtonGroup,'selectedobject'),'String');
    if strcmp(timeBase,'World')
        set(hLabelTimeDisplayed,'String','Displayed (world time):');
    else
        set(hLabelTimeDisplayed,'String','Displayed (duration):');
    end
end

function [rangeStartIndex, rangeEndIndex] = setRange(rangeSecs, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor)
centerIndex = round(rangeStartIndex.Accel + (rangeEndIndex.Accel - rangeStartIndex.Accel)*0.5);
startIdx  = round(centerIndex - (C3.accel.fs * rangeSecs * 0.5));
endIdx  = round(centerIndex + (C3.accel.fs * rangeSecs * 0.5)) - 1;
[startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, C3.accel.samplenum);
rangeStartIndex.Accel = startIdx;
rangeEndIndex.Accel = endIdx;
rangeStartIndex.Temp = floor((rangeStartIndex.Accel - 1) * sampleRateFactor.Temp) + 1;
rangeEndIndex.Temp = min(length(C3.temp.data), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
rangeStartIndex.ECG = ((rangeStartIndex.Accel - 1) * sampleRateFactor.ECG) + 1;
rangeEndIndex.ECG = min(length(C3.ecg.data), rangeEndIndex.Accel * sampleRateFactor.ECG);
rangeStartIndex.Resp = ((rangeStartIndex.Accel - 1) * sampleRateFactor.Resp) + 1;
rangeEndIndex.Resp = min(length(C3.resp.data), rangeEndIndex.Accel * sampleRateFactor.Resp);
%             fprintf('\n');
%             fprintf('ECG start: %d  end: %d\n',rangeStartIndex.ECG,rangeEndIndex.ECG);
%             fprintf('Resp start: %d  end: %d\n',rangeStartIndex.Resp,rangeEndIndex.Resp);
%             fprintf('Accel start: %d  end: %d\n',rangeStartIndex.Accel,rangeEndIndex.Accel);
%             fprintf('Temp start: %d  end: %d\n',rangeStartIndex.Temp,rangeEndIndex.Temp);
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

function ecgIndex = setEcgIndexWithinBounds(C3,ecgIndex)
    if ecgIndex < 1
        ecgIndex = 1;
    elseif ecgIndex > length(C3.ecg.data)
        ecgIndex = length(C3.ecg.data);
    end
end

function [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton)
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

function selectButtons(varargin)
for i=1:length(varargin)
    varargin{i}.Value = 1;
end
end

function disableButtons(varargin)
for i=1:length(varargin)
    varargin{i}.Enable = 'off';
end
end

function deselectButtons(varargin)
for i=1:length(varargin)
    varargin{i}.Value = 0;
end
end

function setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider)
currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
halfRange = round(currentRange * 0.5);
hRangeSlider.Min = halfRange;
hRangeSlider.Max = C3.accel.samplenum - halfRange;
minorstep = max(0.0000011, (currentRange + 1) / double(C3.accel.samplenum)); % slider minorstep must be > 0.000001
majorstep = minorstep * 10;
hRangeSlider.SliderStep = [minorstep majorstep];
sliderVal = rangeStartIndex.Accel + halfRange;
% fprintf('minorstep: %f    majorstep: %f\n',minorstep,majorstep);
% fprintf('Slider min: %d  max: %d  val: %d   minStep: %f  maxStep: %f\n',hRangeSlider.Min, hRangeSlider.Max, sliderVal, hRangeSlider.SliderStep(1), hRangeSlider.SliderStep(2));
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

function clearAxes(axesObjHandles)
    for ii=1:length(axesObjHandles)
        cla(axesObjHandles(ii));
%         axesObjHandles(ii).XLim = [0, 1/(24*60)];
    end
end

function initializeFilterSelections(fileFormat, hPopupEcgHighPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox)
    switch fileFormat
        case 'BLE 24bit'
            % enable all filter checkboxes for 24bit data, but leave selection as is
            hPopupEcgHighPass.String{1} = 'Highpass OFF';
            hRespHighpassCheckbox.Enable = 'on';
            hRespLowpassCheckbox.Enable = 'on';
            hAccelJitterCheckbox.Enable = 'on';
            hAccelMedianCheckbox.Enable = 'on';
            hTempJitterCheckbox.Enable = 'on';
            hEcgNanMissPackCheckbox.Enable = 'on';
            hEcgNanErrCodesCheckbox.Enable = 'off';
            hEcgNanErrCodesCheckbox.Value = 0;
        case 'BLE 16bit'
            % disable but select ECG and Resp Highpass filter checkboxes
            % for 16bit data (forcing them to stay selected, since we don't have the raw data anyway)
            hPopupEcgHighPass.String{1} = 'Highpass was already preapplied by C3';
            hPopupEcgHighPass.Value = 1;
            hRespHighpassCheckbox.Enable = 'off';
            hRespHighpassCheckbox.Value = 1;
            hRespLowpassCheckbox.Enable = 'on';
            hAccelJitterCheckbox.Enable = 'on';
            hAccelMedianCheckbox.Enable = 'on';
            hTempJitterCheckbox.Enable = 'on';
            hEcgNanMissPackCheckbox.Enable = 'on';
            hEcgNanErrCodesCheckbox.Enable = 'on';
        otherwise % folders with .bin-files (currently, 2016-02-29, that exclusively means 16bit ECG and Resp)
            % disable but select ECG and Resp Highpass filter checkboxes
            % for 16bit data (forcing them to stay selected, since we don't have the raw data anyway)
            hPopupEcgHighPass.String{1} = 'Highpass was already preapplied by C3';
            hPopupEcgHighPass.Value = 1;
            hRespHighpassCheckbox.Enable = 'off';
            hRespHighpassCheckbox.Value = 1;
            hRespLowpassCheckbox.Enable = 'on';
            hAccelJitterCheckbox.Enable = 'on';
            hAccelMedianCheckbox.Enable = 'on';
            hTempJitterCheckbox.Enable = 'on';
            % No info avialable about missing packets, when source is .bin-files
            hEcgNanMissPackCheckbox.Enable = 'off';
            hEcgNanMissPackCheckbox.Value = 0;
            hEcgNanErrCodesCheckbox.Enable = 'on';
    end
end

function initializeFiltering(C3, fileFormat, hPopupEcgHighPass, hPopupEcgLowPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox, hEcgNanAccMagCheckbox, hEcgNanMinAccMag, hEcgNanMaxAccMag, hEcgNanAbsEcgCheckbox, hEcgNanAbsEcg, hEcgNanAccMagWinSize, hEcgAbsValWinSize)
    switch fileFormat
        % 24bit data
        case 'BLE 24bit'
            %ECG
            C3.ecg.data = C3.ecg.dataRaw;
            % ECG highpass filter option
            if hPopupEcgHighPass.Value == 2
                hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filter(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 3
                hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filter(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 4
                hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 5
                hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 6
                hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 7
                hF = designfilt('highpassiir','FilterOrder',6,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 8
                hF = designfilt('highpassiir','FilterOrder',12,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 9
                hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.67,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            elseif hPopupEcgHighPass.Value == 10
                hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.67,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(hF,C3.ecg.data);
            end
            % Lowpass filtering
            if hPopupEcgLowPass.Value == 2
                Hd = Lowpass_FIR_max_flat_ord10_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 3
                Hd = Lowpass_FIR_max_flat_ord20_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 4
                Hd = Lowpass_FIR_max_flat_ord40_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 5
                Hd = Lowpass_FIR_max_flat_ord72_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 6
                Hd = Lowpass_FIR_win_cheby_ord100_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 7
                Hd = Lowpass_FIR_win_bartlethanning_ord100_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 8
                Hd = Lowpass_IIR_butterw_ord12_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 9
                d1 = designfilt('lowpassiir','FilterOrder',12,'HalfPowerFrequency',40,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(d1,C3.ecg.data);
            end
            % Replace with NaN
            if hEcgNanMissPackCheckbox.Value == 1 %NOTE: no good with .bin files, since serialNumber is not available!
                % calculate ECG indices of missed batches
                startOfMissed_ecgIdx = ((C3.missingSerials-1)*6)+1;
                endOfMissed_ecgIdx = C3.missingSerials*6;
                % get complete array of indices, by using coloncat function
                ecgIdx = coloncat(startOfMissed_ecgIdx, endOfMissed_ecgIdx);
                % set ECG to NaN at those indices
                C3.ecg.data(ecgIdx,:) = NaN;
            end
            if hEcgNanErrCodesCheckbox.Value == 1
                % Find error codes in the 'raw' data (since filtering may have modified the original error code values)
                C3.ecg.data(abs(C3.ecg.dataRaw) > 32765,:) = NaN;
            end
            if hEcgNanAbsEcgCheckbox.Value == 1
                absEcgVal = getFloatVal(hEcgNanAbsEcg);
                winSize = getIntVal(hEcgAbsValWinSize);
                if winSize < 3 || winSize >= length(C3.ecg.data)
                    warndlg(sprintf('Abs(ECG) window size must be > 2 and < %d\n\nSetting window size to 250',length(C3.ecg.data)));
                    hEcgAbsValWinSize.String = '250';
                    winSize = 250;
                end
                % create indices to match window size
                startIdxEcg = 1:winSize:length(C3.ecg.data);
                endIdxEcg = winSize:winSize:length(C3.ecg.data);
                % make sure the end index is included
                if length(endIdxEcg) == length(startIdxEcg)-1
                    endIdxEcg(length(endIdxEcg)+1) = length(C3.ecg.data);
                end
                % go through all windows to find those that meet the abs(value) criteria
                for ii=1:length(startIdxEcg)
                    if nanmax(nanmax(abs(C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:)))) > absEcgVal
                        % set ECG to NaN at those indices
                        C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:) = NaN;
                    end
                end
            end
            % RESP
            % if Resp data is available
            if ~isempty(C3.resp.dataRaw)
                C3.resp.data = C3.resp.dataRaw;
                % Resp highpass (baseline) option
                if hRespHighpassCheckbox.Value == 1
                    C3.resp.data = filterRespHighpass(C3);
                end
                % Resp lowpass (smoothing) option
                if hRespLowpassCheckbox.Value == 1
                    C3.resp.smoothen;
                end
            end
            % ACCEL
            C3.accel.data = C3.accel.dataRaw;
            C3.accelmag.data = C3.accelmag.dataRaw;
            % Accel jitter filter option
            if hAccelJitterCheckbox.Value == 1
                filter_length = 10;
                C3.accel.remove_jitter(filter_length);
                C3.accelmag.remove_jitter(filter_length);
            end
            % Accel median filter option
            if hAccelMedianCheckbox.Value == 1
                % Median filtering to remove impulse noise
                C3.accel.data = medfilt1(C3.accel.data,round(C3.accel.fs));
                C3.accelmag.data = medfilt1(C3.accelmag.data,round(C3.accelmag.fs));
            end
            % TEMP
            C3.temp.data = C3.temp.dataRaw;
            % Accel jitter filter option
            if hTempJitterCheckbox.Value == 1
                filter_length = 10;
                C3.temp.remove_jitter(filter_length);
            end
            % ECG NaN, based on Accel mag, placed here, after C3.accel.data is initialized
            if hEcgNanAccMagCheckbox.Value == 1
                minAccMag = getFloatVal(hEcgNanMinAccMag);
                maxAccMag = getFloatVal(hEcgNanMaxAccMag);
                winSize = getIntVal(hEcgNanAccMagWinSize);
                if winSize < 3 || winSize >= length(C3.accel.data)
                    warndlg(sprintf('Accel mag window size must be > 2 and < %d\n\nSetting window size to 5',length(C3.accel.data)));
                    hEcgNanAccMagWinSize.String = '5';
                    winSize = 5;
                end
                if minAccMag < maxAccMag && minAccMag > 0 && maxAccMag > 1
                    % create indices to match window size
                        startIdxAcc = 1:winSize:length(C3.accelmag.data);
                        endIdxAcc = winSize:winSize:length(C3.accelmag.data);
                        % make sure the end index is included
                        if length(endIdxAcc) == length(startIdxAcc)-1
                            endIdxAcc(length(endIdxAcc)+1) = length(C3.accelmag.data);
                        end
                        % go through all windows to find those that meet the magnitude criteria
                        idxAccMagTrue(length(startIdxAcc)) = false;
                        for ii=1:length(startIdxAcc)
                            if nanmin(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) < minAccMag || nanmax(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) > maxAccMag
                                idxAccMagTrue(ii) = true;
                            end
                        end
                        % calculate corresponding ECG indices
                        startOfAccMag_ecgIdx = ((startIdxAcc(idxAccMagTrue)-1)*6)+1;
                        endOfAccMag_ecgIdx = endIdxAcc(idxAccMagTrue)*6;
                        % get complete array of indices, by using coloncat function
                        ecgIdx = coloncat(startOfAccMag_ecgIdx,endOfAccMag_ecgIdx);
                        % set ECG to NaN at those indices
                        C3.ecg.data(ecgIdx,:) = NaN;
                else
                    warndlg(sprintf('Minimum Accel mag value should be > 0, and maximum value > 1,\nand minimum Accel mag value should be < maximum accel mag value.'));
                end
            end
        % 16bit data
        otherwise
            % ECG
            % 16bit ECG was already highpass filtered in C3 device, and
            % highpass will be deselected upon loading of BLE 16bit, and
            % BIN folder, meaning highpass can be skipped in initializeFiltering.
            C3.ecg.data = C3.ecg.dataRaw; % "Raw" not really raw here
            % Lowpass filtering
            if hPopupEcgLowPass.Value == 2
                Hd = Lowpass_FIR_max_flat_ord10_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 3
                Hd = Lowpass_FIR_max_flat_ord20_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 4
                Hd = Lowpass_FIR_max_flat_ord40_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 5
                Hd = Lowpass_FIR_max_flat_ord72_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 6
                Hd = Lowpass_FIR_win_cheby_ord100_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 7
                Hd = Lowpass_FIR_win_bartlethanning_ord100_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 8
                Hd = Lowpass_IIR_butterw_ord12_fc40Hz_fs250Hz;
                C3.ecg.data = filter(Hd,C3.ecg.data);
            elseif hPopupEcgLowPass.Value == 9
                d1 = designfilt('lowpassiir','FilterOrder',12,'HalfPowerFrequency',40,'DesignMethod','butter','SampleRate',250);
                C3.ecg.data = filtfilt(d1,C3.ecg.data);
            end
            % Replace with NaN
            if hEcgNanMissPackCheckbox.Value == 1 %NOTE: no good with .bin files, since serialNumber is not available!
                % calculate ECG start/end-indices of missed batches
                startOfMissed_ecgIdx = ((C3.missingSerials-1)*10)+1;
                endOfMissed_ecgIdx = C3.missingSerials*10;
                % get complete array of indices, by using coloncat function
                ecgIdx = coloncat(startOfMissed_ecgIdx, endOfMissed_ecgIdx);
                % set ECG to NaN at those indices
                C3.ecg.data(ecgIdx,:) = NaN;
            end
            if hEcgNanErrCodesCheckbox.Value == 1
                % Find error codes in the 'raw' data (since filtering may have modified the original error code values)
                % Only meaningful for 16bit data
                C3.ecg.data(abs(C3.ecg.dataRaw) > 32765,:) = NaN;
            end
            if hEcgNanAbsEcgCheckbox.Value == 1
                absEcgVal = getFloatVal(hEcgNanAbsEcg);
                winSize = getIntVal(hEcgAbsValWinSize);
                if winSize < 3 || winSize >= length(C3.ecg.data)
                    warndlg(sprintf('Abs(ECG) window size must be > 2 and < %d\n\nSetting window size to 250',length(C3.ecg.data)));
                    hEcgAbsValWinSize.String = '250';
                    winSize = 250;
                end
                % create indices to match window size
                startIdxEcg = 1:winSize:length(C3.ecg.data);
                endIdxEcg = winSize:winSize:length(C3.ecg.data);
                % make sure the end index is included
                if length(endIdxEcg) == length(startIdxEcg)-1
                    endIdxEcg(length(endIdxEcg)+1) = length(C3.ecg.data);
                end
                % go through all windows to find those that meet the abs(value) criteria
                for ii=1:length(startIdxEcg)
                    if nanmax(nanmax(abs(C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:)))) > absEcgVal
                        % set ECG to NaN at those indices
                        C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:) = NaN;
                    end
                end
            end
            % RESP
            % if Resp data is available
            if ~isempty(C3.resp.dataRaw)
                %16bit Resp was already highpass filtered in C3 device, so not optional
                C3.resp.data = C3.resp.dataRaw; % "Raw" not really raw here
                % Resp lowpass (smoothing) option
                if hRespLowpassCheckbox.Value == 1
                    C3.resp.smoothen;
                end
            end
            % ACCEL
            C3.accel.data = C3.accel.dataRaw;
            C3.accelmag.data = C3.accelmag.dataRaw;
            % Accel jitter filter option
            if hAccelJitterCheckbox.Value == 1
                filter_length = 10;
                C3.accel.remove_jitter(filter_length);
                C3.accelmag.remove_jitter(filter_length);
            end
            % Accel median filter option
            if hAccelMedianCheckbox.Value == 1
                % Median filtering to remove impulse noise
                C3.accel.data = medfilt1(C3.accel.data,round(C3.accel.fs));
                C3.accelmag.data = medfilt1(C3.accelmag.data,round(C3.accelmag.fs));
            end
            % ECG NaN, based on Accel mag, placed here, after C3.accel.data is initialized
            if hEcgNanAccMagCheckbox.Value == 1
                minAccMag = getFloatVal(hEcgNanMinAccMag);
                maxAccMag = getFloatVal(hEcgNanMaxAccMag);
                winSize = getIntVal(hEcgNanAccMagWinSize);
                if winSize < 3 || winSize >= length(C3.accel.data)
                    warndlg(sprintf('Accel mag window size must be > 2 and < %d\n\nSetting window size to 5',length(C3.accel.data)));
                    hEcgNanAccMagWinSize.String = '5';
                    winSize = 5;
                end
                if minAccMag < maxAccMag && minAccMag > 0 && maxAccMag > 1
                    % create indices to match window size
                        startIdxAcc = 1:winSize:length(C3.accelmag.data);
                        endIdxAcc = winSize:winSize:length(C3.accelmag.data);
                        % make sure the end index is included
                        if length(endIdxAcc) == length(startIdxAcc)-1
                            endIdxAcc(length(endIdxAcc)+1) = length(C3.accelmag.data);
                        end
                        % go through all windows to find those that meet the magnitude criteria
                        idxAccMagTrue(length(startIdxAcc)) = false;
                        for ii=1:length(startIdxAcc)
                            if nanmin(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) < minAccMag || nanmax(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) > maxAccMag
                                idxAccMagTrue(ii) = true;
                            end
                        end
                        % calculate corresponding ECG indices
                        startOfAccMag_ecgIdx = ((startIdxAcc(idxAccMagTrue)-1)*10)+1;
                        endOfAccMag_ecgIdx = endIdxAcc(idxAccMagTrue)*10;
                        % get complete array of indices, by using coloncat function
                        ecgIdx = coloncat(startOfAccMag_ecgIdx,endOfAccMag_ecgIdx);
                        % set ECG to NaN at those indices
                        C3.ecg.data(ecgIdx,:) = NaN;
                else
                    warndlg(sprintf('Minimum Accel mag value should be > 0, and maximum value > 1,\nand minimum Accel mag value should be < maximum accel mag value.'));
                end
            end
            % TEMP
            C3.temp.data = C3.temp.dataRaw;
            % Temp jitter filter option
            if hTempJitterCheckbox.Value == 1
                filter_length = 10;
                C3.temp.remove_jitter(filter_length);
            end
    end
end

function filterToggleFunc(~, ~, C3, fileFormat, signalName, gS, hPopupEcgHighPass, hPopupEcgLowPass, hRespHighpassCheckbox, hRespLowpassCheckbox, hAccelJitterCheckbox, hAccelMedianCheckbox, hTempJitterCheckbox, hEcgNanMissPackCheckbox, hEcgNanErrCodesCheckbox, hEcgNanAccMagCheckbox, hEcgNanMinAccMag, hEcgNanMaxAccMag, hEcgNanAbsEcgCheckbox, hEcgNanAbsEcg, hEcgNanAccMagWinSize, hEcgAbsValWinSize)
    switch signalName
        case 'ecg'
            if ~isempty(C3.ecg.data)
                C3.ecg.data = C3.ecg.dataRaw;
                % ECG highpass filter option
                if hPopupEcgHighPass.Value == 2
                    hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filter(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 3
                    hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filter(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 4
                    hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.32,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 5
                    hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 6
                    hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 7
                    hF = designfilt('highpassiir','FilterOrder',6,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 8
                    hF = designfilt('highpassiir','FilterOrder',12,'HalfPowerFrequency',0.5,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 9
                    hF = designfilt('highpassiir','FilterOrder',1,'HalfPowerFrequency',0.67,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                elseif hPopupEcgHighPass.Value == 10
                    hF = designfilt('highpassiir','FilterOrder',2,'HalfPowerFrequency',0.67,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(hF,C3.ecg.data);
                end
                % Lowpass filtering
                if hPopupEcgLowPass.Value == 2
                    Hd = Lowpass_FIR_max_flat_ord10_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 3
                    Hd = Lowpass_FIR_max_flat_ord20_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 4
                    Hd = Lowpass_FIR_max_flat_ord40_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 5
                    Hd = Lowpass_FIR_max_flat_ord72_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 6
                    Hd = Lowpass_FIR_win_cheby_ord100_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 7
                    Hd = Lowpass_FIR_win_bartlethanning_ord100_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 8
                    Hd = Lowpass_IIR_butterw_ord12_fc40Hz_fs250Hz;
                    C3.ecg.data = filter(Hd,C3.ecg.data);
                elseif hPopupEcgLowPass.Value == 9
                    d1 = designfilt('lowpassiir','FilterOrder',12,'HalfPowerFrequency',40,'DesignMethod','butter','SampleRate',250);
                    C3.ecg.data = filtfilt(d1,C3.ecg.data);
                end
                % Optional flipping of channels
                if gS.flipEcg1
                    C3.ecg.data(:,1) = C3.ecg.data(:,1) - (2 * C3.ecg.data(:,1));
                end
                if gS.flipEcg2
                    C3.ecg.data(:,2) = C3.ecg.data(:,2) - (2 * C3.ecg.data(:,2));
                end
                if gS.flipEcg3
                    C3.ecg.data(:,3) = C3.ecg.data(:,3) - (2 * C3.ecg.data(:,3));
                end
                % Replace with NaN
                if hEcgNanMissPackCheckbox.Value == 1 %NOTE: no good with .bin files, since serialNumber is not available!
                    % calculate ECG indices of missed batches
                    switch fileFormat% 24bit data
                        case 'BLE 24bit'
                            startOfMissed_ecgIdx = ((C3.missingSerials-1)*6)+1;
                            endOfMissed_ecgIdx = C3.missingSerials*6;
                        otherwise
                            startOfMissed_ecgIdx = ((C3.missingSerials-1)*10)+1;
                            endOfMissed_ecgIdx = C3.missingSerials*10;
                    end
                    % get complete array of indices, by using coloncat function
                    ecgIdx = coloncat(startOfMissed_ecgIdx, endOfMissed_ecgIdx);
                    % set ECG to NaN at those indices
                    C3.ecg.data(ecgIdx,:) = NaN;
                end
                if hEcgNanErrCodesCheckbox.Value == 1
                    % Find error codes in the 'raw' data (since filtering may have modified the original error code values)
                    % Only meaningful for 16bit data
                    C3.ecg.data(abs(C3.ecg.dataRaw) > 32765,:) = NaN;
                end
                if hEcgNanAbsEcgCheckbox.Value == 1
                    absEcgVal = getFloatVal(hEcgNanAbsEcg);
                    winSize = getIntVal(hEcgAbsValWinSize);
                    if winSize < 3 || winSize >= length(C3.ecg.data)
                        warndlg(sprintf('Abs(ECG) window size must be > 2 and < %d\n\nSetting window size to 250',length(C3.ecg.data)));
                        hEcgAbsValWinSize.String = '250';
                        winSize = 250;
                    end
                    % create indices to match window size
                    startIdxEcg = 1:winSize:length(C3.ecg.data);
                    endIdxEcg = winSize:winSize:length(C3.ecg.data);
                    % make sure the end index is included
                    if length(endIdxEcg) == length(startIdxEcg)-1
                        endIdxEcg(length(endIdxEcg)+1) = length(C3.ecg.data);
                    end
                    % go through all windows to find those that meet the abs(value) criteria
                    for ii=1:length(startIdxEcg)
                        if nanmax(nanmax(abs(C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:)))) > absEcgVal
                            % set ECG to NaN at those indices
                            C3.ecg.data(startIdxEcg(ii):endIdxEcg(ii),:) = NaN;
                        end
                    end
                end
                if hEcgNanAccMagCheckbox.Value == 1
                    minAccMag = getFloatVal(hEcgNanMinAccMag);
                    maxAccMag = getFloatVal(hEcgNanMaxAccMag);
                    winSize = getIntVal(hEcgNanAccMagWinSize);
                    if winSize < 3 || winSize >= length(C3.accel.data)
                        warndlg(sprintf('Accel mag window size must be > 2 and < %d\n\nSetting window size to 5',length(C3.accel.data)));
                        hEcgNanAccMagWinSize.String = '5';
                        winSize = 5;
                    end
                    if minAccMag < maxAccMag && minAccMag > 0 && maxAccMag > 1
                        % create indices to match window size
                        startIdxAcc = 1:winSize:length(C3.accelmag.data);
                        endIdxAcc = winSize:winSize:length(C3.accelmag.data);
                        % make sure the end index is included
                        if length(endIdxAcc) == length(startIdxAcc)-1
                            endIdxAcc(length(endIdxAcc)+1) = length(C3.accelmag.data);
                        end
                        % go through all windows to find those that meet the magnitude criteria
                        idxAccMagTrue(length(startIdxAcc)) = false;
                        for ii=1:length(startIdxAcc)
                            if nanmin(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) < minAccMag || nanmax(C3.accelmag.data(startIdxAcc(ii):endIdxAcc(ii))) > maxAccMag
                                idxAccMagTrue(ii) = true;
                            end
                        end
                        % calculate corresponding ECG indices
                        switch fileFormat% 24bit data
                            case 'BLE 24bit'
                                startOfAccMag_ecgIdx = ((startIdxAcc(idxAccMagTrue)-1)*6)+1;
                                endOfAccMag_ecgIdx = endIdxAcc(idxAccMagTrue)*6;
                            otherwise
                                startOfAccMag_ecgIdx = ((startIdxAcc(idxAccMagTrue)-1)*10)+1;
                                endOfAccMag_ecgIdx = endIdxAcc(idxAccMagTrue)*10;
                        end
                        % get complete array of indices, by using coloncat function
                        ecgIdx = coloncat(startOfAccMag_ecgIdx,endOfAccMag_ecgIdx);
                        % set ECG to NaN at those indices
                        C3.ecg.data(ecgIdx,:) = NaN;
                    else
                        warndlg(sprintf('Minimum Accel mag value should be > 0, and maximum value > 1,\nand minimum Accel mag value should be < maximum accel mag value.'));
                    end
                end
            end
        case 'resp'
            if ~isempty(C3.resp.data)
                C3.resp.data = C3.resp.dataRaw;
                % Resp highpass (baseline) option
                if hRespHighpassCheckbox.Value == 1
                    switch fileFormat% 24bit data
                        case 'BLE 24bit'
                            C3.resp.data = filterRespHighpass(C3);
                        otherwise
                            % Nada
                    end
                end
                % Resp lowpass (smoothing) option
                if hRespLowpassCheckbox.Value == 1
                    C3.resp.smoothen;
                end
            end
        case 'accel'
            C3.accel.data = C3.accel.dataRaw;
            C3.accelmag.data = C3.accelmag.dataRaw;
            % Accel jitter filter option
            if hAccelJitterCheckbox.Value == 1
                filter_length = 10;
                C3.accel.remove_jitter(filter_length);
                C3.accelmag.remove_jitter(filter_length);
            end
            % Accel median filter option
            if hAccelMedianCheckbox.Value == 1
                % Median filtering to remove impulse noise
                C3.accel.data = medfilt1(C3.accel.data,round(C3.accel.fs));
                C3.accelmag.data = medfilt1(C3.accelmag.data,round(C3.accelmag.fs));
            end
        case 'temp'
            C3.temp.data = C3.temp.dataRaw;
            % Temp jitter filter option
            if hTempJitterCheckbox.Value == 1
                filter_length = 10;
                C3.temp.remove_jitter(filter_length);
            end
    end
end

% ECG highpass (implementation in C3 firmware, before switch to 24bit ECG)
function filteredData = filterEcgHighpass(C3)
    filteredData(size(C3.ecg.data,1),size(C3.ecg.data,2)) = 0;
    multiplier = (127 / 128);
    for jj = 1:size(C3.ecg.data,2)
        prevSample = 0; filteredSample = 0;
        ii = 1;
        while ii < length(C3.ecg.data)
            sample = C3.ecg.data(ii,jj);
            tmp = filteredSample * multiplier;
            filteredSample = (sample - prevSample) + tmp;
            prevSample = sample;
            filteredData(ii,jj) = filteredSample;
            ii = ii+1;
        end
    end
end

% Resp highpass (implementation in C3 firmware, before switch to 24bit Resp)
function filteredData = filterRespHighpass(C3)
    filteredData(size(C3.resp.data,1),size(C3.resp.data,2)) = 0;
    multiplier = (255 / 256);
    prevSample = 0; filteredSample = 0;
    ii = 1;
    while ii < length(C3.resp.data)
        sample = C3.resp.data(ii);
        tmp = filteredSample * multiplier;
        filteredSample = (sample - prevSample) + tmp;
        prevSample = sample;
        filteredData(ii) = filteredSample;
        ii = ii+1;
    end
end

function hea_fullpath = exportECGtoMITfiles(C3,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hEcg1Checkbox,hEcg2Checkbox,hEcg3Checkbox,full_path,rangeStr,contextStr,fileFormat)
    [source_path,filename_wo_extension,file_extension] = fileparts(full_path);
    if strcmp(contextStr,'export')
        exportMainFolderName = 'MIT_export - ECG';
    elseif strcmp(contextStr,'ecgkit')
        exportMainFolderName = 'ECGkit analysis';
    else
        exportMainFolderName = 'Undefined';
    end
    export_main_path = [source_path filesep exportMainFolderName];
    if ~exist(export_main_path,'dir')
        mkdir(export_main_path);
    end
    if strcmp(rangeStr,'full')
        idxMin = 1;
        idxMax = length(C3.ecg.data);
        rangeStr = 'full_recording';
    else
        idxMin = indexStartECG;
        idxMax = indexEndECG;
        if idxMin == 1 && idxMax == length(C3.ecg.data)
            rangeStr = 'full_recording';
        else
            rangeStr = getRangeStrForFileName(xAxisTimeStamps,timeBase,idxMin,idxMax,'ECG');
        end
    end
    % NOTE: This could go wrong if not all 3 ECG channels are present -
    % e.g. attempt to export ECG3 when no ECG2 was present in the data,
    % will try to access column 3 of C3.ecg.data having only 2 columns.
    % Best fix may be to modify how read_ble_*.m returns ECG data.
    cortrium_matlab_scripts_root_path = getCortriumScriptsRoot;
    bin_path = [cortrium_matlab_scripts_root_path filesep 'bin'];
    if hEcg1Checkbox.Value == 1 && hEcg2Checkbox.Value == 1 && hEcg3Checkbox.Value == 1
        chNum = [1 2 3];
        chNumStr = '1_2_3';
    elseif hEcg1Checkbox.Value == 1 && hEcg2Checkbox.Value == 1 && hEcg3Checkbox.Value == 0
        chNum = [1 2];
        chNumStr = '1_2';
    elseif hEcg1Checkbox.Value == 1 && hEcg2Checkbox.Value == 0 && hEcg3Checkbox.Value == 1
        chNum = [1 3];
        chNumStr = '1_3';
    elseif hEcg1Checkbox.Value == 0 && hEcg2Checkbox.Value == 1 && hEcg3Checkbox.Value == 1
        chNum = [2 3];
        chNumStr = '2_3';
    elseif hEcg1Checkbox.Value == 0 && hEcg2Checkbox.Value == 0 && hEcg3Checkbox.Value == 1
        chNum = 3;
        chNumStr = '3';
    elseif hEcg1Checkbox.Value == 0 && hEcg2Checkbox.Value == 1 && hEcg3Checkbox.Value == 0
        chNum = 2;
        chNumStr = '2';
    elseif hEcg1Checkbox.Value == 1 && hEcg2Checkbox.Value == 0 && hEcg3Checkbox.Value == 0
        chNum = 1;
        chNumStr = '1';
    else
        chNum = 0;
        cmd_status = 0;
        warndlg(sprintf('No ECG channels selected for export!'));
    end
    if chNum(1) ~= 0
        if strcmp(file_extension,'.bin')
            filename_wo_extension = 'BIN-folder';
        end
        export_sub_path = [export_main_path filesep filename_wo_extension '_ecg_' chNumStr '_' rangeStr];
        if ~exist(export_sub_path,'dir')
            mkdir(export_sub_path);
        end
        hea_fullpath = [export_sub_path filesep filename_wo_extension '.hea'];
        % store path to current directory
        currentFolder = pwd;
        % change path to export_sub_path, so the .dat and .hea files output by wrsamp.exe will land there
        cd(export_sub_path);
        physiobank_fullpath = exportECGtoPhysiobankFile(C3,idxMin,idxMax,chNum,export_sub_path,filename_wo_extension,contextStr);
        % For reference on wrsamp.exe and signal formats, go to:
        % https://www.physionet.org/physiotools/wag/wrsamp-1.htm
        % https://www.physionet.org/physiotools/wag/signal-5.htm
        switch fileFormat
            % if selected file format is BLE 24bit
            case 'BLE 24bit'
                % Output format 24, and gain set at 20972 units pr mV
                % NOTE: ECGkit does not read 24bit format .dat files, 
                % so the format must be forced down to 16bit. 
                % How wrsamp.exe handles overflow, and what the consequences 
                % are further down the line, is currently (2016-03-15) unknown.
                cmd_str = ['"' bin_path filesep 'wrsamp.exe" -F ' num2str(C3.ecg.fs) ' -i "' physiobank_fullpath '" -o "' filename_wo_extension '" -O 16 -G 20972'];
            otherwise
                % Output format 16, and gain set at 5243 units pr mV
                cmd_str = ['"' bin_path filesep 'wrsamp.exe" -F ' num2str(C3.ecg.fs) ' -i "' physiobank_fullpath '" -o "' filename_wo_extension '" -O 16 -G 5243'];
        end        
        [cmd_status,~] = system(cmd_str);
        % go back to previous directory
        cd(currentFolder);
        % if the MIT files were generated for export purpose (not for
        % ECGkit report) then tidy up, by deleting the physiobank file.
        if strcmp(contextStr,'export')
            % Turn off recycling, so delete actually means delete, and not "Fill my recycle bin."
            recycle('off');
            % delete physiobank file
            delete(physiobank_fullpath);
        end        
    else
        hea_fullpath = [];
    end
    if cmd_status ~= 0
        warndlg(sprintf('Use of wrsamp.exe to export .dat and .hea files failed!'));
    end
end

function csv_fullpath = exportECGtoCSVfile(C3,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hExportRangeButtonGroup,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path)
    [source_path,filename_wo_extension,file_extension] = fileparts(full_path);
    export_main_path = [source_path filesep 'CSV_export - ECG'];
    if ~exist(export_main_path,'dir')
        mkdir(export_main_path);
    end
    if strcmp('Displayed',get(get(hExportRangeButtonGroup,'selectedobject'),'String'))
        idxMin = indexStartECG;
        idxMax = indexEndECG;
        if idxMin == 1 && idxMax == length(C3.ecg.data)
            rangeStr = 'full_recording';
        else
            rangeStr = getRangeStrForFileName(xAxisTimeStamps,timeBase,idxMin,idxMax,'ECG');
        end
    else
        idxMin = 1;
        idxMax = length(C3.ecg.data);
        rangeStr = 'full_recording';
    end
    % NOTE: This could go wrong if not all 3 ECG channels are present -
    % e.g. attempt to export ECG3 when no ECG2 was present in the data,
    % will try to access column 3 of C3.ecg.data having only 2 columns.
    % Best fix may be to modify how read_ble_*.m returns ECG data.
    if hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 1
        chNum = [1 2 3];
        chNumStr = '1_2_3';
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 0
        chNum = [1 2];
        chNumStr = '1_2';
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 1
        chNum = [1 3];
        chNumStr = '1_3';
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 1
        chNum = [2 3];
        chNumStr = '2_3';
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 1
        chNum = 3;
        chNumStr = '3';
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 0
        chNum = 2;
        chNumStr = '2';
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 0
        chNum = 1;
        chNumStr = '1';
    else
        chNum = 0;
        warndlg(sprintf('No ECG channels selected for export!'));
    end
    if chNum(1) ~= 0
        if strcmp(file_extension,'.bin')
            filename_wo_extension = 'unknown_ble';
        end
        export_sub_path = [export_main_path filesep filename_wo_extension '_ecg_' chNumStr '_' rangeStr];
        if ~exist(export_sub_path,'dir')
            mkdir(export_sub_path);
        end
        csv_fullpath = [export_sub_path filesep filename_wo_extension '.csv'];
        dlmwrite(csv_fullpath, C3.ecg.data(idxMin:idxMax,chNum),'precision','%.3f','delimiter',',');
    else
        csv_fullpath = [];
    end
end

function physiobank_fullpath = exportECGtoPhysiobankFile(C3,indexStartECG,indexEndECG,chNum,export_sub_path,filename_wo_extension,contextStr)
    if strcmp(contextStr,'ecgkit')
        % write a physiobank file for the report script
        physiobank_file_for_report = fullfile(export_sub_path, [filename_wo_extension '_physiobank.txt']);
        % if 3-channel output
        if length(chNum) == 3
            dlmwrite(physiobank_file_for_report, 'MLI MLII MLIII', 'delimiter', '');
            fid = fopen(physiobank_file_for_report,'a');
            fprintf(fid,'%f %f %f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
        % if 2-channel output
        elseif length(chNum) == 2
            if isempty(find(chNum == 3,1))
                dlmwrite(physiobank_file_for_report, 'MLI MLII', 'delimiter', '');
            elseif isempty(find(chNum == 2,1))
                dlmwrite(physiobank_file_for_report, 'MLI MLII', 'delimiter', ''); %'MLI MLIII'
            else
                dlmwrite(physiobank_file_for_report, 'MLI MLII', 'delimiter', ''); % 'MLII MLIII'
            end
            fid = fopen(physiobank_file_for_report,'a');
            fprintf(fid,'%f %f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
        % if 1-channel output
        else
            if isempty(find(chNum == 3,1)) && isempty(find(chNum == 2,1))
                dlmwrite(physiobank_file_for_report, 'MLI', 'delimiter', '');
            elseif isempty(find(chNum == 3,1)) && isempty(find(chNum == 1,1))
                dlmwrite(physiobank_file_for_report, 'MLI', 'delimiter', ''); % 'MLII'
            else
                dlmwrite(physiobank_file_for_report, 'MLI', 'delimiter', ''); % 'MLIII'
            end
            fid = fopen(physiobank_file_for_report,'a');
            fprintf(fid,'%f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
        end
        fclose(fid);
    end
    % physiobank file for wrsamp.exe conversion to .dat
    if length(chNum) == 3
        outStr = sprintf('%f %f %f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
    elseif length(chNum) == 2
        outStr = sprintf('%f %f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
    else
        outStr = sprintf('%f\n',C3.ecg.data(indexStartECG:indexEndECG,chNum)');
    end
    % replace NaN by hyphen
    outStr = strrep(outStr,'NaN','-');
    physiobank_fullpath = fullfile(export_sub_path, [filename_wo_extension '_physiobank_w_-_for_NaN.txt']);
    % if 3-channel output
    if length(chNum) == 3
        dlmwrite(physiobank_fullpath, 'MLI MLII MLIII', 'delimiter', '');
    % if 2-channel output
    elseif length(chNum) == 2
        if isempty(find(chNum == 3,1))
            dlmwrite(physiobank_fullpath, 'MLI MLII', 'delimiter', '');
        elseif isempty(find(chNum == 2,1))
            dlmwrite(physiobank_fullpath, 'MLI MLII', 'delimiter', ''); % 'MLI MLIII'
        else
            dlmwrite(physiobank_fullpath, 'MLI MLII', 'delimiter', ''); % 'MLII MLIII'
        end
    % if 1-channel output
    else
        if isempty(find(chNum == 3,1)) && isempty(find(chNum == 2,1))
            dlmwrite(physiobank_fullpath, 'MLI', 'delimiter', '');
        elseif isempty(find(chNum == 3,1)) && isempty(find(chNum == 1,1))
            dlmwrite(physiobank_fullpath, 'MLI', 'delimiter', ''); % 'MLII'
        else
            dlmwrite(physiobank_fullpath, 'MLI', 'delimiter', ''); % 'MLIII'
        end
    end
    fid = fopen(physiobank_fullpath,'a');
    fprintf(fid,'%s',outStr);
    fclose(fid);
end

function [gS,eventMarkers] = addEventMarker(timePoint,xAxisTimeStamps,timeBase,gS,eventMarkers,hEventMarkerDescription,hEventListBox,hButtonEventMarkerSave,editColorGreen,sampleRateFactor)
    accelIndex = getAccelIndexPoint(xAxisTimeStamps,timeBase,timePoint);
    if isempty(eventMarkers)
        numMarkers = 0;
    else
        numMarkers = size(eventMarkers,2);
    end
    eventMarkers(numMarkers+1).description = hEventMarkerDescription.String;
    eventMarkers(numMarkers+1).serial = accelIndex;
    eventMarkers(numMarkers+1).eventid = char(java.util.UUID.randomUUID);
    hEventMarkerDescription.String = '';
    updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,numMarkers+1);
    hButtonEventMarkerSave.BackgroundColor = editColorGreen;
end

function genECGkitReport(C3,sampleRateFactor,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,reportIOmarkers,jsondata,hECGkitListBox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,hECGkitMakePDFCheckbox,hECGkitOpenPDFCheckbox,full_path,fileFormat)
    if hAnalyseEcg1Checkbox.Value == 0 && hAnalyseEcg2Checkbox.Value == 0 && hAnalyseEcg3Checkbox.Value == 0
        warndlg('No ECG channels selected for analysis!')
        return;
    end
    % Temporary variable for jsondata, to avoid time-offsets being saved to the JSON file.
    if ~isempty(jsondata)
        jsondata_temp = jsondata;
    else
        jsondata_temp.start = '';
    end
    if strcmp(fileFormat,'BIN (folder)')
        jsondata_temp.filename = 'BIN-folder';
    end
    % If no segment is selected, default to displayed range
    if isempty(hECGkitListBox.Value)
        ecgRanges = [indexStartECG indexEndECG];
        jsonTimeOffsetMillisecs = (indexStartECG/double(C3.ecg.fs)) * 1000;
        jsonReportNotes = '';
    else
        jsonTimeOffsetMillisecs = zeros(length(hECGkitListBox.Value),1);
        ecgRanges = zeros(length(hECGkitListBox.Value),2);
        jsonReportNotes = cell(length(hECGkitListBox.Value),1);
        for ii=1:length(hECGkitListBox.Value)
            % if the first item on the list is selected, it means 'Displayed range'
            if hECGkitListBox.Value(ii) == 1
                ecgRanges(ii,:) = [indexStartECG indexEndECG];
                jsonTimeOffsetMillisecs(ii) = (ecgRanges(ii,1)/double(C3.ecg.fs)) * 1000;
                jsonReportNotes{ii,1} = '';
            else
                % find start and end index numbers, based on the list selection
                ecgRanges(ii,:) = [reportIOmarkers(hECGkitListBox.Value(ii)-1).inEcgIndex reportIOmarkers(hECGkitListBox.Value(ii)-1).outEcgIndex];
                jsonTimeOffsetMillisecs(ii) = (ecgRanges(ii,1)/double(C3.ecg.fs)) * 1000;
                jsonReportNotes{ii,1} = reportIOmarkers(hECGkitListBox.Value(ii)-1).description;
            end
        end
    end
    % For every range, export ECG data to MIT-format (.dat, .hea) files, and call the report script.
    for ii=1:size(ecgRanges,1)
        hea_fullpath = exportECGtoMITfiles(C3,ecgRanges(ii,1),ecgRanges(ii,2),xAxisTimeStamps,timeBase,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,full_path,'displayed','ecgkit',fileFormat);
        [tmpPath, tmpName, ~] = fileparts(hea_fullpath);
        % Also export a new JSON file with the "start" field reflecting the
        % the start time of this segment, and a "reportnote" field added.
        timeStartOfThisSegment = datetime(addtodate(C3.date_start,jsonTimeOffsetMillisecs(ii),'millisecond'),'ConvertFrom','datenum','Format','yyyy-MM-dd''T''HH:mm:ss.SSS+0000','TimeZone','UTC');
        jsondata_temp.start = datestr(timeStartOfThisSegment,'yyyy-mm-ddTHH:MM:SS.FFF+0000');
        jsondata_temp.reportnote = jsonReportNotes{ii,1};
        savejson('',jsondata_temp,'FileName',fullfile(tmpPath,[tmpName '.json']),'ParseLogical',1);
        % Export Accel data for this segment. NOTE: Since ECG indices are
        % currently not constrained to match up with whole BLE packages,
        % there will be a slight mismatch between ECG sample count and
        % Accel sample count (after considering the sampleRateFactor).
        accelStartIdx = ceil(ecgRanges(ii,1)/sampleRateFactor.ECG);
        accelEndIdx = ceil(ecgRanges(ii,2)/sampleRateFactor.ECG);
        fid = fopen(fullfile(tmpPath,[tmpName '_accelmag.txt']),'w');
        fprintf(fid,'%f\n',C3.accelmag.data(accelStartIdx:accelEndIdx)');
        fclose(fid);
        % Run ecgkit
        ecgkit_run(hea_fullpath);
        % call report script if checkbox is set to true
        if hECGkitMakePDFCheckbox.Value == 1
            pdf_fullpath = ecgReportType1(jsondata_temp, hea_fullpath);
            % open report, if one was created and checkbox is set to true
            if ~isempty(pdf_fullpath) && hECGkitOpenPDFCheckbox.Value == 1
                winopen(pdf_fullpath);
            end
        end
    end
end

% function for adding in and out report markers, when using single-click
function [gS,reportIOmarkers] = addReportMarker(C3,timePoint,xAxisTimeStamps,timeBase,gS,reportIOmarkers,hECGkitMarkerDescription,hECGkitListBox,hButtonECGkitMarkerSave,editColorGreen)
    ecgIndex = getEcgIndexPoint(xAxisTimeStamps,timeBase,timePoint);
    if isempty(reportIOmarkers)
        numMarkers = 0;
    else
        numMarkers = size(reportIOmarkers,2);
    end
    % if open for in-point
    if ~gS.ecgInpointSet
        if ecgIndex+(10*C3.ecg.fs) > length(C3.ecg.data)
            warndlg(sprintf('In-marker too close to end of recording!\nOut-marker can not be set +10 sec from In-marker\nPlease set new In-marker.'));
        else
            reportIOmarkers(numMarkers+1).inEcgIndex = ecgIndex;
            gS.ecgInpointSet = true;
        end
    elseif ecgIndex >= (reportIOmarkers(numMarkers).inEcgIndex + (10 * C3.ecg.fs))
        reportIOmarkers(numMarkers).description = hECGkitMarkerDescription.String;
        reportIOmarkers(numMarkers).outEcgIndex = ecgIndex;
        gS.ecgInpointSet = false;
        hECGkitMarkerDescription.String = '';
        updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,numMarkers+1);
        hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
    else
        warndlg('Out-marker must be at least +10 sec from In-marker!');
    end
%     fprintf('numMarkers: %d\n',size(reportIOmarkers,2));
end

% function for adding in and out report markers, when out-button was clicked
function [gS,reportIOmarkers] = addReportOutMarker(C3,deltaHMS,xAxisTimeStamps,timeBase,gS,reportIOmarkers,hECGkitMarkerDescription,hECGkitListBox,hButtonECGkitMarkerSave,editColorGreen)
    % if an in-point was set
    if gS.ecgInpointSet
        numMarkers = size(reportIOmarkers,2);
        ecgIndexTemp = reportIOmarkers(numMarkers).inEcgIndex + ((deltaHMS(1)*60*60) + (deltaHMS(2)*60) + deltaHMS(3))*C3.ecg.fs;
        ecgIndex = setEcgIndexWithinBounds(C3,ecgIndexTemp);
        if ecgIndexTemp ~= ecgIndex
            if ecgIndex < (reportIOmarkers(numMarkers).inEcgIndex + (10 * C3.ecg.fs))
                warndlg(sprintf('Out-marker point out of bounds!\nOut-marker can not be set +10 sec from In-marker\nDeleting In-marker, please set new In-marker.'));
                reportIOmarkers(numMarkers) = [];
                gS.ecgInpointSet = false;
            else
                warndlg(sprintf('Out-marker point out of bounds!\nOut-marker has been forced within bounds.'));
                reportIOmarkers(numMarkers).description = hECGkitMarkerDescription.String;
                reportIOmarkers(numMarkers).outEcgIndex = ecgIndex;
                gS.ecgInpointSet = false;
                hECGkitMarkerDescription.String = '';
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,numMarkers+1);
                hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
            end
        elseif ecgIndex >= (reportIOmarkers(numMarkers).inEcgIndex + (10 * C3.ecg.fs))
                reportIOmarkers(numMarkers).description = hECGkitMarkerDescription.String;
                reportIOmarkers(numMarkers).outEcgIndex = ecgIndex;
                gS.ecgInpointSet = false;
                hECGkitMarkerDescription.String = '';
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,numMarkers+1);
                hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
        else
            warndlg('Out-marker must be at least +10 sec from In-marker!');
        end
    end
end

function updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,selectedNum)
    numMarkers = size(reportIOmarkers,2);
    hECGkitListBox.String = cell(numMarkers+1,1);
    % ECGkit listbox always has one default entry: 'Displayed range'
    hECGkitListBox.String{1,1} = 'Displayed range';
    if numMarkers
        for ii=1:numMarkers
            if strcmp(timeBase,'World')
                timeRangeStr = [datestr(xAxisTimeStamps.world.ECG(reportIOmarkers(ii).inEcgIndex), 'yyyy/mm/dd, HH:MM:SS') ' - ' datestr(xAxisTimeStamps.world.ECG(reportIOmarkers(ii).outEcgIndex), 'yyyy/mm/dd, HH:MM:SS')];
            else
                [h,m,s] = hms([xAxisTimeStamps.duration.ECG(reportIOmarkers(ii).inEcgIndex) xAxisTimeStamps.duration.ECG(reportIOmarkers(ii).outEcgIndex)]);
                timeRangeStr = [sprintf('%02d:%02d:%02.0f',h(1),m(1),s(1)) ' ' char(8211) ' ' sprintf('%02d:%02d:%02.0f',h(2),m(2),s(2))];
            end
            hECGkitListBox.String{ii+1,1} = [num2str(ii,'[%02i]') '  ' timeRangeStr ' ' reportIOmarkers(ii).description];
        end
    end
    hECGkitListBox.Value = max(1,selectedNum);
end

function updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,selectedNum)
    numMarkers = size(eventMarkers,2);
    hEventListBox.String = cell(numMarkers,1);
    if numMarkers
        for ii=1:numMarkers
            if strcmp(timeBase,'World')
                timeRangeStr = datestr(xAxisTimeStamps.world.Accel(eventMarkers(ii).serial), 'yyyy/mm/dd, HH:MM:SS');
            else
                [h,m,s] = hms(xAxisTimeStamps.duration.Accel(eventMarkers(ii).serial));
                timeRangeStr = sprintf('%02d:%02d:%02.0f',h(1),m(1),s(1));
            end
            hEventListBox.String{ii,1} = [num2str(ii,'[%02i]') '  ' timeRangeStr ' ' eventMarkers(ii).description];
        end
    end
    hEventListBox.Value = max(1,selectedNum);
end

%function called when loading new sensor data. Fills jsondata.events into eventMarkers.
function eventMarkers = initializEventMarkers(jsondata,eventMarkers)
    if isfield(jsondata,'events') && ~isempty(jsondata.events)
        for ii=1:size(jsondata.events,2)
            eventMarkers(ii).serial = jsondata.events{1,ii}.serial;
            eventMarkers(ii).description = jsondata.events{1,ii}.eventname;
            eventMarkers(ii).eventid = jsondata.events{1,ii}.eventid;
        end
    end
end

%function called when loading new sensor data. Fills jsondata.reportmarkers into reportIOmarkers.
function reportIOmarkers = initializeReportIOmarkers(jsondata,reportIOmarkers)
    if isfield(jsondata,'reportmarkers') && ~isempty(jsondata.reportmarkers)
        for ii=1:size(jsondata.reportmarkers,2)
            reportIOmarkers(ii).inEcgIndex = jsondata.reportmarkers{1,ii}.inecgindex;
            reportIOmarkers(ii).outEcgIndex = jsondata.reportmarkers{1,ii}.outecgindex;
            reportIOmarkers(ii).description = jsondata.reportmarkers{1,ii}.name;
        end
    end
end

function timeRangeStr = getTimeRangeStr(timeStart, timeEnd, timeBase)
    if strcmp(timeBase,'World')
        timeRangeStr = [datestr(timeStart, 'yyyy/mm/dd, HH:MM:SS') ' - ' datestr(timeEnd, 'yyyy/mm/dd, HH:MM:SS')];
    else
        [h,m,s] = hms([timeStart timeEnd]);
        timeRangeStr = [sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))) ' ' char(8211) ' ' sprintf('%02i:%02i:%02i',h(2),m(2),round(s(2)))];
    end
end

function [screenWidth, screenHeight] = getScreenSize()
    % get screen size
    screenSize = get(0,'screensize');
    screenWidth = screenSize(3);
    screenHeight = screenSize(4);
end

function [winXpos, winYpos, winWidth, winHeight] = getPlotWinPos()
    [screenWidth, screenHeight] = getScreenSize;
    winXpos = round(screenWidth*0.05);
    winYpos = round(screenHeight*0.5) - round(screenHeight*0.1);
    winWidth = round(screenWidth*0.5);
    winHeight = round(screenHeight*0.5);
end

function fftEcgNewWindow(C3,startIndex,endIndex,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hOptPlotRangeButtonGroup,gS,full_path)
    if gS.dataLoaded
        if hSaveImagesCheckbox.Value == 1
            saveImages = true;
            [source_path,~,~] = fileparts(full_path);
            imgFiles_path = [source_path filesep 'Images - FFT ECG'];
            if ~exist(imgFiles_path,'dir')
                mkdir(imgFiles_path);
            end
        else
            saveImages = false;
        end
        if strcmp('Full recording',get(get(hOptPlotRangeButtonGroup,'selectedobject'),'String'))
            startIndex = 1;
            endIndex = length(C3.ecg.data);
        end
        rangeStr = getRangeStrForPlotTitle(xAxisTimeStamps,timeBase,startIndex,endIndex,'ECG');
        [winXpos, winYpos, winWidth, winHeight] = getPlotWinPos;
        paperSize = [(winWidth/72)*2.54 (winHeight/72)*2.54];
        paperPosition = [0 0 (winWidth/72)*2.54 (winHeight/72)*2.54];
        yFFT = cell(size(C3.ecg.data,2),1);
        xFFT = cell(size(C3.ecg.data,2),1);
        for ii=1:size(C3.ecg.data,2)
            yFFT{ii,1} = fft(C3.ecg.data(startIndex:endIndex,ii));
            xFFT{ii,1} = linspace(0,C3.ecg.fs,size(C3.ecg.data(startIndex:endIndex,:),1));
        end
        for ii=1:size(C3.ecg.data,2)
            hFig = figure('Numbertitle','off','Name','FFT ECG','OuterPosition',[winXpos+(25*ii) winYpos-(25*ii) winWidth winHeight],'PaperUnits','centimeters','PaperSize',paperSize,'PaperPosition',paperPosition);
            hAx = axes('Parent',hFig,'Position',[0.06,0.1,0.9,0.82], 'Box', 'on');
            hAx.XLim = [round(xFFT{ii,1}(2)) round(xFFT{ii,1}(round(end/2)))];
            hold(hAx,'on');
            plot(hAx,xFFT{ii,1}(2:round(end/2)),abs(yFFT{ii,1}(2:round(end/2))),'Color',gS.colors.col{ii});
            title(hAx,['FFT   ECG' num2str(ii) '   ' rangeStr],'FontSize',14,'FontWeight','bold');
            xlabel(hAx,'Frequency (Hz)','FontSize',10);
%             ylabel(hAx,'fft','FontSize',10);
            set(hAx,'FontSize',10);
            hAx.XTick = hAx.XLim(1):10:hAx.XLim(2);
            if saveImages
                imgTitleStr = ['FFT ECG' num2str(ii) ' ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'ECG')];
                print(hFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng','-r90');
            end
        end
    end
end

function accHistNewWindow(C3,startIndex,endIndex,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hOptPlotRangeButtonGroup,gS,hAccMagHistBinCount,hAccMagHistXLimMin,hAccMagHistXLimMax,hAccXYZHistBinCount,hAccXYZHistXLimMin,hAccXYZHistXLimMax,full_path,jsondata)
    if gS.dataLoaded
        binCountMag = getIntVal(hAccMagHistBinCount);
        xLimMinMag = getFloatVal(hAccMagHistXLimMin);
        xLimMaxMag = getFloatVal(hAccMagHistXLimMax);
        binCountXYZ = getIntVal(hAccXYZHistBinCount);
        xLimMinXYZ = getFloatVal(hAccXYZHistXLimMin);
        xLimMaxXYZ = getFloatVal(hAccXYZHistXLimMax);
        if xLimMinMag >= xLimMaxMag || xLimMinXYZ >= xLimMaxXYZ
            warndlg('Limit min must be < max');
            return;
        end
        if binCountMag < 1 || binCountXYZ < 1
            warndlg('Bin size too small!');
            return;
        end
        if hSaveImagesCheckbox.Value == 1
            saveImages = true;
            [source_path,~,~] = fileparts(full_path);
            imgFiles_path = [source_path filesep 'Images - Accel hist'];
            if ~exist(imgFiles_path,'dir')
                mkdir(imgFiles_path);
            end
        else
            saveImages = false;
        end
        if strcmp('Full recording',get(get(hOptPlotRangeButtonGroup,'selectedobject'),'String'))
            startIndex = 1;
            endIndex = length(C3.accel.data);
        end
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = round(screenSize(3)*0.025);
        winYpos = round(screenSize(4)*0.02);
        winWidth = round(screenSize(3)*0.9);
        winHeight = round(screenSize(4)*0.9);
        paperSize = [(winWidth/72)*2.54 (winHeight/72)*2.54];
        paperPosition = [0 0 (winWidth/72)*2.54 (winHeight/72)*2.54];
        hFig = figure('Numbertitle','off','Name','Acceleration magnitude','Position',[winXpos winYpos winWidth winHeight],'PaperUnits','centimeters','PaperSize',paperSize,'PaperPosition',paperPosition);
        hAxMag = axes('Parent',hFig,'Position',[0.04 0.555 0.44 0.42], 'Box', 'on');
        hAxX = axes('Parent',hFig,'Position',[0.54 0.555 0.44 0.42], 'Box', 'on');
        hAxY = axes('Parent',hFig,'Position',[0.04 0.05 0.44 0.42], 'Box', 'on');
        hAxZ = axes('Parent',hFig,'Position',[0.54 0.05 0.44 0.42], 'Box', 'on');
        binEdgesMag = linspace(xLimMinMag,xLimMaxMag,binCountMag+1);
        binEdgesXYZ = linspace(xLimMinXYZ,xLimMaxXYZ,binCountXYZ+1);
        histogram(C3.accelmag.data(startIndex:endIndex), binEdgesMag, 'Normalization', 'probability', 'FaceColor', 'k','EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxMag);
        histogram(C3.accel.data(startIndex:endIndex,1), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', 'r', 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxX);
        histogram(C3.accel.data(startIndex:endIndex,2), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', [0 0.75 0], 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxY);
        histogram(C3.accel.data(startIndex:endIndex,3), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', 'b', 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxZ);
        hAxMag.XLim = [xLimMinMag xLimMaxMag];
        hAxX.XLim = [xLimMinXYZ xLimMaxXYZ];
        hAxY.XLim = [xLimMinXYZ xLimMaxXYZ];
        hAxZ.XLim = [xLimMinXYZ xLimMaxXYZ];
        % Setting the YLim just a bit lower than 0, to avoid that the bar edges
        % overlay the bottom x-axis.
        yMinMagLim = -(hAxMag.YLim(2) / 300.0);
        hAxMag.YLim = [yMinMagLim hAxMag.YLim(2)];
        yMinXLim = -(hAxX.YLim(2) / 300.0);
        hAxX.YLim = [yMinXLim hAxX.YLim(2)];
        yMinYLim = -(hAxY.YLim(2) / 300.0);
        hAxY.YLim = [yMinYLim hAxY.YLim(2)];
        yMinZLim = -(hAxZ.YLim(2) / 300.0);
        hAxZ.YLim = [yMinZLim hAxZ.YLim(2)];
        grid(hAxMag,'on');
        grid(hAxX,'on');
        grid(hAxY,'on');
        grid(hAxZ,'on');
        hAxMag.YTickLabelRotation = 90;
        hAxMag.FontSize = 11;
        xlabel(hAxMag,'Acceleration magnitude (g-force)','FontSize',11);
        ylabel(hAxMag,'Normalized sample count','FontSize',11);
        xlabel(hAxX,'Acceleration X (g-force)','FontSize',11);
        ylabel(hAxX,'Normalized sample count','FontSize',11);
        xlabel(hAxY,'Acceleration Y (g-force)','FontSize',11);
        ylabel(hAxY,'Normalized sample count','FontSize',11);
        xlabel(hAxZ,'Acceleration Z (g-force)','FontSize',11);
        ylabel(hAxZ,'Normalized sample count','FontSize',11);
        nameStr = '';
        if ~isempty(jsondata)
            if isfield(jsondata, 'patientname')
                if strcmp(jsondata.patientname,'Not specified')
                    nameStr = '';
                else
                    nameStr = jsondata.patientname;
                end
            end
        end
        rangeStr = getRangeStrForPlotTitle(xAxisTimeStamps,timeBase,startIndex,endIndex,'Accel');
        title(hAxMag,sprintf('Acceleration magnitude  %s  %s',nameStr, rangeStr),'FontSize',12,'FontWeight','bold');
        title(hAxX,sprintf('Acceleration X  %s  %s',nameStr, rangeStr),'FontSize',12,'FontWeight','bold');
        title(hAxY,sprintf('Acceleration Y  %s  %s',nameStr, rangeStr),'FontSize',12,'FontWeight','bold');
        title(hAxZ,sprintf('Acceleration Z  %s  %s',nameStr, rangeStr),'FontSize',12,'FontWeight','bold');
        if saveImages
            imgTitleStr = ['Accel mag hist ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'Accel')];
            print(hFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng','-r90');
        end
    end
end

function floatVal = getFloatVal(hEdit)
    if all(ismember(hEdit.String, '1234567890.-'))
        if isempty(hEdit.String)
            floatVal = 0;
        else
            floatVal = str2double(hEdit.String);
        end
    else
        warndlg('Numerical input is required!');
    end
end

function intVal = getIntVal(hEdit)
    if all(ismember(hEdit.String, '1234567890-'))
        if isempty(hEdit.String)
            intVal = 0;
        else
            intVal = str2double(hEdit.String);
        end
    else
        warndlg('Integer input is required!');
    end
end
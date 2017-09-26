function c3_gui()
% WORK IN PROGRESS! Needs cleanup from old code, etc. %testtest

%% Initialize variables
hTic_buildingGUI = tic;

% Root path to Cortrium Matlab scripts
cortrium_matlab_scripts_root_path = getCortriumScriptsRoot;
bin_path = fullfile(cortrium_matlab_scripts_root_path,'bin');

% create new C3 object, empty until a sensor data directory has been selected
C3 = cortrium_c3('');
jsondata = struct([]);
jsondata_class_segment = struct([]);
reportIOmarkers = struct([]);
eventMarkers = struct([]);
rhytmAnns = struct([]);
pathName = '';
partialPathStr = '';
sourceName = '';
fileName = '';
full_path = '';
json_fullpath = '';
jsondata_class_fullpath = '';
classification_fullpath = '';
last_path = '';
conf = [];
% cS, a struct for ECGkit classification results
cS = struct([]);
% qrsAnn, a cell array for QRS annotations
qrsAnn = cell(0);
% gS, a struct to keep track of various options in the GUI, such as whether to flip ecg channels, etc.
gS = struct('dataLoaded',false,...
            'flipEcg1',false,...
            'flipEcg2',false,...initialize
            'flipEcg3',false,...
            'ecgMarkerMode',false,...
            'ecgMarkerDisplay',false,...
            'ecgInpointSet',false,...
            'eventMarkerMode',false,...
            'eventMarkerDisplay',false,...
            'classAnnDragSel',false,...
            'rhythmAnnMode','none',...
            'rhythmAnnECGInSet',false,...
            'rhythmAnnRespInSet',false,...
            'rhythmAnnAccelInSet',false,...
            'rhythmAnnDispECG',false,...
            'rhythmAnnDispResp',false,...
            'rhythmAnnDispAccel',false,...
            'ecgBrowserCh',1,...
            'ecgBrowserNumRows',6,...
            'ecgBrowserYminmV',-0.75,...
            'ecgBrowserYmaxmV',0.75,...
            'unitsPrmV',0,...
            'colors',[]);
                    
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

gS.colors.col = {[1 0 0],... % red, for ECG1, Resp, AccelX, Temp Obj
                 [0 0.6 0],... % green
                 [0 0 1],... % blue
                 [0 0 0],... % black
                 [1 1 1],... % white
                 [0.5 0.5 0.5],... % grey
                 [1.0 0.68 0.1],... % light-orange, for event markers
                 [0.7451 0.2078 0.8588],... % purple-ish, for analysis markers
                 [0.95 0.45 0],... % S
                 [0.95 0 0.95],... % V
                 [0, 0.7 0.3],... % F
                 [0.5000 0.8016 1],... % U
                 [0 0.4470 0.7410],... % N
                 panelColor}; % can be set in ECG Browser

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

ibims = []; ibiDiffms = []; qrsAnnIndices = []; stdIBISegments = [];
ibiSegmentSampleNums = [];

hAxECGbrowser = gobjects(6,1);
hAxAnnECGbrowser = gobjects(6,1);

%% GUI

% (MATLAB R2014b+) turn off graphics smoothing on graphics root object
% set(groot,'DefaultFigureGraphicsSmoothing','off')

% Create GUI window, visibility is turned off while the GUI elements are added
hFig = figure('Name','Cortrium C3 sensor data',...
    'Numbertitle','off',...
    'OuterPosition', [1 1 screenWidth-1 screenHeight-1],...
    'MenuBar', 'figure',...
    'Toolbar','none',...
    'Visible','off',...
    'KeyPressFcn',@guiKeyPressFcn,...
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
    'Position',[0.05 0.85 0.9 0.12],...
    'HorizontalAlignment','left',...
    'String','Recording:',...
    'FontSize',8,...
    'ForegroundColor',dimmedTextColor,...
    'BackgroundColor',panelColor);

hTextTimeRecording = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.75 0.9 0.12],...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% text label for time info, total duration of recording
uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.61 0.9 0.12],...
    'HorizontalAlignment','left',...
    'String','Total duration:',...
    'FontSize',8,...
    'ForegroundColor',dimmedTextColor,...
    'BackgroundColor',panelColor);

hTextDurationRecording = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.51 0.9 0.12],...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% text label for time info, displayed time
hLabelTimeDisplayed = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05 0.37 0.9 0.12],...
    'HorizontalAlignment','left',...
    'String','Displayed:',...
    'FontSize',8,...
    'ForegroundColor',dimmedTextColor,...
    'BackgroundColor',panelColor);

hTextTimeDisplayed = uicontrol('Parent',hPanelTimeInfo,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.05,0.27,0.9,0.12],...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio buttons group, duration-based time vs. world time
hTimebaseButtonGroup = uibuttongroup('Parent',hPanelTimeInfo,...
    'Units','normalized',...
    'Position',[0.05,0.04,0.9,0.21],...
    'BackgroundColor',panelColor,...
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

% Button, Full Range
hResetButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.77,0.9,0.2],...
    'String','Full Range',...
    'FontSize',12,...
    'Callback',@rangeButtonFcn);

% Popup menu, for selecting a range (how many samples are plotted)
hPopupRange = uicontrol('Parent',hPanelNavigateData,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.53,0.552,0.415,0.17],...
    'String', {'Select range...','1 sec','2 sec','5 sec','10 sec','30 sec','1 min','2 min','5 min'},...
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
    'String','<< Event',...
    'FontSize',10,...
    'Callback',@navEventLefFcn);

% Button, Navigate Event right
hNavEventRightButton = uicontrol('Parent',hPanelNavigateData,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.7,0.038,0.25,0.17],...
    'String','Event >>',...
    'FontSize',10,...
    'Callback',@navEventRightFcn);

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
    'Title','ECG - flip channels vertically',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.91 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG1 flip
hFlipEcg1Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 1',...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,1});

% Checkbox, toggles ECG2 flip
hFlipEcg2Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 2',...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,2});

% Checkbox, toggles ECG3 flip
hFlipEcg3Checkbox = uicontrol('Parent',hPanelFlipECG,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 3',...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',{@flipEcgFunc,3});

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
    'Value',9,...
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
    'Position',[0.025,0.84,0.9,0.14],...
    'Value',0,...
    'String','Missing packets',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Checkbox, toggles ECG NaN error codes
hEcgNanErrCodesCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.68,0.9,0.14],...
    'Value',0,...
    'String','Error codes (16bit)',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Checkbox, toggles ECG NaN for abs(ecg) >
hEcgNanAbsEcgCheckbox = uicontrol('Parent',hPanelEcgNan,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.52,0.35,0.14],...
    'Value',0,...
    'String','Abs(ECG) >',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text-edit for entering absolute value for setting ECG to NaN
hEcgNanAbsEcg = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.375,0.51,0.15,0.14],...
    'String','25000',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG abs value window size
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.105,0.35,0.55,0.13],...
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
    'Position',[0.64,0.36,0.14,0.14],...
    'String','250',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG abs value window size, indicating the number refers to samples"
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.79,0.35,0.5,0.13],...
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
    'Position',[0.025,0.17,0.35,0.17],...
    'Value',0,...
    'String','Accel mag <',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text-edit for entering min Accel mag criteria for setting ECG to NaN
hEcgNanMinAccMag = uicontrol('Parent',hPanelEcgNan,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.375,0.18,0.15,0.14],...
    'String','0.95',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag, between fields for min/max Accel mag
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.535,0.16,0.1,0.14],...
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
    'Position',[0.64,0.18,0.14,0.14],...
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
    'Position',[0.64,0.02,0.14,0.14],...
    'String','50',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor,...
    'Callback',{@filterIntermediateToggleFunc,'ecg'});

% Text label, for ECG NaN Accel mag window size, indicating the numbers refers to packets
uicontrol('Parent',hPanelEcgNan,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.79,0.02,0.5,0.13],...
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
    'Position',[0.025,0.55,0.9,0.4],...
    'Value',1,...
    'String','Highpass',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'resp'});

% Checkbox, toggles Resp Lowpass filter
hRespLowpassCheckbox = uicontrol('Parent',hPanelFilterResp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.08,0.9,0.4],...
    'Value',0,...
    'String','Lowpass',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'resp'});

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
    'Position',[0.025,0.55,0.9,0.4],...
    'Value',0,...
    'String','Remove Jitter',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'accel'});

% Checkbox, toggles Accel median filter
hAccelMedianCheckbox = uicontrol('Parent',hPanelFilterAccel,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.025,0.08,0.9,0.4],...
    'Value',0,...
    'String','Median',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'accel'});

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
    'Position',[0.025,0.08,0.9,0.9],...
    'Value',0,...
    'String','Remove Jitter',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',{@filterIntermediateToggleFunc,'temp'});

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
    'Position',[0.68,0.55,0.3,0.36],...
    'Value',0,...
    'String','Display',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@eventsShowMarkersFcn);

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

% create a parent panel for ECGkit results sub-panels
hPanelParentECGkitAnalysis = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons related to ECGkit results
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
    'Position',[0.68,0.745,0.3,0.25],...
    'Value',0,...
    'String','Display',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitShowMarkersFcn);

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
    'Position',[0.02,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 1',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG2 analysis
hAnalyseEcg2Checkbox = uicontrol('Parent',hPanelECGanalysis,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 2',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG3 analysis
hAnalyseEcg3Checkbox = uicontrol('Parent',hPanelECGanalysis,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 3',...
    'Enable','on',...
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
    'Position',[0.03,0.6,0.3,0.26],...
    'Value',1,...
    'String','Make PDF',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Checkbox, open pdf
hECGkitOpenPDFCheckbox = uicontrol('Parent',hPanelECGkitGenReport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.6,0.6,0.26],...
    'Value',1,...
    'String','Open PDF',...
    'Enable','on',...
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
if ~exist([cortrium_matlab_scripts_root_path filesep 'reportScripts'],'dir') || ~exist('InstallECGkit','file')
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

%% -----Panel: ECGkit Results-----

% create a parent panel for ECGkit results sub-panels
hPanelParentECGkitResults = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons related to ECGkit results
hPanelECGkitResults = uipanel('Parent',hPanelParentECGkitResults,...
    'Title','ECGkit Results',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Button, load ECGkit classification results
hButtonLoadECGkitClass = uicontrol('Parent',hPanelParentECGkitResults,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.895,0.45,0.06],...
    'String','Load',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@loadEcgkitClassFunc);

% Sub-panel for ECGkit beat-classification annotations
hPanelECGkitClass = uipanel('Parent',hPanelECGkitResults,...
    'Title','Heartbeat classification',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.66 0.9 0.24],...
    'BackgroundColor',panelColor);

% Checkbox, toggles display of In-Out markers
hECGkitClassCheckbox = uicontrol('Parent',hPanelECGkitClass,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.78,0.98,0.2],...
    'Value',0,...
    'String','Display (range must be <= 1 min)',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgkitShowClassFcn);

% Text label, for N class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.58,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','N:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for V class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.38,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','V:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for F class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.42,0.58,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','F:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for S class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.42,0.38,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','S:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for U class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.8,0.58,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','U:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, N class count
hClassCountN = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.075,0.58,0.25,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, V class count
hClassCountV = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.075,0.38,0.25,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, F class count
hClassCountF = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.475,0.58,0.25,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, S class count
hClassCountS = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.475,0.38,0.25,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for | (artefact) class
uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.8,0.38,0.1,0.16],...
    'HorizontalAlignment','left',...
    'String','|:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, U class count
hClassCountU = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.855,0.58,0.125,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, | (artefact) class count
hClassCountArtefact = uicontrol('Parent',hPanelECGkitClass,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.855,0.38,0.125,0.16],...
    'HorizontalAlignment','left',...
    'String','NaN',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, navigate to the left for selected class
hButtonNavLeftClass = uicontrol('Parent',hPanelECGkitClass,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.25,0.26],...
    'String','<<',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@classNavLeftFunc);

% Popup menu, for selecting an event to navigate to
hPopupClass = uicontrol('Parent',hPanelECGkitClass,...
    'Style', 'popup',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.3,0.1,0.4,0.2],...
    'String', {'Select...',...
    'N (Normal beat)',...
    'V (Ventricular premature)',...
    'S (Supraventricular)',...
    'F (Fusion of normal and ventricular)',...
    'U (Unclassified)',...
    '| (QRS-like noise)'},...
    'FontSize',10);
hPopupClass.Value = 1;

% Button, navigate to the right for selected class
hButtonNavRightClass = uicontrol('Parent',hPanelECGkitClass,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.73,0.05,0.25,0.26],...
    'String','>>',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@classNavRightFunc);

% Sub-panel for Drag-select of multiple beat class annotations
hPanelClassAnnSel = uipanel('Parent',hPanelECGkitResults,...
    'Title','Drag-select to edit multiple annotations',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.51 0.9 0.14],...
    'BackgroundColor',panelColor);

% Button, Drag-select of multiple beat class annotations
hBtnClassAnnSel = uicontrol('Parent',hPanelClassAnnSel,...
    'Style','togglebutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.8],...
    'String','Drag-select',...
    'FontSize',10,...
    'Value',0,...
    'Enable','off',...
    'Callback',@classAnnSelFunc);

% Button, load ECGkit classification results
hButtonSaveECGkitClass = uicontrol('Parent',hPanelParentECGkitResults,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.05,0.40,0.45,0.06],...
    'String','Save',...
    'FontSize',10,...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@saveEcgkitClassFunc);

%% -----Panel: QRS detection -----

% create a parent panel for beat detection
hPanelParentQRS = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons related to beat detection
hPanelQRS = uipanel('Parent',hPanelParentQRS,...
    'Title','QRS Detection',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Checkbox, display markers
hDisplayBeatsCheckbox = uicontrol('Parent',hPanelQRS,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.05,0.95,0.95,0.04],...
    'Value',1,...
    'String','Display beat-markers (range must be <= 1 min)',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@showQRSannFnc);

% Checkbox, open IBI panel after detection
hIBIpanelCheckbox = uicontrol('Parent',hPanelQRS,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.05,0.9,0.95,0.04],...
    'Value',1,...
    'String','Open IBI panel when detection is completed',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Panel, ECG channel
hPanelECGch = uipanel('Parent',hPanelQRS,...
    'Title','ECG channel',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05,0.78,0.425,0.1],...
    'BackgroundColor',panelColor);

% Popup menu, for selecting an ECG channel
hPopupECGch = uicontrol('Parent',hPanelECGch,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.1,0.1,0.8,0.8],...
    'String', {'1','2','3'},...
    'FontSize',10);
hPopupECGch.Value = 1;

% Panel, QRS detector
hPanelQRSdet = uipanel('Parent',hPanelQRS,...
    'Title','QRS Detector',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.525,0.78,0.425,0.1],...
    'BackgroundColor',panelColor);

% Popup menu, for selecting aQRS detector
hPopupQRSdet = uicontrol('Parent',hPanelQRSdet,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.1,0.1,0.8,0.8],...
    'String', {'gqrs','wqrs'},...
    'FontSize',10);
hPopupQRSdet.Value = 1;

% Radio buttons group, select whether export will be of displayed range or entire length of recording
hOptQRSRangeButtonGroup = uibuttongroup('Parent',hPanelQRS,...
    'Units','normalized',...
    'Position',[0.05,0.69,0.9,0.08],...
    'BackgroundColor',panelColor,...
    'Title','Range (for new QRS detections)');

% Radio button, displayed range
hOptQRSRangeButton1 = uicontrol(hOptQRSRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Displayed',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Radio button, full length
hOptQRSRangeButton2 = uicontrol(hOptQRSRangeButtonGroup,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','Full recording',...
    'Units','normalized',...
    'Position',[0.35,0.05,0.4,1],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hOptQRSRangeButtonGroup,'selectedobject',hOptQRSRangeButton1);

% Button, Detect QRS
hButtonDetectQRS = uicontrol('Parent',hPanelQRS,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.6,0.9,0.07],...
    'String','Detect QRS',...
    'FontSize',12,...
    'Callback',@detectQRSFcn);

% Button, Load detection
hButtonLoadQRS = uicontrol('Parent',hPanelQRS,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.51,0.9,0.07],...
    'String','Load QRS detection',...
    'FontSize',12,...
    'Callback',@loadQRSFcn);

% Text label, for total beats
uicontrol('Parent',hPanelQRS,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.05,0.45,0.5,0.035],...
    'HorizontalAlignment','left',...
    'String','Total beats:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for total beats
hTxtTotalBeats = uicontrol('Parent',hPanelQRS,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.26,0.45,0.35,0.035],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for total beats ("in current detection")
uicontrol('Parent',hPanelQRS,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.55,0.45,0.45,0.035],...
    'HorizontalAlignment','left',...
    'String','(in current detection)',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

%% -----Panel: IBI -----

% create a parent panel for inter-beat-interval stats
hPanelParentIBI = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel for buttons related to inter-beat-interval stats
hPanelIBI = uipanel('Parent',hPanelParentIBI,...
    'Title','Interbeat Intervals',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Checkbox, display markers
hDisplayIBICheckbox = uicontrol('Parent',hPanelIBI,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.05,0.95,0.95,0.04],...
    'Value',1,...
    'String','Display IBI''s (range must be <= 30 sec)',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@showIBIFnc);

% Sub-panel for IBI statistics
hPanelIBIstats = uipanel('Parent',hPanelIBI,...
    'Title','IBI statistics (units in ms)',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.72 0.9 0.225],...
    'BackgroundColor',panelColor);

% Text label, for IBI
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.18,0.78,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','IBI:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for IBI diff
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.38,0.78,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','IBI diff:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for min IBI
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.6,0.16,0.18],...
    'HorizontalAlignment','left',...
    'String','min:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for mean IBI
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.4,0.14,0.18],...
    'HorizontalAlignment','left',...
    'String','mean:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for max IBI
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.2,0.14,0.18],...
    'HorizontalAlignment','left',...
    'String','max:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, for IBI standard deviation
uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0,0.16,0.18],...
    'HorizontalAlignment','left',...
    'String','std:',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBI min
hTxtIBImin = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.18,0.6,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBI mean
hTxtIBImean = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.18,0.4,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBI max
hTxtIBImax = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.18,0.2,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBI std
hTxtIBIstd = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.18,0,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBIdiff min
hTxtIBIdiffmin = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.38,0.6,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBIdiff mean
hTxtIBIdiffmean = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.38,0.4,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBIdiff max
hTxtIBIdiffmax = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.38,0.2,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, for IBIdiff std
hTxtIBIdiffstd = uicontrol('Parent',hPanelIBIstats,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.38,0,0.18,0.18],...
    'HorizontalAlignment','left',...
    'String','',...
    'FontWeight','normal',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Sub-panel for IBI search
hPanelIBIsearch = uipanel('Parent',hPanelIBI,...
    'Title','Search IBI''s',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.53 0.9 0.18],...
    'BackgroundColor',panelColor);

% Radio buttons group, IBI < or >
hIBIsearchBtGrp = uibuttongroup('Parent',hPanelIBIsearch,...
    'Units','normalized',...
    'Position',[0.02,0.4,0.96,0.58],...
    'BackgroundColor',panelColor,...
    'BorderType','none');

% Radio button, IBI <
hIBIsearchBt1 = uicontrol(hIBIsearchBtGrp,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','IBI < ',...
    'Units','normalized',...
    'Position',[0,0.5,0.4,0.5],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Text-edit, value for IBI search less than
hIBIlessThan = uicontrol('Parent',hIBIsearchBtGrp,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.18,0.55,0.16,0.4],...
    'String','500',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, ms
uicontrol('Parent',hIBIsearchBtGrp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.35,0.55,0.1,0.36],...
    'HorizontalAlignment','left',...
    'String','ms',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio button, IBI >
hIBIsearchBt2 = uicontrol(hIBIsearchBtGrp,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','IBI > ',...
    'Units','normalized',...
    'Position',[0,0,0.4,0.5],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hIBIsearchBtGrp,'selectedobject',hIBIsearchBt1);

% Text-edit, value for IBI search greater than
hIBIgreaterThan = uicontrol('Parent',hIBIsearchBtGrp,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.18,0.05,0.16,0.4],...
    'String','1500',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, ms
uicontrol('Parent',hIBIsearchBtGrp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.35,0.05,0.1,0.36],...
    'HorizontalAlignment','left',...
    'String','ms',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, Search left
hIBIsearchLeft = uicontrol('Parent',hPanelIBIsearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.44,0.32],...
    'String','<<',...
    'FontSize',12,...
    'Callback',@IBISearchFcn);

% Button, Search left
hIBIsearchRight = uicontrol('Parent',hPanelIBIsearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.54,0.05,0.44,0.32],...
    'String','>>',...
    'FontSize',12,...
    'Callback',@IBISearchFcn);

% Sub-panel for IBIdiff search
hPanelIBIdiffSearch = uipanel('Parent',hPanelIBI,...
    'Title','Search IBI differences''s',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.34 0.9 0.18],...
    'BackgroundColor',panelColor);

% Radio buttons group, IBI diff search
hIBIdiffSearchBtGrp = uibuttongroup('Parent',hPanelIBIdiffSearch,...
    'Units','normalized',...
    'Position',[0.02,0.4,0.96,0.58],...
    'BackgroundColor',panelColor,...
    'BorderType','none');

% Radio button, IBI diff <
hIBIdiffSearchBt1 = uicontrol(hIBIdiffSearchBtGrp,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','IBI diff < ',...
    'Units','normalized',...
    'Position',[0,0.5,0.4,0.5],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');

% Text-edit, value for IBI diff search less than
hIBIdiffLessThan = uicontrol('Parent',hIBIdiffSearchBtGrp,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.27,0.55,0.16,0.4],...
    'String','-150',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, ms
uicontrol('Parent',hIBIdiffSearchBtGrp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.44,0.55,0.1,0.36],...
    'HorizontalAlignment','left',...
    'String','ms',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Radio button, IBI diff >
hIBIdiffSearchBt2 = uicontrol(hIBIdiffSearchBtGrp,...
    'Style','radiobutton',...
    'Enable','on',...
    'String','IBI diff > ',...
    'Units','normalized',...
    'Position',[0,0,0.4,0.5],...
    'BackgroundColor',panelColor,...
    'HandleVisibility','off');
% preselecting one of the radio buttons
set(hIBIdiffSearchBtGrp,'selectedobject',hIBIdiffSearchBt1);

% Text-edit, value for IBI diff search greater than
hIBIdiffGreaterThan = uicontrol('Parent',hIBIdiffSearchBtGrp,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.27,0.05,0.16,0.4],...
    'String','150',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, ms
uicontrol('Parent',hIBIdiffSearchBtGrp,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.44,0.05,0.1,0.36],...
    'HorizontalAlignment','left',...
    'String','ms',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, Search left
hIBIdiffSearchLeft = uicontrol('Parent',hPanelIBIdiffSearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.02,0.05,0.44,0.32],...
    'String','<<',...
    'FontSize',12,...
    'Callback',@IBIdiffSearchFcn);

% Button, Search left
hIBIdiffSearchRight = uicontrol('Parent',hPanelIBIdiffSearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.54,0.05,0.44,0.32],...
    'String','>>',...
    'FontSize',12,...
    'Callback',@IBIdiffSearchFcn);

% Sub-panel for segmentation and std dev search
hPanelStdSearch = uipanel('Parent',hPanelIBI,...
    'Title','Search IBI Standard Deviation',...
    'BorderType','etchedin',...
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.01 0.9 0.32],...
    'BackgroundColor',panelColor);

% Text label, Segment size
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.86,0.35,0.11],...
    'HorizontalAlignment','left',...
    'String','Segment size:',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit, value for IBI search greater than
hSegmentSec = uicontrol('Parent',hPanelStdSearch,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.33,0.86,0.12,0.12],...
    'String','10',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, seconds
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.46,0.86,0.25,0.11],...
    'HorizontalAlignment','left',...
    'String','seconds',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, Search left
hBtAnalyseSegments = uicontrol('Parent',hPanelStdSearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.02,0.62,0.96,0.2],...
    'String','Analyse segments',...
    'FontSize',12,...
    'Callback',@analyseSegmentsFcn);

% Text label, Std min
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.43,0.21,0.11],...
    'HorizontalAlignment','left',...
    'String','Min std:',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, Std min
hStdMin = uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.19,0.43,0.12,0.11],...
    'HorizontalAlignment','left',...
    'String','',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, Std mean
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.33,0.43,0.23,0.11],...
    'HorizontalAlignment','left',...
    'String','Mean std:',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, Std mean
hStdMean = uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.54,0.43,0.14,0.11],...
    'HorizontalAlignment','left',...
    'String','',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, Std max
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.69,0.43,0.21,0.11],...
    'HorizontalAlignment','left',...
    'String','Max std:',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text, Std max
hStdMax = uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.87,0.43,0.14,0.11],...
    'HorizontalAlignment','left',...
    'String','',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text label, Std >
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.25,0.14,0.11],...
    'HorizontalAlignment','left',...
    'String','Std >',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Text-edit, value for search Std greater than
hStdGreaterThan = uicontrol('Parent',hPanelStdSearch,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.15,0.25,0.12,0.12],...
    'String','50',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, ms
uicontrol('Parent',hPanelStdSearch,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.28,0.25,0.14,0.11],...
    'HorizontalAlignment','left',...
    'String','ms',...
    'ForegroundColor',[0 0 0],...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Button, Search left
hStdSearchLeft = uicontrol('Parent',hPanelStdSearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.02,0.03,0.44,0.18],...
    'String','<<',...
    'FontSize',12,...
    'Callback',@stdSearchFcn);

% Button, Search left
hStdSearchRight = uicontrol('Parent',hPanelStdSearch,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.54,0.03,0.44,0.18],...
    'String','>>',...
    'FontSize',12,...
    'Callback',@stdSearchFcn);

%% -----Panel: Rhythm Annotation-----

% create a parent panel for Rhythm Annotation
hPanelParentECGrhythmAnn = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel related to Rhythm Annotation
hPanelECGrhythmAnn = uipanel('Parent',hPanelParentECGrhythmAnn,...
    'Title','Rhythm Annotation',...
    'BorderType','line',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0 0 1 1],...
    'BackgroundColor',panelColor);

% Sub-panel for Display of Rhythm Annotations
hPanelRhytmAnnDisp = uipanel('Parent',hPanelECGrhythmAnn,...
    'Title','Display rhythm annotations',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.91 0.9 0.08],...
    'BackgroundColor',panelColor);

% Checkbox, Display ECG rhythm annotations
hECGrhythmAnnCheckbox = uicontrol('Parent',hPanelRhytmAnnDisp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.02,0.08,0.3,0.9],...
    'Value',1,...
    'String','ECG',...
    'Enable','on',...
    'BackgroundColor',panelColor,...
    'Callback',@ecgrhytmAnnshowFcn);

hRespRhytmAnnCheckbox = uicontrol('Parent',hPanelRhytmAnnDisp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.3,0.9],...
    'Value',0,...
    'String','Resp',...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@resprhytmAnnshowFcn);

hAccelRhytmAnnCheckbox = uicontrol('Parent',hPanelRhytmAnnDisp,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.3,0.9],...
    'Value',0,...
    'String','Accel',...
    'Enable','off',...
    'BackgroundColor',panelColor,...
    'Callback',@accelrhytmAnnshowFcn);

% Sub-panel 
hPanelRhythmSelM2 = uipanel('Parent',hPanelECGrhythmAnn,...
    'Title','Turn on rhythm annotation mode',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.76 0.9 0.14],...
    'BackgroundColor',panelColor);

% Button, Set segment in-point
hButtonRhythmSelClick = uicontrol('Parent',hPanelRhythmSelM2,...
    'Style','togglebutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.8],...
    'String','Rhythm Annotation Mode',...
    'FontSize',10,...
    'Value',0,...
    'Enable','off',...
    'Callback',@rhythmAnnClickFunc);

% Button, Save annotations
hButtonSaveRhytmAnn = uicontrol('Parent',hPanelECGrhythmAnn,...
    'Style','pushbutton',...
    'Enable','off',...
    'Units','normalized',...
    'Position',[0.05,0.66,0.9,0.09],...
    'String','Save Annotations',...
    'FontSize',12,...
    'Callback',@rhytmAnnsaveFunc);


%% -----Panel: Miscellaneous Plots-----

% create a parent panel for optional plots
hPanelParentOptionalPlots = uipanel('Parent',hPanelMain,...
    'Visible','off',...
    'BorderType','none',...
    'Units','normalized',...
    'Position',[0.84 0.01 0.15 0.5],...
    'BackgroundColor',panelColor);

% create a panel related to optional plots
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
    'Position',[0.05,0.95,0.45,0.04],...
    'Value',0,...
    'String','Save images',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Text-edit for image resolution
hImageRes = uicontrol('Parent',hPanelOptionalPlots,...
    'Style','edit',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.4,0.95,0.12,0.04],...
    'String','72',...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'BackgroundColor',editColor);

% Text label, for image resolution
uicontrol('Parent',hPanelOptionalPlots,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.52,0.945,0.15,0.04],...
    'HorizontalAlignment','left',...
    'String','ppi',...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',panelColor);

% Checkbox, save text
hSaveTextCheckbox = uicontrol('Parent',hPanelOptionalPlots,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.05,0.91,0.4,0.04],...
    'Value',0,...
    'String','Save text',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Radio buttons group, select whether export will be of displayed range or entire length of recording
hOptPlotRangeButtonGroup = uibuttongroup('Parent',hPanelOptionalPlots,...
    'Units','normalized',...
    'Position',[0.05,0.82,0.9,0.08],...
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
    'Position',[0.05 0.71 0.9 0.1],...
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
    'Position',[0.05 0.45 0.9 0.25],...
    'BackgroundColor',panelColor);

% Text label, Bin count for Mag
uicontrol('Parent',hPanelAccMag,...
    'Style','text',...
    'Units','normalized',...
    'position',[0.02,0.73,0.23,0.18],...
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
    'Position',[0.25,0.76,0.12,0.19],...
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
    'position',[0.02,0.47,0.23,0.18],...
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
    'Position',[0.25,0.5,0.12,0.19],...
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
    'Position',[0.02,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 1',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG2 export
hExportEcg2Checkbox = uicontrol('Parent',hPanelECGexport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.35,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 2',...
    'Enable','on',...
    'BackgroundColor',panelColor);

% Checkbox, toggles ECG3 export
hExportEcg3Checkbox = uicontrol('Parent',hPanelECGexport,...
    'Style','checkbox',...
    'Units','normalized',...
    'Position',[0.68,0.08,0.3,0.9],...
    'Value',0,...
    'String','ECG 3',...
    'Enable','on',...
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

% Sub-panel for exporting ECG to Kubios custom ASCII format
hPanelECGKubiosexport = uipanel('Parent',hPanelExport,...
    'Title','ECG to Kubios (custom ASCII txt)',...
    'BorderType','etchedin',... %
    'HighlightColor',panelBorderColor,...
    'Units','normalized',...
    'Position',[0.05 0.49 0.9 0.1],...
    'BackgroundColor',panelColor);

% Button, Export
hButtonExportECGtoKubios = uicontrol('Parent',hPanelECGKubiosexport,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02,0.1,0.96,0.85],...
    'String','Export ECG to Kubios',...
    'FontSize',10,...
    'Enable','off',...
    'Callback',@exportECGtoKubiosFunc);


%% -----Popup menu, for selecting functionality panels-----

hParentPanels = [hPanelParentFiltering,hPanelParentEventAnnotation,hPanelParentECGkitAnalysis,hPanelParentECGkitResults,hPanelParentQRS,hPanelParentIBI,hPanelParentECGrhythmAnn,hPanelParentOptionalPlots,hPanelParentExport];

% Popup menu, for selecting functionality panels
hPopupPanel = uicontrol('Parent',hPanelMain,...
    'Style', 'popup',...
    'Enable','on',...
    'Units','normalized',...
    'Position',[0.84,0.49,0.15,0.05],...
    'String',  {'Filtering',...
                'Event Markers',...
                'ECGkit Analysis',...
                'ECGkit Results',...
                'QRS Detection',...
                'Interbeat Intervals',...
                'Rhythm Annotation',...
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

% Axes object for ECG rhythm annotations, behind of ECG axes
% object, otherwise exact same position.
hAxesECGrhythmAnn= axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19]);
xlim(hAxesECGrhythmAnn,'manual');
ylim(hAxesECGrhythmAnn,'manual');
hold(hAxesECGrhythmAnn,'on');
set(hAxesECGrhythmAnn,'Xticklabel',[]);
set(hAxesECGrhythmAnn,'Yticklabel',[]);
hAxesECGrhythmAnn.TickLength = [0 0];
hAxesECGrhythmAnn.YLim = [0 1];

% Axes object for Event Markers plot, behind of ECG axes
% object, otherwise exact same position.
hAxesEventMarkers = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none');
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

% Axes object for ECGkit classification annotations, behind of ECG axes
% object, otherwise exact same position.
hAxesECGkitClass = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none');
xlim(hAxesECGkitClass,'manual');
ylim(hAxesECGkitClass,'manual');
hold(hAxesECGkitClass,'on');
set(hAxesECGkitClass,'Xticklabel',[]);
set(hAxesECGkitClass,'Yticklabel',[]);
hAxesECGkitClass.TickLength = [0 0];
hAxesECGkitClass.YLim = [0 1];

% Axes object for beat-markers, behind of ECG axes
% object, otherwise exact same position.
hAxesQRS = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none');
xlim(hAxesQRS,'manual');
ylim(hAxesQRS,'manual');
hold(hAxesQRS,'on');
set(hAxesQRS,'Xticklabel',[]);
set(hAxesQRS,'Yticklabel',[]);
hAxesQRS.TickLength = [0 0];
hAxesQRS.YLim = [0 1];

% Axes object for ECG plot
hAxesECG = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.785,0.9,0.19], 'Color', 'none', 'Box', 'on');
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
    'ForegroundColor',gS.colors.col{1},...
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
    'ForegroundColor',gS.colors.col{2},...
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
    'ForegroundColor',gS.colors.col{3},...
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

% Button, Full-screen ECG browser in a new, modal, window
hBtnECGbrowser = uicontrol('Parent',hPanelSensorDisplay,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.946,0.785,0.045,0.045],...
    'String','<html><center>ECG<br>browser',...
    'HorizontalAlignment','center',...
    'FontWeight','normal',...
    'FontSize',8,...
    'Callback',@ecgBrowserFunc);

% Axes object for Respiration plot (impedance)
hAxesResp = axes('Parent',hPanelSensorDisplay,...
    'Position',[0.045,0.535,0.9,0.19], 'Box', 'on');
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
    'Position',[0.045,0.285,0.9,0.19], 'Box', 'on');
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
    'ForegroundColor',gS.colors.col{2},...
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
    'Position',[0.045,0.04,0.9,0.19], 'Box', 'on');
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
    'ForegroundColor',gS.colors.col{2},...
    'FontSize',8,...
    'BackgroundColor',panelColor);

%% -----Cortrium logo-----

% create a panel for Cortrium logo
hPanelLogo = uipanel('Parent',hPanelMain,...
    'BorderType','none',... %
    'Units','pixels',...
    'Position',[1 1 125 31],...
    'BackgroundColor',panelColor);
hPanelLogo.Units = 'normalized';
hPanelLogo.Position = [0.759 0.965 hPanelLogo.Position(3) hPanelLogo.Position(4)];

% load Cortrium logo image
logo_cortrium_path = fullfile(bin_path,'Cortrium_logo_w_pod_500x124px.png');
if exist(logo_cortrium_path, 'file') == 2
    [logoCortriumImgData.img, logoCortriumImgData.map, logoCortriumImgData.alpha] = imread(logo_cortrium_path);
else
    warning(['No Cortrium logo file at: ' logo_cortrium_path]);
    logoCortriumImgData = [];
end

% create axes object for Cortrium logo image
if ~isempty(logoCortriumImgData)
    hAxImg = axes('Parent', hPanelLogo, 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    % show the image and set alpha for transparent background
    hImg = imshow(logoCortriumImgData.img, logoCortriumImgData.map, 'InitialMagnification', 'fit', 'Parent', hAxImg);
    hImg.AlphaData = logoCortriumImgData.alpha;
end

%% get actual screen size and set figure window accordingly

% get screen size
screenSize = get(0,'screensize');
screenWidth = screenSize(3);
screenHeight = screenSize(4);
set(hFig,'OuterPosition', [1 1 screenWidth-1 screenHeight-1]);

%% Create context menu for beat class labels
CM_beatClass = uicontextmenu(hFig);
% Create menu items for the uicontextmenu
uimenu(CM_beatClass,'Label','N (Normal beat)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','S (Supraventricular)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','V (Ventricular premature)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','F (Fusion of ventricular and normal)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','U (Unclassifiable)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','| (Isolated QRS-like artifact)','Callback',@setClassAnn);
uimenu(CM_beatClass,'Label','Delete','Callback',@setClassAnn);

%% Make the GUI visible
% linkaxes([hAxesECG hAxesResp hAxesAccel hAxesTemp], 'x');
grid(hAxesECG,'on');
grid(hAxesResp,'on');
grid(hAxesAccel,'on');
grid(hAxesTemp,'on');
hAxesECG.GridAlpha = 0.09;
hAxesResp.GridAlpha = 0.09;
hAxesAccel.GridAlpha = 0.09;
hAxesTemp.GridAlpha = 0.09;
set(hFig,'Visible','on');
fprintf('buildingGUI: %f seconds\n',toc(hTic_buildingGUI));

%% Functions (inline)

    function loadButtonFcn()
        if ~isempty(last_path)
            org_path = cd(last_path);
        else
            org_path = pwd;
        end
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
            clearAxes([hAxesECGrhythmAnn,hAxesEventMarkers,hAxesECGMarkers,hAxesECGkitClass,hAxesQRS,hAxesECG hAxesResp hAxesAccel hAxesTemp]);
            drawnow;
            eventAddMarkersOffOnLoad;
            ecgkitAddMarkersOffOnLoad;
            reportIOmarkers = [];
            eventMarkers = [];
            rhytmAnns = [];
            hEventListBox.Value = [];
            hECGkitListBox.Value = [];
            if hParentPanels(3).Visible
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,0);
            end
            if hParentPanels(2).Visible
                updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
            end
            disableButtons(hButtonEventMarkerAddToggle,hButtonECGkitMarkerAddToggle,hButtonECGkitMarkerOut,hButtonECGkitMarkerDel,hButtonECGkitMarkerEdit,hButtonECGkitMarkerSave);
            disableButtons(hButtonSaveECGkitClass,hIBIsearchLeft,hIBIsearchRight,hIBIdiffSearchLeft,hIBIdiffSearchRight,hBtAnalyseSegments,hStdSearchLeft,hStdSearchRight);
            deselectButtons(hButtonRhythmSelClick);
            rhythmAnnClickFunc([],[]);
            cS = []; qrsAnn = cell(0); ibims = []; ibiDiffms = []; qrsAnnIndices = []; stdIBISegments = []; ibiSegmentSampleNums = [];
            classCountInfoReset(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact);
            gS.dataLoaded = loadAndFormatData;
            if gS.dataLoaded
                last_path = pathName;
                cd(org_path);
                % resetting end times
                timeEnd.world = [];
                timeEnd.duration = [];
                % resetting ECG flip checkboxes
                deselectButtons(hFlipEcg1Checkbox,hFlipEcg2Checkbox,hFlipEcg3Checkbox);
                gS.flipEcg1 = false;
                gS.flipEcg2 = false;
                gS.flipEcg3 = false;
                gS.unitsPrmV = getUnitsPerMillivolt(conf,fileFormat);
                [partialPathStr, sourceName] = updateDirectoryInfo(full_path,jsondata);
                setRecordingTimeInfo(C3,hTextTimeRecording,hTextDurationRecording);
                timeBase = getTimeBase(hTimebaseButtonGroup,hLabelTimeDisplayed);
                [xAxisTimeStamps, timeStart, timeEnd] = calcTimeStamps(C3,xAxisTimeStamps,timeBase,timeStart,timeEnd);
                [rangeStartIndex, rangeEndIndex] = setRangeOnLoad(C3,xAxisTimeStamps,rangeStartIndex,rangeEndIndex,timeBase,sampleRateFactor,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
                clearStrings(hTxtTotalBeats,hTxtIBImin,hTxtIBImean,hTxtIBImax,hTxtIBIstd,hTxtIBIdiffmin,hTxtIBIdiffmean,hTxtIBIdiffmax,hTxtIBIdiffstd,hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU);
                outputRecordingStats;
                if hParentPanels(3).Visible
                    updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,0);
                end
                if hParentPanels(2).Visible
                    updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
                end
                plotSensorData;
                enableButtons(hPopupRange,hRangeButton,hButtonDetectQRS,hButtonLoadQRS,hButtonExportECGtoMIT,hButtonExportECGtoCSV,hButtonExportECGtoKubios,hButtonECGkitGenReport,hButtonLoadECGkitClass,hButtonRhythmSelClick,hButtonSaveRhytmAnn);
                enableButtons(hButtonEventMarkerAddToggle,hButtonEventMarkerDel,hButtonEventMarkerEdit,hButtonEventMarkerSave,hButtonECGkitMarkerAddToggle,hButtonECGkitMarkerOut,hButtonECGkitMarkerDel,hButtonECGkitMarkerEdit,hButtonECGkitMarkerSave);
            end
        end
    end

    function dataLoaded = loadAndFormatData()
        hTic_loadAndFormatData = tic;
        % load JSON file, if any
        json_fullpath = '';
        jsondata_class_fullpath = '';
        classification_fullpath = '';
        jsondata = struct([]);
        jsondata_class_segment = struct([]);
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
        % Now load BLE or a folder of BIN's
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
                [C3.serialNumber, conf, serial_ADS, C3.eventCounter, C3.leadoff, C3.accel.dataRaw, C3.temp.dataRaw,  C3.resp.dataRaw, C3.ecg.dataRaw, ecg_serials] = c3_read_ble_24bit(full_path);
                C3.accel.samplenum = length(C3.accel.dataRaw);
                C3.temp.samplenum = length(C3.temp.dataRaw);
                C3.resp.samplenum = length(C3.resp.dataRaw);
                C3.ecg.samplenum = length(C3.ecg.dataRaw);
                [~,ble_filename_wo_extension,~] = fileparts([pathName filesep fileName]);
                % if there's jsondata available and there's a 'start' field, then that is prioritised to indicate start of recording
                if ~isempty(jsondata) && isfield(jsondata,'start') && ~isempty(jsondata.start)
                    C3.date_start = datenum(datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','local'));
                % if no jsondata, then try using the filename to indicate start of recording, with the assumption that the filename is a HEX posixtime value
                elseif all(ismember(ble_filename_wo_extension, '1234567890abcdefABCDEF')) && length(ble_filename_wo_extension) < 9
                    C3.date_start = datenum(datetime(hex2dec(ble_filename_wo_extension), 'ConvertFrom', 'posixtime', 'TimeZone', 'local'));
                % if none of the above were an option, then set the start time as follows
                else
                    C3.date_start = datenum(datetime('0001-01-01T00:00:00.000+0000','InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','local'));
                end
                if isempty(jsondata)
                    [jsondata, Cancelled] = createNewJSON(C3,full_path,fileFormat);
                    if ~Cancelled
                        json_fullpath = [pathName filename_wo_extension '.json'];
                    end
                    pause(0.1);
                end
                C3.date_end = addtodate(C3.date_start, C3.ecg.samplenum*1000/C3.ecg.fs, 'millisecond');
                C3.missingSerials = find(C3.serialNumber == 0);
                % initialize event markers for events found in the BLE-file (only 24bit version)
                eventMarkers = initializeEventMarkersFromBLE(C3,eventMarkers,sampleRateFactor);
                dataLoaded = true;
                fprintf('GUI, read BLE 24bit file and initialize event markers: %f seconds\n',toc(hTic_readFile));
            % if selected file format is BLE 16bit
            case 'BLE 16bit'
                hTic_readFile = tic;
                % Initialise components
                C3.initializeForBLE16bit;
                % load and assign data from .BLE file, 16bit version
                [C3.serialNumber, C3.leadoff, C3.accel.dataRaw, C3.temp.dataRaw, C3.resp.dataRaw, C3.ecg.dataRaw] = c3_read_ble(full_path);
                conf = [];
                C3.accel.samplenum = length(C3.accel.dataRaw);
                C3.temp.samplenum = length(C3.temp.dataRaw);
                C3.resp.samplenum = length(C3.resp.dataRaw);
                C3.ecg.samplenum = length(C3.ecg.dataRaw);
                [~,ble_filename_wo_extension,~] = fileparts([pathName filesep fileName]);
                % if there's jsondata available and there's a 'start' field, then that is prioritised to indicate start of recording
                if ~isempty(jsondata) && isfield(jsondata,'start') && ~isempty(jsondata.start)
                    C3.date_start = datenum(datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','local'));
                % if no jsondata, then try using the filename to indicate start of recording, with the assumption that the filename is a HEX posixtime value
                elseif all(ismember(ble_filename_wo_extension, '1234567890abcdefABCDEF')) && length(ble_filename_wo_extension) < 9
                    C3.date_start = datenum(datetime(hex2dec(ble_filename_wo_extension), 'ConvertFrom', 'posixtime', 'TimeZone', 'local'));
                % if none of the above were an option, then set the start time as follows
                else
                    C3.date_start = datenum(datetime('0001-01-01T00:00:00.000+0000','InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','local'));
                end
                if isempty(jsondata)
                    [jsondata, Cancelled] = createNewJSON(C3,full_path,fileFormat);
                    if ~Cancelled
                        json_fullpath = [pathName filename_wo_extension '.json'];
                    end
                    pause(0.1);
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
                    conf = [];
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
        % Warn about sample count mismatch (which often occur in .bin files from python script used to convert BLE's)
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
        % initialise event markers, report markers, ECG annotations, from JSON
        eventMarkers = initializeEventMarkersFromJson(jsondata,eventMarkers);
        reportIOmarkers = initializeReportIOmarkers(jsondata,reportIOmarkers);
        rhytmAnns = loadRhythmAnnotations(C3,full_path,rhytmAnns,hECGrhythmAnnCheckbox);
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
                fprintf('Recording start: %s\n', datestr(C3.date_start,'yyyy-mm-ddTHH:MM:SS.FFF'));
            end
            fprintf('Recording end: %s\n', datestr(C3.date_end,'yyyy-mm-ddTHH:MM:SS.FFF'));
%             fprintf('Recording duration: %s\n', 'Unknown');
        end
        fprintf('Total packets (length serial): %i Missing packets: %i\n', length(C3.serialNumber),length(C3.missingSerials));
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
        leadoff_stats = table(unique(C3.leadoff), histc(C3.leadoff(:),unique(C3.leadoff)), round(double(histc(C3.leadoff(:),unique(C3.leadoff))./double(length(C3.leadoff))*100)), 'VariableNames',{'Lead_off_val' 'Count' 'Percent'});
        display(leadoff_stats);
        fprintf('==========================================================\n');
    end

    function plotSensorData()
        plotECGrhythmAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxesECGrhythmAnn,hECGrhythmAnnCheckbox,gS);
        plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
        plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
%         plotECGkitClass(rangeStartIndex.ECG,rangeEndIndex.ECG,cS,hAxesECGkitClass,hECGkitClassCheckbox,gS,CM_beatClass);
        plotQRSann(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS);
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass)
        plotResp(C3,rangeStartIndex.Resp,rangeEndIndex.Resp,xAxisTimeStamps,timeBase,hAxesResp,hRespCheckbox);
        plotAccel(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hAxesAccel,hAccelXCheckbox,hAccelYCheckbox,hAccelZCheckbox,hAccelMagnitudeCheckbox);
        plotTemp(C3,rangeStartIndex.Temp,rangeEndIndex.Temp,xAxisTimeStamps,timeBase,hAxesTemp,hTemp1Checkbox,hTemp2Checkbox);
    end

    function onClickAxes(hAx, eventid)
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
                    plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
                end
            elseif gS.dataLoaded && gS.eventMarkerMode
                [gS,eventMarkers] = addEventMarker(point1(1,1),xAxisTimeStamps,timeBase,gS,eventMarkers,hEventMarkerDescription,hEventListBox,hButtonEventMarkerSave,editColorGreen,sampleRateFactor);
                plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
            elseif gS.dataLoaded && strcmp(gS.rhythmAnnMode,'click')
                if hAx == hAxesECG
                    [gS,rhytmAnns] = addRhythmAnnClick(point1(1,1),xAxisTimeStamps,timeBase,gS,rhytmAnns,'ECG');
                    plotECGrhythmAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxesECGrhythmAnn,hECGrhythmAnnCheckbox,gS);
                end
            end
        % if click-and-drag
        else
            % Define min and max x and y values
            xMin = min([point1(1,1), point2(1,1)]);
            xMax = max([point1(1,1), point2(1,1)]);
%             yMin = min([point1(1,2), point2(1,2)]);
%             yMax = max([point1(1,2), point2(1,2)]);
            if gS.classAnnDragSel
                if hAx == hAxesECG
                    csIdxSel = getClassAnnIdx(xMin,xMax,xAxisTimeStamps,timeBase,cS,sampleRateFactor);
                    choiceClassAnn = dialogAnnClass();
                    if ~isempty(choiceClassAnn)
                        if choiceClassAnn ~= '-' 
                            cS.anntyp(csIdxSel) = choiceClassAnn;
                        else
                            cS.anntyp(csIdxSel) = [];
                            cS.time(csIdxSel) = [];
                        end
                        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass);
                    end                    
                end
            else
                % find corresponding data indices
                [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,xMin,xMax,sampleRateFactor);
                setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
                enableButtons(hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
                % update range info text
                setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
                plotSensorData;
            end
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

    function navEventLefFcn(varargin)
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

    function navEventRightFcn(varargin)
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

    function classNavLeftFunc(~,~)
        % if no event type has been selected
        if hPopupClass.Value == 1
            warndlg(sprintf('Please select a classification\nfrom the popup menu!'),'Select a classification!');
        else
            % find annotated beats to the left of the displayed range
            cL = getClassLabel(hPopupClass.Value);
            cSindicesBool = cS.time < rangeStartIndex.ECG; 
            cSindexMax = find(cSindicesBool,1,'last');
            cSindex = find(cS.anntyp(1:cSindexMax) == cL,1,'last');
            if isempty(cSindex)
                warndlg(sprintf('No occurences of the selected class,\nto the left of the plotted data.'),'No instances to navigate to!');
            else
                ecgIdx = cS.time(cSindex);
                currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
                rangeStartIndex.Accel = round(ecgIdx*(1/sampleRateFactor.ECG)) - round(currentRange * 0.5);
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

    function classNavRightFunc(~,~)
        % if no event type has been selected
        if hPopupClass.Value == 1
            warndlg(sprintf('Please select a classification\nfrom the popup menu!'),'Select a classification!');
        else
            % find annotated beats to the left of the displayed range
            cL = getClassLabel(hPopupClass.Value);
            cSindicesBool = cS.time > rangeEndIndex.ECG; 
            cSindexMin = find(cSindicesBool,1);
            cSindex = cSindexMin + (find(cS.anntyp(cSindexMin:end) == cL,1)) - 1;
            if isempty(cSindex)
                warndlg(sprintf('No occurences of the selected class,\nto the right of the plotted data.'),'No instances to navigate to!');
            else
                ecgIdx = cS.time(cSindex);
                currentRange = (rangeEndIndex.Accel - rangeStartIndex.Accel);
                rangeStartIndex.Accel = round(ecgIdx*(1/sampleRateFactor.ECG)) - round(currentRange * 0.5);
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
        if strcmp(hButton.String,'Full Range')
            [rangeStartIndex, rangeEndIndex] = resetRange(C3,rangeStartIndex,rangeEndIndex,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton);
            hPopupRange.Value = 1;
        % if not, then assume we want to set a specific range
        else
            recLengthSec = length(C3.ecg.data)/C3.ecg.fs;
            % if item 2 ('1 sec') is selected
            if hPopupRange.Value == 2
                dispSec = 1;
            % if item 3 ('2 sec') is selected
            elseif hPopupRange.Value == 3
                dispSec = 2;
            % if item 4 ('5 sec') is selected
            elseif hPopupRange.Value == 4
                dispSec = 5;
            % if item 5 ('10 sec') is selected
            elseif hPopupRange.Value == 5
                dispSec = 10;
            % if item 6 ('30 sec') is selected
            elseif hPopupRange.Value == 6
                dispSec = 30;
            % if item 7 ('1 min') is selected
            elseif hPopupRange.Value == 7
                dispSec = 60;
            % if item 8 ('2 min') is selected
            elseif hPopupRange.Value == 8
                dispSec = 120;
            % if item 9 ('5 min') is selected
            elseif hPopupRange.Value == 9
                dispSec = 300;
            end
            if hPopupRange.Value ~= 1
                if recLengthSec >= dispSec
                    takeAction = true;
                else
                    takeAction = false;
                    warndlg(sprintf('Selected display range is greater than length of recording!\nPlease select a smaller range.'));
                end
            else
                takeAction = false;
                warndlg('Please select a display range!');
            end
            if takeAction
                [rangeStartIndex, rangeEndIndex] = setRange(dispSec, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
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
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        % if item 2 ('Event Annotation') is selected
        elseif hPopupPanel.Value == 2
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'on';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        % if item 3 ('ECGkit Analysis') is selected
        elseif hPopupPanel.Value == 3
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'on';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        % if item 4 ('ECGkit Results') is selected
        elseif hPopupPanel.Value == 4
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'on';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        % if item 5 ('QRS Detection') is selected
        elseif hPopupPanel.Value == 5
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'on';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        % if item 6 ('Interbeat Intervals') is selected
        elseif hPopupPanel.Value == 6
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'on';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        elseif hPopupPanel.Value == 7
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'on';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'off';
        elseif hPopupPanel.Value == 8
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'on';
            hParentPanels(9).Visible = 'off';
        elseif hPopupPanel.Value == 9
            hParentPanels(1).Visible = 'off';
            hParentPanels(2).Visible = 'off';
            hParentPanels(3).Visible = 'off';
            hParentPanels(4).Visible = 'off';
            hParentPanels(5).Visible = 'off';
            hParentPanels(6).Visible = 'off';
            hParentPanels(7).Visible = 'off';
            hParentPanels(8).Visible = 'off';
            hParentPanels(9).Visible = 'on';
        end
    end

    function fileFormatSelectionFcn(varargin)
        fileFormat = getFileFormat(hFileFormatButtonGroup);
    end

    function [partialPathStr, sourceName] = updateDirectoryInfo(full_path,jsondata)
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
        partialPathStr = '';
        if length(dirNameParts) > 2
            partialPathStr = strcat('... ', filesep, {' '}, dirNameParts(end-2), {' '}, filesep, {' '}, dirNameParts(end-1), {' '}, filesep, {' '});
        elseif length(dirNameParts) < 3
            partialPathStr = strcat('... ', filesep, {' '}, dirNameParts(end-1), {' '}, filesep, {' '});
        elseif length(dirNameParts) < 2
            partialPathStr = '';
        end
        set(hPanelSensorDisplay,'Title',strcat('File: ', partialPathStr, dirNameParts(end), jsonDataAvailable));
    end

%% Functions for updating plots, based on checkbox selections
% (CLEAN UP) The callback from the buttons should be modified so they call
% the plot functions directly - not using this intermediate function.

    function ecgPlotFunc(varargin)
        plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass);
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

    function ecgrhytmAnnshowFcn(~,~)
        if hECGrhythmAnnCheckbox.Value == 1
            gS.rhythmAnnDispECG = true;
            plotECGrhythmAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxesECGrhythmAnn,hECGrhythmAnnCheckbox,gS);
        else
            gS.rhythmAnnDispECG = false;
            cla(hAxesECGrhythmAnn);
        end
    end

    function resprhytmAnnshowFcn(~,~)
        if hRespRhytmAnnCheckbox.Value == 1
            gS.rhythmAnnDispResp = true;
%             plotRespRhytmAnn(rangeStartIndex.Resp,rangeEndIndex.Resp,hAxesRespRhytmAnn,hRespRhytmAnnCheckbox,gS);
        else
            gS.rhythmAnnDispResp = false;
%             cla(hAxesRespRhytmAnn);
        end
    end

    function accelrhytmAnnshowFcn(~,~)
        if hAccelRhytmAnnCheckbox.Value == 1
            gS.rhythmAnnDispAccel = true;
%             plotAccelRhytmAnn(rangeStartIndex.Accel,rangeEndIndex.Accel,hAxesAccelRhytmAnn,hAccelRhytmAnnCheckbox,gS);
        else
            gS.rhythmAnnDispAccel = false;
%             cla(hAxesAccelRhytmAnn);
        end
    end

    function classAnnSelFunc(~,~)
        if hBtnClassAnnSel.Value == 1
            gS.classAnnDragSel = true;
            hBtnClassAnnSel.BackgroundColor = editColorGreen;
            % disable other marker and selection modes
            deselectButtons(hButtonRhythmSelClick);
            rhythmAnnClickFunc([],[]);
            gS = deselectEventMarkerMode(hButtonEventMarkerAddToggle,hEventMarkerDescription,gS,panelColor,editColor);
            [gS,reportIOmarkers] = deselectReportMarkerMode(hButtonECGkitMarkerAddToggle,hECGkitMarkerDescription,hButtonECGkitMarkerOut,hECGkitMarkerOutHrs,hECGkitMarkerOutMin,hECGkitMarkerOutSec,reportIOmarkers,gS,panelColor,editColor);
        else
            gS.classAnnDragSel = false;
            hBtnClassAnnSel.BackgroundColor = panelColor;
        end
    end

    function rhythmAnnClickFunc(~,~)
        if hButtonRhythmSelClick.Value == 1
            if ~hECGrhythmAnnCheckbox.Value
                hECGrhythmAnnCheckbox.Value = 1;
                ecgrhytmAnnshowFcn(hECGrhythmAnnCheckbox,[]);
            end
            gS.rhythmAnnMode = 'click';
            hButtonRhythmSelClick.BackgroundColor = editColorGreen;
            deselectButtons(hBtnClassAnnSel);
            hButtonRhythmSelClick.String = 'Click plot to set In-point';
            % Disable other marker and selection modes
            gS.classAnnDragSel = false;
            hBtnClassAnnSel.BackgroundColor = panelColor;
            gS = deselectEventMarkerMode(hButtonEventMarkerAddToggle,hEventMarkerDescription,gS,panelColor,editColor);
            [gS,reportIOmarkers] = deselectReportMarkerMode(hButtonECGkitMarkerAddToggle,hECGkitMarkerDescription,hButtonECGkitMarkerOut,hECGkitMarkerOutHrs,hECGkitMarkerOutMin,hECGkitMarkerOutSec,reportIOmarkers,gS,panelColor,editColor);
        else
            hButtonRhythmSelClick.BackgroundColor = panelColor;
            hButtonRhythmSelClick.String = 'Rhythm Annotation Mode';
        end
        if hButtonRhythmSelClick.Value == 0
            gS.rhythmAnnMode = 'none';
        end
    end

    function rhytmAnnsaveFunc(~,~)
        % overwrite existing .atr-file or create new
        [file_path,file_name,~] = fileparts(full_path);
        % wrann needs a .hea-file in order to proceed with writing the .atr-file
        if exist(fullfile(file_path,[file_name '.hea']), 'file') ~= 2
            fidHea = fopen(fullfile(file_path,[file_name '.hea']),'w');
            fprintf(fidHea,'%s %d %d %d\r\n',file_name, 0, C3.ecg.fs, 0);
            fclose(fidHea);
        end
        numAnns = length(rhytmAnns.ecg.idx);
        anntype = char(ones(numAnns,1)*43); % anntype is '+' for rhythm-change annotations, aka char(43)
        subtype = zeros(numAnns,1); % defaulting subtype to 0
        chan = zeros(numAnns,1); % defaulting channel to 0
        num = zeros(numAnns,1); % defaulting num to 0
        dirOrg = cd(file_path);
        annSaved = true;
        try
            wrann(file_name,'atr',rhytmAnns.ecg.idx,anntype,subtype,chan,num,rhytmAnns.ecg.ann);
        catch
            warndlg('Could not save annotation file!','Warning!','modal');
            annSaved = false;
        end
        if annSaved
            msgbox('Rhythm annotations saved!','Saved','modal');
        end
        cd(dirOrg);
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
            if ~hEventMarkersCheckbox.Value
                hEventMarkersCheckbox.Value = 1;
                eventsShowMarkersFcn(hEventMarkersCheckbox,[]);
            end
            hButtonEventMarkerAddToggle.String = 'On';
            hButtonEventMarkerAddToggle.BackgroundColor = editColorGreen;
            hEventMarkerDescription.BackgroundColor = editColorGreen;
            hButtonEventMarkerSave.BackgroundColor = editColorGreen;
            % turn off other selection modes
            deselectButtons(hButtonRhythmSelClick,hBtnClassAnnSel);
            gS.classAnnDragSel = false;
            hBtnClassAnnSel.BackgroundColor = panelColor;
            % turn other selection and marker modes off
            if gS.ecgMarkerMode
                ecgkitAddMarkersToggleFunc;
            end
            if gS.classAnnDragSel
                gS = deselectClassAnnDragSelMode(hBtnClassAnnSel,gS,panelColor);
            end
            if strcmp(gS.rhythmAnnMode,'click')
                [gS,rhytmAnns] = deselectRhythmSelClickMode(hButtonRhythmSelClick,rhytmAnns,gS,panelColor);
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
            deleteDone = false;
            % if only one entry selected for deletion
            if deleteCount == 1
                existingStr = eventMarkers(hEventListBox.Value).description;
                if strncmp('C3 button press',existingStr,15)
                    warndlg('Deleting of a "C3 button press" event is not allowed!');
                else
                    eventMarkers(entriesForDeletion(1)) = [];
                    deleteDone = true;
                end
            % if multiple entry selected for deletion
            elseif deleteCount > 1
                % check that no C3 BLE events are among those about to be deleted
                C3BLEevents = false;
                for ii=1:deleteCount
                    existingStr = eventMarkers(entriesForDeletion(ii)).description;
                    if strncmp('C3 button press',existingStr,15)
                        C3BLEevents = true;
                        break;
                    end
                end
                if C3BLEevents
                    warndlg(sprintf('Deleting of a "C3 button press" event is not allowed!\nPlease deselect any such events before deleting.'));
                else
                    for ii=1:deleteCount
                        % deleting from the buttom up
                        eventMarkers(entriesForDeletion(deleteCount+1-ii)) = [];
                    end
                    deleteDone = true;
                end
            end
            % update the index field
            if deleteDone
                for ii=1:length(eventMarkers)
                    eventMarkers(ii).index = ii;
                end
                updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,entriesForDeletion(1)-1);
                plotEventMarkers(rangeStartIndex.Accel,rangeEndIndex.Accel,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS);
                hButtonEventMarkerSave.BackgroundColor = editColorGreen;
            end
        end
    end

    function eventMarkerEditFunc(~,~)
        if ~isempty(eventMarkers) && ~isempty(hEventListBox.Value)
            % Edit only one selection at a time.
            if length(hEventListBox.Value) == 1
                existingStr = eventMarkers(hEventListBox.Value).description;
                if strncmp('C3 button press',existingStr,15)
                    warndlg('Editing of a "C3 button press" event is not allowed!');
                else
                    options.Resize='on';
                    answer = inputdlg('Enter new description:','Edit selected event marker',1,{existingStr},options);
                    if ~isempty(answer)
                        eventMarkers(hEventListBox.Value).description = answer{1,1};
                        updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,hEventListBox.Value);
                        hButtonEventMarkerSave.BackgroundColor = editColorGreen;
                    end
                end
            else
                warndlg('For editing, select only one event marker from the list!');
            end
        end
    end

    function eventMarkerSaveFunc(~,~)
        if ~isempty(json_fullpath)
            % load the JSON again, so any recent saves (e.g. of report markers) are preserved
            jsondata = loadjson(json_fullpath);
            numMarkers = size(eventMarkers,2);
            % find indices for event that are NOT a 'C3 button press',
            % which are from the BLE-file and should not be saved among the
            % JSON events.
            jsonEventIdx = [];
            for ii=1:numMarkers
                if ~strncmp('C3 button press',eventMarkers(ii).description,15)
                    jsonEventIdx(end+1) = ii;
                end
            end
            jsondata.events = cell(1,length(jsonEventIdx));
            for ii=1:length(jsonEventIdx)
                jsondata.events{1,ii}.eventid = eventMarkers(jsonEventIdx(ii)).eventid;
                jsondata.events{1,ii}.serial = eventMarkers(jsonEventIdx(ii)).serial;
                jsondata.events{1,ii}.eventname = eventMarkers(jsonEventIdx(ii)).description;
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
            plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
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
            % turn other selection and marker modes off
            if gS.eventMarkerMode
                eventAddMarkersToggleFunc;
            end
            if gS.classAnnDragSel
                gS = deselectClassAnnDragSelMode(hBtnClassAnnSel,gS,panelColor);
            end
            if strcmp(gS.rhythmAnnMode,'click')
                [gS,rhytmAnns] = deselectRhythmSelClickMode(hButtonRhythmSelClick,rhytmAnns,gS,panelColor);
            end
            if ~isempty(jsondata)
                if ~isfield(jsondata,'reportmarkers')
                    jsondata.reportmarkers = [];
                end
            else
                warndlg(sprintf(['No JSON data loaded! Can not save markers.\n\n',...
                'ECGkit analysis can still be performed within the markers you set\nin the current session.\n\n',...
                'If you want to be able to save markers, make sure\n',...
                'that an appropriate JSON file is present in the same directory\nas the sensor data file, before loading it.\n',...
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
                plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
            end
        else
            warndlg('Only integer numerical input accepted!');
        end        
    end

    function ecgkitListBoxFcn(~,~)
        plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
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
                plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
                hButtonECGkitMarkerSave.BackgroundColor = editColorGreen;
            % if multiple entry selected for deletion
            elseif deleteCount > 1
                for ii=1:deleteCount
                    % remember, the indices of reportIOmarkers are offset by -1, relative to the listbox indices
                    reportIOmarkers(entriesForDeletion(deleteCount+1-ii)-1) = [];
                end
                updateEcgkitListbox(hECGkitListBox,reportIOmarkers,xAxisTimeStamps,timeBase,entriesForDeletion(1)-1);
                plotReportMarkers(rangeStartIndex.ECG,rangeEndIndex.ECG,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS);
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
        genECGkitReport(C3,conf,sampleRateFactor,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,reportIOmarkers,jsondata,hECGkitListBox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,hECGkitMakePDFCheckbox,hECGkitOpenPDFCheckbox,full_path,fileFormat,bin_path);
    end

    function ecgkitShowClassFcn(~,~)
        if hECGkitClassCheckbox.Value == 1
%             plotECGkitClass(rangeStartIndex.ECG,rangeEndIndex.ECG,cS,hAxesECGkitClass,hECGkitClassCheckbox,gS,CM_beatClass);
            plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass);
        else
%             cla(hAxesECGkitClass);
            plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass);
        end
    end

    function loadEcgkitClassFunc(~,~)
        org_path = cd(last_path);
        [fileNameClass,pathNameClass] = uigetfile('*heartbeat_classifier.mat');
        cd(org_path);
        % if a file was selected
        if pathNameClass
            % load classification file
            classification_fullpath = fullfile(pathNameClass,fileNameClass);
            if exist(classification_fullpath, 'file') == 2
                % look for and load a JSON in the same folder as the clssification file
                listjson_segment = dir([pathNameClass filesep '*.JSON']);
                % if only one JSON file exist in this directory, load it
                if size(listjson_segment,1) == 1
                    jsondata_class_fullpath = [pathNameClass filesep listjson_segment(1).name];
                    jsondata_class_segment = loadjson(jsondata_class_fullpath);
                % else,if more than 1 JSON file is present, warn
                elseif size(listjson_segment,1) > 1
                    warndlg(sprintf('More than one JSON file present in folder with classification file!\nSample number offset can not be determined.\n\nHeartbeat classifications can not be displayed in ECG plot.'));
                    disableButtons(hButtonNavLeftClass,hButtonNavRightClass,hPopupClass);
                    jsondata_class_segment = [];
                else
                    warndlg(sprintf('No JSON file present in folder with classification file!\nSample number offset can not be determined.\n\nHeartbeat classifications can not be displayed in ECG plot.'));
                    disableButtons(hButtonNavLeftClass,hButtonNavRightClass,hPopupClass);
                    jsondata_class_segment = [];
                end
                if ~isempty(jsondata_class_segment) && isfield(jsondata_class_segment,'ecgsampleoffset')
                    cS = load(classification_fullpath);
                    classCountInfoUpdate(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact,cS);
                    cS.time = cS.time + jsondata_class_segment.ecgsampleoffset;
                    enableButtons(hButtonNavLeftClass,hButtonNavRightClass,hPopupClass,hBtnClassAnnSel,hButtonSaveECGkitClass);
                    hECGkitClassCheckbox.Value = 1;
%                     plotECGkitClass(rangeStartIndex.ECG,rangeEndIndex.ECG,cS,hAxesECGkitClass,hECGkitClassCheckbox,gS,CM_beatClass);
                    plotECG(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass);
                elseif ~isempty(jsondata_class_segment) && ~isfield(jsondata_class_segment,'ecgsampleoffset')
                    warndlg(sprintf(['JSON file for this analysis segment did not contain an "ecgsampleoffset" field!\n\n'...
                    'Heartbeat classifications can not be displayed in ECG plot.\nPlease perform a new ECGkit analysis.']));
                    disableButtons(hButtonNavLeftClass,hButtonNavRightClass,hPopupClass);
                    cS = [];
                    classCountInfoReset(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact);
                    cla(hAxesECGkitClass);
                else
                    cS = [];
                    classCountInfoReset(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact);
                    cla(hAxesECGkitClass);
                end
            else
                cS = [];
                classCountInfoReset(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact);
                warning(['No classification file at: ' classification_fullpath '\n']);
                classification_fullpath = '';
                return;
            end
        end
    end

    function saveEcgkitClassFunc(~,~)
        %savejson('',jsondata_class_segment,'FileName',jsondata_class_fullpath,'ParseLogical',1);
        % NOTE: THIS NEEDS RETHINKING. The workflow of loading and saving classification data that
        % relates to segments of the original full recording.
        cS.time = cS.time - jsondata_class_segment.ecgsampleoffset;
        save(classification_fullpath,'-struct','cS');
        cS.time = cS.time + jsondata_class_segment.ecgsampleoffset;
    end

    function setClassAnn(source,callbackdata)
        hTxtAnn = callbackdata.Source.Parent.Parent.CurrentObject;
        switch source.Label
            case 'N (Normal beat)'
                hTxtAnn.String = 'N';
                hTxtAnn.BackgroundColor = gS.colors.col{13};
                cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case 'S (Supraventricular)'
                hTxtAnn.String = 'S';
                hTxtAnn.BackgroundColor = gS.colors.col{9};
                cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case 'V (Ventricular premature)'
                hTxtAnn.String = 'V';
                hTxtAnn.BackgroundColor = gS.colors.col{10};
                cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case 'F (Fusion of ventricular and normal)'
                hTxtAnn.String = 'F';
                hTxtAnn.BackgroundColor = gS.colors.col{11};
               cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case 'U (Unclassifiable)'
                hTxtAnn.String = 'U';
                hTxtAnn.BackgroundColor = gS.colors.col{12};
                cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case '| (Isolated QRS-like artifact)'
                hTxtAnn.String = '|';
                hTxtAnn.BackgroundColor = gS.colors.col{6};
                cS.anntyp(hTxtAnn.UserData) = hTxtAnn.String;
            case 'Delete'
                hTxtAnn.String = '';
                hTxtAnn.BackgroundColor = 'none';
                cS.time(hTxtAnn.UserData) = [];
                cS.anntyp(hTxtAnn.UserData) = [];
        end
        classCountInfoUpdate(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact,cS);
    end

    function showQRSannFnc(~,~)
        plotQRSann(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS);
    end

    function showIBIFnc(~,~)
        plotQRSann(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS);
    end

    function detectQRSFcn(~,~)
        if strcmp(get(get(hOptQRSRangeButtonGroup,'selectedobject'),'String'),'Displayed')
            rangeStr = 'displayed';
        else
            rangeStr = 'full';
        end
        qrsAnn = detectQRS(C3,conf,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hPopupECGch,hPopupQRSdet,full_path,rangeStr,'qrsdetect',fileFormat,jsondata,bin_path);
        disableButtons(hStdSearchLeft,hStdSearchRight);
        hStdMin.String = ''; hStdMean.String = ''; hStdMax.String = '';
        if ~isempty(qrsAnn)
            % Offset samples by rangeStartIndex.ECG-1 if a segment was analysed (detectQRS already adds +1 to match Matlab indexing)
            if strcmp(rangeStr,'displayed')
                qrsAnn{1,1} = qrsAnn{1,1} + rangeStartIndex.ECG - 1;
            end
            if hIBIpanelCheckbox.Value == 1
                hPopupPanel.Value = 6;
                functionalityPopup([],[],hParentPanels);
            end
            [ibims, ibiDiffms] = calcIBIstats(C3,qrsAnn,hTxtTotalBeats,hTxtIBImin,hTxtIBImean,hTxtIBImax,hTxtIBIstd,hTxtIBIdiffmin,hTxtIBIdiffmean,hTxtIBIdiffmax,hTxtIBIdiffstd);
            plotQRSann(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS);
            enableButtons(hIBIsearchLeft,hIBIsearchRight,hIBIdiffSearchLeft,hIBIdiffSearchRight,hBtAnalyseSegments);
        end
    end

    function loadQRSFcn(~,~)
        qrsAnn = loadQRS(last_path,bin_path);
        disableButtons(hStdSearchLeft,hStdSearchRight);
        hStdMin.String = ''; hStdMean.String = ''; hStdMax.String = '';
        if ~isempty(qrsAnn)
            if hIBIpanelCheckbox.Value == 1
                hPopupPanel.Value = 6;
                functionalityPopup([],[],hParentPanels);
            end
            [ibims, ibiDiffms] = calcIBIstats(C3,qrsAnn,hTxtTotalBeats,hTxtIBImin,hTxtIBImean,hTxtIBImax,hTxtIBIstd,hTxtIBIdiffmin,hTxtIBIdiffmean,hTxtIBIdiffmax,hTxtIBIdiffstd);
            plotQRSann(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS);
            enableButtons(hIBIsearchLeft,hIBIsearchRight,hIBIdiffSearchLeft,hIBIdiffSearchRight,hBtAnalyseSegments);
        end
    end

    function IBISearchFcn(hCtrl,~)
        ecgIdx = [];
        % If search option is 'IBI <'
        if get(hIBIsearchBtGrp,'selectedobject') == hIBIsearchBt1
            searchVal = getPosIntVal(hIBIlessThan);
            % If a valid search value was entered
            if searchVal
                % If '<<' button was clicked
                if hCtrl == hIBIsearchLeft
                    qrsAnnBool = qrsAnn{1,1} < rangeStartIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1,'last')-1;
                    if qrsAnnIdx
                        IBIidx = find(ibims(1:qrsAnnIdx) < searchVal,1,'last');
                    else
                        IBIidx = [];
                    end
                    if isempty(IBIidx)
                        warndlg(sprintf('No occurences to the left of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIidx) + round((qrsAnn{1,1}(IBIidx+1) - qrsAnn{1,1}(IBIidx))/2);
                    end
                % Else, '>>' button was clicked
                else
                    qrsAnnBool = qrsAnn{1,1} > rangeEndIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1)-1;
                    if qrsAnnIdx
                        IBIidx = find(ibims(qrsAnnIdx:end) < searchVal,1) + qrsAnnIdx - 1;
                    else
                        IBIidx = [];
                    end
                    if isempty(IBIidx)
                        warndlg(sprintf('No occurences to the right of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIidx) + round((qrsAnn{1,1}(IBIidx+1) - qrsAnn{1,1}(IBIidx))/2);
                    end
                end
            end
        % Else, search option is 'IBI >'
        else
            searchVal = getIntVal(hIBIgreaterThan);
            % If a valid search value was entered
            if searchVal
                % If '<<' button was clicked
                if hCtrl == hIBIsearchLeft
                    qrsAnnBool = qrsAnn{1,1} < rangeStartIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1,'last')-1;
                    if qrsAnnIdx
                        IBIidx = find(ibims(1:qrsAnnIdx) > searchVal,1,'last');
                    else
                        IBIidx = [];
                    end
                    if isempty(IBIidx)
                        warndlg(sprintf('No occurences to the left of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIidx) + round((qrsAnn{1,1}(IBIidx+1) - qrsAnn{1,1}(IBIidx))/2);
                    end
                % Else, '>>' button was clicked
                else
                    qrsAnnBool = qrsAnn{1,1} > rangeEndIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1)-1;
                    if qrsAnnIdx
                        IBIidx = find(ibims(qrsAnnIdx:end) > searchVal,1) + qrsAnnIdx - 1;
                    else
                        IBIidx = [];
                    end
                    if isempty(IBIidx)
                        warndlg(sprintf('No occurences to the right of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIidx) + round((qrsAnn{1,1}(IBIidx+1) - qrsAnn{1,1}(IBIidx))/2);
                    end
                end
            end
        end
        if ~isempty(ecgIdx)
            currentRange = rangeEndIndex.Accel - rangeStartIndex.Accel;
            rangeStartIndex.Accel = round(ecgIdx/sampleRateFactor.ECG) - round(currentRange * 0.5);
            rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
            currentRangeSec = round(currentRange/C3.accel.fs);
            [rangeStartIndex, rangeEndIndex] = setRange(currentRangeSec, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % update range info text, and plot range
            setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            plotSensorData;
        end
    end

    function IBIdiffSearchFcn(hCtrl,~)
        ecgIdx = [];
        % If search option is 'IBI diff <'
        if get(hIBIdiffSearchBtGrp,'selectedobject') == hIBIdiffSearchBt1
            searchVal = getIntVal(hIBIdiffLessThan);
            % If a valid search value was entered
            if searchVal
                % If '<<' button was clicked
                if hCtrl == hIBIdiffSearchLeft
                    qrsAnnBool = qrsAnn{1,1} < rangeStartIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1,'last')-2;
                    qrsAnnIdx(qrsAnnIdx < 1) = [];
                    if qrsAnnIdx
                        IBIDiffidx = find(ibiDiffms(1:qrsAnnIdx) < searchVal,1,'last');
                    else
                        IBIDiffidx = [];
                    end
                    if isempty(IBIDiffidx)
                        warndlg(sprintf('No occurences to the left of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIDiffidx) + round((qrsAnn{1,1}(IBIDiffidx+2) - qrsAnn{1,1}(IBIDiffidx))/2);
                    end
                % Else, '>>' button was clicked
                else
                    qrsAnnBool = qrsAnn{1,1} > rangeEndIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1)-2;
                    qrsAnnIdx(qrsAnnIdx < 1) = [];
                    if qrsAnnIdx
                        IBIDiffidx = find(ibiDiffms(qrsAnnIdx:end) < searchVal,1) + qrsAnnIdx - 1;
                    else
                        IBIDiffidx = [];
                    end
                    if isempty(IBIDiffidx)
                        warndlg(sprintf('No occurences to the right of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIDiffidx) + round((qrsAnn{1,1}(IBIDiffidx+2) - qrsAnn{1,1}(IBIDiffidx))/2);
                    end
                end
            end
        % Else, search option is 'IBI diff >'
        else
            searchVal = getIntVal(hIBIdiffGreaterThan);
            % If a valid search value was entered
            if searchVal
                % If '<<' button was clicked
                if hCtrl == hIBIdiffSearchLeft
                    qrsAnnBool = qrsAnn{1,1} < rangeStartIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1,'last')-2;
                    qrsAnnIdx(qrsAnnIdx < 1) = [];
                    if qrsAnnIdx
                        IBIDiffidx = find(ibiDiffms(1:qrsAnnIdx) > searchVal,1,'last');
                    else
                        IBIDiffidx = [];
                    end
                    if isempty(IBIDiffidx)
                        warndlg(sprintf('No occurences to the left of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIDiffidx) + round((qrsAnn{1,1}(IBIDiffidx+2) - qrsAnn{1,1}(IBIDiffidx))/2);
                    end
                % Else, '>>' button was clicked
                else
                    qrsAnnBool = qrsAnn{1,1} > rangeEndIndex.ECG; 
                    qrsAnnIdx = find(qrsAnnBool,1)-2;
                    qrsAnnIdx(qrsAnnIdx < 1) = [];
                    if qrsAnnIdx
                        IBIDiffidx = find(ibiDiffms(qrsAnnIdx:end) > searchVal,1) + qrsAnnIdx - 1;
                    else
                        IBIDiffidx = [];
                    end
                    if isempty(IBIDiffidx)
                        warndlg(sprintf('No occurences to the right of the plotted data.'),'No instances to navigate to!');
                    else
                        ecgIdx = qrsAnn{1,1}(IBIDiffidx) + round((qrsAnn{1,1}(IBIDiffidx+2) - qrsAnn{1,1}(IBIDiffidx))/2);
                    end
                end
            end
        end
        if ~isempty(ecgIdx)
            currentRange = rangeEndIndex.Accel - rangeStartIndex.Accel;
            rangeStartIndex.Accel = round(ecgIdx/sampleRateFactor.ECG) - round(currentRange * 0.5);
            rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
            currentRangeSec = round(currentRange/C3.accel.fs);
            [rangeStartIndex, rangeEndIndex] = setRange(currentRangeSec, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % update range info text, and plot range
            setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            plotSensorData;
        end
    end

    function analyseSegmentsFcn(~,~)
        segmentSec = getGT0IntVal(hSegmentSec);
        if segmentSec
            segmentSamples = segmentSec * C3.ecg.fs;
            qrsAnnSamples = qrsAnn{1,1}(end)-qrsAnn{1,1}(1);
            if segmentSamples <= floor(0.5*qrsAnnSamples) && segmentSec >= 2
                numSegs = round(qrsAnnSamples/segmentSamples)+1;
                qrsAnnIndices = zeros(numSegs,1);
                qrsCount = length(qrsAnn{1,1});
                jj = 1;
                qrsAnnIndices(1) = 1;
                while 1
                    jj = jj + 1;
                    nextQrsAnnIdx = find(qrsAnn{1,1} > (qrsAnn{1,1}(qrsAnnIndices(jj-1))+segmentSamples-1), 1);
                    if ~isempty(nextQrsAnnIdx)
                        if nextQrsAnnIdx == qrsCount
                            break;
                        else
                            qrsAnnIndices(jj) = nextQrsAnnIdx - 1;
                        end
                    else
                        break;
                    end
                end
                % Remove any leftover indices
                qrsAnnIndices(qrsAnnIndices == 0) = [];
                ibiSegmentSampleNums = qrsAnn{1,1}(qrsAnnIndices);
                stdIBISegments = zeros(length(qrsAnnIndices)-1,1);
                for ii=1:length(qrsAnnIndices)-1
                    stdIBISegments(ii) = nanstd(ibims(qrsAnnIndices(ii):qrsAnnIndices(ii+1)));
                end
                hStdMin.String = num2str(round(nanmin(stdIBISegments)));
                hStdMean.String = num2str(round(nanmean(stdIBISegments)));
                hStdMax.String = num2str(round(nanmax(stdIBISegments)));
                enableButtons(hStdSearchLeft,hStdSearchRight);
            elseif segmentSamples > floor(0.5*qrsAnnSamples)
                warndlg('Segment size is greater than half the length of the QRS detection! Please enter a smaller segment size.');
            else
                warndlg('Segment size is below 2 seconds! Please enter a larger segment size.');
            end
        end        
    end

    function stdSearchFcn(hCtrl,~)
        ecgIdx = [];
        searchVal = getGT0IntVal(hStdGreaterThan);
        % If a valid search value was entered
        if searchVal
            % Claculate ECG indices from which to search towards the beginning or end of the data
            idxSpanDispECG = rangeEndIndex.ECG - rangeStartIndex.ECG;
            inclFractionOfSpan = 0.125;
            % If '<<' button was clicked
            if hCtrl == hStdSearchLeft
                ibiSegBool = ibiSegmentSampleNums < rangeStartIndex.ECG + (idxSpanDispECG*inclFractionOfSpan); 
                ibiSegIdx = find(ibiSegBool,1,'last')-1;
                ibiSegIdx(ibiSegIdx < 1) = [];
                if ibiSegIdx
                    segIdx = find(stdIBISegments(1:ibiSegIdx) > searchVal,1,'last');
                else
                    segIdx = [];
                end
                if isempty(segIdx)
                    warndlg(sprintf('No occurences to the left of the plotted data.'),'No instances to navigate to!');
                else
                    ecgIdx = ibiSegmentSampleNums(segIdx) + round((ibiSegmentSampleNums(segIdx+1) - ibiSegmentSampleNums(segIdx))/2);
                end
            % Else, '>>' button was clicked
            else
                ibiSegBool = ibiSegmentSampleNums > rangeEndIndex.ECG - (idxSpanDispECG*inclFractionOfSpan); 
                ibiSegIdx = find(ibiSegBool,1);
                ibiSegIdx(ibiSegIdx == length(ibiSegBool)) = [];
                if ibiSegIdx
                    segIdx = find(stdIBISegments(ibiSegIdx:end) > searchVal,1) + ibiSegIdx - 1;
                else
                    segIdx = [];
                end
                if isempty(segIdx)
                    warndlg(sprintf('No occurences to the right of the plotted data.'),'No instances to navigate to!');
                else
                    ecgIdx = ibiSegmentSampleNums(segIdx) + round((ibiSegmentSampleNums(segIdx+1) - ibiSegmentSampleNums(segIdx))/2);
                end
            end
        end
%         fprintf('length(ibiSegBool): %d\nibiSegIdx: %d\nsegIdx: %d\necgIdx: %d\n\n',length(ibiSegBool),ibiSegIdx,segIdx,ecgIdx);
        if ~isempty(ecgIdx)
            currentRange = rangeEndIndex.Accel - rangeStartIndex.Accel;
            rangeStartIndex.Accel = round(ecgIdx/sampleRateFactor.ECG) - round(currentRange * 0.5);
            rangeEndIndex.Accel = rangeStartIndex.Accel + currentRange;
            currentRangeSec = round(currentRange/C3.accel.fs);
            [rangeStartIndex, rangeEndIndex] = setRange(currentRangeSec, rangeStartIndex, rangeEndIndex, C3, sampleRateFactor);
            % update range info text, and plot range
            setRangeSlider(C3,rangeStartIndex,rangeEndIndex,hRangeSlider);
            setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed);
            plotSensorData;
        end
    end

    function exportECGtoMITfilesFunc(~,~)
        if strcmp(get(get(hExportRangeButtonGroup,'selectedobject'),'String'),'Displayed')
            rangeStr = 'displayed';
        else
            rangeStr = 'full';
        end
        exportECGtoMITfiles(C3,conf,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path,rangeStr,'export',fileFormat,jsondata,bin_path);
    end

    function exportECGtoCSVfileFunc(~,~)
        exportECGtoCSVfile(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hExportRangeButtonGroup,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path);
    end

    function exportECGtoKubiosFunc(~,~)
        exportECGtoKubios(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hExportRangeButtonGroup,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path,jsondata,fileFormat);
    end

%% Functions for creating separate, floating plot windows
    
    function ecgBrowserFunc(varargin)
        if gS.dataLoaded
            winXpos = 0;
            winYpos = 0;
            winWidth = screenSize(3);
            winHeight = screenSize(4);
            % Figure window
            hECGbrowser = figure('Numbertitle','off','Name',...
                ['ECG   File: ' char(sourceName)],...
                'Position', [winXpos winYpos winWidth winHeight],...
                'MenuBar', 'none','Toolbar','none',...
                'WindowStyle','normal',... %modal
                'PaperPositionMode','auto',...
                'Visible','off');
            % Panel for ECG plots
            hPnlECGbrAxes = uipanel('Parent',hECGbrowser,...
                'BorderType','line',...
                'HighlightColor',panelBorderColor,...
                'Position',[0 0.05 1 0.925],...
                'BackgroundColor',gS.colors.col{14});
            % Axes for plots
            ecgAxMargin = 1/(gS.ecgBrowserNumRows+4)*0.05;
            ecgAxHeight = (1/gS.ecgBrowserNumRows) - ecgAxMargin;
            hAxECGbrowser = gobjects(gS.ecgBrowserNumRows,1);
            for ia=1:gS.ecgBrowserNumRows
                hAxECGbrowser(ia) = axes('Parent',hPnlECGbrAxes,'Position',[0.02,(1-((ecgAxHeight*ia)+(ecgAxMargin*0.5)+(ecgAxMargin*(ia-1)))),0.96,ecgAxHeight],'Visible','off'); % ,'Visible','off'
                hold(hAxECGbrowser(ia),'on');
                xlim(hAxECGbrowser(ia),'manual');
                ylim(hAxECGbrowser(ia),'manual');
                set(hAxECGbrowser(ia),'Xticklabel',[]);
                hAxECGbrowser(ia).XColor = panelColor;
    %             set(hAxECGbrowser(ia),'Yticklabel',[]);
                hAxECGbrowser(ia).TickLength = [0.0025 0];
                hAxECGbrowser(ia).YLim = [gS.ecgBrowserYminmV*gS.unitsPrmV gS.ecgBrowserYmaxmV*gS.unitsPrmV];
                hAxECGbrowser(ia).FontSize = 8;
            end
            % Axes for annotations, transparent background, layered on top of ECG plot axes.
            hAxAnnECGbrowser = gobjects(gS.ecgBrowserNumRows,1);
            for ia=1:gS.ecgBrowserNumRows
                hAxAnnECGbrowser(ia) = axes('Parent',hPnlECGbrAxes,'Position',[0.02,(1-((ecgAxHeight*ia)+(ecgAxMargin*0.5)+(ecgAxMargin*(ia-1)))),0.96,ecgAxHeight],'Color','none');
                hold(hAxAnnECGbrowser(ia),'on');
                xlim(hAxAnnECGbrowser(ia),'manual');
                ylim(hAxAnnECGbrowser(ia),'manual');
                set(hAxAnnECGbrowser(ia),'Xticklabel',[]);
                set(hAxAnnECGbrowser(ia),'Yticklabel',[]);
                hAxAnnECGbrowser(ia).TickLength = [0 0];
                hAxAnnECGbrowser(ia).XColor = 'none';
                hAxAnnECGbrowser(ia).YColor = 'none';
                hAxAnnECGbrowser(ia).YLim = [0 1];
                hAxAnnECGbrowser(ia).FontSize = 8;
            end

            % Panel for controls
            hPnlECGbrCtrl = uipanel('Parent',hECGbrowser,...
                'BorderType','line',...
                'HighlightColor',panelColor,...
                'Position',[0 0 1 0.05],...
                'BackgroundColor',panelColor);
            % Text-edit for min Y-limit of ECG browser axes
            uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.02,0.55,0.035,0.36],...
                'String','Y-axis limit:',...
                'HorizontalAlignment','left',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            hEditYminECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','edit',...
                'Enable','on',...
                'Units','normalized',...
                'Position',[0.055,0.55,0.025,0.45],...
                'String',num2str(gS.ecgBrowserYminmV),...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',editColor);
            uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.0805,0.55,0.0095,0.36],...
                'String','to',...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            % Text-edit for max Y-limit of ECG browser axes
            hEditYmaxECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','edit',...
                'Enable','on',...
                'Units','normalized',...
                'Position',[0.09,0.55,0.025,0.45],...
                'String',num2str(gS.ecgBrowserYmaxmV),...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',editColor);
            uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.116,0.55,0.012,0.36],...
                'String','mV',...
                'HorizontalAlignment','left',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            % Button for setting panel color
            uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','pushbutton',...
                'Units','normalized',...
                'Position',[0.15,0.55,0.05,0.45],...
                'String','Background',...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',gS.colors.col{14},...
                'Callback',{@ecgBrBgColFcn,hPnlECGbrAxes});
            % Button for saving image of ECG Browser
            hSaveImgECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','pushbutton',...
                'Units','normalized',...
                'Position',[0.225,0.55,0.05,0.45],...
                'String','Save Image',...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            % Button for saving image of ECG Browser
            hSaveAnnECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','pushbutton',...
                'Units','normalized',...
                'Position',[0.3,0.55,0.06,0.45],...
                'String','Save Annotations',...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            % Checkmark for displaying rhythm annotations
            hDispRhytAnnECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','checkbox',...
                'Units','normalized',...
                'Position',[0.385,0.55,0.09,0.45],...
                'String','Display Rhythm Annotations',...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',panelColor,...
                'Value',1);
            % Popup menu, for selecting number of rows of ECG plot
            hPopRowsECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style', 'popup',...
                'Units','normalized',...
                'Position',[0.745,0.6,0.04,0.4],...
                'String', {'4 rows','5 rows','6 rows','7 rows','8 rows','9 rows','10 rows'},...
                'FontSize',8);
            hPopRowsECGbr.Value = gS.ecgBrowserNumRows - 3;
            % Edit for setting number of seconds displayed per row in ECG browser
            hEditSecRowECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','edit',...
                'Units','normalized',...
                'Position',[0.794,0.55,0.025,0.45],...
                'String',sprintf('%.1f',(((rangeEndIndex.ECG-rangeStartIndex.ECG+1)/C3.ecg.fs)/gS.ecgBrowserNumRows)),...
                'HorizontalAlignment','center',...
                'FontSize',8,...
                'BackgroundColor',editColor);
            uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.82,0.55,0.05,0.36],...
                'String','Seconds/row',...
                'HorizontalAlignment','left',...
                'FontSize',8,...
                'BackgroundColor',panelColor);
            % Radio buttons group, ECG channels
            hEcgBrBtnGrp = uibuttongroup('Parent',hPnlECGbrCtrl,...
                'Units','normalized',...
                'Position',[0.87,0.55,0.12,0.45],...
                'BorderType','none',...
                'BackgroundColor',panelColor);
            % Radio button, ECG1
            hEcgBrBtn1 = uicontrol(hEcgBrBtnGrp,...
                'Style','radiobutton',...
                'Enable','on',...
                'String','ECG1',...
                'Units','normalized',...
                'Position',[0.02,0.05,0.4,1],...
                'BackgroundColor',panelColor,...
                'ForegroundColor',[1 0 0],...
                'HandleVisibility','off');
            % Radio button, ECG2
            hEcgBrBtn2 = uicontrol(hEcgBrBtnGrp,...
                'Style','radiobutton',...
                'Enable','on',...
                'String','ECG2',...
                'Units','normalized',...
                'Position',[0.35,0.05,0.4,1],...
                'BackgroundColor',panelColor,...
                'ForegroundColor',[0 0.6 0],...
                'HandleVisibility','off');
            % Radio button, ECG3
            hEcgBrBtn3 = uicontrol(hEcgBrBtnGrp,...
                'Style','radiobutton',...
                'Enable','on',...
                'String','ECG3',...
                'Units','normalized',...
                'Position',[0.68,0.05,0.4,1],...
                'BackgroundColor',panelColor,...
                'ForegroundColor',[0 0 1],...
                'HandleVisibility','off');
            % preselecting ECG1 radio button
            set(hEcgBrBtnGrp,'selectedobject',hEcgBrBtn1);
            % Slider for displayed segment of ECG
            hSliderECGbr = uicontrol('Parent',hPnlECGbrCtrl,...
                'Style','slider',...
                'Enable','on',...
                'Units','normalized',...
                'Position',[0.02,0.02,0.96,0.48],...
                'Min',1,'Max',1000,...
                'Value',500,...
                'SliderStep',[0.1 1],...
                'BackgroundColor',panelColor);
            % Panel for title and time info
            hPnlECGbrTitle = uipanel('Parent',hECGbrowser,...
                'BorderType','line',...
                'HighlightColor',panelColor,...
                'Position',[0 0.975 1 0.025],...
                'BackgroundColor',panelColor);
            % text for file info
            uicontrol('Parent',hPnlECGbrTitle,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.02 0 0.65 0.89],...
                'HorizontalAlignment','left',...
                'String',sprintf('File: %s%s', strjoin(partialPathStr), strjoin(sourceName)),...
                'FontSize',11,...
                'FontWeight','bold',...
                'ForegroundColor',dimmedTextColor,...
                'BackgroundColor',panelColor);
            hTxtECGTime = uicontrol('Parent',hPnlECGbrTitle,...
                'Style','text',...
                'Units','normalized',...
                'Position',[0.75 0 0.23 0.89],...
                'HorizontalAlignment','right',...
                'String','Time displayed',...
                'FontSize',11,...
                'FontWeight','bold',...
                'ForegroundColor',dimmedTextColor,...
                'BackgroundColor',panelColor);
            % Show figure window (ECG browser)
            hECGbrowser.Visible = 'on';
            % Add callback functions for ECG browser window and uicontrols
            % that need to be aware of uicontrols created after their own point of creation.
            hECGbrowser.KeyPressFcn = {@keyFcnECGbrowser,hSliderECGbr,hEcgBrBtnGrp,hEcgBrBtn1,hEcgBrBtn2,hEcgBrBtn3,hTxtECGTime,hDispRhytAnnECGbr};
            hECGbrowser.CloseRequestFcn = @ecgBrCloseReqFcn;
            hPopRowsECGbr.Callback = {@ecgBrRowsFcn,hPnlECGbrAxes,hEditSecRowECGbr,hSliderECGbr,hTxtECGTime,hDispRhytAnnECGbr};
            hEcgBrBtnGrp.SelectionChangedFcn = {@ecgChSelFcn,hTxtECGTime};
            hEditYminECGbr.Callback = {@ecgBrYlimFcn,'min',hEditYmaxECGbr};
            hEditYmaxECGbr.Callback = {@ecgBrYlimFcn,'max',hEditYminECGbr};
            hEditSecRowECGbr.Callback = {@ecgBrSecRowFcn,hSliderECGbr,hTxtECGTime};
            hSliderECGbr.Callback = {@ecgBrSliderFcn,hTxtECGTime,hDispRhytAnnECGbr};
            hSaveImgECGbr.Callback = {@ecgBrSaveImgFcn,hECGbrowser,hEcgBrBtnGrp};
            hSaveAnnECGbr.Callback = @rhytmAnnsaveFunc;
            hDispRhytAnnECGbr.Callback = {@ecgBrDispRhytAnnFcn,hAxAnnECGbrowser};
            for ia=1:length(hAxAnnECGbrowser)
                hAxAnnECGbrowser(ia).ButtonDownFcn = {@onClickAxECGbrowser,hAxAnnECGbrowser,hAxECGbrowser,hDispRhytAnnECGbr};
            end
            ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr);
            gS.ecgBrowserCh = 1;
            % Plot
            plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            if hDispRhytAnnECGbr.Value == 1
                plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
            end
        else
            warndlg('No ECG data to display! Please load data.');
        end
    end

    function ecgBrSaveImgFcn(hObj,~,hECGbrowser,hEcgBrBtnGrp)
        hBtn = get(hEcgBrBtnGrp,'selectedobject');
        ecgBrChStr = get(hBtn,'String');
        set(hObj, 'Enable', 'off');
        drawnow;
        set(hObj, 'Enable', 'on');
        ecgBrSaveImg(hECGbrowser,ecgBrChStr,xAxisTimeStamps,timeBase,rangeStartIndex.ECG,rangeEndIndex.ECG,full_path);
    end

    function ecgBrSliderFcn(hSliderECGbr,~,hTxtECGTime,hDispRhytAnnECGbr)
        currentRange = (rangeEndIndex.ECG - rangeStartIndex.ECG + 1);
        rangeStartIndex.ECG = round(hSliderECGbr.Value - currentRange*0.5);
        rangeEndIndex.ECG = rangeStartIndex.ECG + currentRange - 1;
        [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.ECG, rangeEndIndex.ECG, C3.ecg.samplenum);
        rangeStartIndex.ECG = startIdx;
        rangeEndIndex.ECG = endIdx;
        % hack to bring focus back to figure window
        set(hSliderECGbr, 'Enable', 'off');
        drawnow;
        set(hSliderECGbr, 'Enable', 'on');
        plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
        if hDispRhytAnnECGbr.Value
            plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS)
        end
    end

    function ecgBrRowsFcn(hObj,~,hPnlECGbrAxes,hEditSecRowECGbr,hSliderECGbr,hTxtECGTime,hDispRhytAnnECGbr)
        % Create new set of axes for plots
        oldNumRows = gS.ecgBrowserNumRows;
        gS.ecgBrowserNumRows = hObj.Value + 3;
        ecgAxMargin = 1/(gS.ecgBrowserNumRows+4)*0.05;
        ecgAxHeight = (1/gS.ecgBrowserNumRows) - ecgAxMargin;
        yLimMin = gS.ecgBrowserYminmV*gS.unitsPrmV;
        yLimMax = gS.ecgBrowserYmaxmV*gS.unitsPrmV;
        delete([hAxECGbrowser hAxAnnECGbrowser]);
%         clear hAxECGbrowser; clear hAxAnnECGbrowser;
        % Create new axes for ECG plots
        hAxECGbrowser = gobjects(gS.ecgBrowserNumRows,1);
        for ia=1:gS.ecgBrowserNumRows
            hAxECGbrowser(ia) = axes('Parent',hPnlECGbrAxes,'Position',[0.02,(1-((ecgAxHeight*ia)+(ecgAxMargin*0.5)+(ecgAxMargin*(ia-1)))),0.96,ecgAxHeight],'Visible','off'); % ,'Visible','off'
            hold(hAxECGbrowser(ia),'on');
            xlim(hAxECGbrowser(ia),'manual');
            hAxECGbrowser(ia).YLim = [yLimMin yLimMax];
            set(hAxECGbrowser(ia),'Xticklabel',[]);
%             set(hAxECGbrowser(ia),'Yticklabel',[]);
            hAxECGbrowser(ia).TickLength = [0.0025 0];
            hAxECGbrowser(ia).FontSize = 8;
        end
        % Create new axes for Annotation plots
        hAxAnnECGbrowser = gobjects(gS.ecgBrowserNumRows,1);
        for ia=1:gS.ecgBrowserNumRows
            hAxAnnECGbrowser(ia) = axes('Parent',hPnlECGbrAxes,'Position',[0.02,(1-((ecgAxHeight*ia)+(ecgAxMargin*0.5)+(ecgAxMargin*(ia-1)))),0.96,ecgAxHeight],'Color','none');
            hold(hAxAnnECGbrowser(ia),'on');
            xlim(hAxAnnECGbrowser(ia),'manual');
            ylim(hAxAnnECGbrowser(ia),'manual');
            set(hAxAnnECGbrowser(ia),'Xticklabel',[]);
            set(hAxAnnECGbrowser(ia),'Yticklabel',[]);
            hAxAnnECGbrowser(ia).TickLength = [0 0];
            hAxAnnECGbrowser(ia).XColor = 'none';
            hAxAnnECGbrowser(ia).YColor = 'none';
            hAxAnnECGbrowser(ia).YLim = [0 1];
            hAxAnnECGbrowser(ia).FontSize = 8;
        end
        % Assigning ButtonDownFcn to annotation axes
        for ia=1:length(hAxAnnECGbrowser)
            hAxAnnECGbrowser(ia).ButtonDownFcn = {@onClickAxECGbrowser,hAxAnnECGbrowser,hAxECGbrowser,hDispRhytAnnECGbr};
        end
        cor_uiReleaseFocus(hObj);
        rangeEndIndex.ECG = rangeStartIndex.ECG + round(((rangeEndIndex.ECG - rangeStartIndex.ECG)/oldNumRows)*gS.ecgBrowserNumRows);
        [rangeStartIndex, rangeEndIndex] = setRangeEcgBr(rangeStartIndex, rangeEndIndex, C3);
        % setting the seconds-per-row value (string), in case range had to be restricted
        hEditSecRowECGbr.String = sprintf('%.1f',((rangeEndIndex.ECG-rangeStartIndex.ECG+1)/gS.ecgBrowserNumRows)/C3.ecg.fs);
        ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr);
        plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
        plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
    end

    function ecgChSelFcn(hObj,~,hTxtECGTime)
        hSubObj = get(hObj,'selectedobject');
        ecgBrChStr = get(hSubObj,'String');
        cor_uiReleaseFocus(hSubObj);
        switch ecgBrChStr
            case 'ECG1'
                gS.ecgBrowserCh = 1;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            case 'ECG2'
                gS.ecgBrowserCh = 2;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            case 'ECG3'
                gS.ecgBrowserCh = 3;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
        end
    end

    function ecgBrYlimFcn(hObj,~,yLimStr,hObj2)
        if strcmp(yLimStr,'min')
            yMinmV = getFloatVal(hObj);
            yMaxmV = getFloatVal(hObj2);
        else
            yMaxmV = getFloatVal(hObj);
            yMinmV = getFloatVal(hObj2);
        end
        cor_uiReleaseFocus(hObj);
        if ~isempty(yMinmV) && ~isempty(yMaxmV) && yMinmV < yMaxmV
            gS.ecgBrowserYminmV = yMinmV;
            gS.ecgBrowserYmaxmV = yMaxmV;
            yMin = gS.ecgBrowserYminmV*gS.unitsPrmV;
            yMax = gS.ecgBrowserYmaxmV*gS.unitsPrmV;
            for ii=1:length(hAxECGbrowser)
                hAxECGbrowser(ii).YLim = [yMin yMax];
            end
        else
            if ~isempty(yMinmV) && ~isempty(yMaxmV) && yMinmV > yMaxmV
                warndlg('The right side limit should be greater than the left side limit!');
            end
        end
    end

    function ecgBrBgColFcn(hObj,~,hPnlECGbrAxes)
        hPnlECGbrAxes.BackgroundColor = uisetcolor(gS.colors.col{14});
        cor_uiReleaseFocus(hObj);
    end

    function ecgBrSecRowFcn(hObj,~,hSliderECGbr,hTxtECGTime)
        secPrRow = getFloatVal(hObj);
        cor_uiReleaseFocus(hObj);
        if ~isempty(secPrRow) && secPrRow >= 1
            rangeEndIndex.ECG = round(rangeStartIndex.ECG + (secPrRow*gS.ecgBrowserNumRows)*C3.ecg.fs) - 1;
            [rangeStartIndex, rangeEndIndex] = setRangeEcgBr(rangeStartIndex, rangeEndIndex, C3);
            % setting the seconds-per-row value (string), in case range had to be restricted
            hObj.String = sprintf('%.1f',((rangeEndIndex.ECG-rangeStartIndex.ECG+1)/gS.ecgBrowserNumRows)/C3.ecg.fs);
            ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr);
            plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
        end
        if ~isempty(secPrRow) && secPrRow < 1
            warndlg('Please enter a value greater than 1');
        end
    end

    function ecgWinFunc(varargin)
        %--- creates a new, floating window for the ECG plot ---%
        % get screen size
        screenSize = get(0,'screensize');
        winXpos = 10; %round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.1);
        winWidth = round(screenSize(3)*0.975);
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
        winXpos = 10; %round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.2);
        winWidth = round(screenSize(3)*0.975);
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
        winXpos = 10;%round(screenSize(3)*0.05)
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.3);
        winWidth = round(screenSize(3)*0.975);%*0.5
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
        winXpos = 10; %round(screenSize(3)*0.05);
        winYpos = round(screenSize(4)*0.5) - round(screenSize(4)*0.4);
        winWidth = round(screenSize(3)*0.975);
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
        fftEcgNewWindow(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hImageRes,hOptPlotRangeButtonGroup,gS,full_path);
    end

    function accMagFunc(~,~)
        accHistNewWindow(C3,rangeStartIndex.Accel,rangeEndIndex.Accel,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hImageRes,hSaveTextCheckbox,hOptPlotRangeButtonGroup,gS,hAccMagHistBinCount,hAccMagHistXLimMin,hAccMagHistXLimMax,hAccXYZHistBinCount,hAccXYZHistXLimMin,hAccXYZHistXLimMax,full_path,jsondata);
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

    function guiKeyPressFcn(~,e)
        if hPopupPanel.Value == 4
            switch(e.Key)
                case 'rightarrow'
                    classNavRightFunc;
                case 'leftarrow'
                    classNavLeftFunc;
            end
        end
    end

    function keyFcnECGbrowser(~,e,hSliderECGbr,hEcgBrBtnGrp,hEcgBrBtn1,hEcgBrBtn2,hEcgBrBtn3,hTxtECGTime,hDispRhytAnnECGbr)
        switch(e.Key)
            case {'rightarrow','downarrow'}
                ecgRange = rangeEndIndex.ECG - rangeStartIndex.ECG;
                rangeStartIndex.ECG = rangeStartIndex.ECG + ecgRange;
                rangeEndIndex.ECG = rangeEndIndex.ECG + ecgRange;
                [rangeStartIndex, rangeEndIndex] = setRangeEcgBr(rangeStartIndex, rangeEndIndex, C3);
                ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr);
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
                if hDispRhytAnnECGbr.Value
                    plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS)
                end
            case {'leftarrow','uparrow'}
                ecgRange = rangeEndIndex.ECG - rangeStartIndex.ECG;
                rangeStartIndex.ECG = rangeStartIndex.ECG - ecgRange;
                rangeEndIndex.ECG = rangeEndIndex.ECG - ecgRange;
                [rangeStartIndex, rangeEndIndex] = setRangeEcgBr(rangeStartIndex, rangeEndIndex, C3);
                ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr);
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
                if hDispRhytAnnECGbr.Value
                    plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS)
                end
            case {'1','numpad1'}
                set(hEcgBrBtnGrp,'selectedobject',hEcgBrBtn1);
                gS.ecgBrowserCh = 1;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            case {'2','numpad2'}
                set(hEcgBrBtnGrp,'selectedobject',hEcgBrBtn2);
                gS.ecgBrowserCh = 2;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
            case {'3','numpad3'}
                set(hEcgBrBtnGrp,'selectedobject',hEcgBrBtn3);
                gS.ecgBrowserCh = 3;
                plotEcgBrowser(C3,rangeStartIndex.ECG,rangeEndIndex.ECG,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS);
        end
    end

    function onClickAxECGbrowser(hObj,e,hAxAnnECGbrowser,hAxECGbrowser,hDispRhytAnnECGbr)
%         fprintf('\nCliked!');
        % if it was one of the annotation axes that was clicked
        if sum(hObj == hAxAnnECGbrowser)
            % if left-click
            if e.Button == 1
                if hDispRhytAnnECGbr.Value == 1
                    clickPoint = get(hObj,'CurrentPoint');
                    ecgSampleClick = round(clickPoint(1,1));
                    % cap click point value to within axis limits
                    ecgSampleClick(ecgSampleClick>hObj.XLim(2)) = hObj.XLim(2);
                    ecgSampleClick(ecgSampleClick<hObj.XLim(1)) = hObj.XLim(1);
                    [gS,rhytmAnns] = addRhythmAnnClickECGbr(ecgSampleClick,gS,rhytmAnns);
                    plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
%                     hAnnLine = plot(hObj,[ecgSampleClick ecgSampleClick],hObj.YLim,'LineStyle',':','LineWidth',1.5,'Color',gS.colors.col{4});
%                     fprintf('\nCliked ECG sample number: %d',ecgSampleClick);
%                     fprintf('\nAx lim: %d  %d',hObj.XLim);
                else
                    uiwait(msgbox(sprintf('Turning on display of annotations!\n\nYou may then click to add annotations.'),'Annotation visibility','modal'));
                    hDispRhytAnnECGbr.Value = 1;
                    plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
                end
            end
        end
    end

    function ecgBrDispRhytAnnFcn(hObj,~,hAxAnnECGbrowser)
        if hObj.Value == 1
            plotEcgBrowserAnn(rangeStartIndex.ECG,rangeEndIndex.ECG,rhytmAnns,hAxAnnECGbrowser,gS);
        else
            for ii=1:length(hAxAnnECGbrowser)
                cla(hAxAnnECGbrowser(ii));
            end
        end
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

    function ecgBrCloseReqFcn(hObj,~)
        delete(hObj);
        % update main GUI to display the same range as was just displayed in the ECG Browser
        rangeStartIndex.Accel = round(rangeStartIndex.ECG/sampleRateFactor.ECG);
        rangeEndIndex.Accel = round(rangeEndIndex.ECG/sampleRateFactor.ECG);
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
        if rangeStartIndex.Accel == 1 && rangeEndIndex.Accel == length(C3.accel.data)
            hResetButton.Enable = 'off';
            hRangeSlider.Enable = 'off';
        else
            hResetButton.Enable = 'on';
            hRangeSlider.Enable = 'on';
        end
        plotSensorData;
    end

end

%% Functions (Work in progress... moving inline functions outside of main function.)

function plotEcgBrowser(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxECGbrowser,hTxtECGTime,gS)
% fprintf('%f %f\n',startIdx,endIdx);
    % How many samples pr axis
    gS.ecgBrowserNumRows = length(hAxECGbrowser);
    smplsPrAx = floor((endIdx - startIdx) / gS.ecgBrowserNumRows);
    % Get timestamps
    xAxisTimeStamp = getTimeStamps(xAxisTimeStamps,timeBase,'ECG');
    % Plot
    axStartIdx = startIdx;
    axEndIdx = axStartIdx + smplsPrAx;
    for ii=1:gS.ecgBrowserNumRows
        cla(hAxECGbrowser(ii));
        hAxECGbrowser(ii).XLim = [axStartIdx axEndIdx];
        plot(hAxECGbrowser(ii),axStartIdx:axEndIdx,C3.ecg.data(axStartIdx:axEndIdx,gS.ecgBrowserCh),'Color',gS.colors.col{gS.ecgBrowserCh},'LineWidth',0.5);
        axStartIdx = axEndIdx;
        axEndIdx = axStartIdx + smplsPrAx;
    end
    if strcmp(timeBase,'World')
        hTxtECGTime.String = [datestr(xAxisTimeStamp(startIdx), 'yyyy-mm-dd     HH:MM:SS') ' ' char(8211) ' ' datestr(xAxisTimeStamp(endIdx), 'HH:MM:SS')];
    else
        [h,m,s] = hms([xAxisTimeStamp(startIdx) xAxisTimeStamp(endIdx)]);
        hTxtECGTime.String = [sprintf('%02i:%02i:%02i',h(1),m(1),floor(s(1))) ' ' char(8211) ' ' sprintf('%02i:%02i:%02i',h(2),m(2),floor(s(2)))];
    end
end

function plotEcgBrowserAnn(startIdx,endIdx,rhytmAnns,hAxAnnECGbrowser,gS)
    if ~isempty(rhytmAnns)
        % How many samples pr axis
        gS.ecgBrowserNumRows = length(hAxAnnECGbrowser);
        smplsPrAx = floor((endIdx - startIdx) / gS.ecgBrowserNumRows);
        % Plot
        axStartIdx = startIdx;
        axEndIdx = axStartIdx + smplsPrAx;
        for ii=1:gS.ecgBrowserNumRows
            cla(hAxAnnECGbrowser(ii));
            hAxAnnECGbrowser(ii).XLim = [axStartIdx axEndIdx];
            idxToPlot = find(rhytmAnns.ecg.idx >= axStartIdx & rhytmAnns.ecg.idx <= axEndIdx);
            if ~isempty(idxToPlot)
                for jj=1:length(idxToPlot)
                    plot(hAxAnnECGbrowser(ii),[rhytmAnns.ecg.idx(idxToPlot(jj)) rhytmAnns.ecg.idx(idxToPlot(jj))],[hAxAnnECGbrowser(ii).YLim(1) hAxAnnECGbrowser(ii).YLim(2)],'LineStyle',':','LineWidth',1.5,'Color',gS.colors.col{4});
                    if rhytmAnns.ecg.ann{idxToPlot(jj)}(end) == ')'
                        text(rhytmAnns.ecg.idx(idxToPlot(jj)), 0.05, [rhytmAnns.ecg.ann{idxToPlot(jj)} ' '], 'HorizontalAlignment', 'right', 'FontSize', 9, 'FontWeight', 'bold', 'Color', gS.colors.col{4}, 'EdgeColor', 'none', 'Parent', hAxAnnECGbrowser(ii));
                    else
                        text(rhytmAnns.ecg.idx(idxToPlot(jj)), 0.05, [' ' rhytmAnns.ecg.ann{idxToPlot(jj)}], 'HorizontalAlignment', 'left', 'FontSize', 9, 'FontWeight', 'bold', 'Color', gS.colors.col{4}, 'EdgeColor', 'none', 'Parent', hAxAnnECGbrowser(ii));
                    end
                end
            end
            axStartIdx = axEndIdx;
            axEndIdx = axStartIdx + smplsPrAx;
        end
    else
        gS.ecgBrowserNumRows = length(hAxAnnECGbrowser);
        smplsPrAx = floor((endIdx - startIdx) / gS.ecgBrowserNumRows);
        % Plot
        axStartIdx = startIdx;
        axEndIdx = axStartIdx + smplsPrAx;
        for ii=1:gS.ecgBrowserNumRows
            cla(hAxAnnECGbrowser(ii));
            hAxAnnECGbrowser(ii).XLim = [axStartIdx axEndIdx];
            axStartIdx = axEndIdx;
            axEndIdx = axStartIdx + smplsPrAx;
        end
    end
end

function plotReportMarkers(startIdx,endIdx,reportIOmarkers,hAxesECGMarkers,hAnalysisMarkersCheckbox,hECGkitListBox,gS)
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

function plotECGrhythmAnn(startIdx,endIdx,rhytmAnns,hAxesECGrhythmAnn,hECGrhythmAnnCheckbox,gS)
    cla(hAxesECGrhythmAnn);
    if hECGrhythmAnnCheckbox.Value == 1
        if ~isempty(rhytmAnns) && isfield(rhytmAnns,'ecg') && ~isempty(rhytmAnns.ecg.ann)
            hAxesECGrhythmAnn.XLim = [startIdx endIdx];
            % NOTE: find annotations that are within plot range (remember to
            % include the annotation (if any) that comes immediately before
            % the first whose sampleNum is within range!)
            numRhythmAnns = length(rhytmAnns.ecg.ann);
            currentSpan = endIdx-startIdx;
            for ii=1:numRhythmAnns
                plot(hAxesECGrhythmAnn,[rhytmAnns.ecg.idx(ii) rhytmAnns.ecg.idx(ii)], [0 1],'LineStyle',':','LineWidth',1.5,'Color',gS.colors.col{4});
                if currentSpan < 75001
                    if rhytmAnns.ecg.ann{ii}(end) == ')'
                        text(rhytmAnns.ecg.idx(ii), 0.05, [rhytmAnns.ecg.ann{ii} ' '], 'HorizontalAlignment', 'right', 'FontSize', 9, 'FontWeight', 'bold', 'Color', gS.colors.col{4}, 'EdgeColor', 'none', 'Parent', hAxesECGrhythmAnn);
                    else
                        text(rhytmAnns.ecg.idx(ii), 0.05, [' ' rhytmAnns.ecg.ann{ii}], 'HorizontalAlignment', 'left', 'FontSize', 9, 'FontWeight', 'bold', 'Color', gS.colors.col{4}, 'EdgeColor', 'none', 'Parent', hAxesECGrhythmAnn);
                    end
                end
            end
        end
    end
end

function plotEventMarkers(startIdx,endIdx,eventMarkers,hAxesEventMarkers,hEventMarkersCheckbox,hEventListBox,gS)
    cla(hAxesEventMarkers);
    if hEventMarkersCheckbox.Value == 1 && ~isempty(eventMarkers)
        % indices of markers within currently visible range
        markerIndices = [eventMarkers([eventMarkers.serial] >= startIdx & [eventMarkers.serial] <= endIdx).index];
        % indices of selected markers within currently visible range
        selectedMakers = intersect(hEventListBox.Value,markerIndices);
        % indices of non-selected markers within currently visible range
        nonSelectedMarkers = setdiff(markerIndices,selectedMakers);
        hAxesEventMarkers.XLim = [startIdx endIdx];
        for ii=1:length(nonSelectedMarkers)
            plot(hAxesEventMarkers, [eventMarkers(nonSelectedMarkers(ii)).serial eventMarkers(nonSelectedMarkers(ii)).serial], [0 1], 'Color', gS.colors.col{7}, 'LineWidth', 1.5, 'LineStyle', ':');
        end
        for ii=1:length(selectedMakers)
            plot(hAxesEventMarkers, [eventMarkers(selectedMakers(ii)).serial eventMarkers(selectedMakers(ii)).serial], [0 1], 'Color', min(gS.colors.col{7}*1.3,1), 'LineWidth', 1.5, 'LineStyle', ':');
        end
        % add numbers for markers
        for ii=1:length(nonSelectedMarkers)
            text(eventMarkers(nonSelectedMarkers(ii)).serial, 0.075, sprintf('%02d',nonSelectedMarkers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', gS.colors.col{7}, 'Color', gS.colors.col{4}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesEventMarkers);
        end
        for ii=1:length(selectedMakers)
            text(eventMarkers(selectedMakers(ii)).serial, 0.075, sprintf('%02d',selectedMakers(ii)), 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor', min(gS.colors.col{7}*1.3,1), 'Color', gS.colors.col{4}, 'Margin', 0.4, 'EdgeColor', 'none', 'Parent', hAxesEventMarkers);
        end
    end
end

function plotECGkitClass(startIdx,endIdx,cS,hAxesECGkitClass,hECGkitClassCheckbox,gS,CM_beatClass)
%     cla(hAxesECGkitClass);
%     if hECGkitClassCheckbox.Value == 1 && ~isempty(cS) && (endIdx-startIdx) < 15001
%         hAxesECGkitClass.XLim = [startIdx endIdx];
%         % find beats within displayed range
%         cSindicesBool = cS.time >= startIdx & cS.time <= endIdx; 
%         cSindices = find(cSindicesBool);
%         % plot class labels, one color per class
%         for ii=1:length(cSindices)
%             if cS.anntyp(cSindices(ii)) == 'N'
%                 annCol = gS.colors.col{13};
%             elseif cS.anntyp(cSindices(ii)) == 'S'
%                 annCol = gS.colors.col{9};
%             elseif cS.anntyp(cSindices(ii)) == 'V'
%                 annCol = gS.colors.col{10};
%             elseif cS.anntyp(cSindices(ii)) == 'U'
%                 annCol = gS.colors.col{11};
%             elseif cS.anntyp(cSindices(ii)) == 'F'
%                 annCol = gS.colors.col{12};
%             end
%             hTxt = text(cS.time(cSindices(ii)), 0.95, cS.anntyp(cSindices(ii)), 'HorizontalAlignment', 'left', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', annCol, 'Color', gS.colors.col{5}, 'Margin', 0.6, 'EdgeColor', 'none', 'Parent', hAxesECGkitClass);
%             % Set c to be the text's UIContextMenu
%             hTxt.UIContextMenu = CM_beatClass;
%         end
%     end
end

function plotQRSann(C3,startIdx,endIdx,qrsAnn,ibims,hAxesQRS,hDisplayBeatsCheckbox,hDisplayIBICheckbox,gS)
    cla(hAxesQRS);
    curRange = endIdx-startIdx;
    if ~isempty(qrsAnn) && curRange < 15001
        if hDisplayBeatsCheckbox.Value || hDisplayIBICheckbox.Value
            hAxesQRS.XLim = [startIdx endIdx];
            % find beats within displayed range
            qrsIndicesBool = qrsAnn{1,1}(:) >= startIdx & qrsAnn{1,1}(:) <= endIdx;
            if sum(qrsIndicesBool)
                if hDisplayBeatsCheckbox.Value
                    % plot a marker for each beat, if any in displayed range
                    plot(hAxesQRS,qrsAnn{1,1}(qrsIndicesBool),0.97,'Color','k','LineStyle','none','Marker','v','MarkerFaceColor','k','MarkerSize',5);
                end
                if ~isempty(ibims) && hDisplayIBICheckbox.Value && curRange < 7600
                    text(qrsAnn{1,1}(qrsIndicesBool(1:end-1))+round((ibims(qrsIndicesBool(1:end-1))/1000)*C3.ecg.fs*0.5), ones(length(qrsAnn{1,1}(qrsIndicesBool(1:end-1))),1)*0.96, num2str(ibims(qrsIndicesBool(1:end-1))), 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', gS.colors.col{4}, 'Parent', hAxesQRS);
                end
            end
        end
    end
end

function plotECG(C3,startIdx,endIdx,xAxisTimeStamps,timeBase,hAxesECG,hECG1Checkbox,hECG2Checkbox,hECG3Checkbox,hECGleadoffCheckbox,hECGkitClassCheckbox,cS,gS,CM_beatClass)
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
            if hECGkitClassCheckbox.Value == 1 && ~isempty(cS) && (endIdx-startIdx) < 15001
                txtYpos = hAxesECG.YLim(1) + (hAxesECG.YLim(2) - hAxesECG.YLim(1))*0.95;
                % find beats within displayed range
                cSindicesBool = cS.time >= startIdx & cS.time <= endIdx; 
                cSindices = find(cSindicesBool);
                % plot class labels, one color per class
                for ii=1:length(cSindices)
                    if cS.anntyp(cSindices(ii)) == 'N'
                        annCol = gS.colors.col{13};
                    elseif cS.anntyp(cSindices(ii)) == 'S'
                        annCol = gS.colors.col{9};
                    elseif cS.anntyp(cSindices(ii)) == 'V'
                        annCol = gS.colors.col{10};
                    elseif cS.anntyp(cSindices(ii)) == 'U'
                        annCol = gS.colors.col{11};
                    elseif cS.anntyp(cSindices(ii)) == 'F'
                        annCol = gS.colors.col{12};
                    elseif cS.anntyp(cSindices(ii)) == '|'
                        annCol = gS.colors.col{6};
                    end
                    hTxt = text(datenum(xAxisTimeStamp(cS.time(cSindices(ii)))), txtYpos, cS.anntyp(cSindices(ii)), 'HorizontalAlignment', 'left', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', annCol, 'Color', gS.colors.col{5}, 'Margin', 0.6, 'EdgeColor', 'none', 'Parent', hAxesECG);
                    % Store the cS.anntyp index number in the UserData property of the text label
                    hTxt.UserData = cSindices(ii);
                    % Set CM_beatClass to be the text's UIContextMenu
                    hTxt.UIContextMenu = CM_beatClass;
                end
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
            if hECGkitClassCheckbox.Value == 1 && ~isempty(cS) && (endIdx-startIdx) < 15001
                txtYpos = hAxesECG.YLim(1) + (hAxesECG.YLim(2) - hAxesECG.YLim(1))*0.95;
                % find beats within displayed range
                cSindicesBool = cS.time >= startIdx & cS.time <= endIdx; 
                cSindices = find(cSindicesBool);
                % plot class labels, one color per class
                for ii=1:length(cSindices)
                    if cS.anntyp(cSindices(ii)) == 'N'
                        annCol = gS.colors.col{13};
                    elseif cS.anntyp(cSindices(ii)) == 'S'
                        annCol = gS.colors.col{9};
                    elseif cS.anntyp(cSindices(ii)) == 'V'
                        annCol = gS.colors.col{10};
                    elseif cS.anntyp(cSindices(ii)) == 'U'
                        annCol = gS.colors.col{11};
                    elseif cS.anntyp(cSindices(ii)) == 'F'
                        annCol = gS.colors.col{12};
                    elseif cS.anntyp(cSindices(ii)) == '|'
                        annCol = gS.colors.col{6};
                    end
                    hTxt = text(datenum(xAxisTimeStamp(cS.time(cSindices(ii)))), txtYpos, cS.anntyp(cSindices(ii)), 'HorizontalAlignment', 'left', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', annCol, 'Color', gS.colors.col{5}, 'Margin', 0.6, 'EdgeColor', 'none', 'Parent', hAxesECG);
                    % Store the cS.anntyp index number in the UserData property of the text label
                    hTxt.UserData = cSindices(ii);
                    % Set CM_beatClass to be the text's UIContextMenu
                    hTxt.UIContextMenu = CM_beatClass;
                end
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
    % search for index of value closest to given time, in the Accel data
    accelIndex = (find(datenum(xAxisTimeStamps.world.Accel) > datenum(timePoint), 1)) - 1;
else
    % search for index of value closest to given time, in the Accel data
    accelIndex = (find(datenum(xAxisTimeStamps.duration.Accel) > datenum(timePoint), 1)) - 1;
end
end

function ecgIndex = getEcgIndexPoint(xAxisTimeStamps,timeBase,timePoint)
% This function finds the ECG index number that most closely corresponds to the given time input.
% hTic_getEcgIndexPoint = tic;
if strcmp(timeBase,'World')
    % search for index of value closest to given time, in the ECG data
    ecgIndex = (find(datenum(xAxisTimeStamps.world.ECG) > datenum(timePoint), 1)) - 1;
else
    % search for index of value closest to given time, in the ECG data
    ecgIndex = (find(datenum(xAxisTimeStamps.duration.ECG) > datenum(timePoint), 1)) - 1;
end
% fprintf('getEcgPointIndex: %f seconds\n',toc(hTic_getEcgIndexPoint));
end

function setRecordingTimeInfo(C3,hTextTimeRecording,hTextDurationRecording)
    % World time of recording
    timeStart.world = datetime(C3.date_start, 'ConvertFrom', 'datenum');
    timeEnd.world = datetime(C3.date_end, 'ConvertFrom', 'datenum');
    set(hTextTimeRecording,'String',[datestr(timeStart.world, 'yyyy/mm/dd, HH:MM:SS') ' ' char(8211) ' ' datestr(timeEnd.world, 'yyyy/mm/dd, HH:MM:SS')]);
    % Duration of recording
    deltaTime = datetime(C3.date_end, 'ConvertFrom', 'datenum') - datetime(C3.date_start, 'ConvertFrom', 'datenum');
    [h,m,s] = hms(deltaTime);
    set(hTextDurationRecording,'String',sprintf('%02i:%02i:%02i  (hrs:min:sec)',h(1),m(1),floor(s(1))));
end

function setRangeInfo(xAxisTimeStamps,timeBase,rangeStartIndex,rangeEndIndex,hTextTimeDisplayed)
% Update the info-text that displays range start and end time
%     hTic_setRangeInfo = tic;
if strcmp(timeBase,'World')
    set(hTextTimeDisplayed,'String',[datestr(xAxisTimeStamps.world.Accel(rangeStartIndex.Accel), 'yyyy/mm/dd, HH:MM:SS') ' - ' datestr(xAxisTimeStamps.world.Accel(rangeEndIndex.Accel), 'yyyy/mm/dd, HH:MM:SS')]);
else
    [h,m,s] = hms([xAxisTimeStamps.duration.Accel(rangeStartIndex.Accel) xAxisTimeStamps.duration.Accel(rangeEndIndex.Accel)]);
    set(hTextTimeDisplayed,'String',[sprintf('%02i:%02i:%02i',h(1),m(1),round(s(1))) ' ' char(8211) ' ' sprintf('%02i:%02i:%02i',h(2),m(2),floor(s(2)))]);
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
    rangeStr = sprintf('%04d%02d%02dT%02d%02d%02d-%04d%02d%02dT%02d%02d%02d',Y(1),M(1),D(1),h(1),m(1),floor(s(1)),Y(2),M(2),D(2),h(2),m(2),floor(s(2)));
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
    rangeStr = [sprintf('%02ih%02im%02is',h(1),m(1),floor(s(1))) '-' sprintf('%02ih%02im%02is',h(2),m(2),floor(s(2)))];
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

% Function for setting range in ECG Browser
function [rangeStartIndex, rangeEndIndex] = setRangeEcgBr(rangeStartIndex, rangeEndIndex, C3)
    [startIdx, endIdx] = setRangeWithinBounds(rangeStartIndex.ECG, rangeEndIndex.ECG, C3.ecg.samplenum);
    rangeStartIndex.ECG = startIdx;
    rangeEndIndex.ECG = endIdx;
    % Keeping the other indices as they are. Will be updated in ECG Browser closereq function.
    rangeStartIndex.Accel = rangeStartIndex.Accel;
    rangeEndIndex.Accel = rangeEndIndex.Accel;
    rangeStartIndex.Temp = rangeStartIndex.Temp ;
    rangeEndIndex.Temp = rangeEndIndex.Temp;
    rangeStartIndex.Resp = rangeStartIndex.Resp;
    rangeEndIndex.Resp = rangeEndIndex.Resp;
end

function [startIdx, endIdx] = setRangeWithinBounds(startIdx, endIdx, numSamples)
    idxRange = endIdx - startIdx;
    if startIdx < 1
        startIdx = 1;
        endIdx = 1 + idxRange;
    end
    if endIdx > numSamples
        startIdx = max(1,(numSamples - idxRange));
        endIdx = min(numSamples,(startIdx + idxRange));
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

function [rangeStartIndex, rangeEndIndex] = setRangeOnLoad(C3,xAxisTimeStamps,rangeStartIndex,rangeEndIndex,timeBase,sampleRateFactor,hResetButton,hRangeSlider,hPopupEvent,hNavEventLeftButton,hNavEventRightButton)
% Show max 5 minutes, when loading a new recording
% Find Accel index for 5 min after start of recording
if strcmp(timeBase,'World')
    displayRangeEnd = datetime(addtodate(C3.date_start,5*60*1000,'millisecond'),'ConvertFrom','datenum','Format','yyyy-MM-dd''T''HH:mm:ss.SSS+0000','TimeZone','local');
    accelIndex = getAccelIndexPoint(xAxisTimeStamps,timeBase,displayRangeEnd);
    if isempty(accelIndex)
        displayingFull = true;
    else
        displayingFull = false;
    end
else
    displayRangeEnd = days(minutes(5));
    accelIndex = getAccelIndexPoint(xAxisTimeStamps,timeBase,displayRangeEnd);
    if isempty(accelIndex)
        displayingFull = true;
    else
        displayingFull = false;
    end
end
if displayingFull
    hResetButton.Enable = 'off';
    hRangeSlider.Enable = 'off';
    hPopupEvent.Enable = 'off';
    hNavEventLeftButton.Enable = 'off';
    hNavEventRightButton.Enable = 'off';
    rangeStartIndex.Accel = 1;
    rangeEndIndex.Accel = length(C3.accel.data);
    rangeStartIndex.Temp = 1;
    rangeEndIndex.Temp = length(C3.temp.data);
    rangeStartIndex.ECG = 1;
    rangeEndIndex.ECG = length(C3.ecg.data);
    rangeStartIndex.Resp = 1;
    rangeEndIndex.Resp = length(C3.resp.data);
else
    hResetButton.Enable = 'on';
    hRangeSlider.Enable = 'on';
    hPopupEvent.Enable = 'on';
    hNavEventLeftButton.Enable = 'on';
    hNavEventRightButton.Enable = 'on';
    rangeStartIndex.Accel = 1;
    rangeEndIndex.Accel = accelIndex;
    rangeStartIndex.Temp = 1;
    rangeEndIndex.Temp = min(length(C3.temp.data), round(rangeEndIndex.Accel * sampleRateFactor.Temp));
    rangeStartIndex.ECG = 1;
    rangeEndIndex.ECG = min(length(C3.ecg.data), rangeEndIndex.Accel * sampleRateFactor.ECG);
    rangeStartIndex.Resp = 1;
    rangeEndIndex.Resp = min(length(C3.resp.data), rangeEndIndex.Accel * sampleRateFactor.Resp);
end
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

function ecgBrSetSlider(C3,rangeStartIndex,rangeEndIndex,hSliderECGbr)
    currentRange = (rangeEndIndex.ECG - rangeStartIndex.ECG + 1);
    if currentRange ~= length(C3.ecg.data)
        halfRange = round(currentRange * 0.5);
        hSliderECGbr.Min = halfRange;
        hSliderECGbr.Max = C3.ecg.samplenum - halfRange;
        minorstep = max(0.0000011, currentRange/double(C3.ecg.samplenum)); % slider minorstep must be > 0.000001
        majorstep = minorstep * 10;
        hSliderECGbr.SliderStep = [minorstep majorstep];
        sliderVal = rangeStartIndex.ECG + halfRange;
        if sliderVal > hSliderECGbr.Max
            sliderVal = hSliderECGbr.Max;
        end
        if sliderVal < hSliderECGbr.Min
            sliderVal = hSliderECGbr.Min;
        end
        hSliderECGbr.Value = sliderVal;
    else
        hSliderECGbr.Min = 1;
        hSliderECGbr.Max = C3.ecg.samplenum;
        hSliderECGbr.SliderStep = [1 10000];
        hSliderECGbr.Value = 1;
    end
%     fprintf('SET: Slider min: %d  max: %d  val: %d   minStep: %f  maxStep: %f\n',hSliderECGbr.Min, hSliderECGbr.Max, hSliderECGbr.Value, hSliderECGbr.SliderStep(1), hSliderECGbr.SliderStep(2));
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
            hPopupEcgHighPass.Value = 9;
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
            hPopupEcgHighPass.Value = 9;
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
            hPopupEcgHighPass.Value = 9;
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
            C3.ecg.data = C3.ecg.dataRaw; % "Raw" not really raw when from 16bit recording, which was already highpass filtered
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

function qrsAnn = detectQRS(C3,conf,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hPopupECGch,hPopupQRSdet,full_path,rangeStr,contextStr,fileFormat,jsondata,bin_path)
    [screenWidth, screenHeight] = getScreenSize();
    d = dialog('Position',[round(screenWidth/2)-125 round(screenHeight/2)-25 250 50],'Name','Please wait');
    hDialogTxt = uicontrol('Parent',d,'Style','text','Position',[20 5 210 30],'FontSize',10,'String','Exporting data for QRS detection...');
    pause(0.1);
    ecgChannel = hPopupECGch.Value;
    qrsDetectorList = get(hPopupQRSdet,'String');
    qrsDetector = qrsDetectorList{get(hPopupQRSdet,'Value')};
    % First, export ECG data to MIT format.
    % Fake ECG channel checkboxes, to accomodate exportECGtoMITfiles input args
    if ecgChannel == 1
        hEcg1Checkbox.Value = 1; hEcg2Checkbox.Value = 0; hEcg3Checkbox.Value = 0;
    elseif ecgChannel == 2
        hEcg1Checkbox.Value = 0; hEcg2Checkbox.Value = 1; hEcg3Checkbox.Value = 0;
    else
        hEcg1Checkbox.Value = 0; hEcg2Checkbox.Value = 0; hEcg3Checkbox.Value = 1;
    end
    hea_fullpath = exportECGtoMITfiles(C3,conf,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hEcg1Checkbox,hEcg2Checkbox,hEcg3Checkbox,full_path,rangeStr,contextStr,fileFormat,jsondata,bin_path);
    % Change dir to location of MIT files
    [pathName,recordName,~] = fileparts(hea_fullpath);
    org_path = cd(pathName);
    % Then, perform QRS detection
    if ishandle(d)
        hDialogTxt.String = 'QRS detection in progress...';
    end
    pause(0.1);
    if strcmp(qrsDetector,'gqrs')
        % Run gqrs detector (results will be output to .qrs annotation file)
        sysCmd = ['"' bin_path filesep 'gqrs.exe" -r ' recordName];
        [statusReturn,outReturn] = system(sysCmd);
        if statusReturn ~= 0
            if ishandle(d)
                delete(d);
            end
            warndlg(sprintf('QRS detection process failed!\n\nError message from gqrs.exe:%s\nsysCmd:\n%s',outReturn,sysCmd));
        end
    elseif strcmp(qrsDetector,'wqrs')
        % Run wqrs detector (results will be output to .wqrs annotation file)
        sysCmd = ['"' bin_path filesep 'wqrs.exe" -r ' recordName];
        [statusReturn,outReturn] = system(sysCmd);
        if statusReturn ~= 0
            if ishandle(d)
                delete(d);
            end
            warndlg(sprintf(['QRS detection process failed!\n\nError message from wqrs.exe:\n' outReturn]));
        end
    end
    % Load the QRS detection
    if statusReturn == 0
        if ishandle(d)
            hDialogTxt.String = 'Loading and formatting QRS detection...';
        end
        if strcmp(qrsDetector,'gqrs')
            sysCmd = ['"' bin_path filesep 'rdann.exe" -a qrs -r ' recordName];
            [statusReturn,outReturn] = system(sysCmd);
            if statusReturn ~= 0
                if ishandle(d)
                    delete(d);
                end
                warndlg(sprintf(['Loading the QRS detection failed!\n\nError message from rdann.exe:\n' outReturn]))
                qrsAnn = cell(0);
                return;
            end
            % Format the output from rdann
            % read the first 3 columns and ignore remaining colums. Column 2 is the
            % sample index numbers for beats. Column 3 is annotation type (e.g. 'N')
            qrsAnn = textscan(outReturn,'%s %f %c %*[^\n]');
            % No need for the first column
            qrsAnn(:,1) = [];
            % shift sample number by +1, since WFDB tools operate with
            % 0-based index, and Matlab operates with 1-based index
            qrsAnn{1,1} = qrsAnn{1,1} + 1;            
        elseif strcmp(qrsDetector,'wqrs')
            sysCmd = ['"' bin_path filesep 'rdann.exe" -a wqrs -r ' recordName];
            [statusReturn,outReturn] = system(sysCmd);
            if statusReturn ~= 0
                if ishandle(d)
                    delete(d);
                end
                warndlg(sprintf(['Loading the QRS detection failed!\n\nError message from rdann.exe:\n' outReturn]))
                qrsAnn = cell(0);
                return;
            end
            % Format the output from rdann
            % read the first 3 columns and ignore remaining colums. Column 2 is the
            % sample index numbers for beats. Column 3 is annotation type ('N' for wqrs detector)
            qrsAnn = textscan(outReturn,'%s %f %c %*[^\n]');
            % No need for the first column
            qrsAnn(:,1) = [];
            % shift sample number by +1, since WFDB tools operate with
            % 0-based index, and Matlab operates with 1-based index
            qrsAnn{1,1} = qrsAnn{1,1} + 1;
        end
        if ishandle(d)
            delete(d);
        end
    else
        qrsAnn = cell(0);
    end
    % Change working dir back to origin
    cd(org_path);
end

function qrsAnn = loadQRS(last_path,bin_path)
    org_path = cd(last_path);
    [fileName,pathName] = uigetfile({'*.qrs;*.wqrs','QRS detection files'});
    cd(org_path);
    if fileName
        [screenWidth, screenHeight] = getScreenSize();
        d = dialog('Position',[round(screenWidth/2)-125 round(screenHeight/2)-25 250 50],'Name','Please wait');
        uicontrol('Parent',d,'Style','text','Position',[20 5 210 30],'FontSize',10,'String','Loading and formatting QRS detection...');
        pause(0.1);
        org_path = cd(pathName);
        [~,recordName,fileExt] = fileparts(fullfile(pathName,fileName));
        if strcmp(fileExt,'.qrs')
            sysCmd = ['"' bin_path filesep 'rdann.exe" -a qrs -r ' recordName];
            [statusReturn,outReturn] = system(sysCmd);
            if statusReturn ~= 0
                if ishandle(d)
                    delete(d);
                end
                warndlg(sprintf(['Loading the QRS detection failed!\n\nError message from rdann.exe:\n' outReturn]));
                qrsAnn = cell(0);
                return;
            end
            % Format the output from rdann
            % read the first 3 columns and ignore remaining colums. Column 2 is the
            % sample index numbers for beats. Column 3 is annotation type (e.g. 'N')
            qrsAnn = textscan(outReturn,'%s %f %c %*[^\n]');
            % No need for the first column
            qrsAnn(:,1) = [];
            % shift sample number by +1, since WFDB tools operate with
            % 0-based index, and Matlab operates with 1-based index
            qrsAnn{1,1} = qrsAnn{1,1} + 1;            
        elseif strcmp(fileExt,'.wqrs')
            sysCmd = ['"' bin_path filesep 'rdann.exe" -a wqrs -r ' recordName];
            [statusReturn,outReturn] = system(sysCmd);
            if statusReturn ~= 0
                if ishandle(d)
                    delete(d);
                end
                warndlg(sprintf(['Loading the QRS detection failed!\n\nError message from rdann.exe:\n' outReturn]));
                qrsAnn = cell(0);
                return;
            end
            % Format the output from rdann
            % read the first 3 columns and ignore remaining colums. Column 2 is the
            % sample index numbers for beats. Column 3 is annotation type ('N' for wqrs detector)
            qrsAnn = textscan(outReturn,'%s %f %c %*[^\n]');
            % No need for the first column
            qrsAnn(:,1) = [];
            % shift sample number by +1, since WFDB tools operate with
            % 0-based index, and Matlab operates with 1-based index
            qrsAnn{1,1} = qrsAnn{1,1} + 1;
        end
        if ishandle(d)
            delete(d);
        end
        % Look for and load a JSON in the same folder
        listjson_segment = dir([pathName '*.JSON']);
        % If only one JSON file exist in this directory, load it
        if size(listjson_segment,1) == 1
            json_segment_fullpath = fullfile(pathName, listjson_segment(1).name);
            jsondata_QRSdetection_segment = loadjson(json_segment_fullpath);
        % else, if more than 1 JSON file is present, warn and return
        elseif size(listjson_segment,1) > 1
            warndlg(sprintf('More than one JSON file present with QRS detection!\nLoaded QRS detection was ignored.'));
            qrsAnn = cell(0);
            return;
        end
        % If JSON 'ecgsampleoffset' field is present, offset sample numbers to match loaded segment
        if ~isempty(jsondata_QRSdetection_segment) && isfield(jsondata_QRSdetection_segment,'ecgsampleoffset')
            qrsAnn{1,1} = qrsAnn{1,1} + jsondata_QRSdetection_segment.ecgsampleoffset;
        else
            warndlg(sprintf(['JSON file for this analysis segment did not contain an "ecgsampleoffset" field!\n\n'...
            'QRS detections can not be displayed in ECG plot.\nPlease perform a new QRS detection.']));
            qrsAnn = cell(0);
            return;
        end
        cd(org_path);
    else
        qrsAnn = cell(0);
    end
end

function [ibims, ibiDiffms] = calcIBIstats(C3,qrsAnn,hTxtTotalBeats,hTxtIBImin,hTxtIBImean,hTxtIBImax,hTxtIBIstd,hTxtIBIdiffmin,hTxtIBIdiffmean,hTxtIBIdiffmax,hTxtIBIdiffstd)
    ibims = (double(diff(qrsAnn{1,1}))/double(C3.ecg.fs))*1000;
    hTxtTotalBeats.String = num2str(length(qrsAnn{1,1}));
    hTxtIBImin.String = num2str(round(nanmin(ibims)));
    hTxtIBImean.String = num2str(round(nanmean(ibims)));
    hTxtIBImax.String = num2str(round(nanmax(ibims)));
    hTxtIBIstd.String = num2str(round(nanstd(ibims)));
    ibiDiffms = diff(ibims);
    hTxtIBIdiffmin.String = num2str(round(nanmin(ibiDiffms)));
    hTxtIBIdiffmean.String = num2str(round(nanmean(ibiDiffms)));
    hTxtIBIdiffmax.String = num2str(round(nanmax(ibiDiffms)));
    hTxtIBIdiffstd.String = num2str(round(nanstd(ibiDiffms)));
end

function hea_fullpath = exportECGtoMITfiles(C3,conf,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hEcg1Checkbox,hEcg2Checkbox,hEcg3Checkbox,full_path,rangeStr,contextStr,fileFormat,jsondata,bin_path)
    [source_path,filename_wo_extension,file_extension] = fileparts(full_path);
    if strcmp(contextStr,'export')
        exportMainFolderName = 'Export - ECG MIT';
    elseif strcmp(contextStr,'ecgkit')
        exportMainFolderName = 'ECGkit analysis';
    elseif strcmp(contextStr,'qrsdetect')
        exportMainFolderName = 'QRS detection';
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
        physiobank_fullpath = exportECGtoPhysiobankFile(C3,conf,fileFormat,idxMin,idxMax,chNum,export_sub_path,filename_wo_extension,contextStr);
        % Get units-per-milliVolt
        if strcmp(fileFormat,'BLE 24bit')
            % Get units-per-milliVolt. It is now assumed that gain equals 1, when exporting to PhysioBank (for conversion to 16bit MIT format)
            c3ecgUnitsPerMv = c3_getUnitsPerMillivolt(fileFormat,1);
        else
            % assumed to be 16 bit ECG
            c3ecgUnitsPerMv = c3_getUnitsPerMillivolt(fileFormat,1);
        end
        c3ecgUnitsPerMvStr = num2str(round(c3ecgUnitsPerMv));
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
                cmd_str = ['"' bin_path filesep 'wrsamp.exe" -F ' num2str(C3.ecg.fs) ' -i "' physiobank_fullpath '" -o "' filename_wo_extension '" -O 16 -G ' c3ecgUnitsPerMvStr];
            otherwise
                % Output format 16, and gain set at 5243 units pr mV
                cmd_str = ['"' bin_path filesep 'wrsamp.exe" -F ' num2str(C3.ecg.fs) ' -i "' physiobank_fullpath '" -o "' filename_wo_extension '" -O 16 -G ' c3ecgUnitsPerMvStr];
        end        
        [cmd_status,~] = system(cmd_str);
        % For 'QRS detection' export a new JSON file with the "start" field reflecting the start time of this segment, 
        % and a field indicating the ecg sample number of the original recording that this segment starts from
        % Temporary variable for jsondata, to avoid time-offsets being saved to the JSON file.
        if strcmp(contextStr,'qrsdetect')
            if ~isempty(jsondata)
                jsondata_temp = jsondata;
            else
                jsondata_temp.start = '';
            end
            jsonTimeOffsetMillisecs = (indexStartECG/double(C3.ecg.fs)) * 1000;
            timeStartOfThisSegment = datetime(addtodate(C3.date_start,jsonTimeOffsetMillisecs,'millisecond'),'ConvertFrom','datenum','Format','yyyy-MM-dd''T''HH:mm:ss.SSS+0000','TimeZone','local');
            jsondata_temp.start = datestr(timeStartOfThisSegment,'yyyy-mm-ddTHH:MM:SS.FFF+0000');
            jsondata_temp.ecgsampleoffset = indexStartECG;
            savejson('',jsondata_temp,'FileName',fullfile(export_sub_path,[filename_wo_extension '.json']),'ParseLogical',1);
        end
        % go back to previous directory
        cd(currentFolder);
        % if the MIT files were generated for export purpose (not for
        % ECGkit report) then tidy up, by deleting the physiobank file.
        if strcmp(contextStr,'export') || strcmp(contextStr,'QRS detection')
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
    export_main_path = [source_path filesep 'Export - ECG CSV'];
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

function kubiosTxt_fullpath = exportECGtoKubios(C3,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,hExportRangeButtonGroup,hExportEcg1Checkbox,hExportEcg2Checkbox,hExportEcg3Checkbox,full_path,jsondata,fileFormat)
    unitsPerMv = getUnitsPerMillivolt(jsondata,fileFormat);
    [source_path,filename_wo_extension,file_extension] = fileparts(full_path);
    export_main_path = [source_path filesep 'Export - ECG Kubios'];
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
        chHeaderStr = [{'ECG1'},{'ECG2'},{'ECG3'}];
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 0
        chNum = [1 2];
        chNumStr = '1_2';
        chHeaderStr = [{'ECG1'},{'ECG2'}];
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 1
        chNum = [1 3];
        chNumStr = '1_3';
        chHeaderStr = [{'ECG1'},{'ECG3'}];
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 1
        chNum = [2 3];
        chNumStr = '2_3';
        chHeaderStr = [{'ECG2'},{'ECG3'}];
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 1
        chNum = 3;
        chNumStr = '3';
        chHeaderStr = {'ECG3'};
    elseif hExportEcg1Checkbox.Value == 0 && hExportEcg2Checkbox.Value == 1 && hExportEcg3Checkbox.Value == 0
        chNum = 2;
        chNumStr = '2';
        chHeaderStr = {'ECG2'};
    elseif hExportEcg1Checkbox.Value == 1 && hExportEcg2Checkbox.Value == 0 && hExportEcg3Checkbox.Value == 0
        chNum = 1;
        chNumStr = '1';
        chHeaderStr = {'ECG1'};
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
        genericInfoStr = 'ECG sampling rate: 250Hz. Units: mV';
        kubiosTxt_fullpath = [export_sub_path filesep filename_wo_extension '.txt'];
        % Create and write Kubios ECG txt file.
        fid = fopen(kubiosTxt_fullpath,'w');
        % Write generic header
        fprintf(fid, '%s\r\n\r\n', genericInfoStr);
        % Write ECG channel header
        if size(chHeaderStr,2) == 1
            fprintf(fid, '%s\r\n', chHeaderStr{1});
        else
            fprintf(fid, '%s\t', chHeaderStr{1,1:end-1});
            fprintf(fid, '%s\r\n', chHeaderStr{1,end});
        end
        % close file and open in append mode
        fclose(fid);
        fid = fopen(kubiosTxt_fullpath,'a');
        % write data
        if length(chNum) == 3
            fprintf(fid, '%.3f\t%.3f\t%.3f\r\n', (C3.ecg.data(idxMin:idxMax,chNum)/unitsPerMv)');
        elseif length(chNum) == 2
            fprintf(fid, '%.3f\t%.3f\r\n', (C3.ecg.data(idxMin:idxMax,chNum)/unitsPerMv)');
        else
            fprintf(fid, '%.3f\r\n', (C3.ecg.data(idxMin:idxMax,chNum)/unitsPerMv)');
        end
        fclose(fid);
    else
        kubiosTxt_fullpath = [];
    end
    msgbox({'Export to Kubios ASCII file completed!' kubiosTxt_fullpath});
end

function physiobank_fullpath = exportECGtoPhysiobankFile(C3,conf,fileFormat,indexStartECG,indexEndECG,chNum,export_sub_path,filename_wo_extension,contextStr)
    if strcmp(fileFormat,'BLE 24bit')
        % Get gain, so ECG can be scaled to gain 1 in order to avoid 16bit overflow
        c3ecgGain = c3_getEcgGain(conf);
    else
        % assumed to be 16 bit ECG
        c3ecgGain = 1;
    end
    scaleFactor = 1/double(c3ecgGain);
    c3EcgTempExportData = C3.ecg.data*scaleFactor;
    % Cap values outside of int16
    c3EcgTempExportData(c3EcgTempExportData > 32767) = 32767;
    c3EcgTempExportData(c3EcgTempExportData < -32767) = -32767;
    if strcmp(contextStr,'ecgkit')
        % write a physiobank file for the report script
        physiobank_file_for_report = fullfile(export_sub_path, [filename_wo_extension '_physiobank.txt']);
        % if 3-channel output
        if length(chNum) == 3
            dlmwrite(physiobank_file_for_report, 'MLI MLII MLIII', 'delimiter', '');
            fid = fopen(physiobank_file_for_report,'a');
            fprintf(fid,'%.f %.f %.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
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
            fprintf(fid,'%.f %.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
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
            fprintf(fid,'%.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
        end
        fclose(fid);
    end
    % physiobank file for wrsamp.exe conversion to .dat
    if length(chNum) == 3
        outStr = sprintf('%.f %.f %.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
    elseif length(chNum) == 2
        outStr = sprintf('%.f %.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
    else
        outStr = sprintf('%.f\n',c3EcgTempExportData(indexStartECG:indexEndECG,chNum)');
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

function csIdxSel = getClassAnnIdx(xMin,xMax,xAxisTimeStamps,timeBase,cS,sampleRateFactor)
    [rangeStartIndex, rangeEndIndex] = getRangeIndices(xAxisTimeStamps,timeBase,xMin,xMax,sampleRateFactor);
    if ~isempty(cS)
    % find beats within displayed range
        cSindicesBool = cS.time >= rangeStartIndex.ECG & cS.time <= rangeEndIndex.ECG; 
        csIdxSel = find(cSindicesBool);
    else
        csIdxSel = [];
    end
end

function [gS,rhytmAnns] = addRhythmAnnClick(timePoint,xAxisTimeStamps,timeBase,gS,rhytmAnns,signalName)
    if strcmp(signalName,'ECG')
        if isempty(rhytmAnns)
        	numrhytmAnns = 0;
        elseif ~isempty(rhytmAnns) && isfield(rhytmAnns,'ecg')
            numrhytmAnns = length(rhytmAnns.ecg.ann);
        else
            numrhytmAnns = 0;
        end
        ecgIndex = getEcgIndexPoint(xAxisTimeStamps,timeBase,timePoint);
        if numrhytmAnns == 0
            precedingRhytmAnn = '';
            ECGann = dialogAnnECG(precedingRhytmAnn);
            if ~isempty(ECGann)
                rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
                rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
            end
        else
            % find the annotation (if any) that precedes this point, to offer
            % a choice to annotate the current point as the end of the
            % preceding rhythm explicitly, or the beginning of a new rhythm.
            precedingRhytmIdx = find([rhytmAnns.ecg.idx] <= ecgIndex,1,'last');
            if ~isempty(precedingRhytmIdx)
                if precedingRhytmIdx ~= ecgIndex
                    succedingRhytmIdx = find([rhytmAnns.ecg.idx] > ecgIndex,1);
                    if ~isempty(succedingRhytmIdx)
                        succRhythmAnn = rhytmAnns.ecg.ann{succedingRhytmIdx};
                    else
                        succRhythmAnn = '-';
                    end
                    preRhythmAnn = rhytmAnns.ecg.ann{precedingRhytmIdx};                    
                    if preRhythmAnn(1) == '(' && succRhythmAnn(end) ~= ')'
                        ECGann = dialogAnnECG(preRhythmAnn);
                    elseif preRhythmAnn(1) == '(' && succRhythmAnn(end) == ')'
                        warndlg(sprintf('A new annotation can not be created in between\na closed set of rhythm annotations, enclosed by ( ).\n\nIn this case:  %s     %s',preRhythmAnn,succRhythmAnn),'Warning','modal');
                        ECGann = '';
                    else
                        precedingRhytmAnn = '';
                        ECGann = dialogAnnECG(precedingRhytmAnn);
                    end
                    if ~isempty(ECGann)
                        rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
                        rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
                        % sort the annotation struct
                        [~,reIdx]=sort([rhytmAnns.ecg.idx]);
                        rhytmAnns.ecg.idx = rhytmAnns.ecg.idx(reIdx);
                        rhytmAnns.ecg.ann = rhytmAnns.ecg.ann(reIdx);
                    end
                else
                    warndlg(sprintf('A new annotation can not be created at the exact same point as an existing annotation!\n\nIf you want to edit the existing annotation, then right-click on it.'),'Warning!','modal');
                end
            else
                precedingRhytmAnn = '';
                ECGann = dialogAnnECG(precedingRhytmAnn);
                if ~isempty(ECGann)
                    rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
                    rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
                    % sort the annotation struct
                    [~,reIdx]=sort([rhytmAnns.ecg.idx]);
                    rhytmAnns.ecg.ann = rhytmAnns.ecg.ann(reIdx);
                    rhytmAnns.ecg.idx = rhytmAnns.ecg.idx(reIdx);
                end
            end
        end
    end
end

function [gS,rhytmAnns] = addRhythmAnnClickECGbr(ecgIndex,gS,rhytmAnns)
    if isempty(rhytmAnns)
        numrhytmAnns = 0;
    elseif ~isempty(rhytmAnns) && isfield(rhytmAnns,'ecg')
        numrhytmAnns = length(rhytmAnns.ecg.ann);
    else
        numrhytmAnns = 0;
    end
    if numrhytmAnns == 0
        precedingRhytmAnn = '';
        ECGann = dialogAnnECG(precedingRhytmAnn);
        if ~isempty(ECGann)
            rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
            rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
        end
    else
        % find the annotation (if any) that precedes this point, to offer
        % a choice to annotate the current point as the end of the
        % preceding rhythm explicitly, or the beginning of a new rhythm.
        precedingRhytmIdx = find([rhytmAnns.ecg.idx] <= ecgIndex,1,'last');
        if ~isempty(precedingRhytmIdx)
            if precedingRhytmIdx ~= ecgIndex
                succedingRhytmIdx = find([rhytmAnns.ecg.idx] > ecgIndex,1);
                if ~isempty(succedingRhytmIdx)
                    succRhythmAnn = rhytmAnns.ecg.ann{succedingRhytmIdx};
                else
                    succRhythmAnn = '-';
                end
                preRhythmAnn = rhytmAnns.ecg.ann{precedingRhytmIdx};                    
                if preRhythmAnn(1) == '(' && succRhythmAnn(end) ~= ')'
                    ECGann = dialogAnnECG(preRhythmAnn);
                elseif preRhythmAnn(1) == '(' && succRhythmAnn(end) == ')'
                    warndlg(sprintf('A new annotation can not be created in between\na closed set of rhythm annotations, enclosed by ( ).\n\nIn this case:  %s     %s',preRhythmAnn,succRhythmAnn),'Warning','modal');
                    ECGann = '';
                else
                    precedingRhytmAnn = '';
                    ECGann = dialogAnnECG(precedingRhytmAnn);
                end
                if ~isempty(ECGann)
                    rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
                    rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
                    % sort the annotation struct
                    [~,reIdx]=sort([rhytmAnns.ecg.idx]);
                    rhytmAnns.ecg.idx = rhytmAnns.ecg.idx(reIdx);
                    rhytmAnns.ecg.ann = rhytmAnns.ecg.ann(reIdx);
                end
            else
                warndlg(sprintf('A new annotation can not be created at the exact same point as an existing annotation!\n\nIf you want to edit the existing annotation, then right-click on it.'),'Warning!','modal');
            end
        else
            precedingRhytmAnn = '';
            ECGann = dialogAnnECG(precedingRhytmAnn);
            if ~isempty(ECGann)
                rhytmAnns.ecg.idx(numrhytmAnns+1) = ecgIndex;
                rhytmAnns.ecg.ann{numrhytmAnns+1} = ECGann;
                % sort the annotation struct
                [~,reIdx]=sort([rhytmAnns.ecg.idx]);
                rhytmAnns.ecg.ann = rhytmAnns.ecg.ann(reIdx);
                rhytmAnns.ecg.idx = rhytmAnns.ecg.idx(reIdx);
            end
        end
    end
end

function [gS,eventMarkers] = addEventMarker(timePoint,xAxisTimeStamps,timeBase,gS,eventMarkers,hEventMarkerDescription,hEventListBox,hButtonEventMarkerSave,editColorGreen,sampleRateFactor)
    accelIndex = getAccelIndexPoint(xAxisTimeStamps,timeBase,timePoint);
    if isempty(eventMarkers)
        numMarkers = 0;
    else
        numMarkers = size(eventMarkers,2);
    end
    eventMarkers(numMarkers+1).index = numMarkers+1;
    eventMarkers(numMarkers+1).description = hEventMarkerDescription.String;
    eventMarkers(numMarkers+1).serial = accelIndex;
    eventMarkers(numMarkers+1).eventid = char(java.util.UUID.randomUUID);
    hEventMarkerDescription.String = '';
    updateEventListbox(hEventListBox,eventMarkers,xAxisTimeStamps,timeBase,numMarkers+1);
    hButtonEventMarkerSave.BackgroundColor = editColorGreen;
end

function genECGkitReport(C3,conf,sampleRateFactor,indexStartECG,indexEndECG,xAxisTimeStamps,timeBase,reportIOmarkers,jsondata,hECGkitListBox,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,hECGkitMakePDFCheckbox,hECGkitOpenPDFCheckbox,full_path,fileFormat,bin_path)
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
        hea_fullpath = exportECGtoMITfiles(C3,conf,ecgRanges(ii,1),ecgRanges(ii,2),xAxisTimeStamps,timeBase,hAnalyseEcg1Checkbox,hAnalyseEcg2Checkbox,hAnalyseEcg3Checkbox,full_path,'displayed','ecgkit',fileFormat,jsondata,bin_path);
        [tmpPath, tmpName, ~] = fileparts(hea_fullpath);
        % Also export a new JSON file with the "start" field reflecting the
        % the start time of this segment, and a "reportnote" field added.
        timeStartOfThisSegment = datetime(addtodate(C3.date_start,jsonTimeOffsetMillisecs(ii),'millisecond'),'ConvertFrom','datenum','Format','yyyy-MM-dd''T''HH:mm:ss.SSS+0000','TimeZone','local');
        jsondata_temp.start = datestr(timeStartOfThisSegment,'yyyy-mm-ddTHH:MM:SS.FFF+0000');
        jsondata_temp.reportnote = jsonReportNotes{ii,1};
        % add a field indicating the ecg sample number of the original recording
        % that this segment starts from
        jsondata_temp.ecgsampleoffset = ecgRanges(ii,1);
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
        % Export c3events (events from BLE file only - not from JSON).
        % Offset serial index to match the exported segment.
        eventCounterDiff = diff(C3.eventCounter);
        eventIndices = find(eventCounterDiff > 0);
        % Trim events that are less than 3 seconds apart.
        eventIndices = trimEvents(eventIndices, sampleRateFactor);
        % C3events in the segment being exported for analysis.
        % Original index numbers offset by -accelStartIdx, to align with occurence in the segment.
        eventsInSegment = eventIndices(eventIndices > accelStartIdx & eventIndices < accelEndIdx) - accelStartIdx + 1;
        fid = fopen(fullfile(tmpPath,[tmpName '_c3events.txt']),'w');
        fprintf(fid,'%d\n',eventsInSegment');
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

%function for trimming number of events displayed from the BLE-file (only 24bit)
function eventIndices = trimEvents(eventIndices, sampleRateFactor)
    if ~isempty(eventIndices)
        % Minimum difference between events, in seconds
        minDiffSecs = 3;
        % First event should always be accepted, hence the '[true;' part, which
        % also makes the length of the diff array match the length of the array being diff'ed.
        eventIndices = eventIndices([true; diff(eventIndices) > (250/sampleRateFactor.ECG)*minDiffSecs]);
    end
end

%function called when loading new sensor data. Fills jsondata.events into eventMarkers.
function eventMarkers = initializeEventMarkersFromBLE(C3,eventMarkers,sampleRateFactor)
    eventIndices = find(diff(C3.eventCounter) > 0);
    eventIndices = trimEvents(eventIndices, sampleRateFactor);
    idxOffset = length(eventMarkers);
    for ii=1:length(eventIndices)
        eventMarkers(ii+idxOffset).index = ii+idxOffset;
        eventMarkers(ii+idxOffset).serial = eventIndices(ii);
        eventMarkers(ii+idxOffset).description = ['C3 button press #' num2str(ii)];
        eventMarkers(ii+idxOffset).eventid = 'BLE'; %char(java.util.UUID.randomUUID);
    end
end

%function called when loading new sensor data. Fills jsondata.events into eventMarkers.
function eventMarkers = initializeEventMarkersFromJson(jsondata,eventMarkers)
    if isfield(jsondata,'events') && ~isempty(jsondata.events)
        idxOffset = length(eventMarkers);
        for ii=1:size(jsondata.events,2)
            eventMarkers(ii+idxOffset).index = ii+idxOffset;
            eventMarkers(ii+idxOffset).serial = jsondata.events{1,ii}.serial;
            eventMarkers(ii+idxOffset).description = jsondata.events{1,ii}.eventname;
            eventMarkers(ii+idxOffset).eventid = jsondata.events{1,ii}.eventid;
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

function rhytmAnns = loadRhythmAnnotations(C3,full_path,rhytmAnns,hECGrhythmAnnCheckbox)
    [file_path,file_name,~] = fileparts(full_path);
    % look for .atr file with same name as the .BLE
    annFileExist = false; heaFileExist = false;
    if exist(fullfile(file_path,[file_name '.atr']), 'file') == 2
        annFileExist = true;
        % rdann needs a .hea-file in order to proceed with reading the .atr-file
        if exist(fullfile(file_path,[file_name '.hea']), 'file') == 2
            heaFileExist = true;
        end
    end
    if annFileExist && ~heaFileExist
        msgbox(sprintf('No header file (.hea) was found to match the annotation file (.atr)\n\nA simplified header file has been created.'),'No header file!','modal');
        userResponse = 'OK';
        if strcmp(userResponse,'OK')
            fidHea = fopen(fullfile(file_path,[file_name '.hea']),'w');
            fprintf(fidHea,'%s %d %d %d\r\n',file_name, 0, C3.ecg.fs, 0);
            fclose(fidHea);
            heaFileExist = true;
        end
    end
    if annFileExist && heaFileExist
        % now read the annotation file
        dirOrg = cd(file_path);
        [ann,~,~,~,~,comments] = rdann(file_name, 'atr');
        if max(ann) > length(C3.ecg.data)
            wanrdlg(sprintf('Annotation mismatch!\n\nAnnotations in the .atr-file exceed the length of this recording.\n\nNo annotations were loaded.'),'Warning');
        else
            rhytmAnns.ecg.idx = ann;
            rhytmAnns.ecg.ann = comments;
        end
        cd(dirOrg);
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

function fftEcgNewWindow(C3,startIndex,endIndex,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hImageRes,hOptPlotRangeButtonGroup,gS,full_path)
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
%             hAx.XTick = hAx.XLim(1):10:hAx.XLim(2);
            if saveImages
                imgTitleStr = ['FFT ECG' num2str(ii) ' ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'ECG')];
                imgRes = getGT0IntVal(hImageRes);
                if imgRes > 29 && imgRes < 301
                    resStr = sprintf('-r%d', imgRes);
                    print(hFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng', resStr);
                else
                    warndlg('Image resolution should be between 30 and 300 ppi!');
                end
            end
        end
    end
end

function accHistNewWindow(C3,startIndex,endIndex,xAxisTimeStamps,timeBase,hSaveImagesCheckbox,hImageRes,hSaveTextCheckbox,hOptPlotRangeButtonGroup,gS,hAccMagHistBinCount,hAccMagHistXLimMin,hAccMagHistXLimMax,hAccXYZHistBinCount,hAccXYZHistXLimMin,hAccXYZHistXLimMax,full_path,jsondata)
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
        histAccMag = histogram(C3.accelmag.data(startIndex:endIndex), binEdgesMag, 'Normalization', 'probability', 'FaceColor', 'k','EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxMag);
        histAccX = histogram(C3.accel.data(startIndex:endIndex,1), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', 'r', 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxX);
        histAccY = histogram(C3.accel.data(startIndex:endIndex,2), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', [0 0.75 0], 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxY);
        histAccZ = histogram(C3.accel.data(startIndex:endIndex,3), binEdgesXYZ, 'Normalization', 'probability', 'FaceColor', 'b', 'EdgeColor', [1 1 1], 'FaceAlpha', 1, 'Parent', hAxZ);
        hAxMag.XLim = [xLimMinMag xLimMaxMag];
        hAxX.XLim = [xLimMinXYZ xLimMaxXYZ];
        hAxY.XLim = [xLimMinXYZ xLimMaxXYZ];
        hAxZ.XLim = [xLimMinXYZ xLimMaxXYZ];
        % Setting the YLim just a bit lower than 0, to avoid that the bar edges
        % overlay the bottom x-axis.
%         yMinMagLim = -(hAxMag.YLim(2) / 300.0);
        hAxMag.YLim = [-0.003 1]; % [yMinMagLim hAxMag.YLim(2)];
%         yMinXLim = -(hAxX.YLim(2) / 300.0);
        hAxX.YLim = [-0.003 1];
%         yMinYLim = -(hAxY.YLim(2) / 300.0);
        hAxY.YLim = [-0.003 1];
%         yMinZLim = -(hAxZ.YLim(2) / 300.0);
        hAxZ.YLim = [-0.003 1];
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
        if hSaveImagesCheckbox.Value || hSaveTextCheckbox.Value
            [source_path,~,~] = fileparts(full_path);
            imgFiles_path = [source_path filesep 'Images - Accel hist'];
            if ~exist(imgFiles_path,'dir')
                mkdir(imgFiles_path);
            end
        end
        if hSaveImagesCheckbox.Value
            imgTitleStr = ['Accel hist ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'Accel')];
            imgRes = getGT0IntVal(hImageRes);
            if imgRes > 29 && imgRes < 301
                resStr = sprintf('-r%d', imgRes);
                print(hFig,[imgFiles_path filesep imgTitleStr '.png'],'-dpng', resStr);
            else
                warndlg('Image resolution should be between 30 and 300 ppi!');
            end
        end
        if hSaveTextCheckbox.Value
            % Mag
            txtTitleStr = ['Accel Mag hist ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'Accel')];
            fid = fopen([imgFiles_path filesep txtTitleStr '.txt'],'w');
            fprintf(fid,'%s\n%s\n',full_path,txtTitleStr);
            fprintf(fid,'Bin limits: [%f %f], Num bins: %d, Bin width: %f, Normalization: %s\n',histAccMag.BinLimits(1),histAccMag.BinLimits(2),histAccMag.NumBins,histAccMag.BinWidth,histAccMag.Normalization);
            fprintf(fid,'Bin values, Magnitude:\n');
            fprintf(fid,'%f\n',(histAccMag.Values)');
            fclose(fid);
            % XYZ
            txtTitleStr = ['Accel XYZ hist ' getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'Accel')];
            fid = fopen([imgFiles_path filesep txtTitleStr '.txt'],'w');
            fprintf(fid,'%s\n%s\n',full_path,txtTitleStr);
            fprintf(fid,'Bin limits: [%f %f], Num bins: %d, Bin width: %f, Normalization: %s\n',histAccX.BinLimits(1),histAccX.BinLimits(2),histAccX.NumBins,histAccX.BinWidth,histAccX.Normalization);
            fprintf(fid,'Bin values, X Y Z:\n');
            fprintf(fid,'%f %f %f\n',[(histAccX.Values)', (histAccY.Values)', (histAccZ.Values)']');
            fclose(fid);
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
        floatVal = [];
        if ~all(ismember(hEdit.String, '1234567890.,-'))
            warndlg(sprintf('Numerical input is required!'));
        elseif sum(ismember(hEdit.String, ',')) > 0
            warndlg(sprintf('Please use . (dot) for decimal mark.'));
        end
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

function intVal = getPosIntVal(hEdit)
    if all(ismember(hEdit.String, '1234567890'))
        if isempty(hEdit.String)
            intVal = [];
            warndlg('Integer input is required, and values must be positive!');
        else
            intVal = str2double(hEdit.String);
        end
    else
        intVal = [];
        warndlg('Integer input is required, and values must be positive!');
    end
end

function intVal = getGT0IntVal(hEdit)
    if all(ismember(hEdit.String, '1234567890'))
        if isempty(hEdit.String)
            intVal = [];
            return;
        else
            intVal = str2double(hEdit.String);
            if intVal == 0
                intVal = [];
                warndlg('Value must be greater than zero!');
                return;
            end
        end
    else
        warndlg('Integer input is required, and value must be greater than zero!');
    end
end

function cL = getClassLabel(classPopupValue)
    if classPopupValue == 1
        cL = '';
    elseif classPopupValue == 2
        cL = 'N';
    elseif classPopupValue == 3
        cL = 'V';
    elseif classPopupValue == 4
        cL = 'S';
    elseif classPopupValue == 5
        cL = 'F';
    elseif classPopupValue == 6
        cL = 'U';
    elseif classPopupValue == 7
        cL = '|';
    end
end

function clearStrings(varargin)
    for ii=1:length(varargin)
        set(varargin{ii},'String','');
    end
end

function unitsPerMv = getUnitsPerMillivolt(conf,fileFormat)
    % C3 ecg data is 3495.253 units pr millivolt, for 24bit at gain 1,
    % and 5243 units pr millivolt, for 16bit.
    if ~isempty(conf) && strcmp(fileFormat,'BLE 24bit')
        c3ecgGain = c3_getEcgGain(conf);
        unitsPerMv = c3_getUnitsPerMillivolt(fileFormat,c3ecgGain);
    % default 16bit
    else
        unitsPerMv = 5243.0;
    end
end

function [jsondata, Cancelled] = createNewJSON(C3,full_path,fileFormat)
    jsondata = [];
    startYear = datestr(C3.date_start,'yyyy');
    startMonth = datestr(C3.date_start,'mm');
    startDay = datestr(C3.date_start,'dd');
    startHour = datestr(C3.date_start,'HH');
    startMinute = datestr(C3.date_start,'MM');
    startSecond = datestr(C3.date_start,'SS');
    startMillisecond = datestr(C3.date_start,'FFF');
    startUTCoffset = '+0200'; %datetime('now','TimeZone','local','Format','Z'); % t1.TimeZone
    
    % SETTING DIALOG OPTIONS
    Title = 'Enter recording info';
    Options.WindowStyle = 'modal';
    Options.Resize = 'on';
    Options.Interpreter = 'tex';
    Options.CancelButton = 'on';
    Options.ApplyButton = 'off';
    Options.ButtonNames = {'Continue','Cancel'};

    Prompt = {};
    Formats = {};
    DefAns = struct([]);

    Prompt(1,:) = {'Recording start:',[],[]};
    Formats(1,1).type = 'text';
    Formats(1,1).size = [-1 -1];
    Formats(1,1).span = [1 4]; % item is 1 field x 4 fields

    Prompt(end+1,:) = {'Year', 'year',[]};
    Formats(2,1).type = 'edit';
    Formats(2,1).format = 'integer';
    Formats(2,2).limits = [1970 2999]; % 4-digits (positive #)
    Formats(2,1).size = [-1 -1]; % automatically assign the height
    Formats(2,1).labelloc = 'topleft';
    DefAns(1).year = str2double(startYear);

    Prompt(end+1,:) = {'Month', 'month',[]};
    Formats(2,2).type = 'edit';
    Formats(2,2).format = 'integer';
    Formats(2,2).limits = [1 12]; % 2-digits (positive #)
    Formats(2,2).size = [-1 -1];
    Formats(2,2).labelloc = 'topleft';
    DefAns.month = str2double(startMonth);

    Prompt(end+1,:) = {'Day', 'day',[]};
    Formats(2,3).type = 'edit';
    Formats(2,3).format = 'integer';
    Formats(2,3).limits = [1 31]; % 2-digits (positive #)
    Formats(2,3).size = [-1 -1];
    Formats(2,3).labelloc = 'topleft';
    DefAns.day = str2double(startDay);

    Prompt(end+1,:) = {'Hour (0 - 23)', 'hour',[]};
    Formats(3,1).type = 'edit';
    Formats(3,1).format = 'integer';
    Formats(3,2).limits = [0 23]; % 2-digits (positive #)
    Formats(3,1).size = [-1 -1]; % automatically assign the height
    Formats(3,1).labelloc = 'topleft';
    DefAns(1).hour = str2double(startHour);

    Prompt(end+1,:) = {'Minute', 'minute',[]};
    Formats(3,2).type = 'edit';
    Formats(3,2).format = 'integer';
    Formats(3,2).limits = [0 59]; % 2-digits (positive #)
    Formats(3,2).size = [-1 -1];
    Formats(3,2).labelloc = 'topleft';
    DefAns.minute = str2double(startMinute);

    Prompt(end+1,:) = {'Second', 'second',[]};
    Formats(3,3).type = 'edit';
    Formats(3,3).format = 'integer';
    Formats(3,3).limits = [0 59]; % 2-digits (positive #)
    Formats(3,3).size = [-1 -1];
    Formats(3,3).labelloc = 'topleft';
    DefAns.second = str2double(startSecond);

    Prompt(end+1,:) = {'Millisecond', 'millisecond',[]};
    Formats(3,4).type = 'edit';
    Formats(3,4).format = 'integer';
    Formats(3,4).limits = [0 999]; % 3-digits (positive #)
    Formats(3,4).size = [-1 -1];
    Formats(3,4).labelloc = 'topleft';
    DefAns.millisecond = str2double(startMillisecond);

    Prompt(end+1,:) = {'     ',[],[]};
    Formats(3,5).type = 'text';
    Formats(3,5).size = [-1 -1];
    Formats(3,5).span = [1 1];

    Prompt(end+1,:) = {'',[],[]};
    Formats(4,1).type = 'text';
    Formats(4,1).size = [-1 0];
    Formats(4,1).span = [1 4];

    Prompt(end+1,:) = {'Patient information:',[],[]};
    Formats(5,1).type = 'text';
    Formats(5,1).size = [-1 -1];
    Formats(5,1).span = [1 4];

    Prompt(end+1,:) = {'Patient ID', 'patientid',[]};
    Formats(6,1).type = 'edit';
    Formats(6,1).format = 'text';
    Formats(6,1).size = [-1 -1];
    Formats(6,1).labelloc = 'topleft';
    DefAns.patientid = '';

    Prompt(end+1,:) = {'Patient Name', 'patientname',[]};
    Formats(6,2).type = 'edit';
    Formats(6,2).format = 'text';
    Formats(6,2).size = [-1 -1];
    Formats(6,2).span = [1 1]; 
    Formats(6,2).labelloc = 'topleft';
    DefAns.patientname = '';

    Prompt(end+1,:) = {'Patient Age', 'patientage',[]};
    Formats(6,3).type = 'edit';
    Formats(6,3).format = 'integer';
    Formats(6,3).limits = [0 999]; % 3-digits (positive #)
    Formats(6,3).size = 50;
    Formats(6,3).labelloc = 'topleft';

    Prompt(end+1,:) = {'Gender', 'gender',[]};
    Formats(7,1).type = 'list';
    Formats(7,1).format = 'text';
    Formats(7,1).style = 'radiobutton';
    Formats(7,1).items = {'Not specified' 'F' 'M' };
    Formats(7,1).labelloc = 'topleft';
    Formats(7,1).span = [1 1];
    DefAns.gender = 'Not specified';

    Prompt(end+1,:) = {'',[],[]};
    Formats(8,1).type = 'text';
    Formats(8,1).size = [-1 0];
    Formats(8,1).span = [1 4];

    Prompt(end+1,:) = {'C3 device information:',[],[]};
    Formats(9,1).type = 'text';
    Formats(9,1).size = [-1 -1];
    Formats(9,1).span = [1 4];

    Prompt(end+1,:) = {'C3 ID', 'deviceid',[]};
    Formats(10,1).type = 'edit';
    Formats(10,1).format = 'text';
    Formats(10,1).size = [-1 -1];
    Formats(10,1).labelloc = 'topleft';
    DefAns.deviceid = 'C3-';

    Prompt(end+1,:) = {'C3 Firmware', 'fw',[]};
    Formats(10,2).type = 'edit';
    Formats(10,2).format = 'text';
    Formats(10,2).size = [-1 -1];
    Formats(10,2).labelloc = 'topleft';
    DefAns.fw = '';

    Prompt(end+1,:) = {'C3 Hardware', 'hw',[]};
    Formats(10,3).type = 'list';
    Formats(10,3).format = 'text';
    Formats(10,3).style = 'radiobutton';
    Formats(10,3).items = {'Not specified' 'B5' 'B6' 'B7' 'B8'};
    Formats(10,3).labelloc = 'topleft';
    Formats(10,3).span = [1 2];
    DefAns.hw = 'Not specified';

    Prompt(end+1,:) = {'ECG Gain', 'ecggain',[]};
    Formats(11,1).type = 'list';
    Formats(11,1).format = 'text';
    Formats(11,1).style = 'radiobutton';
    Formats(11,1).items = {'Not specified' '1' '2' '3' '4' '6' '8' '12'};
    Formats(11,1).span = [1 2];
    Formats(11,1).labelloc = 'topleft';
    DefAns.ecggain = 'Not specified';

    Prompt(end+1,:) = {'Sampling Rate', 'samplingrate',[]};
    Formats(11,3).type = 'list';
    Formats(11,3).format = 'text';
    Formats(11,3).style = 'radiobutton';
    Formats(11,3).items = {'250 Hz'};
    Formats(11,3).span = [1 1];
    Formats(11,3).labelloc = 'topleft';
    DefAns.samplingrate = '250 Hz';


    Prompt(end+1,:) = {'',[],[]};
    Formats(12,1).type = 'text';
    Formats(12,1).size = [-1 -1];

    Prompt(end+1,:) = {'',[],[]};
    Formats(13,1).type = 'text';
    Formats(13,1).size = [-1 -1];

    [Answer,Cancelled] = inputsdlg(Prompt,Title,Formats,DefAns,Options);

    if ~Cancelled
        if strcmp(Answer.patientid,'')
            Answer.patientid = 'Not specified';
        end
        if strcmp(Answer.patientname,'')
            Answer.patientname = 'Not specified';
        end
        if isempty(Answer.patientage)
            Answer.patientage = 'Not specified';
        end
        jsondata.start = sprintf('%04d-%02d-%02dT%02d:%02d:%02d.%03d%s',Answer.year,Answer.month,Answer.day,Answer.hour,Answer.minute,Answer.second,Answer.millisecond,startUTCoffset);
        jsondata.patientid = Answer.patientid;
        jsondata.patienname = Answer.patientname;
        jsondata.patientage = Answer.patientage;
        jsondata.gender = Answer.gender;
        jsondata.deviceid = Answer.deviceid;
        jsondata.softwareversion = Answer.fw;
        jsondata.hardwareversion = Answer.hw;
        jsondata.ecggain = Answer.ecggain;
        jsondata.samplingrate = 250;
        [file_path,filename_wo_extension,~] = fileparts(full_path);
        json_fullpath = fullfile(file_path,[filename_wo_extension '.json']);
        savejson('',jsondata,'FileName',json_fullpath,'ParseLogical',1);
    end
end

function classCountInfoUpdate(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact,cS)
    countN = length(find(cS.anntyp == 'N'));
    countS = length(find(cS.anntyp == 'S'));
    countV = length(find(cS.anntyp == 'V'));
    countF = length(find(cS.anntyp == 'F'));
    countU = length(find(cS.anntyp == 'U'));
    countArtefact = length(find(cS.anntyp == '|'));
    set(hClassCountN,'String',num2str(countN));
    set(hClassCountS,'String',num2str(countS));
    set(hClassCountV,'String',num2str(countV));
    set(hClassCountF,'String',num2str(countF));
    set(hClassCountU,'String',num2str(countU));
    set(hClassCountArtefact,'String',num2str(countArtefact));
end

function classCountInfoReset(hClassCountN,hClassCountS,hClassCountV,hClassCountF,hClassCountU,hClassCountArtefact)
    set(hClassCountN,'String','');
    set(hClassCountS,'String','');
    set(hClassCountV,'String','');
    set(hClassCountF,'String','');
    set(hClassCountU,'String','');
    set(hClassCountArtefact,'String','');
end

function choiceECGann = dialogAnnECG(precedingRhytmAnn)
    choiceECGann = '';
    
    % get screen size
    screenSize = get(0,'screensize');
    screenWidth = screenSize(3);
    screenHeight = screenSize(4);

    dHeight = 427;
    dWidth = 580;
    lWidth = dWidth - 20;
    hDialog = dialog('Position',[screenWidth*0.3 max(screenHeight-dHeight-50,20) dWidth dHeight],...
        'Name','Select Annotation','WindowStyle','normal'); %,'WindowStyle','normal'
    
    numBts = 15;
    ECGann = cell(1,numBts);
    annAbrev = cell(1,numBts);
    
    % horisontal divider line
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-22 lWidth 19],...
           'BackgroundColor',[0.5 0.5 0.5],...
           'String','');
       
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',10,...
           'FontWeight','bold',...
           'HorizontalAlignment','left',...
           'Position',[13 dHeight-21 160 17],...
           'BackgroundColor',[0.5 0.5 0.5],...
           'ForegroundColor',[1 1 1],...
           'String','End of preceding rhythm');
    
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[185 dHeight-21 370 14],...
           'BackgroundColor',[0.5 0.5 0.5],...
           'ForegroundColor',[1 1 1],...
           'String','Use only if you are not indicating the start of a new rhytm');
       
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','right',...
           'Position',[95 dHeight-68 100 20],...
           'String','End of:');
       
    idx = 1; ECGann{idx} = precedingRhytmAnn;
    hBtEndPrecRhy = uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-63 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
    if isempty(precedingRhytmAnn)
        hBtEndPrecRhy.Enable = 'off';
    end
    
    % horisontal divider line
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-108 lWidth 19],...
           'BackgroundColor',[0.5 0.5 0.5],...
           'String','');
       
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',10,...
           'FontWeight','bold',...
           'HorizontalAlignment','left',...
           'Position',[13 dHeight-107 lWidth-6 17],...
           'BackgroundColor',[0.5 0.5 0.5],...
           'ForegroundColor',[1 1 1],...
           'String','Start of new rhythm');
    
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-137 200 20],...
           'String','Tachycardia');

    idx = idx+1; ECGann{idx} = 'Atrial fibrillation'; annAbrev{idx} = 'AFIB';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-167 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});

    idx = idx+1; ECGann{idx} = 'Atrial flutter'; annAbrev{idx} = 'AFL';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-167 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});

    idx = idx+1; ECGann{idx} = 'Supraventricular tachycardia'; annAbrev{idx} = 'SVTA';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-167 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});

    idx = idx+1; ECGann{idx} = 'Monomorphic VT'; annAbrev{idx} = 'MVT';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-207 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    idx = idx+1; ECGann{idx} = 'Polymorphic VT'; annAbrev{idx} = 'PVT';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-207 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    idx = idx+1; ECGann{idx} = 'Wide-complex tachycardia of uncertain type'; annAbrev{idx} = 'WCTU';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-207 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});      
       
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-257 200 20],...
           'String','Bradycardia');
       
    idx = idx+1; ECGann{idx} = 'Sinus Bradycardia'; annAbrev{idx} = 'SBR';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-287 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    idx = idx+1; ECGann{idx} = 'First-degree AV block'; annAbrev{idx} = 'BI';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-287 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});

    idx = idx+1; ECGann{idx} = 'Second-degree AV block'; annAbrev{idx} = 'BII';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-287 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    idx = idx+1; ECGann{idx} = 'Wenckenbach/Mobitz I'; annAbrev{idx} = 'WEMOI';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-327 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    idx = idx+1; ECGann{idx} = 'Mobitz II'; annAbrev{idx} = 'MOII';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-327 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});

    idx = idx+1; ECGann{idx} = '3rd-degree AV block complete block'; annAbrev{idx} = 'BIII';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-327 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-377 200 20],...
           'String','Other');
       
    idx = idx+1; ECGann{idx} = 'Noise'; annAbrev{idx} = 'NOISE';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-407 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    hTxtEdit = uicontrol('Parent',hDialog,...
           'Style','edit',...
           'FontSize',10,...
           'HorizontalAlignment','left',...
           'String','Custom annotation',...
           'Position',[255 dHeight-407 125 30],...
           'Callback',@txtEditCallback);
       
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-407 50 30],...
           'FontSize',10,...
           'String','Use:',...
           'Callback',{@customBtnCallback,hTxtEdit,hDialog});

    idx = idx+1; ECGann{idx} = 'Normal Rhythm'; annAbrev{idx} = 'N';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-407 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,idx,ECGann{idx},hDialog});
       
    % Wait for hDialog to close before running to completion
    uiwait(hDialog);
   
    function btnCallback(~,~,idx,annStr,hDialog)
        if idx == 1
            annStr(1) = [];
            annStr = [annStr ')'];
        else
            annStr = ['(' annAbrev{idx}];
        end
        choiceECGann = annStr;
        delete(hDialog);
    end

    function customBtnCallback(~,~,hTxtEdit,hDialog)
      choiceECGann = ['(' hTxtEdit.String];
      delete(hDialog);
    end

    function txtEditCallback(hTxtEdit,~)
      choiceECGann = ['(' hTxtEdit.String];
      delete(hDialog);
    end
end

function choiceClassAnn = dialogAnnClass()
    choiceClassAnn = '';
    
    % get screen size
    screenSize = get(0,'screensize');
    screenWidth = screenSize(3);
    screenHeight = screenSize(4);

    dHeight = 200;
    hDialog = dialog('Position',[screenWidth*0.3 max(screenHeight-400,20) 580 dHeight],...
        'Name','Select Beat Class Annotation');
    
    uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-30 400 20],...
           'String','Choose one common annotation for selected beats');
    
    idx = 1; ECGann{idx} = 'N (Normal beats)';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-60 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'N',hDialog});
       
    idx = idx+1; ECGann{idx} = 'S (Supraventricular)';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-60 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'S',hDialog});
       
    idx = idx+1; ECGann{idx} = 'V (Ventricular premature)';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-60 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'V',hDialog});
       
    idx = idx+1; ECGann{idx} = 'F (Fusion of ventricular and normal)';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-100 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'F',hDialog});
       
    idx = idx+1; ECGann{idx} = 'U (Unclassifiable)';
    uicontrol('Parent',hDialog,...
           'Position',[200 dHeight-100 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'U',hDialog});
       
    idx = idx+1; ECGann{idx} = '| (Isolated QRS-like artifact)';
    uicontrol('Parent',hDialog,...
           'Position',[390 dHeight-100 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'|',hDialog});      

       uicontrol('Parent',hDialog,...
           'Style','text',...
           'FontSize',8,...
           'HorizontalAlignment','left',...
           'Position',[10 dHeight-150 400 20],...
           'String','Or, Delete all currently selected beat annotations');

    idx = idx+1; ECGann{idx} = 'Delete';
    uicontrol('Parent',hDialog,...
           'Position',[10 dHeight-180 180 30],...
           'FontSize',10,...
           'String',ECGann{idx},...
           'Callback',{@btnCallback,'-',hDialog});
       
    % Wait for hDialog to close before running to completion
    uiwait(hDialog);
   
    function btnCallback(~,~,annStr,hDialog)
      choiceClassAnn = annStr;
      delete(hDialog);
    end
end

function gS = deselectEventMarkerMode(hButtonEventMarkerAddToggle,hEventMarkerDescription,gS,panelColor,editColor)
    gS.eventMarkerMode = false;
    hButtonEventMarkerAddToggle.Value = 0;
    hButtonEventMarkerAddToggle.String = 'Off';
    hButtonEventMarkerAddToggle.BackgroundColor = panelColor;
    hEventMarkerDescription.BackgroundColor = editColor;
end

function [gS,reportIOmarkers] = deselectReportMarkerMode(hButtonECGkitMarkerAddToggle,hECGkitMarkerDescription,hButtonECGkitMarkerOut,hECGkitMarkerOutHrs,hECGkitMarkerOutMin,hECGkitMarkerOutSec,reportIOmarkers,gS,panelColor,editColor)
    gS.ecgMarkerMode = false;
    hButtonECGkitMarkerAddToggle.Value = 0;
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
end

function gS = deselectClassAnnDragSelMode(hBtnClassAnnSel,gS,panelColor)
    hBtnClassAnnSel.Value = 0;
    gS.classAnnDragSel = false;
    hBtnClassAnnSel.BackgroundColor = panelColor;
end

function [gS,rhytmAnns] = deselectRhythmSelClickMode(hButtonRhythmSelClick,rhytmAnns,gS,panelColor)
    hButtonRhythmSelClick.Value = 0;
    hButtonRhythmSelClick.BackgroundColor = panelColor;
    hButtonRhythmSelClick.String = 'Rhythm Annotation Mode';
    gS.rhythmAnnMode = 'none';
end

function ecgBrSaveImg(hECGbrowser,ecgBrChStr,xAxisTimeStamps,timeBase,startIndex,endIndex,full_path)
    [file_path,file_name,file_ext] = fileparts(full_path);
    image_path = fullfile(file_path,'Images - ECG Browser');
    if ~exist(image_path,'dir')
        [status,message,~] = mkdir(image_path);
    else
        status = true;
    end
    if status
        timeRangeStr = getRangeStrForFileName(xAxisTimeStamps,timeBase,startIndex,endIndex,'ECG');
        image_fullpath = fullfile(image_path,[file_name file_ext ' ' ecgBrChStr ' ' char(timeRangeStr) '.png']);
        print(hECGbrowser,image_fullpath,'-dpng','-r0');
    else
        warndlg(sprintf('Could not create folder ''Images - ECG Browser'' for image!\n\n%s',message));
    end
end


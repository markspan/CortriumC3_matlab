%% Load _ECG_delineation.mat file and calculate QRS_durations, etc.
% Create a pdf with ECG plots and stats.

function pdf_fullpath = ecgReportType1(jsondata, hea_fullpath)
    % QUESTION: Would there be a 'ECG_delineation_corrector' file if
    % GUIcorrection has been applied? Integrate, at some point?
    
    hTic_ecgReportType1 = tic;
    
    errorCorrection.RR_intervals = true;
    errorCorrection.ECG_amplitude = true;
    errorCorrection.Accel_amplitude = true;
    errorCorrection.ECG_noise = true;
    
%     errorCorrection.RR_intervals = false;
%     errorCorrection.ECG_amplitude = false;
%     errorCorrection.Accel_amplitude = false;
%     errorCorrection.ECG_noise = false;
    
    % get path of Cortrium Matlab scripts folder
    cortrium_matlab_scripts_root_path = getCortriumScriptsRoot;
    
    % pdf toolkit path
%     pdftk_exe = '"bin\pdftk.exe"';
    pdftk_exe = ['"' cortrium_matlab_scripts_root_path '\bin\pdftk.exe"'];
        
    [file_path,filename_wo_extension,~] = fileparts(hea_fullpath);
    
    % delStr is a cell array for full file paths to the individual pdf's,
    % which will be deleted once they have been merged into a single pdf.
    delStr = cell(1);
    
% check if jsondata is empty
if isempty(jsondata)
    jsondata.patientname = 'Not specified';
    jsondata.patientid  = 'Not specified';
    jsondata.gender = 'Not specified';
    jsondata.patientage = NaN;
    jsondata.my_user = 'c3_report'; %NOTE: 'my_user' is not currently (2016-02-09) a field of the app-generated JSON
    jsondata.filename = filename_wo_extension;
    jsondata.start = '0001-01-01T00:00:00.000+0000';
else
    if isfield(jsondata,'patientage')
        if ischar(jsondata.patientage)
            if ~isempty(str2double(jsondata.patientage))
                jsondata.patientage = str2double(jsondata.patientage);
            else
                jsondata.patientage = NaN;
            end
        end
    else
        jsondata.patientage = NaN;
    end
    if ~isfield(jsondata,'patientname')
        jsondata.patientname = 'Not specified';
    end
    if ~isfield(jsondata,'patientid')
        jsondata.patientid  = 'Not specified';
    end
    if ~isfield(jsondata,'gender')
        jsondata.gender  = 'Not specified';
    end
    if ~isfield(jsondata,'filename')
        jsondata.filename  = filename_wo_extension;
    end
    if ~isfield(jsondata,'start')
        jsondata.start = '0001-01-01T00:00:00.000+0000';
    end
    jsondata.my_user = 'c3_report'; %NOTE: 'my_user' is not currently (2016-02-09) a field of the app-generated JSON
end
    
    % read first line of header file, to get info about sampling frquency (fs) and number of samples.
    hea_fullpath = fullfile(file_path, [filename_wo_extension '.hea']);
    if exist(hea_fullpath, 'file') == 2
        hea_fid = fopen(hea_fullpath,'r');
        heaLine = fgetl(hea_fid);
        heaInfo = textscan(heaLine,'%s %d %d %d');
        numEcgChannels = heaInfo{2};
        fs = double(heaInfo{3});
        numSamples = heaInfo{4};
        % duration of recording, in seconds
        recordingDuration = double(numSamples)/fs;
        fclose(hea_fid);
    else
        error(['No header file at: ' hea_fullpath '\n']);
    end
    
    % load delineation file, if it exists
    % dS will be a struct containing the delineation data
    delineation_fullpath = fullfile(file_path, [filename_wo_extension '_ECG_delineation.mat']);
    if exist(delineation_fullpath, 'file') == 2
        dS = load(delineation_fullpath);
    else
        error(['No delineation file at: ' delineation_fullpath '\n']);
    end
    
    % load -physiobank.txt file to get the 3 ECG channels, and Respiration channel
    physbankdata_fullpath = fullfile(file_path, [filename_wo_extension '_physiobank.txt']);
    dat_fullpath = fullfile(file_path, [filename_wo_extension '.dat']);
    if exist(physbankdata_fullpath, 'file') == 2
        [ecgData, respData] = loadAndFormatPhysiobankData(physbankdata_fullpath);
        % NOTE: Error code values have already been replaced with NaN (Not a Number) to remove extreme peaks unrelated to actual ecg values.
    elseif exist(dat_fullpath, 'file') == 2
        ecgData = loadEcgFromMITdat(hea_fullpath, dat_fullpath);
        respData = [];
    else
        error(['No physiobank file at: ' physbankdata_fullpath '\n']);
    end
    
    % temporary fix to deal with reading from MIT db set
    if size(ecgData,2) == 1
        numRows = size(ecgData,1);
        ecgData(:,2:3) = nan(numRows,2);
    elseif size(ecgData,2) == 2
        numRows = size(ecgData,1);
        ecgData(:,3) = nan(numRows,1);
    elseif size(ecgData,2) > 3
        warndlg('More than 3 ECG channels!');
    end
    
    % load classification file, if it exists
    % cS will be a struct containing the classification data
    classification_fullpath = fullfile(file_path, [filename_wo_extension '_ECG_heartbeat_classifier.mat']);
    if exist(classification_fullpath, 'file') == 2
        cS = load(classification_fullpath);
    else
        cS = [];
        warning(['No classification file at: ' classification_fullpath '\n']);
    end
    
    % NOT USED CURRENTLY. load detection file, which contains series_quality.ratios values
    detection_fullpath = fullfile(file_path, [filename_wo_extension '_QRS_detection.mat']);
    if exist(detection_fullpath, 'file') == 2
        detectionStruct = load(detection_fullpath);
        fprintf('Series Quality Ratios: \n');
        for i=1:length(detectionStruct.series_quality.ratios)
            fprintf('series_quality.ratio %d = %f\n', i, detectionStruct.series_quality.ratios(i));
        end
        fprintf('\n');
    else
        warning(['No detection file at: ' detection_fullpath '\n']);
        detectionStruct = [];
    end
    
    % load _accelmag.txt file to get the acceleration magnitude data
    accelmag_fullpath = fullfile(file_path, [filename_wo_extension '_accelmag.txt']);
    if exist(accelmag_fullpath, 'file') == 2
        accelmag = loadAccelmag(accelmag_fullpath);
    else
        accelmag = [];
        warning(['No accelmag file at: ' accelmag_fullpath '\n']);
    end
    
    % load _c3events.txt file to get serial index numbers for events
    c3events_fullpath = fullfile(file_path, [filename_wo_extension '_c3events.txt']);
    if exist(c3events_fullpath, 'file') == 2
        c3events = loadC3events(c3events_fullpath);
    else
        c3events = [];
        warning(['No c3events file at: ' c3events_fullpath '\n']);
    end
    
    % load Cortrium logo image
    logo_cortrium_path = [cortrium_matlab_scripts_root_path '\bin\Cortrium_logo_w_pod_746x219px.png'];
    if exist(logo_cortrium_path, 'file') == 2
        [logoCortriumImgData.img, logoCortriumImgData.map, logoCortriumImgData.alpha] = imread(logo_cortrium_path);
    else
        warning(['No Cortrium logo file at: ' logo_cortrium_path]);
        logoCortriumImgData = [];
    end
    % load Cortrium logo image for the front page
    logo_cortrium_path = [cortrium_matlab_scripts_root_path '\bin\Cortrium_logo_w_pod_1404x437px.png'];
    if exist(logo_cortrium_path, 'file') == 2
        [logoCortriumFrontImgData.img, logoCortriumFrontImgData.map, logoCortriumFrontImgData.alpha] = imread(logo_cortrium_path);
    else
        warning(['No Cortrium logo file at: ' logo_cortrium_path]);
        logoCortriumFrontImgData = [];
    end
    
%% dS - a struct for all things related to the delineation file

    if ~isempty(dS)
        [dS, idxRRNaN, inSampleECGNaN, outSampleECGNaN, inSampleAccNaN, outSampleAccNaN, noisyQRSidx] = calculateDelineationStats(dS, recordingDuration, fs, ecgData, numEcgChannels, accelmag, jsondata, errorCorrection);
    end
    
%% cS - a struct for heartbeat classification data
    
    if ~isempty(cS)
        cS = calculateClassificationStats(cS, dS, recordingDuration, fs, errorCorrection, idxRRNaN, inSampleECGNaN, outSampleECGNaN, inSampleAccNaN, outSampleAccNaN, noisyQRSidx);
    end

%% Timestamps and other preperations

    % get start and end timestamps
    timestamps = getTimeStampsStartEnd(jsondata, recordingDuration, fs);
    
    % define some colors we can reuse
    cortriumColors.color1       = [0.000	0.447	0.741];
    cortriumColors.color2       = [0.500	0.802	1.000];
    cortriumColors.color3       = [0.000	0.700	0.300];
    cortriumColors.color4       = [0.950	0.000   0.950];
    cortriumColors.color5       = [0.950	0.450   0.000];
    cortriumColors.plotcolor1   = [0.800	0.000	0.100];
    cortriumColors.plotcolor2   = [0.000	0.800	0.100];
    cortriumColors.plotcolor3   = [0.000	0.447	0.741];
    cortriumColors.plotcolor4   = [1.000    0.680   0.100];

%%  %------- FRONT PAGE -------%

    % create an A4 page (figure)
    hFig_Page = createPageFig;
    
    % define some useful sizes and positions for plots and textboxes
    maxWidth = hFig_Page.PaperSize(1) - 2;
    maxPlotWidth = hFig_Page.PaperSize(1) - 3;
    halfTextWidth = maxWidth * 0.5;
    topOfPage = hFig_Page.PaperSize(2) - 2;
    midHeightOfPage = hFig_Page.PaperSize(2) * 0.5;
    
    % add front page elements... logo, id of patient, recording time info, HR stats
    objectPosition = [ 0 (topOfPage-2) maxWidth 0];
    addFrontPageElements(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumFrontImgData)
    
    % export front page to PDF
    pdf_fullPath_frontpage = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_p0.pdf']);
    print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullPath_frontpage); % -r0 = screen resolution, -r300 = 300 dpi
%     winopen(pdf_fullPath_frontpage);
    
    % close the (invisible) figure window
    close(hFig_Page);
    
    % add pdf full path to delStr
    delStr{1} = pdf_fullPath_frontpage;
    
%%  %------- PAGE 2 -------%
    
    % create an A4 page (figure)
    hFig_Page = createPageFig;
        
    % add header with logo, id of patient, recording time info
    objectPosition = [ 0 (topOfPage-1.35) maxWidth 1.0];
    addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    
    % add info about recording time
    objectPosition = [ 0 (topOfPage-3.1) halfTextWidth 1.5];
    addRecordingTimeText(hFig_Page, objectPosition, timestamps)
    
    % add stats text
    objectPosition = [ 0 (topOfPage-6.85) 9 3.5];
    addStatsText(hFig_Page, objectPosition, cS, dS)
    
     % add pie chart with heartbeat classifications
    objectPosition = [(maxPlotWidth-4.5), (topOfPage-7.6), 5.5, 6];
    plotHBCpiechart(hFig_Page, objectPosition, cS);
    
    % add RR interval histogram to the page
    objectPosition = [(maxPlotWidth-4.5), (topOfPage-13.75), 5.5, 6];
    plotRRhistogram(hFig_Page, objectPosition, dS);
    
    % add heart rate plot to the page
    objectPosition = [1 , (midHeightOfPage-4.5), maxPlotWidth-0.75, 3];
    plotHR(hFig_Page, objectPosition, dS, timestamps, cortriumColors);
    
    % add Ventricular beat plot to the page
    objectPosition = [1 , (midHeightOfPage-9.25), maxPlotWidth-0.75, 3];
    plotVEB(hFig_Page, objectPosition, cS, dS, timestamps, cortriumColors);
    
    % add Supraventricular beat plot to the page
    objectPosition = [1 , (midHeightOfPage-14), maxPlotWidth-0.75, 3];
    plotSVEB(hFig_Page, objectPosition, cS, dS, timestamps, cortriumColors);
        
    % export page 2 to PDF
    pdf_fullPath_page2 = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_p2.pdf']);
    print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullPath_page2); % -r0 = screen resolution, -r300 = 300 dpi
%     winopen(pdf_fullPath_page2);
    
    % close the (invisible) figure window
    close(hFig_Page);
    
    % add pdf full path to delStr
    delStr{2} = pdf_fullPath_page2;
    
%%  %------- PAGE 4 -------%
     
    % create an A4 page (figure)
    hFig_Page = createPageFig;
    
    % add header with logo, id of patient, recording time info
    objectPosition = [ 0 (topOfPage-1.35) maxWidth 1.0];
    addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)

    % add title "Full Sized Strips" to page
    objectPosition = [ 0 (topOfPage-2.1) maxWidth 0.4];
    addTitleFullSizeStrips(hFig_Page, objectPosition);

    % add full-sized strip of VPB
    objectPosition = [0 , (topOfPage-10.25), maxWidth, 8];
    plotStrip_VPB(hFig_Page, objectPosition, cS, dS, ecgData, fs, timestamps, jsondata, cortriumColors);
    
    % add full-sized strip of SVPB
    objectPosition = [0 , (topOfPage-18.45), maxWidth, 8];
    plotStrip_SVPB(hFig_Page, objectPosition, cS, dS, ecgData, fs, timestamps, jsondata, cortriumColors);
    
    % add full-sized strip of minimum HR to the page
    objectPosition = [0 , (topOfPage-26.65), maxWidth, 8];
    plotStrip_MinHR(hFig_Page, objectPosition, dS, ecgData, timestamps, jsondata, cortriumColors);
    
    % export page 4 to PDF
    pdf_fullPath_page4 = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_p4.pdf']);
    print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullPath_page4); % -r0 = screen resolution, -r300 = 300 dpi
%     winopen(pdf_fullPath_page4);

    % close the (invisible) figure window
    close(hFig_Page);
    
    % add pdf full path to delStr
    delStr{3} = pdf_fullPath_page4;
        
%%  %------- PAGE 5 -------%
     
    % create an A4 page (figure)
    hFig_Page = createPageFig;
    
    % add header with logo, id of patient, recording time info
    objectPosition = [ 0 (topOfPage-1.35) maxWidth 1.0];
    addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    
    % add title "Full Sized Strips" to page
    objectPosition = [ 0 (topOfPage-2.1) maxWidth 0.4];
    addTitleFullSizeStrips(hFig_Page, objectPosition);
    
    % add full-sized strip of maximum RR-interval to the page
    objectPosition = [0 , (topOfPage-10.25), maxWidth, 8];
    plotStrip_MaxRR(hFig_Page, objectPosition, dS, ecgData, fs, timestamps, jsondata, cortriumColors);
    
    % add full-sized strip of minimum RR-interval to the page
    objectPosition = [0 , (topOfPage-18.45), maxWidth, 8];
    plotStrip_MinRR(hFig_Page, objectPosition, dS, ecgData, fs, timestamps, jsondata, cortriumColors);
    
    % add full-sized strip of maximum HR to the page
    objectPosition = [0 , (topOfPage-26.65), maxWidth, 8];
    plotStrip_MaxHR(hFig_Page, objectPosition, dS, ecgData, timestamps, jsondata, cortriumColors);
    
    % export page 5 to PDF
    pdf_fullPath_page5 = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_p5.pdf']);
    print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullPath_page5); % -r0 = screen resolution, -r300 = 300 dpi
%     winopen(pdf_fullPath_page5);

    % close the (invisible) figure window
    close(hFig_Page);
    
    % add pdf full path to delStr
    delStr{4} = pdf_fullPath_page5;
    
%%  %------- PAGE 6 -------%
    
    % create an A4 page (figure)
    hFig_Page = createPageFig;
        
    % add header with logo, id of patient, recording time info
    objectPosition = [ 0 (topOfPage-1.35) maxWidth 1.0];
    addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    
    % add panel with HRV Time Domain Summary
    objectPosition = [ 0 (topOfPage-3.25) maxWidth 1.75];
    addHRVsummary(hFig_Page, objectPosition, cS);
    
    % add Poincare plot, Total Beats
    objectPosition = [0, (topOfPage-8.5), 4.5, 5];
    plotPoincareTotal(hFig_Page, objectPosition, dS);
    
    % add Poincare plot, Normal Beats
    objectPosition = [4.83, (topOfPage-8.5), 4.5, 5];
    plotPoincareNormal(hFig_Page, objectPosition, cS, dS);
    
    % add Poincare plot, Ventricular Beats
    objectPosition = [9.66, (topOfPage-8.5), 4.5, 5];
    plotPoincareVentricular(hFig_Page, objectPosition, cS, dS);
    
    % add Poincare plot, Supraventricular Beats
    objectPosition = [14.5, (topOfPage-8.5), 4.5, 5];
    plotPoincareSupraventricular(hFig_Page, objectPosition, cS, dS);
    
    % add heart rate plot to the page
    objectPosition = [1 , (topOfPage-12.5), maxPlotWidth-0.75, 3];
    plotHR(hFig_Page, objectPosition, dS, timestamps, cortriumColors);
    
    % add SDNN and SDSD plot to the page
    objectPosition = [1 , (topOfPage-17.25), maxPlotWidth-0.75, 3];
    plotSDNN_SDSD(hFig_Page, objectPosition, cS, timestamps, cortriumColors);
    
    % add NN50# and pNN50% plot to the page
    objectPosition = [1 , (topOfPage-22), maxPlotWidth-0.75, 3];
    plotNN50_pNN50(hFig_Page, objectPosition, cS, timestamps, cortriumColors);
    
    % add RR interval mean, and Proc Time plot to the page
    objectPosition = [1 , (topOfPage-26.75), maxPlotWidth-0.75, 3];
    plotRRmean_ProcTime(hFig_Page, objectPosition, dS, timestamps, cortriumColors);
    
    % export page 6 to PDF
    pdf_fullPath_page6 = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_p6.pdf']);
    print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullPath_page6); % -r0 = screen resolution, -r300 = 300 dpi
%     winopen(pdf_fullPath_page6);

    % close the (invisible) figure window
    close(hFig_Page);
    
    % add pdf full path to delStr
    delStr{5} = pdf_fullPath_page6;
    
%%  %------- MERGE PAGES -------%
    
    % merge PDF pages
    pdf_fullpath = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '.pdf']);
    cmdStr = [pdftk_exe ' "' pdf_fullPath_frontpage '" "' pdf_fullPath_page2 '" "' pdf_fullPath_page4 '" "' pdf_fullPath_page5 '" "' pdf_fullPath_page6 '" cat output "' pdf_fullpath];
    
    % merge PDF pages
    [statusMerge,cmdoutMerge] = system(cmdStr);
    if statusMerge == 0
        fprintf('Status of merging pdf files: Successful\n');
    else
        fprintf('Status of merging pdf files: Not successful\n');
        pdf_fullpath = [];
    end
    
    % Delete indivudal-page pdf's, now that we have merged them into one pdf.
    % Turn off recycling, so delete actually means delete.
    recycle('off');
    delete(delStr{1,1:end});
    
%     winopen(pdf_fullpath);

%% %------- C3-EVENT PAGES -------%
    
    pageNumberC3events = 1;
    maxNumEvents = 60; % 60 events, 3 events per page, equals 20 pages
    numC3eventPages = min(ceil(length(c3events)/3),ceil(maxNumEvents/3));
    pdf_fullpath_c3event_page = cell(numC3eventPages,1);
    
    if ~isempty(c3events)
        for ii=1:min(length(c3events),maxNumEvents)
            % modulus of event number, to control plot positioning and page number
            plotMod = mod(ii,3);
            % create a page (figure)
            if plotMod == 1
                hFig_Page = createPageFig;
            end
            % add header with logo, id of patient, recording time info
            objectPosition = [ 0 (topOfPage-1.35) maxWidth 1.0];
            addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
            % add title "Full Sized Strips" to page
            objectPosition = [ 0 (topOfPage-2.1) maxWidth 0.4];
            addTitleFullSizeStrips(hFig_Page, objectPosition);
            % calculating position for plot
            if plotMod == 1
                objYpos = topOfPage-10.25;
            elseif plotMod == 2
                objYpos = topOfPage-18.45;
            else
                objYpos = topOfPage-26.65;
            end
            objectPosition = [0 , objYpos, maxWidth, 8];
            % add event strip
            plotStrip_C3event(hFig_Page, objectPosition, dS, ecgData, fs, c3events(ii), ii, timestamps, jsondata, cortriumColors);
            % export current page if we have put 3 event plots on current page (or this is the last event), and increase page number
            if (plotMod == 0) || (ii == length(c3events))
                % export page to PDF
                pdf_fullpath_c3event_page(pageNumberC3events) = cellstr(fullfile(file_path, [filename_wo_extension '_c3events_page' num2str(pageNumberC3events) '.pdf']));
                print(hFig_Page, '-painters', '-dpdf', '-r0', pdf_fullpath_c3event_page{pageNumberC3events});
    %             winopen(pdf_fullpath_c3event_page{pageNumberC3events});
                % close the (invisible) figure window
                close(hFig_Page);
                pageNumberC3events = pageNumberC3events + 1;
            end
        end
    end

    % build command string for pdftk.exe, including all c3event pages
    cmdStr = pdftk_exe;
    delStr = cell(1);
    for ii=1:length(pdf_fullpath_c3event_page)
        cmdStr = [cmdStr ' "' pdf_fullpath_c3event_page{ii} '"'];
        delStr{ii} = pdf_fullpath_c3event_page{ii};
    end
    pdf_fullpath_c3events = fullfile(file_path, [filename_wo_extension '_c3events.pdf']);
    cmdStr = [cmdStr ' cat output "' pdf_fullpath_c3events '"'];
    % merge PDF pages
    [statusMerge,cmdoutMerge] = system(cmdStr);
    if statusMerge == 0
        fprintf('Status of merging c3event pdf files: Successful\n');
    else
        fprintf('Status of merging c3event pdf files: Not successful\n');
    end
    % Delete indivudal-page pdf's, now that we have merged them into one pdf.
    % Turn off recycling, so delete actually means delete.
    recycle('off');
    delete(delStr{1,1:end});
    
%%  %------- MERGE FIRST PART OF REPORT WITH EVENT PAGES -------%
    
    % merge PDF pages
    pdf_fullpath_w_events = fullfile(file_path, [filename_wo_extension '_' jsondata.my_user '_w_events.pdf']);
    cmdStr = [pdftk_exe ' "' pdf_fullpath '" "' pdf_fullpath_c3events '" cat output "' pdf_fullpath_w_events];
    
    % merge PDF pages
    [statusMerge,cmdoutMerge] = system(cmdStr);
    if statusMerge == 0
        fprintf('Status of merging pdf files of main report and c3events: Successful\n');
    else
        fprintf('Status of merging pdf files of main report and c3events: Not successful\n');
        pdf_fullpath_w_events = [];
    end
    
    
    fprintf('ecgReportType1: %f seconds\n',toc(hTic_ecgReportType1));
end

%% Create a figure, the size of A4 paper, to be used as parent for everything that is created on the page
function hFig_Page = createPageFig()
    X = 21.0;                  % A4 paper size, units in centimeters
    Y = 29.7;                  % A4 paper size, units in centimeters
    xMargin = 1;               % left/right margins from page borders
    yMargin = 1;               % bottom/top margins from page borders
    xSize = X - xMargin*2;     % figure size on paper (width & height)
    ySize = Y - yMargin*2;     % figure size on paper (width & height)
    
    % create page figure, the size of A4
    hFig_Page = figure('Numbertitle','off',...
        'MenuBar', 'None',... %'figure'
        'Toolbar','None',...
        'Visible','off',...
        'Units', 'centimeters',...
        'Position',[0 0 xSize ySize],...
        'PaperUnits','centimeters',...
        'PaperSize',[X Y],...
        'PaperPosition',[0 0 X Y],...
        'PaperOrientation','portrait',...
        'PaperPositionMode','auto');
end

%% get amplitude units pr mV
function unitsPerMv = getUnitsPerMillivolt(jsondata)
    % C3 ecg data is 5243 units pr millivolt, for 16bit,
    % and 20971.52 units pr millivolt, for 24bit.
    % It is assumed that firmwareversion (called "softwareversion" in JSON)
    % from 0.3.0.0 and higher provides 24bit ECG data.
    if ~isempty(jsondata) && isfield(jsondata,'softwareversion')
        FWstr = strrep(jsondata.softwareversion,'.','');
        FWnum = str2double(FWstr);
        if ~isnan(FWnum) && FWnum >= 300
            unitsPerMv = 20971.52;
        else
            unitsPerMv = 5243;
        end
    else
        unitsPerMv = 200; % 5243  (200 is for MIT data)
    end
end

%% get sampleRateFactor
function sampleRateFactor = getSampleRateFactor(ecgData, accelmag, jsondata)
    % C3 ecg data is 5243 units pr millivolt, for 16bit,
    % and 20971.52 units pr millivolt, for 24bit.
    % It is assumed that firmwareversion (called "softwareversion" in JSON)
    % from 0.3.0.0 and higher provides 24bit ECG data.
    if ~isempty(jsondata) && isfield(jsondata,'softwareversion')
        FWstr = strrep(jsondata.softwareversion,'.','');
        FWnum = str2double(FWstr);
        if ~isnan(FWnum) && FWnum >= 300
            fileFormat = '24bit';
        else
            fileFormat = '16bit';
        end
    else
        if length(ecgData)/length(accelmag) < 8
            fileFormat = '24bit';
        else
            fileFormat = '16bit';
        end
    end
    switch fileFormat
        case '24bit'
            sampleRateFactor = 6;
        otherwise
            sampleRateFactor = 10;
    end
end

%% add elements for the front page
function addFrontPageElements(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    % create axes object for logo image
    imgHeightToWidthRatio = double(size(logoCortriumImgData.img,1))/double(size(logoCortriumImgData.img,2));
    imgPrintWidth = 6.5; % cm
    imgPrintHeight = imgPrintWidth * imgHeightToWidthRatio;
    logoAxPos = [objectPosition(1)+objectPosition(3)*0.5-imgPrintWidth*0.5, objectPosition(2)-imgPrintHeight, imgPrintWidth, imgPrintHeight];
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', logoAxPos);
    % show the image and set alpha for transparent background
    hIm = imshow(logoCortriumImgData.img, logoCortriumImgData.map, 'InitialMagnification', 'fit', 'Parent', hAx);
    hIm.AlphaData = logoCortriumImgData.alpha;
    hAx.Visible = 'off';
    
    % some standard sizes for info boxes
    boxWidth = 12.0;
    boxHeight = 0.5;
    
    % axes object for front page title "C3 ECG Report"
    titleObjectPosition = [objectPosition(1)+objectPosition(3)*0.5-boxWidth*0.5, logoAxPos(2)-2.5, boxWidth, boxHeight*2];
    hAxTitle = axes('Parent',hFig_Page,'Units','centimeters','Position',titleObjectPosition);
    % rectancle to frame the title
%     rectangle('Position',[0, 0, 1, 1],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxTitle);
    % add title text
    backgroundColorForText = [1 1 1 0];
    titleStr = 'C3 ECG Report';
    hTxt = text(titleObjectPosition(3)*0.5, 0.25, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'baseline', 'FontSize', 18, 'FontWeight', 'bold', 'Margin', 1,  'Parent', hAxTitle);
    hTxt.BackgroundColor = backgroundColorForText;
    
    % axes object for front page Patient Info
    titleObjectPosition = [objectPosition(1)+objectPosition(3)*0.5-boxWidth*0.5, logoAxPos(2)-4.5, boxWidth, boxHeight*3];
    hAxPatientInfo = axes('Parent',hFig_Page,'Units','centimeters','Position',titleObjectPosition);
    % rectancles for Patient Info
    rectangle('Position',[0, 0, 0.7, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxPatientInfo);
    rectangle('Position',[0, 0.333, 0.7, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxPatientInfo);
    rectangle('Position',[0.7, 0, 0.3, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxPatientInfo);
    rectangle('Position',[0.7, 0.333, 0.3, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxPatientInfo);
%     rectangle('Position',[0, 0.666, 1, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxPatientInfo);
    % add text
    backgroundColorForText = [1 1 1 0];
    titleStr = 'Patient';
    hTxt = text(0, 0.1+boxHeight*2, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 12, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Name:';
    hTxt = text(0.1, 0.1+boxHeight, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    hTxt = text(1.3, 0.1+boxHeight, jsondata.patientname, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'ID:';
    hTxt = text(0.1, 0.1, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    hTxt = text(0.7, 0.1, jsondata.patientid, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Age:';
    hTxt = text(0.1+boxWidth*0.7, 0.1+boxHeight, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    hTxt = text(0.9+0.1+(boxWidth*0.7), 0.1+boxHeight, num2str(jsondata.patientage), 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Gender:';
    hTxt = text(0.1+boxWidth*0.7, 0.1, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    hTxt = text(1.45+0.1+boxWidth*0.7, 0.1, jsondata.gender, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxPatientInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    
    % axes object for front page Recording Info
    titleObjectPosition = [objectPosition(1)+objectPosition(3)*0.5-boxWidth*0.5, logoAxPos(2)-6.5, boxWidth, boxHeight*3];
    hAxRecordingInfo = axes('Parent',hFig_Page,'Units','centimeters','Position',titleObjectPosition);
    % rectancles for Patient Info
    rectangle('Position',[0, 0, 0.5, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxRecordingInfo);
    rectangle('Position',[0, 0.333, 0.5, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxRecordingInfo);
    rectangle('Position',[0.5, 0, 0.5, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxRecordingInfo);
    rectangle('Position',[0.5, 0.333, 0.5, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxRecordingInfo);
%     rectangle('Position',[0, 0.666, 1, 0.333],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxRecordingInfo);
    % add text
    backgroundColorForText = [1 1 1 0];
    titleStr = 'Recording';
    hTxt = text(0, 0.1+boxHeight*2, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 12, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Start:';
    hTxt = text(0.1, 0.1+boxHeight, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    strText = datestr(timestamps.world.timeStart, 'yyyy-mm-dd, HH:MM:SS');
    hTxt = text(1.15, 0.1+boxHeight, strText, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Duration:';
    hTxt = text(0.1, 0.1, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    [h,m,s] = hms(timestamps.duration.timeEnd);
    strText = sprintf('%d hrs, %d min, %.0f sec', h, m, s );
    hTxt = text(1.75, 0.1, strText, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'End:';
    hTxt = text(0.1+boxWidth*0.5, 0.1+boxHeight, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    strText = datestr(timestamps.world.timeEnd, 'yyyy-mm-dd, HH:MM:SS');
    hTxt = text(0.9+0.1+(boxWidth*0.5), 0.1+boxHeight, strText, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    titleStr = 'Filename:';
    hTxt = text(0.1+boxWidth*0.5, 0.1, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;
    hTxt = text(1.7+0.1+(boxWidth*0.5), 0.1, jsondata.filename, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 10, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxRecordingInfo);
    hTxt.BackgroundColor = backgroundColorForText;    
    
    % axes object for front page Note box
    titleObjectPosition = [objectPosition(1)+objectPosition(3)*0.5-boxWidth*0.5, logoAxPos(2)-8.5, boxWidth, boxHeight*3];
    hAxNote = axes('Parent',hFig_Page,'Units','centimeters','Position',titleObjectPosition);
    % rectancles for Patient Info
    rectangle('Position',[0, 0, 1, 0.666],'FaceColor',[1 1 1], 'EdgeColor', [0 0 0], 'LineWidth', 0.1, 'LineStyle', '-', 'Parent', hAxNote);
    % add text
    backgroundColorForText = [1 1 1 0];
    titleStr = 'Note';
    hTxt = text(0, 0.1+boxHeight*2, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline', 'FontSize', 12, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxNote);
    hTxt.BackgroundColor = backgroundColorForText;
    if isfield(jsondata,'reportnote')
        strText = jsondata.reportnote;
    else
        strText = '';
    end
    hTxtBox = uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',[titleObjectPosition(1)+0.1 titleObjectPosition(2)+.1 titleObjectPosition(3)-0.2 titleObjectPosition(4)-boxHeight-0.2],...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',10);
    hTxtBox.BackgroundColor = backgroundColorForText;

    % Set axes visibility to 'off'
    setAxesVisibilty([hAxTitle,hAxPatientInfo,hAxRecordingInfo,hAxNote],'off');
end

%% Add rectangle, e.g. as a frame for text objects
function addRectangle(hFig_Page, objectPosition, varargin)
    if ~isempty(varargin)
        bgColor = varargin{1};
    else
        bgColor = [1 1 1];
    end
    axes('Parent',hFig_Page,'Units','centimeters','Position',objectPosition);
    axis([0 1 0 1]);
    axis off;
    rectangle('Position',[0 0 1 1],'FaceColor',bgColor);
end

%% Add rectangle, e.g. as a frame for text objects
function addRectangleColorFrame(hFig_Page, objectPosition, varargin)
    if ~isempty(varargin)
        bgColor = varargin{1};
        if length(varargin) > 1
            edgeColor = varargin{2};
        end
    else
        bgColor = [1 1 1];
        edgeColor = [0 0 0];
    end
    hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',objectPosition);
    axis(hAx,[0 1 0 1]);
    axis(hAx,'off');
    rectangle('Position',[0 0 1 1],'FaceColor',bgColor,'EdgeColor',edgeColor,'Parent',hAx);
end

%% Add header
function addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    % create axes object for adding a line at the bottom of the header
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
    plot([0, 1], [0, 0], 'Color', 'k', 'LineWidth', 0.5, 'Parent', hAx);
    hAx.YLim = [0, 1];
    hAx.XLim = [0, 1];
    hAx.Color = 'none';
    hAx.Visible = 'off';
    % create axes object for logo image
    imgHeightToWidthRatio = double(size(logoCortriumImgData.img,1))/double(size(logoCortriumImgData.img,2));
    imgPrintWidth = 3.5; % cm
    imgPrintHeight = imgPrintWidth * imgHeightToWidthRatio;
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1)+objectPosition(3)-imgPrintWidth+0.2, objectPosition(2)+0.2, imgPrintWidth, imgPrintHeight]);
    % show the image and set alpha for transparent background
    hIm = imshow(logoCortriumImgData.img, logoCortriumImgData.map, 'InitialMagnification', 'fit', 'Parent', hAx);
    hIm.AlphaData = logoCortriumImgData.alpha;
    hAx.Visible = 'off';
    % add patient ID label
    textObjectPosition = [objectPosition(1) (objectPosition(2)+0.9) 1.7 0.4];
    strText = sprintf('Patient ID:');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add patient ID text
    textObjectPosition = [(objectPosition(1)+1.7) (objectPosition(2)+0.9) 10 0.4];
    strText = sprintf('%s', jsondata.patientid);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add patient name label
    textObjectPosition = [objectPosition(1) (objectPosition(2)+0.5) 2.25 0.4];
    strText = sprintf('Patient Name:');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add patient name text
    textObjectPosition = [(objectPosition(1)+2.25) (objectPosition(2)+0.5) 10 0.4];
    strText = sprintf('%s', jsondata.patientname);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add recording start time label
    textObjectPosition = [objectPosition(1) (objectPosition(2)+0.1) 2.5 0.4];
    strText = sprintf('Recording start:');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add recording start time text
    textObjectPosition = [(objectPosition(1)+2.55) (objectPosition(2)+0.1) 10 0.4];
    strText = sprintf('%s', datestr(timestamps.world.timeStart, 'yyyy-mm-dd, HH:MM:SS'));
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
end

%% Add title for pages with Full-Size Strips
function addTitleFullSizeStrips(hFig_Page, objectPosition)
    strText = sprintf('Full-Sized Strips');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',objectPosition,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
end

%% Add HRV Time Domain Summary
function addHRVsummary(hFig_Page, objectPosition, cS)
    % first, create a box to frame the summary
    bgColor = [0.925 0.925 0.925];
    addRectangle(hFig_Page, objectPosition, bgColor);
    % add headline
    textObjectPosition = [ objectPosition(1)+0.25 objectPosition(2)+1.1 objectPosition(3)-0.5 objectPosition(4)-1.25];
    strText = sprintf('HRV Time Domain Summary');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',bgColor);
    % then add statistics text, if classification data is available
    if ~isempty(cS)
        textObjectPosition = [ objectPosition(1)+0.25 objectPosition(2)+0.2 objectPosition(3)-0.5 objectPosition(4)-1];    
        strText1 = sprintf('SDNN (ms): %-4.0f       SDSD (ms): %-4.0f          NN50 Count: %d        RMSSD (ms): %-4.0f', cS.SDNN, cS.SDSD, cS.NN50, cS.RMSSD);
        strText2 = sprintf('SDANN (ms): %-4.0f      SDNN Index (ms): %-4.0f    pNN50 (%%): %-6.2f', cS.SDANN, cS.SDNN_index, cS.pNN50);
        strText = sprintf('%s\n%s',strText1, strText2);
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',textObjectPosition,...
        'HorizontalAlignment','left',...
        'String',strText,...
        'FontName','FixedWidth',...
        'FontWeight','normal',...
        'FontSize',10,...
        'BackgroundColor',bgColor);
    else
        itemText = 'HRV Time Domain Summary';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Add recording time info
function addRecordingTimeText(hFig_Page, objectPosition, timestamps)
    strText1 = sprintf('Recording start time: %s', datestr(timestamps.world.timeStart, 'yyyy-mm-dd  HH:MM:SS'));
    strText2 = sprintf('Recording end time  : %s', datestr(timestamps.world.timeEnd, 'yyyy-mm-dd  HH:MM:SS'));
    [h,m,s] = hms(timestamps.duration.timeEnd);
    strText3 = sprintf('Recording total time: %d hrs, %d min, %.0f sec', h, m, s );
    strText = sprintf('%s\n%s\n%s\n',strText1, strText2, strText3);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',objectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontName','FixedWidth',...
    'FontWeight','normal',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
end

%% Add stats text
function addStatsText(hFig_Page, objectPosition, cS, dS)
    % add info about total heart beats, HR min, avg, max
    textObjectPosition = [objectPosition(1) objectPosition(2) objectPosition(3) objectPosition(4)];
    strText = sprintf('Beats, total: %d', length(dS.wavedet.MLI.QRSon));
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontName','FixedWidth',...
    'FontWeight','normal',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);

    if ~isempty(cS)
        % add info about total number of supraventricular and ventricular beats
        textObjectPosition = [objectPosition(1) objectPosition(2)-0.5 objectPosition(3) objectPosition(4)];
        strText = sprintf('Supraventricular beats, total: %d\nVentricular beats, total: %d', length(cS.idxClassS), length(cS.idxClassV));
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',textObjectPosition,...
        'HorizontalAlignment','left',...
        'String',strText,...
        'FontName','FixedWidth',...
        'FontWeight','normal',...
        'FontSize',10,...
        'BackgroundColor',[1 1 1]);
    else
        % in case of missing classification data, add info
        textObjectPosition = [objectPosition(1) objectPosition(2)-0.5 objectPosition(3) objectPosition(4)];
        strText = sprintf('Classification data not available.');
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',textObjectPosition,...
        'HorizontalAlignment','left',...
        'String',strText,...
        'FontName','FixedWidth',...
        'FontWeight','normal',...
        'FontSize',10,...
        'BackgroundColor',[1 1 1]);
    end

    bgColor = [0.925 0.925 0.925];
    %strText1 = sprintf('Min, Avg, Max values for entire recording:\n');
    strText2 = sprintf('                      Min    Avg    Max   \n');
    strText3 = sprintf('Heart rate   (bpm): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.HeartRate_min, dS.wavedet.MLI.HeartRate_mean, dS.wavedet.MLI.HeartRate_max);
    strText4 = sprintf('P duration    (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.P_duration_min, dS.wavedet.MLI.P_duration_mean, dS.wavedet.MLI.P_duration_max);
    strText5 = sprintf('PR interval   (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.PR_interval_min, dS.wavedet.MLI.PR_interval_mean, dS.wavedet.MLI.PR_interval_max);
    strText6 = sprintf('QRS duration  (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QRS_duration_min, dS.wavedet.MLI.QRS_duration_mean, dS.wavedet.MLI.QRS_duration_max);
    strText7 = sprintf('QT interval   (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QT_interval_min, dS.wavedet.MLI.QT_interval_mean, dS.wavedet.MLI.QT_interval_max);
    strText8 = sprintf('QTcB interval (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcB_interval_min, dS.wavedet.MLI.QTcB_interval_mean, dS.wavedet.MLI.QTcB_interval_max);
    strText9 = sprintf('QTcF interval (ms): %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcF_interval_min, dS.wavedet.MLI.QTcF_interval_mean, dS.wavedet.MLI.QTcF_interval_max);

    strText = sprintf('%s%s%s%s%s%s%s%s', strText2, strText3, strText4, strText5, strText6, strText7, strText8, strText9);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',[objectPosition(1) objectPosition(2)-1.75 objectPosition(3) objectPosition(4)],...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontName','FixedWidth',...
    'FontWeight','normal',...
    'FontSize',10,...
    'BackgroundColor',bgColor);
end

%% Create piechart of heartbeat classes ("Rhythm Breakdown")
function plotHBCpiechart(hFig_Page, objectPosition, cS)
    % first make a box to frame the chart
    addRectangle(hFig_Page, objectPosition);    
    pieObjectPosition = [ objectPosition(1)+1 objectPosition(2)+0.2 objectPosition(3)-2 objectPosition(4)+1];
    % make sure there's classification data to plot
    if ~isempty(cS)
        % F = fusion of normal and ventricular
        % N = normal
        % S = supraventricular
        % U = unclassified ?
        % V = ventricular
        X = [length(cS.idxClassS), length(cS.idxClassV), length(cS.idxClassF), length(cS.idxClassU), length(cS.idxClassN)];
        % build a label cell array
        labelList = {'SVPB: ';'VPB: ';'Fusion: ';'Unclass.: ';'Normal: '};
        labelIdx = 1;
        colorPicker = [];
        for i=1:length(X)
            if X(i) ~= 0
                labels{labelIdx,1} = labelList{i,1};
                colorPicker(labelIdx) = i;
                labelIdx = labelIdx + 1;
            end
        end
%         labels = {'SVPB: ';'VPB: ';'Fusion: ';'Unclass.: ';'Normal: '};
        hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',pieObjectPosition);
        hPie = pie('Parent',hAx,X); %,labels
        hTextPie = findobj(hPie,'Type','text'); % text object handles
        percentValues = get(hTextPie,'String'); % percent values
        combinedstrings = strcat(labels,percentValues); % labels and percent values
%         oldExtents_cell = get(hTextPie,'Extent'); % cell array
%         oldExtents = cell2mat(oldExtents_cell); % numeric array
%         hTextPie(1).String = combinedstrings(1);
%         hTextPie(2).String = combinedstrings(2);
%         hTextPie(3).String = combinedstrings(3);
%         hTextPie(4).String = combinedstrings(4);
%         hTextPie(5).String = combinedstrings(5);
%         newExtents_cell = get(hTextPie,'Extent'); % cell array
%         newExtents = cell2mat(newExtents_cell); % numeric array
%         width_change = newExtents(:,3)-oldExtents(:,3);
%         signValues = sign(oldExtents(:,1));
%         offset = signValues.*(width_change/2);
%         textPositions_cell = get(hTextPie,{'Position'}); % cell array
%         textPositions = cell2mat(textPositions_cell); % numeric array
%         textPositions(:,1) = textPositions(:,1) + offset; % add offset
%         hTextPie(1).Position = textPositions(1,:);
%         hTextPie(2).Position = textPositions(2,:);
%         hTextPie(3).Position = textPositions(3,:);
%         hTextPie(4).Position = textPositions(4,:);
%         hTextPie(5).Position = textPositions(5,:);
        for i=1:size(hTextPie,1)
            hTextPie(i).String = '';
        end
        % changing FaceColor
        faceColors = [0.95, 0.45, 0;...
                      0.95, 0, 0.95;...
                      0, 0.7, 0.3 ;...
                      0.5000, 0.8016, 1;...
                      0, 0.4470, 0.7410];
        hPatch = findobj(hPie, 'Type', 'patch');
        % color the pie patches according the faceColors array
        for i=1:size(hPatch,1)
            hPatch(i).FaceColor = faceColors(colorPicker(i),:);
        end
        % Legend
        hLegendPie = legend(hAx,combinedstrings,'Location','southoutside','Orientation','vertical');
        hLegendPie.FontSize = 8;
        hLegendPie.Position(4) = 0.05;
        hLegendPie.Position(2) = 0.74;
        title(hAx,'Rhythm Breakdown','FontSize',10,'FontWeight','bold');
    else
        itemText = 'Rhythm Breakdown';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end

    
end

%% Create histogram of RR intervals
function plotRRhistogram(hFig_Page, objectPosition, dS)
    % Error handling, to avoid histogram bugs...
    % Creating a temporary array of RR intervals, that removes values > 2 seconds,
    % since the histogram x-axis limit is fixed between [0 2], and values outside
    % this range can cause obscure visual artefacts in the histogram.
    tmp = dS.wavedet.MLI.RR_intervals;
    tmp(tmp > 2) = [];
    % Deleting NaN entries from tmp
    tmp(isnan(tmp)) = [];
    % create a box to frame the chart
    addRectangle(hFig_Page, objectPosition);
    if ~isempty(tmp)
        histObjectPosition = [objectPosition(1)+1 objectPosition(2)+0.9 objectPosition(3)-1.5 objectPosition(4)-1.6];
        % then create the histogram
        hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',histObjectPosition);
        histogram('Parent', hAx, (1000*tmp), length(unique(tmp)), 'EdgeColor', 'none', 'FaceAlpha', 1);
        set(hAx,'xlim',[0 2000]);
        grid(hAx,'on');
        hAx.YTickLabelRotation = 90;
        hAx.FontSize = 8;
        xlabel(hAx,'RR interval (ms)','FontSize',8);
        ylabel(hAx,'Total Beats','FontSize',8);
        title(hAx,'RR Normals','FontSize',10,'FontWeight','bold');
    end
end

%% Plot HR
function plotHR(hFig_Page, objectPosition, dS, timestamps, cortriumColors)
    % create axis objects
    h = createAxesTwoLayered(hFig_Page, objectPosition);
    % get timestamps for heartbeats
    timestamps = getEventTimeStamps(timestamps, dS.wavedet.MLI.QRSon);
    % plot data
    plot(h.ax1,timestamps.world.timeEvent(2:length(timestamps.world.timeEvent)), dS.wavedet.MLI.HeartRates, 'DatetimeTickFormat', 'HH:mm');
    % manage the appearance of the axes
    layoutAxesTwoLayered(h, objectPosition, timestamps, 1, cortriumColors, [0 200], [0 200], 5, 'HR (BPM)', 'Heart Rate', {'HR'});
end

%% Plot Ventricular beats
function plotVEB(hFig_Page, objectPosition, cS, dS, timestamps, cortriumColors)
    % make sure there's classification data to plot
    idx = [];
    if ~isempty(cS)
        % get timestamps for ventricular heartbeats
        idx = find(cS.anntyp == 'V');
    end
    if ~isempty(cS) && ~isempty(idx)
        % create axis objects
        h = createAxesTwoLayered(hFig_Page, objectPosition);
         % get timestamps for ventricular heartbeats
        vBeatTimes = cS.time(idx);
        timestamps = getEventTimeStamps(timestamps, vBeatTimes);
        % Before we plot, we must shift idx by -1, and in case idx(1) == 0 it must be set to 1.
        % Heart rates are calculated from pairs of beats,
        % and there will always be one less heart-rate than number of beats.
        idx = idx - 1;
        if idx(1) == 0
            idx(1) = 1;
        end
        plot(h.ax1, timestamps.world.timeEvent, dS.wavedet.MLI.HeartRates(idx), 'LineStyle', 'none', 'Marker', '.', 'DatetimeTickFormat', 'HH:mm');
        % manage the appearance of the axes
        layoutAxesTwoLayered(h, objectPosition, timestamps, 1, cortriumColors, [0 200], [0 200], 6, 'VPB/Minute', 'Ventricular', {'VEB'});
    elseif ~isempty(cS) && isempty(idx)
        itemText = 'VEB';
        classText = 'Ventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'VEB';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Plot Supraventricular beats
function plotSVEB(hFig_Page, objectPosition, cS, dS, timestamps, cortriumColors)
    % make sure there's classification data to plot
    idx = [];
    if ~isempty(cS)
        % get timestamps for supraventricular heartbeats
        idx = find(cS.anntyp == 'S');
    end
    if ~isempty(cS) && ~isempty(idx)
        % create axis objects
        h = createAxesTwoLayered(hFig_Page, objectPosition);
        sBeatTimes = cS.time(idx);
        timestamps = getEventTimeStamps(timestamps, sBeatTimes);
        % Before we plot, we must shift idx by -1, and in case idx(1) == 0 it must be set to 1.
        % Heart rates are calculated from pairs of beats,
        % and there will always be one less heart-rate than number of beats.
        idx = idx - 1;
        if idx(1) == 0
            idx(1) = 1;
        end
        plot(h.ax1, timestamps.world.timeEvent, dS.wavedet.MLI.HeartRates(idx), 'LineStyle', 'none', 'Marker', '.', 'DatetimeTickFormat', 'HH:mm');
        % manage the appearance of the axes
        layoutAxesTwoLayered(h, objectPosition, timestamps, 1, cortriumColors, [0 200], [0 200], 6, 'SVPB/Minute', 'Supraventricular', {'SVEB'});
    elseif ~isempty(cS) && isempty(idx)
        itemText = 'SVEB';
        classText = 'Supraventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'SVEB';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Prepare a struct of ecgData for plotting (used in Full-Sized strips)
function [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, secondsToDisplay, fs)
    halfNumSamples = (secondsToDisplay*0.5) * fs;  % 18.5sec * 250Hz = 4625 samples
    ECG_rangeStart_index = round(ECG_center_index - halfNumSamples);
    ECG_rangeEnd_index = round(ECG_center_index + halfNumSamples);
    % check if start or end index is out of bounds, and if so,
    % pad with 'NaN'
    if ECG_rangeStart_index < 1
        nanStartPadding = nan((abs(ECG_rangeStart_index)+1),1);
        ecgDataForPlot.plot1 = [nanStartPadding;ecgData(1:ECG_rangeEnd_index,1)];
        ecgDataForPlot.plot2 = [nanStartPadding;ecgData(1:ECG_rangeEnd_index,2)];
        ecgDataForPlot.plot3 = [nanStartPadding;ecgData(1:ECG_rangeEnd_index,3)];
    elseif ECG_rangeEnd_index > length(ecgData)
        nanEndPadding = nan((ECG_rangeEnd_index-length(ecgData)),1); %NOTE: GET BACK HERE, REVISIT IN OTHER FULL SIZE
        ecgDataForPlot.plot1 = [ecgData(ECG_rangeStart_index:length(ecgData),1);nanEndPadding];
        ecgDataForPlot.plot2 = [ecgData(ECG_rangeStart_index:length(ecgData),2);nanEndPadding];
        ecgDataForPlot.plot3 = [ecgData(ECG_rangeStart_index:length(ecgData),3);nanEndPadding];
    else
        ecgDataForPlot.plot1 = ecgData(ECG_rangeStart_index:ECG_rangeEnd_index,1);
        ecgDataForPlot.plot2 = ecgData(ECG_rangeStart_index:ECG_rangeEnd_index,2);
        ecgDataForPlot.plot3 = ecgData(ECG_rangeStart_index:ECG_rangeEnd_index,3);
    end
    % calculate suitable y-min limit
    ecgDataForPlot.plot1yMinLim = nanmean(ecgDataForPlot.plot1) - nanstd(double(ecgDataForPlot.plot1))*6;
    ecgDataForPlot.plot2yMinLim = nanmean(ecgDataForPlot.plot2) - nanstd(double(ecgDataForPlot.plot2))*6;
    ecgDataForPlot.plot3yMinLim = nanmean(ecgDataForPlot.plot3) - nanstd(double(ecgDataForPlot.plot3))*6;
    % median
    ecgDataForPlot.plot1yMedian = median(ecgDataForPlot.plot1,'omitnan');
    ecgDataForPlot.plot2yMedian = median(ecgDataForPlot.plot2,'omitnan');
    ecgDataForPlot.plot3yMedian = median(ecgDataForPlot.plot3,'omitnan');
    % mean
    ecgDataForPlot.plot1yMean = nanmean(ecgDataForPlot.plot1);
    ecgDataForPlot.plot2yMean = nanmean(ecgDataForPlot.plot2);
    ecgDataForPlot.plot3yMean = nanmean(ecgDataForPlot.plot3);
    % std dev
    ecgDataForPlot.plot1yStd = nanstd(double(ecgDataForPlot.plot1));
    ecgDataForPlot.plot2yStd = nanstd(double(ecgDataForPlot.plot2));
    ecgDataForPlot.plot3yStd = nanstd(double(ecgDataForPlot.plot3));
end

%% Create axes-objects needed for Full-Sized Strips
function h = createAxesFullSizeStrips(hFig_Page, objectPosition)
    % BACKGROUND AXES, not used for plotting, only grid and box is shown
    gridPos = [objectPosition(1), (objectPosition(2)+objectPosition(4))-(objectPosition(4)*0.25)*3, objectPosition(3), objectPosition(4)*0.75];
    h.axBg = axes('Parent',hFig_Page,'Units','centimeters','Position',gridPos,'Box','off');
    % clear ticklabels
    set(h.axBg,'Xticklabel',[]);
    set(h.axBg,'Yticklabel',[]);
    % set up tickmarks for every 5mm, and turn on grid
    set(h.axBg,'xlim',[0 gridPos(3)*10]);
    set(h.axBg,'ylim',[0 gridPos(4)*10]);
    h.axBg.XTick = linspace(0,(gridPos(3)*10)-mod((gridPos(3)*10),5),((gridPos(3)*10)-mod(gridPos(3)*10,5)+5)/5);
    h.axBg.YTick = linspace(0,(gridPos(4)*10)-mod((gridPos(4)*10),5),((gridPos(4)*10)-mod(gridPos(4)*10,5)+5)/5);
    h.axBg.YColor = [0.92 0.92 0.92];
    h.axBg.XColor = [0.92 0.92 0.92];
    grid(h.axBg,'on');
    h.axBg.GridAlpha = 1;
    h.axBg.TickLength = [0 0];
    
    % Frame the plot area
    addRectangleColorFrame(hFig_Page, objectPosition, [1 1 1 0], [0 0 0]);
    
    % CLOSE-UP AXES (invisible), for full-sized plots of MLI, MLII, and MLIII
    axA1Pos = [objectPosition(1)+0.25, objectPosition(2)+objectPosition(4)*0.25, objectPosition(3)-0.5, objectPosition(4)*0.75];
    axA2Pos = [objectPosition(1)+0.25, objectPosition(2)+objectPosition(4)*0.25, objectPosition(3)-0.5, objectPosition(4)*0.75];
    axA3Pos = [objectPosition(1)+0.25, objectPosition(2)+objectPosition(4)*0.25, objectPosition(3)-0.5, objectPosition(4)*0.75];
    h.axA1 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axA1Pos, 'Color', 'none', 'Box', 'off');
    h.axA2 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axA2Pos, 'Color', 'none', 'Box', 'off');
    h.axA3 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axA3Pos, 'Color', 'none', 'Box', 'off');
    
    % ZOOMED-OUT AXES (invisible), for plots of MLI, MLII, and MLIII
    axB1Pos = [objectPosition(1)+0.25, objectPosition(2), objectPosition(3)-0.5, objectPosition(4)*0.25];
    axB2Pos = [objectPosition(1)+0.25, objectPosition(2), objectPosition(3)-0.5, objectPosition(4)*0.25];
    axB3Pos = [objectPosition(1)+0.25, objectPosition(2), objectPosition(3)-0.5, objectPosition(4)*0.25];
    h.axB1 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axB1Pos, 'Color', 'none', 'Box', 'off');
    h.axB2 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axB2Pos, 'Color', 'none', 'Box', 'off');
    h.axB3 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axB3Pos, 'Color', 'none', 'Box', 'off');
    
    % TEXT AXES (invisible) in the foreground, where text can be added
    h.axFg = axes('Parent',hFig_Page,'Units','centimeters','Position',objectPosition);
    h.axFg.YLim = [0 1];
    hold(h.axFg,'on');
    
    % RECTANGLE AXES (invisible), parent to a rectangle highlighting the area of interest, on the zoomed-out plots.
    axFgRectPos = [objectPosition(1)+0.25, (objectPosition(2)+objectPosition(4))-((objectPosition(4)*0.25)*3)-(objectPosition(4)*0.25*0.333333)*3, objectPosition(3)-0.5, objectPosition(4)*0.25];
    h.axFgRect = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', axFgRectPos, 'Color', 'none', 'Box', 'off');
    h.axFgRect.YLim = [0 1];
end

%% Plot Full-Sized strips (general function)
function plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors)
    % calculate the span of the y-axis, making sure that a 5mm grid area equals 0.5mV.
    unitsPerMv = getUnitsPerMillivolt(jsondata);
    % C3 ecg data is 5243 units pr millivolt, for 16bit.
    % 20971.52 units pr millivolt, for 24bit.
    ySpanA = (h.axA1.Position(4)*2*0.5*unitsPerMv);
    % Plot MLI ECG data
    if sum(~isnan(ecgDataForPlot.plot1))
        plot(h.axA1,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot1, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor1);
        set(h.axA1,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        set(h.axA1,'ylim',[ecgDataForPlot.plot1yMedian-ySpanA+ySpanA*0.2 ecgDataForPlot.plot1yMedian+ySpanA*0.2]);
    end
    % Plot MLII ECG data
    if sum(~isnan(ecgDataForPlot.plot2))
        plot(h.axA2,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot2, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor2);
        set(h.axA2,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        if ecgDataForPlot.plot2yMean >= ecgDataForPlot.plot2yMedian
            set(h.axA2,'ylim',[ecgDataForPlot.plot2yMedian-ySpanA*0.5 ecgDataForPlot.plot2yMedian+ySpanA*0.5]);
        else
            set(h.axA2,'ylim',[ecgDataForPlot.plot2yMedian-ySpanA*0.5 ecgDataForPlot.plot2yMedian+ySpanA*0.5]);
        end
    end
    % Plot MLIII ECG data
    if sum(~isnan(ecgDataForPlot.plot3))
        plot(h.axA3,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot3, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor3);
        set(h.axA3,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        set(h.axA3,'ylim',[ecgDataForPlot.plot3yMedian-ySpanA*0.2 ecgDataForPlot.plot3yMedian+ySpanA-ySpanA*0.2]);
    end
end

%% Plot Zoomed-out strips (general function)
function plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors)
    % calculate the span of the y-axis, so that proportions match the Full-Sized plots
    unitsPerMv = getUnitsPerMillivolt(jsondata);
    ySpanB = (h.axA1.Position(4)*2*0.5*unitsPerMv) * (5/3);
    % Plot MLI ECG data
    if sum(~isnan(ecgDataForPlot.plot1))
        plot(h.axB1,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot1, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor1);
        set(h.axB1,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        set(h.axB1,'ylim',[ecgDataForPlot.plot1yMedian-ySpanB+ySpanB*0.275 ecgDataForPlot.plot1yMedian+ySpanB*0.275]);
    end
    % Plot MLII ECG data
    if sum(~isnan(ecgDataForPlot.plot2))
        plot(h.axB2,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot2, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor2);
        set(h.axB2,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        if ecgDataForPlot.plot2yMean >= ecgDataForPlot.plot2yMedian
            set(h.axB2,'ylim',[ecgDataForPlot.plot2yMedian-ySpanB*0.5 ecgDataForPlot.plot2yMedian+ySpanB*0.5]);
        else
            set(h.axB2,'ylim',[ecgDataForPlot.plot2yMedian-ySpanB*0.5 ecgDataForPlot.plot2yMedian+ySpanB*0.5]);
        end
    end
    % Plot MLIII ECG data
    if sum(~isnan(ecgDataForPlot.plot3))
        plot(h.axB3,ECG_rangeStart_index:ECG_rangeEnd_index, ecgDataForPlot.plot3, 'LineWidth', 0.1, 'Color', cortriumColors.plotcolor3);
        set(h.axB3,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        set(h.axB3,'ylim',[ecgDataForPlot.plot3yMedian-ySpanB*0.275 ecgDataForPlot.plot3yMedian+ySpanB-ySpanB*0.275]);
    end
end

function addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, titleStr, hr)
    backgroundColorForText = [1 1 1 0.6];
    % add name of plot
    hTxt = text(objectPosition(3)*0.5, objectPosition(4)-0.3, titleStr, 'Units','centimeters', 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Margin', 1,  'Parent', h.axFg);
    hTxt.BackgroundColor = backgroundColorForText;
    % add time of the event
    eventTime = getEventTimeStamps(timestamps, ECG_center_index);
    timeStr =  datestr(eventTime.world.timeEvent, 'yyyy-mm-dd  HH:MM:SS');
    hTxt = text(objectPosition(1)+0.25, objectPosition(4)-0.3, timeStr, 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'Margin', 1,  'Parent', h.axFg);
    hTxt.BackgroundColor = backgroundColorForText;
    % add HR average for the close-up range
    HRstr = sprintf('HR: %.0f',hr);
    hTxt = text(objectPosition(3)-0.25, objectPosition(4)-0.3, HRstr, 'Units','centimeters', 'HorizontalAlignment', 'right', 'FontSize', 8, 'FontWeight', 'bold', 'Margin', 1,  'Parent', h.axFg);
    hTxt.BackgroundColor = backgroundColorForText;
end

%% C3event Full size strip
function plotStrip_C3event(hFig_Page, objectPosition, dS, ecgData, fs, c3eventIndex, c3eventNum, timestamps, jsondata, cortriumColors)
    h = createAxesFullSizeStrips(hFig_Page, objectPosition);    
    ECG_center_index = ((c3eventIndex - 1) * 6) + 1;
    % We want to display 7.4 seconds of ECG data
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
    % calculate average heart rate during this time window %NOTE: Double-check the indices here
    RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
    RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
    RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
    HR_mean = 60/RR_interval_mean;
    % THE CLOSE-UP PLOTS
    plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % THE ZOOMED-OUT PLOTS
    % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
    % plot
    plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % Plot a vertical line indicating location of event (or rather, the
    % location of when the event was marked by a press on the C3 device -
    % which is probably a few seconds after the actual event)
    plot(h.axFg,[0.5 0.5],[0 0.94],'Color',cortriumColors.plotcolor4,'LineWidth',1.0,'LineStyle',':');
    % ADDING TEXT
    c3eventTitleStr = sprintf('C3 Event # %d',c3eventNum);
    addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, c3eventTitleStr, HR_mean);
    % Set all axes visibility to 'off'
    setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off'); 
end

%% Full size strip of ECG signal, for a Ventricular beat event
function plotStrip_VPB(hFig_Page, objectPosition, cS, dS, ecgData, fs, timestamps, jsondata, cortriumColors)
    if ~isempty(cS) && ~isempty(cS.idxClassV)
        h = createAxesFullSizeStrips(hFig_Page, objectPosition);
        % Get the cS.time index of (first) class 'V' heartbeat
        idx = cS.idxClassV(1);
        % Get the corresponding ecg samples of the QRS complex.
        % cS.time(idx) is the center, and ECG_indices(1) and ECG_indices(2)
        % is a guestimate of left and right side boundary of the QRS.
        ECG_indices(1) = cS.time(idx) - round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001);
        ECG_indices(2) = cS.time(idx) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
        ECG_center_index = cS.time(idx);
        % We want to display 7.4 seconds of ECG data
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
        % calculations for rectangle plot (see further below...)
        eventSpan = ECG_indices(2) - ECG_indices(1);
        rectXpos = ECG_center_index - eventSpan*0.5;
        % calculate average heart rate during this time window %NOTE: Double-check the indices here
        RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
        RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
        RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
        HR_mean = 60/RR_interval_mean;
        % THE CLOSE-UP PLOTS
        plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % THE ZOOMED-OUT PLOTS
        % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
        % plot
        plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % ADDING TEXT
        addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'VPB', HR_mean);
        % ADD RECTANGLE highlighting the area that is the center of the event, on the zoomed-out plots.
        % Rectangle position has to be specified in data units.
        set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
        % Set all axes visibility to 'off'
        setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
    elseif ~isempty(cS) && isempty(cS.idxClassV)
        itemText = 'VPB';
        classText = 'Ventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'VPB';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Full size strip of ECG signal, for a Supraventricular beat event
function plotStrip_SVPB(hFig_Page, objectPosition, cS, dS, ecgData, fs, timestamps, jsondata, cortriumColors)
    if ~isempty(cS) && ~isempty(cS.idxClassS)
        h = createAxesFullSizeStrips(hFig_Page, objectPosition);
        % Get the cS.time index of (first) class 'S' heartbeat
        idx = cS.idxClassS(1);
        % Get the corresponding ecg samples of the QRS complex.
        % cS.time(idx) is the center, and ECG_indices(1) and ECG_indices(2)
        % is a guestimate of left and right side boundary of the QRS.
        ECG_indices(1) = cS.time(idx) - round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001);
        ECG_indices(2) = cS.time(idx) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
        ECG_center_index = cS.time(idx);
        % We want to display 7.4 seconds of ECG data
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
        % calculations for rectangle plot (see further below...)
        eventSpan = ECG_indices(2) - ECG_indices(1);
        rectXpos = ECG_center_index - eventSpan*0.5;
        % calculate average heart rate during this time window %NOTE: Double-check the indices here
        RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
        RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
        RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
        HR_mean = 60/RR_interval_mean;
        % THE CLOSE-UP PLOTS
        plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % THE ZOOMED-OUT PLOTS
        % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
        % plot
        plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % ADDING TEXT
        addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'SVPB', HR_mean);
        % ADD RECTANGLE highlighting the area that is the center of the event, on the zoomed-out plots.
        % Rectangle position has to be specified in data units.
        set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
        % Set axes visibility to 'off'
        setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
    elseif ~isempty(cS) && isempty(cS.idxClassS)
        itemText = 'SVPB';
        classText = 'Supraventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'SVPB';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Full size strip of ECG signal, for a Minimum HR segment %NOTE: REPLACES OLDER FUNCTION
function plotStrip_MinHR(hFig_Page, objectPosition, dS, ecgData, timestamps, jsondata, cortriumColors)
    if isfield(dS,'ARR_15sec')
        h = createAxesFullSizeStrips(hFig_Page, objectPosition);
        % Find the index of (first) minimum RR interval average found in 15 sec segments
        [~, idx] = nanmax(dS.ARR_15sec);
        % Find the corresponding ecg data indices
        ECG_indices = [dS.startIndex_15sec(idx), dS.endIndex_15sec(idx)];
        % Calculate the center index
        ECG_center_index = round(ECG_indices(1) + (ECG_indices(2) - ECG_indices(1))*0.5);
        % We want to display 7.4 seconds of ECG data
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
        % calculations for rectangle plot (see further down...)
        eventSpan = ECG_indices(2) - ECG_indices(1);
        rectXpos = ECG_center_index - eventSpan*0.5;
        % calculate average heart rate during this time window %NOTE: Double-check the indices here
        RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
        RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
        RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
        HR_mean = 60/RR_interval_mean;

    %     fprintf('\nECG1 min, max, median, mean, std:\n');
    %     fprintf('%f, %f, %f, %f, %f\n',nanmin(ecgDataForPlot.plot1), nanmax(ecgDataForPlot.plot1), ecgDataForPlot.plot1yMedian,ecgDataForPlot.plot1yMean,ecgDataForPlot.plot1yStd);
    %     fprintf('\nECG2 min, max, median, mean, std:\n');
    %     fprintf('%f, %f, %f, %f, %f\n',nanmin(ecgDataForPlot.plot2), nanmax(ecgDataForPlot.plot2), ecgDataForPlot.plot2yMedian,ecgDataForPlot.plot2yMean,ecgDataForPlot.plot2yStd);
    %     fprintf('\nECG3 min, max, median, mean, std:\n');
    %     fprintf('%f, %f, %f, %f, %f\n',nanmin(ecgDataForPlot.plot3), nanmax(ecgDataForPlot.plot3), ecgDataForPlot.plot3yMedian,ecgDataForPlot.plot3yMean,ecgDataForPlot.plot3yStd);
    %     fprintf('\nySpan: %f\n',ySpanA);
    %     fprintf('Seconds along x: %f\n',h.axA1.Position(3)*0.4);

        % THE CLOSE-UP PLOTS
        plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % THE ZOOMED-OUT PLOTS
        % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
        % plot
        plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % ADDING TEXT
        addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'Minimum HR', HR_mean);
        % add semi-tranparent rectangle to highlight the area of interest
        set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        % Rectangle position has to be specified in data units.
        rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
        % Set axes visibility to 'off'
        setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
    else
        itemText = 'Min HR';
        addRecLess15SecOrNoARRdataText(hFig_Page, objectPosition, itemText)
    end
end

%% Full size strip of ECG signal, for a Maximum RR interval segment
function plotStrip_MaxRR(hFig_Page, objectPosition, dS, ecgData, fs, timestamps, jsondata, cortriumColors)
    h = createAxesFullSizeStrips(hFig_Page, objectPosition);
    % Find the index of (first) maximum RR interval
    tmp = dS.wavedet.MLI.RR_intervals;
    tmp(tmp > 2.3) = -1; % setting RR intervals > 2.3 seconds to -1, before doing search for max %NOTE: WHAT SHOULD CRITERIA BE?
    [~, idx] = nanmax(tmp); % nanmax(dS.wavedet.MLI.RR_intervals);
    % Find the corresponding ecg data indices of the 2 QRS complexes 
    % that the RR interval was calculated from
    ECG_indices = [dS.wavedet.MLI.QRSon(idx), dS.wavedet.MLI.QRSoff(idx+1)];
    % check if QRSon or QRSoff index is NaN. If so, we will use the qrs fiducial point
    % and mean duration of QRS to arrive at an endpoint for the event.
    if isnan(ECG_indices(1)) || isnan(ECG_indices(2))
        if ~isnan(dS.wavedet.MLI.qrs(idx)) && ~isnan(dS.wavedet.MLI.qrs(idx+1))
            ECG_indices(1) = dS.wavedet.MLI.qrs(idx) - round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001);
            ECG_indices(2) = dS.wavedet.MLI.qrs(idx+1) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
        elseif isfield(dS.wavedet,'multilead')
            if ~isnan(dS.wavedet.multilead.qrs(idx)) && ~isnan(dS.wavedet.multilead.qrs(idx+1))
                ECG_indices(1) = dS.wavedet.multilead.qrs(idx) - round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001);
                ECG_indices(2) = dS.wavedet.multilead.qrs(idx+1) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
            end
        else
            error('Indices are NaN!');
        end
    end
    % Calculate the center index
    ECG_center_index = round(ECG_indices(1) + (ECG_indices(2) - ECG_indices(1))*0.5);
    % We want to display 7.4 seconds of ECG data
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
    % calculations for rectangle plot (see further down...)
    eventSpan = ECG_indices(2) - ECG_indices(1);
    rectXpos = ECG_center_index - eventSpan*0.5;
    % calculate average heart rate during this time window %NOTE: Double-check the indices here
    RR_rangeStart_index = (find(dS.wavedet.MLI.qrs > ECG_rangeStart_index, 1));
    RR_rangeEnd_index = (find(dS.wavedet.MLI.qrs > ECG_rangeEnd_index, 1))-1;
    RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
    HR_mean = 60/RR_interval_mean;
    % THE CLOSE-UP PLOTS
    plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % THE ZOOMED-OUT PLOTS
    % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
    % plot
    plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % ADDING TEXT
    addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'Maximum RR', HR_mean);
    % ADD RECTANGLE highlighting the area that is the center of the event, on the zoomed-out plots.
    % Rectangle position has to be specified in data units.
    set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
    rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
    % Set axes visibility to 'off'
    setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
end

%% Full size strip of ECG signal, for a Minimum RR interval segment
function plotStrip_MinRR(hFig_Page, objectPosition, dS, ecgData, fs, timestamps, jsondata, cortriumColors)
    h = createAxesFullSizeStrips(hFig_Page, objectPosition);
    % Find the index of (first) minimum RR interval
    [~, idx] = nanmin(dS.wavedet.MLI.RR_intervals);
%     % WARNING: HARD CODED FIX FOR A SINGLE REPORT
%     idx = 49266;
%     % WARNING END
    % Find the corresponding ecg data indices of the 2 QRS complexes 
    % that the RR interval was calculated from
    if ~isnan(dS.wavedet.MLI.qrs(idx)) && ~isnan(dS.wavedet.MLI.qrs(idx+1))
        ECG_indices(1) = dS.wavedet.MLI.qrs(idx);
        ECG_indices(2) = dS.wavedet.MLI.qrs(idx+1) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
    elseif isfield(dS.wavedet,'multilead')
        if ~isnan(dS.wavedet.multilead.qrs(idx)) && ~isnan(dS.wavedet.multilead.qrs(idx+1))
            ECG_indices(1) = dS.wavedet.multilead.qrs(idx);
            ECG_indices(2) = dS.wavedet.multilead.qrs(idx+1) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
        end
    else
        error('Indices are NaN!');
    end
    % Calculate the center index
    ECG_center_index = round(ECG_indices(1) + (ECG_indices(2) - ECG_indices(1))*0.5) + round(dS.wavedet.MLI.QRS_duration_mean*fs*0.001*2);
    % We want to display 7.4 seconds of ECG data
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
    % calculations for rectangle plot (see further down...)
    if ~isnan(ECG_indices(1)) && ~isnan(ECG_indices(2))
        eventSpan = ECG_indices(2) - ECG_indices(1);
    else
        eventSpan = round(dS.wavedet.MLI.QRS_duration_mean);
    end
    rectXpos = ECG_center_index - eventSpan*0.5;
    % calculate average heart rate during this time window %NOTE: Double-check the indices here
    RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
    RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
    RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
    HR_mean = 60/RR_interval_mean;
    % THE CLOSE-UP PLOTS
    plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % THE ZOOMED-OUT PLOTS
    % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
    [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
    % plot
    plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
    % ADDING TEXT
    addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'Minimum RR', HR_mean);
    % ADD RECTANGLE highlighting the area that is the center of the event, on the zoomed-out plots.
    % Rectangle position has to be specified in data units.
    set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
    rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
    % Set axes visibility to 'off'
    setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
end

%% Full size strip of ECG signal, for a Maximum HR segment
function plotStrip_MaxHR(hFig_Page, objectPosition, dS, ecgData, timestamps, jsondata, cortriumColors)
    if isfield(dS,'ARR_15sec')
        h = createAxesFullSizeStrips(hFig_Page, objectPosition);
        % Find the index of (first) minimum RR interval average found in 15 sec segments
        [~, idx] = nanmin(dS.ARR_15sec);
        % Find the corresponding ecg data indices of the 2 QRS complexes 
        % that the RR interval was calculated from
        ECG_indices = [dS.startIndex_15sec(idx), dS.endIndex_15sec(idx)];
        % Calculate the center index
        ECG_center_index = round(ECG_indices(1) + (ECG_indices(2) - ECG_indices(1))*0.5);
        % We want to display 7.4 seconds of ECG data
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 7.4, timestamps.samplingrate.fs);
        % calculations for rectangle plot (see further down...)
        eventSpan = ECG_indices(2) - ECG_indices(1);
        rectXpos = ECG_center_index - eventSpan*0.5;
        % calculate average heart rate during this time window %NOTE: Double-check the indices here
        RR_rangeStart_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeStart_index, 1));
        RR_rangeEnd_index = (find(dS.wavedet.MLI.QRSon > ECG_rangeEnd_index, 1))-1;
        RR_interval_mean = nanmean(dS.wavedet.MLI.RR_intervals(RR_rangeStart_index:RR_rangeEnd_index));
        HR_mean = 60/RR_interval_mean;
        % THE CLOSE-UP PLOTS
        plotFullSizedStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % THE ZOOMED-OUT PLOTS
        % We want to display 37 seconds (5 times as much as the close-up plot) of ECG data 
        [ecgDataForPlot, ECG_rangeStart_index, ECG_rangeEnd_index] = getEcgDataForPlot(ecgData, ECG_center_index, 37, timestamps.samplingrate.fs);
        % plot
        plotZoomedOutStrips(h, ECG_rangeStart_index, ECG_rangeEnd_index, ecgDataForPlot , jsondata, cortriumColors);
        % ADDING TEXT
        addTextFullSizedPlots(h, objectPosition, timestamps, ECG_center_index, 'Maximum HR', HR_mean);
        % ADD RECTANGLE highlighting the area that is the center of the event, on the zoomed-out plots.
        % Rectangle position has to be specified in data units.
        set(h.axFgRect,'xlim',[ECG_rangeStart_index ECG_rangeEnd_index]);
        rectangle('Position',[rectXpos, 0, eventSpan, 1],'FaceColor',[0.5 0.5 0.5 0.1], 'EdgeColor', [0 0 0 0.5], 'LineWidth', 0.1, 'LineStyle', ':', 'Parent', h.axFgRect);
        % Set axes visibility to 'off'
        setAxesVisibilty([h.axA1,h.axA2,h.axA3,h.axB1,h.axB2,h.axB3,h.axFg,h.axFgRect],'off');
    else
        itemText = 'Max HR';
        addRecLess15SecOrNoARRdataText(hFig_Page, objectPosition, itemText)
    end
end

%% Poincare plot, Total Beats, RR interval
function plotPoincareTotal(hFig_Page, objectPosition, dS)
    % first create a box to frame the plot
    addRectangle(hFig_Page, objectPosition);    
    plotObjectPosition = [ objectPosition(1)+0.9 objectPosition(2)+0.9 objectPosition(3)-1.1 objectPosition(4)-1.6];
    % then create the plot
    hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',plotObjectPosition);
    plot(hAx, dS.wavedet.MLI.RR_intervals(2:length(dS.wavedet.MLI.RR_intervals)), dS.wavedet.MLI.RR_intervals(1:length(dS.wavedet.MLI.RR_intervals)-1), 'LineStyle', 'none', 'MarkerSize', 1, 'Marker', '.');
    hAx.XLim = [0 2];
    hAx.YLim = [0 2];
    hAx.XTick = linspace(0,2,5);
    hAx.Box = 'off';
    hAx.YTickLabelRotation = 90;
    hAx.FontSize = 8;
    xlabel(hAx,'RR current (s)','FontSize',8);
    ylabel(hAx,'RR previous (s)','FontSize',8);
    title(hAx,[num2str(length(dS.wavedet.MLI.R)) ' Total Beats'],'FontSize',10,'FontWeight','bold');
end

%% Poincare plot, Normal Beats, RR interval
function plotPoincareNormal(hFig_Page, objectPosition, cS, dS)
    % first create a box to frame the plot
    addRectangle(hFig_Page, objectPosition);    
    plotObjectPosition = [ objectPosition(1)+0.9 objectPosition(2)+0.9 objectPosition(3)-1.1 objectPosition(4)-1.6];
    % make sure there's classification data to plot
    if ~isempty(cS)
        % get indices for normal heartbeats
        idx = find(cS.anntyp == 'N');
    else
        idx = [];
    end
    if ~isempty(cS) && ~isempty(idx)
        % store number of normal heartbeats
        numBeats = length(idx);
        % if the first Normal heartbeat has index number 1, we remove it,
        % since there is no RR interval for the very first heartbeat
        if idx(1) == 1
            idx(1) = [];
        end
        % we also need to shift the index number with -1,
        % since e.g. index 2 of 'anntyp' corresponds with index 1 of dS.wavedet.MLI.RR_intervals
        idx = idx-1;
        % NOTE: check that the indices plotted are correct times - may need a +1 index shift
        hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',plotObjectPosition);
        plot(hAx, dS.wavedet.MLI.RR_intervals(idx(2:length(idx))), dS.wavedet.MLI.RR_intervals(idx(1:length(idx)-1)), 'LineStyle', 'none', 'MarkerSize', 1, 'Marker', '.');
        hAx.XLim = [0 2];
        hAx.YLim = [0 2];
        hAx.XTick = linspace(0,2,5);
        hAx.Box = 'off';
        hAx.YTickLabelRotation = 90;
        hAx.FontSize = 8;
        xlabel(hAx,'RR current (s)','FontSize',8);
        ylabel(hAx,'RR previous (s)','FontSize',8);
        title(hAx,[num2str(numBeats) ' Normal Beats'],'FontSize',10,'FontWeight','bold');
    else
        itemText = 'Normal Beats';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Poincare plot, Ventricular Beats, RR interval
function plotPoincareVentricular(hFig_Page, objectPosition, cS, dS)
    % first create a box to frame the plot
    addRectangle(hFig_Page, objectPosition);    
    plotObjectPosition = [ objectPosition(1)+0.9 objectPosition(2)+0.9 objectPosition(3)-1.1 objectPosition(4)-1.6];
    % make sure there's classification data to plot
    % get indices for ventricular heartbeats
    idx = [];
    if ~isempty(cS)
        idx = find(cS.anntyp == 'V');
    end
    if ~isempty(cS) && ~isempty(idx)
        % store number of ventricular heartbeats
        numBeats = length(idx);
        % if the first ventricular heartbeat has index number 1, we remove it,
        % since there is no RR interval for the very first heartbeat
        if idx(1) == 1
            idx(1) = [];
        end
        % we also need to shift the index number with -1,
        % since e.g. index 2 of 'anntyp' corresponds with index 1 of dS.wavedet.MLI.RR_intervals
        idx = idx-1;
        % NOTE: check that the indices plotted are correct times - may need a +1 index shift
        hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',plotObjectPosition);
        plot(hAx, dS.wavedet.MLI.RR_intervals(idx(2:length(idx))), dS.wavedet.MLI.RR_intervals(idx(1:length(idx)-1)), 'LineStyle', 'none', 'MarkerSize', 1, 'Marker', '.');
        hAx.XLim = [0 2];
        hAx.YLim = [0 2];
        hAx.XTick = linspace(0,2,5);
        hAx.Box = 'off';
        hAx.YTickLabelRotation = 90;
        hAx.FontSize = 8;
        xlabel(hAx,'RR current (s)','FontSize',8);
        ylabel(hAx,'RR previous (s)','FontSize',8);
        title(hAx,[num2str(numBeats) ' Ventricular Beats'],'FontSize',10,'FontWeight','bold');
    elseif ~isempty(cS) && isempty(idx)
        itemText = 'Ventricular beats';
        classText = 'Ventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'Ventricular Beats';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% Poincare plot, Supraventricular Beats, RR interval
function plotPoincareSupraventricular(hFig_Page, objectPosition, cS, dS)
    % first create a box to frame the plot
    addRectangle(hFig_Page, objectPosition);    
    plotObjectPosition = [ objectPosition(1)+0.9 objectPosition(2)+0.9 objectPosition(3)-1.1 objectPosition(4)-1.6];
    % make sure there's classification data to plot
    idx = [];
    if ~isempty(cS)
        % get indices for supraventricular heartbeats
        idx = find(cS.anntyp == 'S');
    end
    if ~isempty(cS) && ~isempty(idx)
        % store number of supraventricular heartbeats
        numBeats = length(idx);
        % if the first supraventricular heartbeat has index number 1, we remove it,
        % since there is no RR interval for the very first heartbeat
        if idx(1) == 1
            idx(1) = [];
        end
        % we also need to shift the index number with -1,
        % since e.g. index 2 of 'anntyp' corresponds with index 1 of dS.wavedet.MLI.RR_intervals
        idx = idx-1;
        % NOTE: check that the indices plotted are correct times - may need a +1 index shift
        hAx = axes('Parent',hFig_Page,'Units','centimeters','Position',plotObjectPosition);
        plot(hAx, dS.wavedet.MLI.RR_intervals(idx(2:length(idx))), dS.wavedet.MLI.RR_intervals(idx(1:length(idx)-1)), 'LineStyle', 'none', 'MarkerSize', 1, 'Marker', '.');
        hAx.XLim = [0 2];
        hAx.YLim = [0 2];
        hAx.XTick = linspace(0,2,5);
        hAx.Box = 'off';
        hAx.YTickLabelRotation = 90;
        hAx.FontSize = 8;
        xlabel(hAx,'RR current (s)','FontSize',8);
        ylabel(hAx,'RR previous (s)','FontSize',8);
        title(hAx,[num2str(numBeats) ' Supraventricular'],'FontSize',10,'FontWeight','bold');
    elseif ~isempty(cS) && isempty(idx)
        itemText = 'Supraventricular';
        classText = 'Supraventricular beats';
        addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    else
        itemText = 'Supraventricular';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% plot SDNN and SDSD for 5 min segments during the entire recording
function plotSDNN_SDSD(hFig_Page, objectPosition, cS, timestamps, cortriumColors)
    % IF cS NOT EMPTY, AND DURATION OF RECORDING IS LONGER THAN 5 MINS
    if ~isempty(cS)
        % create axis objects
        h = createAxesTwoLayered(hFig_Page, objectPosition);
        % get timestamps for 5 minute index points
        timestamps = getEventTimeStamps(timestamps, cS.index5mins);
        % plot data  % The first timestamp equals the absolute beginning of the recording, and will not have corresponding SDNN and SDSD values. For the first time index they will be set as zero.
        plot(h.ax1, timestamps.world.timeEvent, [0,cS.SDNN_5min], 'Color', cortriumColors.color1, 'DatetimeTickFormat', 'HH:mm');
        plot(h.ax2, timestamps.world.timeEvent, [0,cS.SDSD_5min], 'Color', cortriumColors.color2, 'DatetimeTickFormat', 'HH:mm');
        % manage the appearance of the axes
        layoutAxesTwoLayered(h, objectPosition, timestamps, 2, cortriumColors, [0 250], [0 250], 6, 'SDNN (ms)', 'SDSD (ms)', [{'SDNN'}, {'SDSD'}]);
    elseif minutes(timestamps.duration.timeEnd) < 5
        % duration of recording is too short to generate data for this plot
        itemText = 'SDNN and SDSD';
        addDurationLessThan5MinText(hFig_Page, objectPosition, itemText);
    else
        % in case no classification data is available
        itemText = 'SDNN and SDSD';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% plot NN50 count, and pNN50 (%), for 5 min segments during the entire recording
function plotNN50_pNN50(hFig_Page, objectPosition, cS, timestamps, cortriumColors)
    % IF cS IS NOT EMPTY, AND DURATION OF RECORDING IS LONGER THAN 5 MINS
    if ~isempty(cS)        
        % create axis objects
        h = createAxesTwoLayered(hFig_Page, objectPosition);
        % get timestamps for 5 minute index points
        timestamps = getEventTimeStamps(timestamps, cS.index5mins);
        % plot data  % The first timestamp equals the absolute beginning of the recording, and will not have a corresponding NN50 count or pNN50 (%). For the first time index they will be set as zero.
        plot(h.ax1, timestamps.world.timeEvent, [0,cS.NN50_5min], 'Color', cortriumColors.color1, 'DatetimeTickFormat', 'HH:mm');
        plot(h.ax2, timestamps.world.timeEvent, [0,cS.pNN50_5min], 'Color', cortriumColors.color2, 'DatetimeTickFormat', 'HH:mm');
        % manage the appearance of the axes
        layoutAxesTwoLayered(h, objectPosition, timestamps, 2, cortriumColors, [0 100], [0 50], 6, 'NN50 (#)', 'pNN50 (%)', [{'NN50 (#)'}, {'pNN50 (%)'}]);
    elseif minutes(timestamps.duration.timeEnd) < 5
        % duration of recording is too short to generate data for this plot
        itemText = 'NN50 and pNN50';
        addDurationLessThan5MinText(hFig_Page, objectPosition, itemText);
    else
        % in case no classification data is available
        itemText = 'NN50 and pNN50';
        addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText);
    end
end

%% plot RR intervals mean, and Proc. Time, for 5 min segments during the entire recording
function plotRRmean_ProcTime(hFig_Page, objectPosition, dS, timestamps, cortriumColors)
    % Recording must have a duration of at least 5 mins. for this plot to be available
    if minutes(timestamps.duration.timeEnd) >= 5 && isfield(dS,'ARR_5min')
        % create axis objects
        h = createAxesTwoLayered(hFig_Page, objectPosition);
        % get timestamps for 5 minute index points
        timestamps = getEventTimeStamps(timestamps, dS.index5mins);
        % plot data  % The first timestamp equals the absolute beginning of the recording, and will not have a corresponding mean RR interval time or Proc Time. For the first time index they will be set as zero.
        plot(h.ax1, timestamps.world.timeEvent, [0,dS.ARR_5min], 'Color', cortriumColors.color1, 'DatetimeTickFormat', 'HH:mm');
        plot(h.ax2, timestamps.world.timeEvent, [0,dS.ProcTime_5min], 'Color', cortriumColors.color2, 'DatetimeTickFormat', 'HH:mm');
        % manage the appearance of the axes
        layoutAxesTwoLayered(h, objectPosition, timestamps, 2, cortriumColors, [0 1000], [0 300], 6, 'Mean RR (ms)', 'Proc Time (sec)', [{'Mean RR (ms)'}, {'Proc Time (sec)'}]);
    else
        % duration of recording is too short to generate data for this plot
        itemText = 'Mean RR and Proc. Time';
        addDurationLessThan5MinText(hFig_Page, objectPosition, itemText);
    end

end

%% Create timestamps for start and end of recording, by decoding the HEX filename and adding length of recording
function timestamps = getTimeStampsStartEnd(jsondata, recordingDuration, fs)
    % Actual (world) start and end timestamps
    timestamps.world.timeStart = datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC');
    timestamps.world.timeEnd = timestamps.world.timeStart + seconds(recordingDuration);
    
    % Duration (start at zero) start and end timestamps
    deltaTime = days(timestamps.world.timeEnd - timestamps.world.timeStart);
    timestamps.duration.timeStart = days(0);
    timestamps.duration.timeEnd = days(deltaTime); 
    
    % Storing sampling rate in the timestamps struct, for easy access in subsequent calculations
    timestamps.samplingrate.fs = fs;
end

%% Create timestamps for events (e.g. QRSon, Supraventricular beats, RR_intervals, etc.)
function timestamps = getEventTimeStamps(timestamps, eventIndices)
    % Actual (world) timestamps for each event in this timeseries
    timestamps.world.timeEvent = seconds(eventIndices./timestamps.samplingrate.fs) + timestamps.world.timeStart;
    
    % Duration (start at zero) timestamps for each event in this timeseries
    timestamps.duration.timeEvent = seconds(eventIndices./timestamps.samplingrate.fs) + timestamps.duration.timeStart;
end

%% Create two axes-objects, layered on top of each other
function h = createAxesTwoLayered(hFig_Page, objectPosition)
    h.ax1 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition, 'Box', 'on');
    h.ax2 = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
end

%% Adjust the appearance of layered axes object (2 layers)
function layoutAxesTwoLayered(h, objectPosition, timestamps, numLines, cortriumColors, y1lim, y2lim, yNumGridLines, y1label, y2label, legendStr)
    % set x-axis limits
    h.ax1.XLim = [datenum(timestamps.world.timeStart) datenum(timestamps.world.timeEnd)];
    h.ax2.XLim = [datenum(timestamps.world.timeStart) datenum(timestamps.world.timeEnd)];
    % set x-axis tickmarks
    h.ax1.XTick = linspace(datenum(timestamps.world.timeStart),datenum(timestamps.world.timeEnd),10);
    h.ax2.XTick = linspace(datenum(timestamps.world.timeStart),datenum(timestamps.world.timeEnd),10);
    % remove ticklabels from x-axis 2, so we don't get "overprint"
    h.ax2.XTickLabel = [];
    % set y-axis location to the right, for axes-object 2
    h.ax2.YAxisLocation = 'Right';
    % set y-axis limits
    h.ax1.YLim = y1lim;
    h.ax2.YLim = y2lim;
    % set y-axis tickmarks
    h.ax1.YTick = linspace(y1lim(1), y1lim(2), yNumGridLines);
    h.ax2.YTick = linspace(y2lim(1), y2lim(2), yNumGridLines);
    % rotate y-axis labels
    h.ax1.YTickLabelRotation = 90;
    h.ax2.YTickLabelRotation = -90;
    % set font size
    h.ax1.FontSize = 8;
    h.ax2.FontSize = 8;
    % turn on grid, only for the first axis object
    grid(h.ax1,'on');
    % set color of y-axes
    if numLines == 2
        h.ax1.YColor = cortriumColors.color1;
        h.ax2.YColor = cortriumColors.color2;
    else
        h.ax1.YColor = cortriumColors.color1;
        h.ax2.YColor = cortriumColors.color1;
    end
    % setting a transparent background for h.ax2
    h.ax2.Color = 'none';
    % adding labels to axes
    h.Xlabel1 = xlabel(h.ax1, 'Time', 'FontSize', 8);
    h.Ylabel2 = ylabel(h.ax1, y1label, 'FontSize', 8);
    h.Ylabel2 = ylabel(h.ax2, y2label, 'FontSize', 8, 'Rotation', -90);
    h.Ylabel2.Units = 'centimeter';
    h.Ylabel2.Position(1) = 18.1;
    % adding legend, which also serves as a title for the plot
    if numLines == 2
        % legend 1, initial setup
        h.legend1 = legend(h.ax1,legendStr(1),'Orientation','horizontal');
        h.legend1.FontSize = 10;
        h.legend1.FontWeight = 'bold';
        h.legend1.Units = 'centimeters';
        % legend 2, initial setup
        h.legend2 = legend(h.ax2,legendStr(2),'Orientation','horizontal');
        h.legend2.FontSize = 10;
        h.legend2.FontWeight = 'bold';
        h.legend2.Units = 'centimeters';
        % sum the width of both legends
        legendWidthTotal = h.legend1.Position(3) + h.legend2.Position(3);
        % legend 1, final positioning
        h.legend1.Position(1) = 9.5  - legendWidthTotal*0.5; % to the left
        h.legend1.Position(2) = objectPosition(2) + objectPosition(4); % positioning the legend above the plot
        h.legend1.Box = 'off';
        % legend 2, final positioning
        h.legend2.Position(1) = h.legend1.Position(1) + h.legend1.Position(3) + 0.25; % to the right
        h.legend2.Position(2) = objectPosition(2) + objectPosition(4); % positioning the legend above the plot
        h.legend2.Box = 'off';
    else
        h.legend1 = legend(h.ax1,legendStr(1),'Orientation','horizontal');
        h.legend1.Units = 'centimeters';
        h.legend1.FontSize = 10;
        h.legend1.FontWeight = 'bold';
        h.legend1.Position(1) = 9.5  - h.legend1.Position(3)*0.5; % center in width of A4 page
        h.legend1.Position(2) = objectPosition(2) + objectPosition(4); % positioning the legend above the plot
        h.legend1.Box = 'off';
    end
end

%% Set visibility of axes
function setAxesVisibilty(hAxes, visStr)
    for ii=1:size(hAxes,2)
        hAxes(ii).Visible = visStr;
    end
end

%% Add frame and text for those cases where classification data is not available
function addClassificationDataNotAvailableText(hFig_Page, objectPosition, itemText)
    addRectangle(hFig_Page, objectPosition);
    itemTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)+0.25, objectPosition(3)-0.2, 0.5];
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',itemTextPos,...
    'HorizontalAlignment','center',...
    'String',itemText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
    strTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)-0.25, objectPosition(3)-0.2, 0.5];
    strText = sprintf('No classification data available');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',strTextPos,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',[1 1 1]);
end

%% Add frame and text for those cases where classification data is available, but there are no instances of this particular class
function addInstancesOfClassNotAvailableText(hFig_Page, objectPosition, itemText, classText)
    addRectangle(hFig_Page, objectPosition);
    itemTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)+0.25, objectPosition(3)-0.2, 0.5];
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',itemTextPos,...
    'HorizontalAlignment','center',...
    'String',itemText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
    strTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)-0.45, objectPosition(3)-0.2, 0.7];
    strText = sprintf('No instances of %s', classText);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',strTextPos,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',[1 1 1]);
end

%% Add frame and text for those cases where recording < 15 secs OR no "ARR_15sec" field exists for dS
function addRecLess15SecOrNoARRdataText(hFig_Page, objectPosition, itemText)
    addRectangle(hFig_Page, objectPosition);
    itemTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)+0.25, objectPosition(3)-0.2, 0.5];
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',itemTextPos,...
    'HorizontalAlignment','center',...
    'String',itemText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
    strTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)-0.45, objectPosition(3)-0.2, 0.7];
    strText = sprintf('Either recording is less than 15 seconds\nor, no average RR data was calculated.');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',strTextPos,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',[1 1 1]);
end

%% Add text for recording if less than 5 mins, meaning various NN statistics can not be plotted
function addDurationLessThan5MinText(hFig_Page, objectPosition, itemText)
    addRectangle(hFig_Page, objectPosition);
    itemTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)+0.25, objectPosition(3)-0.2, 0.5];
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',itemTextPos,...
    'HorizontalAlignment','center',...
    'String',itemText,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',[1 1 1]);
    strTextPos = [objectPosition(1)+0.1, (objectPosition(2)+objectPosition(4)*0.5)-0.25, objectPosition(3)-0.2, 0.5];
    strText = sprintf('This plot is not available, since duration of recording is less than 5 minutes.');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',strTextPos,...
    'HorizontalAlignment','center',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',8,...
    'BackgroundColor',[1 1 1]);
end

%% Read a 4 column physiobank.txt file with ECG and Resp data
function [ecgData, respData] = loadAndFormatPhysiobankData(physbankdata_fullpath)
    fid=fopen(physbankdata_fullpath,'r');
    % skip the first line (header)
    fgetl(fid);
    % now read all the remaining lines
    s = fread(fid,'*char')';
    fclose(fid);
    % although the data is integer, we read as floats in order to keep
    % 'NaN' values (integer sets NaN as 0)
    data = textscan(s,'%f %f %f %f');
    ecgData = [data{1,1},data{1,2},data{1,3}]; %NOTE: Modify if Resp data is included in the physiobank file
    respData = [];  %respData = [data{1,1}];
end

function ecgData = loadEcgFromMITdat(hea_fullpath, dat_fullpath)
    [~,recording_name,~] = fileparts(dat_fullpath);
    hea_fid = fopen(hea_fullpath,'r');
    % header line of .hea file
    heaLine1 = fgetl(hea_fid);
    heaInfo = textscan(heaLine1,'%s %d %d %d');
    numSignals = heaInfo{2};
    numSamples = heaInfo{4};
    % .dat descriptions of .hea file
    datFormat = zeros(numSignals,1);
    for ii=1:numSignals
        heaLineDat = fgetl(hea_fid);
        % .dat info lines: fileName, dataFormat, unitsPerMillivolt, ... and more
        heaInfoDat = textscan(heaLineDat,'%s %d %d %d %d %d %d %d %s');
        % each signal can have its own format (but we will assume the first
        % described format applies to all signals in this .dat
        datFormat(ii) = heaInfoDat{2};
    end
    fclose(hea_fid);
    if datFormat(1) == 212
            ecgData = rdsign212(dat_fullpath, numSignals, 1, numSamples); % rdsign212(recording_name, heasig.nsig, ECG_start_idx, ECG_end_idx)
    else
        error('Error reading .dat. Need moar format options!');
    end            
end

%% Load acceleration magnitude data
function accelmag = loadAccelmag(accelmag_fullpath)
    fid = fopen(accelmag_fullpath,'r');
    s = fread(fid,'*char')';
    fclose(fid);
    data = textscan(s,'%f');
    accelmag = data{1,1};
end

%% Load C3 event data (events that were stored in the BLE, because of press on the C3 B7 button)
function c3events = loadC3events(c3events_fullpath)
    fid = fopen(c3events_fullpath,'r');
    s = fread(fid,'*char')';
    fclose(fid);
    data = textscan(s,'%d');
    c3events = data{1,1};
end

%% Delineation based statistics
function [dS, idxRRNaN, inSampleECGNaN, outSampleECGNaN, inSampleAccNaN, outSampleAccNaN, noisyQRSidx] = calculateDelineationStats(dS, recordingDuration, fs, ecgData, numEcgChannels, accelmag, jsondata, errorCorrection)
    %--- MLI ---%
    % Error correction by variance of ecg signal around each beat.
    % Beats are NaN'ed if too noisy.
    noisyQRSidx = zeros(1,length(dS.wavedet.MLI.qrs));
    noisyQRSvar = [];
    winSize = 74;
    wL = round(winSize*0.5);
    wR = round(winSize*0.5)-1;
    offQRS = 10;
% Noise discrimination by FFT analysis
    if errorCorrection.ECG_noise
        % go through all beats, according to dS.wavedet.MLI.qrs (may differ slightly in cS.time)
        for ii=1:length(dS.wavedet.MLI.qrs)
            ECG_center_index = dS.wavedet.MLI.qrs(ii)+1;
            if ~isnan(ECG_center_index)
                amplECG_inWin = nanmax(ecgData(ECG_center_index-wL:ECG_center_index+wR,1))-nanmin(ecgData(ECG_center_index-wL:ECG_center_index+wR,1));
                % Avoid division by zero
                if amplECG_inWin
                    ecgNormalized_inWin = ecgData(ECG_center_index-wL:ECG_center_index+wR,1)/amplECG_inWin;
                else
                    ecgNormalized_inWin = ecgData(ECG_center_index-wL:ECG_center_index+wR,1)*0;
                end
                NFFT = 2^nextpow2(length(ecgNormalized_inWin)); % Next power of 2 from length of ecgNormalized_inWin
                Y = fft(ecgNormalized_inWin,NFFT)/length(ecgNormalized_inWin);
                f = fs/2*linspace(0,1,NFFT/2+1);                
                fftAmpl = 2*abs(Y(1:NFFT/2+1));
                % Normalizing the FFT result, so the sum is 1
                fftAmplN = fftAmpl/sum(fftAmpl);
                % Inspecting the sum of the FFT for frequencies above 20Hz
                sumFFThigh = sum(fftAmplN(f>25));
                % If more than some % of the FFT amplitude lies above 20Hz
                if sumFFThigh > 0.35
                    isNoisyQRS = true;
                    noisyQRSidx(ii) = dS.wavedet.MLI.qrs(ii);
%                     noisyQRSvar(end+1) = varECGnoiseNormalizedNonR_inWin;
                else
                    isNoisyQRS = false;
                end
                if isNoisyQRS
                    % qrs
                    dS.wavedet.MLI.qrs(ii) = NaN;
                    % R
                    dS.wavedet.MLI.R(ii) = NaN;
                    % Pon
                    dS.wavedet.MLI.Pon(ii) = NaN;
                    % Poff
                    dS.wavedet.MLI.Poff(ii) = NaN;
                    % QRSon
                    dS.wavedet.MLI.QRSon(ii) = NaN;
                    % QRSoff
                    dS.wavedet.MLI.QRSoff(ii) = NaN;
                    % Ton
                    dS.wavedet.MLI.Ton(ii) = NaN;
                    % Toff
                    dS.wavedet.MLI.Toff(ii) = NaN;
                end
            end
        end
        noisyQRSidx(noisyQRSidx == 0) = [];
        fprintf('errorCorrection.ECG_noise,  steps: %d,  Noisy qrs''s: %d\n',ii,length(noisyQRSidx));
    end
    
% % Noise discrimination by inspection of variance - not deemed acceptable
%     if errorCorrection.ECG_noise
%         % go through all beats, according to dS.wavedet.MLI.qrs (may differ slightly in cS.time)
%         for ii=1:length(dS.wavedet.MLI.qrs)
%             ECG_center_index = dS.wavedet.MLI.qrs(ii)+1;
%             if ~isnan(ECG_center_index)
%                 % Amplitude of signal in window around this beat, ecg ch 1
%                 amplECG_inWin = nanmax(ecgData(ECG_center_index-wL:ECG_center_index+wR,1))-nanmin(ecgData(ECG_center_index-wL:ECG_center_index+wR,1));
% %                 ecgNormalizedNonR_inWin = [ecgData(ECG_center_index-wL:ECG_center_index-offQRS,1)/amplECG_inWin; ecgData(ECG_center_index+offQRS:ECG_center_index+wR,1)/amplECG_inWin];
%                 % Only look at signal window just before the R peak (not after, to avoid VEB and SVEB confusion)
%                 % Avoid division by zero
%                 if amplECG_inWin
%                     ecgNormalizedNonR_inWin = ecgData(ECG_center_index-wL:ECG_center_index-offQRS,1)/amplECG_inWin;
%                 else
%                     ecgNormalizedNonR_inWin = 0;
%                 end
%                 varECGnoiseNormalizedNonR_inWin = var(ecgNormalizedNonR_inWin,'omitnan');
% %                 varQRS(ii) = varECGnoiseNormalizedNonR_inWin;
%                 if varECGnoiseNormalizedNonR_inWin > 0.01
%                     isNoisyQRS = true;
%                     noisyQRSidx(end+1) = dS.wavedet.MLI.qrs(ii);
% %                     noisyQRSvar(end+1) = varECGnoiseNormalizedNonR_inWin;
%                 else
%                     isNoisyQRS = false;
%                 end
%                 if isNoisyQRS
%                     % qrs
%                     dS.wavedet.MLI.qrs(ii) = NaN;
%                     % Pon
%                     dS.wavedet.MLI.Pon(ii) = NaN;
%                     % Poff
%                     dS.wavedet.MLI.Poff(ii) = NaN;
%                     % QRSon
%                     dS.wavedet.MLI.QRSon(ii) = NaN;
%                     % QRSoff
%                     dS.wavedet.MLI.QRSoff(ii) = NaN;
%                     % Ton
%                     dS.wavedet.MLI.Ton(ii) = NaN;
%                     % Toff
%                     dS.wavedet.MLI.Toff(ii) = NaN;
%                 end
%             end
%         end
%         fprintf('errorCorrection.ECG_noise,  steps: %d,  Noisy qrs''s: %d\n',ii,length(noisyQRSidx));
%     end
    
    % Error correction by NaN'ing based on ecg amplitude
    if errorCorrection.ECG_amplitude
        unitsPerMv = getUnitsPerMillivolt(jsondata);
        amplitudeMaxLimit = 5.0 * unitsPerMv;
        amplitudeMinLimit = 0.075 * unitsPerMv;
        maxEcgLimit = 2.5 * unitsPerMv;
        minEcgLimit = -2.5 * unitsPerMv;
        winSize = 500 - 1;
        stepSize = round((winSize + 1) * 0.25);
        endIdx = length(ecgData);
        inSampleECGNaN = [];
        outSampleECGNaN = [];
        ii = 1;
        iiECGNan = 1;
        while ii <= endIdx
            if ii+winSize > endIdx
                ii = endIdx - winSize;
                stepSize = winSize + 1;
            end
%             if ii < 10000
%                 fprintf('ii: %d, ii+win: %d, min: %f, max: %f, amplitude: %f\n',ii,ii+winSize,nanmin(nanmin(ecgData(ii:ii+winSize))),nanmax(nanmax(ecgData(ii:ii+winSize))),(nanmax(nanmax(ecgData(ii:ii+winSize))) - nanmin(nanmin(ecgData(ii:ii+winSize)))));
%             end
            if size(ecgData,2) > 1
                maxWinEcg = nanmax(nanmax(ecgData(ii:ii+winSize,1:2)));
                minWinEcg = nanmin(nanmin(ecgData(ii:ii+winSize,1:2)));
            else
                maxWinEcg = nanmax(nanmax(ecgData(ii:ii+winSize,1)));
                minWinEcg = nanmin(nanmin(ecgData(ii:ii+winSize,1)));
            end
            amplWinEcg = (maxWinEcg - minWinEcg);
            if amplWinEcg > amplitudeMaxLimit || maxWinEcg > maxEcgLimit || minWinEcg < minEcgLimit || amplWinEcg < amplitudeMinLimit
                inSampleECGNaN(iiECGNan) = ii;
                outSampleECGNaN(iiECGNan) = ii+winSize;
                iiECGNan = iiECGNan + 1;
            end
            ii = ii + stepSize;
        end
        fprintf('errorCorrection.ECG_amplitude,  steps: %d,  NaN''s: %d\n',ii,length(inSampleECGNaN));
    else
        inSampleECGNaN = [];
        outSampleECGNaN = [];
    end
    if errorCorrection.ECG_amplitude && ~isempty(inSampleECGNaN)
        for ii=1:length(inSampleECGNaN)
            % qrs
            idx2NaN = find(dS.wavedet.MLI.qrs >= inSampleECGNaN(ii) & dS.wavedet.MLI.qrs <= outSampleECGNaN(ii));
            dS.wavedet.MLI.qrs(idx2NaN) = NaN;
            % R
            idx2NaN = find(dS.wavedet.MLI.R >= inSampleECGNaN(ii) & dS.wavedet.MLI.R <= outSampleECGNaN(ii));
            dS.wavedet.MLI.R(idx2NaN) = NaN;
            % Pon
            idx2NaN = find(dS.wavedet.MLI.Pon >= inSampleECGNaN(ii) & dS.wavedet.MLI.Pon <= outSampleECGNaN(ii));
            dS.wavedet.MLI.Pon(idx2NaN) = NaN;
            % Poff
            idx2NaN = find(dS.wavedet.MLI.Poff >= inSampleECGNaN(ii) & dS.wavedet.MLI.Poff <= outSampleECGNaN(ii));
            dS.wavedet.MLI.Poff(idx2NaN) = NaN;
            % QRSon
            idx2NaN = find(dS.wavedet.MLI.QRSon >= inSampleECGNaN(ii) & dS.wavedet.MLI.QRSon <= outSampleECGNaN(ii));
            dS.wavedet.MLI.QRSon(idx2NaN) = NaN;
            % QRSoff
            idx2NaN = find(dS.wavedet.MLI.QRSoff >= inSampleECGNaN(ii) & dS.wavedet.MLI.QRSoff <= outSampleECGNaN(ii));
            dS.wavedet.MLI.QRSoff(idx2NaN) = NaN;
            % Ton
            idx2NaN = find(dS.wavedet.MLI.Ton >= inSampleECGNaN(ii) & dS.wavedet.MLI.Ton <= outSampleECGNaN(ii));
            dS.wavedet.MLI.Ton(idx2NaN) = NaN;
            % Toff
            idx2NaN = find(dS.wavedet.MLI.Toff >= inSampleECGNaN(ii) & dS.wavedet.MLI.Toff <= outSampleECGNaN(ii));
            dS.wavedet.MLI.Toff(idx2NaN) = NaN;
        end
    end
    
    % error correction by acceleration magnitude
    if errorCorrection.Accel_amplitude && ~isempty(accelmag)
        sampleRateFactor = getSampleRateFactor(ecgData, accelmag, jsondata);
        if sampleRateFactor == 10
            winSize = 25 - 1;
        else
            winSize = 42 - 1;
        end
        stepSize = round((winSize + 1) * 0.5);
        endIdx = length(accelmag);
        inSampleAccNaN = [];
        outSampleAccNaN = [];
        ii = 1;
        iiAccNan = 1;
        while ii <= endIdx
            if ii+winSize > endIdx
                ii = endIdx - winSize;
                stepSize = winSize + 1;
            end
            if nanmin(accelmag(ii:ii+winSize)) < 0.85 || nanmax(accelmag(ii:ii+winSize)) > 1.12 % < 0.85 || > 1.12
                % sample numbers converted to match ECG sample numbers
                inSampleAccNaN(iiAccNan) = ((ii-1)*sampleRateFactor) + 1;
                outSampleAccNaN(iiAccNan) = (ii+winSize)*sampleRateFactor;
                iiAccNan = iiAccNan + 1;
            end
            ii = ii + stepSize;
        end
        fprintf('errorCorrection.Accel_amplitude,  steps: %d,  NaN''s: %d\n',ii,length(inSampleAccNaN));
    else
        inSampleAccNaN = [];
        outSampleAccNaN = [];
    end
    % making sure the last index number is not out of bounds
    if errorCorrection.Accel_amplitude && ~isempty(accelmag) && ~isempty(inSampleAccNaN)
        if inSampleAccNaN(end) > length(ecgData)
            inSampleAccNaN(end) = length(ecgData);
        end
        if outSampleAccNaN(end) > length(ecgData)
            outSampleAccNaN(end) = length(ecgData);
        end
    end
    if errorCorrection.Accel_amplitude && ~isempty(accelmag) && ~isempty(inSampleAccNaN)
        for ii=1:length(inSampleAccNaN)
            % qrs
            idx2NaN = find(dS.wavedet.MLI.qrs >= inSampleAccNaN(ii) & dS.wavedet.MLI.qrs <= outSampleAccNaN(ii));
            dS.wavedet.MLI.qrs(idx2NaN) = NaN;
            % R
            idx2NaN = find(dS.wavedet.MLI.R >= inSampleAccNaN(ii) & dS.wavedet.MLI.R <= inSampleAccNaN(ii));
            dS.wavedet.MLI.R(idx2NaN) = NaN;
            % Pon
            idx2NaN = find(dS.wavedet.MLI.Pon >= inSampleAccNaN(ii) & dS.wavedet.MLI.Pon <= outSampleAccNaN(ii));
            dS.wavedet.MLI.Pon(idx2NaN) = NaN;
            % Poff
            idx2NaN = find(dS.wavedet.MLI.Poff >= inSampleAccNaN(ii) & dS.wavedet.MLI.Poff <= outSampleAccNaN(ii));
            dS.wavedet.MLI.Poff(idx2NaN) = NaN;
            % QRSon
            idx2NaN = find(dS.wavedet.MLI.QRSon >= inSampleAccNaN(ii) & dS.wavedet.MLI.QRSon <= outSampleAccNaN(ii));
            dS.wavedet.MLI.QRSon(idx2NaN) = NaN;
            % QRSoff
            idx2NaN = find(dS.wavedet.MLI.QRSoff >= inSampleAccNaN(ii) & dS.wavedet.MLI.QRSoff <= outSampleAccNaN(ii));
            dS.wavedet.MLI.QRSoff(idx2NaN) = NaN;
            % Ton
            idx2NaN = find(dS.wavedet.MLI.Ton >= inSampleAccNaN(ii) & dS.wavedet.MLI.Ton <= outSampleAccNaN(ii));
            dS.wavedet.MLI.Ton(idx2NaN) = NaN;
            % Toff
            idx2NaN = find(dS.wavedet.MLI.Toff >= inSampleAccNaN(ii) & dS.wavedet.MLI.Toff <= outSampleAccNaN(ii));
            dS.wavedet.MLI.Toff(idx2NaN) = NaN;
        end
    end
    
    % RR intervals in seconds.
    dS.wavedet.MLI.RR_intervals = (dS.wavedet.MLI.qrs(2:length(dS.wavedet.MLI.qrs)) - dS.wavedet.MLI.qrs(1:(length(dS.wavedet.MLI.qrs)-1)))./fs;
    % setting RR intervals that were calculated across a NaN section, to zero
    for i=1:length(dS.wavedet.MLI.RR_intervals)
        ecgIndexStart = dS.wavedet.MLI.qrs(i);
        ecgIndexEnd = dS.wavedet.MLI.qrs(i+1);
        if ~isnan(ecgIndexStart) && ~isnan(ecgIndexEnd) && ecgIndexEnd >= ecgIndexStart
%             fprintf('i: %d   idxStart: %d   idxEnd: %d   part1: %f   part2: %d\n', i, ecgIndexStart, ecgIndexEnd, dS.wavedet.MLI.RR_intervals(i), (1 - max(isnan(ecgData(ecgIndexStart:ecgIndexEnd,1)))));
            dS.wavedet.MLI.RR_intervals(i) = dS.wavedet.MLI.RR_intervals(i) * (1 - max(max(isnan(ecgData(ecgIndexStart:ecgIndexEnd,numEcgChannels)))));
        else
            dS.wavedet.MLI.RR_intervals(i) = NaN;
        end
    end
    % In case of meaningless RR_intervals of 0 seconds (e.g. incorrect QRS detection, or previous calc across NaN), set them to 'NaN'
    dS.wavedet.MLI.RR_intervals(dS.wavedet.MLI.RR_intervals <= 0) = NaN;
    % Error correction by NaN'ing RR_intervals unlikely to be true
    if errorCorrection.RR_intervals
        winSize = 3 - 1;
        stepSize = round((winSize + 1) * 0.75);
        endIdx = length(dS.wavedet.MLI.RR_intervals);
        % determine whether dS.wavedet.MLI.RR_intervals is a column or a row vector
        if size(dS.wavedet.MLI.RR_intervals,1) < size(dS.wavedet.MLI.RR_intervals,2)
            rowVector = true;
        else
            rowVector = false;
        end
        idxRRNaN = [];
        ii = 1;
        while ii <= endIdx
            if ii+winSize > endIdx
                ii = endIdx - winSize;
                stepSize = winSize + 1;
            end
            winMedian = median(dS.wavedet.MLI.RR_intervals(ii:ii+winSize),'omitnan');
            minLimHR = winMedian - (winMedian * 0.25);
            maxLimHR = winMedian + (winMedian * 0.25);
            winNaN = (ii - 1) + find(dS.wavedet.MLI.RR_intervals(ii:ii+winSize) < minLimHR | dS.wavedet.MLI.RR_intervals(ii:ii+winSize) > maxLimHR);
            if rowVector
                idxRRNaN = [idxRRNaN, winNaN];
            else
                idxRRNaN = [idxRRNaN; winNaN];
            end
        %     fprintf('ii: %d,  winMedian: %f,  winMin: %f,  winMax: %f,  idx2NaN: %s\n',ii,winMedian,nanmin(dS.wavedet.MLI.RR_intervals(ii:ii+winSize)),nanmax(dS.wavedet.MLI.RR_intervals(ii:ii+winSize)),mat2str(idx2NaN));
            ii = ii + stepSize;
        end
        dS.wavedet.MLI.RR_intervals(idxRRNaN) = NaN;
        dS.wavedet.MLI.R(idxRRNaN) = NaN;
        dS.wavedet.MLI.R(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.Pon(idxRRNaN) = NaN;
        dS.wavedet.MLI.Pon(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.Poff(idxRRNaN) = NaN;
        dS.wavedet.MLI.Poff(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.QRSon(idxRRNaN) = NaN;
        dS.wavedet.MLI.QRSon(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.QRSoff(idxRRNaN) = NaN;
        dS.wavedet.MLI.QRSoff(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.Ton(idxRRNaN) = NaN;
        dS.wavedet.MLI.Ton(idxRRNaN+1) = NaN;
        dS.wavedet.MLI.Toff(idxRRNaN) = NaN;
        dS.wavedet.MLI.Toff(idxRRNaN+1) = NaN;
        fprintf('errorCorrection.RR_intervals,  steps: %d,  NaN''s: %d\n',ii,length(idxRRNaN));
    else
        idxRRNaN = [];
    end
    
    % Additional error correction by inspecting very short RR_intervals
    if errorCorrection.RR_intervals
        % find RR-intervals < 0.3 seconds (HR > 200 bpm)
        RRidxToInspect = find(dS.wavedet.MLI.RR_intervals < 0.3);
        idxRRNaN2 = [];
        idxQRSNaN = [];
        for ii=1:length(RRidxToInspect)
            % the 2 points (beats), as 2d points [sampleNum ecgSampleValue]
            p1 = [dS.wavedet.MLI.qrs(RRidxToInspect(ii)) ecgData(dS.wavedet.MLI.qrs(RRidxToInspect(ii)),1)];
            p2 = [dS.wavedet.MLI.qrs(RRidxToInspect(ii)+1) ecgData(dS.wavedet.MLI.qrs(RRidxToInspect(ii)+1),1)];
            % median of ecg ch1 in a 5 sec window (if possible)
            ecgMedianWindow = [max(1,p1(1)-fs*2.5) min(length(ecgData),p2(1)+fs*2.5)];
            medEcg = median(ecgData(ecgMedianWindow(1):ecgMedianWindow(2),1),'omitnan');
            % amplitude of ecg ch1 in window just around (+/- 10 samples) the 2 points
            amplEcg = nanmax(ecgData(p1(1)-10:p2(1)+10,1)) - nanmin(ecgData(p1(1)-10:p2(1)+10,1));
            % Determine if one of the points are less than 20% of the ecg amplitude from the median.
            % If so, then the point is not likely to be a qrs peak.
            if abs(p2(2)-medEcg)/amplEcg < 0.2
                if rowVector
                    idxRRNaN2 = [idxRRNaN2, RRidxToInspect(ii)];
                    idxQRSNaN = [idxQRSNaN, RRidxToInspect(ii)+1];
                else
                    idxRRNaN2 = [idxRRNaN2; RRidxToInspect(ii)];
                    idxQRSNaN = [idxQRSNaN; RRidxToInspect(ii)+1];
                end
            elseif abs(p1(2)-medEcg)/amplEcg < 0.2
                if rowVector
                    idxRRNaN2 = [idxRRNaN2, RRidxToInspect(ii)];
                    idxQRSNaN = [idxQRSNaN, RRidxToInspect(ii)];
                else
                    idxRRNaN2 = [idxRRNaN2; RRidxToInspect(ii)];
                    idxQRSNaN = [idxQRSNaN, RRidxToInspect(ii)];
                end
            end
        end
        dS.wavedet.MLI.RR_intervals(idxRRNaN2) = NaN;
        dS.wavedet.MLI.qrs(idxQRSNaN) = NaN;
        dS.wavedet.MLI.R(idxQRSNaN) = NaN;
        dS.wavedet.MLI.Pon(idxQRSNaN) = NaN;
        dS.wavedet.MLI.Poff(idxQRSNaN) = NaN;
        dS.wavedet.MLI.QRSon(idxQRSNaN) = NaN;
        dS.wavedet.MLI.QRSoff(idxQRSNaN) = NaN;
        dS.wavedet.MLI.Ton(idxQRSNaN) = NaN;
        dS.wavedet.MLI.Toff(idxQRSNaN) = NaN;
        fprintf('errorCorrection.RR_intervals, (from RRi < 0.3)  steps: %d,  NaN''s: %d\n',ii,length(idxRRNaN2));
        % merge idxRRNaN2 and idxRRNaN
        for jj=1:length(idxRRNaN2)
           if isempty(find(idxRRNaN == idxRRNaN2(jj),1))
               idxRRNaN(end+1) = idxRRNaN2(jj);
           end
        end
    end

    % Heart rates beat-by-beat, in bpm
    dS.wavedet.MLI.HeartRates = 60./dS.wavedet.MLI.RR_intervals;
    % P durations in seconds
    dS.wavedet.MLI.P_durations = (dS.wavedet.MLI.Poff - dS.wavedet.MLI.Pon)./fs;
    % PR intervals in seconds
    dS.wavedet.MLI.PR_intervals = (dS.wavedet.MLI.QRSon - dS.wavedet.MLI.Pon)./fs;
    % QRS durations in seconds
    dS.wavedet.MLI.QRS_durations = (dS.wavedet.MLI.QRSoff - dS.wavedet.MLI.QRSon)./fs;
    % QT Intervals in seconds
    dS.wavedet.MLI.QT_intervals = (dS.wavedet.MLI.Toff - dS.wavedet.MLI.QRSon)./fs;
    % QTc Intervals (corrected QT) using Bazett's formula, QTc = QT/sqrt(RR). NOTICE: The last QT interval can not get a QTc, since it would require a QRS complex that is outside the end of the recording.
    dS.wavedet.MLI.QTcB_intervals = (dS.wavedet.MLI.QT_intervals(1:length(dS.wavedet.MLI.QT_intervals)-1))./sqrt(dS.wavedet.MLI.RR_intervals);
    % QTc Intervals (corrected QT) using Fridericia's formula
    dS.wavedet.MLI.QTcF_intervals = (dS.wavedet.MLI.QT_intervals(1:length(dS.wavedet.MLI.QT_intervals)-1))./nthroot(dS.wavedet.MLI.RR_intervals,3);
%         %--- MLII ---%
%         % RR intervals in seconds
%         dS.wavedet.MLII.RR_intervals = (dS.wavedet.MLII.QRSon(2:length(dS.wavedet.MLII.QRSon)) - dS.wavedet.MLII.QRSon(1:(length(dS.wavedet.MLII.QRSon)-1)))./fs;
%         % Heart rates beat-by-beat, in bpm
%         dS.wavedet.MLII.HeartRates = 60./dS.wavedet.MLII.RR_intervals;
%         % P durations in seconds
%         dS.wavedet.MLII.P_durations = (dS.wavedet.MLII.Poff - dS.wavedet.MLII.Pon)./fs;
%         % PR intervals in seconds
%         dS.wavedet.MLII.PR_intervals = (dS.wavedet.MLII.QRSon - dS.wavedet.MLII.Pon)./fs;
%         % QRS durations in seconds
%         dS.wavedet.MLII.QRS_durations = (dS.wavedet.MLII.QRSoff - dS.wavedet.MLII.QRSon)./fs;
%         % QT Intervals in seconds
%         dS.wavedet.MLII.QT_intervals = (dS.wavedet.MLII.Toff - dS.wavedet.MLII.QRSon)./fs;
%         % QTc Intervals (corrected QT) using Bazett's formula
%         dS.wavedet.MLII.QTcB_intervals = (dS.wavedet.MLII.QT_intervals(1:length(dS.wavedet.MLII.QT_intervals)-1))./sqrt(dS.wavedet.MLII.RR_intervals);
%         % QTc Intervals (corrected QT) using Fridericia's formula
%         dS.wavedet.MLII.QTcF_intervals = (dS.wavedet.MLII.QT_intervals(1:length(dS.wavedet.MLII.QT_intervals)-1))./nthroot(dS.wavedet.MLII.RR_intervals,3);
%         %--- MLIII ---%
%         % RR intervals in seconds
%         dS.wavedet.MLIII.RR_intervals = (dS.wavedet.MLIII.QRSon(2:length(dS.wavedet.MLIII.QRSon)) - dS.wavedet.MLIII.QRSon(1:(length(dS.wavedet.MLIII.QRSon)-1)))./fs;
%         % Heart rates beat-by-beat, in bpm
%         dS.wavedet.MLIII.HeartRates = 60./dS.wavedet.MLIII.RR_intervals;
%         % P durations in seconds
%         dS.wavedet.MLIII.P_durations = (dS.wavedet.MLIII.Poff - dS.wavedet.MLIII.Pon)./fs;
%         % PR intervals in seconds
%         dS.wavedet.MLIII.PR_intervals = (dS.wavedet.MLIII.QRSon - dS.wavedet.MLIII.Pon)./fs;
%         % QRS durations in seconds
%         dS.wavedet.MLIII.QRS_durations = (dS.wavedet.MLIII.QRSoff - dS.wavedet.MLIII.QRSon)./fs;
%         % QT Intervals in seconds
%         dS.wavedet.MLIII.QT_intervals = (dS.wavedet.MLIII.Toff - dS.wavedet.MLIII.QRSon)./fs;
%         % QTc Intervals (corrected QT) using Bazett's formula
%         dS.wavedet.MLIII.QTcB_intervals = (dS.wavedet.MLIII.QT_intervals(1:length(dS.wavedet.MLIII.QT_intervals)-1))./sqrt(dS.wavedet.MLIII.RR_intervals);
%         % QTc Intervals (corrected QT) using Fridericia's formula
%         dS.wavedet.MLIII.QTcF_intervals = (dS.wavedet.MLIII.QT_intervals(1:length(dS.wavedet.MLIII.QT_intervals)-1))./nthroot(dS.wavedet.MLIII.RR_intervals,3);

%%  %--- calculate mean values ---% %--- nanmean calculates mean after removing NaN values ---%
    %--- MLI ---%
    % P duration mean, in milliseconds
    dS.wavedet.MLI.P_duration_mean = nanmean(dS.wavedet.MLI.P_durations)*1000;
    % PR interval mean, in milliseconds
    dS.wavedet.MLI.PR_interval_mean = nanmean(dS.wavedet.MLI.PR_intervals)*1000;
    % QRS duration mean, in milliseconds
    dS.wavedet.MLI.QRS_duration_mean = nanmean(dS.wavedet.MLI.QRS_durations)*1000;
    % QT Interval mean, in milliseconds
    dS.wavedet.MLI.QT_interval_mean = nanmean(dS.wavedet.MLI.QT_intervals)*1000;
    % QTcB Interval mean, in milliseconds
    dS.wavedet.MLI.QTcB_interval_mean = nanmean(dS.wavedet.MLI.QTcB_intervals)*1000;
    % QTcF Interval mean, in milliseconds
    dS.wavedet.MLI.QTcF_interval_mean = nanmean(dS.wavedet.MLI.QTcF_intervals)*1000;
%         %--- MLII ---%
%         % Heart rate mean, in bpm
%         dS.wavedet.MLII.HeartRate_mean = nanmean(dS.wavedet.MLII.HeartRates);
%         % P duration mean, in milliseconds
%         dS.wavedet.MLII.P_duration_mean = nanmean(dS.wavedet.MLII.P_durations)*1000;
%         % PR interval mean, in milliseconds
%         dS.wavedet.MLII.PR_interval_mean = nanmean(dS.wavedet.MLII.PR_intervals)*1000;
%         % QRS duration mean, in milliseconds
%         dS.wavedet.MLII.QRS_duration_mean = nanmean(dS.wavedet.MLII.QRS_durations)*1000;
%         % QT Interval mean, in milliseconds
%         dS.wavedet.MLII.QT_interval_mean = nanmean(dS.wavedet.MLII.QT_intervals)*1000;
%         % QTcB Interval mean, in milliseconds
%         dS.wavedet.MLII.QTcB_interval_mean = nanmean(dS.wavedet.MLII.QTcB_intervals)*1000;
%         % QTcF Interval mean, in milliseconds
%         dS.wavedet.MLII.QTcF_interval_mean = nanmean(dS.wavedet.MLII.QTcF_intervals)*1000;
%         %--- MLIII ---%
%         % Heart rate mean, in bpm
%         dS.wavedet.MLIII.HeartRate_mean = nanmean(dS.wavedet.MLIII.HeartRates);
%         % P duration mean, in milliseconds
%         dS.wavedet.MLIII.P_duration_mean = nanmean(dS.wavedet.MLIII.P_durations)*1000;
%         % PR interval mean, in milliseconds
%         dS.wavedet.MLIII.PR_interval_mean = nanmean(dS.wavedet.MLIII.PR_intervals)*1000;
%         % QRS duration mean, in milliseconds
%         dS.wavedet.MLIII.QRS_duration_mean = nanmean(dS.wavedet.MLIII.QRS_durations)*1000;
%         % QT Interval mean, in milliseconds
%         dS.wavedet.MLIII.QT_interval_mean = nanmean(dS.wavedet.MLIII.QT_intervals)*1000;
%         % QTcB Interval mean, in milliseconds
%         dS.wavedet.MLIII.QTcB_interval_mean = nanmean(dS.wavedet.MLIII.QTcB_intervals)*1000;
%         % QTcF Interval mean, in milliseconds
%         dS.wavedet.MLIII.QTcF_interval_mean = nanmean(dS.wavedet.MLIII.QTcF_intervals)*1000;        
%         %--- Mean of means for MLI, MLII, MLII ---%
%         dS.wavedet.all.HeartRate_mean = mean([dS.wavedet.MLI.HeartRate_mean, dS.wavedet.MLII.HeartRate_mean, dS.wavedet.MLIII.HeartRate_mean]);
%         % P duration mean, in milliseconds
%         dS.wavedet.all.P_duration_mean = mean([dS.wavedet.MLI.P_duration_mean, dS.wavedet.MLII.P_duration_mean, dS.wavedet.MLIII.P_duration_mean]);
%         % PR interval mean, in milliseconds
%         dS.wavedet.all.PR_interval_mean = mean([dS.wavedet.MLI.PR_interval_mean, dS.wavedet.MLII.PR_interval_mean, dS.wavedet.MLIII.PR_interval_mean]);
%         % QRS duration mean, in milliseconds
%         dS.wavedet.all.QRS_duration_mean = mean([dS.wavedet.MLI.QRS_duration_mean, dS.wavedet.MLII.QRS_duration_mean, dS.wavedet.MLIII.QRS_duration_mean]);
%         % QT Interval mean, in milliseconds
%         dS.wavedet.all.QT_interval_mean = mean([dS.wavedet.MLI.QT_interval_mean, dS.wavedet.MLII.QT_interval_mean, dS.wavedet.MLIII.QT_interval_mean]);
%         % QTcB Interval mean, in milliseconds
%         dS.wavedet.all.QTcB_interval_mean = mean([dS.wavedet.MLI.QTcB_interval_mean, dS.wavedet.MLII.QTcB_interval_mean, dS.wavedet.MLIII.QTcB_interval_mean]);
%         % QTcF Interval mean, in milliseconds
%         dS.wavedet.all.QTcF_interval_mean = mean([dS.wavedet.MLI.QTcF_interval_mean, dS.wavedet.MLII.QTcF_interval_mean, dS.wavedet.MLIII.QTcF_interval_mean]);

%%  %--- find max values ---% %--- nanmax finds max after removing NaN values ---%
    %--- MLI ---%
    % P duration max, in milliseconds
    dS.wavedet.MLI.P_duration_max = nanmax(dS.wavedet.MLI.P_durations)*1000;
    % PR interval max, in milliseconds
    dS.wavedet.MLI.PR_interval_max = nanmax(dS.wavedet.MLI.PR_intervals)*1000;
    % QRS duration max, in milliseconds
    dS.wavedet.MLI.QRS_duration_max = nanmax(dS.wavedet.MLI.QRS_durations)*1000;
    % QT Interval max, in milliseconds
    dS.wavedet.MLI.QT_interval_max = nanmax(dS.wavedet.MLI.QT_intervals)*1000;
    % QTcB Interval max, in milliseconds
    dS.wavedet.MLI.QTcB_interval_max = nanmax(dS.wavedet.MLI.QTcB_intervals)*1000;
    % QTcF Interval max, in milliseconds
    dS.wavedet.MLI.QTcF_interval_max = nanmax(dS.wavedet.MLI.QTcF_intervals)*1000;
%         %--- MLII ---%
%         % Heart rate max, in bpm
%         dS.wavedet.MLII.HeartRate_max = nanmax(dS.wavedet.MLII.HeartRates);
%         % P duration max, in milliseconds
%         dS.wavedet.MLII.P_duration_max = nanmax(dS.wavedet.MLII.P_durations)*1000;
%         % PR interval max, in milliseconds
%         dS.wavedet.MLII.PR_interval_max = nanmax(dS.wavedet.MLII.PR_intervals)*1000;
%         % QRS duration max, in milliseconds
%         dS.wavedet.MLII.QRS_duration_max = nanmax(dS.wavedet.MLII.QRS_durations)*1000;
%         % QT Interval max, in milliseconds
%         dS.wavedet.MLII.QT_interval_max = nanmax(dS.wavedet.MLII.QT_intervals)*1000;
%         % QTcB Interval max, in milliseconds
%         dS.wavedet.MLII.QTcB_interval_max = nanmax(dS.wavedet.MLII.QTcB_intervals)*1000;
%         % QTcF Interval max, in milliseconds
%         dS.wavedet.MLII.QTcF_interval_max = nanmax(dS.wavedet.MLII.QTcF_intervals)*1000;
%         %--- MLIII ---%
%         % Heart rate max, in bpm
%         dS.wavedet.MLIII.HeartRate_max = nanmax(dS.wavedet.MLIII.HeartRates);
%         % P duration max, in milliseconds
%         dS.wavedet.MLIII.P_duration_max = nanmax(dS.wavedet.MLIII.P_durations)*1000;
%         % PR interval max, in milliseconds
%         dS.wavedet.MLIII.PR_interval_max = nanmax(dS.wavedet.MLIII.PR_intervals)*1000;
%         % QRS duration max, in milliseconds
%         dS.wavedet.MLIII.QRS_duration_max = nanmax(dS.wavedet.MLIII.QRS_durations)*1000;
%         % QT Interval max, in milliseconds
%         dS.wavedet.MLIII.QT_interval_max = nanmax(dS.wavedet.MLIII.QT_intervals)*1000;
%         % QTcB Interval max, in milliseconds
%         dS.wavedet.MLIII.QTcB_interval_max = nanmax(dS.wavedet.MLIII.QTcB_intervals)*1000;
%         % QTcF Interval max, in milliseconds
%         dS.wavedet.MLIII.QTcF_interval_max = nanmax(dS.wavedet.MLIII.QTcF_intervals)*1000;        
%         %--- max of maxs for MLI, MLII, MLII ---%
%         dS.wavedet.all.HeartRate_max = max([dS.wavedet.MLI.HeartRate_max, dS.wavedet.MLII.HeartRate_max, dS.wavedet.MLIII.HeartRate_max]);
%         % P duration max, in milliseconds
%         dS.wavedet.all.P_duration_max = max([dS.wavedet.MLI.P_duration_max, dS.wavedet.MLII.P_duration_max, dS.wavedet.MLIII.P_duration_max]);
%         % PR interval max, in milliseconds
%         dS.wavedet.all.PR_interval_max = max([dS.wavedet.MLI.PR_interval_max, dS.wavedet.MLII.PR_interval_max, dS.wavedet.MLIII.PR_interval_max]);
%         % QRS duration max, in milliseconds
%         dS.wavedet.all.QRS_duration_max = max([dS.wavedet.MLI.QRS_duration_max, dS.wavedet.MLII.QRS_duration_max, dS.wavedet.MLIII.QRS_duration_max]);
%         % QT Interval max, in milliseconds
%         dS.wavedet.all.QT_interval_max = max([dS.wavedet.MLI.QT_interval_max, dS.wavedet.MLII.QT_interval_max, dS.wavedet.MLIII.QT_interval_max]);
%         % QTcB Interval max, in milliseconds
%         dS.wavedet.all.QTcB_interval_max = max([dS.wavedet.MLI.QTcB_interval_max, dS.wavedet.MLII.QTcB_interval_max, dS.wavedet.MLIII.QTcB_interval_max]);
%         % QTcF Interval max, in milliseconds
%         dS.wavedet.all.QTcF_interval_max = max([dS.wavedet.MLI.QTcF_interval_max, dS.wavedet.MLII.QTcF_interval_max, dS.wavedet.MLIII.QTcF_interval_max]);

%%  %--- calculate min values ---% %--- nanmin calculates min after removing NaN values ---%
    %--- MLI ---%
    % P duration min, in milliseconds
    dS.wavedet.MLI.P_duration_min = nanmin(dS.wavedet.MLI.P_durations)*1000;
    % PR interval min, in milliseconds
    dS.wavedet.MLI.PR_interval_min = nanmin(dS.wavedet.MLI.PR_intervals)*1000;
    % QRS duration min, in milliseconds
    dS.wavedet.MLI.QRS_duration_min = nanmin(dS.wavedet.MLI.QRS_durations)*1000;
    % QT Interval min, in milliseconds
    dS.wavedet.MLI.QT_interval_min = nanmin(dS.wavedet.MLI.QT_intervals)*1000;
    % QTcB Interval min, in milliseconds
    dS.wavedet.MLI.QTcB_interval_min = nanmin(dS.wavedet.MLI.QTcB_intervals)*1000;
    % QTcF Interval min, in milliseconds
    dS.wavedet.MLI.QTcF_interval_min = nanmin(dS.wavedet.MLI.QTcF_intervals)*1000;
%         %--- MLII ---%
%         % Heart rate min, in bpm
%         dS.wavedet.MLII.HeartRate_min = nanmin(dS.wavedet.MLII.HeartRates);
%         % P duration min, in milliseconds
%         dS.wavedet.MLII.P_duration_min = nanmin(dS.wavedet.MLII.P_durations)*1000;
%         % PR interval min, in milliseconds
%         dS.wavedet.MLII.PR_interval_min = nanmin(dS.wavedet.MLII.PR_intervals)*1000;
%         % QRS duration min, in milliseconds
%         dS.wavedet.MLII.QRS_duration_min = nanmin(dS.wavedet.MLII.QRS_durations)*1000;
%         % QT Interval min, in milliseconds
%         dS.wavedet.MLII.QT_interval_min = nanmin(dS.wavedet.MLII.QT_intervals)*1000;
%         % QTcB Interval min, in milliseconds
%         dS.wavedet.MLII.QTcB_interval_min = nanmin(dS.wavedet.MLII.QTcB_intervals)*1000;
%         % QTcF Interval min, in milliseconds
%         dS.wavedet.MLII.QTcF_interval_min = nanmin(dS.wavedet.MLII.QTcF_intervals)*1000;
%         %--- MLIII ---%
%         % Heart rate min, in bpm
%         dS.wavedet.MLIII.HeartRate_min = nanmin(dS.wavedet.MLIII.HeartRates);
%         % P duration min, in milliseconds
%         dS.wavedet.MLIII.P_duration_min = nanmin(dS.wavedet.MLIII.P_durations)*1000;
%         % PR interval min, in milliseconds
%         dS.wavedet.MLIII.PR_interval_min = nanmin(dS.wavedet.MLIII.PR_intervals)*1000;
%         % QRS duration min, in milliseconds
%         dS.wavedet.MLIII.QRS_duration_min = nanmin(dS.wavedet.MLIII.QRS_durations)*1000;
%         % QT Interval min, in milliseconds
%         dS.wavedet.MLIII.QT_interval_min = nanmin(dS.wavedet.MLIII.QT_intervals)*1000;
%         % QTcB Interval min, in milliseconds
%         dS.wavedet.MLIII.QTcB_interval_min = nanmin(dS.wavedet.MLIII.QTcB_intervals)*1000;
%         % QTcF Interval min, in milliseconds
%         dS.wavedet.MLIII.QTcF_interval_min = nanmin(dS.wavedet.MLIII.QTcF_intervals)*1000;        
%         %--- min of mins for MLI, MLII, MLII ---%
%         dS.wavedet.all.HeartRate_min = min([dS.wavedet.MLI.HeartRate_min, dS.wavedet.MLII.HeartRate_min, dS.wavedet.MLIII.HeartRate_min]);
%         % P duration min, in milliseconds
%         dS.wavedet.all.P_duration_min = min([dS.wavedet.MLI.P_duration_min, dS.wavedet.MLII.P_duration_min, dS.wavedet.MLIII.P_duration_min]);
%         % PR interval min, in milliseconds
%         dS.wavedet.all.PR_interval_min = min([dS.wavedet.MLI.PR_interval_min, dS.wavedet.MLII.PR_interval_min, dS.wavedet.MLIII.PR_interval_min]);
%         % QRS duration min, in milliseconds
%         dS.wavedet.all.QRS_duration_min = min([dS.wavedet.MLI.QRS_duration_min, dS.wavedet.MLII.QRS_duration_min, dS.wavedet.MLIII.QRS_duration_min]);
%         % QT Interval min, in milliseconds
%         dS.wavedet.all.QT_interval_min = min([dS.wavedet.MLI.QT_interval_min, dS.wavedet.MLII.QT_interval_min, dS.wavedet.MLIII.QT_interval_min]);
%         % QTcB Interval min, in milliseconds
%         dS.wavedet.all.QTcB_interval_min = min([dS.wavedet.MLI.QTcB_interval_min, dS.wavedet.MLII.QTcB_interval_min, dS.wavedet.MLIII.QTcB_interval_min]);
%         % QTcF Interval min, in milliseconds
%         dS.wavedet.all.QTcF_interval_min = min([dS.wavedet.MLI.QTcF_interval_min, dS.wavedet.MLII.QTcF_interval_min, dS.wavedet.MLIII.QTcF_interval_min]);

    %--- RR interval mean, for succesive 5 minute segments ---%
    % IF DURATION OF RECORDING IS AT LEAST 5 MINS LONG (300 sec)
    if recordingDuration >= 300
        numIndices5mins = 300*fs; % 5 mins (300 sec) with 250Hz sampling rate span 75000 indices.
        dS.index5mins = 1:numIndices5mins:(dS.wavedet.MLI.qrs(end));
        indexStart5mins = 1;
        indexEnd5mins = indexStart5mins + numIndices5mins;
        timeIndexStart = 1; % dS.wavedet.MLI.QRSon(1);
%         timeIndexOfEndBeat = dS.wavedet.MLI.QRSon(length(dS.wavedet.MLI.QRSon)); %OLD
        % Need to find an end QRSon that is not NaN
        j = length(dS.wavedet.MLI.qrs);
        while isnan(dS.wavedet.MLI.qrs(j)) && j > 1
            j = j - 1;
        end
        timeIndexOfEndBeat = dS.wavedet.MLI.qrs(j);
        if ~isnan(dS.wavedet.MLI.qrs(j)) && timeIndexOfEndBeat >= indexEnd5mins
            i = 1;
            while indexEnd5mins <= timeIndexOfEndBeat
                timeIndexNextStart = find(dS.wavedet.MLI.qrs > indexEnd5mins, 1);
                timeIndexEnd = timeIndexNextStart - 1;
    %                 fprintf('i: %d   timeIndexStart: %d    timeIndexEnd: %d   indexStart5mins: %d   indexEnd5mins: %d\n',i ,timeIndexStart, timeIndexEnd, indexStart5mins, indexEnd5mins);
                if timeIndexEnd < timeIndexStart
                    indexStart5mins = indexEnd5mins;
                    indexEnd5mins = indexStart5mins + numIndices5mins;
                    dS.ARR_5min(i) = 0;
                    dS.ProcTime_5min(i) = 0;
                    i = i + 1;
                    continue;
                end
    %                 dS.index5mins(i) = indexEnd5mins;
    %                 fprintf('i: %d   timeIndexStart: %d    timeIndexEnd: %d   indexStart5mins: %d   indexEnd5mins: %d\n',i ,timeIndexStart, timeIndexEnd, indexStart5mins, indexEnd5mins);
                %  Mean RR interval time for 5 min segment, in milliseconds
                dS.ARR_5min(i) = nanmean(1000*dS.wavedet.MLI.RR_intervals(timeIndexStart:timeIndexEnd-1));
                % Proc. Time - the amount of time included in dS.ARR_5min(i), in seconds
                dS.ProcTime_5min(i) = ((dS.wavedet.MLI.qrs(timeIndexEnd-1) - dS.wavedet.MLI.qrs(timeIndexStart))/fs);
                timeIndexStart = timeIndexNextStart;
                indexStart5mins = indexEnd5mins;
                indexEnd5mins = indexStart5mins + numIndices5mins;
                i = i + 1;
            end
        else
            warning('Although recording >= 5 mins, a valid QRS can not be found at a time >= 5 mins! Try adjusting error correction settings.');
        end
    end

    %--- RR interval mean, for succesive 15 second segments ---%
    % Used for selecting events of interest, for the Full-Sized Strips,
    % and for statistics about min, avg, max HR.
    % IF DURATION OF RECORDING IS AT LEAST 30 SECONDS
    if recordingDuration >= 30
        numIndices15sec = round(15*fs); % 15 seconds with 250Hz sampling rate span 3750 indices.
        dS.index15sec = 1:numIndices15sec:(dS.wavedet.MLI.qrs(end)); %REMOVE ? %
        indexStart15sec = 1;
        indexEnd15sec = indexStart15sec + numIndices15sec; %  - 1
        timeIndexStart = 1;
        % Need to find an end qrs that is not NaN
        j = length(dS.wavedet.MLI.qrs);
        while isnan(dS.wavedet.MLI.qrs(j)) && j > 1
            j = j - 1;
        end
        timeIndexOfEndBeat = dS.wavedet.MLI.qrs(j);
        if ~isnan(dS.wavedet.MLI.qrs(j)) && timeIndexOfEndBeat >= indexEnd15sec
            i = 1;
            while indexEnd15sec <= timeIndexOfEndBeat
                timeIndexNextStart = find(dS.wavedet.MLI.qrs > indexEnd15sec, 1);
                timeIndexEnd = timeIndexNextStart - 1;
                if timeIndexEnd < timeIndexStart
                    indexStart15sec = indexEnd15sec;
                    indexEnd15sec = indexStart15sec + numIndices15sec - 1; %  -1
                    dS.ARR_15sec(i) = NaN;
                    dS.startIndex_15sec(i) = indexStart15sec;
                    dS.endIndex_15sec(i) = indexEnd15sec;
                    dS.nanRatio_15sec(i) = 1.0;
                    i = i + 1;
                    continue;
                end
    %                 dS.index15sec(i) = indexEnd15sec;
    %             fprintf('i_15sec: %d   15sec_timeIndexStart: %d   15sec_timeIndexEnd: %d   indexStart15sec: %d   15sec_indexEnd15sec %d\n',i,timeIndexStart,timeIndexEnd,indexStart15sec,indexEnd15sec);
                %  Mean RR interval time for 15 sec segment, in milliseconds
                dS.ARR_15sec(i) = nanmean(1000*dS.wavedet.MLI.RR_intervals(timeIndexStart:timeIndexEnd));
                % What is the ratio of RR_intervals that are NaN, in this span
                numIntervals = length(timeIndexStart:timeIndexEnd);
                numNaN = sum(isnan(dS.wavedet.MLI.RR_intervals(timeIndexStart:timeIndexEnd)));
                if numIntervals > 0
                    dS.nanRatio_15sec(i) = numNaN/numIntervals;
                else
                    dS.nanRatio_15sec(i) = 1.0;
                end
                % The sample index numbers for the start and end of each 15 sec period
                dS.startIndex_15sec(i) = indexStart15sec;
                dS.endIndex_15sec(i) = indexEnd15sec;
                timeIndexStart = timeIndexNextStart;
                indexStart15sec = indexEnd15sec;
                indexEnd15sec = indexStart15sec + numIndices15sec;
                i = i + 1;
            end
        else
            warning('Although recording >= 15 secs, a valid QRS can not be found at a time >= 15 secs! Try adjusting error correction settings.');
        end

        % HR min, avg, and max are calculated from 5 or 15 sec segments, not from just one pair of beats.
        % Copy ARR_15sec to tmpARR and remove occurences where nanRatio was > ratioLim
        ratioLim = 0.2;
        if isfield(dS,'ARR_15sec')
            dS.ARR_15sec(dS.nanRatio_15sec > ratioLim) = NaN;
            % Remove any negative ARR_15sec values (shouldn't exist, so print a message if they do)
            if sum(dS.ARR_15sec < 0)
                dS.ARR_15sec(dS.ARR_15sec < 0) = NaN;
                fprintf('Negative values found in dS.ARR_15sec!\n');
            end
            % Heart rate min, in bpm
            dS.wavedet.MLI.HeartRate_min = 60000/nanmax(dS.ARR_15sec);
            % Heart rate mean, in bpm
            dS.wavedet.MLI.HeartRate_mean = 60000/nanmean(dS.ARR_15sec);
            % Heart rate max, in bpm
            dS.wavedet.MLI.HeartRate_max = 60000/nanmin(dS.ARR_15sec);
        else
            dS.wavedet.MLI.HeartRate_min = NaN;
            dS.wavedet.MLI.HeartRate_mean = NaN;
            dS.wavedet.MLI.HeartRate_max = NaN;
        end
    end
end

%% Classification based statistics
function cS = calculateClassificationStats(cS, dS, recordingDuration, fs, errorCorrection, idxRRNaN, inSampleECGNaN, outSampleECGNaN, inSampleAccNaN, outSampleAccNaN, noisyQRSidx)
    if errorCorrection.ECG_amplitude && ~isempty(inSampleECGNaN)
        % Remove classification indices
        for ii=1:length(inSampleECGNaN)
            idx2NaN = find(cS.time >= inSampleECGNaN(ii) & cS.time <= outSampleECGNaN(ii));
            cS.anntyp(idx2NaN) = '|';
%             cS.time(idx2NaN) = NaN;
        end
    end

    if errorCorrection.Accel_amplitude && ~isempty(inSampleAccNaN)
        % Remove classification indices
        for ii=1:length(inSampleAccNaN)
            idx2NaN = find(cS.time >= inSampleAccNaN(ii) & cS.time <= outSampleAccNaN(ii));
            cS.anntyp(idx2NaN) = '|';
%             cS.time(idx2NaN) = NaN;
        end
    end

    if errorCorrection.RR_intervals
        % Remove classification indices
        csIdxNotFound = 0;
        csIdxRemoved = 0;
        for ii=1:length(idxRRNaN)
            idxMLIqrs = [dS.wavedet.MLI.qrs(idxRRNaN) dS.wavedet.MLI.qrs(idxRRNaN+1)];
            idxCS = find(cS.time == idxMLIqrs(1),1);
            if ~isempty(idxCS)
                cS.anntyp(idxCS) = '|';
%                 cS.time(idxCS) = NaN;
                csIdxRemoved = csIdxRemoved + 1;
            else
                csIdxNotFound = csIdxNotFound + 1;
            end
            idxCS = find(cS.time == idxMLIqrs(2),1);
            if ~isempty(idxCS)
                cS.anntyp(idxCS) = '|';
%                 cS.time(idxCS) = NaN;
                csIdxRemoved = csIdxRemoved + 1;
            else
                csIdxNotFound = csIdxNotFound + 1;
            end
        end
        fprintf('\nNumber of cS indices removed, for RRi: %d\n',csIdxRemoved);
        fprintf('Number of cS indices NOT found (removed already): %d\n\n',csIdxNotFound);
    end
    
    if errorCorrection.ECG_noise
        csIdxNotFoundForNoisyQRS = 0;
        csIdxRemoved = 0;
        for ii=1:length(noisyQRSidx)
            idxCS = find(cS.time == noisyQRSidx(ii));
            % Remove this classification instance (May cause trouble! Consider setting to 'U' instead of removing)
            if ~isempty(idxCS)
                cS.anntyp(idxCS) = '|';
%                 cS.time(idxCS) = NaN;
                csIdxRemoved = csIdxRemoved + 1;
            else
                csIdxNotFoundForNoisyQRS = csIdxNotFoundForNoisyQRS + 1;
            end
        end
        fprintf('Number of cS indices removed, for noisy qrs: %d\n',csIdxRemoved);
        fprintf('Number of cS indices NOT found (removed already): %d\n\n',csIdxNotFoundForNoisyQRS);
    end
    
    % --- Indices and number of occurences of the various heartbeat classes --- %
    cS.idxClassF = find(cS.anntyp == 'F'); % F = fusion of normal and ventricular
    cS.idxClassN = find(cS.anntyp == 'N'); % N = normal
    cS.idxClassS = find(cS.anntyp == 'S'); % S = supraventricular
    cS.idxClassU = find(cS.anntyp == 'U'); % U = unclassified ?
    cS.idxClassV = find(cS.anntyp == 'V'); % V = ventricular
    % --- NN intervals, the time between adjacent pairs of Normal heartbeats --- %
    % First create an array, same length as 'cS.anntyp', to numerically
    % represent indices of 'N's.  'N' = 1. Others = 0.
    annNum(1:length(cS.anntyp)) = 0;
    annNum(cS.idxClassN) = 1;
    % calculate sum between pairs of annNum numbers.
    idxNsum = annNum(2:length(annNum)) + annNum(1:length(annNum)-1);
    % find the indices where sum was 2. These index numbers point to 'N's that has an 'N' next to it (on the right side). 
    cS.idxNN = find(idxNsum == 2);
    % store NN interval times (in seconds) in cS struct
    cS.NN_intervals = (cS.time(cS.idxNN+1) - cS.time(cS.idxNN))./fs;
    % --- SDNN, standard deviation of NN intervals, in milliseconds --- %
    cS.SDNN = std((cS.NN_intervals).*1000);
    % --- NN50, the number of pairs of successive NNs that differ by more than 50 ms --- %
    cS.NNdiff = diff((cS.NN_intervals).*1000);
    cS.NN50 = length(find(cS.NNdiff > 50));
    % --- pNN50, the proportion of NN50 divided by total number of NNs --- %
    cS.pNN50 = (cS.NN50/length(cS.NN_intervals)) * 100;
    % --- SDSD, the standard deviation of the successive differences between adjacent NNs ---%
    cS.SDSD = std(cS.NNdiff);
    % --- RMSSD, the square root of the mean of the squares of the successive differences between adjacent NNs --- %
    cS.RMSSD = sqrt((mean((cS.NNdiff).^2)));
    % IF DURATION OF RECORDING IS AT LEAST 5 MINS LONG (300 sec)
    if recordingDuration >= 300
        % --- SDANN, the standard deviation of the average NN intervals calculated over short periods, usually 5 minutes --- %
        numIndices5mins = 300*fs; % 5 mins (300 sec) with 250Hz sampling rate span 75000 indices.
        cS.index5mins = 1:numIndices5mins:cS.time(length(cS.time));
        indexStart5mins = 1;
        indexEnd5mins = indexStart5mins + numIndices5mins;
        timeIndexStart = 1; % cS.time(1)
        timeIndexOfEndBeat = cS.time(length(cS.time));
        i = 1;
        while indexEnd5mins <= timeIndexOfEndBeat
            timeIndexNextStart = find(cS.time > indexEnd5mins, 1);
            timeIndexEnd = timeIndexNextStart - 1;
%                 fprintf('i_cS: %d   cS.timeIndexStart: %d   cS.timeIndexEnd: %d   cS.indexStart5mins: %d   cS.indexEnd5mins %d\n',i,timeIndexStart,timeIndexEnd,indexStart5mins,indexEnd5mins);
            if timeIndexEnd == 0
                indexStart5mins = indexEnd5mins;
                indexEnd5mins = indexStart5mins + numIndices5mins;
                cS.ANN_5min(i) = 0;
                cS.SDNN_5min(i) = 0;
                cS.SDSD_5min(i) = 0;
                cS.NN_5min(i) = 0;
                cS.NN50_5min(i) = 0;
                cS.pNN50_5min(i) = 0;
                i = i + 1;
                continue;
            end
%                 cS.index5mins(i) = timeIndexEnd; %CHECK!%
            NNidxEnd = find(cS.idxNN > timeIndexEnd,1);
            NNidxEnd = NNidxEnd - 1;
            NNidxStart = find(cS.idxNN > timeIndexStart,1);
            NNidxStart = max(1,NNidxStart - 1);
            if ~isempty(NNidxStart) && ~isempty(NNidxEnd)
                cS.ANN_5min(i) = mean(cS.NN_intervals(NNidxStart:NNidxEnd))*1000; % average duration of NN intervals, in milliseconds, for every 5 mins
                cS.SDNN_5min(i) = std(cS.NN_intervals(NNidxStart:NNidxEnd))*1000; % standard deviation of NN intervals, in milliseconds, for every 5 mins
                cS.SDSD_5min(i) = std(cS.NNdiff(NNidxStart:NNidxEnd-1)); % cS.NNdiff is already in milliseconds
                cS.NN_5min(i) = length(cS.NN_intervals(NNidxStart:NNidxEnd)); % count of NN-pairs for every 5 minutes
                cS.NN50_5min(i) = length(find(cS.NNdiff(NNidxStart:NNidxEnd) > 50)); % count of successive NNs that differ by more than 50 ms, for every 5 minutes
                cS.pNN50_5min(i) = (cS.NN50_5min(i)/cS.NN_5min(i)) * 100;
                timeIndexStart = timeIndexNextStart;
                indexStart5mins = indexEnd5mins;
                indexEnd5mins = indexStart5mins + numIndices5mins;
                i = i + 1;
            else
                indexStart5mins = indexEnd5mins;
                indexEnd5mins = indexStart5mins + numIndices5mins;
                cS.ANN_5min(i) = 0;
                cS.SDNN_5min(i) = 0;
                cS.SDSD_5min(i) = 0;
                cS.NN_5min(i) = 0;
                cS.NN50_5min(i) = 0;
                cS.pNN50_5min(i) = 0;
                i = i + 1;
                continue;
            end
%                 fprintf('i_cS: %d   NNidxStart: %d   NNidxEnd: %d\n',i,NNidxStart,NNidxEnd);
        end
        cS.SDANN = std(cS.ANN_5min);
        % --- SDNNindex, the mean of all the 5-minute standard deviations of NN intervals during the (typically) 24-hour period --- %
        cS.SDNN_index = mean(cS.SDNN_5min);
    end
end

%% Save stats to txt file (may be redundant)
function saveStatsToTxt(dS, recordingDuration, file_path, filename_wo_extension)
    exportFid = fopen(fullfile(file_path, [filename_wo_extension '_stats.txt']),'w');
    % first in the txt file, write name of BLE file
    fprintf(exportFid,'%s     ',[filename_wo_extension '.BLE']);
    % info about length of recording
    hms = fix(mod(recordingDuration, [0, 3600, 60]) ./ [3600, 60, 1]);
    fprintf(exportFid,'%s %d hrs, %d min, %d sec.\n','Duration of recording:',hms(1),hms(2),hms(3));
    % the stats
    fprintf(exportFid,'\n');
    fprintf(exportFid,'Mean values for entire recording:\n');
    fprintf(exportFid,'                      MLI    MLII   MLII   mean(MLI,MLII,MLIII)\n');
    fprintf(exportFid,'Heart rate   (bpm): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.HeartRate_mean, dS.wavedet.MLII.HeartRate_mean, dS.wavedet.MLIII.HeartRate_mean, dS.wavedet.all.HeartRate_mean);
    fprintf(exportFid,'P duration    (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.P_duration_mean, dS.wavedet.MLII.P_duration_mean, dS.wavedet.MLIII.P_duration_mean, dS.wavedet.all.P_duration_mean);
    fprintf(exportFid,'PR interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.PR_interval_mean, dS.wavedet.MLII.PR_interval_mean, dS.wavedet.MLIII.PR_interval_mean, dS.wavedet.all.PR_interval_mean);
    fprintf(exportFid,'QRS duration  (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QRS_duration_mean, dS.wavedet.MLII.QRS_duration_mean, dS.wavedet.MLIII.QRS_duration_mean, dS.wavedet.all.QRS_duration_mean);
    fprintf(exportFid,'QT interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QT_interval_mean, dS.wavedet.MLII.QT_interval_mean, dS.wavedet.MLIII.QT_interval_mean, dS.wavedet.all.QT_interval_mean);
    fprintf(exportFid,'QTcB interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcB_interval_mean, dS.wavedet.MLII.QTcB_interval_mean, dS.wavedet.MLIII.QTcB_interval_mean, dS.wavedet.all.QTcB_interval_mean);
    fprintf(exportFid,'QTcF interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcF_interval_mean, dS.wavedet.MLII.QTcF_interval_mean, dS.wavedet.MLIII.QTcF_interval_mean, dS.wavedet.all.QTcF_interval_mean);
    fprintf(exportFid,'\n');
    fprintf(exportFid,'Min values for entire recording:\n');
    fprintf(exportFid,'                      MLI    MLII   MLII   min(MLI,MLII,MLIII)\n');
    fprintf(exportFid,'Heart rate   (bpm): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.HeartRate_min, dS.wavedet.MLII.HeartRate_min, dS.wavedet.MLIII.HeartRate_min, dS.wavedet.all.HeartRate_min);
    fprintf(exportFid,'P duration    (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.P_duration_min, dS.wavedet.MLII.P_duration_min, dS.wavedet.MLIII.P_duration_min, dS.wavedet.all.P_duration_min);
    fprintf(exportFid,'PR interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.PR_interval_min, dS.wavedet.MLII.PR_interval_min, dS.wavedet.MLIII.PR_interval_min, dS.wavedet.all.PR_interval_min);
    fprintf(exportFid,'QRS duration  (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QRS_duration_min, dS.wavedet.MLII.QRS_duration_min, dS.wavedet.MLIII.QRS_duration_min, dS.wavedet.all.QRS_duration_min);
    fprintf(exportFid,'QT interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QT_interval_min, dS.wavedet.MLII.QT_interval_min, dS.wavedet.MLIII.QT_interval_min, dS.wavedet.all.QT_interval_min);
    fprintf(exportFid,'QTcB interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcB_interval_min, dS.wavedet.MLII.QTcB_interval_min, dS.wavedet.MLIII.QTcB_interval_min, dS.wavedet.all.QTcB_interval_min);
    fprintf(exportFid,'QTcF interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcF_interval_min, dS.wavedet.MLII.QTcF_interval_min, dS.wavedet.MLIII.QTcF_interval_min, dS.wavedet.all.QTcF_interval_min);
    fprintf(exportFid,'\n');
    fprintf(exportFid,'Max values for entire recording:\n');
    fprintf(exportFid,'                      MLI    MLII   MLII   max(MLI,MLII,MLIII)\n');
    fprintf(exportFid,'Heart rate   (bpm): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.HeartRate_max, dS.wavedet.MLII.HeartRate_max, dS.wavedet.MLIII.HeartRate_max, dS.wavedet.all.HeartRate_max);
    fprintf(exportFid,'P duration    (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.P_duration_max, dS.wavedet.MLII.P_duration_max, dS.wavedet.MLIII.P_duration_max, dS.wavedet.all.P_duration_max);
    fprintf(exportFid,'PR interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.PR_interval_max, dS.wavedet.MLII.PR_interval_max, dS.wavedet.MLIII.PR_interval_max, dS.wavedet.all.PR_interval_max);
    fprintf(exportFid,'QRS duration  (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QRS_duration_max, dS.wavedet.MLII.QRS_duration_max, dS.wavedet.MLIII.QRS_duration_max, dS.wavedet.all.QRS_duration_max);
    fprintf(exportFid,'QT interval   (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QT_interval_max, dS.wavedet.MLII.QT_interval_max, dS.wavedet.MLIII.QT_interval_max, dS.wavedet.all.QT_interval_max);
    fprintf(exportFid,'QTcB interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcB_interval_max, dS.wavedet.MLII.QTcB_interval_max, dS.wavedet.MLIII.QTcB_interval_max, dS.wavedet.all.QTcB_interval_max);
    fprintf(exportFid,'QTcF interval (ms): %5.0f  %5.0f  %5.0f  %5.0f\n',dS.wavedet.MLI.QTcF_interval_max, dS.wavedet.MLII.QTcF_interval_max, dS.wavedet.MLIII.QTcF_interval_max, dS.wavedet.all.QTcF_interval_max);
    fclose(exportFid);
end
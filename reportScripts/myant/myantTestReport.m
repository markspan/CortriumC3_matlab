
function pdf_fullpath = myantTestReport(jsondata, ble_fullpath)
    % get path of Cortrium Matlab scripts folder
    cortrium_matlab_scripts_root_path = getCortriumScriptsRoot;
    
    % pdf toolkit path
    pdftk_exe = ['"' cortrium_matlab_scripts_root_path '\bin\pdftk.exe"'];
    
    % read BLE file
    [ble_path,ble_filename_wo_extension,ble_extension] = fileparts(ble_fullpath);
    if exist(ble_fullpath, 'file') == 2
        % NOTE: An assumption is made, that this is a version of the BLE
        % file, where ECG and Resp is stored as 24bit per sample.
        [serialNumber, conf, serial_ADS, leadoff, acc, temp, resp, ecg, ecg_serials] = c3_read_ble_24bit(ble_fullpath);
    else
        error(['BLE file: ' ble_filename_wo_extension ble_extension ' does not exist at path ' ble_path]);
    end
    
    % Export ecg and accel in csv files
    csv_ecg_fullpath = [ble_path filesep ble_filename_wo_extension '_ecg.csv'];
    csv_accel_fullpath = [ble_path filesep ble_filename_wo_extension '_accel.csv'];
    csv_all_data_fullpath = [ble_path filesep ble_filename_wo_extension '.csv'];
    csvwrite(csv_ecg_fullpath, ecg);
    csvwrite(csv_accel_fullpath, acc);
    c3_csv(csv_all_data_fullpath,temp,acc,resp,ecg);
    
    % get event markers from json data
    if ~isempty(jsondata) && ~isempty(jsondata.events)
        numEvents = size(jsondata.events,2);
        if numEvents > 0
            eventMarker = cell(numEvents,5);
            for ii=1:numEvents
                % Event, index number for Accel data
                eventMarker{ii,1} = jsondata.events{1,ii}.serial;
                % Event, index number for ECG data
                eventMarker{ii,2} = jsondata.events{1,ii}.serial * 6;
                % Event, description
                eventMarker{ii,3} = jsondata.events{1,ii}.eventname;
                % Event, leadoff percentage and packet loss, from this event to the next (if any next event)
                if ii < numEvents
                    countPackets = jsondata.events{1,ii+1}.serial - jsondata.events{1,ii}.serial;
                    countEmptyPackets = length(find(serialNumber(jsondata.events{1,ii}.serial:jsondata.events{1,ii+1}.serial-1) == 0));
                    countFullPackets = countPackets - countEmptyPackets;
                    countLeadoff = length(find(leadoff(jsondata.events{1,ii}.serial:jsondata.events{1,ii+1}.serial-1) > 0));
                    % leadoff percentage (calculated only from non-lost packets)
                    if countFullPackets > 0 && countLeadoff > 0
                        eventMarker{ii,4} = (double(countLeadoff)/double(countFullPackets)) * 100;
                    else
                        eventMarker{ii,4} = 0;
                    end
                    % packet loss percentage
                    if countPackets > 0 && countEmptyPackets > 0
                        eventMarker{ii,5} = (double(countEmptyPackets)/double(countPackets)) * 100;
                    else
                        eventMarker{ii,5} = 0;
                    end
                % leadoff percentage and packet loss, from last event to end of recording
                else
                    countPackets = length(serialNumber) - jsondata.events{1,ii}.serial;
                    countEmptyPackets = length(find(serialNumber(jsondata.events{1,ii}.serial:end-1) == 0));
                    countFullPackets = countPackets - countEmptyPackets;
                    countLeadoff = length(find(leadoff(jsondata.events{1,ii}.serial:end-1) > 0));                    
                    % leadoff percentage (calculated only from non-lost packets)
                    if countFullPackets > 0 && countLeadoff > 0
                        eventMarker{ii,4} = (double(countLeadoff)/double(countFullPackets)) * 100;
                    else
                        eventMarker{ii,4} = 0;
                    end
                    % packet loss percentage
                    if countPackets > 0 && countEmptyPackets > 0
                        eventMarker{ii,5} = (double(countEmptyPackets)/double(countPackets)) * 100;
                    else
                        eventMarker{ii,5} = 0;
                    end
                end
            end
        else
            eventMarker{1,1} = [];
        end
    else
        eventMarker{1,1} = [];
    end
    
    % add a jsondata field, that we currently don't have, but are using
    jsondata.report_type = 'Cortrium_test_report';
    
    % load Cortrium logo image
    logo_cortrium_path = [cortrium_matlab_scripts_root_path '\bin\Cortrium_logo_w_pod_746x219px.png'];
    if exist(logo_cortrium_path, 'file') == 2
        [logoCortriumImgData.img, logoCortriumImgData.map, logoCortriumImgData.alpha] = imread(logo_cortrium_path);
    else
        warning(['No Cortrium logo file at: ' logo_cortrium_path]);
        logoCortriumImgData = [];
    end
        
    %% Filtering
    
    % baseline filtering (a highpass filter with very low cutoff frequency)
    ecg_basefilt(size(ecg,1),size(ecg,2)) = 0;
    multiplier = (127 / 128);
    for jj = 1:size(ecg,2)
        prevSample = 0; filteredSample = 0;
        ii = 1;
        while ii < length(ecg)
            sample = ecg(ii,jj);
            tmp = filteredSample * multiplier;
            filteredSample = (sample - prevSample) + tmp;
            prevSample = sample;
            ecg_basefilt(ii,jj) = filteredSample;
            ii = ii+1;
        end
    end
    
%     ecg = ecg_basefilt;
    
    %% Timestamps and data preparation
    timestamps.world.timeStart = datetime(jsondata.start,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC');
%     timestamps.world.timeEnd = timestamps.world.timeStart + days(seconds(length(ecg)*(1/str2double(jsondata.samplingrate))));
    timestamps.world.timeEnd = timestamps.world.timeStart + days(seconds(length(ecg)*(1/double(jsondata.samplingrate))));
    timestamps.world.Accel = linspace(timestamps.world.timeStart,timestamps.world.timeEnd,length(acc));
    % Length of recording. NOTE: An assumption is made, that this is the
    % 24bit version of the BLE file, meaning a batch is sent every 0.024
    % seconds,with 6 ecg samples per batch and channel.
    LengthOfRecondingInSeconds = length(serialNumber) * 0.024;
    [h,m,s] = hms(seconds(LengthOfRecondingInSeconds));
    % calculate timestamps as duration
    timestamps.duration.timeStart = days(0);
    secondsPerDay = 24*60*60;
    timestamps.duration.timeEnd = days(LengthOfRecondingInSeconds/secondsPerDay);
    timestamps.duration.ECG = linspace(timestamps.duration.timeStart,timestamps.duration.timeEnd,length(serialNumber)*6);
    timestamps.duration.Accel = linspace(timestamps.duration.timeStart,timestamps.duration.timeEnd,length(serialNumber));
    % Acceleration magnitude
    accMagnitude = sqrt(sum(acc.^2,2));
    % Convert ECG sample values to millivolts
    mvFactor = ((0.8 * 1000) / (2^24));
    ecg = ecg * mvFactor;
    ecg_basefilt = ecg_basefilt * mvFactor;
    
    %%  %------- define some useful sizes, positions, and resolution for plots and textboxes -------%
    
    % widthInCm = 21.0; heightInCm = 29.7; % A4-sized paper
    widthInCm = 21.59; heightInCm = 27.94; % Letter-sized paper
    maxWidth = widthInCm - 3;
    maxPlotWidth = widthInCm - 4;
    topOfPage = heightInCm - 2.5;
    bottomOfPage = 1.5;
    bottomOfPagePosPlot = 2.0;
    leftOfPagePos = 1.5;
    leftOfPagePosForPlot = 2.5;
    headerPos = heightInCm - 3;
    numEventPlotsOnOnePage = 2;
    verticalSpacingForEventPlots = 0.25;
    eventPlotHeight = ((heightInCm - (heightInCm - headerPos) - bottomOfPage) / numEventPlotsOnOnePage) - verticalSpacingForEventPlots * numEventPlotsOnOnePage; 
    fullRecordingPlotHeight =  eventPlotHeight + 0.75;

    % plot colors
    plotColor{1} = [1.0 0 0];
    plotColor{2} = [0 0.8 0];
    plotColor{3} = [0 0 1.0];
    plotColor{4} = [1.0 0.68 0.1];
    plotColor{5} = [0.92 0.92 0.92];
    
    % Total number of pages. There will always be a minimum of 1 page.
    % Subsequent pages will hold max 2 event plots per page.
    if isempty(eventMarker{1,1})
        totalNumPages = 1;
    else
        totalNumPages = 1 + round(size(eventMarker,1) * 0.5);
    end
    pdf_fullpath_page = cell(totalNumPages,1);
    
    imageRes = '-r0'; % -r0 = screen resolution, -r300 = 300 dpi
    
    % Maximum number of pages. 21 will acommodate first page plus 20 pages with 2 events each.
    maxNumPages = 21;
    
    
    %%  %------- PAGE 1 -------%
    
    pageNumber = 1;
    
    % create a Letter-sized page (figure)
    hFig_Page = createPageFig(widthInCm, heightInCm);

    % add header with logo, file id, recording time info
    objectPosition = [ leftOfPagePos topOfPage maxWidth 1.0];
    addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData);
    
    % add sub header, only for page 1, with details about device, firmware, etc.
    objectPosition = [ leftOfPagePos-0.01 topOfPage-1.0 maxWidth+0.02 1.0];
    addSubHeader(hFig_Page, objectPosition, jsondata, plotColor);
    
    % add event marker list
    objectPosition = [ leftOfPagePos-0.01 topOfPage-2.1 maxWidth+0.02 1.0];
    addEventMarkerList(hFig_Page, objectPosition, jsondata, timestamps, eventMarker, plotColor);
    
    % add ECG1 and Accel plot of entire recording
    objectPosition = [ leftOfPagePosForPlot bottomOfPagePosPlot maxPlotWidth fullRecordingPlotHeight];
    addECGandAccel_full(hFig_Page, objectPosition, ecg, accMagnitude, timestamps, eventMarker, plotColor);
        
    % add footer, with page number
    objectPosition = [ leftOfPagePos bottomOfPage maxWidth 1.0];
    addFooter(hFig_Page, objectPosition, pageNumber, totalNumPages);
    
    % export page to PDF
    pdf_fullpath_page(1) = cellstr(fullfile(ble_path, [ble_filename_wo_extension '_' jsondata.report_type '_page1.pdf']));
    print('-dpdf', imageRes, pdf_fullpath_page{1});
%     winopen(pdf_fullpath_page{1});
    
    % close the (invisible) figure window
    close(hFig_Page);
    
    
    %%  %------- PAGEs 2 - (whatever number of pages will fit all event-zooms -- OR, max number of pages) -------%
    
    pageNumber = 2;
    if ~isempty(eventMarker{1,1})
        for ii=1:min(size(eventMarker,1),maxNumPages-1)
            % modulus of event number, to control plot positioning and page number
            plotMod = mod(ii,2);
            % create a Letter-sized page (figure)
            if plotMod == 1
                hFig_Page = createPageFig(widthInCm, heightInCm);
            end
            % add header with logo, file id, recording time info
            objectPosition = [ leftOfPagePos topOfPage maxWidth 1.0];
            addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData);
            % calculating position for plot
            objectPosition = [ leftOfPagePos (bottomOfPagePosPlot + (plotMod * eventPlotHeight) + (plotMod * 0.5)) maxWidth eventPlotHeight];
            % add event zoom
            addEventZoom(hFig_Page, objectPosition, ecg_basefilt, accMagnitude, timestamps, eventMarker, ii, plotColor);
            % add footer, with page number
            objectPosition = [ leftOfPagePos bottomOfPage maxWidth 1.0];
            addFooter(hFig_Page, objectPosition, pageNumber, totalNumPages);
            % export current page if we have put 2 event plots on current page (or this is the last event), and increase page number
            if (plotMod == 0) || (ii == size(eventMarker,1))
                % export page to PDF
                pdf_fullpath_page(pageNumber) = cellstr(fullfile(ble_path, [ble_filename_wo_extension '_' jsondata.report_type '_page' num2str(pageNumber) '.pdf']));
                print('-dpdf', imageRes, pdf_fullpath_page{pageNumber});
    %             winopen(pdf_fullpath_page{pageNumber});
                % close the (invisible) figure window
                close(hFig_Page);
                pageNumber = pageNumber + 1;
            end
        end
    end
    
    
    %%  %------- MERGE PAGES -------%
    
    % build command string for pdftk.exe, including all pages
    cmdStr = pdftk_exe;
    delStr = cell(1);
    for ii=1:length(pdf_fullpath_page)
        cmdStr = [cmdStr ' "' pdf_fullpath_page{ii} '"'];
        delStr{ii} = pdf_fullpath_page{ii};
    end
    pdf_fullpath = fullfile(ble_path, [ble_filename_wo_extension '_' jsondata.report_type '.pdf']);
    cmdStr = [cmdStr ' cat output "' pdf_fullpath '"'];
    % merge PDF pages
    [statusMerge,cmdoutMerge] = system(cmdStr);
    if statusMerge == 0
        fprintf('Status of merging pdf files: Successful\n');
    else
        fprintf('Status of merging pdf files: Not successful\n');
    end
    % Delete indivudal-page pdf's, now that we have merged them into one pdf.
    % Turn off recycling, so delete actually means delete.
    recycle('off');
    delete(delStr{1,1:end});
%     winopen(pdf_fullpath);
end

%% Create a figure, the size of A4 paper, to be used as parent for everything that is created on the page
function hFig_Page = createPageFig(widthInCm, heightInCm)
    % create page figure, the size of A4
    hFig_Page = figure('Numbertitle','off',...
        'MenuBar', 'None',... %'figure'
        'Toolbar','None',...
        'Visible','off',...
        'Units', 'centimeters',...
        'Position',[0 0 widthInCm heightInCm],...
        'PaperUnits','centimeters',...
        'PaperSize',[widthInCm heightInCm],...
        'PaperPosition',[0 0 widthInCm heightInCm],...
        'PaperOrientation','portrait',...
        'PaperPositionMode','auto');
end
    
function addHeader(hFig_Page, objectPosition, jsondata, timestamps, logoCortriumImgData)
    % create axes object for adding a line at the bottom of the header
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
    plot([0, 1], [0, 0], 'Color', 'k', 'LineWidth', 0.5, 'Parent', hAx);
    hAx.YLim = [0, 1];
    hAx.XLim = [0, 1];
    hAx.Color = 'none';
    hAx.Visible = 'off';
    % create axes object for Cortrium logo image
    imgHeightToWidthRatio = double(size(logoCortriumImgData.img,1))/double(size(logoCortriumImgData.img,2));
    imgPrintWidth = 3.5; % cm
    imgPrintHeight = imgPrintWidth * imgHeightToWidthRatio;
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1)+objectPosition(3)-imgPrintWidth+0.2, objectPosition(2)+0.2, imgPrintWidth, imgPrintHeight]);
    % show the image and set alpha for transparent background
    hIm = imshow(logoCortriumImgData.img, logoCortriumImgData.map, 'InitialMagnification', 'fit', 'Parent', hAx);
    hIm.AlphaData = logoCortriumImgData.alpha;
    hAx.Visible = 'off';
    % add text, field descriptions
    textObjectPosition = [objectPosition(1) objectPosition(2)+0.1 1.8 1.2];
    strText = sprintf('Test title:\nDate, time:\nID:');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','bold',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add text, field info from json file
    textObjectPosition = [objectPosition(1)+1.8 objectPosition(2)+0.1 10.0 1.2];
    strText = sprintf('%s\n%s\n%s', jsondata.emailsubject, datestr(timestamps.world.timeStart, 'yyyy-mm-dd, HH:MM:SS'), jsondata.patientname);
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

function addSubHeader(hFig_Page, objectPosition, jsondata, plotColor)
    % create axes object for adding a line at the bottom of the header
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
    hAx.YLim = [0, 1];
    hAx.XLim = [0, 1];
    hAx.Color = 'none';
    hAx.Visible = 'off';
    rectangle('Position',[0, 0, 1, 0.5],'FaceColor',plotColor{5}, 'EdgeColor', 'none', 'LineWidth', 0.01, 'Parent', hAx);
    % add text, field names and position
    fieldCellArray{1,1} = 'Device ID:';
    fieldCellArray{2,1} = 'Firmware:';
    fieldCellArray{3,1} = 'App:';
    fieldCellArray{4,1} = 'File:';
    yPosText = 0.22;
    fieldCellArray{1,2} = [0.1 yPosText];
    fieldCellArray{2,2} = [6 yPosText];
    fieldCellArray{3,2} = [9.5 yPosText];
    fieldCellArray{4,2} = [13 yPosText];
    % add text objects, field descriptions
    for ii=1:size(fieldCellArray,1)
        text(fieldCellArray{ii,2}(1), fieldCellArray{ii,2}(2), fieldCellArray(ii,1), 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'Parent', hAx);
    end
    % add text, field values and position
    fieldValueCellArray{1,1} = [jsondata.hardwareversion ' ' jsondata.deviceid];
    fieldValueCellArray{2,1} = jsondata.softwareversion;
    fieldValueCellArray{3,1} = [jsondata.appversion ' build ' jsondata.appbuild];
    fieldValueCellArray{4,1} = jsondata.filename;
    fieldValueCellArray{1,2} = [1.65 yPosText];
    fieldValueCellArray{2,2} = [7.5 yPosText];
    fieldValueCellArray{3,2} = [10.25 yPosText];
    fieldValueCellArray{4,2} = [13.75 yPosText];
    % add text objects, field descriptions
    for ii=1:size(fieldValueCellArray,1)
        text(fieldValueCellArray{ii,2}(1), fieldValueCellArray{ii,2}(2), fieldValueCellArray(ii,1), 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'normal', 'Parent', hAx);
    end
end

function addEventMarkerList(hFig_Page, objectPosition, jsondata, timestamps, eventMarker, plotColor)
    % create axes object for adding a line at the bottom of the header
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
    hAx.YLim = [0, 1];
    hAx.XLim = [0, 1];
    hAx.Color = 'none';
    hAx.Visible = 'off';
    rectangle('Position',[0, 0, 1, 0.8],'FaceColor',plotColor{5}, 'EdgeColor', 'none', 'LineWidth', 0.01, 'Parent', hAx);
    % define field names and position
    fieldCellArray{1,1} = 'Event:';
    fieldCellArray{2,1} = 'Time (hh:mm:ss):';
    fieldCellArray{3,1} = 'Date, time:';
    fieldCellArray{4,1} = 'Leadoff %:';
    fieldCellArray{5,1} = 'Packet loss %:';
    yPosText = 0.52;
    fieldCellArray{1,2} = [0.1 yPosText];
    fieldCellArray{2,2} = [6 yPosText];
    fieldCellArray{3,2} = [9.5 yPosText];
    fieldCellArray{4,2} = [13 yPosText];
    fieldCellArray{5,2} = [16 yPosText];
    % add field names
    for ii=1:size(fieldCellArray,1)
        text(fieldCellArray{ii,2}(1), fieldCellArray{ii,2}(2), fieldCellArray(ii,1), 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'bold', 'Parent', hAx);
    end
    % define field descriptions and positions
    fieldCellArray{1,1} = 'Events (max 20) as noted in app';
    fieldCellArray{2,1} = 'Since start of recording';
    fieldCellArray{3,1} = 'Actual time of event';
    fieldCellArray{4,1} = 'From this event to next';
    fieldCellArray{5,1} = 'Lost Bluetooth packets';
    yPosText = 0.22;
    fieldCellArray{1,2} = [0.1 yPosText];
    fieldCellArray{2,2} = [6 yPosText];
    fieldCellArray{3,2} = [9.5 yPosText];
    fieldCellArray{4,2} = [13 yPosText];
    fieldCellArray{5,2} = [16 yPosText];
    % add field descriptions
    for ii=1:size(fieldCellArray,1)
        text(fieldCellArray{ii,2}(1), fieldCellArray{ii,2}(2), fieldCellArray(ii,1), 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 6, 'FontWeight', 'normal', 'Parent', hAx);
    end
    % Check if there are any events at all
    if ~isempty(eventMarker{1,1})
        totalNumEvents = size(eventMarker,1);
    else
        totalNumEvents = 0;
    end
    for ii=1:max(totalNumEvents,20)
        % text background, full width
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1) (objectPosition(2)-(ii*0.4)) objectPosition(3) 0.3],...
        'HorizontalAlignment','left',...
        'String',' ',...
        'FontName','FixedWidth',...
        'FontWeight','normal',...
        'FontSize',7,...
        'BackgroundColor',plotColor{5});
        % field value, event description
        if ii > totalNumEvents
            txtStr = ' ';
        else
            txtStr = [sprintf('%02d',(ii)) '  ' eventMarker{ii,3}];
        end
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1)+0.1 (objectPosition(2)-(ii*0.4)) 5.5 0.3],...
        'HorizontalAlignment','left',...
        'String',txtStr,...
        'FontWeight','normal',...
        'FontSize',7.5,...
        'BackgroundColor',plotColor{5});
        % field value, Time (recording)
        if ii > totalNumEvents
            txtStr = ' ';
        else
            [h,m,s] = hms(timestamps.duration.Accel(eventMarker{ii,1}));
            txtStr = sprintf('%02d:%02d:%02.0f',h,m,s);
        end
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1)+6 (objectPosition(2)-(ii*0.4)) 4 0.3],...
        'HorizontalAlignment','left',...
        'String',txtStr,...
        'FontWeight','normal',...
        'FontSize',7.5,...
        'BackgroundColor',plotColor{5});
        % field value, Time (world)
        if ii > totalNumEvents
            txtStr = ' ';
        else
            txtStr = datestr(timestamps.world.Accel(eventMarker{ii,1}), 'yyyy-mm-dd, HH:MM:SS');
        end
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1)+9.5 (objectPosition(2)-(ii*0.4)) 4 0.3],...
        'HorizontalAlignment','left',...
        'String',txtStr,...
        'FontWeight','normal',...
        'FontSize',7.5,...
        'BackgroundColor',plotColor{5});
        % field value, Leadoff percentage
        if ii > totalNumEvents
            txtStr = ' ';
        else
            txtStr = sprintf('%.2f', eventMarker{ii,4});
        end
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1)+13 (objectPosition(2)-(ii*0.4)) 2 0.3],...
        'HorizontalAlignment','left',...
        'String',txtStr,...
        'FontWeight','normal',...
        'FontSize',7.5,...
        'BackgroundColor',plotColor{5});
        % field value, Packet loss percentage
        if ii > totalNumEvents
            txtStr = ' ';
        else
            txtStr = sprintf('%.2f', eventMarker{ii,5});
        end
        uicontrol('Parent',hFig_Page,...
        'Style','text',...
        'Units','centimeters',...
        'position',[objectPosition(1)+16 (objectPosition(2)-(ii*0.4)) 2 0.3],...
        'HorizontalAlignment','left',...
        'String',txtStr,...
        'FontWeight','normal',...
        'FontSize',7.5,...
        'BackgroundColor',plotColor{5});
    end
end

function addFooter(hFig_Page, objectPosition, pageNumber, totalNumPages)
    % create axes object for adding a line at the top of the footer
    hAx = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', objectPosition);
    plot([0, 1], [0, 0], 'Color', 'k', 'LineWidth', 0.5, 'Parent', hAx);
    hAx.YLim = [0, 1];
    hAx.XLim = [0, 1];
    hAx.Color = 'none';
    hAx.Visible = 'off';
    % add text, Cortrium test report
    textObjectPosition = [objectPosition(1) objectPosition(2)-0.5 12.0 0.4];
    strText = sprintf('Cortrium test report');
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','left',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
    % add text, page number
    textObjectPosition = [(objectPosition(1)+objectPosition(3)-2.0) objectPosition(2)-0.5 2.0 0.4];
    strText = sprintf('page: %d / %d', pageNumber, totalNumPages);
    uicontrol('Parent',hFig_Page,...
    'Style','text',...
    'Units','centimeters',...
    'position',textObjectPosition,...
    'HorizontalAlignment','right',...
    'String',strText,...
    'FontWeight','normal',...
    'FontSize',9,...
    'BackgroundColor',[1 1 1]);
end

function addECGandAccel_full(hFig_Page, objectPosition, ecg, accMagnitude, timestamps, eventMarker, plotColor)
    % Serial index range of interest
    minIdx = 1;
    maxIdx = length(accMagnitude); %length(serialNumber); %121018
    % Index range for ECG and Accel
    minIdxECG = minIdx*6;
    maxIdxECG = maxIdx*6;
    minIdxAcc = minIdx;
    maxIdxAcc = maxIdx;
    % Define height of Accel plot
    accelPlotHeight = 2.0;
    accelPlotTopMargin = 1.0;
    accelPlotBottomMargin = 0.5;
    % Create axes objects
    hAxECG = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1), objectPosition(2)+accelPlotHeight+accelPlotTopMargin+accelPlotBottomMargin, objectPosition(3), objectPosition(4)-accelPlotHeight-accelPlotTopMargin], 'Color', 'none', 'Box', 'on');
    hAxAcc = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1), objectPosition(2)+accelPlotBottomMargin, objectPosition(3), accelPlotHeight], 'Box', 'on');
    % Set axes y-limits
    hAxECG.YLim = [-400 400];
    hAxAcc.YLim = [0 2];
    hold(hAxAcc,'on');
    hold(hAxECG,'on');
    % Prepare for legend
    legendList = cell(0);
    % Plot data, ECG
    for ii=1:size(ecg,2)
        legendList(length(legendList)+1) = {['ECG' num2str(ii)]};
        plot(hAxECG, timestamps.duration.ECG(minIdxECG:maxIdxECG), ecg(minIdxECG:maxIdxECG,ii),'Color',plotColor{ii},'DurationTickFormat','hh:mm:ss');%hh:mm:ss.SSS
    end
    if ~isempty(eventMarker{1,1})
        % Plot event markers on ECG plot
        yLimit = ylim(hAxECG);
        for ii=1:size(eventMarker,1)
            plot(hAxECG,[timestamps.duration.ECG(eventMarker{ii,2}) timestamps.duration.ECG(eventMarker{ii,2})],[yLimit(1) yLimit(2)],'Color',plotColor{4},'LineWidth',1.0,'LineStyle',':','DurationTickFormat','hh:mm:ss');%:ss.SSS
        end
        if size(eventMarker,1) > 0
            legendList(length(legendList)+1) = {'Event'};
        end
        % add numbers for event markers
        for ii=1:size(eventMarker,1)
            text(datenum(timestamps.duration.Accel(eventMarker{ii,1})), yLimit(1)+(yLimit(2)-yLimit(1))*0.075, sprintf('%02d',ii), 'HorizontalAlignment', 'left', 'FontSize', 7, 'FontWeight', 'normal', 'BackgroundColor', plotColor{4}, 'Margin', 1, 'EdgeColor', 'none', 'Parent', hAxECG);
        end
    end
    legend(hAxECG,legendList); %'Location','northoutside','Orientation','horizontal'
    % Plot Accel and event markers
    plot(hAxAcc,timestamps.duration.Accel(minIdxAcc:maxIdxAcc),accMagnitude(minIdxAcc:maxIdxAcc),'Color','k','DurationTickFormat','hh:mm:ss');
    yLimit = ylim(hAxAcc);
    if ~isempty(eventMarker{1,1})
        for ii=1:size(eventMarker,1)
            plot(hAxAcc,[timestamps.duration.Accel(eventMarker{ii,1}) timestamps.duration.Accel(eventMarker{ii,1})],[yLimit(1) yLimit(2)],'Color',plotColor{4},'LineWidth',1.0,'LineStyle',':','DurationTickFormat','hh:mm:ss');
        end
    end
    % Set axes x-limits
    hAxECG.XLim = [datenum(timestamps.duration.ECG(minIdxECG)) datenum(timestamps.duration.ECG(maxIdxECG))];
    hAxAcc.XLim = [datenum(timestamps.duration.Accel(minIdxAcc)) datenum(timestamps.duration.Accel(maxIdxAcc))];
    % Titles, labels, etc.
    EcgTitleStr = sprintf('ECG (unfiltered)');
    title(hAxECG,EcgTitleStr,'FontSize',12,'FontWeight','bold');
    title(hAxAcc,'Acceleration magnitude','FontSize',10,'FontWeight','normal');
    xlabel(hAxAcc,'Time (hrs:min:sec)','FontSize',8);
    ylabel(hAxECG,'mV','FontSize',8);
    ylabel(hAxAcc,'g-force','FontSize',8);
    set(hAxECG,'FontSize',8,'FontWeight','normal');
    set(hAxAcc,'FontSize',8,'FontWeight','normal');
%     grid(hAxECG,'on');
%     grid(hAxAcc,'on');
end

function addEventZoom(hFig_Page, objectPosition, ecg, accMagnitude, timestamps, eventMarker, eventNumber, plotColor)
    [hAxECG_fullsize, hAxECG_overview, hAxAcc, hAxTxt] = createEventZoomAxesObjects(hFig_Page, objectPosition, ecg);
    % Point of interest
    idxStartAcc = eventMarker{eventNumber,1};
    idxStartECG = eventMarker{eventNumber,2};
    % Plot Accel, note: to match scale of ECG plot, we plot 0.4 seconds per 10 mm horisontally
    secondsPerCentimeter = 0.4;
    signalDataCrop = getSignalCrop(idxStartAcc, accMagnitude, 41.666666, objectPosition(3)*secondsPerCentimeter);
    idxEndAcc = idxStartAcc + length(signalDataCrop);
    xVal = 1:length(signalDataCrop);
    hAxAcc.XLim = [1 max(xVal)];
    plot(hAxAcc,xVal,signalDataCrop,'Color','k');
    % Plot ECG
    % For ECG plots, 10 mm represents 0.4 seconds time, horisontally, and  1.0 mV amplitude vertically.
    signalDataCrop = getSignalCrop(idxStartECG, ecg, 250, objectPosition(3)*secondsPerCentimeter);
    xVal = 1:length(signalDataCrop);
    for ii=1:size(ecg,2)
        % calculate vertical center of signal, and y-limits to match 1.0 mV per centimeter vertically
        yLimit = calcYlimits(signalDataCrop(:,ii), hAxECG_fullsize(ii), 1.0);
        yRange = yLimit(2) - yLimit(1);
        hAxECG_fullsize(ii).YLim = [yLimit(1) yLimit(2)];
        hAxECG_fullsize(ii).XLim = [1 max(xVal)];
        if ii == 1
            signalOffset = yLimit(2) - (nanmax(signalDataCrop(:,ii) + (yRange * 0.05)));
        elseif ii == 2
            signalOffset = 0;
        else
            signalOffset = yLimit(1) - (nanmin(signalDataCrop(:,ii) - (yRange * 0.05)));
        end
        plot(hAxECG_fullsize(ii),xVal,signalDataCrop(:,ii)+signalOffset,'Color',plotColor{ii});
%         fprintf('ecg channel: %d,  signalOffset: %f\n',ii,signalOffset);
    end

    % add text, event description 
    hTxt = text(0.2, objectPosition(4)-0.25, ['Event ' sprintf('%02d',eventNumber) ': ' eventMarker{eventNumber,3}], 'Units','centimeters', 'HorizontalAlignment', 'left', 'FontSize', 8, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxTxt);
    hTxt.BackgroundColor = [1 1 1 0.6];
    % add ECG title
    hTxt = text(objectPosition(3)*0.5, objectPosition(4)-0.25, 'ECG (baseline filtered)', 'Units','centimeters', 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxTxt);
    hTxt.BackgroundColor = [1 1 1 0.6];
    % add time of event
    if idxStartAcc > 0
        [h1,m1,s1] = hms(timestamps.duration.Accel(idxStartAcc));
        txtStr1 = sprintf('%02d:%02d:%02.0f',h1,m1,s1);
    else
        txtStr1 = 'NA';
    end
    if idxEndAcc <= length(accMagnitude)
        [h2,m2,s2] = hms(timestamps.duration.Accel(idxEndAcc));
        txtStr2 = sprintf('%02d:%02d:%02.0f',h2,m2,s2);
    else
        txtStr2 = 'NA';
    end
    hTxt = text(objectPosition(3)-0.3, objectPosition(4)-0.25, ['Time displayed: ' txtStr1 ' ' char(8211) ' ' txtStr2], 'Units','centimeters', 'HorizontalAlignment', 'right', 'FontSize', 8, 'FontWeight', 'normal', 'Margin', 1, 'Parent', hAxTxt);
    hTxt.BackgroundColor = [1 1 1 0.6];
    % add Accel mag title
    hTxt = text(hAxAcc.Position(1)+(hAxAcc.Position(3)-hAxAcc.Position(1))*0.5, 1.73, 'Accel mag', 'Units','centimeters', 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Margin', 1, 'Parent', hAxTxt);
    hTxt.BackgroundColor = [1 1 1 0.6];

    % Clean up axes objects (remove tick labels)
    cleanupAxes(hAxECG_fullsize, hAxECG_overview, hAxAcc);
end

function [hAxECG_fullsize, hAxECG_overview, hAxAcc, hAxTxt] = createEventZoomAxesObjects(hFig_Page, objectPosition, ecg)
    % BACKGROUND AXES, not used for plotting, only grid and box is shown
    hAxBg = axes('Parent',hFig_Page,'Units','centimeters','Position',objectPosition, 'Box', 'on');
    % clear ticklabels
    set(hAxBg,'Xticklabel',[]);
    set(hAxBg,'Yticklabel',[]);
    % set up tickmarks for every 5mm, and turn on grid
    set(hAxBg,'xlim',[0.1 objectPosition(3)*10]);
    set(hAxBg,'ylim',[0.1 objectPosition(4)*10]);
    hAxBg.XTick = linspace(0.1,objectPosition(3)*10,objectPosition(3)*2);
    hAxBg.YTick = linspace(0.1,objectPosition(4)*10,objectPosition(4)*2);
    grid(hAxBg,'on');
    hAxBg.GridAlpha = 0.08;
    hAxBg.TickLength = [0 0];
    
    % AXES FOR PLOTS
    accelPlotHeight = 2.0;
    hAxAcc = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1), objectPosition(2), objectPosition(3), accelPlotHeight], 'Box', 'on');
    for ii=1:size(ecg,2)
        hAxECG_fullsize(ii) = axes('Parent', hFig_Page, 'Units', 'centimeters', 'Position', [objectPosition(1), objectPosition(2)+accelPlotHeight, objectPosition(3), objectPosition(4)-accelPlotHeight], 'Color', 'none', 'Box', 'off');
        hAxECG_fullsize(ii).TickLength = [0 0];
        hold(hAxECG_fullsize(ii), 'on');
    end
    hAxECG_overview = [];
    % Set tick length on Accel axes
    hAxAcc.TickLength = [0 0];
    % Set axes y-limits
%     hAxECG_fullsize.YLim = [-400 400];
%     hAxECG_overview = [-400 400];
    hAxAcc.YLim = [0 2];
%     hold(hAxECG_fullsize,'on');
%     hold(hAxECG_overview,'on');
    hold(hAxAcc,'on');
    
    % ADDING TEXT
    % create a foreground (invisible) axes object, where text can be added
    hAxTxt = axes('Parent',hFig_Page,'Units','centimeters','Position',objectPosition, 'Visible', 'off');   
end

function cleanupAxes(hAx1, hAx2, hAx3)
    set(hAx3,'Xticklabel',[]);
    set(hAx3,'Yticklabel',[]);
    set(hAx2,'Xticklabel',[]);
    set(hAx2,'Yticklabel',[]);
    set(hAx1,'Xticklabel',[]);
    set(hAx1,'Yticklabel',[]);
end

function signalDataCrop = getSignalCrop(IdxStart, signalData, samplingFrequency, durationSecs)
    % Function to return a range of signal data, beginning at 'IdxStart',
    % equal to a specified duration in time, for a signal sampled at 
    % a specified sampling rate.
    % If the range exceeds the min and/or max range of the full signal data, 
    % the returned data will be forced within the bounds of the signal data.
    tempMinIdx = IdxStart;
    tempMaxIdx = round(IdxStart + (samplingFrequency * durationSecs) - 1);
    % Method for signals stored as one column per signal
    if length(signalData) == size(signalData,1)
        if tempMaxIdx > length(signalData) && tempMinIdx >= 1
            padLength = tempMaxIdx - length(signalData);
            signalDataCrop = [signalData(tempMinIdx:length(signalData),:); NaN(padLength, size(signalData,2))];
        elseif tempMinIdx < 1 && tempMaxIdx <= length(signalData)
            padLength = abs(tempMinIdx) + 1;
            signalDataCrop = [NaN(padLength, size(signalData,2)); signalData(1:tempMaxIdx,:)];
        elseif tempMaxIdx > length(signalData) && tempMinIdx < 1
            padLength = tempMaxIdx - length(signalData);
            signalDataCrop = [signalData(1:length(signalData),:); NaN(padLength, size(signalData,2))];
            padLength = abs(tempMinIdx) + 1;
            signalDataCrop = [NaN(padLength, size(signalData,2)); signalDataCrop];
        else
            signalDataCrop = signalData(tempMinIdx:tempMaxIdx,:);
        end
    % Method for signals stored as one row per signal
    else
        if tempMaxIdx > length(signalData) && tempMinIdx >= 1
            padLength = tempMaxIdx - length(signalData);
            signalDataCrop = [signalData(:,tempMinIdx:length(signalData)), NaN(size(signalData,1),padLength)];
        elseif tempMinIdx < 1 && tempMaxIdx <= length(signalData)
            padLength = abs(tempMinIdx) + 1;
            signalDataCrop = [NaN(size(signalData,1),padLength), signalData(:,1:tempMaxIdx)];
        elseif tempMaxIdx > length(signalData) && tempMinIdx < 1
            padLength = tempMaxIdx - length(signalData);
            signalDataCrop = [signalData(:,tempMinIdx:length(signalData)), NaN(size(signalData,1),padLength)];
            padLength = abs(tempMinIdx) + 1;
            signalDataCrop = [NaN(size(signalData,1),padLength), signalDataCrop];
        else
            signalDataCrop = signalData(:,tempMinIdx:tempMaxIdx);
        end
    end
%     fprintf('Length of signal crop: %f seconds\n\n',length(signalDataCrop) / samplingFrequency);
end

function yLimit = calcYlimits(signalDataCrop, hAx, mVperCm)
    heightOfECGplot = hAx.Position(4);
    verticalPlotRangeHalf = mVperCm * heightOfECGplot * 0.5;
    verticalCenterOfSignal = median(signalDataCrop,'omitnan');
    yLimit(1) = verticalCenterOfSignal - verticalPlotRangeHalf;
    yLimit(2) = verticalCenterOfSignal + verticalPlotRangeHalf;
%     fprintf('ECG yLim: %f, %f, span: %f\n ',yLimit(1),yLimit(2),yLimit(2)- yLimit(1));
end

% Read ECG (and conf) BLE (Bluetooth Low Energy) files containing Cortrium C3 sensor data.
% 24bit version.

function [ecgData, conf] = c3_read_ble_ecg(ble_fullpath)
    hTic = tic;
    verbose = false;

    conf = []; ecgData = []; ecg1 = []; ecg2 = []; ecg3 = [];

    fid = fopen(ble_fullpath,'r');
    fileInfo = dir(ble_fullpath);
    
    fseek(fid, 0, 'bof');
    bleDescription = fread(fid, 6, '*char')';
    idx7Char = fread(fid, 1, '*char')';
    if strcmp('BLE-C3',bleDescription) && char(idx7Char) == char(0)
        hasHeader = true;
    else
        hasHeader = false;
    end
    
    if hasHeader
        fileFormatVersion = fread(fid, 2, '*char')';
        if strcmp('BLE-C3',bleDescription) && strcmp('01',fileFormatVersion)
            fseek(fid, 10, 'bof');
            deviceID = fread(fid, 15, '*char')';
            fseek(fid, 26, 'bof');
            fwVersion = fread(fid, 12, '*char')';
            fseek(fid, 39, 'bof');
            hwVersion = fread(fid, 7, '*char')';
            fseek(fid, 47, 'bof');
            companySpecific = fread(fid, 1, '*uint8')';
            miscOffset = 48;
        elseif strcmp('BLE-C3',bleDescription) && strcmp('02',fileFormatVersion)
            fseek(fid, 10, 'bof');
            deviceID = fread(fid, 15, '*char')';
            fseek(fid, 26, 'bof');
            fwVersion = fread(fid, 12, '*char')';
            fseek(fid, 39, 'bof');
            hwVersion = fread(fid, 7, '*char')';
            fseek(fid, 47, 'bof');
            confFromHeader = fread(fid, 1, '*uint8');
            fseek(fid, 51, 'bof');
            recordingLengthConf = fread(fid, 1, '*uint32');
            fseek(fid, 55, 'bof');
            companySpecific = fread(fid, 1, '*uint8')';
            miscOffset = 56;
        end
        if cast(companySpecific,'logical')
%             errordlg('This BLE-file is encrypted! Unable to read.','Error Reading File','modal');
%             return;
            miscOffset = miscOffset + 6;
        end
    else
        miscOffset = 0;
    end
    
    fseek(fid, 0 + miscOffset, 'bof');
    % FIND THE FIRST VALID SERIAL AND CONF, i.e. serialNumber is NOT zero
    while ~feof(fid)
        tempSerialNumber = fread(fid, 1, '*uint32');
        % if the 4 bytes just read, is a number > 0 
        % it is assumed that a valid serial number was found
        if tempSerialNumber > 0
            % now get the conf
            fseek(fid, 15, 'cof'); % go to  position for a possible conf
            posForValidConf = ftell(fid);
            conf = fread(fid, 1, '*uint8');
            break;
        end
        % Go to next position for a possible serial number.
        % (We just read 4 bytes. Now move an additional 16 bytes forward, for a total of 20 bytes)
        fseek(fid, 16, 'cof');
    end
    
    if tempSerialNumber == 0
        return;
    end

    % determine which parts are available in this file
    conf_bin = dec2bin(conf,8); % conf, in binary form
    respAvailable = (conf_bin(end) == '1');
    ecg1Available = (conf_bin(end-1) == '1');
    ecg2Available = (conf_bin(end-2) == '1');
    ecg3Available = (conf_bin(end-3) == '1');
    % dec2hex for debugging purposes
    conf_hex = dec2hex(conf);
    
    numBatches = Inf; % Batches to read. 'Inf' = read all batches
    batchSize = 20 + ((ecg1Available + ecg2Available + ecg3Available) * 20); % how many bytes a batch contains, depends on how many sensor signals were included
    fileSizeMinusHeader = fileInfo.bytes - miscOffset;
    batchesInFile = fileSizeMinusHeader/batchSize;

    if verbose
        % Display info about recording start time and duration, output to console
        [~,ble_name,ble_ext] = fileparts(ble_fullpath);
        LengthOfRecondingInSeconds = batchesInFile/(250/6);
        [h,m,s] = hms(seconds(LengthOfRecondingInSeconds));
        fprintf('\n=================================================================\n');
        fprintf('File: %s\nSize: %d bytes, (%f megabytes)\n', [ble_name,ble_ext], fileInfo.bytes, fileInfo.bytes/1024/1024);
        fprintf('Duration: %02d:%02d:%02.0f (hours:mins:secs)\n',h, m, s);
        fprintf('valid conf assumed at file pos: %d bytes\n',posForValidConf);
        fprintf('Conf DEC: %d     Conf BIN: %s    Conf HEX: %s\n',conf,conf_bin,conf_hex);
        if hasHeader
            fprintf('Header: ');
            fprintf('%s, ',bleDescription);
            fprintf('file ver: %s, ',fileFormatVersion);
            fprintf('deviceID: %s, ',deviceID);
            fprintf('FW ver: %s, ',deblank(fwVersion));
            fprintf('HW ver: %s, ',deblank(hwVersion));
            fprintf('comp. specific: %d\n',companySpecific);
            if strcmp('BLE-C3',bleDescription) && strcmp('02',fileFormatVersion)
                fprintf('confFromHeader DEC: %d     BIN: %s     HEX: %s\n',confFromHeader,dec2bin(confFromHeader,8),dec2hex(confFromHeader));
                fprintf('recordingLengthConf: %d\n',recordingLengthConf);
            end
        end
        fprintf('=================================================================\n');
    end

    % [SKIPPING MOST OF] PART 1, MISC, MANDATORY PAYLOAD
    % set the file pointer to the start of the first MISC part
    filePos = 0 + miscOffset;
    fseek(fid, filePos, 'bof');
    serialNumber = fread(fid, numBatches, '*uint32', batchSize-4);
%     fseek(fid, filePos+4, 'bof'); % rewind
%     acc_x = fread(fid, numBatches, 'int16', batchSize-2);
%     fseek(fid, filePos+6, 'bof'); % rewind
%     acc_y = fread(fid, numBatches, 'int16', batchSize-2);
%     fseek(fid, filePos+8, 'bof'); % rewind
%     acc_z = fread(fid, numBatches, 'int16', batchSize-2);
%     fseek(fid, filePos+10, 'bof'); % rewind
%     temp_amb_obj = fread(fid, numBatches, 'uint16', batchSize-2);
%     fseek(fid, filePos+12, 'bof');
%     serial_ADS = fread(fid, numBatches, '*uint8', batchSize-1);
%     fseek(fid, filePos+13, 'bof');
%     eventCounter = fread(fid, numBatches, '*uint8', batchSize-1);
%     fseek(fid, filePos+14, 'bof'); % rewind
%     bat_level_and_status = fread(fid, numBatches, '*uint8', batchSize-1);
%     if respAvailable
%         fseek(fid, filePos+15, 'bof'); % rewind
%         resp = fread(fid, numBatches, 'bit24', (batchSize*8)-24); % when using bitn, 'skip' argument must be specified in bits, not bytes
%     end
%     fseek(fid, filePos+18, 'bof'); % rewind
%     leadoff = fread(fid, numBatches, '*uint8', batchSize-1);  
    % valid conf should not change throughout the file (and is already found), so reading will be skipped
%     fseek(fid, filePos+19, 'bof'); % rewind
%     conf = fread(fid, numBatches, '*uint8', batchSize-1);
    
    % PART 2, ECG_1
    if ecg1Available
        filePos = miscOffset + (ecg1Available * 20);
%         fseek(fid, filePos, 'bof');
%         ecg1_serial = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg1_s1 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+5, 'bof');
        ecg1_s2 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+8, 'bof');
        ecg1_s3 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+11, 'bof');
        ecg1_s4 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+14, 'bof');
        ecg1_s5 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+17, 'bof');
        ecg1_s6 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        % reshape
        ecg1 = reshape([ecg1_s1';ecg1_s2';ecg1_s3';ecg1_s4';ecg1_s5';ecg1_s6'],[],1);
    end

    % PART 3, ECG_2
    if ecg2Available
        filePos = miscOffset + ((ecg1Available + ecg2Available) * 20);
%         fseek(fid, filePos, 'bof');
%         ecg2_serial = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg2_s1 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+5, 'bof');
        ecg2_s2 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+8, 'bof');
        ecg2_s3 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+11, 'bof');
        ecg2_s4 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+14, 'bof');
        ecg2_s5 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+17, 'bof');
        ecg2_s6 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        % reshape
        ecg2 = reshape([ecg2_s1';ecg2_s2';ecg2_s3';ecg2_s4';ecg2_s5';ecg2_s6'],[],1);
    end

    % PART 4, ECG_3
    if ecg3Available
        filePos = miscOffset + ((ecg1Available + ecg2Available + ecg3Available) * 20);
%         fseek(fid, filePos, 'bof');
%         ecg3_serial = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg3_s1 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+5, 'bof');
        ecg3_s2 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+8, 'bof');
        ecg3_s3 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+11, 'bof');
        ecg3_s4 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+14, 'bof');
        ecg3_s5 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        fseek(fid, filePos+17, 'bof');
        ecg3_s6 = fread(fid, numBatches, 'bit24',(batchSize*8)-24);
        % reshape
        ecg3 = reshape([ecg3_s1';ecg3_s2';ecg3_s3';ecg3_s4';ecg3_s5';ecg3_s6'],[],1);
    end
    fclose(fid);
    
    % find indices of missed batches
    missedBatches = find(serialNumber == 0);
    % set ecg, resp, accel, and temp data in missed batches to 'NaN'
    if ~isempty(missedBatches)
        % building index numbers for missed samples in resp and ecg (6 times as many as in accel, temp, and resp)
        startOfMissed_ecg = ((missedBatches-1)*6)+1;
        endOfMissed_ecg = missedBatches*6;
        idx = coloncat(startOfMissed_ecg, endOfMissed_ecg);
        if ~isempty(ecg1)
            ecg1(idx) = 0; % NaN or -32768 for Comm error
        end
        if ~isempty(ecg2)
            ecg2(idx) = 0; % NaN or -32768 for Comm error
        end
        if ~isempty(ecg3)
            ecg3(idx) = 0; % NaN or -32768 for Comm error
        end
    end
    
    ecgData = [ecg1, ecg2, ecg3];
    if verbose
        fprintf('c3_read_ble_ecg: %f seconds\n',toc(hTic));
    end
end

function idx = coloncat(start, stop)
    % COLONCAT Concatenate colon expressions
    %    idx = COLONCAT(START,STOP) returns a vector containing the values
    %    [START(1):STOP(1) START(2):STOP(2) START(END):STOP(END)].

    % Based on Peter Acklam's code for run length decoding.
    len = stop - start + 1;

    % keep only sequences whose length is positive
    pos = len > 0;
    start = start(pos);
    stop = stop(pos);
    len = len(pos);
    if isempty(len)
        idx = [];
        return;
    end

    % expand out the colon expressions
    endlocs = cumsum(len);  
    incr = ones(1, endlocs(end));  
    jumps = start(2:end) - stop(1:end-1);  
    incr(endlocs(1:end-1)+1) = jumps;
    incr(1) = start(1);
    idx = cumsum(incr);
end
% Read BLE (Bluetooth Low Energy) files containing Cortrium C3 sensor data.
% 24bit version, for ECG and RESP data saved with 24bit precision.

% The BLE file contains a sequence of batches.
% Each batch contains up to 4 parts, with 20 bytes in each part.

% Part 1 is mandatory, and is structured like so:
% uint32    serial;     % incremented for every batch. If serial number is 0, then the batch is invalid and all data in the batch are 0.    
% int16     acc_x;
% int16     acc_y;
% int16     acc_z;
% uint16    temp_ambient_object; % temp_ambient and temp_object alternate in every second (modulus 2) batch
% uint16    serial_ADS;
% uint8     bat_level_and_status; % bat_level and bat_status, packed into bitmask
% bit24     resp; % 24 bit, signed, respiration sample
% int8      leadoff;
% uint8     conf;       % bitmask indicating which (if any) of the RESP, ECG1, ECG2, ECG3 parts appear after Part 1. This configuration never changes within the current BLE file.

% The remaining 3 parts are optional, but if present, each part contains
% an uint16 serial, and 6 samples of 24bit ECG data.

function [serialNumber, conf, serial_ADS, eventCounter, leadoff, acc, temp, resp, ecg, ecg_serials] = c3_read_ble_24bit(ble_fullpath)
    hTic = tic;
    debug = false; verbose = true;

    serialNumber = []; conf = []; serial_ADS = []; eventCounter = []; leadoff = [];
    acc = []; temp = []; resp = []; ecg = []; ecg1 = []; ecg2 = []; ecg3 = [];
    ecg_serials = []; ecg1_serial = []; ecg2_serial = []; ecg3_serial = [];

    fid = fopen(ble_fullpath,'r');
    
    fseek(fid, 0, 'bof');
    ble_description_chars = fread(fid, 6, '*char')';
    idx7Char = fread(fid, 1, '*char')';
    if strcmp('BLE-C3',ble_description_chars) && idx7Char == char(0)
        hasHeader = true;
    else
        hasHeader = false;
    end
    if hasHeader
        fileFormatVersion = fread(fid, 2, '*char')';
        fseek(fid, 10, 'bof');
        deviceID = fread(fid, 15, '*char')';
        fseek(fid, 26, 'bof');
        fwVersion = fread(fid, 12, '*char')';
        fseek(fid, 39, 'bof');
        hwVersion = fread(fid, 7, '*char')';
        fseek(fid, 47, 'bof');
        companySpecific = fread(fid, 1, '*uint8')';
        miscOffset = 48;
        if companySpecific
            errordlg('This BLE-file is encrypted! Unable to read.','File Error','modal');
            return;
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
            valid_conf = fread(fid, 1, '*uint8');
            first_valid_serial = tempSerialNumber;
            break;
        end
        % Go to next position for a possible serial number.
        % (We just read 4 bytes. Now move an additional 16 bytes forward, for a total of 20 bytes)
        fseek(fid, 16, 'cof');
    end
    
    if tempSerialNumber <= 0
        return;
    end

    % find out which parts are available in this file
    conf_bin = dec2bin(valid_conf,8); % conf, in binary form
    respAvailable = (conf_bin(end) == '1');
    ecg1Available = (conf_bin(end-1) == '1');
    ecg2Available = (conf_bin(end-2) == '1');
    ecg3Available = (conf_bin(end-3) == '1');
    % dec2hex for debugging purposes
    conf_hex = dec2hex(valid_conf);
    
    if verbose
        % Display info about recording start time and duration, output to console
        [~,ble_name,ble_ext] = fileparts(ble_fullpath);
        fileInfo = dir(ble_fullpath);
        fprintf('\n=======================================================\n');
        fprintf('File: %s\nSize: %d bytes, (%f megabytes)\n', [ble_name,ble_ext], fileInfo.bytes, fileInfo.bytes/1024/1024);
        fprintf('valid conf assumed at file pos: %d bytes\n',posForValidConf);
        fprintf('Conf DEC: %d     Conf BIN: %s    Conf HEX: %s\n',valid_conf,conf_bin,conf_hex);
        if hasHeader
            fprintf('Header: ');
            fprintf('%s, ',ble_description_chars);
            fprintf('file ver: %s, ',fileFormatVersion);
            fprintf('deviceID: %s, ',deviceID);
            fprintf('FW ver: %s, ',deblank(fwVersion));
            fprintf('HW ver: %s, ',deblank(hwVersion));
            fprintf('comp. specific: %d\n',companySpecific);
        end
    end

    numBatches = Inf; % 'Inf' = read all batches
    batchSize = 20 + ((ecg1Available + ecg2Available + ecg3Available) * 20); % how many bytes a batch contains, depends on how many sensor signals were included

    % PART 1, MISC, MANDATORY PAYLOAD
    % set the file pointer to the start of the first MISC part
    filePos = 0 + miscOffset;
    fseek(fid, filePos, 'bof');
    serialNumber = fread(fid, numBatches, '*uint32', batchSize-4);
    fseek(fid, filePos+4, 'bof'); % rewind
    acc_x = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, filePos+6, 'bof'); % rewind
    acc_y = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, filePos+8, 'bof'); % rewind
    acc_z = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, filePos+10, 'bof'); % rewind
    temp_amb_obj = fread(fid, numBatches, 'uint16', batchSize-2);
    fseek(fid, filePos+12, 'bof');
    serial_ADS = fread(fid, numBatches, '*uint8', batchSize-1);
    fseek(fid, filePos+13, 'bof');
    eventCounter = fread(fid, numBatches, '*uint8', batchSize-1);
    fseek(fid, filePos+14, 'bof'); % rewind
    bat_level_and_status = fread(fid, numBatches, '*uint8', batchSize-1);
    if respAvailable
        fseek(fid, filePos+15, 'bof'); % rewind
        resp = fread(fid, numBatches, 'bit24', (batchSize*8)-24); % when using bitn, 'skip' argument must be specified in bits, not bytes
    else
        resp = [];
    end
    fseek(fid, filePos+18, 'bof'); % rewind
    leadoff = fread(fid, numBatches, '*uint8', batchSize-1);  
    fseek(fid, filePos+19, 'bof'); % rewind
    conf = fread(fid, numBatches, '*uint8', batchSize-1);
    
    if verbose
        % WARNING: USING THE FILENAME AS AN 8-DIGIT HEX TIMESTAMP - RENAMED FILES BREAKS THIS
    %     recordingStartTime = datetime(hex2dec(ble_name), 'ConvertFrom', 'posixtime', 'TimeZone', 'local');%'Europe/Zurich'
        LengthOfRecondingInSeconds = length(serialNumber) * 0.024;
        [h,m,s] = hms(seconds(LengthOfRecondingInSeconds));
        fprintf('Duration: %02d:%02d:%02.0f (hours:mins:secs)\n',h, m, s);
        fprintf('=======================================================\n');
    end
   
    % PART 2, ECG_1
    if ecg1Available
        filePos = miscOffset + (ecg1Available * 20);
        fseek(fid, filePos, 'bof');
        ecg1_serial = fread(fid, numBatches, 'uint16', batchSize-2);
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
        fseek(fid, filePos, 'bof');
        ecg2_serial = fread(fid, numBatches, 'uint16', batchSize-2);
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
        fseek(fid, filePos, 'bof');
        ecg3_serial = fread(fid, numBatches, 'uint16', batchSize-2);
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
    
    % Split temp into ambient and object
    % ambient when  (serial % 2 ==0) and object when (serial % 2 == 1) ambient
    
    if debug
        % For debugging using bat_adc
        disp('DEBUGGIING SET IN read_ble_24bit.m');
        figure;plot(bat_adc);
        table(unique(bat_adc), histc(bat_adc(:),unique(bat_adc)), round(double(histc(bat_adc(:),unique(bat_adc))./double(length(bat_adc)))*100), 'VariableNames',{'bat_adc' 'Count' 'Percent'})
    end
    
    % Scale accel to g-force
    acc_x = acc_x * 0.00006103515625;
    acc_y = acc_y * 0.00006103515625;
    acc_z = acc_z * 0.00006103515625;
    
    % find indices of missed batches
    missedBatches = find(serialNumber == 0);
    % set ecg, resp, accel, and temp data in missed batches to 'NaN'
    if ~isempty(missedBatches)
        % set accel, temp, resp, and ecg data to 'NaN' in missed batches (instead of 0, as is their current value)
        acc_x(missedBatches) = NaN;
        acc_y(missedBatches) = NaN;
        acc_z(missedBatches) = NaN;
        temp_amb_obj(missedBatches) = NaN;
        % Setting invalid resp samples to NaN may cause trouble in subsequent filtering
%       if ~isempty(resp)
%           resp(missedBatches) = NaN;
%       end
        % building index numbers for missed samples in resp and ecg (6 times as many as in accel, temp, and resp)
        startOfMissed_ecg_resp = ((missedBatches-1)*6)+1;
        endOfMissed_ecg_resp = missedBatches*6;
        idx = coloncat(startOfMissed_ecg_resp, endOfMissed_ecg_resp);
        if ~isempty(ecg1)
            ecg1(idx) = -32768; % NaN or -32768 for Comm error
        end
        if ~isempty(ecg2)
            ecg2(idx) = -32768; % NaN or -32768 for Comm error
        end
        if ~isempty(ecg3)
            ecg3(idx) = -32768; % NaN or -32768 for Comm error
        end
    end
    
    % Scaling temp to Celsius
    temp_amb_obj(temp_amb_obj ~= 0) = (temp_amb_obj(temp_amb_obj ~= 0) * 0.02) - 273.15;
    % Splitting temp into temp_ambient and tenp_object.
    % temp_ambient is stored in batches where mod(serialNumber,2) == 0.
    batchesBeforeFirstValidSerial = (posForValidConf - 19) / batchSize;
    serialOfFirstBatch = first_valid_serial - batchesBeforeFirstValidSerial;
    if mod(serialOfFirstBatch,2) == 0
        temp_ambient = temp_amb_obj(2:2:end);
        temp_object = temp_amb_obj(1:2:end);
    else
        temp_ambient = temp_amb_obj(1:2:end);
        temp_object = temp_amb_obj(2:2:end);
    end
    
    acc = [acc_y, -acc_x, acc_z]; % yes, acc_x = acc_y, and yes, acc_y = -acc_x
    % if we have one less temp_ambient or temp_object sample (because of
    % odd munber of batches), extend with a copy of last sample.
    if (length(temp_object) - length(temp_ambient)) == 1
        % extend temp_ambient with one sample equal to the final sample
        temp_ambient(end+1) = temp_ambient(end);
    elseif (length(temp_ambient) - length(temp_object)) == 1
        % extend temp_object with one sample equal to the final sample
        temp_object(end+1) = temp_object(end);
    end
    
    temp = [temp_ambient, temp_object];
    ecg = [ecg1, ecg2, ecg3];
    ecg_serials = [ecg1_serial, ecg2_serial, ecg3_serial];
    fprintf('c3_read_ble_24bit: %f seconds\n',toc(hTic));
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
% Read BLE files containing Cortrium C3 sensor data.
%--- EDITION FOR DEBUGGING PROCESS TIMES ---%

% The BLE file contains a sequence of batches.
% Each batch contains up to 5 parts, with 20 bytes in each part.

% Part 1 is mandatory, and is structured like so:
% uint32    serial;     % incremented for every batch. If serial number is 0, then the batch is invalid and all data in the batch are 0.    
% int16     acc_x;
% int16     acc_y;
% int16     acc_z;
% uint16    temp_ambient;
% uint16    temp_object;
% uint8     bat_status; % 0 when charging; 1 when discharging
% uint8     bat_level;  % 0-100%
% uint16    bat_adc;
% int8      leadoff;
% uint8     conf;       % bitmask indicating which (if any) of the RESP, ECG1, ECG2, ECG3 parts appear after Part 1. This configuration never changes within the current BLE file.

% The remaining 4 parts are optional, but if present, each part contains
% 10 samples with data type uint16 (in the case of using the Resp and ECG 
% channels to to store process times for debugging).

function [serialNumber, leadoff, acc, temp, proctime, missedBatches] = c3_read_ble_processTimes(ble_fullpath)

    debug = false; % for bat_adc debugging

    acc = []; temp = []; proctime = [];

    fid = fopen(ble_fullpath,'r');

    % FIND THE FIRST VALID SERIAL AND CONF, i.e. serialNumber is NOT zero
    while ~feof(fid)
        tempSerialNumber = fread(fid, 1, '*uint32');
        % if the 4 bytes just read, is a number > 0 
        % it is assumed that a valid serial number was found
        if tempSerialNumber > 0
            % now get the conf
            fseek(fid, 15, 'cof'); % go to  position for a possible conf
            valid_conf = fread(fid, 1, '*uint8');
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
    conf_bin = dec2bin(valid_conf); % conf, in binary form
    respAvailable = (conf_bin(end) == '1');
    ecg1Available = (conf_bin(end-1) == '1');
    ecg2Available = (conf_bin(end-2) == '1');
    ecg3Available = (conf_bin(end-3) == '1');

    % set the file pointer to the start of the file
    frewind(fid);
    numBatches = Inf; % read all batches
    batchSize = 20 + ((respAvailable + ecg1Available + ecg2Available + ecg3Available) * 20); % how many bytes a batch contains, depends on how many sensor signals were included

    % PART 1, MISC, MANDATORY PAYLOAD
    serialNumber = fread(fid, numBatches, '*uint32', batchSize-4);
    fseek(fid, 4, 'bof'); % rewind
    acc_x = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, 6, 'bof'); % rewind
    acc_y = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, 8, 'bof'); % rewind
    acc_z = fread(fid, numBatches, 'int16', batchSize-2);
    fseek(fid, 10, 'bof'); % rewind
    temp_ambient = fread(fid, numBatches, 'uint16', batchSize-2);
    fseek(fid, 12, 'bof'); % rewind
    temp_object = fread(fid, numBatches, 'uint16', batchSize-2);
    fseek(fid, 14, 'bof'); % rewind
    bat_status = fread(fid, numBatches, '*uint8', batchSize-1);
    fseek(fid, 15, 'bof'); % rewind
    bat_level = fread(fid, numBatches, '*uint8', batchSize-1);
    fseek(fid, 16, 'bof'); % rewind
    bat_adc = fread(fid, numBatches, '*uint16', batchSize-2);
    fseek(fid, 18, 'bof'); % rewind
    leadoff = fread(fid, numBatches, '*int8', batchSize-1);  
    fseek(fid, 19, 'bof'); % rewind
    conf = fread(fid, numBatches, '*uint8', batchSize-1);
   
    % PART 2, RESP
    if respAvailable
        fseek(fid, 20, 'bof'); % rewind
        proctime_1 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 22, 'bof');
        proctime_2 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 24, 'bof');
        proctime_3 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 26, 'bof');
        proctime_4 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 28, 'bof');
        proctime_5 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 30, 'bof');
        proctime_6 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 32, 'bof');
        proctime_7 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 34, 'bof');
        proctime_8 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 36, 'bof');
        proctime_9 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, 38, 'bof');
        proctime_10 = fread(fid, numBatches, '*uint16', batchSize-2);

        proctime = [proctime_1,proctime_2,proctime_3,proctime_4,proctime_5,proctime_6,proctime_7,proctime_8,proctime_9,proctime_10];
    end

    % PART 3, ECG_1
    if ecg1Available
        filePos = (respAvailable + ecg1Available) * 20;
        fseek(fid, filePos, 'bof');
        proctime_11 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        proctime_12 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        proctime_13 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        proctime_14 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        proctime_15 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        proctime_16 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        proctime_17 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        proctime_18 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        proctime_19 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        proctime_20 = fread(fid, numBatches, '*uint16', batchSize-2);

        proctime = [proctime,proctime_11,proctime_12,proctime_13,proctime_14,proctime_15,proctime_16,proctime_17,proctime_18,proctime_19,proctime_20];
    end

    % PART 4, ECG_2
    if ecg2Available
        filePos = (respAvailable + ecg1Available + ecg2Available) * 20;
        fseek(fid, filePos, 'bof');
        proctime_21 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        proctime_22 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        proctime_23 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        proctime_24 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        proctime_25 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        proctime_26 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        proctime_27 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        proctime_28 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        proctime_29 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        proctime_30 = fread(fid, numBatches, '*uint16', batchSize-2);

        proctime = [proctime,proctime_21,proctime_22,proctime_23,proctime_24,proctime_25,proctime_26,proctime_27,proctime_28,proctime_29,proctime_30];
    end

    % PART 5, ECG_3
    if ecg3Available
        filePos = (respAvailable + ecg1Available + ecg2Available + ecg3Available) * 20;
        fseek(fid, filePos, 'bof');
        proctime_31 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        proctime_32 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        proctime_33 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        proctime_34 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        proctime_35 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        proctime_36 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        proctime_37 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        proctime_38 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        proctime_39 = fread(fid, numBatches, '*uint16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        proctime_40 = fread(fid, numBatches, '*uint16', batchSize-2);

        proctime = [proctime,proctime_31,proctime_32,proctime_33,proctime_34,proctime_35,proctime_36,proctime_37,proctime_38,proctime_39,proctime_40];
    end
    fclose(fid);
    
    if debug
        % For debugging using bat_adc
        disp('DEBUGGIING SET IN read_ble.m');
        figure;plot(bat_adc);
        table(unique(bat_adc), histc(bat_adc(:),unique(bat_adc)), round(double(histc(bat_adc(:),unique(bat_adc))./double(length(bat_adc)))*100), 'VariableNames',{'bat_adc' 'Count' 'Percent'})
    else
        % scaling temp to Celsius, and accel to g-force
        temp_ambient = (temp_ambient * 0.02) - 273.15;
        temp_object = (temp_object * 0.02) - 273.15;
        acc_x = acc_x * 0.00006103515625;
        acc_y = acc_y * 0.00006103515625;
        acc_z = acc_z * 0.00006103515625;
    end
    
    % find indices of missed batches
    missedBatches = find(serialNumber == 0);
    % set ecg, resp, accel, and temp data in missed batches to 'NaN'
    if ~isempty(missedBatches)
        fprintf('MISSED BATCHES: %d\n',length(missedBatches));
        % set accel, temp to 'NaN' in missed batches (instead of 0, as is their current value)
        acc_x(missedBatches) = NaN;
        acc_y(missedBatches) = NaN;
        acc_z(missedBatches) = NaN;
        temp_ambient(missedBatches) = NaN;
        temp_object(missedBatches) = NaN;
        % proctime is set to 0 in missed batches. Alternatively set to e.g. intmax('uint16') - or use double and set to NaN
        proctime(missedBatches,:) = 0;
    else
        fprintf('MISSED BATCHES: 0\n');
    end
    acc = [acc_y, -acc_x, acc_z]; % yes, acc_x = acc_y, and yes, acc_y = -acc_x
    temp = [temp_ambient, temp_object];
end

% Read BLE (Bluetooth Low Energy) files containing Cortrium C3 sensor data.

% Temporary test call examples:
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\560D10D8_BLE\560D10D8.BLE'); %  1 min recording
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\4_bin\4.BLE'); % 7 min recording
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\55AE3FE3\55AE3FE3.BLE'); % 22 minutes recording
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\56095DAB_BLE\56095DAB.BLE'); % 49 minutes recording
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\25_bin\25.BLE'); % 4,5 hours recording
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\_all signals_2015-10-05 15.32.47 C3_5640\56127BFE.BLE'); % all signals
% [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble('C:\Users\CT\Documents\MATLAB\Cortrium\C3_recordings\_no_resp_2015-10-05 15.29.15 C3_5640\56127B2B.BLE'); % no resp

% The BLE file contains a sequence of batches.
% Each batch contains up to 5 parts, with 20 bytes in each part.

% Part 1, which is mandatory, is structured like so:
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

function [acc_x, acc_y, acc_z, temp_ambient, temp_object, resp, ecg_1, ecg_2, ecg_3] = read_ble(ble_fullpath)
    hTicStart = tic;

    acc_x = []; acc_y = []; acc_z = []; temp_ambient = []; temp_object = []; resp = []; ecg_1 = []; ecg_2 = []; ecg_3 = [];

    [~, ble_filename, ble_extension] = fileparts(ble_fullpath);

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
    hTicPart1 = tic;
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
    % fseek(fid, 20, 'bof'); % rewind
    fprintf('read_ble(''%s%s'') MISC: %f seconds\n',ble_filename,ble_extension,toc(hTicPart1));

    % PART 2, RESP
    if respAvailable
        hTicPart2 = tic;
        fseek(fid, 20, 'bof'); % rewind
        resp_1 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 22, 'bof');
        resp_2 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 24, 'bof');
        resp_3 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 26, 'bof');
        resp_4 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 28, 'bof');
        resp_5 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 30, 'bof');
        resp_6 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 32, 'bof');
        resp_7 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 34, 'bof');
        resp_8 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 36, 'bof');
        resp_9 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, 38, 'bof');
        resp_10 = fread(fid, numBatches, 'int16', batchSize-2);

        resp = reshape([resp_1';resp_2';resp_3';resp_4';resp_5';resp_6';resp_7';resp_8';resp_9';resp_10'],[],1);
        fprintf('read_ble(''%s%s'') RESP: %f seconds\n',ble_filename,ble_extension,toc(hTicPart2));
        clearvars('resp_1','resp_2','resp_3','resp_4','resp_5','resp_6','resp_7','resp_8','resp_9','resp_10');
    end

    % PART 3, ECG_1
    if ecg1Available
        hTicPart3 = tic;
        filePos = (respAvailable + ecg1Available) * 20;
        fseek(fid, filePos, 'bof');
        ecg1_1 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg1_2 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        ecg1_3 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        ecg1_4 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        ecg1_5 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        ecg1_6 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        ecg1_7 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        ecg1_8 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        ecg1_9 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        ecg1_10 = fread(fid, numBatches, 'int16', batchSize-2);

        ecg_1 = reshape([ecg1_1';ecg1_2';ecg1_3';ecg1_4';ecg1_5';ecg1_6';ecg1_7';ecg1_8';ecg1_9';ecg1_10'],[],1);
        fprintf('read_ble(''%s%s'') ECG_1: %f seconds\n',ble_filename,ble_extension,toc(hTicPart3));
        clearvars('ecg1_1','ecg1_2','ecg1_3','ecg1_4','ecg1_5','ecg1_6','ecg1_7','ecg1_8','ecg1_9','ecg1_10');
    end

    % PART 4, ECG_2
    if ecg2Available
        hTicPart4 = tic;
        filePos = (respAvailable + ecg1Available + ecg2Available) * 20;
        fseek(fid, filePos, 'bof');
        ecg2_1 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg2_2 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        ecg2_3 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        ecg2_4 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        ecg2_5 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        ecg2_6 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        ecg2_7 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        ecg2_8 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        ecg2_9 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        ecg2_10 = fread(fid, numBatches, 'int16', batchSize-2);

        ecg_2 = reshape([ecg2_1';ecg2_2';ecg2_3';ecg2_4';ecg2_5';ecg2_6';ecg2_7';ecg2_8';ecg2_9';ecg2_10'],[],1);
        fprintf('read_ble(''%s%s'') ECG_2: %f seconds\n',ble_filename,ble_extension,toc(hTicPart4));
        clearvars('ecg2_1','ecg2_2','ecg2_3','ecg2_4','ecg2_5','ecg2_6','ecg2_7','ecg2_8','ecg2_9','ecg2_10');
    end

    % PART 5, ECG_3
    if ecg3Available
        hTicPart5 = tic;
        filePos = (respAvailable + ecg1Available + ecg2Available + ecg3Available) * 20;
        fseek(fid, filePos, 'bof');
        ecg3_1 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+2, 'bof');
        ecg3_2 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+4, 'bof');
        ecg3_3 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+6, 'bof');
        ecg3_4 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+8, 'bof');
        ecg3_5 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+10, 'bof');
        ecg3_6 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+12, 'bof');
        ecg3_7 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+14, 'bof');
        ecg3_8 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+16, 'bof');
        ecg3_9 = fread(fid, numBatches, 'int16', batchSize-2);
        fseek(fid, filePos+18, 'bof');
        ecg3_10 = fread(fid, numBatches, 'int16', batchSize-2);

        ecg_3 = reshape([ecg3_1';ecg3_2';ecg3_3';ecg3_4';ecg3_5';ecg3_6';ecg3_7';ecg3_8';ecg3_9';ecg3_10'],[],1);
        fprintf('read_ble(''%s%s'') ECG_3: %f seconds\n',ble_filename,ble_extension,toc(hTicPart5));
        clearvars('ecg3_1','ecg3_2','ecg3_3','ecg3_4','ecg3_5','ecg3_6','ecg3_7','ecg3_8','ecg3_9','ecg3_10');
    end
    fclose(fid);

    % scaling temp to Celsius, and accel to g-force
    temp_ambient = (temp_ambient * 0.02) - 273.15;
    temp_object = (temp_object * 0.02) - 273.15;
    acc_x = acc_x * 0.00006103515625;
    acc_y = acc_y * 0.00006103515625;
    acc_z = acc_z * 0.00006103515625;

    fprintf('Serial number of first batch: %d\n',serialNumber(1));
    % find indices of missed batches
    missedBatches = find(serialNumber == 0);
    % set ecg, resp, accel, and temp data in missed batches to 'NaN'
    if ~isempty(missedBatches)
        fprintf('Number of invalid (missed) batches: %d\n',length(missedBatches));
        % set accel, temp, resp, and ecg data to 'NaN' in missed batches (instead of 0, as is their current value)
        acc_x(missedBatches) = NaN;
        acc_y(missedBatches) = NaN;
        acc_z(missedBatches) = NaN;
        temp_ambient(missedBatches) = NaN;
        temp_object(missedBatches) = NaN;
        if ~isempty(ecg_1)
            %ecg_1() = NaN;
        end
        if ~isempty(ecg_2)
            %ecg_2() = NaN;
        end
        if ~isempty(ecg_3)
            %ecg_3() = NaN;
        end
        if ~isempty(resp)
            %resp() = NaN;
        end
    else
        fprintf('Number of invalid (missed) batches: 0\n');
    end

    % Total processing time
    fprintf('read_ble(''%s%s'') Total time: %f seconds\n',ble_filename,ble_extension,toc(hTicStart));
    
end

%% Export Temperature, Acceleration, Respiration, and ECG, to a single CSV file
% The following samplingrate ratios of the sensor data is expected:
% ECG at 250Hz samplingrate.
% Temp at (250/6/2)Hz samplingrate.
% Acc at (250/6)Hz samplingrate.
% Resp at (250/6)Hz samplingrate.

function csv_fullpath = c3_csv(csv_fullpath,tempData,accData,respData,ecgData)
    % Make sure the first argument is a string (should be a path for the
    % csv about to be created).
    if ~ischar(csv_fullpath)
        warning(sprintf('c3_tempAccRespEcg2Csv.m: First argument must be a file path!\nNo csv output!'));
    end
    % Create new matrices for Temp, Accel, and Resp, (if available), with same row count as ECG data.
    % All new matrices will be initialized with NaN.
    % First make sure there is any ECG data
    if isempty(ecgData)
        warning(sprintf('c3_tempAccRespEcg2Csv.m: At least one column of ECG data is expected!\nNo csv output!'));
        csv_fullpath = [];
        return;
    end    
    % Temp data will populate every 12th row.
    if ~isempty(tempData)
        tempExt = NaN(size(ecgData,1),2);
        tempExt(1:12:end,:) = tempData;
    else
        tempExt = [];
    end
    % Acc data will populate every 6th row.
    if ~isempty(accData)
        accExt = NaN(size(ecgData,1),3);
        accExt(1:6:end,:) = accData;
    else
        accExt = [];
    end
    % Resp data (if any) will populate every 6th row.
    if ~isempty(respData)
        respExt = NaN(size(ecgData,1),1);
        respExt(1:6:end,1) = respData;
    else
        respExt = [];
    end
    
    % Build a cell array for the header, and a format string for sprintf, based on what data is available.
    strHeader = [];
    strOut = '';
    % Temp
    if ~isempty(tempData)
        strOut = '%.1f,%.1f';
        strHeader = [{'TEMPOBJ'},{'TEMPDEV'}];
    end
    % Acc
    if ~isempty(accData)
        if isempty(strOut)
            strOut = '%.3f,%.3f,%.3f';
        else
            strOut = [strOut ',%.3f,%.3f,%.3f'];
        end
        strHeader = [strHeader,{'ACCX'},{'ACCY'},{'ACCZ'}];
    end
    % Resp
    if ~isempty(respData)
        if isempty(strOut)
            strOut = '%d';
        else
            strOut = [strOut ',%d'];
        end
        strHeader = [strHeader,{'RESP'}];
    end
    % ECG
    if size(ecgData,2) == 1
        if isempty(strOut)
            strOut = '%d';
        else
            strOut = [strOut ',%d'];
        end
        strHeader = [strHeader,{'ECG1'}];
    elseif size(ecgData,2) == 2
        if isempty(strOut)
            strOut = '%d,%d';
        else
            strOut = [strOut ',%d,%d'];
        end
        strHeader = [strHeader,{'ECG1'},{'ECG2'}];
    else
        if isempty(strOut)
            strOut = '%d,%d,%d';
        else
            strOut = [strOut ',%d,%d,%d'];
        end
        strHeader = [strHeader,{'ECG1'},{'ECG2'},{'ECG3'}];
    end
    % Build a formatted string
    strOut = sprintf([strOut '\r\n'],[tempExt accExt respExt ecgData]');
    % Replace NaN with nothing
    strOut = strrep(strOut, 'NaN', '');

    % If destination path does not exist, create it.
    [csv_path,~,~] = fileparts(csv_fullpath);
    if ~exist(csv_path,'dir')
        mkdir(csv_path);
    end
    % Create and write csv file.
    fid = fopen(csv_fullpath,'w');
    % Write header
    if size(strHeader,2) == 1
        fprintf(fid, '%s\r\n', strHeader{1});
    else
        fprintf(fid, '%s,', strHeader{1,1:end-1});
        fprintf(fid, '%s\r\n', strHeader{1,end});
    end
    % Write data
    fprintf(fid, '%s', strOut);
    % Close file
    fclose(fid);
end
classdef c3_ecg < c3_sensor
    properties
        nbchan
    end
    
    methods
        function this = c3_ecg(path)
            this.filepath = path;
            this.fs = 250;
        end
        
        function load_data(this)
            this.data = [];
            
            % Read data
            ecg_files = dir(fullfile(this.filepath, 'ecg*_raw.bin'));
            ecg_files = {ecg_files.name};
            for i = 1:length(ecg_files)
                fid = fopen(fullfile(this.filepath, ecg_files{i}), 'r');
                this.data = horzcat(this.data, fread(fid, Inf, 'int16', 0, 'native'));
                fclose(fid);
            end
            this.data(abs(this.data) > 32764) = NaN;
            this.samplenum = length(this.data);
        end 
    end
end
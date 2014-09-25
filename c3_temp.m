classdef c3_temp < c3_sensor
   
    methods
        function this = c3_temp(path)
            % Initialise object
            this.filepath = path;
            this.fs = 25;
        end
        
        function load_data(this)
            % Read in temperature data. Two channels with target and
            % ambient temperature
            % Format is signed 16 bit integer with 25 samples per second
            
            fid = fopen(fullfile(this.filepath,'temp.bin'),'r');
            [tmp_data, tmp_samples] = fread(fid, [2, Inf], 'int16');
            fclose(fid);
            
            this.data = tmp_data' * 0.02 - 273.15;
            this.samplenum = tmp_samples;
        end
    end
    
end
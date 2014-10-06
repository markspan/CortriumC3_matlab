classdef c3_accel < c3_sensor
    properties
        magnitude
    end
    
    methods
        function this = c3_accel(path)
            % Initialise object
            this.filepath = path;
            this.fs = 25;
        end
        
        function load_data(this)
            % Read in accelerometer data
            % format is 16 bit signed with 25 samples per second on each axis
            
            fid = fopen(fullfile(this.filepath,'accel.bin'),'r');
            [tmp_data, ~] = fread(fid, [3, inf], 'float');
            fclose(fid);
            
            this.data = tmp_data';
            this.samplenum = length(this.data);
        end
    end
    
end
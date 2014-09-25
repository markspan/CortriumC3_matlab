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
            for i = 1:2
                fid = fopen(fullfile(this.filepath,sprintf('ecg%d_raw.bin',i)),'r');
                this.data = horzcat(this.data, fread(fid, Inf, 'int16', 0, 'native'));
                fclose(fid);
            end
            this.data(abs(this.data)>32676) = 0;
            this.samplenum = length(this.data);
        end 
    end
end
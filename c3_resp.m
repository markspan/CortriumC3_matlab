classdef c3_resp < c3_sensor
    properties
        rate
        smoothened = false;
    end
    
    properties(Access = private)
        mintab
        maxtab
    end
    
    methods
        function this = c3_resp(path)
            this.filepath = path;
            this.fs = 250;
        end
        
        function load_data(this)            
            % Read data
            fid = fopen(fullfile(this.filepath,'resp_raw.bin'),'r');
            this.data = fread(fid, Inf, 'uint16', 0, 'native');
            fclose(fid);
            this.data(abs(this.data)>32676) = 0;
            
            this.samplenum = length(this.data);
        end
        
        function smoothen(this)
            % Filter
            h = fdesign.lowpass('N,Fp,Fst',256,0.5,0.8,this.fs);
            d = design(h,'equiripple');
            this.data = filtfilt(d.Numerator,1, this.data); %zero-phase filtering
            
            this.smoothened = true;
        end
        
        function [maxtab, mintab] = find_peaks(this, section)
            % Find local minima and maxima. Make sure to filter the data
            % beforehand
            [maxtab, mintab] = peakdet(this.data(section), 20);
            this.maxtab = maxtab;
            this.mintab = mintab; 
        end
        
        function calc_rate(this, section)
            % Calculate breathing rate from peaks in the signal
            if nargin < 2
                section = 1:this.samplenum;
                fprintf('Section not defined, using full length\n');
            end
            this.find_peaks(section);
            this.rate = min([length(this.maxtab), length(this.mintab)])...
                        / (length(section)/this.fs/60);
            fprintf('Respiration rate: %2.1f\n', this.rate);
        end
        
        function show_peaks(this, section)
            if nargin < 2
                section = 1:this.samplenum;
                fprintf('Section not defined, using full length\n');
            end
            
            % Find peaks for section of data
            this.find_peaks(section);
            
            %Plot
            figure, hold on
            plot(this.data(section));
            plot(this.mintab(:,1), this.mintab(:,2),'r*')
            plot(this.maxtab(:,1), this.maxtab(:,2),'r*')
        end
        
    end
    
end
classdef cortrium_c3 < handle
    %% Cortrium C3 device MATLAB script for reading sensor data
    % (c) 2014 Cortrium
    properties
        ecg
        accel
        resp
        temp
        bat
        date_start
        date_end
    end
    properties (Access = private)
        data_dir
    end
    
    methods
        function C3 = cortrium_c3(path)
            % Assign directory with .bin-files
            C3.data_dir = path;
        end
        
        function initialize(C3)
            % Load the invidiual classes and data from files
            C3.ecg = c3_ecg(C3.data_dir);
            C3.ecg.load_data;
            
            C3.accel = c3_accel(C3.data_dir);
            C3.accel.load_data;
            
            if exist(fullfile(C3.data_dir,'resp_raw.bin'), 'file') == 2
                C3.resp = c3_resp(C3.data_dir);
                C3.resp.load_data;
            end
            
            C3.temp = c3_temp(C3.data_dir);
            C3.temp.load_data;
            
            C3.bat = c3_bat(C3.data_dir);
            C3.bat.load_data;
            
            C3.get_time_stamps;
        end
        
        function get_time_stamps(C3)
            C3.date_start = C3.bat.find_date;
            C3.date_end = addtodate(C3.date_start, C3.ecg.samplenum*1000/C3.ecg.fs, 'millisecond');
        end
        
        function clean_sensor_data(C3)
            filter_length = 10;
            C3.accel.remove_jitter(filter_length);
            C3.temp.remove_jitter(filter_length);
        end
        
        function respiration_test(C3)
            % Test and smoothen a section of the data
            test_section = 1:1e4;
            
            if ~C3.resp.smoothened
                C3.resp.smoothen;
            end
            C3.resp.show_peaks(test_section);
            C3.resp.calc_rate(test_section);
        end
    end %methods
end %def
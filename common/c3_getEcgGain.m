% Returns gain value for ECG signal, from a valid C3 BLE conf byte.
% Only meaningful for conf's from 24bit BLE files.
% Input argument 'valid_conf' is a uint8 byte.
function c3ecgGain = c3_getEcgGain(valid_conf)
    c3ecgGain = []; 
    % Check if 'de2bi' function (from Communications System toolbox) is available
    if ~isempty(which('de2bi'))
        % Bitwise AND, to nullify bits that do not concern the gain setting.
        conf_gain_bin = and(de2bi(valid_conf,8,'left-msb'),[1 1 1 0 0 0 0 0]);
        % Comparing value of gain binary array to hex values for specific gains.
        if bi2de(conf_gain_bin,'left-msb') == hex2dec('20')
            c3ecgGain = 1;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('40')
            c3ecgGain = 2;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('60')
            c3ecgGain = 3;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('80')
            c3ecgGain = 4;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('00')
            c3ecgGain = 6;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('A0')
            c3ecgGain = 8;
        elseif bi2de(conf_gain_bin,'left-msb') == hex2dec('C0')
            c3ecgGain = 12;
        end
    % Else, use base MATLAB functions 'dec2bin' and 'bin2dec'
    else
        % conf, in binary form
        conf_bin = dec2bin(valid_conf,8);
        if bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000']) == hex2dec('20')
            c3ecgGain = 1;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('40')
            c3ecgGain = 2;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('60')
            c3ecgGain = 3;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('80')
            c3ecgGain = 4;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('00')
            c3ecgGain = 6;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('A0')
            c3ecgGain = 8;
        elseif bin2dec([conf_bin(1) conf_bin(2) conf_bin(3) '00000'])  == hex2dec('C0')
            c3ecgGain = 12;
        end
    end
end
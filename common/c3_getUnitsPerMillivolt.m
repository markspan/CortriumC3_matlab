% C3 ECG data is ~3495.253 units pr millivolt, for 24bit at gain 1,
% and 5243 units pr millivolt, for 16bit ECG data (no gain variations).
function c3ecgUnitsPerMv = c3_getUnitsPerMillivolt(c3fileFormat,c3ecgGain)
% if 24bit ECG-format BLE file
if strcmp(c3fileFormat,'BLE 24bit')
    % 24bits resolution across a voltage span of 4.8 Volts (-2.4 to 2.4 Volts)
    units_mV_gain1 = (2^24)/4800;
    switch c3ecgGain
        case 1
            c3ecgUnitsPerMv = units_mV_gain1;
        case 2
            c3ecgUnitsPerMv = units_mV_gain1*2;
        case 3
            c3ecgUnitsPerMv = units_mV_gain1*3;
        case 4
            c3ecgUnitsPerMv = units_mV_gain1*4;
        case 5
            c3ecgUnitsPerMv = units_mV_gain1*5;
        case 6
            c3ecgUnitsPerMv = units_mV_gain1*6;
        case 8
            c3ecgUnitsPerMv = units_mV_gain1*8;
        case 12
            c3ecgUnitsPerMv = units_mV_gain1*12;
        otherwise
            c3ecgUnitsPerMv = [];
    end
% else, 16bit ECG-format BLE file
else
    c3ecgUnitsPerMv = 5243.0;
end

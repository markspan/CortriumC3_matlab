function oldId = c3_newDeviceId2human(newDeviceId_first_4_digits)
    % when new device id is:  B6_C3_A9B0E48FC320   
    % call: c3_newDeviceId2human('A9B0')
    % ans = 5225
    newDeviceId_reordered = [newDeviceId_first_4_digits(3) newDeviceId_first_4_digits(4) newDeviceId_first_4_digits(1) newDeviceId_first_4_digits(2)];
    oldId = mod(hex2dec(newDeviceId_reordered),10000);
end
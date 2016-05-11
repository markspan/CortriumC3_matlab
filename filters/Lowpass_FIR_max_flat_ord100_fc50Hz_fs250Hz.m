function Hd = Lowpass_FIR_max_flat_ord100_fc50Hz_fs250Hz
%LOWPASS_MAX_FLAT_ORD100_FC50HZ_FS250HZ Returns a discrete-time filter object.

% FIR maximally flat Lowpass filter designed using the MAXFLAT function.

% Discrete-Time FIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 50                                   
% Stable              : Yes                                  
% Linear Phase        : No                                   
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 135                     
% Number of Adders                 : 100                     
% Number of States                 : 100                     
% Multiplications per Input Sample : 135                     
% Additions per Input Sample       : 100                     

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 100;  % Order
Fc = 50;   % Cutoff Frequency

%% Calculate the second-order sections coefficients to avoid round-off
%errors.
[b,a,b1,b2,sos_var,g] = maxflat(N, 'sym', Fc/(Fs/2));
Hd                    = dfilt.df2sos(sos_var, g);

% [EOF]

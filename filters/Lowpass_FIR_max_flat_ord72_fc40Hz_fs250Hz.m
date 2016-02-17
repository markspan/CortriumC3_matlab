function Hd = Lowpass_FIR_max_flat_ord72_fc40Hz_fs250Hz
%LOWPASS_FIR_MAX_FLAT_ORD72_FC40HZ_FS250HZ Returns a discrete-time filter object.

% FIR maximally flat Lowpass filter designed using the MAXFLAT function.

% Discrete-Time FIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 36                                   
% Stable              : Yes                                  
% Linear Phase        : Yes (Type 1)                         
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 99                      
% Number of Adders                 : 72                      
% Number of States                 : 72                      
% Multiplications per Input Sample : 99                      
% Additions per Input Sample       : 72                      

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 72;  % Order
Fc = 40;  % Cutoff Frequency

%% Calculate the second-order sections coefficients to avoid round-off
%errors.
[b,a,b1,b2,sos_var,g] = maxflat(N, 'sym', Fc/(Fs/2));
Hd                    = dfilt.df2sos(sos_var, g);

% [EOF]

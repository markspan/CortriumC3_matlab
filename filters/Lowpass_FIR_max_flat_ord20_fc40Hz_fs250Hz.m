function Hd = Lowpass_FIR_max_flat_ord20_fc40Hz_fs250Hz
%LOWPASS_MAX_FLAT_ORD20_FC40HZ_FS250HZ Returns a discrete-time filter object.

% FIR maximally flat Lowpass filter designed using the MAXFLAT function.

% Discrete-Time FIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 10                                   
% Stable              : Yes                                  
% Linear Phase        : Yes (Type 1)                         
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 28                      
% Number of Adders                 : 20                      
% Number of States                 : 20                      
% Multiplications per Input Sample : 28                      
% Additions per Input Sample       : 20                      

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 20;  % Order
Fc = 40;  % Cutoff Frequency

%% Calculate the second-order sections coefficients to avoid round-off
%errors.
[b,a,b1,b2,sos_var,g] = maxflat(N, 'sym', Fc/(Fs/2));
Hd                    = dfilt.df2sos(sos_var, g);

% [EOF]

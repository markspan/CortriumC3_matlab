function Hd = Lowpass_FIR_max_flat_ord10_fc40Hz_fs250Hz
%LOWPASS_MAX_FLAT_ORD10_FC40HZ_FS250HZ Returns a discrete-time filter object.

% FIR maximally flat Lowpass filter designed using the MAXFLAT function.

% Discrete-Time FIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 5                                    
% Stable              : Yes                                  
% Linear Phase        : Yes (Type 1)                         
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 14                      
% Number of Adders                 : 10                      
% Number of States                 : 10                      
% Multiplications per Input Sample : 14                      
% Additions per Input Sample       : 10    

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 10;  % Order
Fc = 40;  % Cutoff Frequency

%% Calculate the second-order sections coefficients to avoid round-off
%errors.
[b,a,b1,b2,sos_var,g] = maxflat(N, 'sym', Fc/(Fs/2));
Hd                    = dfilt.df2sos(sos_var, g);

% [EOF]

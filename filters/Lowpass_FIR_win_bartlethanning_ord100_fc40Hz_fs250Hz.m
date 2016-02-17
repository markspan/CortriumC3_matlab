function Hd = Lowpass_FIR_win_bartlethanning_ord100_fc40Hz_fs250Hz
%LOWPASS_WIN_BARTLETHANNING_ORD100_FC40HZ_FS250HZ Returns a discrete-time filter object.

% FIR Window Lowpass filter designed using the FIR1 function.

% Discrete-Time FIR Filter (real)       
% -------------------------------       
% Filter Structure  : Direct-Form FIR   
% Filter Length     : 101               
% Stable            : Yes               
% Linear Phase      : Yes (Type 1)      
%                                       
% Implementation Cost                   
% Number of Multipliers            : 99 
% Number of Adders                 : 98 
% Number of States                 : 100
% Multiplications per Input Sample : 99 
% Additions per Input Sample       : 98 

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N    = 100;      % Order
Fc   = 40;       % Cutoff Frequency
flag = 'scale';  % Sampling Flag

% Create the window vector for the design algorithm.
win = barthannwin(N+1);

% Calculate the coefficients using the FIR1 function.
b  = fir1(N, Fc/(Fs/2), 'low', win, flag);
Hd = dfilt.dffir(b);

% [EOF]

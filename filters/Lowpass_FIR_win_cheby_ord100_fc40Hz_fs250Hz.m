function Hd = Lowpass_FIR_win_cheby_ord100_fc40Hz_fs250Hz
%LOWPASS_WIN_CHEBY_ORD100_FC40HZ_FS250HZ Returns a discrete-time filter object.

% FIR Window Lowpass filter designed using the FIR1 function.

% Discrete-Time FIR Filter (real)       
% -------------------------------       
% Filter Structure  : Direct-Form FIR   
% Filter Length     : 101               
% Stable            : Yes               
% Linear Phase      : Yes (Type 1)      
%                                       
% Implementation Cost                   
% Number of Multipliers            : 101
% Number of Adders                 : 100
% Number of States                 : 100
% Multiplications per Input Sample : 101
% Additions per Input Sample       : 100

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N             = 100;      % Order
Fc            = 40;       % Cutoff Frequency
flag          = 'scale';  % Sampling Flag
SidelobeAtten = 100;      % Window Parameter

% Create the window vector for the design algorithm.
win = chebwin(N+1, SidelobeAtten);

% Calculate the coefficients using the FIR1 function.
b  = fir1(N, Fc/(Fs/2), 'low', win, flag);
Hd = dfilt.dffir(b);

% [EOF]

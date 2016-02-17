function Hd = Highpass_IIR_butterw_ord2_fc05Hz_fs250Hz
%HIGHPASS_IIR_BUTTERW_ORD2_FC05HZ_FS250HZ Returns a discrete-time filter object.

% Butterworth Highpass filter designed using FDESIGN.HIGHPASS.

% Discrete-Time IIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 1                                    
% Stable              : Yes                                  
% Linear Phase        : No                                   
%                                                            
% Design Method Information                                  
% Design Algorithm : butter                                  
%                                                            
% Design Options                                             
% Scale Norm   : no scaling                                  
% SystemObject : false                                       
%                                                            
% Design Specifications                                      
% Sample Rate   : N/A (normalized frequency)                 
% Response      : Highpass                                   
% Specification : N,F3dB                                     
% Filter Order  : 2                                          
% 3-dB Point    : 0.004                                      
%                                                            
% Measurements                                               
% Sample Rate      : N/A (normalized frequency)              
% Stopband Edge    : Unknown                                 
% 6-dB Point       : 0.0030394                               
% 3-dB Point       : 0.004                                   
% Passband Edge    : Unknown                                 
% Stopband Atten.  : Unknown                                 
% Passband Ripple  : Unknown                                 
% Transition Width : Unknown                                 
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 4                       
% Number of Adders                 : 4                       
% Number of States                 : 2                       
% Multiplications per Input Sample : 4                       
% Additions per Input Sample       : 4                       

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 2;    % Order
Fc = 0.5;  % Cutoff Frequency

% Construct an FDESIGN object and call its BUTTER method.
h  = fdesign.highpass('N,F3dB', N, Fc, Fs);
Hd = design(h, 'butter');

% [EOF]

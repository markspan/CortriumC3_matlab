function Hd = Highpass_IIR_butterw_ord12_fc05Hz_fs250Hz
%HIGHPASS_IIR_BUTTERW_ORD12_FC05HZ_FS250HZ Returns a discrete-time filter object.

% Butterworth Highpass filter designed using FDESIGN.HIGHPASS.

% Discrete-Time IIR Filter (real)                            
% -------------------------------                            
% Filter Structure    : Direct-Form II, Second-Order Sections
% Number of Sections  : 6                                    
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
% Filter Order  : 12                                         
% 3-dB Point    : 0.004                                      
%                                                            
% Measurements                                               
% Sample Rate      : N/A (normalized frequency)              
% Stopband Edge    : Unknown                                 
% 6-dB Point       : 0.003821                                
% 3-dB Point       : 0.004                                   
% Passband Edge    : Unknown                                 
% Stopband Atten.  : Unknown                                 
% Passband Ripple  : Unknown                                 
% Transition Width : Unknown                                 
%                                                            
% Implementation Cost                                        
% Number of Multipliers            : 24                      
% Number of Adders                 : 24                      
% Number of States                 : 12                      
% Multiplications per Input Sample : 24                      
% Additions per Input Sample       : 24                      

% All frequency values are in Hz.
Fs = 250;  % Sampling Frequency

N  = 12;   % Order
Fc = 0.5;  % Cutoff Frequency

% Construct an FDESIGN object and call its BUTTER method.
h  = fdesign.highpass('N,F3dB', N, Fc, Fs);
Hd = design(h, 'butter');

% [EOF]

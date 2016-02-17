function Hd = Lowpass_IIR_butterw_ord12_fc40Hz_fs250Hz
%LOWPASS_IIR_BUTTERW_ORD12_FC40HZ_FS250HZ Returns a discrete-time filter object.

% Butterworth Lowpass filter designed using FDESIGN.LOWPASS.

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
% Response      : Lowpass                                    
% Specification : N,F3dB                                     
% Filter Order  : 12                                         
% 3-dB Point    : 0.32                                       
%                                                            
% Measurements                                               
% Sample Rate      : N/A (normalized frequency)              
% Passband Edge    : Unknown                                 
% 3-dB Point       : 0.32                                    
% 6-dB Point       : 0.33245                                 
% Stopband Edge    : Unknown                                 
% Passband Ripple  : Unknown                                 
% Stopband Atten.  : Unknown                                 
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

N  = 12;  % Order
Fc = 40;  % Cutoff Frequency

% Construct an FDESIGN object and call its BUTTER method.
h  = fdesign.lowpass('N,F3dB', N, Fc, Fs);
Hd = design(h, 'butter');

% [EOF]

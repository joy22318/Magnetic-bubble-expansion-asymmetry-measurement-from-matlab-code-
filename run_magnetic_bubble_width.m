% RUN_SWEEP  Pick the folder of sweep images and analyse the whole Hx series.
% Needs measureBubbleWidth.m and analyzeHxSweep.m on the MATLAB path.

clear; clc;

pixelSize  = 1;      % micrometres per pixel; leave 1 to work in pixels
pulseWidth = [];     % single-pulse duration in seconds; [] to skip velocity

folder = uigetdir(pwd, 'Select the folder with the sweep images');
if isequal(folder, 0)
    disp('Cancelled.');
    return
end

[T, R] = analyzeHxSweep(folder, ...
    'HxStart', -500, 'HxStep', 10, 'HxEnd', 500, 'Pulses', 4, ...
    'SortBy', 'name', ...            % use 'date' if file names are not ordered
    'PixelSize', pixelSize, ...
    'PulseWidth', pulseWidth, ...
    'Strict', true);                 % set false to run on a partial folder

disp(head(T, 5));
% RUN_BUBBLE  Pick one image, measure the bubble, print the numbers.
% Needs measureBubbleWidth.m on the MATLAB path (same folder is fine).

clear; clc;

pixelSize = 1;      % micrometres per pixel; leave 1 to get pixels

[fname, fpath] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp', ...
    'Image files'}, 'Select a bubble image');
if isequal(fname, 0)
    disp('Cancelled.');
    return
end

S = measureBubbleWidth(fullfile(fpath, fname), 'PixelSize', pixelSize, 'Show', true);

if pixelSize == 1
    u = 'px';
else
    u = 'um';
end

fprintf('\nFile              : %s\n', S.file);
fprintf('Wall displacement : %.1f +/- %.1f %s (mean over all angles)\n', ...
    S.widthMean, S.widthStd, u);
fprintf('  right / left    : %.1f / %.1f %s   asymmetry %.1f %s\n', ...
    S.widthRight, S.widthLeft, u, S.asymmetryX, u);
fprintf('  up / down       : %.1f / %.1f %s\n', S.widthUp, S.widthDown, u);
fprintf('Outer diameter    : %.1f %s (area-equivalent)\n', S.outerDiameterEq, u);
fprintf('Initial bubble    : %.1f %s (area-equivalent)\n', S.innerDiameterEq, u);
fprintf('Outer bounding box: %.1f x %.1f %s\n', S.outerWidthX, S.outerHeightY, u);

% Width versus azimuth, the curve used for the angular creep fit.
figure('Color', 'w');
plot(S.theta, S.width, 'b-', 'LineWidth', 1.2);
xlabel('azimuth (deg)'); ylabel(['wall displacement (' u ')']);
title(S.file, 'Interpreter', 'none'); grid on; xlim([0 360]);
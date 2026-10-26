% RUN_BUBBLE_BATCH  Pick many images, measure each bubble, save
% delta_y_up / delta_y_down to a text file in image order.
% Needs measureBubbleWidth.m on the MATLAB path (same folder is fine).
clear; clc;
pixelSize = 1;      % micrometres per pixel; leave 1 to get pixels
showFigs  = false;  % true = measureBubbleWidth figure for every image

[fnames, fpath] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp', ...
    'Image files'}, 'Select bubble images', 'MultiSelect', 'on');
if isequal(fnames, 0)
    disp('Cancelled.');
    return
end
if ischar(fnames), fnames = {fnames}; end   % single pick -> cell
fnames = natsortNames(fnames);              % img2 before img10

if pixelSize == 1, u = 'px'; else, u = 'um'; end

n  = numel(fnames);
dU = nan(n, 1);
dD = nan(n, 1);
for k = 1:n
    try
        S = measureBubbleWidth(fullfile(fpath, fnames{k}), ...
            'PixelSize', pixelSize, 'Show', showFigs);
        dU(k) = S.widthUp;
        dD(k) = S.widthDown;
        fprintf('%3d  %-30s  up %.2f  down %.2f %s\n', ...
            k, fnames{k}, dU(k), dD(k), u);
    catch ME
        fprintf('%3d  %-30s  FAILED: %s\n', k, fnames{k}, ME.message);
    end
end

% Tab-separated, one row per image, same order as above (NaN = failed)
outFile = fullfile(fpath, 'delta_y_up_down.txt');
fid = fopen(outFile, 'w');
assert(fid > 0, 'Cannot write %s', outFile);
fprintf(fid, 'index\tfile\tdelta_y_up_%s\tdelta_y_down_%s\n', u, u);
for k = 1:n
    fprintf(fid, '%d\t%s\t%.4f\t%.4f\n', k, fnames{k}, dU(k), dD(k));
end
fclose(fid);
fprintf('\nSaved %d rows to %s\n', n, outFile);

function out = natsortNames(c)
% Zero-pad every digit run so plain text sort gives numeric order.
keys = regexprep(lower(c), '(\d+)', '${[repmat(''0'',1,20-numel($1)) $1]}');
[~, idx] = sort(keys);
out = c(idx);
end
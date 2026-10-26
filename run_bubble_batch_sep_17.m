% RUN_BUBBLE_BATCH  Pick many images, measure each bubble, save
% delta_y_up / delta_y_down to a text file in image order, and save one
% two-contour figure per image WITH a scale bar.
% Needs measureBubbleWidth.m on the MATLAB path (same folder is fine).
clear; clc;
pixelSize  = 1;      % micrometres per pixel; leave 1 to get pixels
showFigs   = true;   % true = contour figure on screen for every image
saveFigs   = true;   % true = also write the contour figure to disk

% ---- scale bar ----
nmPerPixel   = 47;              % 1 px = 47 nm
scaleChoices = [10 20 30 50];   % allowed bar lengths, micrometres
scaleFrac    = 0.25;            % longest bar <= this fraction of image width
scaleFixed   = [];              % e.g. 20 to force 20 um; [] = pick automatically

[fnames, fpath] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp', ...
'Image files'}, 'Select bubble images', 'MultiSelect', 'on');
if isequal(fnames, 0)
    disp('Cancelled.');
return
end
if ischar(fnames), fnames = {fnames}; end   % single pick -> cell
fnames = natsortNames(fnames);              % img2 before img10
if pixelSize == 1, u = 'px'; else, u = 'um'; end
figDir = fullfile(fpath, 'contours');
if saveFigs && ~exist(figDir, 'dir'), mkdir(figDir); end
n  = numel(fnames);
dU = nan(n, 1);
dD = nan(n, 1);
for k = 1:n
try
        if saveFigs
            [~, base] = fileparts(fnames{k});
            savePath = fullfile(figDir, [base '_contour.png']);
        else
            savePath = '';
        end
        % Show is forced true so the figure stays open long enough to get the
        % scale bar; saving is done here, after the bar is drawn.
        figsBefore = findall(0, 'Type', 'figure');
        S = measureBubbleWidth(fullfile(fpath, fnames{k}), ...
'PixelSize', pixelSize, 'Show', true);
        newFigs = setdiff(findall(0, 'Type', 'figure'), figsBefore);
        fh = newFigs(end);
        set(fh, 'Visible', matlab.lang.OnOffSwitchState(showFigs));
        addScaleBar(fh, nmPerPixel, scaleChoices, scaleFrac, scaleFixed);
        if saveFigs
            if exist('exportgraphics', 'file')
                exportgraphics(fh, savePath, 'Resolution', 300);
            else
                print(fh, savePath, '-dpng', '-r300');
            end
        end
        if ~showFigs, close(fh); end
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
if saveFigs, fprintf('Contour figures: %s\n', figDir); end

function out = natsortNames(c)
% Zero-pad every digit run so plain text sort gives numeric order.
keys = regexprep(lower(c), '(\d+)', '${[repmat(''0'',1,20-numel($1)) $1]}');
[~, idx] = sort(keys);
out = c(idx);
end

function addScaleBar(fh, nmPerPixel, choices, frac, fixedLen)
% White bar on a translucent black plate, bottom right of the image axes.
% Length picked as the longest allowed value that stays under frac*width.
imh = findobj(fh, 'Type', 'image');
if isempty(imh), return; end
ax = ancestor(imh(1), 'axes');
[Himg, Wimg, ~] = size(get(imh(1), 'CData'));

umPerPixel = nmPerPixel / 1000;
if ~isempty(fixedLen)
    Lum = fixedLen;
else
    fits = find(choices / umPerPixel <= frac * Wimg, 1, 'last');
    if isempty(fits), fits = 1; end
    Lum = choices(fits);
end
Lpx = Lum / umPerPixel;

barH = max(4, round(0.012 * Himg));
mx   = 0.045 * Wimg;                 % right margin
my   = 0.055 * Himg;                 % bottom margin
x1   = Wimg - mx - Lpx;
y1   = Himg - my - barH;
padx = 0.015 * Wimg;
pady = 0.012 * Himg;
txtH = 0.055 * Himg;                 % room for the label above the bar

wasHeld = ishold(ax); hold(ax, 'on');
% backing plate so the bar reads on light and dark background alike
px = [x1-padx, x1+Lpx+padx, x1+Lpx+padx, x1-padx];
py = [y1-txtH-pady, y1-txtH-pady, y1+barH+pady, y1+barH+pady];
patch(ax, 'XData', px, 'YData', py, 'FaceColor', 'k', ...
    'FaceAlpha', 0.55, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% the bar
patch(ax, 'XData', [x1 x1+Lpx x1+Lpx x1], 'YData', [y1 y1 y1+barH y1+barH], ...
    'FaceColor', 'w', 'EdgeColor', 'none', 'HandleVisibility', 'off');
% the label
text(ax, x1 + Lpx/2, y1 - 0.4*pady, sprintf('%g \\mum', Lum), ...
    'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'Interpreter', 'tex');
if ~wasHeld, hold(ax, 'off'); end
end

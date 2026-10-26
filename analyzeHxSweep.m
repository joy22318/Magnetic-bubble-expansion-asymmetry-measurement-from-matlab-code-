function [T, R] = analyzeHxSweep(folder, varargin)
%ANALYZEHXSWEEP  Batch analysis of a bubble-expansion Hx sweep.
%
%   [T, R] = analyzeHxSweep(FOLDER) reads every image in FOLDER, groups them
%   into blocks of four (one block per in-plane field value), measures the
%   swept-ring width with measureBubbleWidth, divides each width by the
%   number of pulses that produced it, and writes the results to text files.
%
%   Image order model, matching the MagVision sweep script:
%     images 1..4    -> Hx = HxStart          , pulses 1,2,3,4
%     images 5..8    -> Hx = HxStart + HxStep , pulses 1,2,3,4
%     ...
%   The reference frame is taken once before expansion and kept for all four
%   pulses, so the measured width is cumulative. Dividing by the pulse index
%   therefore gives the displacement per pulse, which is what feeds the
%   velocity and the DMI fit.
%
%   Name-value options
%     'HxStart'   First field value. Default -500.
%     'HxStep'    Field step. Default 10.
%     'HxEnd'     Last field value. Default 500.
%     'Pulses'    Images per field value. Default 4.
%     'SortBy'    'name' (natural numeric order) or 'date' (file timestamp).
%                 Default 'name'.
%     'PixelSize' Micrometres per pixel. Default 1, so output is in pixels.
%     'PulseWidth' Single-pulse duration in seconds. If given, a velocity
%                 column du/(n*PulseWidth) is added. Default [] (skipped).
%     'OutFile'   Main results file. Default 'hx_sweep_results.txt'.
%     'Strict'    Error if the image count does not match nHx*Pulses.
%                 Default true. Set false to analyse what is present.
%   Any other option is forwarded to measureBubbleWidth (Sigma, MinArea,
%   LabelMask, ...).
%
%   Outputs
%     T  table, one row per Hx, per-pulse-normalised displacements
%     R  table, one row per image, raw and normalised values
%   Both are written into FOLDER/analysis as tab-delimited text.
%
%   Example
%     T = analyzeHxSweep('C:\data\sweep', 'PixelSize', 0.42, 'SortBy', 'date');

% ---------------------------------------------------------------- options
known = {'HxStart', 'HxStep', 'HxEnd', 'Pulses', 'SortBy', 'PixelSize', ...
         'PulseWidth', 'OutFile', 'Strict'};
opt = struct('HxStart', -500, 'HxStep', 10, 'HxEnd', 500, 'Pulses', 4, ...
             'SortBy', 'name', 'PixelSize', 1, 'PulseWidth', [], ...
             'OutFile', 'hx_sweep_results.txt', 'Strict', true);
fwd = {};                       % options passed on to measureBubbleWidth
for i = 1:2:numel(varargin)
    nameArg = varargin{i};
    if any(strcmpi(nameArg, known))
        opt.(known{strcmpi(nameArg, known)}) = varargin{i+1};
    else
        fwd(end+1:end+2) = varargin(i:i+1); %#ok<AGROW>
    end
end

if nargin < 1 || isempty(folder)
    folder = pwd;
end
if ~exist(folder, 'dir')
    error('analyzeHxSweep:noFolder', 'Folder not found: %s', folder);
end

Hx  = opt.HxStart:opt.HxStep:opt.HxEnd;
nHx = numel(Hx);
nP  = opt.Pulses;

% ------------------------------------------------------------- file list
exts = {'*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff', '*.bmp'};
names = {}; dates = [];
for e = 1:numel(exts)
    d = dir(fullfile(folder, exts{e}));
    for i = 1:numel(d)
        if ~d(i).isdir
            names{end+1,1} = d(i).name;      %#ok<AGROW>
            dates(end+1,1) = d(i).datenum;   %#ok<AGROW>
        end
    end
end
if isempty(names)
    error('analyzeHxSweep:noImages', 'No images found in %s', folder);
end

if strcmpi(opt.SortBy, 'date')
    [~, ord] = sort(dates);
else
    ord = naturalOrder(names);
end
names = names(ord);
nImg  = numel(names);

expected = nHx * nP;
if nImg ~= expected
    msg = sprintf(['Found %d images but expected %d (%d field values x %d ' ...
                   'pulses). Check HxStart/HxStep/HxEnd/Pulses, or that no ' ...
                   'extra files sit in the folder.'], nImg, expected, nHx, nP);
    if opt.Strict
        error('analyzeHxSweep:countMismatch', '%s', msg);
    else
        warning('analyzeHxSweep:countMismatch', '%s', msg);
    end
end

outDir = fullfile(folder, 'analysis');
if ~exist(outDir, 'dir'); mkdir(outDir); end

% -------------------------------------------------------- per-image loop
nUse = min(nImg, expected);
raw  = nan(nUse, 6);        % mean right left up down asym, raw pixels->units
hxOf = nan(nUse, 1);
pnOf = nan(nUse, 1);
used = false(nUse, 1);

fprintf('Analysing %d images (%d field values x %d pulses)\n', nUse, nHx, nP);
for i = 1:nUse
    hxIdx = floor((i-1)/nP) + 1;
    pulse = mod(i-1, nP) + 1;
    hxOf(i) = Hx(hxIdx);
    pnOf(i) = pulse;

    try
        S = measureBubbleWidth(fullfile(folder, names{i}), fwd{:}, ...
                'PixelSize', opt.PixelSize, 'Show', false);
        raw(i,:) = [S.widthMean, S.widthRight, S.widthLeft, ...
                    S.widthUp, S.widthDown, S.asymmetryX];
        used(i) = true;
    catch ME
        fprintf(2, '  %-20s FAILED: %s\n', names{i}, ME.message);
    end

    if mod(i, 20) == 0 || i == nUse
        fprintf('  %d / %d done\n', i, nUse);
    end
end

norm = raw ./ pnOf;         % displacement per pulse

% --------------------------------------------------- per-image result set
R = table(hxOf, pnOf, names(1:nUse), raw(:,1), norm(:,1), norm(:,2), ...
          norm(:,3), norm(:,4), norm(:,5), norm(:,6), ...
    'VariableNames', {'Hx_mA', 'pulse', 'file', 'width_raw', 'du_mean', ...
                      'du_right', 'du_left', 'du_up', 'du_down', 'asym_x'});
writetable(R, fullfile(outDir, 'hx_sweep_per_image.txt'), 'Delimiter', 'tab');

% ------------------------------------------------------- per-Hx result set
cols = nan(nHx, 6);         % averaged over the pulses of that field value
sds  = nan(nHx, 1);
perP = nan(nHx, nP);        % normalised mean width, pulse by pulse
nGood = zeros(nHx, 1);

for h = 1:nHx
    sel = (hxOf == Hx(h)) & used;
    if any(sel)
        cols(h,:) = mean(norm(sel,:), 1);
        sds(h)    = std(norm(sel,1), 0, 1);
        nGood(h)  = nnz(sel);
        for q = 1:nP
            s2 = sel & (pnOf == q);
            if any(s2)
                perP(h,q) = norm(s2,1);
            end
        end
    end
end

vars = {'Hx_mA', 'du_mean', 'du_std', 'du_right', 'du_left', 'du_up', ...
        'du_down', 'asym_x', 'n_images'};
data = [Hx(:), cols(:,1), sds, cols(:,2), cols(:,3), cols(:,4), cols(:,5), ...
        cols(:,6), nGood];

for q = 1:nP
    data(:, end+1) = perP(:,q);          %#ok<AGROW>
    vars{end+1} = sprintf('du_pulse%d', q); %#ok<AGROW>
end

if ~isempty(opt.PulseWidth)
    data(:, end+1) = cols(:,1) / opt.PulseWidth;
    vars{end+1} = 'v_mean';
    data(:, end+1) = cols(:,2) / opt.PulseWidth;
    vars{end+1} = 'v_right';
    data(:, end+1) = cols(:,3) / opt.PulseWidth;
    vars{end+1} = 'v_left';
end

T = array2table(data, 'VariableNames', vars);
outPath = fullfile(outDir, opt.OutFile);
writetable(T, outPath, 'Delimiter', 'tab');

fprintf('\n%d of %d images measured.\n', nnz(used), nUse);
fprintf('Per-Hx results : %s\n', outPath);
fprintf('Per-image data : %s\n', fullfile(outDir, 'hx_sweep_per_image.txt'));

% ------------------------------------------------------------- quick plot
figure('Color', 'w');
plot(Hx, cols(:,2), 'o-', 'DisplayName', 'right'); hold on;
plot(Hx, cols(:,3), 's-', 'DisplayName', 'left');
plot(Hx, cols(:,1), 'k--', 'DisplayName', 'mean');
xlabel('Hx coil current (mA)');
if opt.PixelSize == 1
    ylabel('displacement per pulse (px)');
else
    ylabel('displacement per pulse (um)');
end
legend('Location', 'best'); grid on;
title('Asymmetric bubble expansion versus in-plane field');
end

% ------------------------------------------------------------- local tools
function ord = naturalOrder(names)
% Sort file names so img2 comes before img10, using the last number found.
key = nan(numel(names), 1);
for i = 1:numel(names)
    t = regexp(names{i}, '\d+', 'match');
    if ~isempty(t)
        key(i) = str2double(t{end});
    end
end
if any(isnan(key))
    [~, ord] = sort(names);          % fall back to plain alphabetical
else
    [~, ord] = sort(key);
end
end

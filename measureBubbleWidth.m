function S = measureBubbleWidth(imgFile, varargin)
%MEASUREBUBBLEWIDTH  Detect the two walls of an expanded magnetic bubble and
% measure the vertical expansion at the top (widthUp) and bottom (widthDown).
%
% Image model (matches the Kerr images this was tuned on): mid-grey background,
% a BRIGHT ring = the area swept by the wall, and a DARKER domain inside the
% ring = the initial bubble. The outer edge of the bright ring is the final
% wall position (outer contour), the inner edge of the bright ring is the
% initial wall position (inner contour).
%
%   S = measureBubbleWidth(file)
%   S = measureBubbleWidth(file, 'PixelSize', 0.35, 'Show', true)
%
% Name-value options
%   'PixelSize'   micrometres per pixel (default 1 -> widths in pixels)
%   'Show'        display the contour figure (default false)
%   'Save'        file name for the contour figure (default '' = do not save)
%   'Polarity'    'bright' (default) ring brighter than background,
%                 'dark' ring darker, 'auto' pick whichever forms a ring
%   'MedianSize'  median filter window, kills the salt-and-pepper Kerr noise
%                 (default 7; raise for noisier frames)
%   'SmoothSigma' Gaussian smoothing after the median filter (default 3)
%   'CloseRadius' closing radius that seals gaps in the ring (default 7)
%   'MinArea'     smallest accepted object, fraction of the image if < 1
%                 (default 5e-4) - also removes specks and the field label
%   'Band'        half-width in columns of the strip the edges are read from;
%                 the median over the strip is used (default 10)
%   'Center'      [x y] to force the measurement column (default: inner centroid)
%
% Output struct S
%   widthUp, widthDown       expansion at top / bottom in PixelSize units
%   ring, outerMask, innerMask
%   outerBoundary, innerBoundary     [row col] contour points
%   yOuterTop, yInnerTop, yInnerBottom, yOuterBottom, center
%   threshold                the two Otsu levels used

p = inputParser; p.KeepUnmatched = true;
addParameter(p, 'PixelSize', 1);
addParameter(p, 'Show', false);
addParameter(p, 'Save', '');
addParameter(p, 'Polarity', 'bright');
addParameter(p, 'MedianSize', 7);
addParameter(p, 'SmoothSigma', 3);
addParameter(p, 'CloseRadius', 7);
addParameter(p, 'MinArea', 5e-4);
addParameter(p, 'Band', 10);
addParameter(p, 'Center', []);
parse(p, varargin{:});
o = p.Results;

% ---------------- read ----------------
if ischar(imgFile) || isstring(imgFile)
    [I, map] = imread(char(imgFile));
    if ~isempty(map), I = ind2rgb(I, map); end
else
    I = imgFile;
end
if size(I, 3) > 1
    G0 = rgb2gray(im2double(I(:, :, 1:3)));
else
    G0 = im2double(I);
end

% ---------------- denoise ----------------
% Median first: the Kerr frames are grain-dominated and a Gaussian alone drags
% the wall position around. Median removes the grain and the bright pinning
% specks while leaving the wall edge where it is.
G = G0;
if o.MedianSize > 1, G = medfilt2(G, [o.MedianSize o.MedianSize], 'symmetric'); end
if o.SmoothSigma > 0, G = imgaussfilt(G, o.SmoothSigma); end

minPix = o.MinArea;
if minPix < 1, minPix = max(50, round(minPix * numel(G))); end

% ---------------- ring mask ----------------
% Three grey levels are present (dark domain / mid background / bright ring),
% so a 3-level Otsu is the right split; a plain 2-level threshold merges the
% dark domain with the background or with the ring.
t = multithresh(G, 2);
switch lower(o.Polarity)
    case 'bright', cands = {G > t(2)};
    case 'dark',   cands = {G < t(1)};
    otherwise,     cands = {G > t(2), G < t(1)};
end

ring = []; bestHole = -1;
for i = 1:numel(cands)
    R = cleanMask(cands{i}, minPix, o.CloseRadius);
    if ~any(R(:)), continue; end
    holeA = nnz(imfill(R, 'holes')) - nnz(R);
    if holeA > bestHole, bestHole = holeA; ring = R; end
end
if isempty(ring)
    error('measureBubbleWidth:noRing', ...
        'No ring found. Try Polarity dark/auto, larger MedianSize or smaller MinArea.');
end

outer = imfill(ring, 'holes');
inner = outer & ~ring;                       % the hole of the ring = initial bubble
inner = bwareaopen(inner, minPix);
if ~any(inner(:))
    error('measureBubbleWidth:noInnerContour', ...
        'Ring detected but no inner contour; raise CloseRadius to seal the ring.');
end
inner = imfill(bwareafilt(inner, 1), 'holes');

Bo = bwboundaries(outer, 'noholes'); outerB = Bo{1};
Bi = bwboundaries(inner, 'noholes'); innerB = Bi{1};

% ---------------- measure ----------------
if ~isempty(o.Center)
    xc = round(o.Center(1)); yc = round(o.Center(2));
else
    st = regionprops(inner, 'Centroid');
    xc = round(st(1).Centroid(1)); yc = round(st(1).Centroid(2));
end
xc = min(max(xc, 1), size(outer, 2));

cols = max(1, xc - o.Band):min(size(outer, 2), xc + o.Band);
nc = numel(cols);
oT = nan(nc,1); oB = nan(nc,1); iT = nan(nc,1); iB = nan(nc,1);
for j = 1:nc
    co = find(outer(:, cols(j)));
    ci = find(inner(:, cols(j)));
    if isempty(co) || isempty(ci), continue; end
    oT(j) = co(1); oB(j) = co(end);
    iT(j) = ci(1); iB(j) = ci(end);
end

S.file          = imgFile;
S.pixelSize     = o.PixelSize;
S.threshold     = t;
S.widthUp       = median(iT - oT, 'omitnan') * o.PixelSize;
S.widthDown     = median(oB - iB, 'omitnan') * o.PixelSize;
S.ring          = ring;
S.mask          = ring;
S.outerMask     = outer;
S.innerMask     = inner;
S.outerBoundary = outerB;
S.innerBoundary = innerB;
S.center        = [xc yc];
S.yOuterTop     = median(oT, 'omitnan');
S.yOuterBottom  = median(oB, 'omitnan');
S.yInnerTop     = median(iT, 'omitnan');
S.yInnerBottom  = median(iB, 'omitnan');

% ---------------- contour figure ----------------
if o.Show || ~isempty(o.Save)
    vis = 'off'; if o.Show, vis = 'on'; end
    fh = figure('Color', 'w', 'Visible', vis);
    imshow(G0, []); hold on;
    h1 = plot(outerB(:,2), outerB(:,1), 'r-', 'LineWidth', 1.4);
    h2 = plot(innerB(:,2), innerB(:,1), 'c-', 'LineWidth', 1.4);
    h3 = plot([xc xc], [S.yOuterTop S.yInnerTop], 'y-', 'LineWidth', 3);
    h4 = plot([xc xc], [S.yInnerBottom S.yOuterBottom], 'm-', 'LineWidth', 3);
    if o.PixelSize == 1, u = 'px'; else, u = 'um'; end
    if ischar(imgFile) || isstring(imgFile)
        [~, nm, ex] = fileparts(char(imgFile)); ttl = [nm ex];
    else
        ttl = 'image';
    end
    title(sprintf('%s    \\Deltay_{up} = %.2f %s    \\Deltay_{down} = %.2f %s', ...
        ttl, S.widthUp, u, S.widthDown, u), 'Interpreter', 'tex');
    legend([h1 h2 h3 h4], {'outer contour', 'inner contour', '\Deltay_{up}', '\Deltay_{down}'}, ...
        'Location', 'southoutside', 'Orientation', 'horizontal');
    if ~isempty(o.Save)
        if exist('exportgraphics', 'file')
            exportgraphics(fh, o.Save, 'Resolution', 200);
        else
            print(fh, o.Save, '-dpng', '-r200');
        end
    end
    if ~o.Show, close(fh); end
end
end

% ------------------------------------------------------------------------
function R = cleanMask(R, minPix, closeRad)
R = bwareaopen(R, minPix);
if closeRad > 0, R = imclose(R, strel('disk', closeRad)); end
R = bwareaopen(R, minPix);
if ~any(R(:)), return; end
R = bwareafilt(R, 1);
end

function S = measureBubbleWidth(imgPath, varargin)
%MEASUREBUBBLEWIDTH  Automatic sizing of an expanded magnetic bubble domain.
%
%   S = measureBubbleWidth(IMGPATH) segments a polar-MOKE differential image
%   into three regions (bright swept annulus, dark initial bubble core,
%   unswitched background), then measures the domain-wall displacement
%   (annulus width) as a function of azimuthal angle.
%
%   The width of the swept ring is the wall displacement Deltau, which
%   divided by the pulse length gives the wall velocity used for DMI
%   extraction.
%
%   Name-value options
%     'PixelSize'   Micrometres per pixel. Default 1, so lengths are pixels.
%     'Sigma'       Gaussian pre-smoothing in pixels. Default 4.
%     'AngleStep'   Azimuthal sampling step in degrees. Default 1.
%     'Sector'      Half-width in degrees of the sector averaged for the
%                   left/right/up/down displacements. Default 20.
%     'LabelMask'   [rowFrac colFrac] size of the bottom-left burned-in field
%                   label to ignore. Default [0.07 0.12].
%     'MinArea'     Minimum object area in pixels kept during cleanup.
%                   Default 2000.
%     'Show'        Draw an overlay figure. Default true.
%     'SaveOverlay' File name for the overlay image, '' to skip. Default ''.
%
%   Output struct S contains the per-angle profile (theta, rOuter, rInner,
%   width), the statistics (widthMean, widthStd), the sector averages
%   (widthRight, widthLeft, widthUp, widthDown), the in-plane asymmetry
%   (asymmetryX = right - left, the quantity carrying the DMI signal), the
%   area-equivalent diameters and the bounding-box size of the outer edge.
%
%   Requires the Image Processing Toolbox.
%
%   Example
%     S = measureBubbleWidth('DMI_5.jpg', 'PixelSize', 0.42);

% ---------------------------------------------------------------- options
p = inputParser;
p.KeepUnmatched = false;
p.addParameter('PixelSize', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Sigma', 4, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('AngleStep', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Sector', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('LabelMask', [0.07 0.12], @(x) isnumeric(x) && numel(x) == 2);
p.addParameter('MinArea', 2000, @(x) isnumeric(x) && isscalar(x));
p.addParameter('Show', true);
p.addParameter('SaveOverlay', '');
p.parse(varargin{:});
opt = p.Results;
opt.Show = logical(opt.Show);
overlayFile = char(opt.SaveOverlay);

% ------------------------------------------------------------- read image
I = imread(imgPath);
if ndims(I) == 3
    I = rgb2gray(I);
end
I = im2double(I);
I = (I - min(I(:))) / max(eps, max(I(:)) - min(I(:)));
[H, W] = size(I);

% Ignore the burned-in field label in the bottom-left corner, whose black box
% and white text would otherwise be read as extreme intensity classes.
valid = true(H, W);
r0 = max(1, round((1 - opt.LabelMask(1)) * H));
c1 = max(1, round(opt.LabelMask(2) * W));
valid(r0:end, 1:c1) = false;

% ----------------------------------------------------------- segmentation
F = imgaussfilt(I, opt.Sigma);

% Three-class Otsu: class 1 dark core, class 2 background, class 3 bright ring.
thr = multithresh(F(valid), 2);
L = imquantize(F, thr);

bright = (L == 3) & valid;
bright = imopen(bright, strel('disk', 5));
bright = bwareaopen(bright, opt.MinArea);

outer = imfill(bright, 'holes');
if ~any(outer(:))
    error('measureBubbleWidth:noDomain', ...
          'No bright expanded region found in %s. Lower Sigma or MinArea.', imgPath);
end
outer = bwareafilt(outer, 1);          % keep the single largest domain

% The initial bubble is the hole enclosed by the swept ring. Using the hole
% is more robust than using the dark intensity class, because core and
% background often share almost the same grey level.
core = outer & ~imclose(bright, strel('disk', 9));
core = imopen(core, strel('disk', 7));
core = bwareaopen(core, opt.MinArea);
core = imfill(core, 'holes');
hasCore = any(core(:));
if hasCore
    core = bwareafilt(core, 1);
end

% ---------------------------------------------------------------- centre
if hasCore
    st = regionprops(core, 'Centroid');
else
    st = regionprops(outer, 'Centroid');
end
cx = st(1).Centroid(1);
cy = st(1).Centroid(2);

% ------------------------------------------------- radial edge extraction
theta = 0:opt.AngleStep:(360 - opt.AngleStep);
rMax  = 1.6 * hypot(H, W) / 2;
r     = 0:0.5:rMax;

outerD = double(outer);
coreD  = double(core);

rOuter = nan(size(theta));
rInner = zeros(size(theta));

for k = 1:numel(theta)
    a  = deg2rad(theta(k));
    xs = cx + r * cos(a);
    ys = cy - r * sin(a);              % image y axis points down

    vo = interp2(outerD, xs, ys, 'linear', 0) > 0.5;
    idx = find(vo, 1, 'last');         % outermost crossing along the ray
    if ~isempty(idx)
        rOuter(k) = r(idx);
    end

    if hasCore
        vi = interp2(coreD, xs, ys, 'linear', 0) > 0.5;
        idx = find(vi, 1, 'last');
        if ~isempty(idx)
            rInner(k) = r(idx);
        end
    end
end

width = rOuter - rInner;               % domain-wall displacement per angle

% ------------------------------------------------------------- aggregates
px = opt.PixelSize;
sectorMean = @(c) nanmeanLocal(width(abs(mod(theta - c + 180, 360) - 180) <= opt.Sector));

areaOuter = nnz(outer);
areaInner = nnz(core);
bb = regionprops(outer, 'BoundingBox');

[~, name, ext] = fileparts(imgPath);
S = struct();
S.file      = [name ext];
S.pixelSize = px;
S.center    = [cx cy];
S.theta     = theta;
S.rOuter    = rOuter * px;
S.rInner    = rInner * px;
S.width     = width  * px;

S.widthMean  = nanmeanLocal(width) * px;
S.widthStd   = nanstdLocal(width)  * px;
S.widthRight = sectorMean(0)   * px;
S.widthLeft  = sectorMean(180) * px;
S.widthUp    = sectorMean(90)  * px;
S.widthDown  = sectorMean(270) * px;
S.asymmetryX = S.widthRight - S.widthLeft;

S.outerDiameterEq = 2 * sqrt(areaOuter / pi) * px;
S.innerDiameterEq = 2 * sqrt(areaInner / pi) * px;
S.outerWidthX     = bb(1).BoundingBox(3) * px;
S.outerHeightY    = bb(1).BoundingBox(4) * px;
S.areaOuter       = areaOuter * px^2;
S.areaInner       = areaInner * px^2;
S.hasCore         = hasCore;

% ---------------------------------------------------------------- overlay
if opt.Show || ~isempty(overlayFile)
    vis = 'on';
    if ~opt.Show
        vis = 'off';
    end
    f = figure('Color', 'w', 'Visible', vis);
    imshow(I); hold on;
    drawOutline(outer, 'c');
    if hasCore
        drawOutline(core, 'y');
    end
    plot(cx, cy, 'r+', 'MarkerSize', 12, 'LineWidth', 1.5);

    for c = [0 90 180 270]
        k = find(theta == c, 1);
        if isempty(k) || isnan(rOuter(k))
            continue
        end
        a = deg2rad(c);
        plot(cx + [rInner(k) rOuter(k)] * cos(a), ...
             cy - [rInner(k) rOuter(k)] * sin(a), 'r-', 'LineWidth', 2);
    end

    unitTxt = 'px';
    if px ~= 1
        unitTxt = 'um';
    end
    title(sprintf('%s   mean du = %.1f %s   right %.1f   left %.1f   asym %.1f', ...
                  S.file, S.widthMean, unitTxt, S.widthRight, S.widthLeft, ...
                  S.asymmetryX), 'Interpreter', 'none');
    hold off;

    if ~isempty(overlayFile)
        saveFigure(f, overlayFile);
    end
    if ~opt.Show
        close(f);
    end
end
end

% ------------------------------------------------------------- local tools
function drawOutline(BW, colorSpec)
% Outline a binary mask without relying on visboundaries.
B = bwboundaries(BW, 'noholes');
for i = 1:numel(B)
    plot(B{i}(:,2), B{i}(:,1), '-', 'Color', colorSpec, 'LineWidth', 1.2);
end
end

function saveFigure(f, fname)
% exportgraphics exists from R2020a; fall back to print on older releases.
if exist('exportgraphics', 'file') == 2
    exportgraphics(gca, fname, 'Resolution', 150);
else
    print(f, '-dpng', '-r150', fname);
end
end

function m = nanmeanLocal(v)
v = v(~isnan(v));
if isempty(v)
    m = NaN;
else
    m = mean(v);
end
end

function s = nanstdLocal(v)
v = v(~isnan(v));
if numel(v) < 2
    s = NaN;
else
    s = std(v);
end
end
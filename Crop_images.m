%% crop_and_save.m  — crop image(s), save. No processing.
clear; clc;

[files, folder] = uigetfile( ...
    {'*.png;*.tif;*.tiff;*.bmp;*.jpg','Image files'}, ...
    'Select image(s) to crop', 'MultiSelect','on');
if isequal(files,0); error('No files selected.'); end
if ischar(files); files = {files}; end

outDir = fullfile(folder,'cropped');
if ~exist(outDir,'dir'); mkdir(outDir); end

figure('Name','Crop','Color','w');
for k = 1:numel(files)
    I = imread(fullfile(folder, files{k}));

    clf; imshow(I,'InitialMagnification','fit');
    title(sprintf('%d/%d: draw box, double-click to crop', k, numel(files)), ...
        'Interpreter','none');

    C = imcrop;                      % same class as I, no resampling
    if isempty(C)
        warning('Skipped %s.', files{k}); continue;
    end

    [~,base,ext] = fileparts(files{k});
    if strcmpi(ext,'.jpg') || strcmpi(ext,'.jpeg'); ext = '.png'; end   % avoid re-JPEG loss
    outFile = fullfile(outDir,[base '_crop' ext]);
    imwrite(C, outFile);
    fprintf('saved %s  [%d x %d]\n', outFile, size(C,2), size(C,1));
end
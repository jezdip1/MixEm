% +mixem/showImageCentered.m
function tOn = showImageCentered(params, imgPath, w, h, margin)
% Draw image centered and FLIP. Returns absolute onset time (GetSecs).
% w/h optional – if omitted uses contain-fit.

if nargin < 5 || isempty(margin), margin = 0.9; end

if ~exist(imgPath, 'file')
    error('showImageCentered:NotFound','Image not found: %s', imgPath);
end

img = imread(imgPath);
if nargin >= 3 && ~isempty(w) && ~isempty(h)
    img = imresize(img, [h, w]);
    tgtRect = [0 0 w h];
else
    tgtRect = [0 0 size(img,2) size(img,1)];
end

tex = Screen('MakeTexture', params.win, img);
winRect = Screen('Rect', params.win);
dstRect = mixem.fitRectToWindow(tgtRect, winRect, margin);

Screen('FillRect', params.win, 0);             % ensure clean background
Screen('DrawTexture', params.win, tex, [], dstRect);
tOn = Screen('Flip', params.win);

Screen('Close', tex);
end
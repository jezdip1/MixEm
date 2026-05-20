function tOn = showImageCentered(params, imgPath, w, h, margin)
% Draw image centered and FLIP. Returns absolute onset time (GetSecs).
%
% IMPORTANT: If w/h are provided, the drawn stimulus is exactly w x h
% screen pixels. This is required by the MixEm design for visual stimuli
% (500 x 400 px). If w/h are omitted, the image is contain-fitted.

if nargin < 5 || isempty(margin), margin = 0.9; end

if ~exist(imgPath, 'file')
    error('showImageCentered:NotFound','Image not found: %s', imgPath);
end

img = imread(imgPath);
tex = Screen('MakeTexture', params.win, img);
winRect = Screen('Rect', params.win);

if nargin >= 3 && ~isempty(w) && ~isempty(h)
    [cx, cy] = RectCenter(winRect);
    dstRect = CenterRectOnPoint([0 0 double(w) double(h)], cx, cy);
else
    srcRect = [0 0 size(img,2) size(img,1)];
    dstRect = mixem.fitRectToWindow(srcRect, winRect, margin);
end

Screen('FillRect', params.win, 0);             % ensure clean background
Screen('DrawTexture', params.win, tex, [], dstRect);
tOn = Screen('Flip', params.win);

Screen('Close', tex);
end

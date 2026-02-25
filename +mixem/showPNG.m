function tOn = showPNG(params, pngName, doFlip, margin)
% showPNG: jen vykreslí PNG (contain-fit) a volitelně flipne.
% Nečeká na žádný vstup. Input patří do waitOnPNG / trial loopu.

if nargin < 3 || isempty(doFlip), doFlip = true; end
if nargin < 4 || isempty(margin), margin = 0.9; end

img = imread(fullfile(params.pngDir, pngName));
tex = Screen('MakeTexture', params.win, img);
winRect = Screen('Rect', params.win);

dstRect = mixem.fitRectToWindow([0 0 size(img,2) size(img,1)], winRect, margin);
Screen('DrawTexture', params.win, tex, [], dstRect);

if doFlip
    tOn = Screen('Flip', params.win);
else
    tOn = NaN;
end

Screen('Close', tex);
end

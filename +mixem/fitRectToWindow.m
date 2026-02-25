function dstRect = fitRectToWindow(srcRect, winRect, margin)
if nargin<3 || isempty(margin), margin = 0.9; end
winW = RectWidth(winRect);  winH = RectHeight(winRect);
boxW = winW*margin; boxH = winH*margin;
srcW = RectWidth(srcRect);  srcH = RectHeight(srcRect);
scale = min(boxW/srcW, boxH/srcH);
newW = round(srcW*scale); newH = round(srcH*scale);
[cx, cy] = RectCenter(winRect);
dstRect = CenterRectOnPoint([0 0 newW newH], cx, cy);
end

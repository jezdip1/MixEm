function rect = mapImgRectToScreen(params, pngName, hitBB)
% hitBB: [x1 y1 x2 y2] v rozsahu 0..1 v souřadnicích PNG (normalizované)
img = imread(fullfile(params.pngDir, pngName));
imgW = size(img,2); imgH = size(img,1);

% převod na pixely PNG
hitImg = [hitBB(1)*imgW, hitBB(2)*imgH, hitBB(3)*imgW, hitBB(4)*imgH];

winRect = Screen('Rect', params.win);
dstRect = mixem.fitRectToWindow([0 0 imgW imgH], winRect, 0.9);

sx = (dstRect(3)-dstRect(1)) / imgW;
sy = (dstRect(4)-dstRect(2)) / imgH;

rect = [
    dstRect(1) + hitImg(1)*sx, ...
    dstRect(2) + hitImg(2)*sy, ...
    dstRect(1) + hitImg(3)*sx, ...
    dstRect(2) + hitImg(4)*sy
];
end

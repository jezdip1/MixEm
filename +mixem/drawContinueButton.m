function rect = drawContinueButton(params, label)
% Vykreslí velké tlačítko dole uprostřed; vrátí [left top right bottom].
% Pro přístupnost škáluje s oknem a používá polo-transparentní podklad.
if nargin<2, label = "Pokračovat"; end

win = params.win;
winRect = Screen('Rect', win);
winW = RectWidth(winRect); winH = RectHeight(winRect);

btnW = round(winW * 0.36);
btnH = round(winH * 0.10);
[cx, cy] = RectCenter(winRect);
y = round(winH * 0.85);
rect = CenterRectOnPoint([0 0 btnW btnH], cx, y);

% podklad (poloprůhledná šedá)
base = [0.6 0.6 0.6] * 255;
Screen('FillRect', win, base, rect);

% rámeček
Screen('FrameRect', win, [220 220 220], rect, 2);

% text (velikost ~3.5 % výšky okna)
Screen('TextFont', win, 'Arial');
Screen('TextSize', win, round(0.035 * winH));
[nx, ny, bbox] = DrawFormattedText(win, char(label), 'center', 'center', 255, [], [], [], 1.2, [], rect);
Screen('Flip', win);
end

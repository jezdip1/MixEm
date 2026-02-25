function out = collectRating3x7(params, pngName, deck, opts)
% COLLECTRATING3X7
% pngName: 'resp_val_aud.png' nebo 'resp_val_vis.png'
%
% out.ratings      = [arousal valence intensity] (1..7)
% out.rt_ms        = čas od onsetu rating screenu po SUBMIT (ms)
% out.tRatingOn    = ABS GetSecs timestamp prvního Flip rating screenu
% out.tSubmitAbs   = ABS GetSecs timestamp potvrzení (Enter/Continue)
% out.tEndAbs      = ABS GetSecs timestamp těsně před návratem
%
% Ovládání:
% - myš: klik do grid nastaví hodnotu (a rovnou umístí fajfku pro daný řádek),
%        klik na continue odešle (jen pokud jsou všechny 3 fajfky).
% - klávesnice: šipky move, SPACE = select (umístí fajfku), ENTER = submit,
%               čísla 1..7 přímo volí hodnotu pro aktuální řádek (umístí fajfku).
% - deck: LEFT/RIGHT/UP/DOWN move, OK = select (umístí fajfku), CONT = submit.

if nargin < 3, deck = []; end
if nargin < 4, opts = struct(); end

if ~isfield(opts,'startRow'), opts.startRow = 2; end   % 1..3
if ~isfield(opts,'startCol'), opts.startCol = 4; end   % 1..7

% hitboxy
gridRect = mixem.getClickableRectForPNG(params, pngName, 'grid');
contRect = mixem.getClickableRectForPNG(params, pngName, 'continue');

% pro aud variantu můžeš mít "speaker" pro replay (volitelné)
spkRect = [];
try
    spkRect = mixem.getClickableRectForPNG(params, pngName, 'speaker');
catch
end

% deck layout
if ~isempty(deck)
    try
        deck = mixem.deck_show_rating_nav(deck);
        params.deck = deck;
    catch
        deck = [];
    end
end

% state: dokud není explicitně vybráno, je NaN a bez fajfky
ratings = nan(1,3);        % [A V I] (1..7), NaN dokud nevyplněno
filled  = false(1,3);      % které řádky mají fajfku
curRow  = opts.startRow;
curCol  = opts.startCol;

% -------- render initial & capture TRUE rating onset --------
[tRatingOn] = local_render(true);  % first flip timestamp = rating onset (ABS GetSecs)

% input prep
scr = Screen('WindowScreenNumber', params.win);

% mouse flush + edge
[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

% keyboard edge
[prevKeyDown,~,~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown,~,~] = KbCheck;
end

% deck edge
prevDeck = [];
if ~isempty(deck)
    try
        prevDeck = mixem.deck_read_states_any(deck);
    catch
        prevDeck = [];
    end
end

% init outputs (will be finalized on submit)
out = struct();
out.ratings    = ratings;
out.rt_ms      = NaN;
out.tRatingOn  = double(tRatingOn);
out.tSubmitAbs = NaN;
out.tEndAbs    = NaN;

while true
    % -------- mouse --------
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        % continue (jen pokud jsou všechny 3 vyplněné)
        if ~isempty(contRect) && IsInRect(mx,my,contRect)
            if all(filled)
                out.ratings    = ratings;
                out.tSubmitAbs = GetSecs;
                out.rt_ms      = (out.tSubmitAbs - out.tRatingOn) * 1000;
                out.tEndAbs    = GetSecs;
                return
            else
                local_render(false);
            end
        end

        % replay speaker (jen u aud) – no-op, řeší caller
        if ~isempty(spkRect) && IsInRect(mx,my,spkRect)
            % no-op
        end

        % click do grid -> nastav + umísti fajfku pro daný řádek
        if ~isempty(gridRect) && IsInRect(mx,my,gridRect)
            [r,c] = local_pos_to_cell(mx,my);
            if ~isempty(r)
                curRow = r; curCol = c;
                ratings(curRow) = curCol;
                filled(curRow)  = true;
                local_render(false);
            end
        end
    end

    % -------- keyboard --------
    [keyDown,~,kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc);
        if ischar(k), k={k}; end

        % SUBMIT: Enter/Return (jen pokud jsou všechny 3 vyplněné)
        if any(strcmpi(k,'return')) || any(strcmpi(k,'enter'))
            if all(filled)
                out.ratings    = ratings;
                out.tSubmitAbs = GetSecs;
                out.rt_ms      = (out.tSubmitAbs - out.tRatingOn) * 1000;
                out.tEndAbs    = GetSecs;
                return
            else
                local_render(false);
            end
        end

        % SELECT (OK): Space -> umístí fajfku pro aktuální řádek
        if any(strcmpi(k,'space'))
            ratings(curRow) = curCol;
            filled(curRow)  = true;
            local_render(false);
        end

        % Movement (arrow keys)
        if any(strcmpi(k,'LeftArrow'))
            curCol = max(1, curCol-1); local_render(false);
        elseif any(strcmpi(k,'RightArrow'))
            curCol = min(7, curCol+1); local_render(false);
        elseif any(strcmpi(k,'UpArrow'))
            curRow = max(1, curRow-1); local_render(false);
        elseif any(strcmpi(k,'DownArrow'))
            curRow = min(3, curRow+1); local_render(false);
        end

        % Numeric direct select 1..7 for current row (umístí fajfku)
        for dig = 1:7
            if any(strcmp(k, sprintf('%d',dig))) || any(strcmp(k, sprintf('%d!',dig)))
                curCol = dig;
                ratings(curRow) = curCol;
                filled(curRow)  = true;
                local_render(false);
            end
        end
    end
    prevKeyDown = keyDown;

    % -------- deck --------
    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            pCont = deck.kCont0 + 1;
            pUp   = deck.kUp0   + 1;
            pOk   = deck.kOk0   + 1;
            pL    = deck.kLeft0 + 1;
            pD    = deck.kDown0 + 1;
            pR    = deck.kRight0+ 1;

            % SUBMIT: CONT (jen pokud všechny 3 vyplněné)
            if pCont<=numel(risingDeck) && risingDeck(pCont)
                if all(filled)
                    out.ratings    = ratings;
                    out.tSubmitAbs = GetSecs;
                    out.rt_ms      = (out.tSubmitAbs - out.tRatingOn) * 1000;
                    out.tEndAbs    = GetSecs;
                    return
                else
                    local_render(false);
                end
            end

            % Movement
            if pUp<=numel(risingDeck) && risingDeck(pUp)
                curRow = max(1, curRow-1); local_render(false);
            elseif pD<=numel(risingDeck) && risingDeck(pD)
                curRow = min(3, curRow+1); local_render(false);
            elseif pL<=numel(risingDeck) && risingDeck(pL)
                curCol = max(1, curCol-1); local_render(false);
            elseif pR<=numel(risingDeck) && risingDeck(pR)
                curCol = min(7, curCol+1); local_render(false);
            elseif pOk<=numel(risingDeck) && risingDeck(pOk)
                ratings(curRow) = curCol;
                filled(curRow)  = true;
                local_render(false);
            end

        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end

% ---------- nested helpers ----------
    function tFlip = local_render(isFirst)
        %#ok<INUSD>
        mixem.showPNG(params, pngName, false);

        if isfield(params,'debugClickable') && params.debugClickable
            if ~isempty(gridRect), Screen('FrameRect', params.win, [80 80 80], gridRect, 1); end
            if ~isempty(contRect), Screen('FrameRect', params.win, [80 80 80], contRect, 1); end
        end

        % fajfky pro vyplněné řádky
        for rr = 1:3
            if ~filled(rr), continue; end
            cc = ratings(rr);
            rc = local_cell_rect(rr, cc);
            local_draw_checkmark(rc);
        end

        % cursor (yellow)
        curRc = local_cell_rect(curRow, curCol);
        Screen('FrameRect', params.win, [255 255 0], curRc, 4);

        % IMPORTANT: capture Flip timestamp
        tFlip = Screen('Flip', params.win);
    end

    function [r,c] = local_pos_to_cell(x,y)
        r = []; c = [];
        if isempty(gridRect), return; end
        L=gridRect(1); T=gridRect(2); R=gridRect(3); B=gridRect(4);
        gw = (R-L); gh=(B-T);
        if gw<=0 || gh<=0, return; end
        relx = (x - L) / gw;
        rely = (y - T) / gh;
        if relx<0 || relx>1 || rely<0 || rely>1, return; end
        c = floor(relx*7) + 1;
        r = floor(rely*3) + 1;
        c = min(max(c,1),7);
        r = min(max(r,1),3);
    end

    function rc = local_cell_rect(r,c)
        L=gridRect(1); T=gridRect(2); R=gridRect(3); B=gridRect(4);
        gw = (R-L); gh=(B-T);
        cw = gw/7; rh = gh/3;
        x1 = L + (c-1)*cw;
        x2 = L + c*cw;
        y1 = T + (r-1)*rh;
        y2 = T + r*rh;

        insetFrac = 0.25;
        insetX = insetFrac * (x2 - x1);
        insetY = insetFrac * (y2 - y1);

        rc = [x1+insetX, y1+insetY, x2-insetX, y2-insetY];
    end

    function local_draw_checkmark(rc)
        L = rc(1); T = rc(2); R = rc(3); B = rc(4);

        x1 = L + 0.26*(R-L);  y1 = T + 0.58*(B-T);
        x2 = L + 0.44*(R-L);  y2 = T + 0.74*(B-T);
        x3 = L + 0.72*(R-L);  y3 = T + 0.34*(B-T);

        w = max(2, round(0.08 * min(R-L, B-T)));
        Screen('DrawLine', params.win, [0 200 0], x1, y1, x2, y2, w);
        Screen('DrawLine', params.win, [0 200 0], x2, y2, x3, y3, w);
    end

end
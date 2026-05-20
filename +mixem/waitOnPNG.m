function source = waitOnPNG(params, pngName, deck, debugOutline)

if nargin < 3, deck = []; end
if nargin < 4, debugOutline = false; end

% General instruction/break pages should always present an OK/continue
% button on the StreamDeck. This fixes pages reached after response screens,
% where the deck could still show 1/2/3 and confuse the participant.
if ~isempty(deck)
    try, deck = mixem.deck_show_ok(deck); catch, end
end

% Draw without flip
mixem.showPNG(params, pngName, false);

% hitContinue = mixem.getClickableRectForPNG(Screen('Rect', params.win), pngName);
hitContinue = mixem.getClickableRectForPNG(params, pngName, "continue");
if debugOutline && ~isempty(hitContinue)
    Screen('FrameRect', params.win, [255 0 0], hitContinue, 2);
end

Screen('Flip', params.win);

scr = Screen('WindowScreenNumber', params.win);

% Flush mouse
[~, ~, buttons] = GetMouse(scr);
while any(buttons)
    [~, ~, buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

% Flush keyboard non-blocking
[prevKeyDown, ~, ~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown, ~, ~] = KbCheck;
end

% Flush deck
prevDeck = [];
if ~isempty(deck)
    try
        prevDeck = mixem.deck_read_states_any(deck);
    catch
        prevDeck = [];
    end
end

while true
    % --- MOUSE: accept ONLY inside hitContinue ---
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        if ~isempty(hitContinue) && IsInRect(mx,my,hitContinue)
            source = 'mouse';
            return
        end
    end

    % --- KEY ---
    [keyDown, ~, ~] = KbCheck;
    if keyDown && ~prevKeyDown
        source = 'key';
        return
    end
    prevKeyDown = keyDown;

    % --- DECK edge ---
    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            if any(risingDeck)
                WaitSecs(0.12); % debounce
                source = 'deck';
                return
            end
        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end
end

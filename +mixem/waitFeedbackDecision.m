function choice = waitFeedbackDecision(params)
% Vrací 'repeat' nebo 'continue'
% feedback.png má mít hitboxy: which="repeat" a which="continue"

% UI
mixem.showPNG(params,'feedback.png',false);

hitRepeat  = mixem.getClickableRectForPNG(params,'feedback.png',"repeat");
hitCont    = mixem.getClickableRectForPNG(params,'feedback.png',"continue");

if isfield(params,'debugClickable') && params.debugClickable
    if ~isempty(hitRepeat), Screen('FrameRect', params.win, [255 0 0], hitRepeat, 2); end
    if ~isempty(hitCont),   Screen('FrameRect', params.win, [0 255 0], hitCont, 2); end
end
Screen('Flip', params.win);

% Deck layout
deck = [];
if isfield(params,'deck'), deck = params.deck; end
if ~isempty(deck)
    try
        deck = mixem.deck_show_feedback(deck);
        params.deck = deck;
    catch
        deck = [];
    end
end

scr = Screen('WindowScreenNumber', params.win);

% flush mouse
[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

% keyboard edge (R=repeat, Enter/Space=continue, nebo libovolná klávesa = continue)
[prevKeyDown, ~, ~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown, ~, ~] = KbCheck;
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

while true
    % mouse
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;
    if any(risingMouse)
        if ~isempty(hitRepeat) && IsInRect(mx,my,hitRepeat)
            choice = 'repeat'; return
        elseif ~isempty(hitCont) && IsInRect(mx,my,hitCont)
            choice = 'continue'; return
        end
    end

    % keyboard
    [keyDown,~,kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc);
        if ischar(k), k = {k}; end
        if any(strcmpi(k,'r'))
            choice = 'repeat'; return
        else
            choice = 'continue'; return
        end
    end
    prevKeyDown = keyDown;

    % deck
    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            okPos = deck.okIndex0 + 1;
            rpPos = deck.repeatIndex0 + 1;

            if rpPos<=numel(risingDeck) && risingDeck(rpPos)
                choice = 'repeat'; return
            end
            if okPos<=numel(risingDeck) && risingDeck(okPos)
                choice = 'continue'; return
            end
        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end
end

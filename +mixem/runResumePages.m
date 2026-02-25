function runResumePages(params)
% RUNRESUMEPAGES
% Long break + resume pages + krátké control demo test.
% Používá stejné ovládání jako ostatní screeny (myš/klávesnice/deck OK).

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

% OK-only deck pro screen pages
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

% Long break
mixem.waitOnPNG(params,'long_break_page.png', params.deck, dbg);

% Resume info
mixem.waitOnPNG(params,'test_resume_page.png', params.deck, dbg);

% Resume control demo (test verze re_stim_control_test)
% V designu je po dlouhé pauze znovu krátký „control reminder“.
% Použijeme stejný demo runner jako v runControlCondition:
try
    demoTones = local_pick_demo_tones(params); % použij tu opravenou low/mid/high
catch
    demoTones = {[],[],[]};
end

% stim_control demo (1/2/3 přehrává tóny, OK pokračuje)
local_run_stim_control_demo(params, demoTones, dbg);

% re_stim_control_test: repeat nebo continue
choice = local_wait_repeat_continue(params, 're_stim_control_test.png', dbg);
while strcmp(choice,'repeat')
    local_run_stim_control_demo(params, demoTones, dbg);
    choice = local_wait_repeat_continue(params, 're_stim_control_test.png', dbg);
end

assignin('caller','params',params);
end

% ----- helpers (kopie stejné logiky jako v runControlCondition) -----

function tones = local_pick_demo_tones(params)
% očekává se, že máš robustní implementaci (low/mid/high)
tones = {[],[],[]};
folder = fullfile(params.stimDir,'control_stimuli');
lowD  = dir(fullfile(folder,'control_tone_low_*.wav'));
midD  = dir(fullfile(folder,'control_tone_mid_*.wav'));
highD = dir(fullfile(folder,'control_tone_high_*.wav'));
tones{1} = pick1(lowD);
tones{2} = pick1(midD);
tones{3} = pick1(highD);
if ~isempty(tones{1}) && ~isempty(tones{2}) && ~isempty(tones{3}), return; end
D = dir(fullfile(folder,'control_tone_*.wav'));
if isempty(D), return; end
[~,ix] = sort({D.name});
D = D(ix);
for i=1:min(3,numel(D))
    tones{i} = fullfile(D(i).folder, D(i).name);
end
end

function p = pick1(D)
p = [];
if isempty(D), return; end
[~,ix] = sort({D.name});
d = D(ix(1));
p = fullfile(d.folder, d.name);
end

function local_run_stim_control_demo(params, demoTones, dbg)
mixem.showPNG(params,'stim_control.png',false);

hit = struct('r1',[],'r2',[],'r3',[]);
try, hit.r1 = mixem.getClickableRectForPNG(params,'stim_control.png','r1'); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,'stim_control.png','r2'); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,'stim_control.png','r3'); catch, end
hitCont = [];
try, hitCont = mixem.getClickableRectForPNG(params,'stim_control.png','continue'); catch, end

if dbg
    if ~isempty(hit.r1), Screen('FrameRect', params.win, [255 0 0], hit.r1, 2); end
    if ~isempty(hit.r2), Screen('FrameRect', params.win, [0 255 0], hit.r2, 2); end
    if ~isempty(hit.r3), Screen('FrameRect', params.win, [0 0 255], hit.r3, 2); end
    if ~isempty(hitCont), Screen('FrameRect', params.win, [255 255 0], hitCont, 2); end
end
Screen('Flip', params.win);

% Deck: 1/2/3 + OK
deck = [];
if isfield(params,'deck'), deck = params.deck; end
if ~isempty(deck)
    try
        deck = mixem.deck_show_123(deck);
        deck.okIndex0 = 4; % OK navíc
        deck = mixem.deck_set_key_icon(deck, deck.okIndex0, 'OK', 'green');
        deck = mixem.deck_clear_keys(deck, setdiff(0:(double(deck.dev.key_count())-1), [deck.k1Index0 deck.k2Index0 deck.k3Index0 deck.okIndex0]));
        params.deck = deck;
    catch
        deck = [];
    end
end

scr = Screen('WindowScreenNumber', params.win);

[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

[prevKeyDown,~,~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown,~,~] = KbCheck;
end

prevDeck = [];
if ~isempty(deck)
    try, prevDeck = mixem.deck_read_states_any(deck); catch, prevDeck = []; end
end

while true
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        if ~isempty(hit.r1) && IsInRect(mx,my,hit.r1)
            if ~isempty(demoTones{1}), mixem.playAudioFile(params, demoTones{1}); end
        elseif ~isempty(hit.r2) && IsInRect(mx,my,hit.r2)
            if ~isempty(demoTones{2}), mixem.playAudioFile(params, demoTones{2}); end
        elseif ~isempty(hit.r3) && IsInRect(mx,my,hit.r3)
            if ~isempty(demoTones{3}), mixem.playAudioFile(params, demoTones{3}); end
        elseif ~isempty(hitCont) && IsInRect(mx,my,hitCont)
            return
        end
    end

    [keyDown,~,kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc); if ischar(k), k={k}; end
        if any(strcmp(k,'1!')) || any(strcmp(k,'1'))
            if ~isempty(demoTones{1}), mixem.playAudioFile(params, demoTones{1}); end
        elseif any(strcmp(k,'2@')) || any(strcmp(k,'2'))
            if ~isempty(demoTones{2}), mixem.playAudioFile(params, demoTones{2}); end
        elseif any(strcmp(k,'3#')) || any(strcmp(k,'3'))
            if ~isempty(demoTones{3}), mixem.playAudioFile(params, demoTones{3}); end
        else
            return
        end
    end
    prevKeyDown = keyDown;

    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            p1 = deck.k1Index0 + 1;
            p2 = deck.k2Index0 + 1;
            p3 = deck.k3Index0 + 1;
            pOk = deck.okIndex0 + 1;

            if p1<=numel(risingDeck) && risingDeck(p1)
                if ~isempty(demoTones{1}), mixem.playAudioFile(params, demoTones{1}); end
            elseif p2<=numel(risingDeck) && risingDeck(p2)
                if ~isempty(demoTones{2}), mixem.playAudioFile(params, demoTones{2}); end
            elseif p3<=numel(risingDeck) && risingDeck(p3)
                if ~isempty(demoTones{3}), mixem.playAudioFile(params, demoTones{3}); end
            elseif pOk<=numel(risingDeck) && risingDeck(pOk)
                return
            end
        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end
end

function choice = local_wait_repeat_continue(params, pngName, dbg)
mixem.showPNG(params, pngName, false);

hitRepeat = [];
hitCont   = [];
try, hitRepeat = mixem.getClickableRectForPNG(params, pngName, 'repeat'); catch, end
try, hitCont   = mixem.getClickableRectForPNG(params, pngName, 'continue'); catch, end

if dbg
    if ~isempty(hitRepeat), Screen('FrameRect', params.win, [255 0 0], hitRepeat, 2); end
    if ~isempty(hitCont),   Screen('FrameRect', params.win, [0 255 0], hitCont, 2); end
end
Screen('Flip', params.win);

deck = [];
if isfield(params,'deck'), deck = params.deck; end
if ~isempty(deck)
    try
        deck = mixem.deck_show_feedback(deck); % REP + OK
        params.deck = deck;
    catch
        deck = [];
    end
end

scr = Screen('WindowScreenNumber', params.win);

[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

[prevKeyDown,~,~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown,~,~] = KbCheck;
end

prevDeck = [];
if ~isempty(deck)
    try, prevDeck = mixem.deck_read_states_any(deck); catch, prevDeck = []; end
end

while true
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

    [keyDown,~,kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc); if ischar(k), k={k}; end
        if any(strcmpi(k,'r'))
            choice='repeat'; return
        else
            choice='continue'; return
        end
    end
    prevKeyDown = keyDown;

    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            rpPos = deck.repeatIndex0 + 1;
            okPos = deck.okIndex0 + 1;

            if rpPos<=numel(risingDeck) && risingDeck(rpPos)
                choice='repeat'; return
            end
            if okPos<=numel(risingDeck) && risingDeck(okPos)
                choice='continue'; return
            end
        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end
end

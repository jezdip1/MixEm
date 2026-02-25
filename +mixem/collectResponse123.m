function [respKey, resp, rt_ms, tRespAbs] = collectResponse123(params, deck, timeout, hitRects, opts)
% Multi-input odpověď 1/2/3: klávesnice + myš + deck
% - Absolute timing: returns tRespAbs (GetSecs) as 4th output (optional).
% - Backward compatible: if caller asks only 3 outputs, works unchanged.
% - FIX: pokud je odpověď už stisknutá v okamžiku startu sběru, bereme ji hned.
%
% Usage:
%   [rk,r,rt] = mixem.collectResponse123(params, deck, timeout, hitRects);
%   [rk,r,rt,tAbs] = mixem.collectResponse123(params, deck, timeout, hitRects);
%   ... opts.returnAbsTimes = true; (optional, currently informational)

if nargin < 2, deck = []; end
if nargin < 3 || isempty(timeout), timeout = Inf; end
if nargin < 4 || isempty(hitRects), hitRects = struct(); end
if nargin < 5, opts = struct(); end %#ok<NASGU>

respKey = '';
resp    = NaN;
rt_ms   = NaN;
tRespAbs = NaN;

t0 = GetSecs;

scr = Screen('WindowScreenNumber', params.win);

% --- mouse flush + edge state ---
[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

% --- keyboard: immediate pressed allowed ---
[prevKeyDown, ~, kc] = KbCheck; %#ok<ASGLU>
if prevKeyDown
    k = KbName(kc);
    if ischar(k), k = {k}; end
    [respKey, resp] = local_map_kb_to_123(k);
    if ~isempty(respKey)
        tRespAbs = GetSecs;
        rt_ms = (tRespAbs - t0) * 1000;
        return
    end
end

% --- deck: immediate pressed allowed ---
prevDeck = [];
if ~isempty(deck)
    try
        st0 = mixem.deck_read_states_any(deck);
        [respKey, resp] = local_map_deck_to_123(deck, st0);
        if ~isempty(respKey)
            tRespAbs = GetSecs;
            rt_ms = (tRespAbs - t0) * 1000;
            return
        end
        prevDeck = st0;
    catch
        prevDeck = [];
    end
end

% main polling loop
while (GetSecs - t0) < timeout

    % ---- mouse rising edge ----
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        if isfield(hitRects,'r1') && ~isempty(hitRects.r1) && IsInRect(mx,my,hitRects.r1)
            respKey='1'; resp=1;
            tRespAbs = GetSecs; break
        elseif isfield(hitRects,'r2') && ~isempty(hitRects.r2) && IsInRect(mx,my,hitRects.r2)
            respKey='2'; resp=2;
            tRespAbs = GetSecs; break
        elseif isfield(hitRects,'r3') && ~isempty(hitRects.r3) && IsInRect(mx,my,hitRects.r3)
            respKey='3'; resp=3;
            tRespAbs = GetSecs; break
        end
    end

    % ---- keyboard edge ----
    [keyDown, ~, kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc);
        if ischar(k), k = {k}; end
        [respKey, resp] = local_map_kb_to_123(k);
        if ~isempty(respKey)
            tRespAbs = GetSecs; break
        end
    end
    prevKeyDown = keyDown;

    % ---- deck edge (plus held fallback) ----
    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);

            % rising
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            [respKey, resp] = local_map_deck_to_123(deck, risingDeck);
            if ~isempty(respKey)
                tRespAbs = GetSecs; break
            end

            % held fallback (když někdo drží)
            [respKey, resp] = local_map_deck_to_123(deck, st);
            if ~isempty(respKey)
                tRespAbs = GetSecs; break
            end

        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end

% RT only if response occurred
if ~isempty(respKey) && isfinite(tRespAbs)
    rt_ms = (tRespAbs - t0) * 1000;
else
    rt_ms = NaN;
    tRespAbs = NaN;
end
end

function [rk, r] = local_map_kb_to_123(keys)
rk=''; r=NaN;
allowed = {'1!','2@','3#','1','2','3'};
hit = keys(find(ismember(keys, allowed), 1));
if isempty(hit), return; end
if startsWith(hit{1},'1'), rk='1'; r=1;
elseif startsWith(hit{1},'2'), rk='2'; r=2;
elseif startsWith(hit{1},'3'), rk='3'; r=3;
end
end

function [rk, r] = local_map_deck_to_123(deck, stVec)
rk=''; r=NaN;
if ~isstruct(deck), return; end
if ~isfield(deck,'k1Index0') || ~isfield(deck,'k2Index0') || ~isfield(deck,'k3Index0')
    return
end
p1 = deck.k1Index0 + 1;
p2 = deck.k2Index0 + 1;
p3 = deck.k3Index0 + 1;

if p1<=numel(stVec) && stVec(p1), rk='1'; r=1; return; end
if p2<=numel(stVec) && stVec(p2), rk='2'; r=2; return; end
if p3<=numel(stVec) && stVec(p3), rk='3'; r=3; return; end
end
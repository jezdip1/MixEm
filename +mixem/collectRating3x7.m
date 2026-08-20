function [out, params] = collectRating3x7(params, pngName, deck, opts)
% COLLECTRATING3X7
% pngName: 'resp_val_aud.png' or 'resp_val_vis.png'
%
% out.ratings      = [arousal valence intensity] (1..7)
% out.rt_ms        = time from rating screen onset to SUBMIT (ms)
% out.tRatingOn    = ABS GetSecs timestamp of the first rating-screen flip
% out.tSubmitAbs   = ABS GetSecs timestamp of confirmation
% out.tEndAbs      = ABS GetSecs timestamp immediately before return
% out.tStimOn      = stimulus onset in the embedded validation screen
% out.tStimOff     = stimulus offset / validation submit timestamp
%
% opts.stimPath/modality allow the validation stimulus to be presented on
% the same page as the rating scales. For visual trials the image is drawn
% at 500 x 400 px in the upper part of resp_val_vis.png. For auditory trials
% the sound is played after the rating screen appears and can be replayed via
% the speaker icon.

if nargin < 3, deck = []; end
if nargin < 4, opts = struct(); end

if ~isfield(opts,'startRow'), opts.startRow = 2; end   % 1..3
if ~isfield(opts,'startCol'), opts.startCol = 4; end   % 1..7
if ~isfield(opts,'stimPath'), opts.stimPath = ''; end
if ~isfield(opts,'modality'), opts.modality = ''; end
if ~isfield(opts,'imageW'), opts.imageW = 500; end
if ~isfield(opts,'imageH'), opts.imageH = 400; end
if ~isfield(opts,'autoPlayAudio'), opts.autoPlayAudio = true; end
if ~isfield(opts,'stimOnTrigger'), opts.stimOnTrigger = ''; end
if ~isfield(opts,'stimOffTrigger'), opts.stimOffTrigger = 'STIM_OFF'; end
if ~isfield(opts,'valScreenTrigger'), opts.valScreenTrigger = ''; end

modality = lower(strtrim(char(string(opts.modality))));
stimPath = char(string(opts.stimPath));
isAud = any(strcmp(modality, {'aud','audio','auditory'}));
isVis = any(strcmp(modality, {'vis','visual','image'}));

% Preload validation audio before the rating screen/trigger path. The same
% filled buffer can be restarted for replays without disk IO between trigger
% and PsychPortAudio Start.
audioPrepared = false;
if isAud && ~isempty(stimPath) && exist(stimPath,'file') == 2
    audioPrepared = mixem.prepareAudioFile(params, stimPath);
end

% hitboxes
gridRect = mixem.getClickableRectForPNG(params, pngName, 'grid');
contRect = mixem.getClickableRectForPNG(params, pngName, 'continue');

% speaker for auditory replay
spkRect = [];
try
    spkRect = mixem.getClickableRectForPNG(params, pngName, 'speaker');
catch
end

% optional visual stimulus texture on the same page as the scales
stimTex = [];
stimDst = [];
cleanupStim = [];
if isVis && ~isempty(stimPath) && exist(stimPath,'file') == 2
    try
        img = imread(stimPath);
        stimTex = Screen('MakeTexture', params.win, img);
        winRect = Screen('Rect', params.win);
        [cx, ~] = RectCenter(winRect);
        cy = winRect(2) + 0.25 * RectHeight(winRect);
        stimDst = CenterRectOnPoint([0 0 double(opts.imageW) double(opts.imageH)], cx, cy);
        cleanupStim = onCleanup(@() Screen('Close', stimTex)); %#ok<NASGU>
    catch ME
        warning('collectRating3x7:VisualOverlayFailed','Could not prepare validation image overlay: %s', ME.message);
        stimTex = [];
        stimDst = [];
    end
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

% state: no checkmark until explicitly selected
ratings = nan(1,3);        % [A V I]
filled  = false(1,3);
curRow  = opts.startRow;
curCol  = opts.startCol;

% outputs initialized before first render
out = struct();
out.ratings    = ratings;
out.rt_ms      = NaN;
out.tRatingOn  = NaN;
out.tSubmitAbs = NaN;
out.tEndAbs    = NaN;
out.tStimOn    = NaN;
out.tStimOff   = NaN;
out.audioReplayCount = 0;

% -------- render initial rating page + embedded stimulus --------
tRatingOn = local_render(true);
out.tRatingOn = double(tRatingOn);

if ~isempty(opts.valScreenTrigger)
    params = mixem.sendTrig(params, char(opts.valScreenTrigger));
end

if isVis
    out.tStimOn = double(tRatingOn);
    if ~isempty(opts.stimOnTrigger)
        params = mixem.sendTrig(params, char(opts.stimOnTrigger));
    end
elseif isAud && opts.autoPlayAudio
    local_play_audio('initial');
end

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

while true
    % -------- mouse --------
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        % continue (only once all three rows are filled)
        if ~isempty(contRect) && IsInRect(mx,my,contRect)
            if local_try_submit(), return; end
        end

        % replay speaker (auditory validation)
        if isAud && ~isempty(spkRect) && IsInRect(mx,my,spkRect)
            local_play_audio('replay');
        end

        % grid click -> select value/checkmark for that row
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

        % SUBMIT: Enter/Return
        if any(strcmpi(k,'return')) || any(strcmpi(k,'enter'))
            if local_try_submit(), return; end
        end

        % SELECT: Space
        if any(strcmpi(k,'space'))
            ratings(curRow) = curCol;
            filled(curRow)  = true;
            local_render(false);
        end

        % Movement
        if any(strcmpi(k,'LeftArrow'))
            curCol = max(1, curCol-1); local_render(false);
        elseif any(strcmpi(k,'RightArrow'))
            curCol = min(7, curCol+1); local_render(false);
        elseif any(strcmpi(k,'UpArrow'))
            curRow = max(1, curRow-1); local_render(false);
        elseif any(strcmpi(k,'DownArrow'))
            curRow = min(3, curRow+1); local_render(false);
        end

        % Numeric direct select 1..7 for current row
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

            % SUBMIT: CONT
            if pCont<=numel(risingDeck) && risingDeck(pCont)
                if local_try_submit(), return; end
            end

            % Movement/select
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

        if ~isempty(stimTex) && ~isempty(stimDst)
            Screen('DrawTexture', params.win, stimTex, [], stimDst);
        end

        if isfield(params,'debugClickable') && params.debugClickable
            if ~isempty(gridRect), Screen('FrameRect', params.win, [80 80 80], gridRect, 1); end
            if ~isempty(contRect), Screen('FrameRect', params.win, [80 80 80], contRect, 1); end
            if ~isempty(spkRect),  Screen('FrameRect', params.win, [80 80 80], spkRect, 1); end
            if ~isempty(stimDst),  Screen('FrameRect', params.win, [80 80 80], stimDst, 1); end
        end

        % checkmarks for filled rows
        for rr = 1:3
            if ~filled(rr), continue; end
            cc = ratings(rr);
            rc = local_cell_rect(rr, cc);
            local_draw_checkmark(rc);
        end

        % cursor
        curRc = local_cell_rect(curRow, curCol);
        Screen('FrameRect', params.win, [255 255 0], curRc, 4);

        tFlip = Screen('Flip', params.win);
    end

    function local_play_audio(note)
        if ~isAud || isempty(stimPath) || exist(stimPath,'file') ~= 2
            return
        end
        % If replay is requested while the previous playback is still active,
        % fade it briefly instead of cutting it at an arbitrary sample.
        try, mixem.stopAudio(params, 0.020); catch, end
        if ~isempty(opts.stimOnTrigger)
            params = mixem.sendTrig(params, char(opts.stimOnTrigger), 'note', char(note));
        end
        tTrigAud = local_last_trig_getsecs(params);
        if audioPrepared
            tAudOn = mixem.startPreparedAudio(params);
        else
            tAudOn = NaN;
        end
        trigToAudio_ms = NaN;
        if isfinite(tTrigAud) && isfinite(tAudOn)
            trigToAudio_ms = 1000*(tAudOn - tTrigAud);
        end
        if strcmp(note,'replay')
            out.audioReplayCount = out.audioReplayCount + 1;
        end
        if ~isfinite(out.tStimOn) || isnan(out.tStimOn)
            out.tStimOn = double(tAudOn);
        end
        try
            params = mixem.logMsg(params, "VAL_AUDIO_PLAY", 'note', string(note), 'file', stimPath, ...
                'tAudOn_GetSecs', tAudOn, 'trigToAudio_ms', trigToAudio_ms);
        catch
        end
    end

    function t = local_last_trig_getsecs(paramsLocal)
        t = NaN;
        try
            if isfield(paramsLocal,'trigLog') && ~isempty(paramsLocal.trigLog) && ...
                    ismember('GetSecs_On', paramsLocal.trigLog.Properties.VariableNames)
                t = double(paramsLocal.trigLog.GetSecs_On(end));
            end
        catch
        end
    end

    function done = local_try_submit()
        done = false;
        if all(filled)
            if isAud
                try, mixem.stopAudio(params); catch, end
            end
            out.ratings    = ratings;
            out.tSubmitAbs = GetSecs;
            out.rt_ms      = (out.tSubmitAbs - out.tRatingOn) * 1000;
            out.tEndAbs    = GetSecs;
            out.tStimOff   = out.tEndAbs;
            if ~isempty(opts.stimOffTrigger)
                params = mixem.sendTrig(params, char(opts.stimOffTrigger));
            end
            done = true;
        else
            local_render(false);
        end
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

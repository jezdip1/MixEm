function runControlCondition(params, phase)
% RUNCONTROLCONDITION  Control task (low/mid/high tone OR dark/mid/bright grey).
%
% Systemově dle masterSchedule: v dané Phase spustí screen+trial sekvenčně dle Seq.
%
% phase (orchestrace z RunExperiment):
%   'practice'      -> Phase 'practice_control'
%   'control_1_4'   -> Phase 'test'         (Blocks 1-4)
%   'control_5_8'   -> Phase 'supplemental' (Blocks 5-8)
%   'control_9_12'  -> Phase 'repetition2'  (Blocks 9-12)
%
% TIMING POLICY:
% - OnsetFix, OnsetStim, OffsetStim, OnsetPrompt1, OnsetPrompt2, TrialEnd: ABS GetSecs (double).
% - WallClockEpoch_TrialEnd: POSIX epoch (double) via params.getsecs_minus_epoch.
% - RT_ms: default RT from stimulus onset (aud: audio onset if available, else stim screen onset; vis: stim flip).

ms = params.masterSchedule;
cellchar = @(v) local_cellchar(v);

% map phase -> PhaseName + optional block filter
switch phase
    case 'practice'
        phaseName = 'practice_control';
        blkLo = -Inf; blkHi = Inf;

    case 'control_1_4'
        phaseName = 'test';
        blkLo = 1; blkHi = 4;

    case 'control_5_8'
        phaseName = 'supplemental';
        blkLo = 5; blkHi = 8;

    case 'control_9_12'
        phaseName = 'repetition2';
        blkLo = 9; blkHi = 12;

    otherwise
        error('runControlCondition:BadPhase','Neznámý phase=%s', phase);
end

% vyber screeny v dané phase + control trialy v dané phase (+ blok filtr)
isPhase  = strcmp(cellfun(cellchar, ms.Phase, 'UniformOutput', false), phaseName);
isScreen = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'screen');
isTrial  = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial') & ...
                    strcmp(cellfun(cellchar, ms.Task,  'UniformOutput', false), 'control') & ...
                    (ms.Block >= blkLo) & (ms.Block <= blkHi);

rows = ms(isScreen | isTrial,:);
if height(rows)==0
    warning('runControlCondition:NoRows','Žádné řádky pro phase=%s (%s).', phase, phaseName);
    return
end

% řadit dle Seq
[~,ord] = sort(rows.Seq);
rows = rows(ord,:);

if isfield(params,'resumeActive') && logical(params.resumeActive) && ...
        isfield(params,'lastCompletedSeq') && ~isempty(params.lastCompletedSeq)
    rows = rows(rows.Seq > double(params.lastCompletedSeq), :);
    if height(rows)==0
        params = mixem.logMsg(params, "CONTROL_SKIP_ALREADY_DONE", 'phase', phase, 'phaseName', phaseName);
        assignin('caller','params',params);
        return
    end
end

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

% --- helper: vybrat 3 demo tóny (low/mid/high) ---
demoTones = local_pick_demo_tones(params);

params = mixem.logMsg(params, "CONTROL_BEGIN", 'phase', phase, 'phaseName', phaseName, 'blkLo', blkLo, 'blkHi', blkHi, 'nRows', height(rows));
params = mixem.progressMsg(params, 'CONTROL_BEGIN', 'phase', phaseName, 'blocks', sprintf('%d-%d', blkLo, blkHi), 'rows', height(rows));

% -------- PRACTICE repeat loop (včetně instrukcí) --------
repeatPractice = strcmp(phase,'practice');
while true
    if ~repeatPractice
        [params, ~] = local_run_once(params, rows, phase, demoTones, dbg, hasBridge);
        break
    end

    [params, doRepeat] = local_run_once(params, rows, phase, demoTones, dbg, hasBridge);

    if doRepeat
        params = mixem.logMsg(params, "CONTROL_PRACTICE_REPEAT_LOOP");
        continue
    else
        break
    end
end

params = mixem.logMsg(params, "CONTROL_END", 'phase', phase, 'phaseName', phaseName);
params = mixem.progressMsg(params, 'CONTROL_DONE', 'phase', phaseName);

assignin('caller','params',params);
end

% ======================== core runner ========================

function [params, doRepeat] = local_run_once(params, rows, phase, demoTones, dbg, hasBridge)
doRepeat = false;

cellchar = @(v) local_cellchar(v);

% na začátku: screen pages -> OK-only deck
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

for k = 1:height(rows)
    r  = rows(k,:);
    ev = cellchar(r.Event);

    % set common context
    params.currentSeq   = double(r.Seq);
    params.currentBlock = double(r.Block);
    params.currentTrialInBlock = double(r.TrialInBlock);
    params.currentTask  = "control";

    if strcmp(ev,'screen')
        png = cellchar(r.PNG);
        if isempty(png), continue; end

        params.currentModality = "";
        params.currentStimPath = "";

        params = mixem.logMsg(params, "SCREEN", 'PNG', png, 'phase', phase);
        params = mixem.progressMsg(params, 'SCREEN', 'phase', phase, 'block', double(r.Block), 'seq', double(r.Seq), 'png', png);

        % --- stim_control = interaktivní DEMO ---
        if strcmp(png,'stim_control.png')
            params = local_run_stim_control_demo(params, demoTones, dbg);
            continue
        end

        % --- re_stim_control = volba repeat demo / continue ---
        if strcmp(png,'re_stim_control.png')
            choice = local_wait_repeat_continue(params, 're_stim_control.png', dbg);
            params = mixem.logMsg(params, "RE_STIM_CONTROL", 'choice', choice);

            if strcmp(choice,'repeat')
                params = local_run_stim_control_demo(params, demoTones, dbg);
                choice = local_wait_repeat_continue(params, 're_stim_control.png', dbg);
                params = mixem.logMsg(params, "RE_STIM_CONTROL", 'choice', choice);

                while strcmp(choice,'repeat')
                    params = local_run_stim_control_demo(params, demoTones, dbg);
                    choice = local_wait_repeat_continue(params, 're_stim_control.png', dbg);
                    params = mixem.logMsg(params, "RE_STIM_CONTROL", 'choice', choice);
                end
            end
            continue
        end

        % --- feedback.png na konci practice_control: repeat/continue pro celý practice ---
        if strcmp(png,'feedback.png') && strcmp(phase,'practice')
            choice = mixem.waitFeedbackDecision(params);
            params = mixem.logMsg(params, "PRACTICE_FEEDBACK", 'choice', choice);
            if strcmp(choice,'repeat')
                doRepeat = true;
            end
            params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
            try, mixem.safeSave(params); catch, end
            return
        end

        % --- běžný screen ---
        if isfield(params,'deck') && ~isempty(params.deck)
            try, params.deck = mixem.deck_show_ok(params.deck); catch, end
        end
        mixem.waitOnPNG(params, png, params.deck, dbg);
        params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
        try, mixem.safeSave(params); catch, end
        continue
    end

    % -------------------- TRIAL (control) --------------------
    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_123(params.deck); catch, end
    end
%     if isfield(params,'deck') && ~isempty(params.deck)
%         try
%             params.deck = mixem.deck_show_123(params.deck);
%             % některé implementace potřebují ještě explicitní redraw/refresh:
% %             try, params.deck = mixem.deck_render(params.deck); catch, end   % pokud existuje
%         catch ME
%             % fallback: aspoň logni a vrať deck do 123 přes hard reset (viz níž)
%             params = mixem.logMsg(params, "DECK_SHOW_123_FAIL", 'msg', ME.message);
%         end
%     end

    modality = lower(strtrim(cellchar(r.Modality)));
    stimPath = cellchar(r.StimPath);

    params.currentModality = string(modality);
    params.currentStimPath = string(stimPath);

    params = mixem.logMsg(params, "TRIAL_START", 'phase', phase, 'modality', modality, 'stim', stimPath);
    params = mixem.progressMsg(params, 'TRIAL_START', 'phase', phase, 'task', 'control', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'modality', modality, 'stim', stimPath);

    % Preserve the historical RNG order (fix jitter first, control duration
    % second), but prepare audio before fixation starts.
    fixWait = 2 + rand()*0.5;
    stimTimeout = 0.3 + rand()*3.3;

    audioPrepared = false;
    if any(strcmp(modality, {'aud','audio'}))
        audioPrepared = mixem.prepareAudioFile(params, stimPath, ...
            'MaxDurationSec', stimTimeout, 'FadeOutSec', 0.050);
    end

    % Fix cross 2–2.5 s jitter
    mixem.showPNG(params,'fix_cross.png',false);
    tFixOn = Screen('Flip', params.win);
    params = mixem.sendTrig(params,'FIX_ON');
    WaitSecs(fixWait);

    % init timestamps
    tStimOn    = NaN;
    tStimOff   = NaN;
    tAudOn     = NaN;
    tPrompt1On = NaN;
    tPrompt2On = NaN;

    respKey = '';
    resp    = NaN;
    rt_ms   = NaN;
    tRespAbs = NaN;
    sentRespTrig = false;

    if any(strcmp(modality, {'aud','audio'}))
        mixem.showPNG(params,'stim_aud.png',false);
        tStimOn = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'STIM_ON_AUD');

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
        params = mixem.logMsg(params, "AUDIO_START", 'file', stimPath, 'tAudOn_GetSecs', tAudOn, ...
            'trigToAudio_ms', trigToAudio_ms, 'plannedDur_ms', 1000*stimTimeout, 'plannedFadeOut_ms', 50);

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "stim");
        end

        % At the planned timeout, prepareAudioFile has already shaped the
        % buffer to end with a 50 ms fade exactly at stimTimeout. If the
        % participant responded earlier, start a 50 ms runtime fade now.
        if ~isempty(respKey)
            fadeSec = 0.050;
            if isfinite(tAudOn) && isfinite(tRespAbs)
                fadeSec = min(fadeSec, max(0, (tAudOn + stimTimeout) - tRespAbs));
            end
            tStimOff = mixem.stopAudio(params, fadeSec);
        else
            tStimOff = mixem.stopAudio(params, 0);
        end

        tRef = tStimOn;
        if isfinite(tAudOn), tRef = tAudOn; end
        if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tRef); end

    else
        tStimOn = mixem.showImageCentered(params, stimPath, 500, 400);
        params = mixem.logMsg(params, "VIS_ON", 'file', stimPath, 'tOn_GetSecs', tStimOn);
        params = mixem.sendTrig(params,'STIM_ON_VIS');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, stimTimeout, struct());
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "stim");
        end

        if isfinite(tRespAbs), rt_ms = 1000*(tRespAbs - tStimOn); end

        if ~isempty(respKey)
            tStimOff = mixem.clearScreen(params, 0);
        end
    end

    % stim off = moment we leave stim section
    if isnan(tStimOff)
        tStimOff = GetSecs;
    end
    params = mixem.sendTrig(params,'STIM_OFF');

    % Prompt cascade (stejné jako main)
    hitP1 = local_prompt_hitrects(params,'prompt_1.png');
    hitP2 = local_prompt_hitrects(params,'prompt_2.png');

    if isempty(respKey)
        mixem.showPNG(params,'prompt_1.png',false);
        tPrompt1On = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'PROMPT1_ON');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, 2.0, hitP1);
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "prompt1");
        end
    end

    if isempty(respKey)
        mixem.showPNG(params,'prompt_2.png',false);
        tPrompt2On = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'PROMPT2_ON');

        [respKey, resp, ~, tRespAbs] = mixem.collectResponse123(params, params.deck, Inf, hitP2);
        if ~isempty(respKey) && ~sentRespTrig
            params = mixem.sendTrig(params,'RESP_KEYPRESS','note',respKey);
            sentRespTrig = true;
            params = mixem.logMsg(params, "RESP", 'respKey', respKey, 'resp', resp, 'tResp_GetSecs', tRespAbs, 'from', "prompt2");
        end
    end

    % If response arrived during prompt_1/prompt_2, rt_ms was not set in
    % the stimulus window above. RT is still measured from stimulus onset
    % (audio: actual audio onset when available; visual: image flip).
    if isnan(rt_ms) && isfinite(tRespAbs)
        tRef = tStimOn;
        if exist('tAudOn','var') && isfinite(tAudOn)
            tRef = tAudOn;
        end
        if isfinite(tRef)
            rt_ms = 1000*(tRespAbs - tRef);
        end
    end

    tTrialEnd = GetSecs;
    epochEnd = NaN;
    if hasBridge
        epochEnd = tTrialEnd - params.getsecs_minus_epoch;
    end

    % Log do resultsTable
    if isempty(respKey)
        respKeyStr = ""; respStr = "";
    else
        respKeyStr = string(respKey);
        respStr    = respKeyStr;
    end

    row = { ...
        string(params.subjID), ...
        "control", double(r.Block), double(r.TrialInBlock), ...
        string(modality), "na", string(stimPath), double(1000*stimTimeout), ...
        "control_1_2_3", NaN, respKeyStr, respStr, double(rt_ms), ...
        double(tFixOn), double(tStimOn), double(tStimOff), ...
        double(tPrompt1On), double(tPrompt2On), double(NaN), double(tTrialEnd), ...
        double(epochEnd) ...
    };

    params.resultsTable = [params.resultsTable; row]; %#ok<AGROW>

    params = mixem.sendTrig(params,'TRIAL_END');
    params = mixem.logMsg(params, "TRIAL_END", 'respKey', respKeyStr, 'rt_ms', rt_ms, 'tTrialEnd_GetSecs', tTrialEnd);
    params = mixem.progressMsg(params, 'TRIAL_DONE', 'phase', phase, 'task', 'control', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'resp', respKeyStr, 'rt_ms', rt_ms);

    params.currTrial = params.currTrial + 1;
    params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
    mixem.safeSave(params);
end
end

% ======================== stim_control demo ========================

function params = local_run_stim_control_demo(params, demoTones, dbg)
% stim_control: interaktivní demo obrazovka (3 tóny + continue).
mixem.showPNG(params,'stim_control.png',false);

params.currentTask = "control_demo";
params.currentModality = "";
params.currentStimPath = "";

hit = struct();
hit.r1 = []; hit.r2 = []; hit.r3 = [];
try, hit.r1 = mixem.getClickableRectForPNG(params,'stim_control.png',"r1"); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,'stim_control.png',"r2"); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,'stim_control.png',"r3"); catch, end

hitCont = [];
try, hitCont = mixem.getClickableRectForPNG(params,'stim_control.png',"continue"); catch, end

if dbg
    if ~isempty(hit.r1), Screen('FrameRect', params.win, [255 0 0], hit.r1, 2); end
    if ~isempty(hit.r2), Screen('FrameRect', params.win, [0 255 0], hit.r2, 2); end
    if ~isempty(hit.r3), Screen('FrameRect', params.win, [0 0 255], hit.r3, 2); end
    if ~isempty(hitCont), Screen('FrameRect', params.win, [255 255 0], hitCont, 2); end
end
Screen('Flip', params.win);

params = mixem.logMsg(params, "CONTROL_DEMO_ON");
params = mixem.progressMsg(params, 'CONTROL_DEMO');

% Deck: 1/2/3 + OK
deck = [];
if isfield(params,'deck'), deck = params.deck; end
if ~isempty(deck)
    try
        deck = mixem.deck_show_123(deck);
        deck.okIndex0 = 4;
        deck = mixem.deck_set_key_icon(deck, deck.okIndex0, 'OK', 'green');
        deck = mixem.deck_clear_keys(deck, setdiff(0:(double(deck.dev.key_count())-1), [deck.k1Index0 deck.k2Index0 deck.k3Index0 deck.okIndex0]));
        params.deck = deck;
%         deck = mixem.deck_show_123(deck);
%         
%         % explicitně nastav ikony/štítky pro 1/2/3
%         deck = mixem.deck_set_key_icon(deck, deck.k1Index0, '1', 'red');
%         deck = mixem.deck_set_key_icon(deck, deck.k2Index0, '2', 'yellow');
%         deck = mixem.deck_set_key_icon(deck, deck.k3Index0, '3', 'green');
%         
%         % OK tlačítko
%         deck.okIndex0 = 4;
%         deck = mixem.deck_set_key_icon(deck, deck.okIndex0, 'OK', 'green');
%         
%         % nech jen 1/2/3/OK, ostatní zhasni
%         deck = mixem.deck_clear_keys(deck, setdiff(0:(double(deck.dev.key_count())-1), ...
%             [deck.k1Index0 deck.k2Index0 deck.k3Index0 deck.okIndex0]));
%         params.deck = deck;
    catch
        deck = [];
    end
end

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
    try, prevDeck = mixem.deck_read_states_any(deck); catch, prevDeck = []; end
end

while true
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        if ~isempty(hit.r1) && IsInRect(mx,my,hit.r1)
            if ~isempty(demoTones{1})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "low", 'file', demoTones{1});
                mixem.playAudioFile(params, demoTones{1});
            end
        elseif ~isempty(hit.r2) && IsInRect(mx,my,hit.r2)
            if ~isempty(demoTones{2})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "mid", 'file', demoTones{2});
                mixem.playAudioFile(params, demoTones{2});
            end
        elseif ~isempty(hit.r3) && IsInRect(mx,my,hit.r3)
            if ~isempty(demoTones{3})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "high", 'file', demoTones{3});
                mixem.playAudioFile(params, demoTones{3});
            end
        elseif ~isempty(hitCont) && IsInRect(mx,my,hitCont)
            params = mixem.logMsg(params, "CONTROL_DEMO_CONTINUE");
            mixem.stopAudio(params);
            return
        end
    end

    [keyDown,~,kc] = KbCheck;
    if keyDown && ~prevKeyDown
        k = KbName(kc);
        if ischar(k), k = {k}; end
        if any(strcmp(k,'1!')) || any(strcmp(k,'1'))
            if ~isempty(demoTones{1})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "low", 'file', demoTones{1});
                mixem.playAudioFile(params, demoTones{1});
            end
        elseif any(strcmp(k,'2@')) || any(strcmp(k,'2'))
            if ~isempty(demoTones{2})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "mid", 'file', demoTones{2});
                mixem.playAudioFile(params, demoTones{2});
            end
        elseif any(strcmp(k,'3#')) || any(strcmp(k,'3'))
            if ~isempty(demoTones{3})
                params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "high", 'file', demoTones{3});
                mixem.playAudioFile(params, demoTones{3});
            end
        else
            params = mixem.logMsg(params, "CONTROL_DEMO_EXIT_BY_KEY");
            mixem.stopAudio(params);
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

            p1  = deck.k1Index0 + 1;
            p2  = deck.k2Index0 + 1;
            p3  = deck.k3Index0 + 1;
            pOk = deck.okIndex0 + 1;

            if p1<=numel(risingDeck) && risingDeck(p1)
                if ~isempty(demoTones{1})
                    params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "low", 'file', demoTones{1});
                    mixem.playAudioFile(params, demoTones{1});
                end
            elseif p2<=numel(risingDeck) && risingDeck(p2)
                if ~isempty(demoTones{2})
                    params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "mid", 'file', demoTones{2});
                    mixem.playAudioFile(params, demoTones{2});
                end
            elseif p3<=numel(risingDeck) && risingDeck(p3)
                if ~isempty(demoTones{3})
                    params = mixem.logMsg(params, "CONTROL_DEMO_PLAY", 'which', "high", 'file', demoTones{3});
                    mixem.playAudioFile(params, demoTones{3});
                end
            elseif pOk<=numel(risingDeck) && risingDeck(pOk)
                params = mixem.logMsg(params, "CONTROL_DEMO_CONTINUE");
                mixem.stopAudio(params);
                return
            end
        catch
            deck = [];
        end
    end

    WaitSecs(0.001);
end
end

function tones = local_pick_demo_tones(params)
% tones{1}=low, tones{2}=mid, tones{3}=high
tones = {[],[],[]};
folder = fullfile(params.stimDir,'control_stimuli');

lowD  = dir(fullfile(folder,'control_tone_low_*.wav'));
midD  = dir(fullfile(folder,'control_tone_mid_*.wav'));
highD = dir(fullfile(folder,'control_tone_high_*.wav'));

pick1 = @(D) local_pick_first_deterministic(D);

tones{1} = pick1(lowD);
tones{2} = pick1(midD);
tones{3} = pick1(highD);

if ~isempty(tones{1}) && ~isempty(tones{2}) && ~isempty(tones{3})
    return
end

D = dir(fullfile(folder,'control_tone_*.wav'));
if isempty(D), return; end

freq = nan(numel(D),1);
for i = 1:numel(D)
    nm = D(i).name;
    m = regexp(nm, '([0-9]+(?:\.[0-9]+)?(?:e[+\-]?[0-9]+)?)Hz', 'tokens', 'once');
    if ~isempty(m)
        freq(i) = str2double(m{1});
    end
end

valid = ~isnan(freq);
if nnz(valid) >= 3
    Dv = D(valid);
    fv = freq(valid);

    [~,ix] = sort(fv, 'ascend');
    Dv = Dv(ix);

    tones{1} = fullfile(Dv(1).folder, Dv(1).name);
    tones{2} = fullfile(Dv(round(numel(Dv)/2)).folder, Dv(round(numel(Dv)/2)).name);
    tones{3} = fullfile(Dv(end).folder, Dv(end).name);
    return
end

[~,ix] = sort({D.name});
D = D(ix);
for i = 1:min(3,numel(D))
    tones{i} = fullfile(D(i).folder, D(i).name);
end
end

function p = local_pick_first_deterministic(D)
p = [];
if isempty(D), return; end
[~,ix] = sort({D.name});
d = D(ix(1));
p = fullfile(d.folder, d.name);
end

% ======================== repeat/continue generic ========================

function choice = local_wait_repeat_continue(params, pngName, dbg)
mixem.showPNG(params, pngName, false);

hitRepeat = [];
hitCont   = [];
try, hitRepeat = mixem.getClickableRectForPNG(params, pngName, "repeat"); catch, end
try, hitCont   = mixem.getClickableRectForPNG(params, pngName, "continue"); catch, end

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

% mouse flush
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
        k = KbName(kc);
        if ischar(k), k={k}; end
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

% ======================== misc helpers ========================

function t = local_last_trig_getsecs(params)
t = NaN;
try
    if isfield(params,'trigLog') && ~isempty(params.trigLog) && ...
            ismember('GetSecs_On', params.trigLog.Properties.VariableNames)
        t = double(params.trigLog.GetSecs_On(end));
    end
catch
end
end

function v = getfield_with_default(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = s.(fieldName);
else
    v = defaultValue;
end
end


function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s=''; else, s=char(v{1}); end
else
    s = char(v);
end
end

function hit = local_prompt_hitrects(params, pngName)
hit = struct('r1',[],'r2',[],'r3',[]);
try, hit.r1 = mixem.getClickableRectForPNG(params,pngName,"r1"); catch, end
try, hit.r2 = mixem.getClickableRectForPNG(params,pngName,"r2"); catch, end
try, hit.r3 = mixem.getClickableRectForPNG(params,pngName,"r3"); catch, end
end
% end
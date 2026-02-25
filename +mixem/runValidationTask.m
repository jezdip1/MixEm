function runValidationTask(params)
% Validation: stimulus -> rating (3 škály 1..7) -> continue
% jede podle masterSchedule Phase='validation' (screen + trial podle Seq)

ms = params.masterSchedule;
cellchar = @(v) local_cellchar(v);

isPhase  = strcmp(cellfun(cellchar, ms.Phase, 'UniformOutput', false), 'validation');
isScreen = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'screen');
isTrial  = isPhase & strcmp(cellfun(cellchar, ms.Event, 'UniformOutput', false), 'trial') & ...
                    strcmp(cellfun(cellchar, ms.Task,  'UniformOutput', false), 'validation');

rows = ms(isScreen | isTrial, :);
if height(rows)==0
    warning('runValidationTask:NoRows','No validation rows in masterSchedule.');
    return
end

[~,ord] = sort(rows.Seq);
rows = rows(ord,:);

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

% Screen pages OK-only
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

params = mixem.logMsg(params, "VAL_TASK_BEGIN");

for k = 1:height(rows)
    r = rows(k,:);
    ev = cellchar(r.Event);

    % keep context for logging/trigger log
    params.currentSeq   = double(r.Seq);
    params.currentBlock = double(r.Block);
    params.currentTrialInBlock = double(r.TrialInBlock);
    params.currentTask  = "validation";

    if strcmp(ev,'screen')
        png = cellchar(r.PNG);
        if ~isempty(png)
            params = mixem.logMsg(params, "SCREEN", 'PNG', png);
            if isfield(params,'deck') && ~isempty(params.deck)
                try, params.deck = mixem.deck_show_ok(params.deck); catch, end
            end
            mixem.waitOnPNG(params, png, params.deck, dbg);
        end
        continue
    end

    % --- trial ---
    modality = local_norm_modality(cellchar(r.Modality));
    stimPath = cellchar(r.StimPath);

    params.currentModality = string(modality);
    params.currentStimPath = string(stimPath);

    params = mixem.logMsg(params, "TRIAL_START", 'Phase', "validation", 'Modality', modality, 'Stim', stimPath);

    % Fix
    mixem.showPNG(params,'fix_cross.png',false);
    tFixOn = Screen('Flip', params.win);
    params = mixem.sendTrig(params,'FIX_ON');
    WaitSecs(2 + rand()*0.5);

    % Stimulus
    tStimOn  = NaN;
    tStimOff = NaN;

    if strcmp(modality,'aud')
        mixem.showPNG(params,'stim_aud.png',false);
        tStimOn = Screen('Flip', params.win);
        params = mixem.sendTrig(params,'STIM_ON_AUD');

        tAudOn = mixem.playAudioFile(params, stimPath);
        params = mixem.logMsg(params, "AUDIO_START", 'File', stimPath, 'tAudOn_GetSecs', tAudOn);

        d = local_audio_duration_sec(stimPath);
        if isnan(d) || d<=0, d = 1.0; end
        WaitSecs(d + 0.05);

        try, mixem.stopAudio(params); catch, end

        tStimOff = GetSecs;
        params = mixem.sendTrig(params,'STIM_OFF');
        ratingPng = 'resp_val_aud.png';

        % screen marker (optional)
        params = mixem.sendTrig(params,'VAL_SCREEN_ON_AUD');

    else
        tStimOn = mixem.showImageCentered(params, stimPath, 500, 400);
        params = mixem.logMsg(params, "VIS_ON", 'File', stimPath, 'tOn_GetSecs', tStimOn);
        params = mixem.sendTrig(params,'STIM_ON_VIS');

        dur_ms = double(r.Dur_ms);
        if isnan(dur_ms) || dur_ms<=0
            WaitSecs(1.5);
        else
            WaitSecs(dur_ms/1000);
        end

        tStimOff = GetSecs;
        params = mixem.sendTrig(params,'STIM_OFF');
        ratingPng = 'resp_val_vis.png';

        params = mixem.sendTrig(params,'VAL_SCREEN_ON_VIS');
    end

    % Rating UI (deck navigation)
    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_rating_nav(params.deck); catch, end
    end

    out = mixem.collectRating3x7(params, ratingPng, params.deck, struct());

    ratings   = out.ratings;    % [A V I]
    rt_ms     = out.rt_ms;
    tRatingOn = double(out.tRatingOn);

    params = mixem.logMsg(params, "RATING_ON", 'PNG', ratingPng, 'tOn_GetSecs', tRatingOn);

    % TrialEnd policy
    tTrialEnd = double(out.tEndAbs);
    epochEnd = NaN;
    if hasBridge && isfinite(tTrialEnd)
        epochEnd = tTrialEnd - params.getsecs_minus_epoch;
    end

    params = mixem.logMsg(params, "RATING_SUBMIT", ...
        'ratings', ratings, 'rt_ms', rt_ms, 'tSubmit_GetSecs', double(out.tSubmitAbs));

    % TTL marker for submit/continue
    params = mixem.sendTrig(params,'VAL_CONTINUE');

    respStr = sprintf('A=%d;V=%d;I=%d', ratings(1), ratings(2), ratings(3));

    cc = NaN;
    if ismember('CorrectCat', r.Properties.VariableNames)
        try, cc = double(r.CorrectCat); catch, cc = NaN; end
    end

    rowOut = { ...
        string(params.subjID), ...
        "validation", double(r.Block), double(r.TrialInBlock), ...
        string(modality), "", string(stimPath), double(r.Dur_ms), ...
        "rating_1_7", double(cc), "RATING", string(respStr), double(rt_ms), ...
        double(tFixOn), double(tStimOn), double(tStimOff), ...
        double(NaN), double(NaN), double(tRatingOn), double(tTrialEnd), ...
        double(epochEnd) ...
    };

    params.resultsTable = [params.resultsTable; rowOut]; %#ok<AGROW>

    params = mixem.sendTrig(params,'TRIAL_END');
    params = mixem.logMsg(params, "TRIAL_END", 'TrialEnd_GetSecs', tTrialEnd);

    params.currTrial = params.currTrial + 1;
    mixem.safeSave(params);
end

params = mixem.logMsg(params, "VAL_TASK_END");

assignin('caller','params',params);
end

% ---- helpers ----
function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1}), s=''; else, s=char(v{1}); end
else
    s = char(v);
end
end

function m = local_norm_modality(m)
m = lower(strtrim(m));
if any(strcmp(m, {'aud','audio','auditory'})), m='aud'; return; end
if any(strcmp(m, {'vis','visual','image'})),   m='vis'; return; end
end

function d = local_audio_duration_sec(wavPath)
d = NaN;
try
    info = audioinfo(wavPath);
    d = double(info.Duration);
catch
end
end
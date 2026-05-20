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

if isfield(params,'resumeActive') && logical(params.resumeActive) && ...
        isfield(params,'lastCompletedSeq') && ~isempty(params.lastCompletedSeq)
    rows = rows(rows.Seq > double(params.lastCompletedSeq), :);
    if height(rows)==0
        params = mixem.logMsg(params, "VAL_SKIP_ALREADY_DONE");
        assignin('caller','params',params);
        return
    end
end

dbg = false;
if isfield(params,'debugClickable'), dbg = logical(params.debugClickable); end

hasBridge = isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
         && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch);

% Screen pages OK-only
if isfield(params,'deck') && ~isempty(params.deck)
    try, params.deck = mixem.deck_show_ok(params.deck); catch, end
end

params = mixem.logMsg(params, "VAL_TASK_BEGIN");
params = mixem.progressMsg(params, 'VAL_BEGIN', 'rows', height(rows));

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
            params = mixem.progressMsg(params, 'SCREEN', 'phase', 'validation', 'block', double(r.Block), 'seq', double(r.Seq), 'png', png);
            if isfield(params,'deck') && ~isempty(params.deck)
                try, params.deck = mixem.deck_show_ok(params.deck); catch, end
            end
            mixem.waitOnPNG(params, png, params.deck, dbg);
            params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
            try, mixem.safeSave(params); catch, end
        end
        continue
    end

    % --- trial ---
    modality = local_norm_modality(cellchar(r.Modality));
    stimPath = cellchar(r.StimPath);

    params.currentModality = string(modality);
    params.currentStimPath = string(stimPath);

    params = mixem.logMsg(params, "TRIAL_START", 'Phase', "validation", 'Modality', modality, 'Stim', stimPath);
    params = mixem.progressMsg(params, 'TRIAL_START', 'phase', 'validation', 'task', 'validation', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'modality', modality, 'stim', stimPath);

    % Fix
    mixem.showPNG(params,'fix_cross.png',false);
    tFixOn = Screen('Flip', params.win);
    params = mixem.sendTrig(params,'FIX_ON');
    WaitSecs(2 + rand()*0.5);

    % Rating UI with embedded stimulus (validation design):
    % - visual stimulus is shown on resp_val_vis.png together with scales
    % - auditory stimulus is played from resp_val_aud.png and replayable
    tStimOn  = NaN;
    tStimOff = NaN;

    if strcmp(modality,'aud')
        ratingPng = 'resp_val_aud.png';
        stimOnTrig = 'STIM_ON_AUD';
        valScreenTrig = 'VAL_SCREEN_ON_AUD';
    else
        ratingPng = 'resp_val_vis.png';
        stimOnTrig = 'STIM_ON_VIS';
        valScreenTrig = 'VAL_SCREEN_ON_VIS';
    end

    % Rating UI (deck navigation)
    if isfield(params,'deck') && ~isempty(params.deck)
        try, params.deck = mixem.deck_show_rating_nav(params.deck); catch, end
    end

    ratingOpts = struct();
    ratingOpts.modality = modality;
    ratingOpts.stimPath = stimPath;
    ratingOpts.imageW = 500;
    ratingOpts.imageH = 400;
    ratingOpts.autoPlayAudio = true;
    ratingOpts.stimOnTrigger = stimOnTrig;
    ratingOpts.stimOffTrigger = 'STIM_OFF';
    ratingOpts.valScreenTrigger = valScreenTrig;

    [out, params] = mixem.collectRating3x7(params, ratingPng, params.deck, ratingOpts);

    tStimOn = double(out.tStimOn);
    if ~isfinite(tStimOn), tStimOn = double(out.tRatingOn); end
    tStimOff = double(out.tStimOff);
    if ~isfinite(tStimOff), tStimOff = double(out.tEndAbs); end

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
    params = mixem.progressMsg(params, 'TRIAL_DONE', 'phase', 'validation', 'task', 'validation', 'block', double(r.Block), 'trialInBlock', double(r.TrialInBlock), 'ratings', respStr, 'rt_ms', rt_ms);

    params.currTrial = params.currTrial + 1;
    params.lastCompletedSeq = max(double(getfield_with_default(params,'lastCompletedSeq',0)), double(r.Seq));
    mixem.safeSave(params);
end

params = mixem.logMsg(params, "VAL_TASK_END");
params = mixem.progressMsg(params, 'VAL_DONE');

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


function v = getfield_with_default(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = s.(fieldName);
else
    v = defaultValue;
end
end

function d = local_audio_duration_sec(wavPath)
d = NaN;
try
    info = audioinfo(wavPath);
    d = double(info.Duration);
catch
end
end
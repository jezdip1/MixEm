function params = sendTrig(params, trigName, varargin)
% mixem.sendTrig
% - Najde kód podle params.trig
% - Pošle TTL pulse (syncTriggerPulse)
% - Loguje do params.trigLog + textově přes mixem.logMsg
%
% Usage:
%   params = mixem.sendTrig(params,'FIX_ON');
%   params = mixem.sendTrig(params,'STIM_ON_AUD','note',"stimulus onset");

    p = inputParser;
    p.addParameter('note',"",@(s)ischar(s)||isstring(s));
    p.parse(varargin{:});
    note = string(p.Results.note);

    if ~isfield(params,'trig') || isempty(params.trig)
        params.trig = mixem.TriggerCodes();
    end
    if ~isfield(params.trig, trigName)
        error('Unknown trigger name: %s', trigName);
    end

    code = params.trig.(trigName);

    % --- send pulse ---
    [params.sync, tOn, tOff] = mixem.syncTriggerPulse(params.sync, code);

    % --- convert to epoch (best-effort) ---
    eOn = NaN; eOff = NaN;
    if isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
            && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch)
        eOn  = tOn  - params.getsecs_minus_epoch;
        eOff = tOff - params.getsecs_minus_epoch;
    end

    % --- init trigLog (rich) ---
    if ~isfield(params,'trigLog') || isempty(params.trigLog)
        params.trigLog = table('Size',[0 14], ...
            'VariableTypes', {'double','double','double','double','string','double','string', ...
                              'double','double','double','string','string','string','string'}, ...
            'VariableNames', {'WallClockEpoch_On','WallClockEpoch_Off','GetSecs_On','GetSecs_Off', ...
                              'Name','Code','Note', ...
                              'Seq','Block','Trial','Task','Modality','StimPath','Stage'});
    end

    % --- context best-effort ---
    seq = NaN; blk = NaN; trl = NaN;
    task = ""; mod = ""; stim = ""; stage = "";

    if isfield(params,'currentSeq') && ~isempty(params.currentSeq),       seq = double(params.currentSeq); end
    if isfield(params,'currentBlock') && ~isempty(params.currentBlock),   blk = double(params.currentBlock); end
    if isfield(params,'currTrial') && ~isempty(params.currTrial),         trl = double(params.currTrial); end

    if isfield(params,'currentTask') && ~isempty(params.currentTask),         task = string(params.currentTask); end
    if isfield(params,'currentModality') && ~isempty(params.currentModality), mod  = string(params.currentModality); end
    if isfield(params,'currentStimPath') && ~isempty(params.currentStimPath), stim = string(params.currentStimPath); end
    if isfield(params,'debugStage') && ~isempty(params.debugStage),           stage = string(params.debugStage); end

    newRow = {eOn, eOff, tOn, tOff, string(trigName), double(code), note, ...
              seq, blk, trl, task, mod, stim, stage};
    params.trigLog = [params.trigLog; newRow]; %#ok<AGROW>

    % --- text log ---
    params = mixem.logMsg(params, "TRIG", ...
        'Name', string(trigName), 'Code', double(code), 'Note', note);
end
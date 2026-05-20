function params = sendTrig(params, trigName, varargin)
% mixem.sendTrig
% - Finds the logical trigger code by params.trig.(trigName)
% - Sends a MixEm STATE trigger value via syncTriggerSet(), no return-to-zero
% - Guarantees that two identical physical trigger values are not sent in a row
%   by alternating to a reserved physical *_ALT code when needed
% - Logs both logical and physical codes into params.trigLog
%
% Usage:
%   params = mixem.sendTrig(params,'FIX_ON');
%   params = mixem.sendTrig(params,'STIM_ON_AUD','note',"stimulus onset");

    p = inputParser;
    p.addParameter('note',"",@(s)ischar(s)||isstring(s));
    p.parse(varargin{:});
    note = string(p.Results.note);

    trigName = char(string(trigName));

    if ~isfield(params,'trig') || isempty(params.trig)
        params.trig = mixem.TriggerCodes();
    end
    if ~isfield(params,'trigAlt') || isempty(params.trigAlt)
        params.trigAlt = mixem.TriggerAltCodes();
    end
    if ~isfield(params.trig, trigName)
        error('sendTrig:UnknownTriggerName','Unknown trigger name: %s', trigName);
    end
    if ~isfield(params,'sync') || isempty(params.sync)
        params.sync = struct('mode','none','ok',false,'lastCode',[],'enforceUniqueStates',true);
    end

    logicalCode = double(params.trig.(trigName));
    if ~isfinite(logicalCode) || logicalCode < 0 || logicalCode > 255
        error('sendTrig:LogicalCodeOutOfRange','Logical trigger code out of range 0..255: %s=%g', trigName, logicalCode);
    end

    % Physical code starts as the primary logical code.
    physicalCode = logicalCode;
    usedAltCode = false;
    duplicateAvoided = false;

    lastPhysical = local_last_physical_code(params);

    % MixEm state convention: two equal physical values in a row are not
    % observable. If the primary code would repeat, use the alternate code
    % for the same logical event. Repeated identical logical events therefore
    % alternate: primary -> alternate -> primary -> alternate ...
    if isfinite(lastPhysical) && double(lastPhysical) == double(physicalCode)
        if ~isfield(params.trigAlt, trigName)
            error('sendTrig:RepeatedCodeWithoutAlternate', ...
                ['State trigger would repeat physical code %d for %s, but no alternate code exists. ' ...
                 'This would not be detectable in the recording.'], logicalCode, trigName);
        end
        physicalCode = double(params.trigAlt.(trigName));
        usedAltCode = true;
        duplicateAvoided = true;
    end

    if isfinite(lastPhysical) && double(lastPhysical) == double(physicalCode)
        error('sendTrig:RepeatedPhysicalCode', ...
            'Internal trigger coding error: physical code %d would still repeat for %s.', physicalCode, trigName);
    end

    % --- send state trigger ---
    % MixEm convention: trigger values are step/state values, not pulses.
    % The physicalCode remains on the output until the next trigger is sent.
    [params.sync, tOn, tOff] = mixem.syncTriggerSet(params.sync, uint8(physicalCode));

    % Keep a logical guard even when sync.mode='none' or hardware is absent.
    params.lastTrigPhysicalCode = double(physicalCode);
    params.lastTrigLogicalName  = string(trigName);
    params.lastTrigLogicalCode  = double(logicalCode);

    % --- convert to epoch (best-effort) ---
    eOn = NaN; eOff = NaN;
    if isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
            && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch)
        eOn  = tOn  - params.getsecs_minus_epoch;
        eOff = tOff - params.getsecs_minus_epoch;
    end

    % --- init/normalize trigLog schema ---
    params.trigLog = local_ensure_trig_log(params);

    % --- context best-effort ---
    seq = NaN; blk = NaN; trl = NaN; trlInBlock = NaN;
    task = ""; mod = ""; stim = ""; stage = "";

    if isfield(params,'currentSeq') && ~isempty(params.currentSeq),       seq = double(params.currentSeq); end
    if isfield(params,'currentBlock') && ~isempty(params.currentBlock),   blk = double(params.currentBlock); end
    if isfield(params,'currTrial') && ~isempty(params.currTrial),         trl = double(params.currTrial); end
    if isfield(params,'currentTrialInBlock') && ~isempty(params.currentTrialInBlock), trlInBlock = double(params.currentTrialInBlock); end

    if isfield(params,'currentTask') && ~isempty(params.currentTask),         task = string(params.currentTask); end
    if isfield(params,'currentModality') && ~isempty(params.currentModality), mod  = string(params.currentModality); end
    if isfield(params,'currentStimPath') && ~isempty(params.currentStimPath), stim = string(params.currentStimPath); end
    if isfield(params,'debugStage') && ~isempty(params.debugStage),           stage = string(params.debugStage); end

    rowCell = {eOn, eOff, tOn, tOff, string(trigName), double(physicalCode), ...
               double(logicalCode), double(physicalCode), logical(usedAltCode), logical(duplicateAvoided), note, ...
               seq, blk, trl, trlInBlock, task, mod, stim, stage};
    newRow = local_empty_trig_log();
    newRow(1,:) = rowCell;
    params.trigLog = [params.trigLog; newRow]; %#ok<AGROW>

    % --- text log ---
    params = mixem.logMsg(params, "TRIG", ...
        'Name', string(trigName), ...
        'Code', double(physicalCode), ...
        'LogicalCode', double(logicalCode), ...
        'UsedAltCode', double(usedAltCode), ...
        'DuplicateAvoided', double(duplicateAvoided), ...
        'Note', note);
end

% -------------------------------------------------------------------------
function lastPhysical = local_last_physical_code(params)
    lastPhysical = NaN;

    if isfield(params,'lastTrigPhysicalCode') && ~isempty(params.lastTrigPhysicalCode) ...
            && isnumeric(params.lastTrigPhysicalCode) && isfinite(double(params.lastTrigPhysicalCode))
        lastPhysical = double(params.lastTrigPhysicalCode);
        return
    end

    if isfield(params,'sync') && isfield(params.sync,'lastCode') && ~isempty(params.sync.lastCode)
        v = double(params.sync.lastCode);
        if isfinite(v)
            lastPhysical = v;
        end
    end
end

% -------------------------------------------------------------------------
function [names, types] = local_trig_log_schema()
    names = {'WallClockEpoch_On','WallClockEpoch_Off','GetSecs_On','GetSecs_Off', ...
             'Name','Code','LogicalCode','PhysicalCode','UsedAltCode','DuplicateAvoided','Note', ...
             'Seq','Block','Trial','TrialInBlock','Task','Modality','StimPath','Stage'};
    types = {'double','double','double','double','string','double','double','double', ...
             'logical','logical','string','double','double','double','double', ...
             'string','string','string','string'};
end

% -------------------------------------------------------------------------
function T = local_empty_trig_log()
    [names, types] = local_trig_log_schema();
    T = table('Size',[0 numel(names)], ...
        'VariableTypes', types, ...
        'VariableNames', names);
end

% -------------------------------------------------------------------------
function T = local_ensure_trig_log(params)
    desired = local_empty_trig_log();
    [names, types] = local_trig_log_schema();

    if ~isfield(params,'trigLog') || isempty(params.trigLog) || ~istable(params.trigLog)
        T = desired;
        return
    end

    old = params.trigLog;
    oldNames = string(old.Properties.VariableNames);
    newNames = string(names);

    % Already correct schema.
    if numel(oldNames) == numel(newNames) && all(oldNames == newNames)
        T = old;
        return
    end

    % Build a new table with desired schema and copy compatible columns.
    n = height(old);
    T = table('Size',[n numel(names)], ...
        'VariableTypes', types, ...
        'VariableNames', names);

    % Default missing values.
    for j = 1:numel(names)
        nm = names{j};
        typ = types{j};
        switch typ
            case 'string'
                T.(nm) = strings(n,1);
            case 'logical'
                T.(nm) = false(n,1);
            otherwise
                T.(nm) = nan(n,1);
        end
    end

    common = intersect(cellstr(oldNames), cellstr(newNames), 'stable');
    for i = 1:numel(common)
        nm = common{i};
        try
            T.(nm) = old.(nm);
        catch
            % Keep default if a type conversion fails.
        end
    end

    % Backfill new code columns from legacy Code if available.
    if ismember('Code', old.Properties.VariableNames)
        try
            T.PhysicalCode = double(old.Code);
            T.LogicalCode = double(old.Code);
        catch
        end
    end
end

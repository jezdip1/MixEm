function params = logMsg(params, msg, varargin)
% mixem.logMsg
% Ukecaný text log do params.logFID (pokud existuje).
% Přidá timestamp (epoch + GetSecs) + best-effort kontext (seq/block/trial/task/mod/stim).
%
% Usage:
%   params = mixem.logMsg(params, "AUDIO_START", 'File', wavPath, 'tOn', tAudOn);
%   params = mixem.logMsg(params, "TRIAL_START");
%
% Optional kv pairs: ('Key',Value, ...)

    if nargin < 2 || isempty(msg)
        return;
    end

    if ~isfield(params,'logFID') || isempty(params.logFID) || params.logFID < 0
        return; % no-op
    end

    % parse extras
    extra = struct();
    if ~isempty(varargin)
        if mod(numel(varargin),2) ~= 0
            error('mixem.logMsg: optional args must be key/value pairs');
        end
        for i = 1:2:numel(varargin)
            k = char(varargin{i});
            extra.(k) = varargin{i+1};
        end
    end

    try
        tGS = GetSecs;

        tEpoch = NaN;
        if isfield(params,'getsecs_minus_epoch') && ~isempty(params.getsecs_minus_epoch) ...
                && isnumeric(params.getsecs_minus_epoch) && isfinite(params.getsecs_minus_epoch)
            tEpoch = tGS - params.getsecs_minus_epoch;
        end

        if isfinite(tEpoch)
            stamp = char(datetime(tEpoch,'ConvertFrom','posixtime','Format','yyyy-MM-dd HH:mm:ss.SSS'));
            prefix = sprintf('[%s] (epoch=%.6f getsecs=%.6f)', stamp, tEpoch, tGS);
        else
            prefix = sprintf('[getsecs=%.6f]', tGS);
        end

        % best-effort context
        ctx = "";
        if isfield(params,'subjID') && ~isempty(params.subjID),         ctx = ctx + " subj=" + string(params.subjID); end
        if isfield(params,'sessionID') && ~isempty(params.sessionID),   ctx = ctx + " session=" + string(params.sessionID); end
        if isfield(params,'currentSeq') && ~isempty(params.currentSeq), ctx = ctx + " seq=" + string(params.currentSeq); end
        if isfield(params,'currentBlock') && ~isempty(params.currentBlock), ctx = ctx + " block=" + string(params.currentBlock); end
        if isfield(params,'currTrial') && ~isempty(params.currTrial),   ctx = ctx + " trial=" + string(params.currTrial); end
        if isfield(params,'currentTrialInBlock') && ~isempty(params.currentTrialInBlock)
            ctx = ctx + " tinb=" + string(params.currentTrialInBlock);
        end
        if isfield(params,'currentTask') && ~isempty(params.currentTask), ctx = ctx + " task=" + string(params.currentTask); end
        if isfield(params,'currentModality') && ~isempty(params.currentModality), ctx = ctx + " mod=" + string(params.currentModality); end
        if isfield(params,'currentStimPath') && ~isempty(params.currentStimPath), ctx = ctx + " stim=""" + string(params.currentStimPath) + """";
        end

        % extras to string
        extrastr = "";
        f = fieldnames(extra);
        for i = 1:numel(f)
            key = string(f{i});
            v = extra.(f{i});
            if isstring(v) || ischar(v)
                extrastr = extrastr + " " + key + "=""" + string(v) + """";
            elseif isnumeric(v) && isscalar(v)
                extrastr = extrastr + " " + key + "=" + string(v);
            else
                try
                    extrastr = extrastr + " " + key + "=" + string(mat2str(v));
                catch
                    extrastr = extrastr + " " + key + "=[unprintable]";
                end
            end
        end

        fprintf(params.logFID, '%s%s %s%s\n', prefix, char(ctx), char(string(msg)), char(extrastr));
    catch
        % never crash experiment due to logging
    end
end
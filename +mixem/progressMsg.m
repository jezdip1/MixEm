function params = progressMsg(params, eventName, varargin)
% PROGRESSMSG  Lightweight console progress for long MixEm runs.
% Prints only outside the time-critical stimulus presentation path.
% Disable with environment variable: MIXEM_PROGRESS=0

if nargin < 2 || isempty(eventName)
    eventName = "PROGRESS";
end

enabled = true;
if isfield(params,'progressConsole') && ~isempty(params.progressConsole)
    enabled = logical(params.progressConsole);
end

env = getenv('MIXEM_PROGRESS');
if ~isempty(env)
    enabled = ~any(strcmpi(strtrim(env), {'0','false','off','no'}));
end

if ~enabled
    return
end

try
    wall = char(datetime('now','Format','HH:mm:ss'));
catch
    wall = datestr(now,'HH:MM:SS');
end

elapsedStr = '';
try
    if isfield(params,'tExpStartAbs') && ~isempty(params.tExpStartAbs) && isnumeric(params.tExpStartAbs)
        elapsedMin = (GetSecs - double(params.tExpStartAbs)) / 60;
        if isfinite(elapsedMin)
            elapsedStr = sprintf(' +%.1fmin', elapsedMin);
        end
    end
catch
end

[nDone, nTotal] = local_trial_progress(params, eventName);
trialStr = '';
if isfinite(nDone) && isfinite(nTotal) && nTotal > 0
    trialStr = sprintf(' [%d/%d trials]', nDone, nTotal);
end

kvStr = local_format_kv(varargin{:});
if isempty(kvStr)
    msg = sprintf('[%s%s] MixEm %-14s%s', wall, elapsedStr, char(string(eventName)), trialStr);
else
    msg = sprintf('[%s%s] MixEm %-14s%s | %s', wall, elapsedStr, char(string(eventName)), trialStr, kvStr);
end

fprintf(1, '%s\n', msg);
try, drawnow('limitrate'); catch, try, drawnow; catch, end, end

% Also mirror progress to the text log when available. This makes it easy to
% reconstruct where a long run spent time even when the MATLAB console scrolls.
try
    if isfield(params,'logFID') && ~isempty(params.logFID) && params.logFID > 0
        fprintf(params.logFID, '[PROGRESS] %s\n', msg);
    end
catch
end
end

function [nDone, nTotal] = local_trial_progress(params, eventName)
nDone = NaN;
nTotal = NaN;

try
    if isfield(params,'resultsTable') && ~isempty(params.resultsTable)
        nDone = height(params.resultsTable);
    else
        nDone = 0;
    end

    ev = upper(char(string(eventName)));
    if contains(ev,'TRIAL_START') || strcmp(ev,'TRIAL')
        nDone = nDone + 1;
    end
catch
    nDone = NaN;
end

try
    if isfield(params,'masterSchedule') && ~isempty(params.masterSchedule) && istable(params.masterSchedule)
        ms = params.masterSchedule;
        events = cellfun(@local_cellchar, table2cell(ms(:, 'Event')), 'UniformOutput', false);
        nTotal = sum(strcmp(events, 'trial'));
    end
catch
    nTotal = NaN;
end
end

function s = local_format_kv(varargin)
parts = {};
if mod(numel(varargin),2) ~= 0
    varargin = varargin(1:end-1);
end
for i = 1:2:numel(varargin)
    key = char(string(varargin{i}));
    val = varargin{i+1};
    parts{end+1} = sprintf('%s=%s', key, local_val_to_str(key, val)); %#ok<AGROW>
end
s = strjoin(parts, ' ');
end

function s = local_val_to_str(key, val)
try
    if isstring(val)
        if isscalar(val), s = char(val); else, s = char(strjoin(val, ',')); end
    elseif ischar(val)
        s = val;
    elseif isnumeric(val) || islogical(val)
        if isscalar(val)
            if isnan(double(val))
                s = 'NaN';
            elseif abs(double(val) - round(double(val))) < eps(max(abs(double(val)),1))
                s = sprintf('%d', round(double(val)));
            else
                s = sprintf('%.3g', double(val));
            end
        else
            s = mat2str(val);
        end
    elseif iscell(val)
        if isempty(val), s = ''; else, s = local_val_to_str(key, val{1}); end
    else
        s = char(string(val));
    end
catch
    s = '<unprintable>';
end

% Keep console lines readable: show only basename for stimulus paths.
if any(strcmpi(key, {'stim','Stim','StimPath','file','File','png','PNG'}))
    try
        [~,nm,ext] = fileparts(s);
        if ~isempty(nm)
            s = [nm ext];
        end
    catch
    end
end

maxLen = 80;
if numel(s) > maxLen
    s = [s(1:maxLen-3) '...'];
end
end

function s = local_cellchar(v)
if iscell(v)
    if isempty(v) || isempty(v{1})
        s = '';
    else
        s = char(v{1});
    end
elseif isstring(v)
    if isempty(v), s = ''; else, s = char(v(1)); end
else
    s = char(v);
end
end

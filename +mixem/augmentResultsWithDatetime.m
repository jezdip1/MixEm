function params = augmentResultsWithDatetime(params)
% Add human-readable wall-clock columns derived from ABS GetSecs columns.

if ~isfield(params,'resultsTable') || ~istable(params.resultsTable)
    return
end
T = params.resultsTable;

if ~isfield(params,'getsecs_minus_epoch') || ~isfinite(params.getsecs_minus_epoch)
    warning('augmentResultsWithDatetime:NoBridge','Missing getsecs_minus_epoch; cannot convert to datetime.');
    return
end

cols = ["OnsetFix","OnsetStim","OffsetStim","OnsetPrompt1","OnsetPrompt2","OnsetRating","TrialEnd"];

for c = cols
    if ~ismember(c, string(T.Properties.VariableNames)), continue; end

    tAbs = T.(c);                        % GetSecs absolute
    epoch = tAbs - params.getsecs_minus_epoch;

    % keep NaNs as NaT
    dt = repmat(datetime(NaN, 'ConvertFrom','posixtime'), size(epoch));
    ok = isfinite(epoch);
    dt(ok) = datetime(epoch(ok), 'ConvertFrom','posixtime');

    epochName = c + "_epoch";
    dtName    = c + "_dt";

    % only add if not already present
    if ~ismember(epochName, string(T.Properties.VariableNames))
        T.(epochName) = epoch;
    end
    if ~ismember(dtName, string(T.Properties.VariableNames))
        T.(dtName) = dt;
    end
end

params.resultsTable = T;
end
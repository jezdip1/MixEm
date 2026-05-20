function ALT = TriggerAltCodes()
% mixem.TriggerAltCodes
% Alternate physical codes for MixEm STATE triggers.
%
% Why this exists:
%   MixEm uses step/state trigger values, not pulses. Therefore two identical
%   physical values in a row would not create a detectable transition in the
%   EEG/iEEG recording. sendTrig() normally sends the primary code from
%   TriggerCodes(); if that primary code would equal the previous physical
%   output value, sendTrig() sends the alternate physical code from this map
%   instead. Both primary and alternate codes decode to the same logical event.
%
% The mapping is deterministic and excludes all primary trigger values and 0.

    TC = mixem.TriggerCodes();
    ver = string(TC.Version);

    fn = fieldnames(TC);
    fn = fn(~strcmp(fn,'Version'));

    % Keep only numeric scalar trigger fields.
    keep = false(size(fn));
    primaryCodes = nan(size(fn));
    for i = 1:numel(fn)
        v = TC.(fn{i});
        keep(i) = isnumeric(v) && isscalar(v) && isfinite(double(v));
        if keep(i), primaryCodes(i) = double(v); end
    end
    names = sort(fn(keep));
    primaryCodes = primaryCodes(keep);

    % Prefer a compact high range for alternate codes, then use unused gaps.
    pool = uint16([201:239, 24:39, 42:49, 53:59, 64:69, 71:79, 81:89, ...
                   94:99, 106:109, 112:129, 132:139, 142:149, 153:159, ...
                   161:199, 241:255]);
    reserved = uint16([0, primaryCodes(:)']);
    pool = setdiff(pool, reserved, 'stable');

    if numel(pool) < numel(names)
        error('TriggerAltCodes:NoCodeSpace', ...
            'Not enough free physical trigger codes for alternate state coding. Need %d, have %d.', ...
            numel(names), numel(pool));
    end

    ALT = struct();
    ALT.Version = ver + "_ALT";
    for i = 1:numel(names)
        ALT.(names{i}) = uint8(pool(i));
    end

    % Validate alternate codes are unique and do not collide with primaries.
    altCodes = zeros(numel(names),1);
    for i = 1:numel(names)
        altCodes(i) = double(ALT.(names{i}));
    end
    if numel(unique(altCodes)) ~= numel(altCodes)
        error('TriggerAltCodes:DuplicateAlternateCodes','Duplicate alternate trigger codes generated.');
    end
    if any(ismember(altCodes, primaryCodes)) || any(altCodes == 0)
        error('TriggerAltCodes:CodeCollision','Alternate trigger codes collide with primary codes or zero.');
    end
end

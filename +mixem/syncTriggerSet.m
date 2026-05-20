function [sync, tSet, tClear] = syncTriggerSet(sync, code)
% mixem.syncTriggerSet
% State trigger for MixEm: sets the physical output to CODE and leaves it.
%
% Important:
%   This is NOT a TTL pulse. The function DOES NOT return the output to zero.
%   The value remains on the parallel/serial output until the next trigger is sent.
%
% Logging behavior:
%   tSet is always a GetSecs timestamp, even when sync.mode='none' or no
%   hardware is available. In no-hardware mode this is a dry-run software
%   timestamp, useful for debugging and trigLog completeness. With real
%   hardware, tSet is sampled immediately before the physical write.
%
% Safety:
%   If sync.enforceUniqueStates is true, the same physical CODE cannot be
%   written twice in a row. sendTrig() should normally prevent this by using
%   alternate physical codes for repeated logical events.
%
% Outputs:
%   tSet   ... GetSecs time of state write / dry-run state set
%   tClear ... always NaN; kept for compatibility with *_Off trigLog columns

    tSet   = NaN;
    tClear = NaN;

    c = double(code);
    if ~isfinite(c) || c < 0 || c > 255
        error('syncTriggerSet:CodeOutOfRange','Trigger code out of range 0..255: %g', c);
    end
    c8 = uint8(c);

    if isempty(sync) || ~isstruct(sync)
        tSet = GetSecs;
        return;
    end

    enforce = true;
    if isfield(sync,'enforceUniqueStates') && ~isempty(sync.enforceUniqueStates)
        enforce = logical(sync.enforceUniqueStates);
    end
    if enforce && isfield(sync,'lastCode') && ~isempty(sync.lastCode) && double(sync.lastCode) == double(c8)
        error('syncTriggerSet:RepeatedPhysicalCode', ...
            ['Refusing to write physical trigger code %d twice in a row. ' ...
             'Use mixem.sendTrig(), which can alternate duplicate logical events to *_ALT codes.'], double(c8));
    end

    % No hardware / disabled sync: still record a software timestamp and keep
    % lastCode so dry-run tests exercise the same state-transition logic.
    if ~isfield(sync,'ok') || ~sync.ok
        tSet = GetSecs;
        sync.lastCode = c8;
        return;
    end

    switch lower(string(sync.mode))
        case "parallel"
            tSet = GetSecs;
            mixem.pp_write(sync, c8);

        case "serial"
            if isempty(sync.serial) || ~isvalid(sync.serial)
                tSet = GetSecs;
                sync.lastCode = c8;
                return;
            end
            tSet = GetSecs;
            write(sync.serial, c8, "uint8");

        otherwise
            tSet = GetSecs;
    end

    sync.lastCode = c8;
end

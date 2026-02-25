function [sync, tOn, tOff] = syncTriggerPulse(sync, code)
% mixem.syncTriggerPulse
% Atomický TTL pulse: nastav code, počkej pulseWidth, vrať na 0, pak gap.

    tOn  = NaN;
    tOff = NaN;

    if isempty(sync) || ~isfield(sync,'ok') || ~sync.ok
        return;
    end

    c = double(code);
    if ~isfinite(c) || c < 0 || c > 255
        error('Trigger code out of range 0..255: %g', c);
    end
    c8 = uint8(c);

    switch lower(string(sync.mode))
        case "parallel"
            tOn = GetSecs;
            mixem.pp_write(sync, c8);
            WaitSecs(sync.pulseWidth);
            mixem.pp_write(sync, uint8(0));
            tOff = GetSecs;

        case "serial"
            if isempty(sync.serial) || ~isvalid(sync.serial)
                return;
            end
            tOn = GetSecs;
            write(sync.serial, c8, "uint8");
            WaitSecs(sync.pulseWidth);
            write(sync.serial, uint8(0), "uint8");
            tOff = GetSecs;

        otherwise
            return;
    end

    sync.lastCode = c8;

    if isfield(sync,'interPulseGap') && sync.interPulseGap > 0
        WaitSecs(sync.interPulseGap);
    end
end
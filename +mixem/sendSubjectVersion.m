function params = sendSubjectVersion(params)
% mixem.sendSubjectVersion
% - V serial mode pošle ASCII "VER:..." (pro Pico/krabičku, pokud to umíte zpracovat)
% - Vždy pošle TTL marker SUBJECT_VERSION_SENT (jednoznačné místo pro epoching)
% - Uloží version string do params

    if ~isfield(params,'trig') || isempty(params.trig)
        params.trig = mixem.TriggerCodes();
    end
    ver = string(params.trig.Version);
    params.trigVersion = ver;

    % serial ASCII (pokud chceš)
    try
        if isfield(params,'sync') && isfield(params.sync,'mode') && strcmpi(string(params.sync.mode),'serial') ...
                && isfield(params.sync,'serial') && ~isempty(params.sync.serial) && isvalid(params.sync.serial)
            msg = uint8(char("VER:" + ver + newline));
            write(params.sync.serial, msg, "uint8");
        end
    catch
        % nevadí; TTL marker bude vždy
    end

    % TTL marker
    params = mixem.sendTrig(params, 'SUBJECT_VERSION_SENT', 'note', ver);
end
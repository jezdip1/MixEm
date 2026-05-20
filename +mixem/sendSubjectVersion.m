function params = sendSubjectVersion(params)
% mixem.sendSubjectVersion
% Log/send a subject-version marker without injecting unlogged bytes.
%
% Earlier versions optionally wrote an ASCII "VER:..." string on the serial
% trigger line. In MixEm state-trigger mode every byte on that line is a
% physical trigger value, so raw ASCII would create unlogged state changes.
% Therefore the default is now: store the version in params/logs and send only
% the single logical marker SUBJECT_VERSION_SENT.

    if ~isfield(params,'trig') || isempty(params.trig)
        params.trig = mixem.TriggerCodes();
    end
    ver = string(params.trig.Version);
    params.trigVersion = ver;

    try
        params = mixem.logMsg(params, "TRIG_VERSION", 'Version', ver);
    catch
    end

    params = mixem.sendTrig(params, 'SUBJECT_VERSION_SENT', 'note', ver);
end

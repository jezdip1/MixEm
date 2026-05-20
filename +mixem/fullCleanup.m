function fullCleanup(params)
% FULLCLEANUP  Best-effort cleanup všech zařízení (PTB, audio, sync, deck).

try
    % StreamDeck
    if isfield(params,'deck')
        mixem.streamdeck_close(params.deck);
    end
catch
end

try
    % Close the sync device handle if possible. Do not implicitly write zero:
    % MixEm uses state/step trigger values, not pulses with automatic reset.
    if isfield(params,'sync')
        try, mixem.closeSyncDevice(params.sync); catch, end
    end
catch
end

try
    % Optional room audio back-recording object
    if isfield(params,'audioReader') && ~isempty(params.audioReader)
        try, release(params.audioReader); catch, end
        try, delete(params.audioReader); catch, end
    end
catch
end

try
    % Audio
    PsychPortAudio('Close');
catch
end

try
    % PTB window
    sca;
    Priority(0);
    ShowCursor;
catch
end

try
    if isfield(params,'logFID') && ~isempty(params.logFID) && params.logFID > 0
        try, fclose(params.logFID); catch, end
    end
catch
end

try
    % ppdev mex close
    if exist('ppdev_mex','file')
        ppdev_mex('CloseAll');
    end
catch
end
end

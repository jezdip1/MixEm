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
    % Sync trigger off
    if isfield(params,'sync')
        mixem.syncTriggerOff(params.sync);
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
    % ppdev mex close
    if exist('ppdev_mex','file')
        ppdev_mex('CloseAll');
    end
catch
end
end

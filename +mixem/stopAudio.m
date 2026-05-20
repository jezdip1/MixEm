function stopAudio(params)
% STOPAUDIO  Stop current PsychPortAudio playback immediately.
try
    % waitForEndOfPlayback = 0 is essential here: using 1 waits until the
    % sound finishes naturally, which made tones/stimuli continue after a
    % response and could overlap with following trials.
    PsychPortAudio('Stop', params.pahandle, 0);
catch
end
end

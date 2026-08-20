function tAudOnAbs = startPreparedAudio(params)
% STARTPREPAREDAUDIO  Start the buffer previously filled by prepareAudioFile.
% Returns PsychPortAudio's absolute GetSecs onset estimate.

tAudOnAbs = NaN;
try
    tAudOnAbs = PsychPortAudio('Start', params.pahandle, 1, 0, 1);
catch ME
    warning('startPreparedAudio:StartFailed','PsychPortAudio start failed: %s', ME.message);
end
end

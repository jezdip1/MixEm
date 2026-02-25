function stopAudio(params)
try
    PsychPortAudio('Stop', params.pahandle, 1); % immediate stop
catch
end
end

function tAudOnAbs = playAudioFile(params, wavPath)
% Play audio and return absolute onset time (GetSecs) if requested.
% Backward compatible: callers ignoring output still work.
%
% IMPORTANT:
% Uses PsychPortAudio('Start', ..., waitForStart=1) to obtain a precise start time.

tAudOnAbs = NaN;

try
    PsychPortAudio('Stop', params.pahandle, 0);
catch
end

if exist(wavPath,'file') ~= 2
    warning('playAudioFile:MissingFile','Missing audio file: %s', wavPath);
    return
end

[y, fs] = audioread(wavPath);
if fs ~= params.samplerate
    y = resample(y, params.samplerate, fs);
end
if size(y,2)==1, y = [y y]; end % stereo

PsychPortAudio('FillBuffer', params.pahandle, y');

% Start immediately, waitForStart=1 returns precise start time
try
    tAudOnAbs = PsychPortAudio('Start', params.pahandle, 1, 0, 1);
catch ME
    warning('playAudioFile:StartFailed','PsychPortAudio start failed: %s', ME.message);
    tAudOnAbs = NaN;
end
end
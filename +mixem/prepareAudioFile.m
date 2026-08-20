function [ok, preparedDurationSec] = prepareAudioFile(params, wavPath, varargin)
% PREPAREAUDIOFILE  Load/resample/shape audio and fill PsychPortAudio buffer.
%
% [ok, preparedDurationSec] = mixem.prepareAudioFile(params, wavPath, ...)
%
% Optional name/value arguments:
%   'MaxDurationSec'  []     truncate playback buffer to this duration
%   'FadeOutSec'      0      half-cosine fade at the prepared buffer endpoint
%
% This function does NOT start playback. Keeping file IO, resampling and
% FillBuffer outside the trigger-to-audio critical path avoids a large and
% variable delay between STIM_ON_AUD and actual PsychPortAudio onset.

ok = false;
preparedDurationSec = NaN;

ip = inputParser;
ip.addParameter('MaxDurationSec', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
ip.addParameter('FadeOutSec', 0, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
ip.parse(varargin{:});
maxDurationSec = ip.Results.MaxDurationSec;
fadeOutSec = double(ip.Results.FadeOutSec);

if ~isfield(params,'pahandle') || isempty(params.pahandle)
    warning('prepareAudioFile:NoHandle','Missing PsychPortAudio handle.');
    return
end
if exist(wavPath,'file') ~= 2
    warning('prepareAudioFile:MissingFile','Missing audio file: %s', wavPath);
    return
end

% FillBuffer is only safe/reproducible with the previous playback stopped.
try, PsychPortAudio('Stop', params.pahandle, 0, 1); catch, end

[y, fs] = audioread(wavPath);
if fs ~= params.samplerate
    y = resample(y, params.samplerate, fs);
    fs = params.samplerate;
end

if ~isempty(maxDurationSec)
    nTarget = min(size(y,1), max(1, round(double(maxDurationSec) * fs)));
    y = y(1:nTarget,:);
    if fadeOutSec > 0
        nFade = min(size(y,1), max(2, round(fadeOutSec * fs)));
        phase = linspace(0, pi, nFade)';
        gain = 0.5 * (1 + cos(phase));   % 1 -> 0 half-cosine
        y(end-nFade+1:end,:) = y(end-nFade+1:end,:) .* gain;
    end
end

if size(y,2)==1, y = [y y]; end
PsychPortAudio('FillBuffer', params.pahandle, y');

preparedDurationSec = size(y,1) / double(fs);
ok = true;
end

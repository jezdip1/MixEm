function tAudOnAbs = playAudioFile(params, wavPath, varargin)
% PLAYAUDIOFILE  Compatibility helper: prepare then start an audio file.
%
% For timing-critical experiment trials prefer the explicit sequence:
%   mixem.prepareAudioFile(...);   % before fixation / before trigger
%   params = mixem.sendTrig(...);  % trigger close to audio start
%   tAudOn = mixem.startPreparedAudio(params);
%
% Optional name/value arguments are forwarded to prepareAudioFile:
%   'MaxDurationSec'  []
%   'FadeOutSec'      0

tAudOnAbs = NaN;

% Compatibility/demo calls may request a new sound while another one is
% still playing. Fade the old sound briefly instead of replacing its buffer
% with an abrupt stop at an arbitrary waveform phase. Timing-critical trial
% code uses prepareAudioFile/startPreparedAudio directly and is unaffected.
try, mixem.stopAudio(params, 0.050); catch, end

[ok, ~] = mixem.prepareAudioFile(params, wavPath, varargin{:});
if ~ok
    return
end
tAudOnAbs = mixem.startPreparedAudio(params);
end

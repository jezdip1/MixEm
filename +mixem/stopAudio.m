function tStopAbs = stopAudio(params, fadeOutSec)
% STOPAUDIO  Stop current PsychPortAudio playback.
%
% tStopAbs = mixem.stopAudio(params)
% tStopAbs = mixem.stopAudio(params, 0.050)
%
% With fadeOutSec > 0, an ACTIVE playback is attenuated with a short
% half-cosine master-volume ramp before stopping. This is intended for an
% early participant response to a control tone: the fade starts immediately
% after the response instead of cutting a sine wave at an arbitrary phase.
%
% If playback already ended naturally (e.g. a control buffer that was
% pre-truncated and faded to its planned timeout), no extra fade/wait is added.

if nargin < 2 || isempty(fadeOutSec)
    fadeOutSec = 0;
end
fadeOutSec = max(0, double(fadeOutSec));
tStopAbs = NaN;

if ~isfield(params,'pahandle') || isempty(params.pahandle)
    return
end
pah = params.pahandle;

active = true;
try
    st = PsychPortAudio('GetStatus', pah);
    if isfield(st,'Active')
        active = logical(st.Active);
    end
catch
end

restoreVolume = [];
if fadeOutSec > 0 && active
    try
        restoreVolume = PsychPortAudio('Volume', pah);
        if isempty(restoreVolume) || ~isfinite(restoreVolume)
            restoreVolume = 1;
        end

        nSteps = max(8, round(fadeOutSec / 0.0025));
        t0 = GetSecs;
        for k = 1:nSteps
            phase = pi * (double(k) / double(nSteps));
            gain = 0.5 * (1 + cos(phase));   % near 1 -> 0
            PsychPortAudio('Volume', pah, restoreVolume * gain);
            WaitSecs('UntilTime', t0 + fadeOutSec * (double(k) / double(nSteps)));
        end
        PsychPortAudio('Volume', pah, 0);
    catch
        % If volume control/ramping is unavailable, fall back to a normal
        % immediate stop below rather than risking a stuck audio stream.
    end
end

try
    [~,~,~,estStopTime] = PsychPortAudio('Stop', pah, 0, 1);
    if ~isempty(estStopTime) && isfinite(estStopTime)
        tStopAbs = double(estStopTime);
    else
        tStopAbs = GetSecs;
    end
catch
    try, PsychPortAudio('Stop', pah, 0); catch, end
    tStopAbs = GetSecs;
end

% A fade must never leak into the next sound. Restore the previous master
% volume only after playback has stopped.
if ~isempty(restoreVolume)
    try, PsychPortAudio('Volume', pah, restoreVolume); catch, end
end
end

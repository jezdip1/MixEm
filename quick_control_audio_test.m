function quick_control_audio_test()
% QUICK_CONTROL_AUDIO_TEST  Short listening smoke test for control-tone fades.
%
% Run from MixEm repository root on the W540:
%   quick_control_audio_test
%
% No PTB window and no triggers are used. The test plays each low/mid/high
% control tone once with a planned truncated duration and then demonstrates
% an early-response 50 ms runtime fade. Listen specifically for clicks.

baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir, '-begin');
rehash;

PsychDefaultSetup(2);
InitializePsychSound(1);

params = struct();
params.stimDir = fullfile(baseDir,'Stimuli');
params.samplerate = 44100;
params.pahandle = PsychPortAudio('Open', [], 1, 0, params.samplerate, 2);
cleanupObj = onCleanup(@() local_cleanup(params.pahandle)); %#ok<NASGU>

folder = fullfile(params.stimDir,'control_stimuli');
files = { ...
    local_first(fullfile(folder,'control_tone_low_*.wav')), ...
    local_first(fullfile(folder,'control_tone_mid_*.wav')), ...
    local_first(fullfile(folder,'control_tone_high_*.wav')) ...
};
labels = {'LOW','MID','HIGH'};
planned = [0.65, 1.20, 2.40];

for i = 1:3
    if isempty(files{i})
        error('quick_control_audio_test:MissingTone','Missing %s control tone.', labels{i});
    end
    fprintf('Timeout fade test %s: %.0f ms\n', labels{i}, 1000*planned(i));
    mixem.playAudioFile(params, files{i}, 'MaxDurationSec', planned(i), 'FadeOutSec', 0.050);
    WaitSecs(planned(i) + 0.20);
end

fprintf('Early-response fade test MID: start 2.0 s buffer, fade/stop after 0.70 s\n');
mixem.playAudioFile(params, files{2}, 'MaxDurationSec', 2.0, 'FadeOutSec', 0.050);
WaitSecs(0.70);
mixem.stopAudio(params, 0.050);
WaitSecs(0.20);

fprintf('\nPASS if all four endings were smooth/no-click.\n');
fprintf('If a click is still audible, do not commit the audio patch; report which test clicked.\n');
end

function p = local_first(pattern)
D = dir(pattern);
p = '';
if isempty(D), return; end
[~,ix] = sort({D.name});
d = D(ix(1));
p = fullfile(d.folder,d.name);
end

function local_cleanup(pah)
try, PsychPortAudio('Stop', pah, 0, 1); catch, end
try, PsychPortAudio('Close', pah); catch, end
end

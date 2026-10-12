function reader = microphone(c)
% MusEm requires this recorder; MixEm retains its existing optional recorder.
assert(exist('audioDeviceReader', 'file') ~= 0, ...
    'audioDeviceReader unavailable. Check Audio Toolbox on this MATLAB installation.');
args = {'SampleRate',44100,'NumChannels',1,'SamplesPerFrame',512};
if ~isempty(c.mic), args = [{'Device',c.mic}, args]; end
reader = audioDeviceReader(args{:});
fprintf('Microphone: %s\n', reader.Device);
end

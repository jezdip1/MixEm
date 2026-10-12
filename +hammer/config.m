function c = config(paradigm, root)
% Machine settings live outside the versioned experiment.
c.paradigm = paradigm;
c.root = root;
c.stimuli = getenv('HAMMER_STIMULI_ROOT');
if isempty(c.stimuli), c.stimuli = fullfile(root, 'Stimuli'); end
c.results = getenv('HAMMER_RESULTS_ROOT');
if isempty(c.results), c.results = fullfile(root, 'Results'); end
c.port = strtrim(getenv('HAMMER_TRIGGER_PORT'));
c.baud = hammer.number('HAMMER_TRIGGER_BAUD', 115200);
c.screen = hammer.number('HAMMER_SCREEN_NUMBER', []);
c.audio = hammer.number('HAMMER_AUDIO_DEVICE', []);
c.skipSync = hammer.number('HAMMER_SKIP_SYNC_TESTS', 0);
assert(ismember(c.skipSync, [0 1]), 'HAMMER_SKIP_SYNC_TESTS must be 0 or 1.');
c.mic = getenv('HAMMER_MIC_DEVICE');
c.python = getenv('HAMMER_PYTHON');
c.managed = strcmp(getenv('HAMMER_MANAGED'), '1');
c.Runtime = jsondecode(fileread(fullfile(root, 'DEPLOYMENT.json')));
c.Runtime.git_commit = getenv('HAMMER_GIT_COMMIT');
c.Runtime.assets_manifest_sha256 = getenv('HAMMER_ASSETS_SHA256');
c.Runtime.results_root = c.results;
c.Runtime.stimuli_root = c.stimuli;
c.Runtime.trigger_port = c.port;
c.Runtime.matlab = version;
c.Runtime.started_local = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z'));
end

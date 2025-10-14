function master = ensure_schedule(PID, scope, stimRoot, cfg)
% scope: 'all_phases' (MixEm) — vytvoří master tabulku se všemi fázemi
% Struktura: Phase, Set, Modality, SocRel, StimulusPath, Block, TrialIndex, Done, ...

idxCsv = fullfile(stimRoot,'index','stimuli_master_index.csv');
if ~exist(idxCsv,'file')
    error('Missing stimuli index: %s. Run Code/tools/buildStimuliIndex first.', idxCsv);
end
T = utils.loadStimuliTable(idxCsv);

% Split sets
Tmain = T(strcmpi(T.set,'main'),:);
Tsupp = T(strcmpi(T.set,'supp'),:);
Tctl  = T(strcmpi(T.set,'control'),:);

% Randomize within sets once per subject
rng('shuffle');
ord_main = randperm(height(Tmain))';
ord_supp = randperm(height(Tsupp))';
% main2 reuses main set, but different order
ord_main2 = randperm(height(Tmain))';

% Build phase tables
m1 = phaseTable('main1', Tmain(ord_main,:), cfg);
su = phaseTable('supplemental', Tsupp(ord_supp,:), cfg);
m2 = phaseTable('main2', Tmain(ord_main2,:), cfg);
va = validationTable('validation', Tmain, Tsupp, cfg);

% Concat master
master = [m1; su; m2; va];

% Helper: write initial Done=false
master.Done = false(height(master),1);
master.Resp = strings(height(master),1);
master.RTms = nan(height(master),1);
master.Onset = strings(height(master),1);
master.Offset= strings(height(master),1);

end

function P = phaseTable(phaseName, TT, cfg)
% annotate blocks and trials (4 blocks per phase)
N = height(TT); blocks = 4; edges = round(linspace(1,N+1,blocks+1));
Phase   = repmat(string(phaseName), N, 1);
Set     = TT.set; Modality=TT.modality; SocRel=TT.soc_rel; StimulusPath=TT.path; Valence=TT.valence_cluster;
Block = zeros(N,1); TrialIndex=zeros(N,1);
for b=1:blocks
    rows = edges(b):edges(b+1)-1;
    Block(rows) = b;
    TrialIndex(rows) = (1:numel(rows))';
end
P = table(Phase, Set, Modality, SocRel, StimulusPath, Valence, Block, TrialIndex);
end

function V = validationTable(~, Tmain, Tsupp, cfg)
% Take up to 32 main + 36 supp for validation; shuffle
nM = min(32, height(Tmain)); nS = min(36, height(Tsupp));
idx = [randperm(height(Tmain), nM), height(Tmain)+randperm(height(Tsupp), nS)];
TT = [Tmain; Tsupp]; TT = TT(idx,:);
V = phaseTable('validation', TT, cfg);
end

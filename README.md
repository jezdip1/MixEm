# MixEm — MusEm‑style (MATLAB/Psychtoolbox)

Entry point: `Code/runExperiment.m`

How to run:
1) Put stimuli into `Stimuli/*` and build the index:
   ```matlab
   Code/tools/buildStimuliIndex
   ```
2) Start the experiment:
   ```matlab
   runExperiment
   ```
Resuming an interrupted session: run `runExperiment`, choose Continue.

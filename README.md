%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% File: README.md
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# MixEm (MATLAB/Psychtoolbox)


**One entry point:** `runExperiment.m`.


## Install
- MATLAB R2021b+ (recommended) with Psychtoolbox.
- Optional: `ppdev-mex` for hardware sync.
- Place stimulus folders under `Stimuli/` and PNG UI assets under `PNG/` (see tree).
- Put `data/mixem_reunified_stimuli_19_9_2025.xlsx` into `data/`.


## Run
```matlab
>> runExperiment
```


## Resume
- The file `Results/<SubjID>.mat` stores `params.masterSchedule`, `params.resultsTable`, and `params.currTrial`.
- If execution is interrupted, re-run and choose **Continue** to resume exactly where it stopped.


## Notes
- Main task: 12 blocks (1–4, 9–12 are matched selections; 5–8 supplemental).
- Each main/control block is preceded by a PNG screen with instructions as per design.
- Validation comprises two blocks (groups 1 and 6) with three 1–7 ratings per trial.


## Extending
- Wire `mixem.initSyncDevice`, `mixem.syncTriggerOff`, and `mixem.sendSubjectVersion` to your trigger hardware.
- Add joystick/gamepad handling in `mixem.collectKey` if needed.
- If your workbook uses different column names, adjust `+mixem/buildScheduleMixEm.m` mappings.
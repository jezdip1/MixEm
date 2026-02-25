params = struct;
params.subjID   = 'test';
params.stimDir  = fullfile(pwd,'Stimuli');
params.stimXlsx = fullfile(pwd,'data','mixem_reunified_stimuli_19_9_2025.xlsx');
params.idNum    = mixem.rngFromSubjID(params.subjID);

MS = mixem.buildScheduleMixEm(params);
size(MS), MS(1:8,:)  % rychlý náhled
MS.Properties.VariableNames   % zkontroluj, zda SR/CorrectCat jsou přidané/odebrané podle XLS

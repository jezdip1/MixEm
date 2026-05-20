function [sync, tOn, tOff] = syncTriggerPulse(sync, code)
% mixem.syncTriggerPulse
% Backward-compatible wrapper.
%
% Historical versions used this function name for code -> short pulse -> 0.
% MixEm W540 patch v4 intentionally changes the semantics to a STATE trigger:
% write CODE and keep that value until the next trigger code is written.
% There is no automatic return to zero.

    [sync, tOn, tOff] = mixem.syncTriggerSet(sync, code);
end

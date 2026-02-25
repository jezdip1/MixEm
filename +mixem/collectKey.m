%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% File: +mixem/collectKey.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [keyName, rt_ms] = collectKey(~, allowed, timeout)
KbReleaseWait; t0 = GetSecs; keyName = '';
while GetSecs - t0 < timeout
[down, ~, kc] = KbCheck;
if down
k = KbName(kc);
if ischar(k), k = {k}; end
if any(ismember(k, allowed))
keyName = k{find(ismember(k,allowed),1)}; %#ok<FNDSB>
break
end
end
end
rt_ms = (GetSecs - t0)*1000;
end
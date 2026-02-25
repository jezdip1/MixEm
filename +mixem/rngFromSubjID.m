%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% File: +mixem/rngFromSubjID.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function idNum = rngFromSubjID(subjID)
tokens = regexp(subjID,'(\d+)$','tokens','once');
if ~isempty(tokens)
idNum = str2double(tokens{1});
else
idNum = sum(double(subjID));
end
end
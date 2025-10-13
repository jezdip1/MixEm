function update_schedule_row(schedPath, rowIdx, fields)
Sched = readtable(schedPath);
fn = fieldnames(fields);
for k = 1:numel(fn)
    col = fn{k};
    if ~ismember(col, Sched.Properties.VariableNames)
        Sched.(col) = repmat(local_missing_like(fields.(col)), height(Sched), 1);
    end
    Sched.(col)(rowIdx) = fields.(col);
end
writetable(Sched, schedPath);
end
function v = local_missing_like(x)
if isstring(x) || ischar(x), v = strings(1,1);
elseif isnumeric(x),         v = NaN;
elseif islogical(x),         v = false;
else,                        v = strings(1,1);
end
end

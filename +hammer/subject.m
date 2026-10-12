function id = subject(id)
id = strtrim(char(id));
assert(~isempty(regexp(id, '^[A-Za-z0-9][A-Za-z0-9_.-]*$', 'once')), ...
    'ID must begin with a letter/digit and contain only letters, digits, _, - or dot.');
end

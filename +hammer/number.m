function v = number(name, fallback)
s = strtrim(getenv(name));
if isempty(s), v = fallback; return; end
v = str2double(s);
assert(isscalar(v) && isfinite(v) && v >= 0 && v == floor(v), ...
    '%s must be a nonnegative integer.', name);
end

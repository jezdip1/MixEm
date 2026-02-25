function okPos = deck_ok_position(okIdx, nKeys)
% Převede okIdx na 1-based index robustně (pokryje 0-based i 1-based).
%
% okIdx může být:
%  - 0-based (0..nKeys-1)
%  - 1-based (1..nKeys)

okPos = NaN;

% pokud je v rozsahu 1..nKeys, ber jako 1-based
if okIdx >= 1 && okIdx <= nKeys
    okPos = okIdx;
    return
end

% pokud je v rozsahu 0..nKeys-1, převeď na 1-based
if okIdx >= 0 && okIdx <= (nKeys-1)
    okPos = okIdx + 1;
    return
end

% jinak fallback: nedefinované
okPos = NaN;
end

function source = waitForContinue(params, continueRect, deck)
% Vrátí 'mouse' | 'key' | 'deck'.
if nargin<3, deck = []; end
win = params.win;

% flush myši (bez indexu zařízení)
[~, ~, buttons] = GetMouse(win);
while any(buttons)
    [~, ~, buttons] = GetMouse(win);
    WaitSecs(0.01);
end
KbReleaseWait;

okIdx = [];
if ~isempty(deck) && isfield(deck,'okIndex'), okIdx = deck.okIndex; end

while true
    % --- mouse ---
    [mx, my, buttons] = GetMouse(win);
    if any(buttons)
        if IsInRect(mx, my, continueRect)
            while any(GetMouse(win)), end % debounce
            source = 'mouse'; return;
        end
    end

    % --- keyboard ---
    [down, ~, ~] = KbCheck;
    if down
        KbReleaseWait;
        source = 'key'; return;
    end

    % --- stream deck ---
    if ~isempty(deck)
        try
            % převedeme Python list(bool) -> logické pole
            stCell = cell(py.list(deck.dev.key_states()));
            st = cellfun(@(b) logical(b), stCell);
            if ~isempty(okIdx) && okIdx+1 <= numel(st) && st(okIdx+1)
                pause(0.15); % debounce
                source = 'deck'; return;
            end
        catch
            % zařízení se odpojilo → pokračuj bez něj
            deck = [];
        end
    end
    WaitSecs(0.01);
end
end

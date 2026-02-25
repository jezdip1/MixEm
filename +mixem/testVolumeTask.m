function testVolumeTask(params)
% TESTVOLUMETASK
% - vol_test.png
% - speaker click (mouse) => přehraje WAV (musí proběhnout alespoň jednou)
% - speaker button (deck) => přehraje WAV pokaždé
% - continue (mouse/deck/key) až po přehrání alespoň jednou

%% 0) Najdi test wav
vt = dir(fullfile(params.stimDir,'vol_test','*.wav'));
if isempty(vt)
    warning('testVolumeTask:NoWav','Nenalezen žádný WAV v Stimuli/vol_test.');
    return
end
wavPath = fullfile(vt(1).folder, vt(1).name);

%% 1) Vykresli stránku + hitboxy + debug rámečky
mixem.showPNG(params,'vol_test.png',false);

hitSpeaker  = mixem.getClickableRectForPNG(params,'vol_test.png',"speaker");
hitContinue = mixem.getClickableRectForPNG(params,'vol_test.png',"continue");

debugOutline = false;
if debugOutline
    if ~isempty(hitSpeaker),  Screen('FrameRect', params.win, [255 0 0], hitSpeaker, 2); end
    if ~isempty(hitContinue), Screen('FrameRect', params.win, [0 255 0], hitContinue, 2); end
end
Screen('Flip', params.win);

%% 2) Připrav input
scr = Screen('WindowScreenNumber', params.win);

% flush mouse
[~,~,buttons] = GetMouse(scr);
while any(buttons)
    [~,~,buttons] = GetMouse(scr);
    WaitSecs(0.005);
end
prevButtons = buttons;

% flush keyboard
[prevKeyDown, ~, ~] = KbCheck;
if prevKeyDown
    WaitSecs(0.05);
    [prevKeyDown, ~, ~] = KbCheck;
end

% deck setup
deck = [];
if isfield(params,'deck'), deck = params.deck; end

% Překreslení decku do volume režimu (VOL + OK)
if ~isempty(deck)
%     try
        deck = mixem.deck_show_volume(deck);   % musí nastavit deck.okIndex0 a deck.speakerIndex0
        params.deck = deck;
%     catch ME
%         warning('deck_show_volume failed: %s', ME.message);
%         deck = [];
%     end
end

% flush deck
prevDeck = [];
if ~isempty(deck)
    try
        prevDeck = mixem.deck_read_states_any(deck);
    catch
        prevDeck = [];
    end
end

playedOnce = false;

%% 3) Loop
while true
    % --- MOUSE edge ---
    [mx,my,buttons] = GetMouse(scr);
    risingMouse = buttons & ~prevButtons;
    prevButtons = buttons;

    if any(risingMouse)
        if ~isempty(hitSpeaker) && IsInRect(mx,my,hitSpeaker)
            mixem.playAudioFile(params, wavPath);
            playedOnce = true;
        elseif ~isempty(hitContinue) && IsInRect(mx,my,hitContinue)
            if playedOnce
                return
            end
        end
    end

    % --- KEY edge ---
    [keyDown, ~, ~] = KbCheck;
    if keyDown && ~prevKeyDown
        if playedOnce
            return
        end
    end
    prevKeyDown = keyDown;

    % --- DECK edge ---
    if ~isempty(deck)
        try
            st = mixem.deck_read_states_any(deck);
            if isempty(prevDeck), prevDeck = false(size(st)); end
            risingDeck = st & ~prevDeck;
            prevDeck = st;

            if any(risingDeck)
                % Debug: co přesně stouplo
                % fprintf('Deck rising: %s\n', mat2str(find(risingDeck)));

                % Pozice ve vektoru st jsou 1-based; deck_show_volume má uložit 0-based indexy.
                okPos = NaN; spPos = NaN;
                if isstruct(deck) && isfield(deck,'okIndex0')
                    okPos = deck.okIndex0 + 1;
                end
                if isstruct(deck) && isfield(deck,'speakerIndex0')
                    spPos = deck.speakerIndex0 + 1;
                end

                % Speaker: přehraj POKAŽDÉ při stisku speaker tlačítka
                if ~isnan(spPos) && spPos <= numel(risingDeck) && risingDeck(spPos)
                    mixem.playAudioFile(params, wavPath);
                    playedOnce = true;

                    % počkej na uvolnění, aby další stisk šel okamžitě znovu
                    while true
                        st2 = mixem.deck_read_states_any(deck);
                        if spPos > numel(st2) || ~st2(spPos)
                            break
                        end
                        WaitSecs(0.01);
                    end
                    WaitSecs(0.03);
                end

                % OK: pokračuj až po playedOnce
                if ~isnan(okPos) && okPos <= numel(risingDeck) && risingDeck(okPos)
                    if playedOnce
                        while true
                            st2 = mixem.deck_read_states_any(deck);
                            if okPos > numel(st2) || ~st2(okPos)
                                break
                            end
                            WaitSecs(0.01);
                        end
                        WaitSecs(0.03);
                        return
                    end
                end

                % Fallback: pokud layout nemá indexy (nebo nesedí), chovej se konzervativně:
                % jakýkoli stisk = přehraj (pokaždé), continue řeš myší/klávesnicí
                if isnan(okPos) || isnan(spPos)
                    mixem.playAudioFile(params, wavPath);
                    playedOnce = true;
                    WaitSecs(0.03);
                end
            end

        catch
            deck = []; % deck přestal fungovat -> pokračuj bez něj
        end
    end

    WaitSecs(0.001);
end
end

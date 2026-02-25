% 5 sekund monitoruj stisky a vypiš indexy kláves, které jsou stisknuté
t0 = GetSecs;
while GetSecs - t0 < 5
    try
        st = mixem.deck_read_states_any(params.deck);   % musí vracet logical 1xN
        idx = find(st);
        if ~isempty(idx)
            fprintf('Deck pressed: %s\n', mat2str(idx));
            break
        end
    catch ME
        fprintf('Deck read error: %s\n', ME.message);
        break
    end
    WaitSecs(0.01);
end

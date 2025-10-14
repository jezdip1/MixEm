function showWelcomeScreen(params)
    white = WhiteIndex(params.win); black = BlackIndex(params.win);
    DrawFormattedText(params.win, 'Vítejte! Stiskněte libovolnou klávesu...', 'center','center', white);
    Screen('Flip', params.win); KbStrokeWait; Screen('FillRect', params.win, black); Screen('Flip', params.win);
end

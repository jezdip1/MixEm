function testVolumeTask(params)
    % Placeholder: next iteration will play WAV from Stimuli/control_stimuli/vol_test.wav
    white = WhiteIndex(params.win); black = BlackIndex(params.win);
    DrawFormattedText(params.win, 'Volume test — upravte hlasitost a stiskněte klávesu', 'center','center', white);
    Screen('Flip', params.win); KbStrokeWait; Screen('FillRect', params.win, black); Screen('Flip', params.win);
end

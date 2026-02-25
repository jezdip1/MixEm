scr = Screen('WindowScreenNumber', params.win);
for i=1:2000
    [mx,my,buttons] = GetMouse(scr);
    if any(buttons)
        fprintf('CLICK: mx=%d my=%d buttons=%s\n', mx, my, mat2str(buttons));
        break
    end
    WaitSecs(0.01);
end

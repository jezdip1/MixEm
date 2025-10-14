function map = keymap()
    KbName('UnifyKeyNames');
    map.neg = KbName('1!'); map.neu = KbName('2@'); map.pos = KbName('3#');
    map.low = map.neg; map.mid = map.neu; map.high = map.pos;
    map.quit= KbName('ESCAPE');
end

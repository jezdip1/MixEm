% quicktest_welcome.m
[win, winRect] = PsychImaging('OpenWindow', max(Screen('Screens')), 0);
params.win = win; params.winRect = winRect;
params.pngDir = fullfile(pwd,'PNG');

try
    params.deck = mixem.streamdeck_init();
    mixem.deck_show_welcome(params.deck);
catch, params.deck = []; end

mixem.showPNG(params,'welcome_page.png',false);
r = mixem.drawContinueButton(params,"Pokračovat");
src = mixem.waitForContinue(params, r, params.deck);
disp("Source: " + src);

sca;
if ~isempty(params.deck), params.deck.dev.reset(); params.deck.dev.close(); end

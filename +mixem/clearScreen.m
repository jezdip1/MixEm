function tFlip = clearScreen(params, color)
% CLEARSCREEN  Clear PTB window to a uniform color and flip immediately.
% Used to make visual stimuli disappear as soon as a response is registered.

if nargin < 2 || isempty(color), color = 0; end
Screen('FillRect', params.win, color);
tFlip = Screen('Flip', params.win);
end

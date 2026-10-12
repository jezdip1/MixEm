function n = screen(c)
screens = Screen('Screens');
n = c.screen;
if isempty(n), n = max(screens); end
assert(ismember(n, screens), 'Configured screen %g is not available.', n);
fprintf('Presentation screen: %g (fullscreen; original image aspect ratio).\n', n);
end

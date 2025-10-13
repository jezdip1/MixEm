function idx = next_pointer(Sched)
ix = find(~Sched.done, 1, 'first'); if isempty(ix), idx = []; else, idx = ix; end
end

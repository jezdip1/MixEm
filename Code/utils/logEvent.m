function logEvent(outDir, fname, S)
    if ~exist(outDir,'dir'), mkdir(outDir); end
    fp = fullfile(outDir, fname);
    T = struct2table(S);
    if exist(fp,'file')
        writetable(T, fp, 'WriteMode','Append');
    else
        writetable(T, fp);
    end
end

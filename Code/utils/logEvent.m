function logEvent(outDir, fname, S)
fp = fullfile(outDir, fname); T = struct2table(S);
if exist(fp,'file'), writetable(T, fp, 'WriteMode','Append'); else, writetable(T, fp); end
end

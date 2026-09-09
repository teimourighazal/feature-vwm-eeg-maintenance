%% STEP01D_RESTING_FINAL.m
% Final resting-state summary + figures after strict QC and duplicate screening.
%
% Input:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP01B_Resting_QC_Final
%
% Output:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP01D_Resting_Final
%
% This script:
%   1) Reads strict QC resting outputs.
%   2) Detects exact duplicate derived spectral profiles.
%   3) Creates a conservative UNIQUE dataset.
%   4) Recomputes final EC vs EO statistics.
%   5) Saves manuscript-ready summary tables and figures.

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
inDir   = fullfile(rootDir, 'STEP01B_Resting_QC_Final');
outDir  = fullfile(rootDir, 'STEP01D_Resting_Final');

if ~exist(outDir, 'dir'); mkdir(outDir); end

reactFile   = fullfile(inDir, 'Rest_EC_EO_AlphaReactivity_STRICT.csv');
channelFile = fullfile(inDir, 'Rest_ChannelBandPower_Long_STRICT.csv');
summaryFile = fullfile(inDir, 'Rest_SubjectCondition_Summary_STRICT.csv');
qcFile      = fullfile(inDir, 'Resting_QC_FinalInclusion.csv');

if ~exist(reactFile,'file') || ~exist(channelFile,'file') || ~exist(summaryFile,'file')
    error('Required strict resting files are missing. Run STEP01B_RESTING_QC_FINAL first.');
end

Treact = readtable(reactFile);
Tch    = readtable(channelFile);
Tsum   = readtable(summaryFile);
Tqc    = readtable(qcFile);

fprintf('\n=== STEP01D RESTING FINAL ===\n');
fprintf('Strict paired subjects: %d\n', height(Treact));

%% Duplicate screening based on exact derived spectral features
subjects = unique(Tch.Subject, 'stable');
fingerprints = strings(numel(subjects),1);

for i = 1:numel(subjects)
    subj = subjects{i};
    Tsub = Tch(strcmp(Tch.Subject, subj), :);
    Tsub = sortrows(Tsub, {'Condition','ChannelIndex','Band'});

    vals = [Tsub.AbsPower, Tsub.RelPower, Tsub.LogAbsPower, Tsub.TotalPower_1_45Hz];
    vals = round(vals, 12);

    fp = "";
    for r = 1:size(vals,1)
        fp = fp + sprintf('%.12g,%.12g,%.12g,%.12g;', vals(r,1), vals(r,2), vals(r,3), vals(r,4));
    end
    fingerprints(i) = fp;
end

[G, ~] = findgroups(fingerprints);
dupRows = {};
keepSubjects = {};
dropSubjects = {};

for g = 1:max(G)
    idx = find(G == g);
    groupSubjects = subjects(idx);

    keepSubjects{end+1,1} = groupSubjects{1}; %#ok<SAGROW>

    if numel(groupSubjects) > 1
        for k = 2:numel(groupSubjects)
            dropSubjects{end+1,1} = groupSubjects{k}; %#ok<SAGROW>
        end
        dupRows(end+1,:) = {g, strjoin(groupSubjects, ' | '), groupSubjects{1}, strjoin(groupSubjects(2:end), ' | '), numel(groupSubjects)}; %#ok<SAGROW>
    end
end

if isempty(dupRows)
    Tdup = cell2table(cell(0,5), 'VariableNames', {'DuplicateGroupID','SubjectsInGroup','KeptSubject','DroppedSubjects','GroupSize'});
else
    Tdup = cell2table(dupRows, 'VariableNames', {'DuplicateGroupID','SubjectsInGroup','KeptSubject','DroppedSubjects','GroupSize'});
end

writetable(Tdup, fullfile(outDir, 'Resting_DuplicateGroups_FINAL.csv'));

%% Unique conservative set
TreactU = Treact(ismember(Treact.Subject, keepSubjects), :);
TsumU   = Tsum(ismember(Tsum.Subject, keepSubjects), :);
TchU    = Tch(ismember(Tch.Subject, keepSubjects), :);

writetable(TreactU, fullfile(outDir, 'Rest_EC_EO_AlphaReactivity_FINAL.csv'));
writetable(TsumU,   fullfile(outDir, 'Rest_SubjectCondition_Summary_FINAL.csv'));
writetable(TchU,    fullfile(outDir, 'Rest_ChannelBandPower_Long_FINAL.csv'));

%% Stats and descriptives
statsRows = {};

[pa,ha,ta] = safeT(TreactU.EC_PosteriorAlphaAbs, TreactU.EO_PosteriorAlphaAbs);
statsRows(end+1,:) = {'PosteriorAlphaAbs','paired_ttest',pa,ha,ta}; %#ok<SAGROW>
[pa,ha,ta] = safeW(TreactU.EC_PosteriorAlphaAbs, TreactU.EO_PosteriorAlphaAbs);
statsRows(end+1,:) = {'PosteriorAlphaAbs','signrank',pa,ha,ta}; %#ok<SAGROW>

[pr,hr,tr] = safeT(TreactU.EC_PosteriorAlphaRel, TreactU.EO_PosteriorAlphaRel);
statsRows(end+1,:) = {'PosteriorAlphaRel','paired_ttest',pr,hr,tr}; %#ok<SAGROW>
[pr,hr,tr] = safeW(TreactU.EC_PosteriorAlphaRel, TreactU.EO_PosteriorAlphaRel);
statsRows(end+1,:) = {'PosteriorAlphaRel','signrank',pr,hr,tr}; %#ok<SAGROW>

[pp,hp,tp] = safeT(TreactU.EC_AlphaPeakHz, TreactU.EO_AlphaPeakHz);
statsRows(end+1,:) = {'AlphaPeakHz','paired_ttest',pp,hp,tp}; %#ok<SAGROW>
[pp,hp,tp] = safeW(TreactU.EC_AlphaPeakHz, TreactU.EO_AlphaPeakHz);
statsRows(end+1,:) = {'AlphaPeakHz','signrank',pp,hp,tp}; %#ok<SAGROW>

Tstats = cell2table(statsRows, 'VariableNames', {'Feature','Test','pValue','h','StatsText'});
writetable(Tstats, fullfile(outDir, 'Rest_EC_vs_EO_BasicStats_FINAL.csv'));

descRows = {};
descRows(end+1,:) = describePair('PosteriorAlphaAbs', TreactU.EO_PosteriorAlphaAbs, TreactU.EC_PosteriorAlphaAbs); %#ok<SAGROW>
descRows(end+1,:) = describePair('PosteriorAlphaRel', TreactU.EO_PosteriorAlphaRel, TreactU.EC_PosteriorAlphaRel); %#ok<SAGROW>
descRows(end+1,:) = describePair('AlphaPeakHz', TreactU.EO_AlphaPeakHz, TreactU.EC_AlphaPeakHz); %#ok<SAGROW>

Tdesc = cell2table(descRows, 'VariableNames', ...
    {'Feature','N','EO_Mean','EO_Median','EO_SD','EC_Mean','EC_Median','EC_SD','ECminusEO_Mean','ECminusEO_Median','N_ECgreaterEO'});
writetable(Tdesc, fullfile(outDir, 'Rest_PairedDescriptives_FINAL.csv'));

%% Compact manuscript summary
nInitial = height(Tqc);
nStrict  = height(Treact);
nDupGroups = height(Tdup);
nDroppedDup = numel(dropSubjects);
nFinal = height(TreactU);

idxRelT = strcmp(Tstats.Feature,'PosteriorAlphaRel') & strcmp(Tstats.Test,'paired_ttest');
idxRelW = strcmp(Tstats.Feature,'PosteriorAlphaRel') & strcmp(Tstats.Test,'signrank');
idxRelD = strcmp(Tdesc.Feature,'PosteriorAlphaRel');

Summary = table();
Summary.InitialLogSubjects = nInitial;
Summary.StrictPairedN = nStrict;
Summary.DuplicateGroups = nDupGroups;
Summary.DuplicateRecordsDropped = nDroppedDup;
Summary.FinalIndependentN = nFinal;
Summary.RelativeAlpha_EO_Mean = Tdesc.EO_Mean(idxRelD);
Summary.RelativeAlpha_EC_Mean = Tdesc.EC_Mean(idxRelD);
Summary.RelativeAlpha_ECminusEO_Mean = Tdesc.ECminusEO_Mean(idxRelD);
Summary.RelativeAlpha_N_ECgreaterEO = Tdesc.N_ECgreaterEO(idxRelD);
Summary.RelativeAlpha_ttest_p = Tstats.pValue(idxRelT);
Summary.RelativeAlpha_ttest_text = Tstats.StatsText(idxRelT);
Summary.RelativeAlpha_Wilcoxon_p = Tstats.pValue(idxRelW);

writetable(Summary, fullfile(outDir, 'Rest_ManuscriptSummary_FINAL.csv'));

%% Figures
% Figure 1: paired line plot for posterior relative alpha
fig1 = figure('Color','w','Position',[100 100 850 650]);
hold on;

xEO = ones(height(TreactU),1);
xEC = 2*ones(height(TreactU),1);
for i = 1:height(TreactU)
    plot([1 2], [TreactU.EO_PosteriorAlphaRel(i), TreactU.EC_PosteriorAlphaRel(i)], '-o', 'LineWidth', 1);
end

xlim([0.75 2.25]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'Eyes open','Eyes closed'}, 'FontSize', 12);
ylabel('Posterior relative alpha power');
title(sprintf('Posterior relative alpha reactivity, N = %d', nFinal));
box off;
grid on;

saveFigure(fig1, fullfile(outDir, 'Figure_Resting_PairedRelativeAlpha'));

% Figure 2: mean +/- SEM bar with individual points
fig2 = figure('Color','w','Position',[120 120 850 650]);
eo = TreactU.EO_PosteriorAlphaRel;
ec = TreactU.EC_PosteriorAlphaRel;
means = [mean(eo,'omitnan'), mean(ec,'omitnan')];
sems = [std(eo,'omitnan')/sqrt(sum(isfinite(eo))), std(ec,'omitnan')/sqrt(sum(isfinite(ec)))];

bar(1:2, means);
hold on;
errorbar(1:2, means, sems, 'k', 'LineStyle','none', 'LineWidth', 1.2);
scatter(ones(size(eo))*1, eo, 35, 'filled', 'MarkerFaceAlpha', 0.6);
scatter(ones(size(ec))*2, ec, 35, 'filled', 'MarkerFaceAlpha', 0.6);

xlim([0.5 2.5]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'Eyes open','Eyes closed'}, 'FontSize', 12);
ylabel('Posterior relative alpha power');
title('Mean posterior relative alpha power');
box off;
grid on;

saveFigure(fig2, fullfile(outDir, 'Figure_Resting_MeanRelativeAlpha'));

%% Save workspace
save(fullfile(outDir, 'STEP01D_Resting_Final_Workspace.mat'), ...
    'TreactU','TsumU','TchU','Tdup','Tstats','Tdesc','Summary','keepSubjects','dropSubjects');

fprintf('\n================ STEP01D FINAL SUMMARY ================\n');
fprintf('Strict paired N: %d\n', nStrict);
fprintf('Duplicate groups: %d\n', nDupGroups);
fprintf('Duplicate records dropped: %d\n', nDroppedDup);
fprintf('Final independent N: %d\n', nFinal);
fprintf('Relative alpha paired t-test p: %.6g\n', Summary.RelativeAlpha_ttest_p);
fprintf('Relative alpha Wilcoxon p: %.6g\n', Summary.RelativeAlpha_Wilcoxon_p);
fprintf('Outputs saved in:\n%s\n', outDir);

%% Functions
function [p,h,txt] = safeT(x,y)
    ok = isfinite(x) & isfinite(y);
    x=x(ok); y=y(ok);
    if numel(x)<3
        p=NaN; h=NaN; txt='not enough paired observations'; return;
    end
    try
        [h,p,~,st] = ttest(x,y);
        txt = sprintf('t(%d)=%.4f', st.df, st.tstat);
    catch ME
        p=NaN; h=NaN; txt=['ttest failed: ' ME.message];
    end
end

function [p,h,txt] = safeW(x,y)
    ok = isfinite(x) & isfinite(y);
    x=x(ok); y=y(ok);
    if numel(x)<3
        p=NaN; h=NaN; txt='not enough paired observations'; return;
    end
    try
        p = signrank(x,y);
        h = p < 0.05;
        txt = 'Wilcoxon signed-rank test';
    catch ME
        p=NaN; h=NaN; txt=['signrank failed: ' ME.message];
    end
end

function row = describePair(name, eo, ec)
    ok = isfinite(eo) & isfinite(ec);
    eo = eo(ok);
    ec = ec(ok);
    d = ec - eo;
    row = {name, numel(eo), mean(eo,'omitnan'), median(eo,'omitnan'), std(eo,'omitnan'), ...
           mean(ec,'omitnan'), median(ec,'omitnan'), std(ec,'omitnan'), ...
           mean(d,'omitnan'), median(d,'omitnan'), sum(d > 0)};
end

function saveFigure(fig, basePath)
    try
        exportgraphics(fig, [basePath '.png'], 'Resolution', 300);
    catch
        saveas(fig, [basePath '.png']);
    end

    try
        savefig(fig, [basePath '.fig']);
    catch
    end
end

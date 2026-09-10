%% STEP03W3_TASK_EEG_STATS.m
% Task EEG statistics after final duplicate-QC.
%
% Run after:
%   STEP03V3_TASK_EEG_FINALQC.m
%
% Input:
%   STEP03V3_TaskEEG_FinalQC/TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv
%
% Output:
%   STEP03W3_TaskEEG_Stats under the selected Article2 Analysis folder.
%
% Main outputs:
%   TaskEEG_Omnibus_Friedman_ChannelStats.csv
%   TaskEEG_Pairwise_Signrank_ChannelStats.csv
%   TaskEEG_Significant_Omnibus_q05.csv
%   TaskEEG_Significant_Pairwise_q05.csv
%   TaskEEG_Top50_Omnibus.csv
%   TaskEEG_Top50_Pairwise.csv
%   TaskEEG_StatsSummary.csv
%
% Design:
%   Unit of analysis = subject-level median feature.
%   Primary metric   = RelPower_SubjectMedian.
%   Secondary metric = LogAbsPower_SubjectMedian.
%
% Tests:
%   3-condition omnibus:
%       Friedman test across color, orientation, conjunction
%       within each Phase × Band × Channel.
%
%   Pairwise contrasts:
%       Wilcoxon signed-rank test:
%       color vs orientation
%       color vs conjunction
%       orientation vs conjunction
%
% Multiple comparison correction:
%   FDR is computed:
%       1) globally within each metric for omnibus tests
%       2) globally within each metric for all pairwise tests
%       3) separately within each metric × contrast family
%
% Important:
%   Complete-case subjects are used per test. This is necessary because one
%   subject may have missing/invalid epochs in a specific phase/condition.

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

inDir = fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC');
outDir = fullfile(rootDir, 'STEP03W3_TaskEEG_Stats');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP03W3_TaskEEG_Stats');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

featureFile = fullfile(inDir, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv');

% Robust file finder:
% If the final feature file is not exactly in the expected STEP03V3 folder,
% try common Result locations. If still not found, ask the user to select it.
if ~exist(featureFile, 'file')
    candidateFiles = { ...
        fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(rootDir, 'Result', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(pwd, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv') ...
        };

    for cf = 1:numel(candidateFiles)
        if exist(candidateFiles{cf}, 'file')
            featureFile = candidateFiles{cf};
            break;
        end
    end
end

if ~exist(featureFile, 'file')
    fprintf('\nFinal feature file was not found automatically.\n');
    fprintf('Please select TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv manually.\n');
    [selFile, selPath] = uigetfile('*.csv', 'Select TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv');
    if isequal(selFile, 0)
        error('Final subject-level feature file not selected. Run STEP03V3 first or select the FINAL csv file.');
    end
    featureFile = fullfile(selPath, selFile);
end

fprintf('\n=== STEP03W3 TASK EEG STATS ===\n');
fprintf('Input:\n%s\n', featureFile);
fprintf('Output:\n%s\n', outDir);
fprintf('Result copy:\n%s\n', resultOutDir);

T = readtable(featureFile);

%% Basic checks
requiredCols = {'Subject','Condition','ConditionLabel','Phase','ChannelIndex','ChannelName','Band', ...
                'RelPower_SubjectMedian','LogAbsPower_SubjectMedian'};
for c = 1:numel(requiredCols)
    if ~ismember(requiredCols{c}, T.Properties.VariableNames)
        error('Missing required column: %s', requiredCols{c});
    end
end

T.Subject = cellstr(string(T.Subject));
T.ConditionLabel = cellstr(string(T.ConditionLabel));
T.Phase = cellstr(string(T.Phase));
T.ChannelName = cellstr(string(T.ChannelName));
T.Band = cellstr(string(T.Band));

metrics = {'RelPower_SubjectMedian','LogAbsPower_SubjectMedian'};
metricLabels = {'relative_power','log_absolute_power'};

conditions = [1 2 3];
conditionLabels = {'color','orientation','conjunction'};

contrasts = {
    1, 2, 'color_vs_orientation';
    1, 3, 'color_vs_conjunction';
    2, 3, 'orientation_vs_conjunction'
};

phases = unique(T.Phase, 'stable');
bands = unique(T.Band, 'stable');
channels = unique(T(:, {'ChannelIndex','ChannelName'}), 'stable');
channels = sortrows(channels, 'ChannelIndex');

fprintf('Subjects: %d\n', numel(unique(T.Subject)));
fprintf('Channels: %d\n', height(channels));
fprintf('Phases: %d\n', numel(phases));
fprintf('Bands: %d\n', numel(bands));

%% Omnibus Friedman tests
omniRows = {};

for m = 1:numel(metrics)
    metric = metrics{m};
    metricLabel = metricLabels{m};

    for p = 1:numel(phases)
        phase = phases{p};

        for b = 1:numel(bands)
            band = bands{b};

            for ch = 1:height(channels)
                chIdx = channels.ChannelIndex(ch);
                chName = channels.ChannelName{ch};

                Xwide = makeWideConditionMatrix(T, metric, phase, band, chIdx, conditions);
                X = Xwide.X;
                subjList = Xwide.Subjects;

                ok = all(isfinite(X), 2);
                X = X(ok, :);
                subjList = subjList(ok);

                nSubj = size(X,1);

                pval = NaN;
                chi2stat = NaN;
                df = 2;
                kendallW = NaN;

                med1 = NaN; med2 = NaN; med3 = NaN;
                mean1 = NaN; mean2 = NaN; mean3 = NaN;
                bestCond = '';
                bestMedian = NaN;

                if nSubj >= 5
                    try
                        [pval, tbl] = friedman(X, 1, 'off');
                        chi2stat = extractFriedmanChiSquare(tbl);
                    catch
                        [pval, chi2stat] = friedmanManual(X);
                    end

                    if isfinite(chi2stat)
                        kendallW = chi2stat / (nSubj * (numel(conditions)-1));
                    end

                    medVals = median(X, 1, 'omitnan');
                    meanVals = mean(X, 1, 'omitnan');

                    med1 = medVals(1); med2 = medVals(2); med3 = medVals(3);
                    mean1 = meanVals(1); mean2 = meanVals(2); mean3 = meanVals(3);

                    [bestMedian, bestIdx] = max(medVals);
                    bestCond = conditionLabels{bestIdx};
                end

                omniRows(end+1,:) = {metricLabel, metric, phase, band, chIdx, chName, nSubj, ...
                    pval, chi2stat, df, kendallW, ...
                    med1, med2, med3, mean1, mean2, mean3, bestCond, bestMedian, strjoin(subjList, '|')}; %#ok<SAGROW>
            end
        end
    end
end

Tomni = cell2table(omniRows, 'VariableNames', ...
    {'MetricLabel','Metric','Phase','Band','ChannelIndex','ChannelName','NSubjects', ...
     'p_Friedman','ChiSquare','DF','KendallW', ...
     'Median_Color','Median_Orientation','Median_Conjunction', ...
     'Mean_Color','Mean_Orientation','Mean_Conjunction','HighestMedianCondition','HighestMedianValue','SubjectsUsed'});

%% FDR for omnibus: per metric
Tomni.q_FDR_metricFamily = nan(height(Tomni),1);

for m = 1:numel(metricLabels)
    idx = strcmp(Tomni.MetricLabel, metricLabels{m});
    Tomni.q_FDR_metricFamily(idx) = bhFDR(Tomni.p_Friedman(idx));
end

Tomni = sortrows(Tomni, {'MetricLabel','q_FDR_metricFamily','p_Friedman'}, {'ascend','ascend','ascend'});
writetable(Tomni, fullfile(outDir, 'TaskEEG_Omnibus_Friedman_ChannelStats.csv'));

TsigOmni = Tomni(isfinite(Tomni.q_FDR_metricFamily) & Tomni.q_FDR_metricFamily < 0.05, :);
writetable(TsigOmni, fullfile(outDir, 'TaskEEG_Significant_Omnibus_q05.csv'));

TtopOmni = Tomni(isfinite(Tomni.p_Friedman), :);
TtopOmni = sortrows(TtopOmni, {'MetricLabel','p_Friedman'}, {'ascend','ascend'});
TtopOmni = TtopOmni(1:min(50,height(TtopOmni)), :);
writetable(TtopOmni, fullfile(outDir, 'TaskEEG_Top50_Omnibus.csv'));

%% Pairwise Wilcoxon signed-rank tests
pairRows = {};

for m = 1:numel(metrics)
    metric = metrics{m};
    metricLabel = metricLabels{m};

    for cst = 1:size(contrasts,1)
        c1 = contrasts{cst,1};
        c2 = contrasts{cst,2};
        contrastLabel = contrasts{cst,3};

        for p = 1:numel(phases)
            phase = phases{p};

            for b = 1:numel(bands)
                band = bands{b};

                for ch = 1:height(channels)
                    chIdx = channels.ChannelIndex(ch);
                    chName = channels.ChannelName{ch};

                    Xwide = makeWideConditionMatrix(T, metric, phase, band, chIdx, [c1 c2]);
                    X = Xwide.X;
                    subjList = Xwide.Subjects;

                    ok = all(isfinite(X), 2);
                    X = X(ok, :);
                    subjList = subjList(ok);

                    nSubj = size(X,1);

                    pval = NaN;
                    signedRank = NaN;
                    zval = NaN;

                    x1 = X(:,1);
                    x2 = X(:,2);
                    diff12 = x1 - x2;

                    med1 = NaN; med2 = NaN; medDiff = NaN; meanDiff = NaN;
                    nPositive = NaN; nNegative = NaN; nZero = NaN;
                    direction = '';
                    propPositive = NaN;

                    if nSubj >= 5 && any(isfinite(diff12)) && any(abs(diff12) > 0)
                        try
                            [pval, ~, stats] = signrank(x1, x2);
                            if isstruct(stats)
                                if isfield(stats, 'signedrank'); signedRank = stats.signedrank; end
                                if isfield(stats, 'zval'); zval = stats.zval; end
                            end
                        catch
                            pval = NaN;
                        end

                        med1 = median(x1, 'omitnan');
                        med2 = median(x2, 'omitnan');
                        medDiff = median(diff12, 'omitnan');
                        meanDiff = mean(diff12, 'omitnan');

                        nPositive = sum(diff12 > 0);
                        nNegative = sum(diff12 < 0);
                        nZero = sum(diff12 == 0);
                        propPositive = nPositive / nSubj;

                        if medDiff > 0
                            direction = sprintf('condition_%d_higher', c1);
                        elseif medDiff < 0
                            direction = sprintf('condition_%d_higher', c2);
                        else
                            direction = 'no_median_difference';
                        end
                    end

                    pairRows(end+1,:) = {metricLabel, metric, contrastLabel, c1, c2, conditionName(c1), conditionName(c2), ...
                        phase, band, chIdx, chName, nSubj, pval, signedRank, zval, ...
                        med1, med2, medDiff, meanDiff, nPositive, nNegative, nZero, propPositive, direction, strjoin(subjList, '|')}; %#ok<SAGROW>
                end
            end
        end
    end
end

Tpair = cell2table(pairRows, 'VariableNames', ...
    {'MetricLabel','Metric','Contrast','ConditionA','ConditionB','ConditionA_Label','ConditionB_Label', ...
     'Phase','Band','ChannelIndex','ChannelName','NSubjects','p_Signrank','SignedRank','ZValue', ...
     'Median_A','Median_B','MedianDiff_AminusB','MeanDiff_AminusB', ...
     'N_AgreaterB','N_AlessB','N_Equal','Proportion_AgreaterB','DirectionByMedian','SubjectsUsed'});

%% FDR for pairwise
Tpair.q_FDR_metricPairwiseFamily = nan(height(Tpair),1);
Tpair.q_FDR_metricContrastFamily = nan(height(Tpair),1);

for m = 1:numel(metricLabels)
    idxM = strcmp(Tpair.MetricLabel, metricLabels{m});
    Tpair.q_FDR_metricPairwiseFamily(idxM) = bhFDR(Tpair.p_Signrank(idxM));

    for cst = 1:size(contrasts,1)
        cLabel = contrasts{cst,3};
        idxMC = idxM & strcmp(Tpair.Contrast, cLabel);
        Tpair.q_FDR_metricContrastFamily(idxMC) = bhFDR(Tpair.p_Signrank(idxMC));
    end
end

Tpair = sortrows(Tpair, {'MetricLabel','Contrast','q_FDR_metricContrastFamily','p_Signrank'}, {'ascend','ascend','ascend','ascend'});
writetable(Tpair, fullfile(outDir, 'TaskEEG_Pairwise_Signrank_ChannelStats.csv'));

TsigPair_global = Tpair(isfinite(Tpair.q_FDR_metricPairwiseFamily) & Tpair.q_FDR_metricPairwiseFamily < 0.05, :);
writetable(TsigPair_global, fullfile(outDir, 'TaskEEG_Significant_Pairwise_q05_GlobalMetricFamily.csv'));

TsigPair_contrast = Tpair(isfinite(Tpair.q_FDR_metricContrastFamily) & Tpair.q_FDR_metricContrastFamily < 0.05, :);
writetable(TsigPair_contrast, fullfile(outDir, 'TaskEEG_Significant_Pairwise_q05_ContrastFamily.csv'));

% Backward-compatible simpler file name: contrast-family FDR table
writetable(TsigPair_contrast, fullfile(outDir, 'TaskEEG_Significant_Pairwise_q05.csv'));

TtopPair = Tpair(isfinite(Tpair.p_Signrank), :);
TtopPair = sortrows(TtopPair, {'MetricLabel','p_Signrank'}, {'ascend','ascend'});
TtopPair = TtopPair(1:min(50,height(TtopPair)), :);
writetable(TtopPair, fullfile(outDir, 'TaskEEG_Top50_Pairwise.csv'));

%% Summary tables
Tsummary = makeStatsSummary(T, Tomni, Tpair, TsigOmni, TsigPair_global, TsigPair_contrast);
writetable(Tsummary, fullfile(outDir, 'TaskEEG_StatsSummary.csv'));

Tcoverage = makeCoverageSummary(T);
writetable(Tcoverage, fullfile(outDir, 'TaskEEG_StatsCoverage_ByPhaseCondition.csv'));

save(fullfile(outDir, 'STEP03W3_TaskEEG_Stats_Workspace.mat'), ...
    'T','Tomni','Tpair','TsigOmni','TsigPair_global','TsigPair_contrast','Tsummary','Tcoverage');

fprintf('\n================ STEP03W SUMMARY ================\n');
disp(Tsummary);
copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% ===================== FUNCTIONS =====================

function copyOutputsToResultFolder(outDir, resultOutDir)
    if ~exist(resultOutDir, 'dir')
        mkdir(resultOutDir);
    end

    patterns = {'*.csv','*.mat','*.png','*.fig','*.pdf'};
    for p = 1:numel(patterns)
        files = dir(fullfile(outDir, patterns{p}));
        for i = 1:numel(files)
            src = fullfile(files(i).folder, files(i).name);
            dst = fullfile(resultOutDir, files(i).name);
            try
                copyfile(src, dst);
            catch ME
                warning('Could not copy %s to Result folder: %s', files(i).name, ME.message);
            end
        end
    end
end


function Xwide = makeWideConditionMatrix(T, metric, phase, band, chIdx, conditions)
    idx = strcmp(T.Phase, phase) & strcmp(T.Band, band) & T.ChannelIndex == chIdx & ismember(T.Condition, conditions);
    S = T(idx, {'Subject','Condition'});
    vals = T.(metric)(idx);

    subjects = unique(S.Subject, 'stable');
    X = nan(numel(subjects), numel(conditions));

    for i = 1:numel(subjects)
        subj = subjects{i};
        for c = 1:numel(conditions)
            cond = conditions(c);
            hit = strcmp(S.Subject, subj) & S.Condition == cond;
            if any(hit)
                X(i,c) = median(vals(hit), 'omitnan');
            end
        end
    end

    Xwide = struct();
    Xwide.Subjects = subjects;
    Xwide.X = X;
end

function chi2 = extractFriedmanChiSquare(tbl)
    chi2 = NaN;
    try
        % MATLAB's friedman table usually has chi-square in row 2, column 5.
        for r = 1:size(tbl,1)
            for c = 1:size(tbl,2)
                if ischar(tbl{r,c}) || isstring(tbl{r,c})
                    txt = lower(string(tbl{r,c}));
                    if contains(txt, "chi")
                        % Try next numeric cell in the same row
                        for cc = c+1:size(tbl,2)
                            if isnumeric(tbl{r,cc})
                                chi2 = tbl{r,cc};
                                return;
                            end
                        end
                    end
                end
            end
        end

        if size(tbl,1) >= 2 && size(tbl,2) >= 5 && isnumeric(tbl{2,5})
            chi2 = tbl{2,5};
        end
    catch
        chi2 = NaN;
    end
end

function [pval, chi2] = friedmanManual(X)
    pval = NaN;
    chi2 = NaN;

    try
        [n,k] = size(X);
        R = nan(n,k);
        for i = 1:n
            R(i,:) = tiedrank(X(i,:));
        end
        Rsum = sum(R,1);
        chi2 = (12/(n*k*(k+1))) * sum(Rsum.^2) - 3*n*(k+1);
        pval = 1 - chi2cdf(chi2, k-1);
    catch
        pval = NaN;
        chi2 = NaN;
    end
end

function q = bhFDR(p)
    p = double(p(:));
    q = nan(size(p));

    valid = isfinite(p) & p >= 0 & p <= 1;
    pv = p(valid);

    if isempty(pv)
        return;
    end

    [ps, order] = sort(pv, 'ascend');
    m = numel(ps);
    qs = ps .* m ./ (1:m)';

    % Enforce monotonicity from largest to smallest.
    for i = m-1:-1:1
        qs(i) = min(qs(i), qs(i+1));
    end

    qs = min(qs, 1);

    tmp = nan(size(pv));
    tmp(order) = qs;
    q(valid) = tmp;
end

function name = conditionName(c)
    if c == 1
        name = 'color';
    elseif c == 2
        name = 'orientation';
    elseif c == 3
        name = 'conjunction';
    else
        name = sprintf('condition_%g', c);
    end
end

function Tsummary = makeStatsSummary(T, Tomni, Tpair, TsigOmni, TsigPairGlobal, TsigPairContrast)
    rows = {};

    rows(end+1,:) = {'Final subjects in feature table', numel(unique(T.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'Final feature rows', height(T)}; %#ok<AGROW>
    rows(end+1,:) = {'Unique channels', numel(unique(T.ChannelIndex))}; %#ok<AGROW>
    rows(end+1,:) = {'Omnibus tests total', height(Tomni)}; %#ok<AGROW>
    rows(end+1,:) = {'Omnibus significant q<0.05 metric family', height(TsigOmni)}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise tests total', height(Tpair)}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise significant q<0.05 global metric family', height(TsigPairGlobal)}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise significant q<0.05 contrast family', height(TsigPairContrast)}; %#ok<AGROW>

    metricLabels = unique(Tomni.MetricLabel, 'stable');
    for i = 1:numel(metricLabels)
        ml = metricLabels{i};

        idxO = strcmp(Tomni.MetricLabel, ml);
        rows(end+1,:) = {sprintf('Omnibus significant q<0.05 for %s', ml), ...
            sum(idxO & isfinite(Tomni.q_FDR_metricFamily) & Tomni.q_FDR_metricFamily < 0.05)}; %#ok<AGROW>

        idxP = strcmp(Tpair.MetricLabel, ml);
        rows(end+1,:) = {sprintf('Pairwise significant global q<0.05 for %s', ml), ...
            sum(idxP & isfinite(Tpair.q_FDR_metricPairwiseFamily) & Tpair.q_FDR_metricPairwiseFamily < 0.05)}; %#ok<AGROW>
    end

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function Tcov = makeCoverageSummary(T)
    [G, Phase, Condition, ConditionLabel] = findgroups(T.Phase, T.Condition, T.ConditionLabel);
    nSubjects = splitapply(@(x) numel(unique(x)), T.Subject, G);
    nRows = splitapply(@numel, T.Subject, G);

    Tcov = table(Phase, Condition, ConditionLabel, nSubjects, nRows, ...
        'VariableNames', {'Phase','Condition','ConditionLabel','NSubjects','NFeatureRows'});
end

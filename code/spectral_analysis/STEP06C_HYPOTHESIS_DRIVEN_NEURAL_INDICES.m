%% STEP06C_HYPOTHESIS_DRIVEN_NEURAL_INDICES.m
% Hypothesis-driven neural indices for Article2.
%
% Purpose:
%   Convert the ROI-level and behavioral-neural results into a small number of
%   neuroscience-motivated, manuscript-ready neural indices.
%
% Why this step:
%   The preceding analyses identified broad patterns:
%       1) maintenance posterior alpha organization, strongest for color
%       2) maintenance posterior/parietal relative gamma, with orientation highest
%          and conjunction also elevated relative to color in posterior regions
%       3) an exploratory retrieval-delta association with reconstructed timing
%       4) no reliable hemispheric lateralization
%
%   STEP06C turns these into compact indices that can be plotted and reported.
%
% Primary indices:
%   I1. Maintenance posterior alpha log-power index:
%       posterior ROIs = parietal, parieto_occipital, occipital
%       alpha, log_absolute_power, maintenance
%       expected: color higher than orientation/conjunction
%
%   I2. Maintenance posterior gamma relative-power index:
%       posterior ROIs = parietal, parieto_occipital
%       gamma, relative_power, maintenance
%       directional expectation: orientation highest; conjunction may also exceed color
%       (do not interpret this index as conjunction-specific binding)
%
%   I3. Maintenance posterior-minus-anterior alpha relative-power gradient:
%       from STEP06A_APGradient_SubjectFeatures
%       alpha, relative_power, maintenance
%       descriptive topographic index; no positive directional claim is assumed
%       because the final omnibus effect was not reliable
%
%   I4. Retrieval delta RT-EEG canonical association:
%       color-vs-conjunction RT difference
%       correlated with retrieval delta log absolute power difference at P4
%       exploratory association evaluated from the preceding RT-EEG analysis
%
% Outputs:
%   Result/STEP06C_HypothesisDriven_NeuralIndices under the selected Article2 Analysis folder.
%
% Main outputs:
%   STEP06C_CompositeIndex_SubjectValues.csv
%   STEP06C_CompositeIndex_ConditionStats.csv
%   STEP06C_CompositeIndex_ContrastStats.csv
%   STEP06C_RT_EEG_CanonicalCorrelations.csv
%   STEP06C_NeuralIndexSummary.csv
%   STEP06C_Final_Interpretation_English.txt
%   STEP06C_Final_Interpretation_Persian.txt

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

resultRoot = fullfile(rootDir, 'Result');
outDir = fullfile(resultRoot, 'STEP06C_HypothesisDriven_NeuralIndices');

if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP06C HYPOTHESIS-DRIVEN NEURAL INDICES ===\n');
fprintf('Primary output folder:\n%s\n', outDir);

%% Inputs
roiFile = findInput(rootDir, 'STEP06A_ROI_SubjectFeatures.csv');
apFile  = findInput(rootDir, 'STEP06A_APGradient_SubjectFeatures.csv');
eegFile = findInput(rootDir, 'STEP05_EEG_SubjectFeatures_STANDARDIZED.csv');
rtFile  = findInput(rootDir, 'STEP05_RT_SubjectWide_STANDARDIZED.csv');

fprintf('\nROI file:\n%s\n', roiFile);
fprintf('AP-gradient file:\n%s\n', apFile);
fprintf('EEG standardized file:\n%s\n', eegFile);
fprintf('RT standardized file:\n%s\n', rtFile);

Troi = readtable(roiFile);
Tap  = readtable(apFile);
E    = readtable(eegFile);
R    = readtable(rtFile);

Troi = harmonizeText(Troi);
Tap  = harmonizeText(Tap);
E    = harmonizeText(E);
R    = harmonizeText(R);

%% Build condition-level composite indices
Tidx = table();

% I1: maintenance posterior alpha log-power
T1 = buildROIConditionIndex(Troi, ...
    'posterior_alpha_log_power', ...
    {'parietal','parieto_occipital','occipital'}, ...
    'maintenance', 'alpha', 'log_absolute_power');
Tidx = [Tidx; T1];

% I2: maintenance posterior gamma relative-power
T2 = buildROIConditionIndex(Troi, ...
    'posterior_gamma_relative_power', ...
    {'parietal','parieto_occipital'}, ...
    'maintenance', 'gamma', 'relative_power');
Tidx = [Tidx; T2];

% I3: maintenance posterior-minus-anterior alpha relative-power
T3 = buildAPConditionIndex(Tap, ...
    'posterior_minus_anterior_alpha_relative_power', ...
    'maintenance', 'alpha', 'relative_power');
Tidx = [Tidx; T3];

writetable(Tidx, fullfile(outDir, 'STEP06C_CompositeIndex_SubjectValues.csv'));

%% Condition stats
TcondStats = runConditionStats(Tidx);
writetable(TcondStats, fullfile(outDir, 'STEP06C_CompositeIndex_ConditionStats.csv'));

%% Contrast stats
TcontrastStats = runContrastStats(Tidx);
writetable(TcontrastStats, fullfile(outDir, 'STEP06C_CompositeIndex_ContrastStats.csv'));

%% Canonical RT-EEG correlations
TrtCorr = runCanonicalRTEEG(E, R, Troi);
writetable(TrtCorr, fullfile(outDir, 'STEP06C_RT_EEG_CanonicalCorrelations.csv'));

%% Summary
Tsummary = makeSummary(Tidx, TcondStats, TcontrastStats, TrtCorr);
writetable(Tsummary, fullfile(outDir, 'STEP06C_NeuralIndexSummary.csv'));

%% Text interpretation
englishText = makeEnglishText(TcondStats, TcontrastStats, TrtCorr);
persianText = makePersianText(TcondStats, TcontrastStats, TrtCorr);

writeText(fullfile(outDir, 'STEP06C_Final_Interpretation_English.txt'), englishText);
writeText(fullfile(outDir, 'STEP06C_Final_Interpretation_Persian.txt'), persianText);

%% Figures
try
    makeIndexFigures(Tidx, outDir);
    makeRTEEGFigures(TrtCorr, E, R, Troi, outDir);
catch ME
    warning('Some STEP06C figures were not created: %s', ME.message);
end

%% Save
save(fullfile(outDir, 'STEP06C_HypothesisDriven_NeuralIndices_Workspace.mat'), ...
    'Troi','Tap','E','R','Tidx','TcondStats','TcontrastStats','TrtCorr','Tsummary','englishText','persianText');

fprintf('\n================ STEP06C SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved directly in Result:\n%s\n', outDir);

%% ===================== FUNCTIONS =====================

function fpath = findInput(rootDir, fileName)
    resultRoot = fullfile(rootDir, 'Result');

    candidates = {
        fullfile(resultRoot, 'STEP06A_Neuro_ROI_TopoSummary', fileName);
        fullfile(resultRoot, 'STEP05_RT_EEG_Correlation', fileName);
        fullfile(resultRoot, fileName);
        fullfile(rootDir, fileName);
        fullfile(pwd, fileName)
    };

    fpath = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            fpath = candidates{i};
            return;
        end
    end

    files = dir(fullfile(resultRoot, '**', fileName));
    if isempty(files)
        files = recursiveDir(resultRoot, fileName);
    end
    if isempty(files)
        files = dir(fullfile(rootDir, '**', fileName));
    end
    if isempty(files)
        files = recursiveDir(rootDir, fileName);
    end

    if ~isempty(files)
        fpath = fullfile(files(1).folder, files(1).name);
        return;
    end

    fprintf('\nCould not find %s automatically.\n', fileName);
    [selFile, selPath] = uigetfile('*.csv', ['Select ' fileName]);
    if isequal(selFile, 0)
        error('Required input not selected: %s', fileName);
    end
    fpath = fullfile(selPath, selFile);
end

function files = recursiveDir(rootDir, pattern)
    files = [];
    if ~exist(rootDir, 'dir'); return; end

    d = dir(rootDir);
    for i = 1:numel(d)
        if d(i).isdir
            name = d(i).name;
            if strcmp(name,'.') || strcmp(name,'..')
                continue;
            end
            files = [files; recursiveDir(fullfile(rootDir,name), pattern)]; %#ok<AGROW>
        end
    end
    files = [files; dir(fullfile(rootDir, pattern))];
end

function T = harmonizeText(T)
    if isempty(T); return; end

    textVars = {'Subject','ConditionLabel','PhaseLabel','Band','ROI','EEGMetric','FeatureLabel','ChannelName','Condition','Contrast'};
    for i = 1:numel(textVars)
        v = textVars{i};
        if ismember(v, T.Properties.VariableNames)
            if iscell(T.(v))
                T.(v) = cellstr(string(T.(v)));
            elseif isstring(T.(v)) || iscategorical(T.(v)) || ischar(T.(v))
                T.(v) = cellstr(string(T.(v)));
            end
        end
    end
end

function Tout = buildROIConditionIndex(Troi, indexName, rois, phase, band, metric)
    idx = strcmp(Troi.PhaseLabel, phase) & strcmp(Troi.Band, band) & ...
          strcmp(Troi.EEGMetric, metric) & ismember(Troi.ROI, rois);

    S = Troi(idx, :);
    keys = unique(S(:, {'Subject','ConditionLabel'}), 'stable');

    rows = {};
    for i = 1:height(keys)
        idx2 = strcmp(S.Subject, keys.Subject{i}) & strcmp(S.ConditionLabel, keys.ConditionLabel{i});
        vals = S.FeatureValue(idx2);

        rows(end+1,:) = {keys.Subject{i}, indexName, keys.ConditionLabel{i}, ...
            phase, band, metric, strjoin(rois,'|'), median(vals,'omitnan'), sum(isfinite(vals))}; %#ok<AGROW>
    end

    Tout = cell2table(rows, 'VariableNames', ...
        {'Subject','IndexName','ConditionLabel','Phase','Band','EEGMetric','SpatialDefinition','IndexValue','NComponents'});
end

function Tout = buildAPConditionIndex(Tap, indexName, phase, band, metric)
    idx = strcmp(Tap.PhaseLabel, phase) & strcmp(Tap.Band, band) & ...
          strcmp(Tap.EEGMetric, metric);

    S = Tap(idx, :);

    rows = {};
    for i = 1:height(S)
        rows(end+1,:) = {S.Subject{i}, indexName, S.ConditionLabel{i}, ...
            phase, band, metric, 'posterior_minus_anterior', S.FeatureValue(i), 1}; %#ok<AGROW>
    end

    Tout = cell2table(rows, 'VariableNames', ...
        {'Subject','IndexName','ConditionLabel','Phase','Band','EEGMetric','SpatialDefinition','IndexValue','NComponents'});
end

function Tstats = runConditionStats(Tidx)
    indices = unique(Tidx.IndexName, 'stable');
    rows = {};

    for i = 1:numel(indices)
        S = Tidx(strcmp(Tidx.IndexName, indices{i}), :);
        [X, subjects] = wideByCondition(S);

        ok = all(isfinite(X),2);
        Xok = X(ok,:);
        subjectsUsed = subjects(ok);
        n = size(Xok,1);

        pF = NaN; chi2 = NaN; W = NaN;
        medColor = NaN; medOri = NaN; medConj = NaN;
        maxCond = '';

        if n >= 3
            try
                [pF, tbl] = friedman(Xok, 1, 'off');
                chi2 = extractFriedmanChiSquare(tbl);
            catch
                [pF, chi2] = friedmanManual(Xok);
            end

            W = chi2 / (n * 2);

            medVals = median(Xok,1,'omitnan');
            medColor = medVals(1);
            medOri = medVals(2);
            medConj = medVals(3);

            labels = {'color','orientation','conjunction'};
            [~,imax] = max(medVals);
            maxCond = labels{imax};
        end

        rows(end+1,:) = {indices{i}, n, pF, chi2, W, medColor, medOri, medConj, maxCond, strjoin(subjectsUsed,'|')}; %#ok<AGROW>
    end

    Tstats = cell2table(rows, 'VariableNames', ...
        {'IndexName','NSubjects','p_Friedman','ChiSquare','KendallW','Median_Color','Median_Orientation','Median_Conjunction','MaxCondition','SubjectsUsed'});
end

function Tstats = runContrastStats(Tidx)
    indices = unique(Tidx.IndexName, 'stable');
    contrasts = {
        'color','orientation','color_vs_orientation';
        'color','conjunction','color_vs_conjunction';
        'orientation','conjunction','orientation_vs_conjunction'
    };

    rows = {};

    for i = 1:numel(indices)
        S = Tidx(strcmp(Tidx.IndexName, indices{i}), :);

        for c = 1:size(contrasts,1)
            condA = contrasts{c,1};
            condB = contrasts{c,2};
            contrast = contrasts{c,3};

            [X, subjects] = wideBySelectedConditions(S, {condA, condB});
            ok = all(isfinite(X),2);
            Xok = X(ok,:);
            subjectsUsed = subjects(ok);

            n = size(Xok,1);
            pW = NaN; medA = NaN; medB = NaN; medDiff = NaN; direction = '';

            if n >= 3
                diffAB = Xok(:,1) - Xok(:,2);
                medA = median(Xok(:,1),'omitnan');
                medB = median(Xok(:,2),'omitnan');
                medDiff = median(diffAB,'omitnan');

                if any(abs(diffAB) > 0)
                    try
                        pW = signrank(Xok(:,1), Xok(:,2));
                    catch
                        pW = NaN;
                    end
                end

                if medDiff > 0
                    direction = [condA '_greater_than_' condB];
                elseif medDiff < 0
                    direction = [condB '_greater_than_' condA];
                else
                    direction = 'no_median_difference';
                end
            end

            rows(end+1,:) = {indices{i}, contrast, condA, condB, n, pW, medA, medB, medDiff, direction, strjoin(subjectsUsed,'|')}; %#ok<AGROW>
        end
    end

    Tstats = cell2table(rows, 'VariableNames', ...
        {'IndexName','Contrast','ConditionA','ConditionB','NSubjects','p_Signrank','Median_A','Median_B','MedianDiff_AminusB','DirectionByMedian','SubjectsUsed'});
end

function Trt = runCanonicalRTEEG(E, R, Troi)
    rows = {};

    % C1: channel-level P4 retrieval delta log absolute power color-vs-conjunction
    [rtDiff, eegDiff, subjects] = getChannelContrast(E, R, ...
        'color_vs_conjunction', 'color', 'conjunction', ...
        'retrieval', 'delta', 'P4', 'LogAbsPower');

    [rho, p] = robustSpearman(rtDiff, eegDiff);
    rows(end+1,:) = {'canonical_P4_retrieval_delta_logpower_color_vs_conjunction', ...
        'color_vs_conjunction', 'retrieval', 'delta', 'log_absolute_power', 'P4', ...
        numel(rtDiff), rho, p, median(rtDiff,'omitnan'), median(eegDiff,'omitnan'), strjoin(subjects,'|')}; %#ok<AGROW>

    % C2: posterior ROI retrieval delta log absolute power color-vs-conjunction
    [rtDiff2, eegDiff2, subjects2] = getROIContrast(Troi, R, ...
        'color_vs_conjunction', 'color', 'conjunction', ...
        'retrieval', 'delta', 'log_absolute_power', {'parietal','parieto_occipital','occipital'});

    [rho2, p2] = robustSpearman(rtDiff2, eegDiff2);
    rows(end+1,:) = {'posteriorROI_retrieval_delta_logpower_color_vs_conjunction', ...
        'color_vs_conjunction', 'retrieval', 'delta', 'log_absolute_power', 'posterior_ROI', ...
        numel(rtDiff2), rho2, p2, median(rtDiff2,'omitnan'), median(eegDiff2,'omitnan'), strjoin(subjects2,'|')}; %#ok<AGROW>

    % C3: posterior gamma relative power maintenance conjunction-vs-color with conjunction RT
    [rtConj, eegGamma, subjects3] = getConditionROIForRT(Troi, R, ...
        'conjunction', 'maintenance', 'gamma', 'relative_power', {'parietal','parieto_occipital'});

    [rho3, p3] = robustSpearman(rtConj, eegGamma);
    rows(end+1,:) = {'posteriorROI_maintenance_gamma_relativepower_conjunctionRT', ...
        'conjunction_condition_matched', 'maintenance', 'gamma', 'relative_power', 'posterior_ROI', ...
        numel(rtConj), rho3, p3, median(rtConj,'omitnan'), median(eegGamma,'omitnan'), strjoin(subjects3,'|')}; %#ok<AGROW>

    Trt = cell2table(rows, 'VariableNames', ...
        {'CanonicalAnalysis','BehaviorContrastOrCondition','Phase','Band','EEGMetric','SpatialFeature','NSubjects','SpearmanRho','p_Spearman','MedianRT_or_RTDiff_ms','MedianEEG_or_EEGDiff','SubjectsUsed'});
end

function [rtDiff, eegDiff, subjects] = getChannelContrast(E, R, contrast, condA, condB, phase, band, chName, metricCol)
    rtCol = [strrep(contrast, '_vs_', '_minus_') '_RT_ms'];

    idxA = strcmp(E.ConditionLabel, condA) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, chName);
    idxB = strcmp(E.ConditionLabel, condB) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, chName);

    EA = E(idxA, {'Subject', metricCol});
    EB = E(idxB, {'Subject', metricCol});

    EA.Properties.VariableNames{2} = 'EEG_A';
    EB.Properties.VariableNames{2} = 'EEG_B';

    M_EEG = innerjoin(EA, EB, 'Keys', 'Subject');
    M_EEG.EEG_Diff = M_EEG.EEG_A - M_EEG.EEG_B;

    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RT_Diff';

    M = innerjoin(Rs, M_EEG(:, {'Subject','EEG_Diff'}), 'Keys', 'Subject');
    ok = isfinite(M.RT_Diff) & isfinite(M.EEG_Diff);

    rtDiff = M.RT_Diff(ok);
    eegDiff = M.EEG_Diff(ok);
    subjects = M.Subject(ok);
end

function [rtDiff, eegDiff, subjects] = getROIContrast(Troi, R, contrast, condA, condB, phase, band, metric, rois)
    rtCol = [strrep(contrast, '_vs_', '_minus_') '_RT_ms'];

    idx = strcmp(Troi.PhaseLabel, phase) & strcmp(Troi.Band, band) & ...
          strcmp(Troi.EEGMetric, metric) & ismember(Troi.ROI, rois);

    S = Troi(idx, :);
    subjectsAll = unique(S.Subject, 'stable');

    rows = {};
    for i = 1:numel(subjectsAll)
        subj = subjectsAll{i};
        valsA = S.FeatureValue(strcmp(S.Subject, subj) & strcmp(S.ConditionLabel, condA));
        valsB = S.FeatureValue(strcmp(S.Subject, subj) & strcmp(S.ConditionLabel, condB));

        if ~isempty(valsA) && ~isempty(valsB)
            rows(end+1,:) = {subj, median(valsA,'omitnan') - median(valsB,'omitnan')}; %#ok<AGROW>
        end
    end

    Teeg = cell2table(rows, 'VariableNames', {'Subject','EEG_Diff'});
    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RT_Diff';

    M = innerjoin(Rs, Teeg, 'Keys', 'Subject');
    ok = isfinite(M.RT_Diff) & isfinite(M.EEG_Diff);

    rtDiff = M.RT_Diff(ok);
    eegDiff = M.EEG_Diff(ok);
    subjects = M.Subject(ok);
end

function [rtVals, eegVals, subjects] = getConditionROIForRT(Troi, R, cond, phase, band, metric, rois)
    rtCol = [cond '_RT_ms'];

    idx = strcmp(Troi.PhaseLabel, phase) & strcmp(Troi.Band, band) & ...
          strcmp(Troi.EEGMetric, metric) & ismember(Troi.ROI, rois) & strcmp(Troi.ConditionLabel, cond);

    S = Troi(idx, :);
    subjectsAll = unique(S.Subject, 'stable');

    rows = {};
    for i = 1:numel(subjectsAll)
        subj = subjectsAll{i};
        vals = S.FeatureValue(strcmp(S.Subject, subj));
        rows(end+1,:) = {subj, median(vals,'omitnan')}; %#ok<AGROW>
    end

    Teeg = cell2table(rows, 'VariableNames', {'Subject','EEGValue'});
    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RTValue';

    M = innerjoin(Rs, Teeg, 'Keys', 'Subject');
    ok = isfinite(M.RTValue) & isfinite(M.EEGValue);

    rtVals = M.RTValue(ok);
    eegVals = M.EEGValue(ok);
    subjects = M.Subject(ok);
end

function Tsummary = makeSummary(Tidx, TcondStats, TcontrastStats, TrtCorr)
    rows = {};
    rows(end+1,:) = {'Composite index rows', height(Tidx)}; %#ok<AGROW>
    rows(end+1,:) = {'Composite indices', numel(unique(Tidx.IndexName))}; %#ok<AGROW>
    rows(end+1,:) = {'Condition-stat tests', height(TcondStats)}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast-stat tests', height(TcontrastStats)}; %#ok<AGROW>
    rows(end+1,:) = {'Canonical RT-EEG tests', height(TrtCorr)}; %#ok<AGROW>
    rows(end+1,:) = {'Condition effects p<0.05', sum(TcondStats.p_Friedman < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast effects p<0.05', sum(TcontrastStats.p_Signrank < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Canonical RT-EEG p<0.05', sum(TrtCorr.p_Spearman < 0.05, 'omitnan')}; %#ok<AGROW>

    if ~isempty(TcondStats)
        [~,iBest] = min(TcondStats.p_Friedman);
        rows(end+1,:) = {'Strongest composite condition index', TcondStats.IndexName{iBest}}; %#ok<AGROW>
        rows(end+1,:) = {'Strongest composite condition p', TcondStats.p_Friedman(iBest)}; %#ok<AGROW>
    end

    if ~isempty(TrtCorr)
        [~,iBest] = min(TrtCorr.p_Spearman);
        rows(end+1,:) = {'Strongest canonical RT-EEG analysis', TrtCorr.CanonicalAnalysis{iBest}}; %#ok<AGROW>
        rows(end+1,:) = {'Strongest canonical RT-EEG rho', TrtCorr.SpearmanRho(iBest)}; %#ok<AGROW>
        rows(end+1,:) = {'Strongest canonical RT-EEG p', TrtCorr.p_Spearman(iBest)}; %#ok<AGROW>
    end

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function txt = makeEnglishText(TcondStats, TcontrastStats, TrtCorr)
    txt = ['Hypothesis-driven neural-index analyses were used to summarize the main neuroscience patterns identified in the ROI and RT-EEG analyses. ', ...
        'Three compact task-EEG indices were evaluated: maintenance posterior alpha log power, maintenance posterior gamma relative power, and maintenance posterior-minus-anterior alpha relative power. ', ...
        'These indices were designed to summarize posterior alpha organization for color-only trials and posterior relative-gamma differences in which orientation was highest and conjunction could also exceed color. ', ...
        'Canonical RT-EEG analyses further evaluated, on an exploratory basis, the color-versus-conjunction retrieval-delta association using a small number of predefined features. ', ...
        'These analyses should be interpreted as focused summaries of the preceding analyses rather than as independent confirmatory evidence.'];
end

function txt = makePersianText(TcondStats, TcontrastStats, TrtCorr)
    txt = ['در این مرحله، برای خلاصه‌سازی الگوهای اصلی نوروساینسی، چند شاخص محدود و فرضیه‌محور تعریف شد. ', ...
        'سه شاخص اصلی EEG تکلیف شامل log-power آلفای posterior در فاز maintenance، توان نسبی گامای posterior در فاز maintenance، و شاخص آلفای posterior-minus-anterior در فاز maintenance بودند. ', ...
        'هدف این شاخص‌ها خلاصه‌سازی سازمان‌یافتگی آلفای posterior در وضعیت color-only و تفاوت‌های گامای نسبی posterior بود؛ در نتایج نهایی orientation بالاترین مقدار را داشت و conjunction نیز می‌توانست از color بیشتر باشد. ', ...
        'در کنار آن، تحلیل‌های canonical RT–EEG به‌صورت اکتشافی ارتباط color-versus-conjunction در باند دلتای فاز retrieval را با چند ویژگی از پیش تعریف‌شده بررسی کردند. ', ...
        'این تحلیل‌ها باید به‌عنوان خلاصه‌های متمرکز از تحلیل‌های قبلی تفسیر شوند و نه به‌عنوان شواهد تأییدی مستقل.'];
end

function makeIndexFigures(Tidx, outDir)
    figDir = fullfile(outDir, 'Figures');
    if ~exist(figDir, 'dir'); mkdir(figDir); end

    indices = unique(Tidx.IndexName, 'stable');
    labels = {'color','orientation','conjunction'};

    for i = 1:numel(indices)
        S = Tidx(strcmp(Tidx.IndexName, indices{i}), :);
        [X, ~] = wideByCondition(S);

        fig = figure('Color','w','Position',[100 100 780 480]);
        boxplot(X, 'Labels', labels);
        ylabel('Composite neural index');
        title(indices{i}, 'Interpreter', 'none');
        grid on;
        saveas(fig, fullfile(figDir, [indices{i} '_condition_boxplot.png']));
        savefig(fig, fullfile(figDir, [indices{i} '_condition_boxplot.fig']));
        close(fig);
    end
end

function makeRTEEGFigures(TrtCorr, E, R, Troi, outDir)
    figDir = fullfile(outDir, 'Figures');
    if ~exist(figDir, 'dir'); mkdir(figDir); end

    % Recreate strongest channel-level canonical scatter if available.
    idx = strcmp(TrtCorr.CanonicalAnalysis, 'canonical_P4_retrieval_delta_logpower_color_vs_conjunction');
    if any(idx)
        [x,y,~] = getChannelContrast(E, R, ...
            'color_vs_conjunction', 'color', 'conjunction', ...
            'retrieval', 'delta', 'P4', 'LogAbsPower');

        makeScatter(x, y, ...
            'Color minus conjunction RT difference (ms)', ...
            'Color minus conjunction retrieval delta log power at P4', ...
            sprintf('Canonical RT-EEG: rho=%.2f, p=%.3g', TrtCorr.SpearmanRho(idx), TrtCorr.p_Spearman(idx)), ...
            fullfile(figDir, 'Canonical_RT_EEG_P4_RetrievalDelta_ColorVsConjunction.png'));
    end
end

function makeScatter(x, y, xlab, ylab, ttl, outPng)
    fig = figure('Color','w','Position',[100 100 700 520]);
    scatter(x, y, 50, 'filled'); hold on;
    lsline;
    xlabel(xlab, 'Interpreter', 'none');
    ylabel(ylab, 'Interpreter', 'none');
    title(ttl, 'Interpreter', 'none');
    grid on;
    saveas(fig, outPng);
    savefig(fig, strrep(outPng, '.png', '.fig'));
    close(fig);
end

function [X, subjects] = wideByCondition(S)
    labels = {'color','orientation','conjunction'};
    [X, subjects] = wideBySelectedConditions(S, labels);
end

function [X, subjects] = wideBySelectedConditions(S, labels)
    subjects = unique(S.Subject, 'stable');
    X = nan(numel(subjects), numel(labels));

    for s = 1:numel(subjects)
        subj = subjects{s};
        for c = 1:numel(labels)
            idx = strcmp(S.Subject, subj) & strcmp(S.ConditionLabel, labels{c});
            if any(idx)
                X(s,c) = median(S.IndexValue(idx), 'omitnan');
            end
        end
    end
end

function [rho, pval] = robustSpearman(x,y)
    x = x(:);
    y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);

    rho = NaN;
    pval = NaN;

    if numel(x) < 5 || numel(unique(x)) < 3 || numel(unique(y)) < 3
        return;
    end

    try
        [rho, pval] = corr(x, y, 'Type', 'Spearman', 'Rows', 'complete');
    catch
        try
            rx = tiedrank(x);
            ry = tiedrank(y);
            C = corrcoef(rx, ry);
            rho = C(1,2);
            n = numel(x);
            if n > 2 && abs(rho) < 1
                tval = rho * sqrt((n-2)/(1-rho^2));
                pval = 2 * (1 - tcdf(abs(tval), n-2));
            end
        catch
            rho = NaN;
            pval = NaN;
        end
    end
end

function chi2 = extractFriedmanChiSquare(tbl)
    chi2 = NaN;
    try
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

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Could not write text file: %s', fpath);
    end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

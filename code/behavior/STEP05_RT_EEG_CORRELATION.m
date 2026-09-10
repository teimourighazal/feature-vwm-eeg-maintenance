%% STEP05_RT_EEG_CORRELATION.m
% Reconstructed response-interval–EEG association analysis for Article2.
%
% Purpose:
%   Use the EEG-aligned reconstructed response-interval results and final task-EEG
%   subject-level spectral features to test whether between-subject RT
%   variability is associated with EEG spectral features.
%
% Analysis set:
%   Only subjects present in BOTH:
%       1) final task-EEG subject features
%       2) EEG-aligned reconstructed response-interval table
%
% Main analyses:
%   A) Condition-matched correlation:
%      Reconstructed response-interval median for a condition vs EEG feature for the same condition.
%
%   B) Contrast correlation:
%      Reconstructed response-interval difference between two conditions vs EEG feature difference between
%      the same two conditions.
%
% EEG metrics:
%   Primary:     relative power
%   Complement:  log absolute power
%
% Statistics:
%   Spearman correlation across subjects.
%   FDR correction separately by analysis family and EEG metric.
%
% Output:
%   STEP05_RT_EEG_Correlation and Result/STEP05_RT_EEG_Correlation
%   under the selected Article2 Analysis folder.
%
% Note:
%   Legacy file/variable names retain "RT" for backward compatibility. The
%   behavioral measure is a reconstructed response interval, not conventional RT.
%
% Key outputs:
%   STEP05_RT_EEG_AnalysisSummary.csv
%   STEP05_RT_EEG_SubjectOverlap.csv
%   STEP05_RT_EEG_ConditionMatched_Correlations.csv
%   STEP05_RT_EEG_Contrast_Correlations.csv
%   STEP05_RT_EEG_Top50_ConditionMatched.csv
%   STEP05_RT_EEG_Top50_Contrast.csv
%   STEP05_RT_EEG_Significant_ConditionMatched_q05.csv
%   STEP05_RT_EEG_Significant_Contrast_q05.csv

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(rootDir, 'STEP05_RT_EEG_Correlation');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP05_RT_EEG_Correlation');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP05 RT-EEG CORRELATION ===\n');
fprintf('Stage output:\n%s\n', outDir);
fprintf('Result output:\n%s\n', resultOutDir);

%% Locate inputs
eegFile = findInput(rootDir, {
    fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
    fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
    fullfile(rootDir, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv')}, ...
    'Select TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv');

rtWideFile = findInput(rootDir, {
    fullfile(rootDir, 'STEP04D_RT_FinalReport', 'RT_FinalReport_SubjectWide_EEG_ALIGNED.csv'), ...
    fullfile(rootDir, 'Result', 'STEP04D_RT_FinalReport', 'RT_FinalReport_SubjectWide_EEG_ALIGNED.csv'), ...
    fullfile(rootDir, 'RT_FinalReport_SubjectWide_EEG_ALIGNED.csv')}, ...
    'Select RT_FinalReport_SubjectWide_EEG_ALIGNED.csv');

fprintf('\nEEG feature file:\n%s\n', eegFile);
fprintf('\nRT wide file:\n%s\n', rtWideFile);

%% Read and standardize
Eraw = readtable(eegFile);
Rraw = readtable(rtWideFile);

E = standardizeEEGTable(Eraw);
R = standardizeRTWideTable(Rraw);

writetable(E, fullfile(outDir, 'STEP05_EEG_SubjectFeatures_STANDARDIZED.csv'));
writetable(R, fullfile(outDir, 'STEP05_RT_SubjectWide_STANDARDIZED.csv'));

%% Subject overlap
eegSubjects = unique(E.Subject, 'stable');
rtSubjects = unique(R.Subject, 'stable');
overlapSubjects = intersect(eegSubjects, rtSubjects, 'stable');

Tsubj = makeSubjectOverlapTable(eegSubjects, rtSubjects);
writetable(Tsubj, fullfile(outDir, 'STEP05_RT_EEG_SubjectOverlap.csv'));

fprintf('\nFinal EEG subjects in feature table: %d\n', numel(eegSubjects));
fprintf('RT subjects in EEG-aligned RT table: %d\n', numel(rtSubjects));
fprintf('Overlap subjects used for RT-EEG: %d\n', numel(overlapSubjects));

%% Restrict to overlap
E = E(ismember(E.Subject, overlapSubjects), :);
R = R(ismember(R.Subject, overlapSubjects), :);

%% Condition-matched correlations
TcondCorr = runConditionMatchedCorrelations(E, R);
TcondCorr = addFDR(TcondCorr, {'AnalysisType','EEGMetric'});
writetable(TcondCorr, fullfile(outDir, 'STEP05_RT_EEG_ConditionMatched_Correlations.csv'));

TcondSig = TcondCorr(TcondCorr.q_FDR_metricFamily < 0.05, :);
TcondSig = sortrows(TcondSig, {'EEGMetric','q_FDR_metricFamily','p_Spearman'});
writetable(TcondSig, fullfile(outDir, 'STEP05_RT_EEG_Significant_ConditionMatched_q05.csv'));

TcondTop = makeTopTable(TcondCorr, 50);
writetable(TcondTop, fullfile(outDir, 'STEP05_RT_EEG_Top50_ConditionMatched.csv'));

%% Contrast correlations
TcontrastCorr = runContrastCorrelations(E, R);
TcontrastCorr = addFDR(TcontrastCorr, {'AnalysisType','EEGMetric'});
TcontrastCorr = addFDRByContrast(TcontrastCorr);
writetable(TcontrastCorr, fullfile(outDir, 'STEP05_RT_EEG_Contrast_Correlations.csv'));

TcontrastSig = TcontrastCorr(TcontrastCorr.q_FDR_metricFamily < 0.05, :);
TcontrastSig = sortrows(TcontrastSig, {'EEGMetric','q_FDR_metricFamily','p_Spearman'});
writetable(TcontrastSig, fullfile(outDir, 'STEP05_RT_EEG_Significant_Contrast_q05.csv'));

TcontrastSigContrast = TcontrastCorr(TcontrastCorr.q_FDR_contrastFamily < 0.05, :);
TcontrastSigContrast = sortrows(TcontrastSigContrast, {'EEGMetric','Contrast','q_FDR_contrastFamily','p_Spearman'});
writetable(TcontrastSigContrast, fullfile(outDir, 'STEP05_RT_EEG_Significant_Contrast_q05_WithinContrastFamily.csv'));

TcontrastTop = makeTopTable(TcontrastCorr, 50);
writetable(TcontrastTop, fullfile(outDir, 'STEP05_RT_EEG_Top50_Contrast.csv'));

%% Summary
Tsummary = makeAnalysisSummary(Eraw, Rraw, E, R, Tsubj, TcondCorr, TcontrastCorr, TcondSig, TcontrastSig, TcontrastSigContrast);
writetable(Tsummary, fullfile(outDir, 'STEP05_RT_EEG_AnalysisSummary.csv'));

%% Figures for top findings
try
    makeTopScatterFigures(E, R, TcondTop, TcontrastTop, outDir);
catch ME
    warning('Top scatter figures were not created: %s', ME.message);
end

%% Save workspace and copy
save(fullfile(outDir, 'STEP05_RT_EEG_Correlation_Workspace.mat'), ...
    'Eraw','Rraw','E','R','Tsubj','TcondCorr','TcontrastCorr','TcondSig','TcontrastSig','TcontrastSigContrast','Tsummary');

copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\n================ STEP05 SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% ===================== FUNCTIONS =====================

function fpath = findInput(rootDir, candidates, dialogTitle)
    fpath = '';

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            fpath = candidates{i};
            return;
        end
    end

    % Recursive fallback
    [~, targetName, targetExt] = fileparts(candidates{end});
    pattern = [targetName targetExt];
    files = dir(fullfile(rootDir, '**', pattern));
    if isempty(files)
        files = recursiveDir(rootDir, pattern);
    end
    if ~isempty(files)
        fpath = fullfile(files(1).folder, files(1).name);
        return;
    end

    fprintf('\nCould not find required input automatically.\n');
    [selFile, selPath] = uigetfile('*.csv', dialogTitle);
    if isequal(selFile, 0)
        error('Input file not selected.');
    end
    fpath = fullfile(selPath, selFile);
end

function files = recursiveDir(rootDir, pattern)
    files = [];
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

function E = standardizeEEGTable(T)
    cols = T.Properties.VariableNames;
    colsLow = lower(cols);

    idxSubj = findColumn(colsLow, {'subject','subj'});
    idxCondLabel = findColumn(colsLow, {'conditionlabel','condition_label'});
    idxCond = findColumn(colsLow, {'condition','cond'});
    idxPhase = findColumn(colsLow, {'phaselabel','phase'});
    idxBand = findColumn(colsLow, {'band','freqband','frequencyband'});
    idxChName = findColumn(colsLow, {'channelname','channame','channel','chan'});
    idxChIndex = findColumn(colsLow, {'channelindex','chanindex','chindex','channelidx'});
    idxRel = findColumn(colsLow, {'relpower','relativepower','relative_power'});
    idxLogAbs = findColumn(colsLow, {'logabspower','log_abs_power','logabsolute','log_absolute_power'});
    idxAbs = findColumn(colsLow, {'abspower','absolute_power','absolutepower'});

    if isempty(idxSubj) || isempty(idxBand) || isempty(idxRel)
        error('EEG feature table must contain at least Subject, Band, and RelPower/relative power columns.');
    end

    E = table();
    E.Subject = toText(T.(cols{idxSubj}));

    if ~isempty(idxCondLabel)
        E.ConditionLabel = normalizeConditionLabels(toText(T.(cols{idxCondLabel})));
    elseif ~isempty(idxCond)
        condNum = toNumeric(T.(cols{idxCond}));
        E.ConditionLabel = conditionLabelFromNumber(condNum);
    else
        error('EEG feature table must contain ConditionLabel or Condition.');
    end

    E.Condition = conditionNumberFromLabel(E.ConditionLabel);

    if isempty(idxPhase)
        error('EEG feature table must contain Phase or PhaseLabel.');
    else
        E.PhaseLabel = normalizePhaseLabels(toText(T.(cols{idxPhase})));
    end

    E.Phase = phaseNumberFromLabel(E.PhaseLabel);

    E.Band = normalizeBandLabels(toText(T.(cols{idxBand})));

    if isempty(idxChName)
        if ~isempty(idxChIndex)
            chIdx = toNumeric(T.(cols{idxChIndex}));
            E.ChannelName = cellstr("ch" + string(chIdx));
        else
            E.ChannelName = repmat({'unknown'}, height(T), 1);
        end
    else
        E.ChannelName = toText(T.(cols{idxChName}));
    end

    if isempty(idxChIndex)
        E.ChannelIndex = nan(height(T),1);
    else
        E.ChannelIndex = toNumeric(T.(cols{idxChIndex}));
    end

    E.RelPower = toNumeric(T.(cols{idxRel}));

    if isempty(idxLogAbs)
        if ~isempty(idxAbs)
            tmpAbs = toNumeric(T.(cols{idxAbs}));
            E.LogAbsPower = log(tmpAbs + eps);
        else
            E.LogAbsPower = nan(height(T),1);
        end
    else
        E.LogAbsPower = toNumeric(T.(cols{idxLogAbs}));
    end

    % Optional absolute power
    if isempty(idxAbs)
        E.AbsPower = nan(height(T),1);
    else
        E.AbsPower = toNumeric(T.(cols{idxAbs}));
    end

    % Keep only task conditions and valid primary features.
    keep = ismember(E.ConditionLabel, {'color','orientation','conjunction'}) & ...
           ismember(E.PhaseLabel, {'stimulus','maintenance','retrieval'}) & ...
           isfinite(E.Condition) & isfinite(E.Phase);
    E = E(keep, :);
end

function R = standardizeRTWideTable(T)
    cols = T.Properties.VariableNames;
    colsLow = lower(cols);

    idxSubj = findColumn(colsLow, {'subject','subj'});
    if isempty(idxSubj)
        error('RT wide table must contain Subject.');
    end

    R = table();
    R.Subject = toText(T.(cols{idxSubj}));

    R.color_RT_ms = getRTCol(T, cols, colsLow, {'color_medianrt_ms','color_median_rt_ms','color_rt_ms'});
    R.orientation_RT_ms = getRTCol(T, cols, colsLow, {'orientation_medianrt_ms','orientation_median_rt_ms','orientation_rt_ms'});
    R.conjunction_RT_ms = getRTCol(T, cols, colsLow, {'conjunction_medianrt_ms','conjunction_median_rt_ms','conjunction_rt_ms'});

    % If complete-case flag exists, keep it; otherwise compute.
    idxCC = findColumn(colsLow, {'completecase3conditions','complete_case_3conditions'});
    if isempty(idxCC)
        R.CompleteCase3Conditions = isfinite(R.color_RT_ms) & isfinite(R.orientation_RT_ms) & isfinite(R.conjunction_RT_ms);
    else
        R.CompleteCase3Conditions = logical(toNumeric(T.(cols{idxCC})));
    end

    R.color_minus_orientation_RT_ms = R.color_RT_ms - R.orientation_RT_ms;
    R.color_minus_conjunction_RT_ms = R.color_RT_ms - R.conjunction_RT_ms;
    R.orientation_minus_conjunction_RT_ms = R.orientation_RT_ms - R.conjunction_RT_ms;
end

function x = getRTCol(T, cols, colsLow, candidates)
    idx = findColumn(colsLow, candidates);
    if isempty(idx)
        error('Could not find RT column. Tried: %s', strjoin(candidates, ', '));
    end
    x = toNumeric(T.(cols{idx}));
end

function Tsubj = makeSubjectOverlapTable(eegSubjects, rtSubjects)
    allSubjects = unique([eegSubjects(:); rtSubjects(:)], 'stable');
    inEEG = ismember(allSubjects, eegSubjects);
    inRT = ismember(allSubjects, rtSubjects);

    status = cell(numel(allSubjects),1);
    for i = 1:numel(allSubjects)
        if inEEG(i) && inRT(i)
            status{i} = 'overlap';
        elseif inEEG(i)
            status{i} = 'eeg_only';
        else
            status{i} = 'rt_only';
        end
    end

    Tsubj = table(allSubjects(:), inEEG(:), inRT(:), status, ...
        'VariableNames', {'Subject','In_Final_EEG','In_EEGAligned_RT','OverlapStatus'});
end

function Tcorr = runConditionMatchedCorrelations(E, R)
    conditions = {'color','orientation','conjunction'};
    eegMetrics = {'RelPower','LogAbsPower'};
    eegMetricLabels = {'relative_power','log_absolute_power'};

    combos = unique(E(:, {'ConditionLabel','PhaseLabel','Band','ChannelName','ChannelIndex'}), 'stable');

    rows = {};
    for em = 1:numel(eegMetrics)
        metric = eegMetrics{em};
        metricLabel = eegMetricLabels{em};

        for c = 1:numel(conditions)
            cond = conditions{c};
            rtCol = [cond '_RT_ms'];

            C = combos(strcmp(combos.ConditionLabel, cond), :);

            for i = 1:height(C)
                idxE = strcmp(E.ConditionLabel, cond) & ...
                       strcmp(E.PhaseLabel, C.PhaseLabel{i}) & ...
                       strcmp(E.Band, C.Band{i}) & ...
                       strcmp(E.ChannelName, C.ChannelName{i});

                Es = E(idxE, {'Subject', metric});
                Es.Properties.VariableNames{2} = 'EEGValue';

                Rs = R(:, {'Subject', rtCol});
                Rs.Properties.VariableNames{2} = 'RTValue';

                M = innerjoin(Rs, Es, 'Keys', 'Subject');
                ok = isfinite(M.RTValue) & isfinite(M.EEGValue);
                x = M.RTValue(ok);
                y = M.EEGValue(ok);
                subjectsUsed = M.Subject(ok);

                n = numel(x);
                rho = NaN; p = NaN;
                if n >= 8 && numel(unique(x)) > 2 && numel(unique(y)) > 2
                    [rho, p] = robustSpearman(x, y);
                end

                rows(end+1,:) = {'condition_matched', metricLabel, cond, '', '', '', ...
                    C.PhaseLabel{i}, C.Band{i}, C.ChannelName{i}, C.ChannelIndex(i), ...
                    n, rho, p, median(x,'omitnan'), median(y,'omitnan'), strjoin(subjectsUsed,'|')}; %#ok<AGROW>
            end
        end
    end

    Tcorr = cell2table(rows, 'VariableNames', ...
        {'AnalysisType','EEGMetric','Condition','Contrast','ConditionA','ConditionB', ...
         'Phase','Band','ChannelName','ChannelIndex','NSubjects','SpearmanRho','p_Spearman', ...
         'MedianRT_ms','MedianEEGFeature','SubjectsUsed'});
end

function Tcorr = runContrastCorrelations(E, R)
    contrasts = {
        'color','orientation','color_vs_orientation','color_minus_orientation_RT_ms';
        'color','conjunction','color_vs_conjunction','color_minus_conjunction_RT_ms';
        'orientation','conjunction','orientation_vs_conjunction','orientation_minus_conjunction_RT_ms'
    };

    eegMetrics = {'RelPower','LogAbsPower'};
    eegMetricLabels = {'relative_power','log_absolute_power'};

    combos = unique(E(:, {'PhaseLabel','Band','ChannelName','ChannelIndex'}), 'stable');

    rows = {};
    for em = 1:numel(eegMetrics)
        metric = eegMetrics{em};
        metricLabel = eegMetricLabels{em};

        for c = 1:size(contrasts,1)
            condA = contrasts{c,1};
            condB = contrasts{c,2};
            contrast = contrasts{c,3};
            rtCol = contrasts{c,4};

            for i = 1:height(combos)
                phase = combos.PhaseLabel{i};
                band = combos.Band{i};
                chName = combos.ChannelName{i};
                chIdx = combos.ChannelIndex(i);

                idxA = strcmp(E.ConditionLabel, condA) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, chName);
                idxB = strcmp(E.ConditionLabel, condB) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, chName);

                EA = E(idxA, {'Subject', metric});
                EB = E(idxB, {'Subject', metric});

                if isempty(EA) || isempty(EB)
                    continue;
                end

                EA.Properties.VariableNames{2} = 'EEG_A';
                EB.Properties.VariableNames{2} = 'EEG_B';

                M_EEG = innerjoin(EA, EB, 'Keys', 'Subject');
                M_EEG.EEG_Diff_AminusB = M_EEG.EEG_A - M_EEG.EEG_B;

                Rs = R(:, {'Subject', rtCol});
                Rs.Properties.VariableNames{2} = 'RT_Diff_AminusB';

                M = innerjoin(Rs, M_EEG(:, {'Subject','EEG_Diff_AminusB'}), 'Keys', 'Subject');
                ok = isfinite(M.RT_Diff_AminusB) & isfinite(M.EEG_Diff_AminusB);
                x = M.RT_Diff_AminusB(ok);
                y = M.EEG_Diff_AminusB(ok);
                subjectsUsed = M.Subject(ok);

                n = numel(x);
                rho = NaN; p = NaN;
                if n >= 8 && numel(unique(x)) > 2 && numel(unique(y)) > 2
                    [rho, p] = robustSpearman(x, y);
                end

                rows(end+1,:) = {'contrast_difference', metricLabel, '', contrast, condA, condB, ...
                    phase, band, chName, chIdx, n, rho, p, median(x,'omitnan'), median(y,'omitnan'), strjoin(subjectsUsed,'|')}; %#ok<AGROW>
            end
        end
    end

    Tcorr = cell2table(rows, 'VariableNames', ...
        {'AnalysisType','EEGMetric','Condition','Contrast','ConditionA','ConditionB', ...
         'Phase','Band','ChannelName','ChannelIndex','NSubjects','SpearmanRho','p_Spearman', ...
         'MedianRT_Diff_ms','MedianEEG_Diff','SubjectsUsed'});
end

function Tout = addFDR(Tin, familyCols)
    Tout = Tin;
    Tout.q_FDR_metricFamily = nan(height(Tout),1);

    if isempty(Tout)
        return;
    end

    familyKeys = strings(height(Tout),1);
    for i = 1:height(Tout)
        parts = strings(1,numel(familyCols));
        for j = 1:numel(familyCols)
            val = Tout.(familyCols{j})(i);
            if iscell(val)
                parts(j) = string(val{1});
            else
                parts(j) = string(val);
            end
        end
        familyKeys(i) = strjoin(parts, '|');
    end

    u = unique(familyKeys, 'stable');
    for k = 1:numel(u)
        idx = familyKeys == u(k);
        Tout.q_FDR_metricFamily(idx) = bhFDR(Tout.p_Spearman(idx));
    end
end

function Tout = addFDRByContrast(Tin)
    Tout = Tin;
    Tout.q_FDR_contrastFamily = nan(height(Tout),1);

    if isempty(Tout)
        return;
    end

    eegMetrics = unique(Tout.EEGMetric, 'stable');
    contrasts = unique(Tout.Contrast, 'stable');

    for m = 1:numel(eegMetrics)
        for c = 1:numel(contrasts)
            idx = strcmp(Tout.EEGMetric, eegMetrics{m}) & strcmp(Tout.Contrast, contrasts{c});
            Tout.q_FDR_contrastFamily(idx) = bhFDR(Tout.p_Spearman(idx));
        end
    end
end

function Ttop = makeTopTable(T, nTop)
    if isempty(T)
        Ttop = T;
        return;
    end

    Ttmp = T;
    Ttmp.AbsRho = abs(Ttmp.SpearmanRho);
    Ttmp = sortrows(Ttmp, {'p_Spearman','AbsRho'}, {'ascend','descend'});

    n = min(nTop, height(Ttmp));
    Ttop = Ttmp(1:n,:);
end

function Tsummary = makeAnalysisSummary(Eraw, Rraw, E, R, Tsubj, TcondCorr, TcontrastCorr, TcondSig, TcontrastSig, TcontrastSigContrast)
    rows = {};
    rows(end+1,:) = {'Raw EEG feature rows', height(Eraw)}; %#ok<AGROW>
    rows(end+1,:) = {'Raw RT subject rows', height(Rraw)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG subjects after overlap restriction', numel(unique(E.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'RT subjects after overlap restriction', numel(unique(R.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'Overlap subjects used', sum(strcmp(Tsubj.OverlapStatus,'overlap'))}; %#ok<AGROW>
    rows(end+1,:) = {'Condition-matched tests', height(TcondCorr)}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast-difference tests', height(TcontrastCorr)}; %#ok<AGROW>
    rows(end+1,:) = {'Condition-matched significant q<0.05', height(TcondSig)}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast significant global metric-family q<0.05', height(TcontrastSig)}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast significant within-contrast-family q<0.05', height(TcontrastSigContrast)}; %#ok<AGROW>
    rows(end+1,:) = {'Condition-matched relative-power significant q<0.05', sum(strcmp(TcondSig.EEGMetric,'relative_power'))}; %#ok<AGROW>
    rows(end+1,:) = {'Condition-matched log-absolute-power significant q<0.05', sum(strcmp(TcondSig.EEGMetric,'log_absolute_power'))}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast relative-power significant global q<0.05', sum(strcmp(TcontrastSig.EEGMetric,'relative_power'))}; %#ok<AGROW>
    rows(end+1,:) = {'Contrast log-absolute-power significant global q<0.05', sum(strcmp(TcontrastSig.EEGMetric,'log_absolute_power'))}; %#ok<AGROW>

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function makeTopScatterFigures(E, R, TcondTop, TcontrastTop, outDir)
    figDir = fullfile(outDir, 'TopScatterFigures');
    if ~exist(figDir, 'dir'); mkdir(figDir); end

    % Plot up to 6 top condition-matched findings and 6 top contrast findings.
    nCond = min(6, height(TcondTop));
    for i = 1:nCond
        row = TcondTop(i,:);
        [x, y, xlab, ylab, ttl] = getConditionMatchedXY(E, R, row);
        if numel(x) >= 8
            makeScatter(x, y, xlab, ylab, ttl, fullfile(figDir, sprintf('ConditionMatched_Top%02d.png', i)));
        end
    end

    nCon = min(6, height(TcontrastTop));
    for i = 1:nCon
        row = TcontrastTop(i,:);
        [x, y, xlab, ylab, ttl] = getContrastXY(E, R, row);
        if numel(x) >= 8
            makeScatter(x, y, xlab, ylab, ttl, fullfile(figDir, sprintf('Contrast_Top%02d.png', i)));
        end
    end
end

function [x, y, xlab, ylab, ttl] = getConditionMatchedXY(E, R, row)
    cond = row.Condition{1};
    phase = row.Phase{1};
    band = row.Band{1};
    ch = row.ChannelName{1};
    metricLabel = row.EEGMetric{1};

    if strcmp(metricLabel, 'relative_power')
        metric = 'RelPower';
    else
        metric = 'LogAbsPower';
    end

    rtCol = [cond '_RT_ms'];
    idxE = strcmp(E.ConditionLabel, cond) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, ch);

    Es = E(idxE, {'Subject', metric});
    Es.Properties.VariableNames{2} = 'EEGValue';
    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RTValue';
    M = innerjoin(Rs, Es, 'Keys', 'Subject');
    ok = isfinite(M.RTValue) & isfinite(M.EEGValue);

    x = M.RTValue(ok);
    y = M.EEGValue(ok);

    xlab = sprintf('%s RT (ms)', cond);
    ylab = sprintf('%s %s %s %s', metricLabel, cond, phase, band);
    ttl = sprintf('%s | %s | %s | %s | rho=%.2f, p=%.3g', cond, phase, band, ch, row.SpearmanRho, row.p_Spearman);
end

function [x, y, xlab, ylab, ttl] = getContrastXY(E, R, row)
    condA = row.ConditionA{1};
    condB = row.ConditionB{1};
    contrast = row.Contrast{1};
    phase = row.Phase{1};
    band = row.Band{1};
    ch = row.ChannelName{1};
    metricLabel = row.EEGMetric{1};

    if strcmp(metricLabel, 'relative_power')
        metric = 'RelPower';
    else
        metric = 'LogAbsPower';
    end

    rtCol = [strrep(contrast, '_vs_', '_minus_') '_RT_ms'];

    idxA = strcmp(E.ConditionLabel, condA) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, ch);
    idxB = strcmp(E.ConditionLabel, condB) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, ch);

    EA = E(idxA, {'Subject', metric});
    EB = E(idxB, {'Subject', metric});
    EA.Properties.VariableNames{2} = 'EEG_A';
    EB.Properties.VariableNames{2} = 'EEG_B';

    M_EEG = innerjoin(EA, EB, 'Keys', 'Subject');
    M_EEG.EEG_Diff = M_EEG.EEG_A - M_EEG.EEG_B;

    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RT_Diff';
    M = innerjoin(Rs, M_EEG(:, {'Subject','EEG_Diff'}), 'Keys', 'Subject');

    ok = isfinite(M.RT_Diff) & isfinite(M.EEG_Diff);
    x = M.RT_Diff(ok);
    y = M.EEG_Diff(ok);

    xlab = sprintf('%s reconstructed response-interval difference (ms)', contrast);
    ylab = sprintf('%s EEG difference: %s %s %s', metricLabel, phase, band, ch);
    ttl = sprintf('%s | %s | %s | %s | rho=%.2f, p=%.3g', contrast, phase, band, ch, row.SpearmanRho, row.p_Spearman);
end

function makeScatter(x, y, xlab, ylab, ttl, outPng)
    fig = figure('Color','w','Position',[100 100 700 520]);
    scatter(x, y, 45, 'filled'); hold on;
    lsline;
    xlabel(xlab, 'Interpreter', 'none');
    ylabel(ylab, 'Interpreter', 'none');
    title(ttl, 'Interpreter', 'none');
    grid on;
    saveas(fig, outPng);
    savefig(fig, strrep(outPng, '.png', '.fig'));
    close(fig);
end

function [rho, pval] = robustSpearman(x, y)
    x = x(:);
    y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);

    rho = NaN;
    pval = NaN;

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

function q = bhFDR(p)
    p = double(p(:));
    q = nan(size(p));
    valid = isfinite(p) & p >= 0 & p <= 1;
    pv = p(valid);

    if isempty(pv); return; end

    [ps, order] = sort(pv, 'ascend');
    m = numel(ps);
    qs = ps .* m ./ (1:m)';

    for i = m-1:-1:1
        qs(i) = min(qs(i), qs(i+1));
    end
    qs = min(qs, 1);

    tmp = nan(size(pv));
    tmp(order) = qs;
    q(valid) = tmp;
end

function idx = findColumn(colsLow, names)
    idx = [];
    for i = 1:numel(names)
        hit = find(strcmp(colsLow, lower(names{i})), 1);
        if ~isempty(hit); idx = hit; return; end
    end
    for i = 1:numel(names)
        hit = find(contains(colsLow, lower(names{i})), 1);
        if ~isempty(hit); idx = hit; return; end
    end
end

function x = toNumeric(v)
    if isnumeric(v) || islogical(v)
        x = double(v(:));
    elseif iscell(v)
        x = nan(numel(v),1);
        for i = 1:numel(v)
            if isnumeric(v{i})
                x(i) = double(v{i}(1));
            else
                x(i) = str2double(string(v{i}));
            end
        end
    elseif iscategorical(v)
        x = str2double(string(v(:)));
    else
        x = str2double(string(v(:)));
    end
end

function c = toText(v)
    if iscell(v)
        c = cellfun(@(z) char(string(z)), v(:), 'UniformOutput', false);
    else
        c = cellstr(string(v(:)));
    end
end

function labels = normalizeConditionLabels(labels)
    labels = cellstr(lower(strtrim(string(labels))));
    for i = 1:numel(labels)
        x = labels{i};
        if contains(x, 'color')
            labels{i} = 'color';
        elseif contains(x, 'ori')
            labels{i} = 'orientation';
        elseif contains(x, 'conj')
            labels{i} = 'conjunction';
        elseif strcmp(x,'1')
            labels{i} = 'color';
        elseif strcmp(x,'2')
            labels{i} = 'orientation';
        elseif strcmp(x,'3')
            labels{i} = 'conjunction';
        end
    end
end

function nums = conditionNumberFromLabel(labels)
    nums = nan(numel(labels),1);
    for i = 1:numel(labels)
        if strcmp(labels{i}, 'color')
            nums(i) = 1;
        elseif strcmp(labels{i}, 'orientation')
            nums(i) = 2;
        elseif strcmp(labels{i}, 'conjunction')
            nums(i) = 3;
        end
    end
end

function labels = conditionLabelFromNumber(nums)
    labels = cell(numel(nums),1);
    for i = 1:numel(nums)
        if nums(i) == 1
            labels{i} = 'color';
        elseif nums(i) == 2
            labels{i} = 'orientation';
        elseif nums(i) == 3
            labels{i} = 'conjunction';
        else
            labels{i} = sprintf('condition_%g', nums(i));
        end
    end
end

function labels = normalizePhaseLabels(labels)
    labels = cellstr(lower(strtrim(string(labels))));
    for i = 1:numel(labels)
        x = labels{i};
        if contains(x, 'stim')
            labels{i} = 'stimulus';
        elseif contains(x, 'maint')
            labels{i} = 'maintenance';
        elseif contains(x, 'retr')
            labels{i} = 'retrieval';
        elseif strcmp(x,'1')
            labels{i} = 'stimulus';
        elseif strcmp(x,'2')
            labels{i} = 'maintenance';
        elseif strcmp(x,'3')
            labels{i} = 'retrieval';
        end
    end
end

function nums = phaseNumberFromLabel(labels)
    nums = nan(numel(labels),1);
    for i = 1:numel(labels)
        if strcmp(labels{i}, 'stimulus')
            nums(i) = 1;
        elseif strcmp(labels{i}, 'maintenance')
            nums(i) = 2;
        elseif strcmp(labels{i}, 'retrieval')
            nums(i) = 3;
        end
    end
end

function labels = normalizeBandLabels(labels)
    labels = cellstr(lower(strtrim(string(labels))));
    for i = 1:numel(labels)
        x = labels{i};
        x = strrep(x, 'band_', '');
        labels{i} = x;
    end
end

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

    % Copy scatter folder if it exists.
    scatterDir = fullfile(outDir, 'TopScatterFigures');
    if exist(scatterDir, 'dir')
        resultScatterDir = fullfile(resultOutDir, 'TopScatterFigures');
        if ~exist(resultScatterDir, 'dir'); mkdir(resultScatterDir); end
        imgs = dir(fullfile(scatterDir, '*.*'));
        for i = 1:numel(imgs)
            if imgs(i).isdir; continue; end
            try
                copyfile(fullfile(imgs(i).folder, imgs(i).name), fullfile(resultScatterDir, imgs(i).name));
            catch
            end
        end
    end
end

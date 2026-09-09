%% STEP06A_NEURO_ROI_TOPO_SUMMARY.m
% Neuroscience-oriented ROI/topographic summary for task EEG.
%
% Purpose:
%   Convert channel-level task EEG spectral features into interpretable
%   neuroscience summaries:
%
%   1) ROI-level condition effects:
%      frontal, frontocentral, central, centroparietal, parietal,
%      parieto-occipital, occipital, temporal
%
%   2) Anterior-posterior gradient:
%      posterior ROI activity minus anterior ROI activity
%
%   3) Hemispheric asymmetry:
%      right hemisphere activity minus left hemisphere activity
%
%   4) Phase-band-ROI summaries for manuscript interpretation.
%
% Input:
%   TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv
%
% Output:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP06A_Neuro_ROI_TopoSummary
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP06A_Neuro_ROI_TopoSummary
%
% Main outputs:
%   STEP06A_ROI_SubjectFeatures.csv
%   STEP06A_ROI_Omnibus_Friedman.csv
%   STEP06A_ROI_Pairwise_Signrank.csv
%   STEP06A_ROI_Significant_Omnibus_q05.csv
%   STEP06A_ROI_Significant_Pairwise_q05.csv
%   STEP06A_APGradient_SubjectFeatures.csv
%   STEP06A_APGradient_Omnibus_Friedman.csv
%   STEP06A_HemisphereAsymmetry_SubjectFeatures.csv
%   STEP06A_HemisphereAsymmetry_Omnibus_Friedman.csv
%   STEP06A_NeuroInterpretationSummary.csv
%   STEP06A_Top50_ROI_Omnibus.csv
%   STEP06A_Top50_ROI_Pairwise.csv
%
% Metrics:
%   relative_power      primary
%   log_absolute_power  complementary
%
% Condition convention:
%   color, orientation, conjunction
%
% Notes:
%   The script uses subject-level feature values and aggregates channels
%   within ROI by median. Friedman and Wilcoxon signed-rank tests are then
%   computed across participants.

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
outDir = fullfile(rootDir, 'STEP06A_Neuro_ROI_TopoSummary');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP06A_Neuro_ROI_TopoSummary');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP06A NEURO ROI / TOPOGRAPHIC SUMMARY ===\n');
fprintf('Stage output:\n%s\n', outDir);
fprintf('Result output:\n%s\n', resultOutDir);

%% Locate input
featureFile = findInputFeatureFile(rootDir);
fprintf('\nFeature file:\n%s\n', featureFile);

Traw = readtable(featureFile);
E = standardizeEEGTable(Traw);
writetable(E, fullfile(outDir, 'STEP06A_ChannelFeatures_STANDARDIZED.csv'));

fprintf('Standardized EEG feature rows: %d\n', height(E));
fprintf('Subjects: %d\n', numel(unique(E.Subject)));
fprintf('Channels: %d\n', numel(unique(E.ChannelName)));

%% Add anatomical labels
E.ROI = cell(height(E),1);
E.Hemisphere = cell(height(E),1);
E.APGroup = cell(height(E),1);

for i = 1:height(E)
    E.ROI{i} = channelToROI(E.ChannelName{i});
    E.Hemisphere{i} = channelToHemisphere(E.ChannelName{i});
    E.APGroup{i} = roiToAPGroup(E.ROI{i});
end

TchanMap = unique(E(:, {'ChannelName','ChannelIndex','ROI','Hemisphere','APGroup'}), 'stable');
TchanMap = sortrows(TchanMap, {'ROI','Hemisphere','ChannelName'});
writetable(TchanMap, fullfile(outDir, 'STEP06A_Channel_ROI_Hemisphere_Map.csv'));

%% ROI subject features
Troi = makeROISubjectFeatures(E);
writetable(Troi, fullfile(outDir, 'STEP06A_ROI_SubjectFeatures.csv'));

%% ROI statistics
[TroiOmni, TroiPair] = runFeatureSetStats(Troi, 'ROI', 'ROI');
writetable(TroiOmni, fullfile(outDir, 'STEP06A_ROI_Omnibus_Friedman.csv'));
writetable(TroiPair, fullfile(outDir, 'STEP06A_ROI_Pairwise_Signrank.csv'));

TsigOmni = TroiOmni(TroiOmni.q_FDR_metricFamily < 0.05, :);
TsigOmni = sortrows(TsigOmni, {'EEGMetric','q_FDR_metricFamily','p_Friedman'});
writetable(TsigOmni, fullfile(outDir, 'STEP06A_ROI_Significant_Omnibus_q05.csv'));

TsigPair = TroiPair(TroiPair.q_FDR_metricFamily < 0.05, :);
TsigPair = sortrows(TsigPair, {'EEGMetric','q_FDR_metricFamily','p_Signrank'});
writetable(TsigPair, fullfile(outDir, 'STEP06A_ROI_Significant_Pairwise_q05.csv'));

TsigPairContrast = TroiPair(TroiPair.q_FDR_contrastFamily < 0.05, :);
TsigPairContrast = sortrows(TsigPairContrast, {'EEGMetric','Contrast','q_FDR_contrastFamily','p_Signrank'});
writetable(TsigPairContrast, fullfile(outDir, 'STEP06A_ROI_Significant_Pairwise_q05_ContrastFamily.csv'));

TtopOmni = topTable(TroiOmni, 50, 'p_Friedman');
TtopPair = topTable(TroiPair, 50, 'p_Signrank');
writetable(TtopOmni, fullfile(outDir, 'STEP06A_Top50_ROI_Omnibus.csv'));
writetable(TtopPair, fullfile(outDir, 'STEP06A_Top50_ROI_Pairwise.csv'));

%% Anterior-posterior gradient
Tap = makeAPGradientFeatures(Troi);
writetable(Tap, fullfile(outDir, 'STEP06A_APGradient_SubjectFeatures.csv'));

[TapOmni, TapPair] = runFeatureSetStats(Tap, 'APGradient', 'FeatureLabel');
writetable(TapOmni, fullfile(outDir, 'STEP06A_APGradient_Omnibus_Friedman.csv'));
writetable(TapPair, fullfile(outDir, 'STEP06A_APGradient_Pairwise_Signrank.csv'));

TsigAPOmni = TapOmni(TapOmni.q_FDR_metricFamily < 0.05, :);
TsigAPPair = TapPair(TapPair.q_FDR_metricFamily < 0.05, :);
writetable(TsigAPOmni, fullfile(outDir, 'STEP06A_APGradient_Significant_Omnibus_q05.csv'));
writetable(TsigAPPair, fullfile(outDir, 'STEP06A_APGradient_Significant_Pairwise_q05.csv'));

%% Hemispheric asymmetry
Themi = makeHemisphereAsymmetryFeatures(E);
writetable(Themi, fullfile(outDir, 'STEP06A_HemisphereAsymmetry_SubjectFeatures.csv'));

[ThemiOmni, ThemiPair] = runFeatureSetStats(Themi, 'HemiAsymmetry', 'FeatureLabel');
writetable(ThemiOmni, fullfile(outDir, 'STEP06A_HemisphereAsymmetry_Omnibus_Friedman.csv'));
writetable(ThemiPair, fullfile(outDir, 'STEP06A_HemisphereAsymmetry_Pairwise_Signrank.csv'));

TsigHemiOmni = ThemiOmni(ThemiOmni.q_FDR_metricFamily < 0.05, :);
TsigHemiPair = ThemiPair(ThemiPair.q_FDR_metricFamily < 0.05, :);
writetable(TsigHemiOmni, fullfile(outDir, 'STEP06A_HemisphereAsymmetry_Significant_Omnibus_q05.csv'));
writetable(TsigHemiPair, fullfile(outDir, 'STEP06A_HemisphereAsymmetry_Significant_Pairwise_q05.csv'));

%% Neuro summaries
Tsummary = makeNeuroSummary(E, TchanMap, Troi, TroiOmni, TroiPair, TsigOmni, TsigPair, TsigAPOmni, TsigAPPair, TsigHemiOmni, TsigHemiPair);
writetable(Tsummary, fullfile(outDir, 'STEP06A_NeuroInterpretationSummary.csv'));

Tcounts = makeEffectCountTables(TsigOmni, TsigPair);
writetable(Tcounts, fullfile(outDir, 'STEP06A_ROI_EffectCounts.csv'));

%% Simple figures
try
    makeSummaryFigures(TsigOmni, TsigPair, outDir);
catch ME
    warning('STEP06A summary figures were not created: %s', ME.message);
end

%% Save and copy
save(fullfile(outDir, 'STEP06A_Neuro_ROI_TopoSummary_Workspace.mat'), ...
    'E','TchanMap','Troi','TsigOmni','TsigPair','Tap','TapOmni','TapPair','Themi','ThemiOmni','ThemiPair','Tsummary');

copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\n================ STEP06A SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% ===================== FUNCTIONS =====================

function featureFile = findInputFeatureFile(rootDir)
    candidates = { ...
        fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(rootDir, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(pwd, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv') ...
    };

    featureFile = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            featureFile = candidates{i};
            return;
        end
    end

    fprintf('\nCould not find TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv automatically.\n');
    [selFile, selPath] = uigetfile('*.csv', 'Select TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv');
    if isequal(selFile, 0)
        error('Feature file not selected.');
    end
    featureFile = fullfile(selPath, selFile);
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
        E.ChannelName = cleanChannelName(toText(T.(cols{idxChName})));
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

    if isempty(idxAbs)
        E.AbsPower = nan(height(T),1);
    else
        E.AbsPower = toNumeric(T.(cols{idxAbs}));
    end

    keep = ismember(E.ConditionLabel, {'color','orientation','conjunction'}) & ...
           ismember(E.PhaseLabel, {'stimulus','maintenance','retrieval'}) & ...
           isfinite(E.Condition) & isfinite(E.Phase);
    E = E(keep, :);
end

function Troi = makeROISubjectFeatures(E)
    rows = {};
    metrics = {'RelPower','LogAbsPower'};
    metricLabels = {'relative_power','log_absolute_power'};

    keys = unique(E(:, {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band','ROI'}), 'stable');

    for m = 1:numel(metrics)
        metric = metrics{m};
        metricLabel = metricLabels{m};

        for i = 1:height(keys)
            idx = strcmp(E.Subject, keys.Subject{i}) & E.Condition == keys.Condition(i) & ...
                  E.Phase == keys.Phase(i) & strcmp(E.Band, keys.Band{i}) & strcmp(E.ROI, keys.ROI{i});

            vals = E.(metric)(idx);
            chs = unique(E.ChannelName(idx));
            val = median(vals, 'omitnan');

            rows(end+1,:) = {keys.Subject{i}, keys.Condition(i), keys.ConditionLabel{i}, ...
                keys.Phase(i), keys.PhaseLabel{i}, keys.Band{i}, keys.ROI{i}, metricLabel, ...
                val, numel(chs), strjoin(chs,'|')}; %#ok<AGROW>
        end
    end

    Troi = cell2table(rows, 'VariableNames', ...
        {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band','ROI','EEGMetric','FeatureValue','NChannelsInROI','ChannelsInROI'});
end

function [Tomni, Tpair] = runFeatureSetStats(Tfeat, analysisName, featureCol)
    metrics = unique(Tfeat.EEGMetric, 'stable');
    phases = unique(Tfeat.PhaseLabel, 'stable');
    bands = unique(Tfeat.Band, 'stable');
    features = unique(Tfeat.(featureCol), 'stable');

    omniRows = {};
    pairRows = {};

    contrasts = {
        'color','orientation','color_vs_orientation';
        'color','conjunction','color_vs_conjunction';
        'orientation','conjunction','orientation_vs_conjunction'
    };

    for m = 1:numel(metrics)
        for p = 1:numel(phases)
            for b = 1:numel(bands)
                for f = 1:numel(features)
                    idx = strcmp(Tfeat.EEGMetric, metrics{m}) & strcmp(Tfeat.PhaseLabel, phases{p}) & ...
                          strcmp(Tfeat.Band, bands{b}) & strcmp(Tfeat.(featureCol), features{f});

                    S = Tfeat(idx, :);
                    [X, subjects] = wideByCondition(S);
                    ok = all(isfinite(X),2);
                    Xok = X(ok,:);
                    subjectsUsed = subjects(ok);

                    n = size(Xok,1);
                    pF = NaN; chi2 = NaN; W = NaN;
                    medColor = NaN; medOri = NaN; medConj = NaN;
                    maxCondition = '';

                    if n >= 3
                        try
                            [pF, tbl] = friedman(Xok, 1, 'off');
                            chi2 = extractFriedmanChiSquare(tbl);
                        catch
                            [pF, chi2] = friedmanManual(Xok);
                        end

                        if isfinite(chi2)
                            W = chi2 / (n * 2);
                        end

                        medVals = median(Xok, 1, 'omitnan');
                        medColor = medVals(1);
                        medOri = medVals(2);
                        medConj = medVals(3);

                        [~, imax] = max(medVals);
                        labels = {'color','orientation','conjunction'};
                        maxCondition = labels{imax};
                    end

                    omniRows(end+1,:) = {analysisName, metrics{m}, phases{p}, bands{b}, features{f}, ...
                        n, pF, chi2, 2, W, medColor, medOri, medConj, maxCondition, strjoin(subjectsUsed,'|')}; %#ok<AGROW>

                    for c = 1:size(contrasts,1)
                        condA = contrasts{c,1};
                        condB = contrasts{c,2};
                        contrast = contrasts{c,3};

                        [X2, subjects2] = wideBySelectedConditions(S, {condA, condB});
                        ok2 = all(isfinite(X2),2);
                        X2 = X2(ok2,:);
                        subjects2 = subjects2(ok2);

                        n2 = size(X2,1);
                        pW = NaN; signedRank = NaN; zval = NaN;
                        medA = NaN; medB = NaN; medDiff = NaN; direction = '';

                        if n2 >= 3 && any(abs(X2(:,1)-X2(:,2)) > 0)
                            try
                                [pW, ~, stats] = signrank(X2(:,1), X2(:,2));
                                if isstruct(stats)
                                    if isfield(stats,'signedrank'); signedRank = stats.signedrank; end
                                    if isfield(stats,'zval'); zval = stats.zval; end
                                end
                            catch
                                pW = NaN;
                            end

                            diffAB = X2(:,1) - X2(:,2);
                            medA = median(X2(:,1),'omitnan');
                            medB = median(X2(:,2),'omitnan');
                            medDiff = median(diffAB,'omitnan');

                            if medDiff > 0
                                direction = [condA '_greater_than_' condB];
                            elseif medDiff < 0
                                direction = [condB '_greater_than_' condA];
                            else
                                direction = 'no_median_difference';
                            end
                        end

                        pairRows(end+1,:) = {analysisName, metrics{m}, contrast, condA, condB, phases{p}, bands{b}, features{f}, ...
                            n2, pW, signedRank, zval, medA, medB, medDiff, direction, strjoin(subjects2,'|')}; %#ok<AGROW>
                    end
                end
            end
        end
    end

    Tomni = cell2table(omniRows, 'VariableNames', ...
        {'AnalysisType','EEGMetric','Phase','Band','FeatureLabel','NSubjects','p_Friedman','ChiSquare','DF','KendallW', ...
         'Median_Color','Median_Orientation','Median_Conjunction','MaxCondition','SubjectsUsed'});

    Tpair = cell2table(pairRows, 'VariableNames', ...
        {'AnalysisType','EEGMetric','Contrast','ConditionA','ConditionB','Phase','Band','FeatureLabel','NSubjects','p_Signrank','SignedRank','ZValue', ...
         'Median_A','Median_B','MedianDiff_AminusB','DirectionByMedian','SubjectsUsed'});

    Tomni.q_FDR_metricFamily = nan(height(Tomni),1);
    metricsU = unique(Tomni.EEGMetric, 'stable');
    for m = 1:numel(metricsU)
        idx = strcmp(Tomni.EEGMetric, metricsU{m});
        Tomni.q_FDR_metricFamily(idx) = bhFDR(Tomni.p_Friedman(idx));
    end

    Tpair.q_FDR_metricFamily = nan(height(Tpair),1);
    Tpair.q_FDR_contrastFamily = nan(height(Tpair),1);

    metricsU = unique(Tpair.EEGMetric, 'stable');
    for m = 1:numel(metricsU)
        idx = strcmp(Tpair.EEGMetric, metricsU{m});
        Tpair.q_FDR_metricFamily(idx) = bhFDR(Tpair.p_Signrank(idx));

        contrastsU = unique(Tpair.Contrast(idx), 'stable');
        for c = 1:numel(contrastsU)
            idx2 = idx & strcmp(Tpair.Contrast, contrastsU{c});
            Tpair.q_FDR_contrastFamily(idx2) = bhFDR(Tpair.p_Signrank(idx2));
        end
    end
end

function Tap = makeAPGradientFeatures(Troi)
    % posterior minus anterior. Intermediate ROIs are not used.
    anteriorROIs = {'frontal','frontocentral'};
    posteriorROIs = {'centroparietal','parietal','parieto_occipital','occipital'};

    keys = unique(Troi(:, {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band','EEGMetric'}), 'stable');

    rows = {};
    for i = 1:height(keys)
        idxBase = strcmp(Troi.Subject, keys.Subject{i}) & Troi.Condition == keys.Condition(i) & ...
                  Troi.Phase == keys.Phase(i) & strcmp(Troi.Band, keys.Band{i}) & strcmp(Troi.EEGMetric, keys.EEGMetric{i});

        A = Troi(idxBase & ismember(Troi.ROI, anteriorROIs), :);
        P = Troi(idxBase & ismember(Troi.ROI, posteriorROIs), :);

        aval = median(A.FeatureValue, 'omitnan');
        pval = median(P.FeatureValue, 'omitnan');
        grad = pval - aval;

        rows(end+1,:) = {keys.Subject{i}, keys.Condition(i), keys.ConditionLabel{i}, keys.Phase(i), keys.PhaseLabel{i}, ...
            keys.Band{i}, keys.EEGMetric{i}, 'posterior_minus_anterior', grad, aval, pval, height(A), height(P)}; %#ok<AGROW>
    end

    Tap = cell2table(rows, 'VariableNames', ...
        {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band','EEGMetric','FeatureLabel','FeatureValue', ...
         'AnteriorValue','PosteriorValue','NAnteriorROIs','NPosteriorROIs'});
end

function Themi = makeHemisphereAsymmetryFeatures(E)
    keys = unique(E(:, {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band'}), 'stable');
    metrics = {'RelPower','LogAbsPower'};
    metricLabels = {'relative_power','log_absolute_power'};

    rows = {};
    for m = 1:numel(metrics)
        metric = metrics{m};
        metricLabel = metricLabels{m};

        for i = 1:height(keys)
            idxBase = strcmp(E.Subject, keys.Subject{i}) & E.Condition == keys.Condition(i) & ...
                      E.Phase == keys.Phase(i) & strcmp(E.Band, keys.Band{i});

            L = E(idxBase & strcmp(E.Hemisphere,'left'), :);
            R = E(idxBase & strcmp(E.Hemisphere,'right'), :);

            lval = median(L.(metric), 'omitnan');
            rval = median(R.(metric), 'omitnan');
            asym = rval - lval;

            rows(end+1,:) = {keys.Subject{i}, keys.Condition(i), keys.ConditionLabel{i}, keys.Phase(i), keys.PhaseLabel{i}, ...
                keys.Band{i}, metricLabel, 'right_minus_left', asym, lval, rval, height(L), height(R)}; %#ok<AGROW>
        end
    end

    Themi = cell2table(rows, 'VariableNames', ...
        {'Subject','Condition','ConditionLabel','Phase','PhaseLabel','Band','EEGMetric','FeatureLabel','FeatureValue', ...
         'LeftValue','RightValue','NLeftChannels','NRightChannels'});
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
                X(s,c) = median(S.FeatureValue(idx), 'omitnan');
            end
        end
    end
end

function Tsummary = makeNeuroSummary(E, TchanMap, Troi, TroiOmni, TroiPair, TsigOmni, TsigPair, TsigAPOmni, TsigAPPair, TsigHemiOmni, TsigHemiPair)
    rows = {};

    rows(end+1,:) = {'Input standardized EEG rows', height(E)}; %#ok<AGROW>
    rows(end+1,:) = {'Subjects', numel(unique(E.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'Channels mapped', height(TchanMap)}; %#ok<AGROW>
    rows(end+1,:) = {'ROI subject-feature rows', height(Troi)}; %#ok<AGROW>
    rows(end+1,:) = {'ROI omnibus tests', height(TroiOmni)}; %#ok<AGROW>
    rows(end+1,:) = {'ROI pairwise tests', height(TroiPair)}; %#ok<AGROW>
    rows(end+1,:) = {'ROI significant omnibus q<0.05', height(TsigOmni)}; %#ok<AGROW>
    rows(end+1,:) = {'ROI significant pairwise q<0.05 metric-family', height(TsigPair)}; %#ok<AGROW>
    rows(end+1,:) = {'AP-gradient significant omnibus q<0.05', height(TsigAPOmni)}; %#ok<AGROW>
    rows(end+1,:) = {'AP-gradient significant pairwise q<0.05', height(TsigAPPair)}; %#ok<AGROW>
    rows(end+1,:) = {'Hemisphere-asymmetry significant omnibus q<0.05', height(TsigHemiOmni)}; %#ok<AGROW>
    rows(end+1,:) = {'Hemisphere-asymmetry significant pairwise q<0.05', height(TsigHemiPair)}; %#ok<AGROW>

    if ~isempty(TsigOmni)
        rows(end+1,:) = {'ROI significant omnibus relative_power', sum(strcmp(TsigOmni.EEGMetric,'relative_power'))}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus log_absolute_power', sum(strcmp(TsigOmni.EEGMetric,'log_absolute_power'))}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus maintenance', sum(strcmp(TsigOmni.Phase,'maintenance'))}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus retrieval', sum(strcmp(TsigOmni.Phase,'retrieval'))}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus stimulus', sum(strcmp(TsigOmni.Phase,'stimulus'))}; %#ok<AGROW>
    else
        rows(end+1,:) = {'ROI significant omnibus relative_power', 0}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus log_absolute_power', 0}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus maintenance', 0}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus retrieval', 0}; %#ok<AGROW>
        rows(end+1,:) = {'ROI significant omnibus stimulus', 0}; %#ok<AGROW>
    end

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function Tcounts = makeEffectCountTables(TsigOmni, TsigPair)
    rows = {};

    % Omnibus counts
    if ~isempty(TsigOmni)
        rows = appendCountRows(rows, TsigOmni, 'omnibus', 'Phase');
        rows = appendCountRows(rows, TsigOmni, 'omnibus', 'Band');
        rows = appendCountRows(rows, TsigOmni, 'omnibus', 'FeatureLabel');
        rows = appendCountRows(rows, TsigOmni, 'omnibus', 'MaxCondition');
        rows = appendCountRows(rows, TsigOmni, 'omnibus', 'EEGMetric');
    end

    % Pairwise counts
    if ~isempty(TsigPair)
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'Phase');
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'Band');
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'FeatureLabel');
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'Contrast');
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'EEGMetric');
        rows = appendCountRows(rows, TsigPair, 'pairwise', 'DirectionByMedian');
    end

    if isempty(rows)
        Tcounts = cell2table(cell(0,4), 'VariableNames', {'EffectSet','GroupingVariable','Level','Count'});
    else
        Tcounts = cell2table(rows, 'VariableNames', {'EffectSet','GroupingVariable','Level','Count'});
    end
end

function rows = appendCountRows(rows, T, effectSet, varName)
    vals = T.(varName);
    if isnumeric(vals)
        vals = cellstr(string(vals));
    end
    u = unique(vals, 'stable');
    for i = 1:numel(u)
        if iscell(u)
            level = u{i};
            count = sum(strcmp(vals, level));
        else
            level = char(string(u(i)));
            count = sum(vals == u(i));
        end
        rows(end+1,:) = {effectSet, varName, level, count}; %#ok<AGROW>
    end
end

function makeSummaryFigures(TsigOmni, TsigPair, outDir)
    figDir = fullfile(outDir, 'SummaryFigures');
    if ~exist(figDir, 'dir'); mkdir(figDir); end

    if ~isempty(TsigOmni)
        makeCountBar(TsigOmni.Phase, 'Significant ROI omnibus effects by phase', fullfile(figDir, 'ROI_Omnibus_ByPhase.png'));
        makeCountBar(TsigOmni.Band, 'Significant ROI omnibus effects by band', fullfile(figDir, 'ROI_Omnibus_ByBand.png'));
        makeCountBar(TsigOmni.FeatureLabel, 'Significant ROI omnibus effects by ROI/feature', fullfile(figDir, 'ROI_Omnibus_ByROI.png'));
    end

    if ~isempty(TsigPair)
        makeCountBar(TsigPair.Phase, 'Significant ROI pairwise effects by phase', fullfile(figDir, 'ROI_Pairwise_ByPhase.png'));
        makeCountBar(TsigPair.Band, 'Significant ROI pairwise effects by band', fullfile(figDir, 'ROI_Pairwise_ByBand.png'));
        makeCountBar(TsigPair.Contrast, 'Significant ROI pairwise effects by contrast', fullfile(figDir, 'ROI_Pairwise_ByContrast.png'));
    end
end

function makeCountBar(vals, ttl, outPng)
    if iscell(vals)
        cats = categorical(vals);
    else
        cats = categorical(string(vals));
    end

    [u,~,ic] = unique(cats);
    counts = accumarray(ic, 1);

    fig = figure('Color','w','Position',[100 100 800 450]);
    bar(counts);
    set(gca, 'XTick', 1:numel(u), 'XTickLabel', cellstr(string(u)), 'XTickLabelRotation', 45);
    ylabel('Count');
    title(ttl, 'Interpreter', 'none');
    grid on;
    saveas(fig, outPng);
    savefig(fig, strrep(outPng, '.png', '.fig'));
    close(fig);
end

function Ttop = topTable(T, nTop, pCol)
    if isempty(T)
        Ttop = T;
        return;
    end

    Ttmp = T;
    if ismember('KendallW', Ttmp.Properties.VariableNames)
        Ttmp.AbsEffect = abs(Ttmp.KendallW);
    elseif ismember('MedianDiff_AminusB', Ttmp.Properties.VariableNames)
        Ttmp.AbsEffect = abs(Ttmp.MedianDiff_AminusB);
    else
        Ttmp.AbsEffect = nan(height(Ttmp),1);
    end

    Ttmp = sortrows(Ttmp, {pCol,'AbsEffect'}, {'ascend','descend'});
    Ttop = Ttmp(1:min(nTop,height(Ttmp)), :);
end

function roi = channelToROI(ch)
    ch = cleanOneChannel(ch);
    low = lower(ch);

    if startsWith(low, 'fp') || startsWith(low, 'af') || startsWith(low, 'f') && ~startsWith(low,'fc') && ~startsWith(low,'ft')
        roi = 'frontal';
    elseif startsWith(low, 'fc') || startsWith(low, 'ft')
        roi = 'frontocentral';
    elseif startsWith(low, 'c') && ~startsWith(low,'cp')
        roi = 'central';
    elseif startsWith(low, 'cp') || startsWith(low, 'tp')
        roi = 'centroparietal';
    elseif startsWith(low, 'p') && ~startsWith(low,'po')
        roi = 'parietal';
    elseif startsWith(low, 'po')
        roi = 'parieto_occipital';
    elseif startsWith(low, 'o')
        roi = 'occipital';
    elseif startsWith(low, 't')
        roi = 'temporal';
    else
        roi = 'other';
    end
end

function hemi = channelToHemisphere(ch)
    ch = cleanOneChannel(ch);
    low = lower(ch);

    if endsWith(low,'z')
        hemi = 'midline';
        return;
    end

    toks = regexp(low, '(\d+)$', 'tokens', 'once');
    if isempty(toks)
        hemi = 'unknown';
        return;
    end

    num = str2double(toks{1});
    if mod(num,2) == 1
        hemi = 'left';
    else
        hemi = 'right';
    end
end

function ap = roiToAPGroup(roi)
    if ismember(roi, {'frontal','frontocentral'})
        ap = 'anterior';
    elseif ismember(roi, {'centroparietal','parietal','parieto_occipital','occipital'})
        ap = 'posterior';
    else
        ap = 'intermediate_or_other';
    end
end

function chs = cleanChannelName(chs)
    chs = cellstr(string(chs));
    for i = 1:numel(chs)
        chs{i} = cleanOneChannel(chs{i});
    end
end

function ch = cleanOneChannel(ch)
    ch = char(string(ch));
    ch = strtrim(ch);
    ch = regexprep(ch, '^EEG\s*', '', 'ignorecase');
    ch = regexprep(ch, '\s+', '');
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

    figDir = fullfile(outDir, 'SummaryFigures');
    if exist(figDir, 'dir')
        resultFigDir = fullfile(resultOutDir, 'SummaryFigures');
        if ~exist(resultFigDir, 'dir'); mkdir(resultFigDir); end
        imgs = dir(fullfile(figDir, '*.*'));
        for i = 1:numel(imgs)
            if imgs(i).isdir; continue; end
            try
                copyfile(fullfile(imgs(i).folder, imgs(i).name), fullfile(resultFigDir, imgs(i).name));
            catch
            end
        end
    end
end

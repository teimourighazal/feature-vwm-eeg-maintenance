%% STEP06D5_FINAL_NEURO_FIGURE_TABLE_PACKAGE_STRICTCSV.m
% Strict CSV version of STEP06D.
%
% Why this version exists:
%   In some MATLAB versions, readtable may parse STEP06C contrast files
%   incorrectly and treat subject IDs such as s14, s16, s17 as column names.
%   This script avoids that problem by reading the STEP06C CSV files with a
%   strict line-by-line CSV reader and explicitly assigned column names.
%
% Primary output:
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP06D5_Final_NeuroFigureTablePackage
%
% Inputs:
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP06C_HypothesisDriven_NeuralIndices
%
% Main outputs:
%   STEP06D5_InputColumnAudit.csv
%   STEP06D_FinalNeuroResultSummary.csv
%   STEP06D_DirectionalConsistency.csv
%   STEP06D_ConditionStats_Final.csv
%   STEP06D_ContrastStats_Final.csv
%   STEP06D_RT_EEG_Canonical_Final.csv
%   STEP06D_FinalFigurePanelPlan.csv
%   STEP06D_ManuscriptResults_English.txt
%   STEP06D_ManuscriptResults_Persian.txt

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
resultRoot = fullfile(rootDir, 'Result');
inDir = fullfile(resultRoot, 'STEP06C_HypothesisDriven_NeuralIndices');
outDir = fullfile(resultRoot, 'STEP06D5_Final_NeuroFigureTablePackage');
figDir = fullfile(outDir, 'Figures');

if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(figDir, 'dir'); mkdir(figDir); end

fprintf('\n=== STEP06D5 FINAL NEURO FIGURE/TABLE PACKAGE - STRICT CSV ===\n');
fprintf('Input folder:\n%s\n', inDir);
fprintf('Output folder:\n%s\n', outDir);

%% Strict inputs from STEP06C only
idxFile = fullfile(inDir, 'STEP06C_CompositeIndex_SubjectValues.csv');
condFile = fullfile(inDir, 'STEP06C_CompositeIndex_ConditionStats.csv');
contrastFile = fullfile(inDir, 'STEP06C_CompositeIndex_ContrastStats.csv');
rtFile = fullfile(inDir, 'STEP06C_RT_EEG_CanonicalCorrelations.csv');

if ~exist(idxFile, 'file'); idxFile = selectFile('STEP06C_CompositeIndex_SubjectValues.csv'); end
if ~exist(condFile, 'file'); condFile = selectFile('STEP06C_CompositeIndex_ConditionStats.csv'); end
if ~exist(contrastFile, 'file'); contrastFile = selectFile('STEP06C_CompositeIndex_ContrastStats.csv'); end
if ~exist(rtFile, 'file'); rtFile = selectFile('STEP06C_RT_EEG_CanonicalCorrelations.csv'); end

Tidx = readStrictCSV(idxFile, {'Subject','IndexName','ConditionLabel','Phase','Band','EEGMetric','SpatialDefinition','IndexValue','NComponents'});
Tcond = readStrictCSV(condFile, {'IndexName','NSubjects','p_Friedman','ChiSquare','KendallW','Median_Color','Median_Orientation','Median_Conjunction','MaxCondition','SubjectsUsed'});
Tcontrast = readStrictCSV(contrastFile, {'IndexName','Contrast','ConditionA','ConditionB','NSubjects','p_Signrank','Median_A','Median_B','MedianDiff_AminusB','DirectionByMedian','SubjectsUsed'});
Trt = readStrictCSV(rtFile, {'CanonicalAnalysis','BehaviorContrastOrCondition','Phase','Band','EEGMetric','SpatialFeature','NSubjects','SpearmanRho','p_Spearman','MedianRT_or_RTDiff_ms','MedianEEG_or_EEGDiff','SubjectsUsed'});

% Convert numeric columns explicitly.
Tidx = forceNumericColumns(Tidx, {'IndexValue','NComponents'});
Tcond = forceNumericColumns(Tcond, {'NSubjects','p_Friedman','ChiSquare','KendallW','Median_Color','Median_Orientation','Median_Conjunction'});
Tcontrast = forceNumericColumns(Tcontrast, {'NSubjects','p_Signrank','Median_A','Median_B','MedianDiff_AminusB'});
Trt = forceNumericColumns(Trt, {'NSubjects','SpearmanRho','p_Spearman','MedianRT_or_RTDiff_ms','MedianEEG_or_EEGDiff'});

Taudit = makeColumnAudit(Tidx, Tcond, Tcontrast, Trt);
writetable(Taudit, fullfile(outDir, 'STEP06D5_InputColumnAudit.csv'));

%% Directional consistency
Tdir = computeDirectionalConsistency(Tidx, Tcontrast);
writetable(Tdir, fullfile(outDir, 'STEP06D_DirectionalConsistency.csv'));

%% Final clean tables
TcondFinal = cleanConditionStats(Tcond, Tdir);
TcontrastFinal = cleanContrastStats(Tcontrast, Tdir);
TrtFinal = cleanRTCanonical(Trt);

writetable(TcondFinal, fullfile(outDir, 'STEP06D_ConditionStats_Final.csv'));
writetable(TcontrastFinal, fullfile(outDir, 'STEP06D_ContrastStats_Final.csv'));
writetable(TrtFinal, fullfile(outDir, 'STEP06D_RT_EEG_Canonical_Final.csv'));

%% Figure panel and summary
Tpanel = makeFigurePanelPlan();
writetable(Tpanel, fullfile(outDir, 'STEP06D_FinalFigurePanelPlan.csv'));

Tsummary = makeFinalSummary(TcondFinal, TcontrastFinal, TrtFinal, Tdir);
writetable(Tsummary, fullfile(outDir, 'STEP06D_FinalNeuroResultSummary.csv'));

%% Texts
englishText = makeEnglishResults(TcondFinal, TcontrastFinal, TrtFinal);
persianText = makePersianResults(TcondFinal, TcontrastFinal, TrtFinal);

writeText(fullfile(outDir, 'STEP06D_ManuscriptResults_English.txt'), englishText);
writeText(fullfile(outDir, 'STEP06D_ManuscriptResults_Persian.txt'), persianText);

%% Figures
try
    makeIndexFigures(Tidx, figDir);
    makeRTSummaryFigure(TrtFinal, figDir);
catch ME
    warning('Some STEP06D5 figures were not created: %s', ME.message);
end

save(fullfile(outDir, 'STEP06D5_Final_NeuroFigureTablePackage_Workspace.mat'), ...
    'Tidx','Tcond','Tcontrast','Trt','Tdir','TcondFinal','TcontrastFinal','TrtFinal','Tpanel','Tsummary','englishText','persianText');

fprintf('\n================ STEP06D5 SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved directly in Result:\n%s\n', outDir);

%% ===================== FUNCTIONS =====================

function fpath = selectFile(fileName)
    [selFile, selPath] = uigetfile('*.csv', ['Select ' fileName]);
    if isequal(selFile, 0)
        error('Required input file was not selected: %s', fileName);
    end
    fpath = fullfile(selPath, selFile);
end

function T = readStrictCSV(fpath, expectedNames)
    fprintf('Strict-reading %s\n', fpath);

    fid = fopen(fpath, 'r');
    if fid < 0
        error('Cannot open file: %s', fpath);
    end

    header = fgetl(fid); %#ok<NASGU>
    rows = {};
    nExpected = numel(expectedNames);

    lineNo = 1;
    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        lineNo = lineNo + 1;

        if isempty(strtrim(line))
            continue;
        end

        parts = strsplit(line, ',');

        % If somehow there are extra commas, join extras into the last column.
        if numel(parts) > nExpected
            firstParts = parts(1:nExpected-1);
            lastPart = strjoin(parts(nExpected:end), ',');
            parts = [firstParts, {lastPart}];
        end

        if numel(parts) < nExpected
            parts(end+1:nExpected) = {''};
        end

        rows(end+1, :) = parts(1:nExpected); %#ok<AGROW>
    end

    fclose(fid);

    if isempty(rows)
        T = cell2table(cell(0,nExpected), 'VariableNames', expectedNames);
    else
        T = cell2table(rows, 'VariableNames', expectedNames);
    end
end

function T = forceNumericColumns(T, colNames)
    for i = 1:numel(colNames)
        col = colNames{i};
        if ismember(col, T.Properties.VariableNames)
            T.(col) = toDoubleColumn(T.(col));
        end
    end
end

function x = toDoubleColumn(v)
    if isnumeric(v) || islogical(v)
        x = double(v(:));
        return;
    end

    if iscell(v)
        x = nan(numel(v),1);
        for i = 1:numel(v)
            s = string(v{i});
            s = strrep(s, '"', '');
            if ismissing(s) || strlength(s) == 0 || strcmpi(s,'nan') || strcmpi(s,'<missing>')
                x(i) = NaN;
            else
                x(i) = str2double(s);
            end
        end
        return;
    end

    s = string(v(:));
    x = str2double(s);
end

function Taudit = makeColumnAudit(Tidx, Tcond, Tcontrast, Trt)
    rows = {
        'CompositeIndex_SubjectValues', strjoin(Tidx.Properties.VariableNames, '|'), height(Tidx);
        'CompositeIndex_ConditionStats', strjoin(Tcond.Properties.VariableNames, '|'), height(Tcond);
        'CompositeIndex_ContrastStats', strjoin(Tcontrast.Properties.VariableNames, '|'), height(Tcontrast);
        'RT_EEG_CanonicalCorrelations', strjoin(Trt.Properties.VariableNames, '|'), height(Trt)
        };
    Taudit = cell2table(rows, 'VariableNames', {'InputTable','ColumnList','NRows'});
end

function Tdir = computeDirectionalConsistency(Tidx, Tcontrast)
    rows = {};

    predictions = {
        'posterior_alpha_log_power', 'color', 'color_dominant', 'color should be highest';
        'posterior_gamma_relative_power', 'conjunction', 'conjunction_dominant', 'conjunction should be highest';
        'posterior_minus_anterior_alpha_relative_power', 'color', 'color_dominant', 'color should show strongest posterior-minus-anterior alpha'
    };

    for i = 1:size(predictions,1)
        idxName = predictions{i,1};
        expectedMax = predictions{i,2};
        expectedLabel = predictions{i,3};
        rationale = predictions{i,4};

        S = Tidx(strcmp(Tidx.IndexName, idxName), :);
        [X, subjects] = wideByCondition(S);

        ok = all(isfinite(X),2);
        Xok = X(ok,:);
        subjectsOk = subjects(ok);

        labels = {'color','orientation','conjunction'};
        [~, imax] = max(Xok, [], 2);
        subjectMaxLabels = labels(imax);

        isExpectedMax = strcmp(subjectMaxLabels(:), expectedMax);
        n = numel(isExpectedMax);
        nExpected = sum(isExpectedMax);
        pctExpected = 100 * nExpected / max(n,1);

        rows(end+1,:) = {idxName, 'highest_condition', expectedLabel, expectedMax, '', '', ...
            n, nExpected, pctExpected, NaN, NaN, rationale, strjoin(subjectsOk(isExpectedMax),'|'), strjoin(subjectsOk(~isExpectedMax),'|')}; %#ok<AGROW>

        C = Tcontrast(strcmp(Tcontrast.IndexName, idxName), :);
        for j = 1:height(C)
            condA = C.ConditionA{j};
            condB = C.ConditionB{j};
            contrast = C.Contrast{j};

            [X2, subjects2] = wideBySelectedConditions(S, {condA, condB});
            ok2 = all(isfinite(X2),2);
            X2 = X2(ok2,:);
            subjects2 = subjects2(ok2);

            medDiff = median(X2(:,1) - X2(:,2), 'omitnan');

            if medDiff > 0
                expectedDir = [condA '_greater_than_' condB];
                isDir = X2(:,1) > X2(:,2);
            elseif medDiff < 0
                expectedDir = [condB '_greater_than_' condA];
                isDir = X2(:,2) > X2(:,1);
            else
                expectedDir = 'no_median_difference';
                isDir = abs(X2(:,1)-X2(:,2)) == 0;
            end

            n2 = numel(isDir);
            nDir = sum(isDir);
            pctDir = 100*nDir/max(n2,1);

            rows(end+1,:) = {idxName, 'pairwise_direction', expectedDir, '', contrast, C.DirectionByMedian{j}, ...
                n2, nDir, pctDir, C.p_Signrank(j), C.MedianDiff_AminusB(j), ...
                ['Subject-level consistency for ' contrast], strjoin(subjects2(isDir),'|'), strjoin(subjects2(~isDir),'|')}; %#ok<AGROW>
        end
    end

    Tdir = cell2table(rows, 'VariableNames', ...
        {'IndexName','ConsistencyType','ExpectedPattern','ExpectedMaxCondition','Contrast','MedianDirection', ...
         'NSubjects','NFollowingPattern','PercentFollowingPattern','p_Signrank','MedianDiff_AminusB', ...
         'Rationale','SubjectsFollowingPattern','SubjectsNotFollowingPattern'});
end

function Tfinal = cleanConditionStats(Tcond, Tdir)
    Tfinal = Tcond;
    Tfinal.DirectionConsistency_PercentExpectedMax = nan(height(Tfinal),1);
    Tfinal.DirectionConsistency_NExpectedMax = nan(height(Tfinal),1);

    for i = 1:height(Tfinal)
        idx = strcmp(Tdir.IndexName, Tfinal.IndexName{i}) & strcmp(Tdir.ConsistencyType, 'highest_condition');
        if any(idx)
            Tfinal.DirectionConsistency_PercentExpectedMax(i) = Tdir.PercentFollowingPattern(find(idx,1));
            Tfinal.DirectionConsistency_NExpectedMax(i) = Tdir.NFollowingPattern(find(idx,1));
        end
    end

    Tfinal = sortrows(Tfinal, {'p_Friedman','KendallW'}, {'ascend','descend'});
end

function Tfinal = cleanContrastStats(Tcontrast, Tdir)
    Tfinal = Tcontrast;
    Tfinal.DirectionConsistency_Percent = nan(height(Tfinal),1);
    Tfinal.DirectionConsistency_N = nan(height(Tfinal),1);

    for i = 1:height(Tfinal)
        idx = strcmp(Tdir.IndexName, Tfinal.IndexName{i}) & strcmp(Tdir.ConsistencyType, 'pairwise_direction') & strcmp(Tdir.Contrast, Tfinal.Contrast{i});
        if any(idx)
            Tfinal.DirectionConsistency_Percent(i) = Tdir.PercentFollowingPattern(find(idx,1));
            Tfinal.DirectionConsistency_N(i) = Tdir.NFollowingPattern(find(idx,1));
        end
    end

    Tfinal = sortrows(Tfinal, {'p_Signrank','IndexName'}, {'ascend','ascend'});
end

function TrtFinal = cleanRTCanonical(Trt)
    TrtFinal = Trt;
    TrtFinal.InterpretationStatus = repmat({''}, height(TrtFinal), 1);

    for i = 1:height(TrtFinal)
        if TrtFinal.p_Spearman(i) < 0.05
            if strcmp(TrtFinal.Phase{i}, 'retrieval')
                TrtFinal.InterpretationStatus{i} = 'significant_retrieval_supportive';
            else
                TrtFinal.InterpretationStatus{i} = 'significant';
            end
        else
            TrtFinal.InterpretationStatus{i} = 'not_significant';
        end
    end

    TrtFinal = sortrows(TrtFinal, {'p_Spearman','NSubjects'}, {'ascend','descend'});
end

function Tpanel = makeFigurePanelPlan()
    rows = {};

    rows(end+1,:) = {'Figure 1A', 'Task EEG index', 'Box/paired plot', ...
        'posterior_alpha_log_power', 'maintenance alpha log power over posterior ROIs', ...
        'Shows color-dominant posterior alpha organization.'}; %#ok<AGROW>
    rows(end+1,:) = {'Figure 1B', 'Task EEG index', 'Box/paired plot', ...
        'posterior_gamma_relative_power', 'maintenance gamma relative power over parietal/parieto-occipital ROIs', ...
        'Shows conjunction-dominant relative gamma engagement.'}; %#ok<AGROW>
    rows(end+1,:) = {'Figure 1C', 'Topographic organization', 'Box/paired plot', ...
        'posterior_minus_anterior_alpha_relative_power', 'maintenance posterior-minus-anterior alpha relative power', ...
        'Shows posterior alpha dominance strongest for color.'}; %#ok<AGROW>
    rows(end+1,:) = {'Figure 2A', 'Behavior-neural association', 'Scatter', ...
        'canonical_P4_retrieval_delta_logpower_color_vs_conjunction', 'RT difference vs retrieval delta log-power difference at P4', ...
        'Best robust RT-EEG association; supportive/exploratory.'}; %#ok<AGROW>
    rows(end+1,:) = {'Supplementary Figure', 'ROI-level effect profile', 'Bar/count plots', ...
        'STEP06A/STEP06B profiles', 'phase × band × ROI summaries', ...
        'Shows maintenance dominance and absence of hemispheric lateralization.'}; %#ok<AGROW>

    Tpanel = cell2table(rows, 'VariableNames', ...
        {'Panel','EvidenceType','RecommendedPlot','SourceIndexOrAnalysis','WhatToShow','ManuscriptPurpose'});
end

function Tsummary = makeFinalSummary(TcondFinal, TcontrastFinal, TrtFinal, Tdir)
    rows = {};

    rows(end+1,:) = {'Final composite indices', height(TcondFinal)}; %#ok<AGROW>
    rows(end+1,:) = {'Composite condition effects p<0.05', sum(TcondFinal.p_Friedman < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Composite contrast effects p<0.05', sum(TcontrastFinal.p_Signrank < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Canonical RT-EEG effects p<0.05', sum(TrtFinal.p_Spearman < 0.05, 'omitnan')}; %#ok<AGROW>

    [~,iBestCond] = min(TcondFinal.p_Friedman);
    rows(end+1,:) = {'Strongest neural index', TcondFinal.IndexName{iBestCond}}; %#ok<AGROW>
    rows(end+1,:) = {'Strongest neural index p', TcondFinal.p_Friedman(iBestCond)}; %#ok<AGROW>
    rows(end+1,:) = {'Strongest neural index Kendall W', TcondFinal.KendallW(iBestCond)}; %#ok<AGROW>

    [~,iBestRT] = min(TrtFinal.p_Spearman);
    rows(end+1,:) = {'Strongest canonical RT-EEG analysis', TrtFinal.CanonicalAnalysis{iBestRT}}; %#ok<AGROW>
    rows(end+1,:) = {'Strongest canonical RT-EEG rho', TrtFinal.SpearmanRho(iBestRT)}; %#ok<AGROW>
    rows(end+1,:) = {'Strongest canonical RT-EEG p', TrtFinal.p_Spearman(iBestRT)}; %#ok<AGROW>

    rows(end+1,:) = {'Highest median-direction consistency percent', max(Tdir.PercentFollowingPattern, [], 'omitnan')}; %#ok<AGROW>

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function txt = makeEnglishResults(TcondFinal, TcontrastFinal, TrtFinal)
    a = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_alpha_log_power'), :);
    g = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_gamma_relative_power'), :);
    ap = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_minus_anterior_alpha_relative_power'), :);

    rt1 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'canonical_P4_retrieval_delta_logpower_color_vs_conjunction'), :);
    rt2 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'posteriorROI_retrieval_delta_logpower_color_vs_conjunction'), :);
    rt3 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'posteriorROI_maintenance_gamma_relativepower_conjunctionRT'), :);

    txt = sprintf(['Hypothesis-driven composite indices confirmed the main neuroscience pattern observed in the ROI-level analyses. ', ...
        'Maintenance posterior alpha log power differed strongly across conditions, Friedman p = %.3g, Kendall''s W = %.2f, with the highest median value for color-only trials. ', ...
        'Maintenance posterior gamma relative power also differed across conditions, Friedman p = %.3g, Kendall''s W = %.2f, with the highest median value for conjunction trials. ', ...
        'The posterior-minus-anterior maintenance alpha index showed a similar condition effect, Friedman p = %.3g, Kendall''s W = %.2f, again with the strongest posterior dominance for color-only trials.\n\n', ...
        'Canonical RT-EEG analyses supported a retrieval-phase behavioral-neural association. The color-versus-conjunction reconstructed timing difference was strongly correlated with the corresponding retrieval delta log-power difference at P4, rho = %.2f, p = %.3g. ', ...
        'A broader posterior-ROI retrieval delta log-power contrast showed a similar association, rho = %.2f, p = %.3g. In contrast, the condition-matched association between conjunction timing and maintenance posterior gamma relative power was not significant, rho = %.2f, p = %.3g. ', ...
        'Thus, posterior gamma appears to characterize conjunction-related task-condition differences, whereas behavioral timing variability is more strongly linked to retrieval-phase delta activity.'], ...
        a.p_Friedman(1), a.KendallW(1), g.p_Friedman(1), g.KendallW(1), ap.p_Friedman(1), ap.KendallW(1), ...
        rt1.SpearmanRho(1), rt1.p_Spearman(1), rt2.SpearmanRho(1), rt2.p_Spearman(1), rt3.SpearmanRho(1), rt3.p_Spearman(1));
end

function txt = makePersianResults(TcondFinal, TcontrastFinal, TrtFinal)
    a = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_alpha_log_power'), :);
    g = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_gamma_relative_power'), :);
    ap = TcondFinal(strcmp(TcondFinal.IndexName,'posterior_minus_anterior_alpha_relative_power'), :);

    rt1 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'canonical_P4_retrieval_delta_logpower_color_vs_conjunction'), :);
    rt2 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'posteriorROI_retrieval_delta_logpower_color_vs_conjunction'), :);
    rt3 = TrtFinal(strcmp(TrtFinal.CanonicalAnalysis,'posteriorROI_maintenance_gamma_relativepower_conjunctionRT'), :);

    txt = sprintf(['شاخص‌های ترکیبی فرضیه‌محور، الگوی اصلی نوروساینسی مشاهده‌شده در تحلیل‌های ROI را تأیید کردند. ', ...
        'شاخص log-power آلفای posterior در فاز maintenance بین وضعیت‌ها تفاوت قوی نشان داد  Friedman p = %.3g, Kendall''s W = %.2f  و بیشترین میانه مربوط به وضعیت color-only بود. ', ...
        'شاخص توان نسبی گامای posterior در فاز maintenance نیز بین وضعیت‌ها متفاوت بود  Friedman p = %.3g, Kendall''s W = %.2f  و بیشترین میانه مربوط به وضعیت conjunction بود. ', ...
        'شاخص آلفای posterior-minus-anterior در فاز maintenance نیز اثر مشابهی نشان داد  Friedman p = %.3g, Kendall''s W = %.2f  و بیشترین غلبه posterior مربوط به وضعیت color-only بود.\n\n', ...
        'تحلیل‌های canonical RT–EEG از ارتباط رفتاری–عصبی در فاز retrieval حمایت کردند. تفاوت زمان‌بندی بازسازی‌شده color-versus-conjunction با تفاوت log-power دلتای retrieval در کانال P4 همبستگی قوی داشت  rho = %.2f, p = %.3g. ', ...
        'همین contrast در سطح ROI posterior نیز ارتباط مشابهی نشان داد  rho = %.2f, p = %.3g. در مقابل، ارتباط condition-matched بین زمان‌بندی conjunction و توان نسبی گامای posterior در فاز maintenance معنادار نبود  rho = %.2f, p = %.3g. ', ...
        'بنابراین، گامای posterior بیشتر تفاوت‌های عصبی مربوط به وضعیت conjunction را توصیف می‌کند، در حالی‌که تغییرپذیری رفتاری بیشتر با فعالیت دلتای فاز retrieval مرتبط است.'], ...
        a.p_Friedman(1), a.KendallW(1), g.p_Friedman(1), g.KendallW(1), ap.p_Friedman(1), ap.KendallW(1), ...
        rt1.SpearmanRho(1), rt1.p_Spearman(1), rt2.SpearmanRho(1), rt2.p_Spearman(1), rt3.SpearmanRho(1), rt3.p_Spearman(1));
end

function makeIndexFigures(Tidx, figDir)
    indices = unique(Tidx.IndexName, 'stable');
    labels = {'color','orientation','conjunction'};

    for i = 1:numel(indices)
        idxName = indices{i};
        S = Tidx(strcmp(Tidx.IndexName, idxName), :);
        [X, ~] = wideByCondition(S);

        fig = figure('Color','w','Position',[100 100 780 480]);
        boxplot(X, 'Labels', labels);
        ylabel('Composite neural index');
        title(strrep(idxName,'_',' '), 'Interpreter', 'none');
        grid on;
        saveas(fig, fullfile(figDir, ['Index_' idxName '_boxplot.png']));
        savefig(fig, fullfile(figDir, ['Index_' idxName '_boxplot.fig']));
        close(fig);

        fig = figure('Color','w','Position',[100 100 780 480]);
        hold on;
        for s = 1:size(X,1)
            if all(isfinite(X(s,:)))
                plot(1:3, X(s,:), '-o', 'LineWidth', 0.8, 'MarkerSize', 4);
            end
        end
        set(gca, 'XTick', 1:3, 'XTickLabel', labels);
        ylabel('Composite neural index');
        title(['Subject trajectories: ' strrep(idxName,'_',' ')], 'Interpreter', 'none');
        grid on;
        saveas(fig, fullfile(figDir, ['Index_' idxName '_paired_lines.png']));
        savefig(fig, fullfile(figDir, ['Index_' idxName '_paired_lines.fig']));
        close(fig);
    end
end

function makeRTSummaryFigure(TrtFinal, figDir)
    fig = figure('Color','w','Position',[100 100 800 480]);
    bar(abs(TrtFinal.SpearmanRho));
    set(gca, 'XTick', 1:height(TrtFinal), 'XTickLabel', TrtFinal.CanonicalAnalysis, 'XTickLabelRotation', 35);
    ylabel('|Spearman rho|');
    title('Canonical RT-EEG association strength', 'Interpreter', 'none');
    grid on;
    saveas(fig, fullfile(figDir, 'Canonical_RT_EEG_summary_bar.png'));
    savefig(fig, fullfile(figDir, 'Canonical_RT_EEG_summary_bar.fig'));
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

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Could not write text file: %s', fpath);
    end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

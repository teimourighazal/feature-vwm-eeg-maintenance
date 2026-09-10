%% STEP05B_RT_EEG_ROBUSTNESS_CHECK.m
% Robustness check for STEP05 reconstructed response-interval–EEG correlations.
%
% Why this step is needed:
%   STEP05 found many significant response-interval–EEG correlations. However, reconstructed
%   RT has many tied values and conjunction RT contains a subgroup with very
%   long intervals (>2000 ms). Therefore, as a post hoc sensitivity analysis,
%   we test whether significant correlations remain stable after:
%
%   1) excluding high-conjunction-RT subjects:
%        conjunction_RT_ms > 2000
%
%   2) leave-one-subject-out robustness:
%        recompute rho after removing each subject one at a time
%
% Inputs:
%   STEP05_EEG_SubjectFeatures_STANDARDIZED.csv
%   STEP05_RT_SubjectWide_STANDARDIZED.csv
%   STEP05_RT_EEG_Significant_ConditionMatched_q05.csv
%   STEP05_RT_EEG_Significant_Contrast_q05.csv
%
% Outputs:
%   STEP05B_RT_EEG_Robustness and Result/STEP05B_RT_EEG_Robustness
%   under the selected Article2 Analysis folder.
%
% Note:
%   Legacy file/variable names retain "RT" for backward compatibility. The
%   behavioral measure is a reconstructed response interval, not conventional RT.
%
% Main outputs:
%   STEP05B_Robustness_ConditionMatched.csv
%   STEP05B_Robustness_Contrast.csv
%   STEP05B_RobustCore_ConditionMatched.csv
%   STEP05B_RobustCore_Contrast.csv
%   STEP05B_RobustnessSummary.csv
%
% Interpretation:
%   RobustCore = same sign after excluding high-conjunction RT subjects,
%                p<0.05 after exclusion,
%                leave-one-out sign stable,
%                and at least 80% of leave-one-out tests p<0.05.
%
% This is intentionally conservative.

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(rootDir, 'STEP05B_RT_EEG_Robustness');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP05B_RT_EEG_Robustness');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP05B RT-EEG ROBUSTNESS CHECK ===\n');
fprintf('Stage output:\n%s\n', outDir);
fprintf('Result output:\n%s\n', resultOutDir);

%% Locate inputs
Efile = findInput(rootDir, 'STEP05_EEG_SubjectFeatures_STANDARDIZED.csv', 'Select STEP05_EEG_SubjectFeatures_STANDARDIZED.csv');
Rfile = findInput(rootDir, 'STEP05_RT_SubjectWide_STANDARDIZED.csv', 'Select STEP05_RT_SubjectWide_STANDARDIZED.csv');
sigCondFile = findInput(rootDir, 'STEP05_RT_EEG_Significant_ConditionMatched_q05.csv', 'Select STEP05_RT_EEG_Significant_ConditionMatched_q05.csv');
sigContrastFile = findInput(rootDir, 'STEP05_RT_EEG_Significant_Contrast_q05.csv', 'Select STEP05_RT_EEG_Significant_Contrast_q05.csv');

E = readtable(Efile);
R = readtable(Rfile);
TsigCond = readtable(sigCondFile);
TsigContrast = readtable(sigContrastFile);

fprintf('\nEEG rows: %d\n', height(E));
fprintf('RT subjects: %d\n', height(R));
fprintf('Significant condition-matched findings: %d\n', height(TsigCond));
fprintf('Significant contrast findings: %d\n', height(TsigContrast));

%% Define high-conjunction RT subjects
highConj = R.conjunction_RT_ms > 2000 & isfinite(R.conjunction_RT_ms);
highConjSubjects = R.Subject(highConj);

Thigh = table(R.Subject, R.color_RT_ms, R.orientation_RT_ms, R.conjunction_RT_ms, highConj, ...
    'VariableNames', {'Subject','ColorRT_ms','OrientationRT_ms','ConjunctionRT_ms','HighConjunctionRT_gt2000ms'});
writetable(Thigh, fullfile(outDir, 'STEP05B_HighConjunctionRT_Subjects.csv'));

fprintf('High-conjunction-RT subjects (>2000 ms): %d\n', sum(highConj));

%% Robustness for condition-matched significant findings
TrobCond = robustnessConditionMatched(E, R, TsigCond, highConjSubjects);
writetable(TrobCond, fullfile(outDir, 'STEP05B_Robustness_ConditionMatched.csv'));

TcoreCond = TrobCond(TrobCond.RobustCore == true, :);
TcoreCond = sortrows(TcoreCond, {'EEGMetric','p_NoHighConj','AbsRho_NoHighConj'}, {'ascend','ascend','descend'});
writetable(TcoreCond, fullfile(outDir, 'STEP05B_RobustCore_ConditionMatched.csv'));

%% Robustness for contrast significant findings
TrobContrast = robustnessContrast(E, R, TsigContrast, highConjSubjects);
writetable(TrobContrast, fullfile(outDir, 'STEP05B_Robustness_Contrast.csv'));

TcoreContrast = TrobContrast(TrobContrast.RobustCore == true, :);
TcoreContrast = sortrows(TcoreContrast, {'EEGMetric','p_NoHighConj','AbsRho_NoHighConj'}, {'ascend','ascend','descend'});
writetable(TcoreContrast, fullfile(outDir, 'STEP05B_RobustCore_Contrast.csv'));

%% Summary
Tsummary = makeSummary(R, highConjSubjects, TsigCond, TsigContrast, TrobCond, TrobContrast, TcoreCond, TcoreContrast);
writetable(Tsummary, fullfile(outDir, 'STEP05B_RobustnessSummary.csv'));

save(fullfile(outDir, 'STEP05B_RT_EEG_Robustness_Workspace.mat'), ...
    'E','R','TsigCond','TsigContrast','Thigh','TrobCond','TrobContrast','TcoreCond','TcoreContrast','Tsummary');

copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\n================ STEP05B SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% ===================== FUNCTIONS =====================

function Trob = robustnessConditionMatched(E, R, Tfind, highConjSubjects)
    rows = {};

    for i = 1:height(Tfind)
        row = Tfind(i,:);

        cond = getStr(row, 'Condition');
        phase = getStr(row, 'Phase');
        band = getStr(row, 'Band');
        ch = getStr(row, 'ChannelName');
        metricLabel = getStr(row, 'EEGMetric');

        [x, y, subjects] = getXYCondition(E, R, cond, phase, band, ch, metricLabel);

        stats = robustStats(x, y, subjects, highConjSubjects);

        rows(end+1,:) = { ...
            'condition_matched', metricLabel, cond, '', '', '', phase, band, ch, getNum(row,'ChannelIndex'), ...
            getNum(row,'NSubjects'), getNum(row,'SpearmanRho'), getNum(row,'p_Spearman'), getNum(row,'q_FDR_metricFamily'), NaN, ...
            stats.N_Full, stats.Rho_Full, stats.P_Full, ...
            stats.N_NoHighConj, stats.Rho_NoHighConj, stats.P_NoHighConj, abs(stats.Rho_NoHighConj), stats.SameSign_NoHighConj, ...
            stats.LOO_N, stats.LOO_MinRho, stats.LOO_MaxRho, stats.LOO_SignStable, stats.LOO_pLT05_Count, stats.LOO_pLT05_Fraction, ...
            stats.RobustCore, strjoin(stats.SubjectsUsed,'|'), strjoin(stats.HighConjSubjectsRemoved,'|')}; %#ok<AGROW>
    end

    Trob = cell2table(rows, 'VariableNames', commonNames());
end

function Trob = robustnessContrast(E, R, Tfind, highConjSubjects)
    rows = {};

    for i = 1:height(Tfind)
        row = Tfind(i,:);

        contrast = getStr(row, 'Contrast');
        condA = getStr(row, 'ConditionA');
        condB = getStr(row, 'ConditionB');
        phase = getStr(row, 'Phase');
        band = getStr(row, 'Band');
        ch = getStr(row, 'ChannelName');
        metricLabel = getStr(row, 'EEGMetric');

        [x, y, subjects] = getXYContrast(E, R, contrast, condA, condB, phase, band, ch, metricLabel);

        stats = robustStats(x, y, subjects, highConjSubjects);

        qContrast = NaN;
        if ismember('q_FDR_contrastFamily', Tfind.Properties.VariableNames)
            qContrast = getNum(row, 'q_FDR_contrastFamily');
        end

        rows(end+1,:) = { ...
            'contrast_difference', metricLabel, '', contrast, condA, condB, phase, band, ch, getNum(row,'ChannelIndex'), ...
            getNum(row,'NSubjects'), getNum(row,'SpearmanRho'), getNum(row,'p_Spearman'), getNum(row,'q_FDR_metricFamily'), qContrast, ...
            stats.N_Full, stats.Rho_Full, stats.P_Full, ...
            stats.N_NoHighConj, stats.Rho_NoHighConj, stats.P_NoHighConj, abs(stats.Rho_NoHighConj), stats.SameSign_NoHighConj, ...
            stats.LOO_N, stats.LOO_MinRho, stats.LOO_MaxRho, stats.LOO_SignStable, stats.LOO_pLT05_Count, stats.LOO_pLT05_Fraction, ...
            stats.RobustCore, strjoin(stats.SubjectsUsed,'|'), strjoin(stats.HighConjSubjectsRemoved,'|')}; %#ok<AGROW>
    end

    Trob = cell2table(rows, 'VariableNames', commonNames());
end

function names = commonNames()
    names = {'AnalysisType','EEGMetric','Condition','Contrast','ConditionA','ConditionB','Phase','Band','ChannelName','ChannelIndex', ...
        'N_Input','Rho_Input','p_Input','q_InputMetricFamily','q_InputContrastFamily', ...
        'N_FullRecomputed','Rho_FullRecomputed','p_FullRecomputed', ...
        'N_NoHighConj','Rho_NoHighConj','p_NoHighConj','AbsRho_NoHighConj','SameSign_NoHighConj', ...
        'LOO_N','LOO_MinRho','LOO_MaxRho','LOO_SignStable','LOO_pLT05_Count','LOO_pLT05_Fraction', ...
        'RobustCore','SubjectsUsed','HighConjSubjectsRemoved'};
end

function stats = robustStats(x, y, subjects, highConjSubjects)
    x = x(:);
    y = y(:);
    subjects = subjects(:);

    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);
    subjects = subjects(ok);

    [rhoFull, pFull] = robustSpearman(x,y);

    isHigh = ismember(subjects, highConjSubjects);
    xNH = x(~isHigh);
    yNH = y(~isHigh);
    subjectsNH = subjects(~isHigh);

    [rhoNH, pNH] = robustSpearman(xNH,yNH);

    sameSignNH = false;
    if isfinite(rhoFull) && isfinite(rhoNH) && rhoFull ~= 0 && rhoNH ~= 0
        sameSignNH = sign(rhoFull) == sign(rhoNH);
    end

    % Leave-one-out
    looRhos = nan(numel(x),1);
    looPs = nan(numel(x),1);
    for i = 1:numel(x)
        idx = true(numel(x),1);
        idx(i) = false;
        [looRhos(i), looPs(i)] = robustSpearman(x(idx), y(idx));
    end

    validLoo = isfinite(looRhos);
    looMin = NaN; looMax = NaN; signStable = false; pCount = NaN; pFrac = NaN;

    if any(validLoo)
        looMin = min(looRhos(validLoo));
        looMax = max(looRhos(validLoo));

        if isfinite(rhoFull) && rhoFull > 0
            signStable = all(looRhos(validLoo) > 0);
        elseif isfinite(rhoFull) && rhoFull < 0
            signStable = all(looRhos(validLoo) < 0);
        end

        pCount = sum(looPs(validLoo) < 0.05);
        pFrac = pCount / sum(validLoo);
    end

    robustCore = false;
    if sameSignNH && isfinite(pNH) && pNH < 0.05 && signStable && isfinite(pFrac) && pFrac >= 0.80
        robustCore = true;
    end

    stats = struct();
    stats.N_Full = numel(x);
    stats.Rho_Full = rhoFull;
    stats.P_Full = pFull;
    stats.N_NoHighConj = numel(xNH);
    stats.Rho_NoHighConj = rhoNH;
    stats.P_NoHighConj = pNH;
    stats.SameSign_NoHighConj = sameSignNH;
    stats.LOO_N = numel(x);
    stats.LOO_MinRho = looMin;
    stats.LOO_MaxRho = looMax;
    stats.LOO_SignStable = signStable;
    stats.LOO_pLT05_Count = pCount;
    stats.LOO_pLT05_Fraction = pFrac;
    stats.RobustCore = robustCore;
    stats.SubjectsUsed = subjects;
    stats.HighConjSubjectsRemoved = subjects(isHigh);
end

function [x, y, subjects] = getXYCondition(E, R, cond, phase, band, ch, metricLabel)
    metric = metricColumn(metricLabel);
    rtCol = [cond '_RT_ms'];

    idxE = strcmp(E.ConditionLabel, cond) & strcmp(E.PhaseLabel, phase) & strcmp(E.Band, band) & strcmp(E.ChannelName, ch);

    Es = E(idxE, {'Subject', metric});
    Es.Properties.VariableNames{2} = 'EEGValue';

    Rs = R(:, {'Subject', rtCol});
    Rs.Properties.VariableNames{2} = 'RTValue';

    M = innerjoin(Rs, Es, 'Keys', 'Subject');
    x = M.RTValue;
    y = M.EEGValue;
    subjects = M.Subject;
end

function [x, y, subjects] = getXYContrast(E, R, contrast, condA, condB, phase, band, ch, metricLabel)
    metric = metricColumn(metricLabel);
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

    x = M.RT_Diff;
    y = M.EEG_Diff;
    subjects = M.Subject;
end

function metric = metricColumn(metricLabel)
    if strcmp(metricLabel, 'relative_power')
        metric = 'RelPower';
    elseif strcmp(metricLabel, 'log_absolute_power')
        metric = 'LogAbsPower';
    else
        error('Unknown EEGMetric: %s', metricLabel);
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

function Tsummary = makeSummary(R, highConjSubjects, TsigCond, TsigContrast, TrobCond, TrobContrast, TcoreCond, TcoreContrast)
    rows = {};

    rows(end+1,:) = {'RT subjects', height(R)}; %#ok<AGROW>
    rows(end+1,:) = {'High-conjunction RT subjects >2000 ms', numel(highConjSubjects)}; %#ok<AGROW>
    rows(end+1,:) = {'High-conjunction RT subject list', strjoin(highConjSubjects,'|')}; %#ok<AGROW>
    rows(end+1,:) = {'Input significant condition-matched findings', height(TsigCond)}; %#ok<AGROW>
    rows(end+1,:) = {'Input significant contrast findings', height(TsigContrast)}; %#ok<AGROW>
    rows(end+1,:) = {'RobustCore condition-matched findings', height(TcoreCond)}; %#ok<AGROW>
    rows(end+1,:) = {'RobustCore contrast findings', height(TcoreContrast)}; %#ok<AGROW>

    if ~isempty(TrobCond)
        rows(end+1,:) = {'Condition-matched same-sign after high-RT exclusion', sum(TrobCond.SameSign_NoHighConj)}; %#ok<AGROW>
        rows(end+1,:) = {'Condition-matched p<0.05 after high-RT exclusion', sum(TrobCond.p_NoHighConj < 0.05, 'omitnan')}; %#ok<AGROW>
        rows(end+1,:) = {'Condition-matched LOO sign-stable', sum(TrobCond.LOO_SignStable)}; %#ok<AGROW>
    end

    if ~isempty(TrobContrast)
        rows(end+1,:) = {'Contrast same-sign after high-RT exclusion', sum(TrobContrast.SameSign_NoHighConj)}; %#ok<AGROW>
        rows(end+1,:) = {'Contrast p<0.05 after high-RT exclusion', sum(TrobContrast.p_NoHighConj < 0.05, 'omitnan')}; %#ok<AGROW>
        rows(end+1,:) = {'Contrast LOO sign-stable', sum(TrobContrast.LOO_SignStable)}; %#ok<AGROW>
    end

    if ~isempty(TcoreCond)
        rows(end+1,:) = {'RobustCore condition relative_power', sum(strcmp(TcoreCond.EEGMetric,'relative_power'))}; %#ok<AGROW>
        rows(end+1,:) = {'RobustCore condition log_absolute_power', sum(strcmp(TcoreCond.EEGMetric,'log_absolute_power'))}; %#ok<AGROW>
    else
        rows(end+1,:) = {'RobustCore condition relative_power', 0}; %#ok<AGROW>
        rows(end+1,:) = {'RobustCore condition log_absolute_power', 0}; %#ok<AGROW>
    end

    if ~isempty(TcoreContrast)
        rows(end+1,:) = {'RobustCore contrast relative_power', sum(strcmp(TcoreContrast.EEGMetric,'relative_power'))}; %#ok<AGROW>
        rows(end+1,:) = {'RobustCore contrast log_absolute_power', sum(strcmp(TcoreContrast.EEGMetric,'log_absolute_power'))}; %#ok<AGROW>
    else
        rows(end+1,:) = {'RobustCore contrast relative_power', 0}; %#ok<AGROW>
        rows(end+1,:) = {'RobustCore contrast log_absolute_power', 0}; %#ok<AGROW>
    end

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function s = getStr(Trow, col)
    v = Trow.(col);
    if iscell(v)
        s = char(string(v{1}));
    elseif isstring(v)
        s = char(v(1));
    elseif iscategorical(v)
        s = char(string(v(1)));
    elseif ischar(v)
        s = v;
    elseif isnumeric(v)
        if isnan(v(1))
            s = '';
        else
            s = char(string(v(1)));
        end
    else
        s = char(string(v(1)));
    end

    if strcmpi(s,'<missing>') || strcmpi(s,'nan')
        s = '';
    end
end

function x = getNum(Trow, col)
    if ~ismember(col, Trow.Properties.VariableNames)
        x = NaN;
        return;
    end
    v = Trow.(col);
    if iscell(v)
        x = str2double(string(v{1}));
    elseif isnumeric(v)
        x = double(v(1));
    else
        x = str2double(string(v(1)));
    end
end

function fpath = findInput(rootDir, fileName, dialogTitle)
    candidates = {
        fullfile(rootDir, 'STEP05_RT_EEG_Correlation', fileName);
        fullfile(rootDir, 'Result', 'STEP05_RT_EEG_Correlation', fileName);
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

    files = dir(fullfile(rootDir, '**', fileName));
    if isempty(files)
        files = recursiveDir(rootDir, fileName);
    end
    if ~isempty(files)
        fpath = fullfile(files(1).folder, files(1).name);
        return;
    end

    fprintf('\nCould not find %s automatically.\n', fileName);
    [selFile, selPath] = uigetfile('*.csv', dialogTitle);
    if isequal(selFile,0)
        error('Input not selected: %s', fileName);
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

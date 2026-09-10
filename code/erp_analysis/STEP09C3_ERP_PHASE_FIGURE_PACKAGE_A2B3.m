%% STEP09C3_ERP_PHASE_FIGURE_PACKAGE_A2B3.m
% STEP09C3: Figure/table package for STEP09A2 and STEP09B3 ERP analyses.
%
% This script does not run new statistics. It reads STEP09A/STEP09B outputs
% and creates compact reviewer-friendly figures for the strongest ERP and
% maintenance slow-wave findings.
%
% Recommended order:
%   1) Run STEP09A2_CONDITION_ERP_WINDOWS_N22_ROIFIX.m
%   2) Run STEP09B3_MAINTENANCE_SLOWWAVE_N22_PATHFIX.m
%   3) Run this script
%
% Outputs:
%   Result/STEP09C3_ERP_PhaseFigurePackage_A2B3 under the selected Article2 Analysis folder.

clear; clc; close all;

%% Paths
% Select the local Analysis folder so the public script is machine-independent.
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

resultRoot = fullfile(rootDir, 'Result');
step09AOut = fullfile(resultRoot, 'STEP09A2_ConditionERP_Windows_N22');
step09BOut = fullfile(resultRoot, 'STEP09B3_MaintenanceSlowWave_N22');
outDir = fullfile(resultRoot, 'STEP09C3_ERP_PhaseFigurePackage_A2B3');

if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP09C ERP PHASE FIGURE PACKAGE ===\n');
fprintf('Output folder:\n%s\n', outDir);

%% Read files
A_subj_file = fullfile(step09AOut, 'STEP09A2_ERP_SubjectConditionComponents.csv');
A_omni_file = fullfile(step09AOut, 'STEP09A2_ConditionOmnibus_Friedman.csv');
A_pair_file = fullfile(step09AOut, 'STEP09A2_ConditionPairwise_Signrank.csv');

B_subj_file = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_SubjectCondition.csv');
B_omni_file = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_Omnibus.csv');
B_pair_file = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_Pairwise.csv');

if exist(A_subj_file,'file') ~= 2 || exist(A_omni_file,'file') ~= 2
    error('STEP09C3 needs STEP09A2 outputs. Run STEP09A2 first.');
end

A_subj = readtable(A_subj_file, 'VariableNamingRule', 'preserve');
A_omni = readtable(A_omni_file, 'VariableNamingRule', 'preserve');
A_pair = readtable(A_pair_file, 'VariableNamingRule', 'preserve');

hasB = exist(B_subj_file,'file') == 2 && exist(B_omni_file,'file') == 2;
if hasB
    B_subj = readtable(B_subj_file, 'VariableNamingRule', 'preserve');
    B_omni = readtable(B_omni_file, 'VariableNamingRule', 'preserve');
    B_pair = readtable(B_pair_file, 'VariableNamingRule', 'preserve');
else
    B_subj = table(); B_omni = table(); B_pair = table();
end

%% Top findings tables
A_top = topRows(A_omni, 12, 'ERP_window');
writetable(A_top, fullfile(outDir, 'STEP09C3_TopConditionERP_Omnibus.csv'));

if hasB
    B_top = topRows(B_omni, 12, 'maintenance_slowwave');
    writetable(B_top, fullfile(outDir, 'STEP09C3_TopMaintenanceSlowWave_Omnibus.csv'));
else
    B_top = table();
end

%% Create figures for top effects
nA = min(6, height(A_top));
for i = 1:nA
    phase = A_top.PhaseLabel{i};
    comp = A_top.Component{i};
    roi = A_top.ROI{i};
    plotConditionSpaghettiA(A_subj, phase, comp, roi, outDir, i);
end

if hasB
    nB = min(6, height(B_top));
    for i = 1:nB
        win = B_top.Window{i};
        roi = B_top.ROI{i};
        plotConditionSpaghettiB(B_subj, win, roi, outDir, i);
    end
end

%% Phase profile heatmap-like tables
A_profile = makePhaseProfileTable(A_omni);
writetable(A_profile, fullfile(outDir, 'STEP09C3_ERP_PhaseProfile.csv'));

if hasB
    B_profile = makeSlowWaveProfileTable(B_omni);
    writetable(B_profile, fullfile(outDir, 'STEP09C3_SlowWave_Profile.csv'));
end

%% Summary text
summaryText = makeFigurePackageSummary(A_omni, A_pair, B_omni, B_pair, hasB);
writeText(fullfile(outDir, 'STEP09C3_FigurePackageSummary.txt'), summaryText);

fprintf('\n%s\n', summaryText);
fprintf('\nFigures and tables saved in:\n%s\n', outDir);

%% =============== local functions ===============

function Ttop = topRows(T, n, analysisName)
    if isempty(T)
        Ttop = table();
        return;
    end

    if ismember('q_FDR', T.Properties.VariableNames)
        T = sortrows(T, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
    elseif ismember('p_Friedman', T.Properties.VariableNames)
        T = sortrows(T, 'p_Friedman', 'ascend');
    end

    Ttop = T(1:min(n,height(T)),:);
    Ttop.Analysis = repmat({analysisName}, height(Ttop), 1);
end

function plotConditionSpaghettiA(T, phase, comp, roi, outDir, idx)
    S = T(strcmp(T.PhaseLabel,phase) & strcmp(T.Component,comp) & strcmp(T.ROI,roi), :);
    W = wideConditions(S, 'MedianMeanAmplitude');
    if isempty(W) || height(W) < 3
        return;
    end

    X = [W.color, W.orientation, W.conjunction];
    conds = {'color','orientation','conjunction'};
    fig = figure('Visible','off', 'Position', [100 100 800 550]);
    hold on;

    for i = 1:height(W)
        plot(1:3, X(i,:), '-o', 'LineWidth', 0.8);
    end

    med = median(X,1,'omitnan');
    plot(1:3, med, '-ko', 'LineWidth', 3, 'MarkerFaceColor','k');

    xlim([0.7 3.3]);
    set(gca, 'XTick', 1:3, 'XTickLabel', conds, 'FontSize', 12);
    ylabel('Subject median mean amplitude');
    title(sprintf('ERP condition effect: %s | %s | %s', phase, comp, roi), 'Interpreter','none');
    grid on;

    fname = sprintf('STEP09C3_A%02d_ERP_%s_%s_%s.png', idx, phase, comp, roi);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end

function plotConditionSpaghettiB(T, win, roi, outDir, idx)
    S = T(strcmp(T.Window,win) & strcmp(T.ROI,roi), :);
    W = wideConditions(S, 'SubjectMedianMeanAmplitude');
    if isempty(W) || height(W) < 3
        return;
    end

    X = [W.color, W.orientation, W.conjunction];
    conds = {'color','orientation','conjunction'};
    fig = figure('Visible','off', 'Position', [100 100 800 550]);
    hold on;

    for i = 1:height(W)
        plot(1:3, X(i,:), '-o', 'LineWidth', 0.8);
    end

    med = median(X,1,'omitnan');
    plot(1:3, med, '-ko', 'LineWidth', 3, 'MarkerFaceColor','k');

    xlim([0.7 3.3]);
    set(gca, 'XTick', 1:3, 'XTickLabel', conds, 'FontSize', 12);
    ylabel('Subject median slow-wave amplitude');
    title(sprintf('Maintenance slow-wave: %s | %s', win, roi), 'Interpreter','none');
    grid on;

    fname = sprintf('STEP09C3_B%02d_SlowWave_%s_%s.png', idx, win, roi);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end

function W = wideConditions(S, valueCol)
    subjects = unique(S.Subject, 'stable');
    rows = {};
    conds = {'color','orientation','conjunction'};
    for i = 1:numel(subjects)
        subj = subjects{i};
        vals = nan(1,3);
        ok = true;
        for c = 1:3
            Sc = S(strcmp(S.Subject,subj) & strcmp(S.ConditionLabel,conds{c}),:);
            if isempty(Sc)
                ok = false; break;
            end
            vals(c) = median(Sc.(valueCol),'omitnan');
        end
        if ok && all(isfinite(vals))
            rows(end+1,:) = {subj, vals(1), vals(2), vals(3)}; %#ok<AGROW>
        end
    end
    if isempty(rows)
        W = table();
    else
        W = cell2table(rows, 'VariableNames', {'Subject','color','orientation','conjunction'});
    end
end

function P = makePhaseProfileTable(T)
    if isempty(T)
        P = table();
        return;
    end
    keys = {};
    for i = 1:height(T)
        key = sprintf('%s | %s | %s', T.PhaseLabel{i}, T.Component{i}, T.ROI{i});
        keys{end+1,1} = key; %#ok<AGROW>
    end
    P = table(keys, T.NSubjects, T.p_Friedman, T.q_FDR, T.KendallW, T.MaxCondition, ...
        'VariableNames', {'Effect','NSubjects','p_Friedman','q_FDR','KendallW','MaxCondition'});
    P = sortrows(P, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
end

function P = makeSlowWaveProfileTable(T)
    if isempty(T)
        P = table();
        return;
    end
    keys = {};
    for i = 1:height(T)
        key = sprintf('%s | %s', T.Window{i}, T.ROI{i});
        keys{end+1,1} = key; %#ok<AGROW>
    end
    P = table(keys, T.NSubjects, T.p_Friedman, T.q_FDR, T.KendallW, T.MaxCondition, ...
        'VariableNames', {'Effect','NSubjects','p_Friedman','q_FDR','KendallW','MaxCondition'});
    P = sortrows(P, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
end

function txt = makeFigurePackageSummary(A_omni, A_pair, B_omni, B_pair, hasB)
    nA = height(A_omni);
    sigA = countSig(A_omni);
    nAp = height(A_pair);
    sigAp = countSig(A_pair);

    if hasB
        nB = height(B_omni);
        sigB = countSig(B_omni);
        nBp = height(B_pair);
        sigBp = countSig(B_pair);
    else
        nB = 0; sigB = 0; nBp = 0; sigBp = 0;
    end

    txt = sprintf(['STEP09C3 figure package summary\n\n', ...
        'Condition ERP omnibus tests: %d\n', ...
        'Condition ERP omnibus q<0.05: %d\n', ...
        'Condition ERP pairwise tests: %d\n', ...
        'Condition ERP pairwise q<0.05: %d\n\n', ...
        'Maintenance slow-wave omnibus tests: %d\n', ...
        'Maintenance slow-wave omnibus q<0.05: %d\n', ...
        'Maintenance slow-wave pairwise tests: %d\n', ...
        'Maintenance slow-wave pairwise q<0.05: %d\n\n', ...
        'Use these figures only after confirming that STEP09A2/STEP09B3 results are statistically interpretable. ', ...
        'If no corrected effects survive, present the figures as supplementary descriptive visualizations.'], ...
        nA, sigA, nAp, sigAp, nB, sigB, nBp, sigBp);
end

function n = countSig(T)
    if isempty(T) || ~ismember('q_FDR', T.Properties.VariableNames)
        n = 0;
    else
        n = sum(T.q_FDR < 0.05, 'omitnan');
    end
end

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Could not write file: %s', fpath);
    end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

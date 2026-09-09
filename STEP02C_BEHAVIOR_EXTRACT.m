%% STEP02C_BEHAVIOR_EXTRACT.m
% Extract trial-level behavioral metrics from inspected workspace MAT files.
%
% Run after:
%   STEP02_BEHAVIOR_SCAN.m
%   STEP02B_BEHAVIOR_TABLE_INSPECT.m
%
% This script extracts behavior only from tables that contain response and RT:
%   Preferred table:
%       T_allCond
%   Fallback tables:
%       T_cond1_40, T_cond2_60, T_cond3_16
%
% Main columns expected:
%   TrialNum
%   Condition
%   RT_sec / RT_ms
%   Responces
%   TriggerCode
%
% Outputs:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP02C_Behavior_Extract

clear; clc; close all;

%% Config
cfg = struct();

cfg.analysisRoot = '/Users/ghazal/Desktop/Article2/Analysis';
cfg.inspectDir = fullfile(cfg.analysisRoot, 'STEP02B_Behavior_TableInspect');
cfg.outDir = fullfile(cfg.analysisRoot, 'STEP02C_Behavior_Extract');

if ~exist(cfg.outDir, 'dir'); mkdir(cfg.outDir); end

cfg.candidateTablesFile = fullfile(cfg.inspectDir, 'STEP02B_Behavior_CandidateTables.csv');

% RT QC. The task allowed responses up to around 10 seconds.
% A small tolerance is used because reconstructed markers can slightly exceed 10 s.
cfg.minRT_sec = 0.20;
cfg.maxRT_sec = 10.50;

% Tables used for behavior.
cfg.preferredTable = 'T_allCond';
cfg.fallbackTables = {'T_cond1_40','T_cond2_60','T_cond3_16'};

% Condition labels. Adjust later if task coding is confirmed differently.
cfg.conditionLabels = containers.Map({1,2,3}, {'color','orientation','conjunction'});

fprintf('\n=== STEP02C BEHAVIOR EXTRACT ===\n');
fprintf('Output folder:\n%s\n', cfg.outDir);

if ~exist(cfg.candidateTablesFile, 'file')
    error('Candidate table file not found. Run STEP02B first.');
end

Tcand = readtable(cfg.candidateTablesFile);

% Use unique candidate files.
[uniqueFiles, ia] = unique(Tcand.FilePath, 'stable');
Tfile = Tcand(ia, {'Subject','FileName','FilePath'});

fprintf('Candidate files to inspect: %d\n', height(Tfile));

trialRows = {};
fileRows = {};

for i = 1:height(Tfile)
    subj = Tfile.Subject{i};
    fname = Tfile.FileName{i};
    fpath = Tfile.FilePath{i};
    runID = inferRunID(fname);

    if ~exist(fpath, 'file')
        fileRows(end+1,:) = {subj, fname, fpath, runID, 'missing_file', '', 0, ''}; %#ok<SAGROW>
        continue;
    end

    try
        S = load(fpath);
        usedTable = '';
        T = table();

        if isfield(S, cfg.preferredTable) && istable(S.(cfg.preferredTable))
            T = S.(cfg.preferredTable);
            usedTable = cfg.preferredTable;
        else
            parts = {};
            for t = 1:numel(cfg.fallbackTables)
                tv = cfg.fallbackTables{t};
                if isfield(S, tv) && istable(S.(tv)) && height(S.(tv)) > 0
                    parts{end+1} = S.(tv); %#ok<AGROW>
                end
            end

            if ~isempty(parts)
                T = vertcatWithCommonColumns(parts);
                usedTable = strjoin(cfg.fallbackTables, '+');
            end
        end

        if isempty(T) || height(T) == 0
            fileRows(end+1,:) = {subj, fname, fpath, runID, 'no_behavior_table', '', 0, ''}; %#ok<SAGROW>
            continue;
        end

        % Check required columns.
        vars = T.Properties.VariableNames;
        hasTrial = ismember('TrialNum', vars);
        hasCond  = ismember('Condition', vars);
        hasRTsec = ismember('RT_sec', vars);
        hasRTms  = ismember('RT_ms', vars);
        hasResp  = ismember('Responces', vars);

        if ~(hasCond && hasResp && (hasRTsec || hasRTms))
            note = sprintf('Missing columns. HasCondition=%d HasResponse=%d HasRTsec=%d HasRTms=%d', hasCond, hasResp, hasRTsec, hasRTms);
            fileRows(end+1,:) = {subj, fname, fpath, runID, 'missing_required_columns', usedTable, height(T), note}; %#ok<SAGROW>
            continue;
        end

        for r = 1:height(T)
            trialNum = getValueOrNaN(T, r, 'TrialNum');
            condition = getValueOrNaN(T, r, 'Condition');
            triggerCode = getValueOrNaN(T, r, 'TriggerCode');
            resp = getValueOrNaN(T, r, 'Responces');

            if hasRTsec
                rtSec = getValueOrNaN(T, r, 'RT_sec');
            else
                rtSec = getValueOrNaN(T, r, 'RT_ms') / 1000;
            end
            if hasRTms
                rtMs = getValueOrNaN(T, r, 'RT_ms');
            else
                rtMs = rtSec * 1000;
            end

            isCorrect = resp;
            isValidRT = isfinite(rtSec) && rtSec >= cfg.minRT_sec && rtSec <= cfg.maxRT_sec;
            isUsable = isfinite(condition) && isfinite(isCorrect) && isValidRT;

            condLabel = conditionLabel(condition, cfg.conditionLabels);

            trialRows(end+1,:) = {subj, runID, fname, fpath, usedTable, trialNum, condition, condLabel, triggerCode, ...
                                  rtSec, rtMs, resp, isCorrect, isValidRT, isUsable}; %#ok<SAGROW>
        end

        fileRows(end+1,:) = {subj, fname, fpath, runID, 'ok', usedTable, height(T), ''}; %#ok<SAGROW>

    catch ME
        fileRows(end+1,:) = {subj, fname, fpath, runID, ['error: ' ME.message], '', 0, ''}; %#ok<SAGROW>
    end
end

%% Tables
if isempty(trialRows)
    Ttrial = cell2table(cell(0,15), 'VariableNames', ...
        {'Subject','Run','FileName','FilePath','SourceTable','TrialNum','Condition','ConditionLabel','TriggerCode','RT_sec','RT_ms','ResponseRaw','IsCorrect','IsValidRT','IsUsableTrial'});
else
    Ttrial = cell2table(trialRows, 'VariableNames', ...
        {'Subject','Run','FileName','FilePath','SourceTable','TrialNum','Condition','ConditionLabel','TriggerCode','RT_sec','RT_ms','ResponseRaw','IsCorrect','IsValidRT','IsUsableTrial'});
end

TfileLog = cell2table(fileRows, 'VariableNames', ...
    {'Subject','FileName','FilePath','Run','Status','UsedTable','NRows','Note'});

writetable(Ttrial, fullfile(cfg.outDir, 'Behavior_TrialLevel.csv'));
writetable(TfileLog, fullfile(cfg.outDir, 'Behavior_FileExtractionLog.csv'));

%% Summaries
Tvalid = Ttrial(Ttrial.IsUsableTrial == true, :);

% Subject x run x condition
if ~isempty(Tvalid)
    Gsrc = {'Subject','Run','Condition','ConditionLabel'};
    TsubRunCond = groupsummary(Tvalid, Gsrc, {'mean','median','std'}, {'RT_sec','IsCorrect'});
    TsubRunCond.Properties.VariableNames = matlab.lang.makeValidName(TsubRunCond.Properties.VariableNames);
    writetable(TsubRunCond, fullfile(cfg.outDir, 'Behavior_SubjectRunCondition_Summary.csv'));

    % Subject x condition across runs
    Gsrc2 = {'Subject','Condition','ConditionLabel'};
    TsubCond = groupsummary(Tvalid, Gsrc2, {'mean','median','std'}, {'RT_sec','IsCorrect'});
    TsubCond.Properties.VariableNames = matlab.lang.makeValidName(TsubCond.Properties.VariableNames);
    writetable(TsubCond, fullfile(cfg.outDir, 'Behavior_SubjectCondition_Summary.csv'));

    % Group condition summary from subject-level means
    TgroupCond = groupsummary(TsubCond, {'Condition','ConditionLabel'}, {'mean','median','std'}, {'mean_RT_sec','mean_IsCorrect'});
    writetable(TgroupCond, fullfile(cfg.outDir, 'Behavior_GroupCondition_Summary.csv'));

    % Subject summary
    Tsubject = groupsummary(Tvalid, {'Subject'}, {'mean','median','std'}, {'RT_sec','IsCorrect'});
    writetable(Tsubject, fullfile(cfg.outDir, 'Behavior_SubjectOverall_Summary.csv'));

    % Basic nonparametric and repeated-condition tests
    Tstats = computeBehaviorStats(TsubCond);
    writetable(Tstats, fullfile(cfg.outDir, 'Behavior_ConditionStats.csv'));
else
    writetable(table(), fullfile(cfg.outDir, 'Behavior_SubjectRunCondition_Summary.csv'));
    writetable(table(), fullfile(cfg.outDir, 'Behavior_SubjectCondition_Summary.csv'));
    writetable(table(), fullfile(cfg.outDir, 'Behavior_GroupCondition_Summary.csv'));
    writetable(table(), fullfile(cfg.outDir, 'Behavior_SubjectOverall_Summary.csv'));
    writetable(table(), fullfile(cfg.outDir, 'Behavior_ConditionStats.csv'));
end

%% Availability
subjectsAll = unique(Tfile.Subject, 'stable');
availRows = {};

for i = 1:numel(subjectsAll)
    subj = subjectsAll{i};
    F = TfileLog(strcmp(TfileLog.Subject, subj), :);
    Tr = Ttrial(strcmp(Ttrial.Subject, subj), :);
    V = Tr(Tr.IsUsableTrial == true, :);

    nFiles = height(F);
    nOKFiles = sum(strcmp(F.Status, 'ok'));
    nTrials = height(Tr);
    nUsable = height(V);
    runs = unique(F.Run);
    runs = runs(~isnan(runs));

    hasBehavior = nUsable > 0;

    availRows(end+1,:) = {subj, nFiles, nOKFiles, numel(runs), nTrials, nUsable, hasBehavior}; %#ok<SAGROW>
end

Tavail = cell2table(availRows, 'VariableNames', ...
    {'Subject','NFilesInspected','NBehaviorFilesOK','NRunsDetected','NExtractedTrials','NUsableTrials','HasUsableBehavior'});
writetable(Tavail, fullfile(cfg.outDir, 'Behavior_Availability_BySubject.csv'));

%% Figures
try
    if ~isempty(Tvalid)
        makeBehaviorFigures(Tvalid, cfg.outDir);
    end
catch ME
    warning('Could not create behavior figures: %s', ME.message);
end

%% Final summary
fprintf('\n================ STEP02C SUMMARY ================\n');
fprintf('Files inspected: %d\n', height(Tfile));
fprintf('Files with behavior extracted: %d\n', sum(strcmp(TfileLog.Status,'ok')));
fprintf('Subjects with usable behavior: %d\n', sum(Tavail.HasUsableBehavior));
fprintf('Extracted trials total: %d\n', height(Ttrial));
fprintf('Usable trials after RT QC: %d\n', height(Tvalid));
fprintf('Outputs saved in:\n%s\n', cfg.outDir);

if exist('TgroupCond','var') && ~isempty(TgroupCond)
    fprintf('\nGroup condition summary:\n');
    disp(TgroupCond);
end

save(fullfile(cfg.outDir, 'STEP02C_Behavior_Extract_Workspace.mat'), ...
    'cfg','Ttrial','Tvalid','TfileLog','Tavail');

%% ======================= FUNCTIONS =======================

function runID = inferRunID(fname)
    runID = NaN;
    [~, base, ~] = fileparts(fname);
    tok = regexp(base, '(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        runID = str2double(tok{1});
    end
end

function val = getValueOrNaN(T, r, col)
    if ismember(col, T.Properties.VariableNames)
        x = T.(col);
        try
            val = x(r);
            if iscell(val)
                val = val{1};
            end
            if isstring(val) || ischar(val)
                val = str2double(val);
            end
            if ~isnumeric(val) || isempty(val)
                val = NaN;
            else
                val = double(val(1));
            end
        catch
            val = NaN;
        end
    else
        val = NaN;
    end
end

function label = conditionLabel(cond, mapObj)
    if ~isfinite(cond)
        label = 'unknown';
        return;
    end

    key = double(cond);
    if isKey(mapObj, key)
        label = mapObj(key);
    else
        label = sprintf('condition_%g', cond);
    end
end

function Tout = vertcatWithCommonColumns(parts)
    if isempty(parts)
        Tout = table();
        return;
    end

    commonVars = parts{1}.Properties.VariableNames;
    for i = 2:numel(parts)
        commonVars = intersect(commonVars, parts{i}.Properties.VariableNames, 'stable');
    end

    if isempty(commonVars)
        Tout = table();
        return;
    end

    for i = 1:numel(parts)
        parts{i} = parts{i}(:, commonVars);
    end

    Tout = vertcat(parts{:});
end

function Tstats = computeBehaviorStats(TsubCond)
    rows = {};

    conditions = unique(TsubCond.Condition);
    conditions = conditions(isfinite(conditions));

    features = {'mean_RT_sec','mean_IsCorrect'};
    featureNames = {'RT_sec','Accuracy'};

    for f = 1:numel(features)
        feat = features{f};
        featName = featureNames{f};

        % Wide paired matrix subject x condition
        subjects = unique(TsubCond.Subject, 'stable');
        M = nan(numel(subjects), numel(conditions));

        for s = 1:numel(subjects)
            for c = 1:numel(conditions)
                idx = strcmp(TsubCond.Subject, subjects{s}) & TsubCond.Condition == conditions(c);
                if any(idx)
                    M(s,c) = TsubCond.(feat)(find(idx,1));
                end
            end
        end

        complete = all(isfinite(M),2);
        Mc = M(complete,:);

        if size(Mc,1) >= 3 && numel(conditions) >= 3
            try
                p = friedman(Mc, 1, 'off');
                rows(end+1,:) = {featName, 'Friedman_3condition', size(Mc,1), NaN, p, 'Across conditions 1,2,3'}; %#ok<AGROW>
            catch ME
                rows(end+1,:) = {featName, 'Friedman_3condition', size(Mc,1), NaN, NaN, ['failed: ' ME.message]}; %#ok<AGROW>
            end
        end

        % Pairwise signrank
        for a = 1:numel(conditions)
            for b = a+1:numel(conditions)
                x = M(:,a);
                y = M(:,b);
                ok = isfinite(x) & isfinite(y);

                if sum(ok) >= 3
                    try
                        p = signrank(x(ok), y(ok));
                        medDiff = median(y(ok) - x(ok), 'omitnan');
                        note = sprintf('condition_%g_vs_condition_%g; median(second-first)=%.6g', conditions(a), conditions(b), medDiff);
                        rows(end+1,:) = {featName, 'pairwise_signrank', sum(ok), medDiff, p, note}; %#ok<AGROW>
                    catch ME
                        rows(end+1,:) = {featName, 'pairwise_signrank', sum(ok), NaN, NaN, ['failed: ' ME.message]}; %#ok<AGROW>
                    end
                else
                    note = sprintf('condition_%g_vs_condition_%g; not enough paired subjects', conditions(a), conditions(b));
                    rows(end+1,:) = {featName, 'pairwise_signrank', sum(ok), NaN, NaN, note}; %#ok<AGROW>
                end
            end
        end
    end

    if isempty(rows)
        Tstats = table();
    else
        Tstats = cell2table(rows, 'VariableNames', {'Feature','Test','N','EffectOrMedianDifference','pValue','Note'});
    end
end

function makeBehaviorFigures(Tvalid, outDir)
    % Subject-level condition means.
    TsubCond = groupsummary(Tvalid, {'Subject','Condition','ConditionLabel'}, {'mean'}, {'RT_sec','IsCorrect'});

    conds = unique(TsubCond.Condition);
    conds = conds(isfinite(conds));

    % Figure Accuracy
    fig1 = figure('Color','w','Position',[100 100 850 650]);
    hold on;
    means = nan(numel(conds),1);
    sems = nan(numel(conds),1);

    for i = 1:numel(conds)
        vals = TsubCond.mean_IsCorrect(TsubCond.Condition == conds(i));
        means(i) = mean(vals,'omitnan');
        sems(i) = std(vals,'omitnan') / sqrt(sum(isfinite(vals)));
    end

    bar(1:numel(conds), means);
    errorbar(1:numel(conds), means, sems, 'k', 'LineStyle','none', 'LineWidth',1.2);
    set(gca, 'XTick', 1:numel(conds), 'XTickLabel', conditionLabelsForPlot(conds), 'FontSize', 12);
    ylabel('Accuracy');
    title('Behavioral accuracy by condition');
    ylim([0 1]);
    box off; grid on;
    saveFigure(fig1, fullfile(outDir, 'Figure_Behavior_Accuracy_ByCondition'));

    % Figure RT
    fig2 = figure('Color','w','Position',[120 120 850 650]);
    hold on;
    means = nan(numel(conds),1);
    sems = nan(numel(conds),1);

    for i = 1:numel(conds)
        vals = TsubCond.mean_RT_sec(TsubCond.Condition == conds(i));
        means(i) = mean(vals,'omitnan');
        sems(i) = std(vals,'omitnan') / sqrt(sum(isfinite(vals)));
    end

    bar(1:numel(conds), means);
    errorbar(1:numel(conds), means, sems, 'k', 'LineStyle','none', 'LineWidth',1.2);
    set(gca, 'XTick', 1:numel(conds), 'XTickLabel', conditionLabelsForPlot(conds), 'FontSize', 12);
    ylabel('Reaction time (s)');
    title('Reaction time by condition');
    box off; grid on;
    saveFigure(fig2, fullfile(outDir, 'Figure_Behavior_RT_ByCondition'));
end

function labs = conditionLabelsForPlot(conds)
    labs = cell(numel(conds),1);
    for i = 1:numel(conds)
        if conds(i) == 1
            labs{i} = 'Color';
        elseif conds(i) == 2
            labs{i} = 'Orientation';
        elseif conds(i) == 3
            labs{i} = 'Conjunction';
        else
            labs{i} = sprintf('Cond %g', conds(i));
        end
    end
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

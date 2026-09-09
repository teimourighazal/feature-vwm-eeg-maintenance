%% STEP02D_BEHAVIOR_FINAL.m
% Final behavioral QC and summary after STEP02C.
%
% Input:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP02C_Behavior_Extract
%
% Output:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP02D_Behavior_Final
%
% This script:
%   1) Reads trial-level behavior from STEP02C.
%   2) Detects exact duplicate subject-run behavioral sequences.
%   3) Drops duplicated runs conservatively.
%   4) Recomputes final subject-level and group-level behavior.
%   5) Saves final stats and figures.
%
% Expected current outcome:
%   Usable behavior before duplicate-run screening: N = 7
%   Conservative final independent behavior sample: N = 6

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
inDir   = fullfile(rootDir, 'STEP02C_Behavior_Extract');
outDir  = fullfile(rootDir, 'STEP02D_Behavior_Final');

if ~exist(outDir, 'dir'); mkdir(outDir); end

trialFile = fullfile(inDir, 'Behavior_TrialLevel.csv');
availFile = fullfile(inDir, 'Behavior_Availability_BySubject.csv');

if ~exist(trialFile, 'file')
    error('Behavior_TrialLevel.csv not found. Run STEP02C first.');
end

Ttrial = readtable(trialFile);
Tavail = readtable(availFile);

fprintf('\n=== STEP02D BEHAVIOR FINAL ===\n');
fprintf('Input trial rows: %d\n', height(Ttrial));

%% Keep usable trials only
Tvalid = Ttrial(Ttrial.IsUsableTrial == true, :);
fprintf('Usable trial rows before duplicate-run screening: %d\n', height(Tvalid));

%% Duplicate run screening
runKeys = unique(Tvalid(:, {'Subject','Run'}), 'stable');
fingerprints = strings(height(runKeys),1);

for i = 1:height(runKeys)
    subj = runKeys.Subject{i};
    runID = runKeys.Run(i);

    idx = strcmp(Tvalid.Subject, subj) & Tvalid.Run == runID;
    Tr = Tvalid(idx, :);
    Tr = sortrows(Tr, {'TrialNum','Condition'});

    vals = [Tr.TrialNum, Tr.Condition, Tr.TriggerCode, Tr.RT_sec, Tr.ResponseRaw, Tr.IsCorrect];
    vals = round(vals, 6);

    fp = "";
    for r = 1:size(vals,1)
        fp = fp + sprintf('%.6g,%.6g,%.6g,%.6g,%.6g,%.6g;', ...
            vals(r,1), vals(r,2), vals(r,3), vals(r,4), vals(r,5), vals(r,6));
    end
    fingerprints(i) = fp;
end

[G, ~] = findgroups(fingerprints);
dupRows = {};
dropRunMask = false(height(runKeys),1);

for g = 1:max(G)
    idx = find(G == g);

    if numel(idx) > 1
        kept = idx(1);
        dropped = idx(2:end);
        dropRunMask(dropped) = true;

        groupText = {};
        for k = 1:numel(idx)
            groupText{end+1} = sprintf('%s_run%d', runKeys.Subject{idx(k)}, runKeys.Run(idx(k))); %#ok<AGROW>
        end

        droppedText = {};
        for k = 1:numel(dropped)
            droppedText{end+1} = sprintf('%s_run%d', runKeys.Subject{dropped(k)}, runKeys.Run(dropped(k))); %#ok<AGROW>
        end

        dupRows(end+1,:) = {g, strjoin(groupText, ' | '), ...
            sprintf('%s_run%d', runKeys.Subject{kept}, runKeys.Run(kept)), ...
            strjoin(droppedText, ' | '), numel(idx)}; %#ok<SAGROW>
    end
end

if isempty(dupRows)
    Tdup = cell2table(cell(0,5), 'VariableNames', {'DuplicateRunGroupID','RunsInGroup','KeptRun','DroppedRuns','GroupSize'});
else
    Tdup = cell2table(dupRows, 'VariableNames', {'DuplicateRunGroupID','RunsInGroup','KeptRun','DroppedRuns','GroupSize'});
end

writetable(Tdup, fullfile(outDir, 'Behavior_DuplicateRunGroups_FINAL.csv'));

%% Build final valid trial table after dropping duplicate runs
dropRunKeys = runKeys(dropRunMask, :);
dropTrialMask = false(height(Tvalid),1);

for i = 1:height(dropRunKeys)
    dropTrialMask = dropTrialMask | (strcmp(Tvalid.Subject, dropRunKeys.Subject{i}) & Tvalid.Run == dropRunKeys.Run(i));
end

Tfinal = Tvalid(~dropTrialMask, :);
writetable(Tfinal, fullfile(outDir, 'Behavior_TrialLevel_FINAL.csv'));

%% Availability final
subjectsAll = unique(Tvalid.Subject, 'stable');
availRows = {};

for i = 1:numel(subjectsAll)
    subj = subjectsAll{i};
    before = Tvalid(strcmp(Tvalid.Subject, subj), :);
    after  = Tfinal(strcmp(Tfinal.Subject, subj), :);

    runsBefore = unique(before.Run);
    runsAfter  = unique(after.Run);

    availRows(end+1,:) = {subj, height(before), numel(runsBefore), height(after), numel(runsAfter), height(after) > 0}; %#ok<SAGROW>
end

TavailFinal = cell2table(availRows, 'VariableNames', ...
    {'Subject','NUsableTrialsBeforeDupCheck','NRunsBeforeDupCheck','NUsableTrialsFinal','NRunsFinal','HasFinalBehavior'});
writetable(TavailFinal, fullfile(outDir, 'Behavior_Availability_FINAL.csv'));

%% Final summaries
TsubRunCond = groupsummary(Tfinal, {'Subject','Run','Condition','ConditionLabel'}, {'mean','median','std'}, {'RT_sec','IsCorrect'});
TsubRunCond.Properties.VariableNames = matlab.lang.makeValidName(TsubRunCond.Properties.VariableNames);
writetable(TsubRunCond, fullfile(outDir, 'Behavior_SubjectRunCondition_Summary_FINAL.csv'));

TsubCond = groupsummary(Tfinal, {'Subject','Condition','ConditionLabel'}, {'mean','median','std'}, {'RT_sec','IsCorrect'});
TsubCond.Properties.VariableNames = matlab.lang.makeValidName(TsubCond.Properties.VariableNames);
writetable(TsubCond, fullfile(outDir, 'Behavior_SubjectCondition_Summary_FINAL.csv'));

TgroupCond = groupsummary(TsubCond, {'Condition','ConditionLabel'}, {'mean','median','std'}, {'mean_RT_sec','mean_IsCorrect'});
writetable(TgroupCond, fullfile(outDir, 'Behavior_GroupCondition_Summary_FINAL.csv'));

Tsubject = groupsummary(Tfinal, {'Subject'}, {'mean','median','std'}, {'RT_sec','IsCorrect'});
writetable(Tsubject, fullfile(outDir, 'Behavior_SubjectOverall_Summary_FINAL.csv'));

Tstats = computeBehaviorStats(TsubCond);
writetable(Tstats, fullfile(outDir, 'Behavior_ConditionStats_FINAL.csv'));

%% Compact summary
nBefore = numel(unique(Tvalid.Subject));
nFinal  = numel(unique(Tfinal.Subject));
nTrialBefore = height(Tvalid);
nTrialFinal  = height(Tfinal);

Summary = table();
Summary.BehaviorN_BeforeDuplicateRunCheck = nBefore;
Summary.BehaviorN_Final = nFinal;
Summary.UsableTrials_BeforeDuplicateRunCheck = nTrialBefore;
Summary.UsableTrials_Final = nTrialFinal;
Summary.DuplicateRunGroups = height(Tdup);
Summary.DuplicateRunsDropped = height(dropRunKeys);

% Add key condition means
for i = 1:height(TgroupCond)
    label = char(TgroupCond.ConditionLabel{i});
    label = regexprep(label, '[^A-Za-z0-9]', '');
    Summary.([label '_RT_Mean']) = TgroupCond.mean_mean_RT_sec(i);
    Summary.([label '_Accuracy_Mean']) = TgroupCond.mean_mean_IsCorrect(i);
end

writetable(Summary, fullfile(outDir, 'Behavior_ManuscriptSummary_FINAL.csv'));

%% Figures
try
    makeFigures(TsubCond, outDir);
catch ME
    warning('Could not make figures: %s', ME.message);
end

save(fullfile(outDir, 'STEP02D_Behavior_Final_Workspace.mat'), ...
    'Tvalid','Tfinal','Tdup','TavailFinal','TsubRunCond','TsubCond','TgroupCond','Tsubject','Tstats','Summary');

fprintf('\n================ STEP02D FINAL SUMMARY ================\n');
fprintf('Behavior subjects before duplicate-run screening: %d\n', nBefore);
fprintf('Duplicate run groups: %d\n', height(Tdup));
fprintf('Duplicate runs dropped: %d\n', height(dropRunKeys));
fprintf('Final independent behavior subjects: %d\n', nFinal);
fprintf('Usable trials final: %d\n', nTrialFinal);
fprintf('Outputs saved in:\n%s\n', outDir);

if height(Tdup) > 0
    fprintf('\nDuplicate runs:\n');
    disp(Tdup);
end

fprintf('\nFinal group condition summary:\n');
disp(TgroupCond);

%% Functions
function Tstats = computeBehaviorStats(TsubCond)
    rows = {};
    conditions = unique(TsubCond.Condition);
    conditions = conditions(isfinite(conditions));

    features = {'mean_RT_sec','mean_IsCorrect'};
    featureNames = {'RT_sec','Accuracy'};

    for f = 1:numel(features)
        feat = features{f};
        featName = featureNames{f};

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

        for a = 1:numel(conditions)
            for b = a+1:numel(conditions)
                x = M(:,a);
                y = M(:,b);
                ok = isfinite(x) & isfinite(y);

                if sum(ok) >= 3
                    try
                        p = signrank(x(ok), y(ok));
                        medDiff = median(y(ok)-x(ok), 'omitnan');
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

    Tstats = cell2table(rows, 'VariableNames', {'Feature','Test','N','EffectOrMedianDifference','pValue','Note'});
end

function makeFigures(TsubCond, outDir)
    conds = unique(TsubCond.Condition);
    conds = conds(isfinite(conds));

    % Accuracy
    fig1 = figure('Color','w','Position',[100 100 850 650]);
    means = nan(numel(conds),1);
    sems = nan(numel(conds),1);

    for i = 1:numel(conds)
        vals = TsubCond.mean_IsCorrect(TsubCond.Condition == conds(i));
        means(i) = mean(vals,'omitnan');
        sems(i) = std(vals,'omitnan') / sqrt(sum(isfinite(vals)));
    end

    bar(1:numel(conds), means); hold on;
    errorbar(1:numel(conds), means, sems, 'k', 'LineStyle','none', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:numel(conds), 'XTickLabel', labelsForConds(conds), 'FontSize', 12);
    ylabel('Accuracy');
    title('Behavioral accuracy by condition');
    ylim([0 1]);
    box off; grid on;
    saveFigure(fig1, fullfile(outDir, 'Figure_Behavior_Accuracy_FINAL'));

    % RT
    fig2 = figure('Color','w','Position',[120 120 850 650]);
    means = nan(numel(conds),1);
    sems = nan(numel(conds),1);

    for i = 1:numel(conds)
        vals = TsubCond.mean_RT_sec(TsubCond.Condition == conds(i));
        means(i) = mean(vals,'omitnan');
        sems(i) = std(vals,'omitnan') / sqrt(sum(isfinite(vals)));
    end

    bar(1:numel(conds), means); hold on;
    errorbar(1:numel(conds), means, sems, 'k', 'LineStyle','none', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:numel(conds), 'XTickLabel', labelsForConds(conds), 'FontSize', 12);
    ylabel('Reaction time (s)');
    title('Reaction time by condition');
    box off; grid on;
    saveFigure(fig2, fullfile(outDir, 'Figure_Behavior_RT_FINAL'));
end

function labs = labelsForConds(conds)
    labs = cell(numel(conds),1);
    for i = 1:numel(conds)
        if conds(i)==1
            labs{i} = 'Color';
        elseif conds(i)==2
            labs{i} = 'Orientation';
        elseif conds(i)==3
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

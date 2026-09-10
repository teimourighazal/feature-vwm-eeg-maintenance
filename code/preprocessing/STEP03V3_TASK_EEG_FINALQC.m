%% STEP03V3_TASK_EEG_FINALQC.m
% Reconstructed final-QC bridge for the Article2 task-EEG spectral pipeline.
%
% IMPORTANT
% ---------
% The original historical STEP03V3 script is not available. This file is a
% transparent reconstruction based on the documented STEP03V2 outputs and
% the downstream files that expect STEP03V3 outputs.
%
% This script DOES NOT re-extract EEG features and DOES NOT change spectral
% windows. It:
%   1) reads run-level features and the extraction log produced by STEP03V2;
%   2) applies the fixed final N=22 participant set documented by downstream
%      Article2 scripts;
%   3) verifies that all 22 participants have runs 1, 2, and 3 retained;
%   4) audits duplicate run-feature keys rather than silently deleting them;
%   5) recomputes participant-level features from retained run-level medians;
%   6) writes the exact FINAL filenames expected by downstream scripts.
%
% Final participant set:
%   s1-s9, s11-s23 (22 participants; s10 not in the final set).
%
% NOTE ON WINDOWS
% ---------------
% STEP03V2 used its own legacy extraction windows. This reconstructed STEP03V3
% is only a QC/compatibility stage and does not redefine them. The revised
% manuscript-aligned spectral re-analysis uses the dedicated STEP10 script
% with 0-0.6 s stimulus, 0-1.0 s maintenance, and 0-0.6 s retrieval windows.
%
% Expected STEP03V2 inputs:
%   TaskEEG_ChannelBand_RunFeatures.csv
%   TaskEEG_RunExtractionLog.csv
%
% Main outputs:
%   TaskEEG_RunExtractionLog_FINAL.csv
%   TaskEEG_ChannelBand_RunFeatures_FINAL.csv
%   TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv
%   STEP03V3_FinalSubjectList.csv
%   STEP03V3_FinalQC_Summary.csv
%
% MATLAB R2021a compatible.

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC');
resultOutDir = fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

%% Locate STEP03V2 inputs
runFeatureFile = findInput(rootDir, ...
    {'STEP03V2_TaskEEG_Features_TPhasesEDF', 'STEP03V_TaskEEG_Features_TPhasesEDF'}, ...
    'TaskEEG_ChannelBand_RunFeatures.csv', ...
    'Select TaskEEG_ChannelBand_RunFeatures.csv');

runLogFile = findInput(rootDir, ...
    {'STEP03V2_TaskEEG_Features_TPhasesEDF', 'STEP03V_TaskEEG_Features_TPhasesEDF'}, ...
    'TaskEEG_RunExtractionLog.csv', ...
    'Select TaskEEG_RunExtractionLog.csv');

fprintf('\n=== STEP03V3 RECONSTRUCTED FINAL QC ===\n');
fprintf('Run features:\n%s\n', runFeatureFile);
fprintf('Run log:\n%s\n', runLogFile);
fprintf('Output:\n%s\n', outDir);

Trun = readtable(runFeatureFile);
Tlog = readtable(runLogFile);

%% Required columns
requiredRunCols = { ...
    'Subject','Run','Condition','ConditionLabel','Phase', ...
    'ChannelIndex','ChannelName','Band','BandLowHz','BandHighHz', ...
    'NTrialPhaseValues','AbsPower_Median','RelPower_Median', ...
    'RelPower_Mean','LogAbsPower_Median','TotalPower_Median'};

for i = 1:numel(requiredRunCols)
    if ~ismember(requiredRunCols{i}, Trun.Properties.VariableNames)
        error('Run-feature table is missing required column: %s', requiredRunCols{i});
    end
end

if ~ismember('Subject', Tlog.Properties.VariableNames) || ...
   ~ismember('Run', Tlog.Properties.VariableNames) || ...
   ~ismember('Status', Tlog.Properties.VariableNames)
    error('Run extraction log must contain Subject, Run, and Status.');
end

Trun.Subject = cellstr(string(Trun.Subject));
Tlog.Subject = cellstr(string(Tlog.Subject));
Trun.ConditionLabel = cellstr(string(Trun.ConditionLabel));
Trun.Phase = cellstr(string(Trun.Phase));
Trun.ChannelName = cellstr(string(Trun.ChannelName));
Trun.Band = cellstr(string(Trun.Band));
Tlog.Status = cellstr(string(Tlog.Status));

%% Fixed final participant set documented by downstream Article2 scripts
finalSubjects = { ...
    's1';'s2';'s3';'s4';'s5';'s6';'s7';'s8';'s9'; ...
    's11';'s12';'s13';'s14';'s15';'s16';'s17'; ...
    's18';'s19';'s20';'s21';'s22';'s23'};

TsubjectList = table(finalSubjects, true(numel(finalSubjects),1), ...
    'VariableNames', {'Subject','FinalInclude'});
writetable(TsubjectList, fullfile(outDir, 'STEP03V3_FinalSubjectList.csv'));

%% Restrict extraction log to final subjects and successful runs
isFinalLog = ismember(Tlog.Subject, finalSubjects);
isOK = strcmpi(Tlog.Status, 'ok');

TlogFinal = Tlog(isFinalLog & isOK, :);
TlogFinal = sortrows(TlogFinal, {'Subject','Run'});

% Verify exactly runs 1,2,3 for every final subject.
coverageRows = {};
coverageOK = true;

for s = 1:numel(finalSubjects)
    subj = finalSubjects{s};
    idx = strcmp(TlogFinal.Subject, subj);
    runs = unique(double(TlogFinal.Run(idx)))';
    runs = runs(isfinite(runs));

    has1 = any(runs == 1);
    has2 = any(runs == 2);
    has3 = any(runs == 3);
    exactThree = numel(runs) == 3 && has1 && has2 && has3;

    coverageRows(end+1,:) = {subj, numel(runs), joinRuns(runs), ...
        has1, has2, has3, exactThree}; %#ok<AGROW>

    if ~exactThree
        coverageOK = false;
    end
end

Tcoverage = cell2table(coverageRows, 'VariableNames', ...
    {'Subject','NRunsOK','RunsOK','HasRun1','HasRun2','HasRun3','ExactRuns123'});
writetable(Tcoverage, fullfile(outDir, 'STEP03V3_RunCoverage_FINAL.csv'));

if ~coverageOK
    disp(Tcoverage(~Tcoverage.ExactRuns123,:));
    error(['Final-QC reconstruction stopped: at least one documented final ' ...
           'participant does not have exactly successful runs 1, 2, and 3.']);
end

if height(TlogFinal) ~= 66
    error('Expected 66 successful final subject-run log rows, found %d.', height(TlogFinal));
end

%% Restrict run features to final 22 x runs 1:3
keepRun = ismember(Trun.Subject, finalSubjects) & ismember(double(Trun.Run), 1:3);
TrunFinal = Trun(keepRun, :);

if isempty(TrunFinal)
    error('No run-level feature rows remain after final participant/run selection.');
end

%% Audit duplicate identifying keys
keyVars = {'Subject','Run','Condition','ConditionLabel','Phase', ...
           'ChannelIndex','ChannelName','Band','BandLowHz','BandHighHz'};

Tkeys = TrunFinal(:, keyVars);
[~, ia, ic] = unique(Tkeys, 'rows', 'stable');
keyCounts = accumarray(ic, 1);
dupKeyGroups = find(keyCounts > 1);

if ~isempty(dupKeyGroups)
    dupMask = ismember(ic, dupKeyGroups);
    Tdup = TrunFinal(dupMask, :);
    writetable(Tdup, fullfile(outDir, 'STEP03V3_DuplicateRunFeatureKeys.csv'));
    error(['Duplicate run-feature keys were detected. They were NOT silently ' ...
           'removed. Inspect STEP03V3_DuplicateRunFeatureKeys.csv first.']);
else
    Tdup = TrunFinal([],:);
    writetable(Tdup, fullfile(outDir, 'STEP03V3_DuplicateRunFeatureKeys.csv'));
end

%% Basic content checks
expectedConditions = {'color','orientation','conjunction'};
expectedPhases = {'stimulus','maintenance','retrieval'};
expectedBands = {'delta','theta','alpha','beta','gamma'};

missingCond = setdiff(expectedConditions, unique(TrunFinal.ConditionLabel));
missingPhase = setdiff(expectedPhases, unique(TrunFinal.Phase));
missingBand = setdiff(expectedBands, unique(TrunFinal.Band));

if ~isempty(missingCond)
    error('Missing expected condition(s): %s', strjoin(missingCond, ', '));
end
if ~isempty(missingPhase)
    error('Missing expected phase(s): %s', strjoin(missingPhase, ', '));
end
if ~isempty(missingBand)
    error('Missing expected band(s): %s', strjoin(missingBand, ', '));
end

nChannels = numel(unique(TrunFinal.ChannelIndex));
if nChannels ~= 64
    error('Expected 64 EEG channel indices in final run features, found %d.', nChannels);
end

%% Recompute subject-level features exactly from retained run-level summaries
TsubjFinal = summarizeSubjectFeatures(TrunFinal);

% Verify final N.
nFinal = numel(unique(TsubjFinal.Subject));
if nFinal ~= 22
    error('Expected 22 final participants in subject features, found %d.', nFinal);
end

% Require all three run-level values for every subject/condition/phase/channel/band cell.
badRunCount = TsubjFinal.NRuns ~= 3;
if any(badRunCount)
    Tbad = TsubjFinal(badRunCount, :);
    writetable(Tbad, fullfile(outDir, 'STEP03V3_Cells_NotThreeRuns.csv'));
    error(['Some final subject feature cells do not contain exactly three run-level ' ...
           'values. See STEP03V3_Cells_NotThreeRuns.csv.']);
else
    writetable(TsubjFinal([],:), fullfile(outDir, 'STEP03V3_Cells_NotThreeRuns.csv'));
end

%% Write canonical FINAL outputs
writetable(TlogFinal, fullfile(outDir, 'TaskEEG_RunExtractionLog_FINAL.csv'));
writetable(TrunFinal, fullfile(outDir, 'TaskEEG_ChannelBand_RunFeatures_FINAL.csv'));
writetable(TsubjFinal, fullfile(outDir, 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'));

%% Summary
summaryRows = { ...
    'Reconstruction status', 'PASS'; ...
    'Historical original STEP03V3 available', 'no'; ...
    'Final participants', nFinal; ...
    'Final successful runs', height(TlogFinal); ...
    'Expected runs per participant', 3; ...
    'Run-feature rows', height(TrunFinal); ...
    'Subject-feature rows', height(TsubjFinal); ...
    'Unique channels', nChannels; ...
    'Duplicate key groups', numel(dupKeyGroups); ...
    'Final-set rule', 'fixed documented N=22: s1-s9, s11-s23'; ...
    'Window handling', 'unchanged from STEP03V2; no re-extraction in this QC stage'};

Tsummary = cell2table(summaryRows, 'VariableNames', {'Metric','Value'});
writetable(Tsummary, fullfile(outDir, 'STEP03V3_FinalQC_Summary.csv'));

%% Copy outputs to Result
copyOutputs(outDir, resultOutDir);

save(fullfile(outDir, 'STEP03V3_FinalQC_Reconstructed_Workspace.mat'), ...
    'Trun','Tlog','TrunFinal','TlogFinal','TsubjFinal','Tcoverage','Tsummary','finalSubjects');

fprintf('\n================ STEP03V3 FINAL QC SUMMARY ================\n');
disp(Tsummary);
fprintf('\nPASS. Canonical FINAL outputs saved in:\n%s\n', outDir);
fprintf('\nImportant: this is a reconstructed QC bridge, not the missing historical STEP03V3 source code.\n');

%% ===================== FUNCTIONS =====================
function fpath = findInput(rootDir, folderCandidates, fileName, dialogTitle)
    fpath = '';

    for i = 1:numel(folderCandidates)
        candidates = { ...
            fullfile(rootDir, folderCandidates{i}, fileName), ...
            fullfile(rootDir, 'Result', folderCandidates{i}, fileName)};

        for j = 1:numel(candidates)
            if exist(candidates{j}, 'file')
                fpath = candidates{j};
                return;
            end
        end
    end

    recursiveHits = dir(fullfile(rootDir, '**', fileName));
    if ~isempty(recursiveHits)
        fpath = fullfile(recursiveHits(1).folder, recursiveHits(1).name);
        return;
    end

    [f,p] = uigetfile('*.csv', dialogTitle);
    if isequal(f,0)
        error('Required input not selected: %s', fileName);
    end
    fpath = fullfile(p,f);
end

function Tout = summarizeSubjectFeatures(TfeaturesRun)
    [G, Subject, Condition, ConditionLabel, Phase, ChannelIndex, ChannelName, ...
        Band, BandLowHz, BandHighHz] = findgroups( ...
        TfeaturesRun.Subject, TfeaturesRun.Condition, TfeaturesRun.ConditionLabel, ...
        TfeaturesRun.Phase, TfeaturesRun.ChannelIndex, TfeaturesRun.ChannelName, ...
        TfeaturesRun.Band, TfeaturesRun.BandLowHz, TfeaturesRun.BandHighHz);

    nRuns = splitapply(@numel, TfeaturesRun.RelPower_Median, G);
    absMed = splitapply(@(x) median(x,'omitnan'), TfeaturesRun.AbsPower_Median, G);
    relMed = splitapply(@(x) median(x,'omitnan'), TfeaturesRun.RelPower_Median, G);
    logMed = splitapply(@(x) median(x,'omitnan'), TfeaturesRun.LogAbsPower_Median, G);
    nTrialPhaseValues = splitapply(@sum, TfeaturesRun.NTrialPhaseValues, G);

    Tout = table(Subject, Condition, ConditionLabel, Phase, ChannelIndex, ...
        ChannelName, Band, BandLowHz, BandHighHz, nRuns, nTrialPhaseValues, ...
        absMed, relMed, logMed, ...
        'VariableNames', {'Subject','Condition','ConditionLabel','Phase', ...
        'ChannelIndex','ChannelName','Band','BandLowHz','BandHighHz', ...
        'NRuns','NTrialPhaseValues','AbsPower_SubjectMedian', ...
        'RelPower_SubjectMedian','LogAbsPower_SubjectMedian'});
end

function txt = joinRuns(runs)
    if isempty(runs)
        txt = '';
        return;
    end
    parts = arrayfun(@(x) sprintf('%g',x), runs, 'UniformOutput', false);
    txt = strjoin(parts, '|');
end

function copyOutputs(srcDir, dstDir)
    if ~exist(dstDir,'dir'); mkdir(dstDir); end
    patterns = {'*.csv','*.txt','*.mat'};
    for p = 1:numel(patterns)
        F = dir(fullfile(srcDir, patterns{p}));
        for i = 1:numel(F)
            copyfile(fullfile(F(i).folder,F(i).name), ...
                     fullfile(dstDir,F(i).name));
        end
    end
end

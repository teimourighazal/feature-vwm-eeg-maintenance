%% STEP04D_RT_FINAL_REPORT.m
% Reconstructed final-report bridge for Article2 behavioral timing results.
%
% IMPORTANT
% ---------
% The original historical STEP04D source file is not available. This script
% is a transparent reconstruction from the documented STEP04C outputs and
% the exact filenames required by downstream STEP04D4 and STEP05 scripts.
%
% The behavioral measure is a reconstructed response interval:
%   retrieval onset -> next-trial onset
% It is NOT treated as conventional reaction time. Legacy filenames retain
% "RT" only for compatibility with the existing pipeline.
%
% Run after:
%   STEP04C_ALIGN_STEP122_RT_WITH_EEG.m
%
% Required STEP04C inputs:
%   STEP04C_RT_TrialLevel_EEG_ALIGNED.csv
%   STEP04C_RT_SubjectCondition_EEG_ALIGNED.csv
%   STEP04C_RT_ConditionSummary_EEG_ALIGNED.csv
%   STEP04C_RT_Friedman_EEG_ALIGNED.csv
%   STEP04C_RT_Pairwise_EEG_ALIGNED.csv
%   STEP04C_RT_EEG_SubjectAlignment.csv
%
% Main outputs:
%   RT_FinalReport_SubjectWide_EEG_ALIGNED.csv
%   RT_FinalReport_ConditionTable_EEG_ALIGNED.csv
%   RT_FinalReport_FriedmanTable_EEG_ALIGNED.csv
%   RT_FinalReport_PairwiseTable_EEG_ALIGNED.csv
%   RT_FinalReport_KeyNumbers.csv
%   RT_FinalReport_ResultsSentence.txt
%   RT_FinalReport_ReconstructionNote.txt
%
% MATLAB R2021a compatible.

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(rootDir, 'STEP04D_RT_FinalReport');
resultOutDir = fullfile(rootDir, 'Result', 'STEP04D_RT_FinalReport');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP04D RECONSTRUCTED FINAL REPORT ===\n');
fprintf('Output:\n%s\n', outDir);

%% Locate STEP04C inputs
trialFile = findInput(rootDir, 'STEP04C_RT_TrialLevel_EEG_ALIGNED.csv');
subjCondFile = findInput(rootDir, 'STEP04C_RT_SubjectCondition_EEG_ALIGNED.csv');
condFile = findInput(rootDir, 'STEP04C_RT_ConditionSummary_EEG_ALIGNED.csv');
friedFile = findInput(rootDir, 'STEP04C_RT_Friedman_EEG_ALIGNED.csv');
pairFile = findInput(rootDir, 'STEP04C_RT_Pairwise_EEG_ALIGNED.csv');
alignFile = findInput(rootDir, 'STEP04C_RT_EEG_SubjectAlignment.csv');

Ttrial = readtable(trialFile);
Tsubj = readtable(subjCondFile);
Tcond = readtable(condFile);
Tfried = readtable(friedFile);
Tpair = readtable(pairFile);
Talign = readtable(alignFile);

%% Required-column checks
requireColumns(Ttrial, {'Subject','ConditionLabel','RT_ms','RT_Valid_Final'}, 'trial-level table');
requireColumns(Tsubj, {'Subject','ConditionLabel','MedianRT_ms'}, 'subject-condition table');
requireColumns(Tfried, {'NCompleteSubjects','p_Friedman','KendallW'}, 'Friedman table');
requireColumns(Tpair, {'Contrast','p_Signrank','q_FDR_threeContrasts'}, 'pairwise table');
requireColumns(Talign, {'Subject','In_Final_EEG','AlignmentStatus'}, 'alignment table');

Ttrial.Subject = cellstr(string(Ttrial.Subject));
Ttrial.ConditionLabel = normalizeLabels(Ttrial.ConditionLabel);
Tsubj.Subject = cellstr(string(Tsubj.Subject));
Tsubj.ConditionLabel = normalizeLabels(Tsubj.ConditionLabel);
Talign.Subject = cellstr(string(Talign.Subject));
Talign.AlignmentStatus = cellstr(string(Talign.AlignmentStatus));

%% Build subject-wide table required by STEP04D4 and STEP05
subjects = unique(Tsubj.Subject, 'stable');
n = numel(subjects);

Twide = table();
Twide.Subject = subjects(:);

Twide.color_MedianRT_ms = nan(n,1);
Twide.orientation_MedianRT_ms = nan(n,1);
Twide.conjunction_MedianRT_ms = nan(n,1);

Twide.color_NValid = nan(n,1);
Twide.orientation_NValid = nan(n,1);
Twide.conjunction_NValid = nan(n,1);

hasNValid = ismember('N_ValidRT', Tsubj.Properties.VariableNames);

for s = 1:n
    subj = subjects{s};

    Twide.color_MedianRT_ms(s) = getSubjectConditionValue( ...
        Tsubj, subj, 'color', 'MedianRT_ms');
    Twide.orientation_MedianRT_ms(s) = getSubjectConditionValue( ...
        Tsubj, subj, 'orientation', 'MedianRT_ms');
    Twide.conjunction_MedianRT_ms(s) = getSubjectConditionValue( ...
        Tsubj, subj, 'conjunction', 'MedianRT_ms');

    if hasNValid
        Twide.color_NValid(s) = getSubjectConditionValue( ...
            Tsubj, subj, 'color', 'N_ValidRT');
        Twide.orientation_NValid(s) = getSubjectConditionValue( ...
            Tsubj, subj, 'orientation', 'N_ValidRT');
        Twide.conjunction_NValid(s) = getSubjectConditionValue( ...
            Tsubj, subj, 'conjunction', 'N_ValidRT');
    end
end

Twide.CompleteCase3Conditions = ...
    isfinite(Twide.color_MedianRT_ms) & ...
    isfinite(Twide.orientation_MedianRT_ms) & ...
    isfinite(Twide.conjunction_MedianRT_ms);

Twide.color_minus_orientation_RT_ms = ...
    Twide.color_MedianRT_ms - Twide.orientation_MedianRT_ms;
Twide.color_minus_conjunction_RT_ms = ...
    Twide.color_MedianRT_ms - Twide.conjunction_MedianRT_ms;
Twide.orientation_minus_conjunction_RT_ms = ...
    Twide.orientation_MedianRT_ms - Twide.conjunction_MedianRT_ms;

writetable(Twide, fullfile(outDir, ...
    'RT_FinalReport_SubjectWide_EEG_ALIGNED.csv'));

%% Preserve the STEP04C inferential tables under the historical STEP04D names
% STEP04D4 expects the pairwise columns exactly as produced by STEP04C:
% Contrast, p_Signrank, q_FDR_threeContrasts, etc.
writetable(Tcond, fullfile(outDir, ...
    'RT_FinalReport_ConditionTable_EEG_ALIGNED.csv'));
writetable(Tfried, fullfile(outDir, ...
    'RT_FinalReport_FriedmanTable_EEG_ALIGNED.csv'));
writetable(Tpair, fullfile(outDir, ...
    'RT_FinalReport_PairwiseTable_EEG_ALIGNED.csv'));

%% Key numbers required by STEP04D4
nFinalEEG = sum(toLogical(Talign.In_Final_EEG));
nRTAligned = sum(strcmp(Talign.AlignmentStatus, 'overlap'));
nValid = sum(toLogical(Ttrial.RT_Valid_Final));
nComplete = Tfried.NCompleteSubjects(1);
pF = Tfried.p_Friedman(1);
W = Tfried.KendallW(1);

rtOnly = Talign.Subject(strcmp(Talign.AlignmentStatus, 'rt_only'));
eegOnly = Talign.Subject(strcmp(Talign.AlignmentStatus, 'eeg_only'));

rtOnlyList = strjoin(rtOnly, ',');
eegOnlyList = strjoin(eegOnly, ',');

metrics = { ...
    'Final EEG subjects'; ...
    'EEG-aligned RT subjects'; ...
    'EEG-aligned valid RT rows'; ...
    'Friedman complete-case N'; ...
    'Friedman p'; ...
    'Kendall W'; ...
    'RT-only subject list'; ...
    'EEG-only subject list'; ...
    'Historical original STEP04D available'; ...
    'Behavioral timing definition'};

values = { ...
    nFinalEEG; ...
    nRTAligned; ...
    nValid; ...
    nComplete; ...
    pF; ...
    W; ...
    rtOnlyList; ...
    eegOnlyList; ...
    'no'; ...
    'retrieval onset to next-trial onset; not conventional reaction time'};

Tkey = table(metrics, values, 'VariableNames', {'Metric','Value'});
writetable(Tkey, fullfile(outDir, 'RT_FinalReport_KeyNumbers.csv'));

%% Manuscript-safe descriptive sentence
medColor = median(Twide.color_MedianRT_ms, 'omitnan');
medOri = median(Twide.orientation_MedianRT_ms, 'omitnan');
medConj = median(Twide.conjunction_MedianRT_ms, 'omitnan');

[pCO,qCO] = getPair(Tpair, 'color_vs_orientation');
[pCC,qCC] = getPair(Tpair, 'color_vs_conjunction');
[pOC,qOC] = getPair(Tpair, 'orientation_vs_conjunction');

resultText = sprintf([ ...
    'Reconstructed response intervals (retrieval onset to next-trial onset) were available for %d of %d final task-EEG participants. ' ...
    'The complete-case Friedman test used %d participants and showed a condition effect (p = %.6g, Kendall''s W = %.6g). ' ...
    'Median subject-level intervals were %.0f ms for color, %.0f ms for orientation, and %.0f ms for conjunction. ' ...
    'Pairwise signed-rank tests gave color versus orientation p = %.6g (FDR q = %.6g), ' ...
    'color versus conjunction p = %.6g (FDR q = %.6g), and orientation versus conjunction p = %.6g (FDR q = %.6g). ' ...
    'These values are reconstructed response intervals and should not be described as conventional reaction times.'], ...
    nRTAligned, nFinalEEG, nComplete, pF, W, medColor, medOri, medConj, ...
    pCO, qCO, pCC, qCC, pOC, qOC);

writeText(fullfile(outDir, 'RT_FinalReport_ResultsSentence.txt'), resultText);

reconText = sprintf([ ...
    'RECONSTRUCTION NOTE\n\n' ...
    'The historical STEP04D MATLAB source was not available when the public repository was assembled.\n' ...
    'This script reconstructs the report-building stage from the documented STEP04C outputs and the exact downstream filenames expected by STEP04D4 and STEP05.\n' ...
    'No behavioral intervals are re-estimated here and no inferential test is newly selected: subject-condition summaries, Friedman statistics, and pairwise signed-rank/FDR results are taken directly from STEP04C.\n' ...
    'Legacy filenames retain RT for compatibility, but the behavioral measure is retrieval-onset to next-trial-onset and is not conventional reaction time.\n']);
writeText(fullfile(outDir, 'RT_FinalReport_ReconstructionNote.txt'), reconText);

%% Static outcome checks against documented current Article2 sample
% These are warnings rather than hard-coded selection rules.
if nFinalEEG ~= 22
    warning('Documented final EEG N is 22, but this run found %d.', nFinalEEG);
end
if nRTAligned ~= 20
    warning('Documented reconstructed-interval N is 20, but this run found %d.', nRTAligned);
end
if nComplete ~= 19
    warning('Documented complete-case N is 19, but this run found %d.', nComplete);
end

%% Copy to Result
copyOutputsToResultFolder(outDir, resultOutDir);

save(fullfile(outDir, 'STEP04D_RT_FinalReport_Reconstructed_Workspace.mat'), ...
    'Ttrial','Tsubj','Tcond','Tfried','Tpair','Talign','Twide','Tkey');

fprintf('\n================ STEP04D SUMMARY ================\n');
fprintf('Final EEG participants      : %d\n', nFinalEEG);
fprintf('EEG-aligned interval sample : %d\n', nRTAligned);
fprintf('Valid interval observations : %d\n', nValid);
fprintf('Complete-case Friedman N    : %d\n', nComplete);
fprintf('Friedman p                  : %.6g\n', pF);
fprintf('Kendall W                   : %.6g\n', W);
fprintf('\nPASS. Outputs saved in:\n%s\n', outDir);
fprintf('\nImportant: this is a reconstructed report bridge, not the missing historical STEP04D source.\n');

%% ===================== FUNCTIONS =====================
function fpath = findInput(rootDir, fileName)
    candidates = { ...
        fullfile(rootDir, 'STEP04C_RT_EEG_Alignment', fileName), ...
        fullfile(rootDir, 'Result', 'STEP04C_RT_EEG_Alignment', fileName), ...
        fullfile(rootDir, fileName), ...
        fullfile(pwd, fileName)};

    fpath = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            fpath = candidates{i};
            return;
        end
    end

    hits = dir(fullfile(rootDir, '**', fileName));
    if ~isempty(hits)
        fpath = fullfile(hits(1).folder, hits(1).name);
        return;
    end

    [f,p] = uigetfile('*.csv', ['Select ' fileName]);
    if isequal(f,0)
        error('Required STEP04C input not selected: %s', fileName);
    end
    fpath = fullfile(p,f);
end

function requireColumns(T, names, label)
    for i = 1:numel(names)
        if ~ismember(names{i}, T.Properties.VariableNames)
            error('%s is missing required column: %s', label, names{i});
        end
    end
end

function labels = normalizeLabels(v)
    labels = cellstr(lower(strtrim(string(v))));
    for i = 1:numel(labels)
        x = labels{i};
        if contains(x,'color')
            labels{i} = 'color';
        elseif contains(x,'ori')
            labels{i} = 'orientation';
        elseif contains(x,'conj')
            labels{i} = 'conjunction';
        end
    end
end

function val = getSubjectConditionValue(T, subj, cond, varName)
    idx = strcmp(T.Subject, subj) & strcmp(T.ConditionLabel, cond);
    if ~any(idx)
        val = NaN;
        return;
    end

    x = double(T.(varName)(idx));
    x = x(isfinite(x));
    if isempty(x)
        val = NaN;
    else
        val = median(x, 'omitnan');
    end
end

function [p,q] = getPair(Tpair, contrast)
    idx = strcmp(cellstr(string(Tpair.Contrast)), contrast);
    if ~any(idx)
        p = NaN; q = NaN;
        return;
    end
    p = double(Tpair.p_Signrank(find(idx,1)));
    q = double(Tpair.q_FDR_threeContrasts(find(idx,1)));
end

function x = toLogical(v)
    if islogical(v)
        x = v(:);
    elseif isnumeric(v)
        x = v(:) ~= 0;
    else
        s = lower(strtrim(string(v(:))));
        x = s == "1" | s == "true" | s == "yes";
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

function copyOutputsToResultFolder(outDir, resultOutDir)
    if ~exist(resultOutDir, 'dir')
        mkdir(resultOutDir);
    end

    patterns = {'*.csv','*.txt','*.mat'};
    for p = 1:numel(patterns)
        F = dir(fullfile(outDir, patterns{p}));
        for i = 1:numel(F)
            src = fullfile(F(i).folder, F(i).name);
            dst = fullfile(resultOutDir, F(i).name);
            try
                copyfile(src, dst);
            catch ME
                warning('Could not copy %s to Result folder: %s', F(i).name, ME.message);
            end
        end
    end
end

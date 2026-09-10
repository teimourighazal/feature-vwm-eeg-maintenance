%% STEP04C_ALIGN_STEP122_RT_WITH_EEG.m
% Align old STEP122 reconstructed RT results with the final task-EEG subject list.
%
% Purpose:
%   STEP122 provides reconstructed RT for N=22, but its subject list may not
%   match the final duplicate-QC task EEG subject list. This script:
%
%   1) Reads STEP122 RT trial-level and summary files.
%   2) Reads the final task-EEG subject list from final-QC outputs, or from a
%      user-selected final EEG subject-list CSV if those outputs are elsewhere.
%   3) Compares subject sets:
%         RT subjects
%         EEG-final subjects
%         overlap
%         RT-only subjects
%         EEG-only subjects
%   4) Recomputes RT statistics for:
%         A) STEP122 full RT set
%         B) EEG-aligned overlap subset
%   5) Saves clean tables into:
%         STEP04C_RT_EEG_Alignment
%         Result/STEP04C_RT_EEG_Alignment
%      under the selected Article2 Analysis folder.
%
% Important:
%   RT here is reconstructed as retrieval-to-next-trial interval when based
%   on STEP122 columns:
%       RetrSample -> NextTrialTaskSample
%   It should be reported as reconstructed response interval unless a true
%   response marker is confirmed.
%
% Main outputs:
%   STEP04C_RT_EEG_SubjectAlignment.csv
%   STEP04C_RT_TrialLevel_STEP122_FULL.csv
%   STEP04C_RT_TrialLevel_EEG_ALIGNED.csv
%   STEP04C_RT_SubjectCondition_STEP122_FULL.csv
%   STEP04C_RT_SubjectCondition_EEG_ALIGNED.csv
%   STEP04C_RT_Friedman_STEP122_FULL.csv
%   STEP04C_RT_Friedman_EEG_ALIGNED.csv
%   STEP04C_RT_Pairwise_STEP122_FULL.csv
%   STEP04C_RT_Pairwise_EEG_ALIGNED.csv
%   STEP04C_RT_AlignmentSummary.csv
%
% Condition convention:
%   color, orientation, conjunction

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(rootDir, 'STEP04C_RT_EEG_Alignment');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP04C_RT_EEG_Alignment');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP04C ALIGN STEP122 RT WITH FINAL EEG ===\n');
fprintf('Stage output:\n%s\n', outDir);
fprintf('Result output:\n%s\n', resultOutDir);

%% Locate STEP122 files
rtTrialFile = findFile(rootDir, 'STEP122_RT_trial_level_FINAL_N22*.csv', 'Select STEP122_RT_trial_level_FINAL_N22.csv');
rtQCFile = findOptionalFile(rootDir, 'STEP122_RT_QC_summary_FINAL_N22*.csv');
rtInvalidFile = findOptionalFile(rootDir, 'STEP122_RT_invalid_reason_summary_FINAL_N22*.csv');
rtSubjectCondFile = findOptionalFile(rootDir, 'STEP122_RT_subject_condition_summary_FINAL_N22*.csv');
rtCondFile = findOptionalFile(rootDir, 'STEP122_RT_condition_summary_FINAL_N22*.csv');

fprintf('\nSTEP122 trial file:\n%s\n', rtTrialFile);

%% Locate final EEG subject list
eegListFile = findFinalEEGFile(rootDir);
fprintf('\nFinal EEG subject source:\n%s\n', eegListFile);

%% Read and standardize RT trial-level
Traw = readtable(rtTrialFile);
Ttrial = standardizeRTTrialTable(Traw);

% Keep all rows in full table, but create validity column.
Ttrial.RT_Valid_Final = isfinite(Ttrial.RT_ms) & Ttrial.RT_ms > 0 & Ttrial.RT_ms <= 10000 & Ttrial.RT_valid == 1;

writetable(Ttrial, fullfile(outDir, 'STEP04C_RT_TrialLevel_STEP122_FULL.csv'));

%% Read final EEG subjects
TeegSubjects = readFinalEEGSubjects(eegListFile);
rtSubjects = unique(Ttrial.Subject, 'stable');
eegSubjects = unique(TeegSubjects.Subject, 'stable');

[Toverlap, TrtOnly, TeegOnly, Talign] = makeSubjectAlignment(rtSubjects, eegSubjects);
writetable(Talign, fullfile(outDir, 'STEP04C_RT_EEG_SubjectAlignment.csv'));

fprintf('\nRT subjects: %d\n', numel(rtSubjects));
fprintf('EEG-final subjects: %d\n', numel(eegSubjects));
fprintf('Overlap subjects: %d\n', height(Toverlap));
fprintf('RT-only subjects: %d\n', height(TrtOnly));
fprintf('EEG-only subjects: %d\n', height(TeegOnly));

%% EEG-aligned RT trial table
isAligned = ismember(Ttrial.Subject, Toverlap.Subject);
TtrialAligned = Ttrial(isAligned, :);
writetable(TtrialAligned, fullfile(outDir, 'STEP04C_RT_TrialLevel_EEG_ALIGNED.csv'));

%% Recompute subject-condition summaries
TsubjFull = summarizeSubjectConditionRT(Ttrial);
TsubjAligned = summarizeSubjectConditionRT(TtrialAligned);

writetable(TsubjFull, fullfile(outDir, 'STEP04C_RT_SubjectCondition_STEP122_FULL.csv'));
writetable(TsubjAligned, fullfile(outDir, 'STEP04C_RT_SubjectCondition_EEG_ALIGNED.csv'));

%% Condition-level summaries
TcondFull = summarizeConditionRT(Ttrial);
TcondAligned = summarizeConditionRT(TtrialAligned);

writetable(TcondFull, fullfile(outDir, 'STEP04C_RT_ConditionSummary_STEP122_FULL.csv'));
writetable(TcondAligned, fullfile(outDir, 'STEP04C_RT_ConditionSummary_EEG_ALIGNED.csv'));

%% Stats
TfriedFull = friedmanRT(TsubjFull, 'STEP122_FULL');
TfriedAligned = friedmanRT(TsubjAligned, 'EEG_ALIGNED');

TpairFull = pairwiseRT(TsubjFull, 'STEP122_FULL');
TpairAligned = pairwiseRT(TsubjAligned, 'EEG_ALIGNED');

writetable(TfriedFull, fullfile(outDir, 'STEP04C_RT_Friedman_STEP122_FULL.csv'));
writetable(TfriedAligned, fullfile(outDir, 'STEP04C_RT_Friedman_EEG_ALIGNED.csv'));
writetable(TpairFull, fullfile(outDir, 'STEP04C_RT_Pairwise_STEP122_FULL.csv'));
writetable(TpairAligned, fullfile(outDir, 'STEP04C_RT_Pairwise_EEG_ALIGNED.csv'));

%% Optional import old summaries for comparison
if ~isempty(rtQCFile)
    TqcOld = readtable(rtQCFile);
    writetable(TqcOld, fullfile(outDir, 'STEP04C_Imported_STEP122_QC_Summary.csv'));
end
if ~isempty(rtInvalidFile)
    TinvOld = readtable(rtInvalidFile);
    writetable(TinvOld, fullfile(outDir, 'STEP04C_Imported_STEP122_InvalidReasonSummary.csv'));
end
if ~isempty(rtSubjectCondFile)
    TscOld = readtable(rtSubjectCondFile);
    writetable(TscOld, fullfile(outDir, 'STEP04C_Imported_STEP122_SubjectConditionSummary.csv'));
end
if ~isempty(rtCondFile)
    TcOld = readtable(rtCondFile);
    writetable(TcOld, fullfile(outDir, 'STEP04C_Imported_STEP122_ConditionSummary.csv'));
end

%% Summary
Tsummary = makeAlignmentSummary(Ttrial, TtrialAligned, TsubjFull, TsubjAligned, ...
    TfriedFull, TfriedAligned, TpairFull, TpairAligned, Talign);

writetable(Tsummary, fullfile(outDir, 'STEP04C_RT_AlignmentSummary.csv'));

%% Simple figures
try
    makeRTFigures(TsubjFull, TsubjAligned, outDir);
catch ME
    warning('RT figures were not created: %s', ME.message);
end

save(fullfile(outDir, 'STEP04C_RT_EEG_Alignment_Workspace.mat'), ...
    'Traw','Ttrial','TtrialAligned','TeegSubjects','Talign','TsubjFull','TsubjAligned', ...
    'TcondFull','TcondAligned','TfriedFull','TfriedAligned','TpairFull','TpairAligned','Tsummary');

copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\n================ STEP04C SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% ===================== FUNCTIONS =====================

function fpath = findFile(rootDir, pattern, dialogTitle)
    fpath = '';

    candidates = {};
    searchRoots = {rootDir, fullfile(rootDir, 'Result'), pwd, fileparts(rootDir)};

    for r = 1:numel(searchRoots)
        if exist(searchRoots{r}, 'dir')
            files = dir(fullfile(searchRoots{r}, '**', pattern));
            if isempty(files)
                files = recursiveDir(searchRoots{r}, pattern);
            end
            for i = 1:numel(files)
                candidates{end+1} = fullfile(files(i).folder, files(i).name); %#ok<AGROW>
            end
        end
    end

    if ~isempty(candidates)
        candidates = unique(candidates, 'stable');
        fpath = candidates{1};
        return;
    end

    fprintf('\nCould not find required file: %s\n', pattern);
    [selFile, selPath] = uigetfile('*.csv', dialogTitle);
    if isequal(selFile, 0)
        error('Required file was not selected: %s', pattern);
    end
    fpath = fullfile(selPath, selFile);
end

function fpath = findOptionalFile(rootDir, pattern)
    fpath = '';
    searchRoots = {rootDir, fullfile(rootDir, 'Result'), pwd, fileparts(rootDir)};

    for r = 1:numel(searchRoots)
        if exist(searchRoots{r}, 'dir')
            files = dir(fullfile(searchRoots{r}, '**', pattern));
            if isempty(files)
                files = recursiveDir(searchRoots{r}, pattern);
            end
            if ~isempty(files)
                fpath = fullfile(files(1).folder, files(1).name);
                return;
            end
        end
    end
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

function eegFile = findFinalEEGFile(rootDir)
    candidates = { ...
        fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_RunExtractionLog_FINAL.csv'), ...
        fullfile(rootDir, 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv'), ...
        fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_RunExtractionLog_FINAL.csv'), ...
        fullfile(rootDir, 'Result', 'STEP03V3_TaskEEG_FinalQC', 'TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv') ...
    };

    eegFile = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            eegFile = candidates{i};
            return;
        end
    end

    fprintf('\nCould not find final EEG subject list automatically.\n');
    fprintf('Please select TaskEEG_RunExtractionLog_FINAL.csv or TaskEEG_ChannelBand_SubjectFeatures_FINAL.csv.\n');
    [selFile, selPath] = uigetfile('*.csv', 'Select final EEG subject list CSV');
    if isequal(selFile, 0)
        error('Final EEG subject list was not selected.');
    end
    eegFile = fullfile(selPath, selFile);
end

function T = standardizeRTTrialTable(Traw)
    cols = Traw.Properties.VariableNames;
    colsLow = lower(cols);

    idxSubj = findColumn(colsLow, {'subject','subj'});
    idxRun = findColumn(colsLow, {'runnum','run','runid'});
    idxTrial = findColumn(colsLow, {'trialnum','trial'});
    idxCondLabel = findColumn(colsLow, {'conditionlabel','condition_label'});
    idxCondRaw = findColumn(colsLow, {'conditionraw','condition','cond'});
    idxRTms = findColumn(colsLow, {'rt_ms','rtms'});
    idxRTsec = findColumn(colsLow, {'rt_sec','rtsec'});
    idxRTvalid = findColumn(colsLow, {'rt_valid','rtvalid','validrt'});
    idxInvalidReason = findColumn(colsLow, {'invalidreason','invalid_reason'});
    idxRetr = findColumn(colsLow, {'retrsample'});
    idxNext = findColumn(colsLow, {'nexttrialtasksample'});
    idxRTsamples = findColumn(colsLow, {'rt_samples','rtsamples'});
    idxSource = findColumn(colsLow, {'sourcecleanmat','sourcefile','filepath'});

    if isempty(idxSubj) || isempty(idxCondLabel)
        error('RT trial table must contain Subject and ConditionLabel.');
    end

    n = height(Traw);
    T = table();

    T.Subject = toText(Traw.(cols{idxSubj}));

    if isempty(idxRun); T.RunNum = nan(n,1); else; T.RunNum = toNumeric(Traw.(cols{idxRun})); end
    if isempty(idxTrial); T.TrialNum = (1:n)'; else; T.TrialNum = toNumeric(Traw.(cols{idxTrial})); end

    T.ConditionLabel = normalizeConditionLabels(toText(Traw.(cols{idxCondLabel})));
    T.Condition = conditionNumberFromLabel(T.ConditionLabel);

    if ~isempty(idxCondRaw)
        T.ConditionRaw = toNumeric(Traw.(cols{idxCondRaw}));
    else
        T.ConditionRaw = T.Condition;
    end

    if ~isempty(idxRTms)
        T.RT_ms = toNumeric(Traw.(cols{idxRTms}));
    elseif ~isempty(idxRTsec)
        T.RT_ms = toNumeric(Traw.(cols{idxRTsec})) * 1000;
    else
        error('RT trial table must contain RT_ms or RT_sec.');
    end

    T.RT_sec = T.RT_ms / 1000;

    if ~isempty(idxRTvalid)
        T.RT_valid = toNumeric(Traw.(cols{idxRTvalid}));
        T.RT_valid(T.RT_valid >= 0.5) = 1;
        T.RT_valid(T.RT_valid < 0.5) = 0;
    else
        T.RT_valid = double(isfinite(T.RT_ms));
    end

    if ~isempty(idxInvalidReason)
        T.InvalidReason = toText(Traw.(cols{idxInvalidReason}));
    else
        T.InvalidReason = repmat({''}, n, 1);
    end

    if ~isempty(idxRetr); T.RetrSample = toNumeric(Traw.(cols{idxRetr})); else; T.RetrSample = nan(n,1); end
    if ~isempty(idxNext); T.NextTrialTaskSample = toNumeric(Traw.(cols{idxNext})); else; T.NextTrialTaskSample = nan(n,1); end
    if ~isempty(idxRTsamples); T.RT_samples = toNumeric(Traw.(cols{idxRTsamples})); else; T.RT_samples = nan(n,1); end

    if ~isempty(idxSource)
        T.SourceCleanMAT = toText(Traw.(cols{idxSource}));
    else
        T.SourceCleanMAT = repmat({''}, n, 1);
    end
end

function T = readFinalEEGSubjects(eegFile)
    E = readtable(eegFile);
    cols = E.Properties.VariableNames;
    colsLow = lower(cols);
    idxSubj = findColumn(colsLow, {'subject','subj'});

    if isempty(idxSubj)
        error('Final EEG file does not contain a Subject column.');
    end

    subjects = unique(toText(E.(cols{idxSubj})), 'stable');
    T = table(subjects, 'VariableNames', {'Subject'});
end

function [Toverlap, TrtOnly, TeegOnly, Talign] = makeSubjectAlignment(rtSubjects, eegSubjects)
    overlap = intersect(rtSubjects, eegSubjects, 'stable');
    rtOnly = setdiff(rtSubjects, eegSubjects, 'stable');
    eegOnly = setdiff(eegSubjects, rtSubjects, 'stable');

    Toverlap = table(overlap(:), repmat({'overlap'}, numel(overlap),1), 'VariableNames', {'Subject','SetStatus'});
    TrtOnly = table(rtOnly(:), repmat({'rt_only'}, numel(rtOnly),1), 'VariableNames', {'Subject','SetStatus'});
    TeegOnly = table(eegOnly(:), repmat({'eeg_only'}, numel(eegOnly),1), 'VariableNames', {'Subject','SetStatus'});

    allSubjects = unique([rtSubjects(:); eegSubjects(:)], 'stable');
    status = cell(numel(allSubjects),1);
    inRT = false(numel(allSubjects),1);
    inEEG = false(numel(allSubjects),1);

    for i = 1:numel(allSubjects)
        inRT(i) = ismember(allSubjects{i}, rtSubjects);
        inEEG(i) = ismember(allSubjects{i}, eegSubjects);

        if inRT(i) && inEEG(i)
            status{i} = 'overlap';
        elseif inRT(i)
            status{i} = 'rt_only';
        else
            status{i} = 'eeg_only';
        end
    end

    Talign = table(allSubjects(:), inRT, inEEG, status, ...
        'VariableNames', {'Subject','In_STEP122_RT','In_Final_EEG','AlignmentStatus'});
end

function Tsubj = summarizeSubjectConditionRT(Ttrial)
    Tvalid = Ttrial(Ttrial.RT_Valid_Final == true & ismember(Ttrial.ConditionLabel, {'color','orientation','conjunction'}), :);

    if isempty(Tvalid)
        Tsubj = table();
        return;
    end

    [G, Subject, Condition, ConditionLabel] = findgroups(Tvalid.Subject, Tvalid.Condition, Tvalid.ConditionLabel);

    nValid = splitapply(@numel, Tvalid.RT_ms, G);
    medRT = splitapply(@(x) median(x,'omitnan'), Tvalid.RT_ms, G);
    meanRT = splitapply(@(x) mean(x,'omitnan'), Tvalid.RT_ms, G);
    sdRT = splitapply(@(x) std(x,'omitnan'), Tvalid.RT_ms, G);
    q1 = splitapply(@(x) prctile(x,25), Tvalid.RT_ms, G);
    q3 = splitapply(@(x) prctile(x,75), Tvalid.RT_ms, G);
    minRT = splitapply(@(x) min(x,[],'omitnan'), Tvalid.RT_ms, G);
    maxRT = splitapply(@(x) max(x,[],'omitnan'), Tvalid.RT_ms, G);
    nRuns = splitapply(@(x) numel(unique(x(isfinite(x)))), Tvalid.RunNum, G);

    Tsubj = table(Subject, Condition, ConditionLabel, nRuns, nValid, medRT, meanRT, sdRT, q1, q3, minRT, maxRT, ...
        'VariableNames', {'Subject','Condition','ConditionLabel','NRuns','N_ValidRT','MedianRT_ms','MeanRT_ms','SDRT_ms','Q1RT_ms','Q3RT_ms','MinRT_ms','MaxRT_ms'});
end

function Tcond = summarizeConditionRT(Ttrial)
    Tvalid = Ttrial(Ttrial.RT_Valid_Final == true & ismember(Ttrial.ConditionLabel, {'color','orientation','conjunction'}), :);

    if isempty(Tvalid)
        Tcond = table();
        return;
    end

    [G, Condition, ConditionLabel] = findgroups(Tvalid.Condition, Tvalid.ConditionLabel);

    nValid = splitapply(@numel, Tvalid.RT_ms, G);
    nSubjects = splitapply(@(x) numel(unique(x)), Tvalid.Subject, G);
    nRuns = splitapply(@(s,r) height(unique(table(s,r))), Tvalid.Subject, Tvalid.RunNum, G);
    medRT = splitapply(@(x) median(x,'omitnan'), Tvalid.RT_ms, G);
    meanRT = splitapply(@(x) mean(x,'omitnan'), Tvalid.RT_ms, G);
    sdRT = splitapply(@(x) std(x,'omitnan'), Tvalid.RT_ms, G);
    q1 = splitapply(@(x) prctile(x,25), Tvalid.RT_ms, G);
    q3 = splitapply(@(x) prctile(x,75), Tvalid.RT_ms, G);

    Tcond = table(Condition, ConditionLabel, nSubjects, nRuns, nValid, medRT, meanRT, sdRT, q1, q3, ...
        'VariableNames', {'Condition','ConditionLabel','NSubjects','NRuns','N_ValidRT','MedianRT_ms','MeanRT_ms','SDRT_ms','Q1RT_ms','Q3RT_ms'});
end

function Tfried = friedmanRT(Tsubj, analysisSet)
    [X, subjects] = wideRT(Tsubj);
    ok = all(isfinite(X), 2);
    X = X(ok,:);
    subjects = subjects(ok);

    n = size(X,1);
    p = NaN;
    chi2 = NaN;
    W = NaN;
    medColor = NaN; medOri = NaN; medConj = NaN;
    meanColor = NaN; meanOri = NaN; meanConj = NaN;
    note = '';

    if n >= 3
        try
            [p, tbl] = friedman(X, 1, 'off');
            chi2 = extractFriedmanChiSquare(tbl);
        catch ME
            [p, chi2] = friedmanManual(X);
            note = appendNote(note, ['manual Friedman used after: ' ME.message]);
        end

        if isfinite(chi2)
            W = chi2 / (n * 2);
        end

        medVals = median(X, 1, 'omitnan');
        meanVals = mean(X, 1, 'omitnan');

        medColor = medVals(1); medOri = medVals(2); medConj = medVals(3);
        meanColor = meanVals(1); meanOri = meanVals(2); meanConj = meanVals(3);
    else
        note = 'Not enough complete-case subjects.';
    end

    Tfried = table({analysisSet}, n, p, chi2, 2, W, ...
        medColor, medOri, medConj, meanColor, meanOri, meanConj, {strjoin(subjects,'|')}, {note}, ...
        'VariableNames', {'AnalysisSet','NCompleteSubjects','p_Friedman','ChiSquare','DF','KendallW', ...
        'MedianRT_Color_ms','MedianRT_Orientation_ms','MedianRT_Conjunction_ms', ...
        'MeanRT_Color_ms','MeanRT_Orientation_ms','MeanRT_Conjunction_ms','SubjectsUsed','Note'});
end

function Tpair = pairwiseRT(Tsubj, analysisSet)
    contrasts = {
        'color','orientation','color_vs_orientation';
        'color','conjunction','color_vs_conjunction';
        'orientation','conjunction','orientation_vs_conjunction'
    };

    rows = {};

    for c = 1:size(contrasts,1)
        labelA = contrasts{c,1};
        labelB = contrasts{c,2};
        contrast = contrasts{c,3};

        [X, subjects] = wideRT(Tsubj, {labelA,labelB});
        ok = all(isfinite(X),2);
        X = X(ok,:);
        subjects = subjects(ok);

        n = size(X,1);
        p = NaN;
        signedRank = NaN;
        zval = NaN;
        medA = NaN; medB = NaN; medDiff = NaN; meanDiff = NaN;
        nAgtB = NaN; nAltB = NaN; nEq = NaN;
        direction = '';
        note = '';

        if n >= 3 && any(abs(X(:,1)-X(:,2)) > 0)
            try
                [p, ~, stats] = signrank(X(:,1), X(:,2));
                if isstruct(stats)
                    if isfield(stats,'signedrank'); signedRank = stats.signedrank; end
                    if isfield(stats,'zval'); zval = stats.zval; end
                end
            catch ME
                note = ME.message;
            end

            diffAB = X(:,1) - X(:,2);
            medA = median(X(:,1),'omitnan');
            medB = median(X(:,2),'omitnan');
            medDiff = median(diffAB,'omitnan');
            meanDiff = mean(diffAB,'omitnan');
            nAgtB = sum(diffAB > 0);
            nAltB = sum(diffAB < 0);
            nEq = sum(diffAB == 0);

            if medDiff < 0
                direction = sprintf('%s_faster_than_%s', labelA, labelB);
            elseif medDiff > 0
                direction = sprintf('%s_faster_than_%s', labelB, labelA);
            else
                direction = 'no_median_difference';
            end
        else
            note = 'Not enough subjects or all differences are zero.';
        end

        rows(end+1,:) = {analysisSet, contrast, labelA, labelB, n, p, signedRank, zval, ...
            medA, medB, medDiff, meanDiff, nAgtB, nAltB, nEq, direction, strjoin(subjects,'|'), note}; %#ok<AGROW>
    end

    Tpair = cell2table(rows, 'VariableNames', ...
        {'AnalysisSet','Contrast','ConditionA','ConditionB','NSubjects','p_Signrank','SignedRank','ZValue', ...
        'MedianRT_A_ms','MedianRT_B_ms','MedianDiff_AminusB_ms','MeanDiff_AminusB_ms', ...
        'N_AgreaterB','N_AlessB','N_Equal','DirectionByMedian','SubjectsUsed','Note'});

    Tpair.q_FDR_threeContrasts = bhFDR(Tpair.p_Signrank);
end

function [X, subjects] = wideRT(Tsubj, labels)
    if nargin < 2
        labels = {'color','orientation','conjunction'};
    end

    subjects = unique(Tsubj.Subject, 'stable');
    X = nan(numel(subjects), numel(labels));

    for s = 1:numel(subjects)
        subj = subjects{s};
        for l = 1:numel(labels)
            idx = strcmp(Tsubj.Subject, subj) & strcmp(Tsubj.ConditionLabel, labels{l});
            if any(idx)
                X(s,l) = median(Tsubj.MedianRT_ms(idx), 'omitnan');
            end
        end
    end
end

function Tsummary = makeAlignmentSummary(Ttrial, TtrialAligned, TsubjFull, TsubjAligned, ...
    TfFull, TfAligned, TpFull, TpAligned, Talign)

    rows = {};
    rows(end+1,:) = {'STEP122 RT subjects', numel(unique(Ttrial.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'Final EEG subjects', sum(Talign.In_Final_EEG)}; %#ok<AGROW>
    rows(end+1,:) = {'Overlap RT and EEG subjects', sum(strcmp(Talign.AlignmentStatus,'overlap'))}; %#ok<AGROW>
    rows(end+1,:) = {'RT-only subjects', sum(strcmp(Talign.AlignmentStatus,'rt_only'))}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-only subjects', sum(strcmp(Talign.AlignmentStatus,'eeg_only'))}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 total RT rows', height(Ttrial)}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 valid RT rows', sum(Ttrial.RT_Valid_Final)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned total RT rows', height(TtrialAligned)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned valid RT rows', sum(TtrialAligned.RT_Valid_Final)}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 subject-condition rows', height(TsubjFull)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned subject-condition rows', height(TsubjAligned)}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 Friedman complete-case N', TfFull.NCompleteSubjects(1)}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 Friedman p', TfFull.p_Friedman(1)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned Friedman complete-case N', TfAligned.NCompleteSubjects(1)}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned Friedman p', TfAligned.p_Friedman(1)}; %#ok<AGROW>
    rows(end+1,:) = {'STEP122 pairwise significant q<0.05', sum(TpFull.q_FDR_threeContrasts < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-aligned pairwise significant q<0.05', sum(TpAligned.q_FDR_threeContrasts < 0.05, 'omitnan')}; %#ok<AGROW>

    rtOnly = Talign.Subject(strcmp(Talign.AlignmentStatus,'rt_only'));
    eegOnly = Talign.Subject(strcmp(Talign.AlignmentStatus,'eeg_only'));
    rows(end+1,:) = {'RT-only subject list', strjoin(rtOnly, ',')}; %#ok<AGROW>
    rows(end+1,:) = {'EEG-only subject list', strjoin(eegOnly, ',')}; %#ok<AGROW>

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function makeRTFigures(TsubjFull, TsubjAligned, outDir)
    makeOneRTFigure(TsubjFull, fullfile(outDir, 'STEP04C_RT_STEP122_FULL_ByCondition.png'), 'STEP122 full RT set');
    makeOneRTFigure(TsubjAligned, fullfile(outDir, 'STEP04C_RT_EEG_ALIGNED_ByCondition.png'), 'EEG-aligned RT subset');
end

function makeOneRTFigure(Tsubj, outPng, ttl)
    labels = {'color','orientation','conjunction'};
    means = nan(1,3);
    sems = nan(1,3);

    for i = 1:3
        vals = Tsubj.MedianRT_ms(strcmp(Tsubj.ConditionLabel, labels{i}));
        means(i) = mean(vals,'omitnan');
        sems(i) = std(vals,'omitnan') / sqrt(sum(isfinite(vals)));
    end

    fig = figure('Color','w','Position',[100 100 700 450]);
    bar(means); hold on;
    errorbar(1:3, means, sems, 'k.', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:3, 'XTickLabel', labels);
    ylabel('Median RT (ms)');
    title(ttl);
    grid on;
    saveas(fig, outPng);
    savefig(fig, strrep(outPng, '.png', '.fig'));
    close(fig);
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

function noteOut = appendNote(noteIn, extra)
    if isempty(extra)
        noteOut = noteIn;
    elseif isempty(noteIn)
        noteOut = extra;
    else
        noteOut = [noteIn ' ' extra];
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
end

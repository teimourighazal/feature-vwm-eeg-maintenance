%% STEP09B3_MAINTENANCE_SLOWWAVE_N22_PATHFIX.m
% STEP09B: Maintenance sustained slow-wave / delay-period ERP amplitude.
%
% Goal:
%   Test whether maintenance-period sustained time-domain amplitude differs
%   among color, orientation, and conjunction conditions.
%
% Important:
%   This is not classical N1/P2/N2/P3. Report as:
%   "maintenance-onset phase-locked sustained amplitude / slow-wave window".
%
% Recommended order:
%   Run STEP09A first, because this script reuses:
%     STEP09A_MergedTrialPhaseTable.csv
%
% Outputs:
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP09B3_MaintenanceSlowWave_N22

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
resultRoot = fullfile(rootDir, 'Result');
step09AOut = fullfile(resultRoot, 'STEP09A2_ConditionERP_Windows_N22');
outDir = fullfile(resultRoot, 'STEP09B3_MaintenanceSlowWave_N22');

if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP09B3 MAINTENANCE SLOW-WAVE N22 - ROI FIX ===\n');
fprintf('Output folder:\n%s\n', outDir);

%% Parameters
P = struct();
P.fsDefault = 250;
P.epochMs = [-200 1000];
P.baselineMs = [-200 0];
P.maxChannels = 64;
P.minTrialsPerSubjectCell = 3;
P.minSubjectsForStats = 8;
P.targetConditions = {'color','orientation','conjunction'};

% Slow-wave windows after maintenance onset.
P.windows = {
    'SW_300_1000', 300, 1000;
    'SW_300_600',  300, 600;
    'SW_600_1000', 600, 1000
    };

R = defineROIs();
P.roiNames = {'frontal','frontocentral','central','centroparietal','parietal','parieto_occipital','posterior','occipital'};
P.primaryROIs = R;

%% Input
% Prefer the corrected STEP09A2 output. Fallback to STEP09A only if A2 is absent.
step09A2Out = fullfile(resultRoot, 'STEP09A2_ConditionERP_Windows_N22');
step09A1Out = fullfile(resultRoot, 'STEP09A_ConditionERP_Windows_N22');

mergedFileA2 = fullfile(step09A2Out, 'STEP09A2_MergedTrialPhaseTable.csv');
mergedFileA1 = fullfile(step09A1Out, 'STEP09A_MergedTrialPhaseTable.csv');

if exist(mergedFileA2, 'file') == 2
    mergedFile = mergedFileA2;
    fprintf('Using STEP09A2 merged table:\n%s\n', mergedFile);
elseif exist(mergedFileA1, 'file') == 2
    mergedFile = mergedFileA1;
    fprintf('WARNING: STEP09A2 merged table not found. Using older STEP09A table:\n%s\n', mergedFile);
else
    fprintf('\nCould not find either merged table:\n%s\n%s\n', mergedFileA2, mergedFileA1);
    error('STEP09B3 needs STEP09A2_MergedTrialPhaseTable.csv. Run STEP09A2 first.');
end

M = readtable(mergedFile, 'VariableNamingRule', 'preserve');

% Robust column standardization
M.Subject = cellstr(normalizeSubjectKey(M.Subject));
M.Run = cellstr(normalizeRunKey(M.Run));
M.Trial = cellstr(normalizeTrialKey(M.Trial));
M.ConditionLabel = cellstr(normalizeConditionLabel(M.ConditionLabel));
M.PhaseLabel = cellstr(normalizePhaseLabel(M.PhaseLabel));
M.RawEEGPath = string(M.RawEEGPath);

% Keep maintenance only.
M = M(strcmp(M.PhaseLabel,'maintenance') & ismember(M.ConditionLabel, P.targetConditions), :);

if isempty(M)
    error('STEP09B3 cannot proceed: no maintenance rows in STEP09A2 merged table.');
end

writetable(M, fullfile(outDir, 'STEP09B3_MaintenanceMergedTrialPhaseTable.csv'));

%% Extract slow-wave features
Ttrial = extractSlowWaveFeatures09B(M, P, outDir);
if isempty(Ttrial)
    error('STEP09B stopped: no slow-wave features extracted.');
end
writetable(Ttrial, fullfile(outDir, 'STEP09B3_MaintenanceSlowWave_TrialFeatures.csv'));

Tsubj = aggregateSlowWave09B(Ttrial, P.minTrialsPerSubjectCell);
writetable(Tsubj, fullfile(outDir, 'STEP09B3_MaintenanceSlowWave_SubjectCondition.csv'));

Tomni = slowWaveOmnibus09B(Tsubj, P);
Tpair = slowWavePairwise09B(Tsubj, P);

writetable(Tomni, fullfile(outDir, 'STEP09B3_MaintenanceSlowWave_Omnibus.csv'));
writetable(Tpair, fullfile(outDir, 'STEP09B3_MaintenanceSlowWave_Pairwise.csv'));

Tsummary = makeSummary09B(M, Ttrial, Tsubj, Tomni, Tpair);
writetable(Tsummary, fullfile(outDir, 'STEP09B3_AnalysisSummary.csv'));

save(fullfile(outDir, 'STEP09B3_MaintenanceSlowWave_N22_Workspace.mat'), ...
    'P','M','Ttrial','Tsubj','Tomni','Tpair','Tsummary');

fprintf('\n================ STEP09B SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);

%% ===== STEP09B local functions =====

function Ttrial = extractSlowWaveFeatures09B(M, P, outDir)
    rows = {};
    rawFiles = unique(string(M.RawEEGPath), 'stable');
    rawFiles = rawFiles(strlength(rawFiles)>0 & ~ismissing(rawFiles));
    logRows = {};

    for f = 1:numel(rawFiles)
        rawPath = rawFiles(f);
        fprintf('Reading raw EEG %d/%d: %s\n', f, numel(rawFiles), rawPath);

        if ~exist(rawPath, 'file')
            logRows(end+1,:) = {char(rawPath), 0, 'file_not_found'}; %#ok<AGROW>
            continue;
        end

        try
            [EEG, chanLabels, fs] = readRawEEG(rawPath, P.fsDefault, P.maxChannels);
        catch ME
            logRows(end+1,:) = {char(rawPath), 0, ['read_failed: ' ME.message]}; %#ok<AGROW>
            continue;
        end

        fileRows = M(strcmp(string(M.RawEEGPath), rawPath), :);

        for r = 1:height(fileRows)
            onset = round(fileRows.PhaseStartSample(r));
            epochStart = onset + round(P.epochMs(1)/1000*fs);
            epochEnd = onset + round(P.epochMs(2)/1000*fs);

            if ~isfinite(onset) || onset <= 0 || epochStart < 1 || epochEnd > size(EEG,1)
                continue;
            end

            epoch = EEG(epochStart:epochEnd, :);
            tMs = ((epochStart:epochEnd) - onset) / fs * 1000;

            baseIdx = tMs >= P.baselineMs(1) & tMs < P.baselineMs(2);
            if sum(baseIdx) < 3
                continue;
            end

            base = mean(epoch(baseIdx,:), 1, 'omitnan');
            epochBC = epoch - base;

            for w = 1:size(P.windows,1)
                winName = P.windows{w,1};
                winStart = P.windows{w,2};
                winEnd = P.windows{w,3};
                winIdx = tMs >= winStart & tMs <= winEnd;

                if sum(winIdx) < 5
                    continue;
                end

                for rr = 1:numel(P.roiNames)
                    roiName = P.roiNames{rr};
                    roiChans = getfield(P.primaryROIs, roiName); %#ok<GFLD>
                    chanIdx = findChannelIndices(chanLabels, roiChans);

                    if isempty(chanIdx)
                        chanIdx = 1:size(epochBC,2);
                        roiUsed = [roiName '_fallback_allChannels'];
                    else
                        roiUsed = roiName;
                    end

                    roiWave = mean(epochBC(:, chanIdx), 2, 'omitnan');
                    meanAmp = mean(roiWave(winIdx), 'omitnan');
                    medianAmp = median(roiWave(winIdx), 'omitnan');

                    rows(end+1,:) = { ...
                        char(fileRows.Subject(r)), char(string(fileRows.Run(r))), char(string(fileRows.Trial(r))), ...
                        char(string(fileRows.ConditionLabel(r))), char(rawPath), ...
                        winName, roiUsed, winStart, winEnd, meanAmp, medianAmp, numel(chanIdx), fs}; %#ok<AGROW>
                end
            end
        end

        logRows(end+1,:) = {char(rawPath), 1, 'ok'}; %#ok<AGROW>
    end

    if ~isempty(logRows)
        Tlog = cell2table(logRows, 'VariableNames', {'RawEEGPath','ReadOK','Status'});
        writetable(Tlog, fullfile(outDir, 'STEP09B3_RawEEG_ReadLog.csv'));
    end

    if isempty(rows)
        Ttrial = table();
    else
        Ttrial = cell2table(rows, 'VariableNames', ...
            {'Subject','Run','Trial','ConditionLabel','RawEEGPath', ...
            'Window','ROI','WindowStartMs','WindowEndMs','MeanAmplitude','MedianAmplitude','NChannels','SamplingRate'});
    end
end

function Tsubj = aggregateSlowWave09B(Ttrial, minTrials)
    keys = {'Subject','ConditionLabel','Window','ROI'};
    [G, keyTable] = findgroups(Ttrial(:,keys));
    meanAmp = splitapply(@(x) median(x,'omitnan'), Ttrial.MeanAmplitude, G);
    medAmp = splitapply(@(x) median(x,'omitnan'), Ttrial.MedianAmplitude, G);
    nTrials = splitapply(@(x) sum(isfinite(x)), Ttrial.MeanAmplitude, G);

    Tsubj = keyTable;
    Tsubj.SubjectMedianMeanAmplitude = meanAmp;
    Tsubj.SubjectMedianMedianAmplitude = medAmp;
    Tsubj.NTrials = nTrials;
    Tsubj = Tsubj(Tsubj.NTrials >= minTrials, :);
end

function Tomni = slowWaveOmnibus09B(Tsubj, P)
    U = unique(Tsubj(:, {'Window','ROI'}), 'rows');
    rows = {};
    for i = 1:height(U)
        S = Tsubj(strcmp(Tsubj.Window,U.Window{i}) & strcmp(Tsubj.ROI,U.ROI{i}), :);
        W = wideConditions09B(S);
        if height(W) < P.minSubjectsForStats
            continue;
        end
        X = [W.color, W.orientation, W.conjunction];
        p = NaN; chi2 = NaN; kendallW = NaN;
        try
            [p,tbl] = friedman(X,1,'off');
            chi2 = tbl{2,5};
            kendallW = chi2/(height(W)*(3-1));
        catch
        end
        meds = median(X,1,'omitnan');
        conds = {'color','orientation','conjunction'};
        [~,mx] = max(meds);

        rows(end+1,:) = {U.Window{i}, U.ROI{i}, height(W), ...
            meds(1), meds(2), meds(3), conds{mx}, p, chi2, kendallW, strjoin(W.Subject,'|')}; %#ok<AGROW>
    end

    if isempty(rows)
        Tomni = table();
        return;
    end

    Tomni = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','NSubjects','Median_color','Median_orientation','Median_conjunction','MaxCondition','p_Friedman','ChiSquare','KendallW','SubjectsUsed'});
    Tomni.q_FDR = fdrBH09B(Tomni.p_Friedman);
    Tomni = sortrows(Tomni, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
end

function Tpair = slowWavePairwise09B(Tsubj, P)
    pairs = {'color','orientation'; 'color','conjunction'; 'orientation','conjunction'};
    U = unique(Tsubj(:, {'Window','ROI'}), 'rows');
    rows = {};
    for i = 1:height(U)
        S = Tsubj(strcmp(Tsubj.Window,U.Window{i}) & strcmp(Tsubj.ROI,U.ROI{i}), :);
        W = wideConditions09B(S);
        if height(W) < P.minSubjectsForStats
            continue;
        end
        for pp = 1:size(pairs,1)
            a = pairs{pp,1}; b = pairs{pp,2};
            x = W.(a); y = W.(b); d = x-y;
            p = NaN;
            try
                p = signrank(x,y);
            catch
            end
            medDiff = median(d,'omitnan');
            if medDiff > 0
                direction = [a '_greater_than_' b];
            elseif medDiff < 0
                direction = [b '_greater_than_' a];
            else
                direction = 'no_median_difference';
            end
            rows(end+1,:) = {U.Window{i}, U.ROI{i}, [a '_vs_' b], height(W), ...
                median(x,'omitnan'), median(y,'omitnan'), medDiff, p, direction, strjoin(W.Subject,'|')}; %#ok<AGROW>
        end
    end

    if isempty(rows)
        Tpair = table();
        return;
    end

    Tpair = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','Contrast','NSubjects','Median_A','Median_B','MedianDiff_AminusB','p_Signrank','Direction','SubjectsUsed'});
    Tpair.q_FDR = fdrBH09B(Tpair.p_Signrank);
    Tpair = sortrows(Tpair, {'q_FDR','p_Signrank'}, {'ascend','ascend'});
end

function W = wideConditions09B(S)
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
            vals(c) = median(Sc.SubjectMedianMeanAmplitude,'omitnan');
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

function q = fdrBH09B(p)
    p = p(:);
    q = nan(size(p));
    ok = isfinite(p);
    pOK = p(ok);
    if isempty(pOK); return; end
    [ps, idx] = sort(pOK);
    m = numel(ps);
    qs = ps .* m ./ (1:m)';
    qs = flipud(cummin(flipud(qs)));
    qs(qs>1) = 1;
    qOK = nan(size(pOK));
    qOK(idx) = qs;
    q(ok) = qOK;
end

function Tsummary = makeSummary09B(M, Ttrial, Tsubj, Tomni, Tpair)
    rows = {};
    rows(end+1,:) = {'Maintenance trial-phase rows', height(M)}; %#ok<AGROW>
    rows(end+1,:) = {'Subjects', numel(unique(M.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'Slow-wave trial-feature rows', height(Ttrial)}; %#ok<AGROW>
    rows(end+1,:) = {'Subject-condition rows', height(Tsubj)}; %#ok<AGROW>
    rows(end+1,:) = {'Omnibus tests', height(Tomni)}; %#ok<AGROW>
    rows(end+1,:) = {'Omnibus q<0.05', sum(Tomni.q_FDR < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise tests', height(Tpair)}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise q<0.05', sum(Tpair.q_FDR < 0.05, 'omitnan')}; %#ok<AGROW>
    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end




function rois = defineROIs()
    % Shared ROI definitions for STEP09 ERP analyses.
    % These labels are intentionally broad and conservative for 64-channel EEG.

    rois = struct();

    rois.frontal = {'Fp1','Fpz','Fp2','AF7','AF3','AFz','AF4','AF8','F7','F5','F3','F1','Fz','F2','F4','F6','F8'};
    rois.frontocentral = {'F3','F1','Fz','F2','F4','FC5','FC3','FC1','FCz','FC2','FC4','FC6','Cz'};
    rois.central = {'C5','C3','C1','Cz','C2','C4','C6','FC1','FCz','FC2','CP1','CPz','CP2'};
    rois.centroparietal = {'C3','C1','Cz','C2','C4','CP5','CP3','CP1','CPz','CP2','CP4','CP6','Pz'};
    rois.parietal = {'P7','P5','P3','P1','Pz','P2','P4','P6','P8','CP3','CP1','CPz','CP2','CP4'};
    rois.parieto_occipital = {'P3','P1','Pz','P2','P4','PO7','PO3','POz','PO4','PO8','O1','Oz','O2'};
    rois.posterior = {'P3','P1','Pz','P2','P4','P7','P8','PO7','PO3','POz','PO4','PO8','O1','Oz','O2'};
    rois.occipital = {'PO7','PO3','POz','PO4','PO8','O1','Oz','O2'};

    % Component-specific primary ROI recommendation.
    rois.component.N1 = {'posterior','occipital'};
    rois.component.P2 = {'frontocentral','central','parietal'};
    rois.component.N2 = {'frontocentral','central'};
    rois.component.P3 = {'centroparietal','parietal','posterior'};
end


%% ===== Shared helper functions copied from STEP08D2 =====
function allTables = loadCandidateTables(rootDir, articleRoot)
    allTables = {};

    matFiles = [recursiveFiles(rootDir, '*.mat'); recursiveFiles(articleRoot, '*.mat')];
    csvFiles = [recursiveFiles(rootDir, '*.csv'); recursiveFiles(articleRoot, '*.csv')];

    matFiles = unique(matFiles, 'stable');
    csvFiles = unique(csvFiles, 'stable');

    for f = 1:numel(matFiles)
        fpath = matFiles{f};
        try
            info = whos('-file', fpath);
        catch
            continue;
        end

        for v = 1:numel(info)
            if ~strcmp(info(v).class, 'table')
                continue;
            end
            try
                S = load(fpath, info(v).name);
                T = S.(info(v).name);
            catch
                continue;
            end
            if istable(T)
                allTables{end+1} = struct('T', T, 'FilePath', fpath, 'Name', info(v).name, 'SourceType', 'MAT'); %#ok<AGROW>
            end
        end
    end

    for f = 1:numel(csvFiles)
        fpath = csvFiles{f};
        try
            T = readtable(fpath, 'VariableNamingRule', 'preserve');
        catch
            try
                T = readtable(fpath);
            catch
                continue;
            end
        end
        [~, name, ~] = fileparts(fpath);
        allTables{end+1} = struct('T', T, 'FilePath', fpath, 'Name', name, 'SourceType', 'CSV'); %#ok<AGROW>
    end
end

function files = recursiveFiles(rootDir, pattern)
    files = {};
    if ~exist(rootDir, 'dir')
        return;
    end

    d = dir(rootDir);
    for i = 1:numel(d)
        if d(i).isdir
            name = d(i).name;
            if strcmp(name,'.') || strcmp(name,'..')
                continue;
            end
            files = [files; recursiveFiles(fullfile(rootDir, name), pattern)]; %#ok<AGROW>
        end
    end

    dd = dir(fullfile(rootDir, pattern));
    for i = 1:numel(dd)
        files{end+1,1} = fullfile(dd(i).folder, dd(i).name); %#ok<AGROW>
    end
end

function [bestInfo, bestT] = findBestPhaseTable(allTables)
    bestScore = -Inf;
    bestInfo = struct();
    bestT = table();

    for i = 1:numel(allTables)
        T = allTables{i}.T;
        vars = lowerClean(T.Properties.VariableNames);
        score = 0;
        score = score + 2*hasAny(vars, {'subject','subj'});
        score = score + hasAny(vars, {'run'});
        score = score + 2*hasAny(vars, {'trial'});
        score = score + 2*hasAny(vars, {'phase','phaselabel'});
        score = score + 3*hasAny(vars, {'startsample','phasestartsample','sampleonset','retrsample','stimsample','maintsample','start'});
        score = score + hasAny(vars, {'condition','conditionlabel','cond'});
        score = score + min(height(T)/1000, 3);

        name = lower(allTables{i}.Name);
        if contains(name,'phase'); score = score + 3; end
        if contains(name,'trial'); score = score + 1; end
        if contains(name,'taskeeg'); score = score + 1; end

        if score > bestScore
            bestScore = score;
            bestT = T;
            bestInfo = allTables{i};
            bestInfo.Score = score;
        end
    end
end

function [bestInfo, bestT] = findBestCorrectnessTable(allTables)
    bestScore = -Inf;
    bestInfo = struct();
    bestT = table();

    for i = 1:numel(allTables)
        T = allTables{i}.T;
        vars = lowerClean(T.Properties.VariableNames);
        score = 0;
        score = score + 2*hasAny(vars, {'subject','subj'});
        score = score + hasAny(vars, {'run'});
        score = score + 2*hasAny(vars, {'trial'});
        score = score + 5*hasAny(vars, correctnessAliases());
        score = score + 2*hasAny(vars, {'response','answer','acc','accuracy','correct'});
        score = score + hasAny(vars, {'rt','reactiontime','responsetime'});
        score = score + min(height(T)/1000, 3);

        name = lower(allTables{i}.Name);
        if contains(name,'behavior') || contains(name,'behav'); score = score + 4; end
        if contains(name,'rt'); score = score + 2; end
        if contains(name,'trial'); score = score + 1; end

        if score > bestScore && hasAny(vars, correctnessAliases())
            bestScore = score;
            bestT = T;
            bestInfo = allTables{i};
            bestInfo.Score = score;
        end
    end
end

function [bestInfo, bestT] = findBestRawPathTable(allTables)
    bestScore = -Inf;
    bestInfo = struct();
    bestT = table();

    for i = 1:numel(allTables)
        T = allTables{i}.T;
        vars = lowerClean(T.Properties.VariableNames);
        score = 0;
        score = score + 2*hasAny(vars, {'subject','subj'});
        score = score + hasAny(vars, {'run'});
        score = score + 5*hasAny(vars, {'edffile','edfpath','rawfile','rawpath','eegfile','filepath','filename','sourcefile'});
        score = score + min(height(T)/1000, 3);

        name = lower(allTables{i}.Name);
        if contains(name,'filemap') || contains(name,'map'); score = score + 3; end
        if contains(name,'edf'); score = score + 2; end

        if score > bestScore && hasAny(vars, {'edf','edffile','edfpath','rawfile','rawpath','eegfile','filepath','filename','sourcefile'})
            bestScore = score;
            bestT = T;
            bestInfo = allTables{i};
            bestInfo.Score = score;
        end
    end
end

function out = lowerClean(vars)
    out = lower(regexprep(vars, '[^a-zA-Z0-9]', ''));
end

function tf = hasAny(varsLower, aliases)
    tf = false;
    aliases = lower(regexprep(aliases, '[^a-zA-Z0-9]', ''));
    for i = 1:numel(aliases)
        if any(strcmp(varsLower, aliases{i})) || any(contains(varsLower, aliases{i}))
            tf = true;
            return;
        end
    end
end

function aliases = correctnessAliases()
    aliases = {'correct','iscorrect','responsecorrect','accuracy','acc','isaccurate','correctness','answercorrect','trialcorrect','hit','success'};
end

function T = standardizePhaseTable(T)
    T = standardizeCommonKeys(T);

    phaseCol = findColumn(T, {'phase','phaselabel','memoryphase'});
    condCol = findColumn(T, {'condition','conditionlabel','taskcondition','cond'});
    startCol = findColumn(T, {'phasestartsample','startsample','sampleonset','startsamplephase','eventsample','onsetsample','start'});
    endCol = findColumn(T, {'phaseendsample','endsample','sampleoffset','offsetsample','end'});

    if ~isempty(phaseCol); T.PhaseLabel = string(T.(phaseCol)); end
    if ~isempty(condCol); T.ConditionLabel = normalizeConditionLabel(T.(condCol)); end
    if ~isempty(startCol); T.PhaseStartSample = toDouble(T.(startCol)); end
    if ~isempty(endCol); T.PhaseEndSample = toDouble(T.(endCol)); end

    rawCol = findColumn(T, {'edffile','edfpath','rawfile','rawpath','eegfile','filepath','filename','sourcefile'});
    if ~isempty(rawCol); T.RawEEGPath = string(T.(rawCol)); end
end


function T = standardizeForcedCorrectnessTable(T)
    T = standardizeCommonKeys(T);

    if ismember('ConditionLabel', T.Properties.VariableNames)
        T.ConditionLabel = normalizeConditionLabel(T.ConditionLabel);
    elseif ismember('Condition', T.Properties.VariableNames)
        T.ConditionLabel = normalizeConditionLabel(T.Condition);
    end

    if ismember('Correctness', T.Properties.VariableNames)
        T.Correctness = normalizeCorrectness(T.Correctness);
    else
        corrCol = findColumn(T, correctnessAliases());
        if ~isempty(corrCol)
            T.Correctness = normalizeCorrectness(T.(corrCol));
        end
    end

    if ismember('RT_ms', T.Properties.VariableNames)
        T.RT_ms = toDouble(T.RT_ms);
    else
        rtCol = findColumn(T, {'rt','reactiontime','responsetime','responsert','reconstructedrt','responseinterval'});
        if ~isempty(rtCol); T.RT_ms = toDouble(T.(rtCol)); end
    end

    required = {'Subject','Run','Trial','Correctness'};
    missing = required(~ismember(required, T.Properties.VariableNames));
    if ~isempty(missing)
        error('Forced correctness table missing required columns: %s', strjoin(missing, ', '));
    end
end

function keepSubjects = subjectsWithCompleteConditions(T, minConditions)
    keepSubjects = strings(0,1);
    if ~ismember('ConditionLabel', T.Properties.VariableNames)
        keepSubjects = unique(string(T.Subject), 'stable');
        return;
    end
    subjects = unique(string(T.Subject), 'stable');
    for i = 1:numel(subjects)
        S = T(string(T.Subject)==subjects(i), :);
        conds = unique(string(S.ConditionLabel));
        conds = conds(strlength(conds)>0 & ~ismissing(conds));
        if numel(conds) >= minConditions
            keepSubjects(end+1,1) = subjects(i); %#ok<AGROW>
        end
    end
end

function c = normalizeConditionLabel(x)
    s = lower(strtrim(string(x)));
    c = strings(numel(s),1);
    for i = 1:numel(s)
        if any(strcmp(s(i), ["1","color","color_only","color-only","coloronly","c"]))
            c(i) = "color";
        elseif any(strcmp(s(i), ["2","orientation","ori","orientation_only","orientation-only","orientationonly","o"]))
            c(i) = "orientation";
        elseif any(strcmp(s(i), ["3","conjunction","conj","binding"]))
            c(i) = "conjunction";
        else
            c(i) = s(i);
        end
    end
end

function T = standardizeCorrectnessTable(T)
    T = standardizeCommonKeys(T);

    corrCol = findColumn(T, correctnessAliases());
    if ~isempty(corrCol)
        T.Correctness = normalizeCorrectness(T.(corrCol));
    else
        % Try deriving from response and correct-answer columns.
        responseCol = findColumn(T, {'response','answer','participantresponse','userresponse'});
        correctAnswerCol = findColumn(T, {'correctanswer','targetanswer','expectedresponse','correctresponse'});
        if ~isempty(responseCol) && ~isempty(correctAnswerCol)
            T.Correctness = strings(height(T),1);
            resp = string(T.(responseCol));
            answ = string(T.(correctAnswerCol));
            ok = strcmpi(strtrim(resp), strtrim(answ));
            T.Correctness(ok) = "correct";
            T.Correctness(~ok) = "incorrect";
        end
    end

    rtCol = findColumn(T, {'rt','reactiontime','responsetime','responsert','reconstructedrt','responseinterval'});
    if ~isempty(rtCol); T.RT_ms = toDouble(T.(rtCol)); end
end

function T = standardizeRawPathTable(T)
    T = standardizeCommonKeys(T);

    rawCol = findColumn(T, {'edffile','edfpath','rawfile','rawpath','eegfile','filepath','filename','sourcefile'});
    if ~isempty(rawCol)
        T.RawEEGPath = string(T.(rawCol));
    end
end

function T = standardizeCommonKeys(T)
    subjCol = findColumn(T, {'subject','subj','participant'});
    runCol = findColumn(T, {'run','runid','runlabel'});
    trialCol = findColumn(T, {'trial','trialnum','trialnumber','trialid','trialindex'});

    if ~isempty(subjCol); T.Subject = normalizeSubjectKey(T.(subjCol)); end
    if ~isempty(runCol); T.Run = normalizeRunKey(T.(runCol)); end
    if ~isempty(trialCol); T.Trial = normalizeTrialKey(T.(trialCol)); end
end

function s = normalizeSubjectKey(x)
    raw = lower(strtrim(string(x)));
    s = strings(numel(raw),1);
    for i = 1:numel(raw)
        xi = raw(i);
        tok = regexp(xi, 's[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once');
        if isempty(tok); tok = regexp(xi, 'subject[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once'); end
        if isempty(tok); tok = regexp(xi, 'sub[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once'); end
        if isempty(tok); tok = regexp(xi, '^0*([0-9]{1,3})$', 'tokens', 'once'); end

        if ~isempty(tok)
            s(i) = "s" + string(str2double(tok{1}));
        elseif ismissing(xi) || strlength(xi)==0
            s(i) = "";
        else
            s(i) = xi;
        end
    end
end

function r = normalizeRunKey(x)
    raw = lower(strtrim(string(x)));
    r = strings(numel(raw),1);
    for i = 1:numel(raw)
        xi = raw(i);
        tok = regexp(xi, 'run[_\-\s]*0*([0-9]{1,2})', 'tokens', 'once');
        if isempty(tok); tok = regexp(xi, '^0*([0-9]{1,2})$', 'tokens', 'once'); end

        if ~isempty(tok)
            r(i) = "run" + string(str2double(tok{1}));
        elseif ismissing(xi) || strlength(xi)==0
            r(i) = "";
        else
            r(i) = xi;
        end
    end
end

function t = normalizeTrialKey(x)
    raw = strtrim(string(x));
    t = strings(numel(raw),1);
    for i = 1:numel(raw)
        xi = raw(i);
        val = str2double(xi);
        if isfinite(val)
            t(i) = string(round(val));
        elseif ismissing(xi) || strlength(xi)==0
            t(i) = "";
        else
            % Remove common prefixes if present.
            low = lower(xi);
            tok = regexp(low, 'trial[_\-\s]*0*([0-9]+)', 'tokens', 'once');
            if ~isempty(tok)
                t(i) = string(str2double(tok{1}));
            else
                t(i) = low;
            end
        end
    end
end

function s = normalizeID(x)
    % Backward-compatible generic normalizer retained for older helper calls.
    s = string(x);
    s = strtrim(s);
end


function col = findColumn(T, aliases)
    col = '';
    vars = T.Properties.VariableNames;
    varsLower = lowerClean(vars);
    aliases = lower(regexprep(aliases, '[^a-zA-Z0-9]', ''));

    for i = 1:numel(aliases)
        hit = find(strcmp(varsLower, aliases{i}), 1);
        if ~isempty(hit)
            col = vars{hit};
            return;
        end
    end

    for i = 1:numel(aliases)
        hit = find(contains(varsLower, aliases{i}), 1);
        if ~isempty(hit)
            col = vars{hit};
            return;
        end
    end
end

function c = normalizeCorrectness(x)
    s = lower(strtrim(string(x)));
    c = strings(numel(s),1);

    for i = 1:numel(s)
        if ismissing(s(i)) || strlength(s(i)) == 0
            c(i) = "missing";
        elseif any(strcmp(s(i), ["1","true","correct","yes","y","hit","success","accurate"]))
            c(i) = "correct";
        elseif any(strcmp(s(i), ["0","false","incorrect","wrong","no","n","miss","error","inaccurate"]))
            c(i) = "incorrect";
        else
            val = str2double(s(i));
            if isfinite(val)
                if val == 1
                    c(i) = "correct";
                elseif val == 0
                    c(i) = "incorrect";
                else
                    c(i) = "other";
                end
            else
                c(i) = "other";
            end
        end
    end
end

function phase = normalizePhaseLabel(x)
    s = lower(strtrim(string(x)));
    phase = strings(numel(s),1);

    for i = 1:numel(s)
        if contains(s(i), 'stim')
            phase(i) = "stimulus";
        elseif contains(s(i), 'maint') || contains(s(i), 'delay')
            phase(i) = "maintenance";
        elseif contains(s(i), 'retr') || contains(s(i), 'probe') || contains(s(i), 'test')
            phase(i) = "retrieval";
        else
            phase(i) = s(i);
        end
    end
end

function x = toDouble(v)
    if isnumeric(v) || islogical(v)
        x = double(v(:));
    else
        x = str2double(string(v(:)));
    end
end

function [M, status] = mergePhaseCorrectRaw(Tphase, Tcorr, Traw)
    M = table();
    status = 'not_started';

    requiredPhase = {'Subject','Run','Trial','PhaseLabel','PhaseStartSample'};
    requiredCorr = {'Subject','Run','Trial','Correctness'};

    if ~all(ismember(requiredPhase, Tphase.Properties.VariableNames))
        missing = requiredPhase(~ismember(requiredPhase, Tphase.Properties.VariableNames));
        status = ['phase_table_missing_required_columns: ' strjoin(missing, ',')];
        return;
    end
    if ~all(ismember(requiredCorr, Tcorr.Properties.VariableNames))
        missing = requiredCorr(~ismember(requiredCorr, Tcorr.Properties.VariableNames));
        status = ['correctness_table_missing_required_columns: ' strjoin(missing, ',')];
        return;
    end

    % Prefer matching by condition as well, because STEP08C6 creates
    % condition-specific trialData rows. This prevents assigning color
    % correctness to an orientation/conjunction phase row with the same
    % trial number.
    if ismember('ConditionLabel', Tphase.Properties.VariableNames) && ismember('ConditionLabel', Tcorr.Properties.VariableNames)
        keySets = {
            {'Subject','Run','ConditionLabel','Trial'}
            {'Subject','Run','Trial'}
            };
    else
        keySets = {
            {'Subject','Run','Trial'}
            };
    end

    mergeTried = strings(0,1);

    for kk = 1:numel(keySets)
        keys = keySets{kk};
        if ~all(ismember(keys, Tphase.Properties.VariableNames)) || ~all(ismember(keys, Tcorr.Properties.VariableNames))
            continue;
        end

        corrKeep = unique([keys, {'Correctness','RT_ms'}], 'stable');
        corrKeep = corrKeep(ismember(corrKeep, Tcorr.Properties.VariableNames));

        % Deduplicate correctness keys before joining.
        TcorrSmall = Tcorr(:, corrKeep);
        try
            TcorrSmall = unique(TcorrSmall, 'rows');
        catch
        end

        try
            Mtry = innerjoin(Tphase, TcorrSmall, 'Keys', keys);
        catch ME
            mergeTried(end+1,1) = "failed_" + strjoin(string(keys), "_") + ": " + string(ME.message); %#ok<AGROW>
            continue;
        end

        mergeTried(end+1,1) = "keys_" + strjoin(string(keys), "_") + "_rows_" + string(height(Mtry)); %#ok<AGROW>

        if ~isempty(Mtry)
            M = Mtry;
            status = ['merged_success_keys_' strjoin(keys, '_')];
            break;
        end
    end

    if isempty(M)
        status = ['phase_correct_merge_empty_after_keyfix: ' char(strjoin(mergeTried, ' | '))];
        return;
    end

    % Add raw path if already exists.
    if ~ismember('RawEEGPath', M.Properties.VariableNames)
        M.RawEEGPath = strings(height(M),1);
    end

    % Merge raw paths from raw table if needed.
    if ~isempty(Traw) && ismember('RawEEGPath', Traw.Properties.VariableNames)
        rawKeys = intersect({'Subject','Run'}, intersect(M.Properties.VariableNames, Traw.Properties.VariableNames), 'stable');
        if ismember('Subject', rawKeys)
            rawKeep = unique([rawKeys, {'RawEEGPath'}], 'stable');
            TrawSmall = unique(Traw(:, rawKeep), 'rows');

            try
                M2 = outerjoin(M, TrawSmall, 'Keys', rawKeys, 'MergeKeys', true);
                if ismember('RawEEGPath_M', M2.Properties.VariableNames) && ismember('RawEEGPath_TrawSmall', M2.Properties.VariableNames)
                    left = string(M2.RawEEGPath_M);
                    right = string(M2.RawEEGPath_TrawSmall);
                    useRight = (strlength(left)==0 | ismissing(left)) & strlength(right)>0 & ~ismissing(right);
                    left(useRight) = right(useRight);
                    M2.RawEEGPath = left;
                    M2.RawEEGPath_M = [];
                    M2.RawEEGPath_TrawSmall = [];
                elseif ismember('RawEEGPath_TrawSmall', M2.Properties.VariableNames)
                    M2.RawEEGPath = string(M2.RawEEGPath_TrawSmall);
                    M2.RawEEGPath_TrawSmall = [];
                end
                M = M2;
            catch
                % keep M without raw merge
            end
        end
    end
end


function paths = resolveRawPaths(paths)
    paths = string(paths);
    roots = {
        '/Users/ghazal/Desktop/Article2';
        '/Users/ghazal/Desktop/Article2/Subjects';
        '/Users/ghazal/Desktop/IPM/Subjects';
        '/Users/ghazal/Desktop'
        };

    for i = 1:numel(paths)
        p = strtrim(paths(i));
        if strlength(p)==0 || ismissing(p)
            continue;
        end

        if exist(p, 'file')
            paths(i) = p;
            continue;
        end

        % Try searching by filename only.
        [~, name, ext] = fileparts(p);
        if strlength(ext)==0
            patterns = {[char(name) '.edf'], [char(name) '.mat']};
        else
            patterns = {[char(name) char(ext)]};
        end

        found = '';
        for r = 1:numel(roots)
            for pp = 1:numel(patterns)
                files = recursiveFiles(roots{r}, patterns{pp});
                if ~isempty(files)
                    found = files{1};
                    break;
                end
            end
            if ~isempty(found); break; end
        end

        if ~isempty(found)
            paths(i) = string(found);
        end
    end
end

function counts = computeTrialCounts(M)
    keys = {'Subject','ConditionLabel','PhaseLabel','Correctness'};
    for i = 1:numel(keys)
        if ~ismember(keys{i}, M.Properties.VariableNames)
            M.(keys{i}) = repmat("unknown", height(M),1);
        end
    end
    counts = groupcounts(M, keys);
    counts.Properties.VariableNames{end} = 'NTrials';
end


function [M, rawMap, status] = attachAutoRawPaths(M, articleRoot, rootDir, outDir)
    status = 'not_started';
    rawMap = table();

    if ~ismember('Subject', M.Properties.VariableNames)
        status = 'no_subject_column_in_merged_table';
        return;
    end

    if ~ismember('Run', M.Properties.VariableNames)
        M.Run = repmat("", height(M), 1);
    end

    searchRoots = {
        fullfile(articleRoot, 'Subjects');
        articleRoot;
        '/Users/ghazal/Desktop/IPM/Subjects';
        '/Users/ghazal/Desktop/IPM';
        rootDir
        };

    rawMap = buildAutoRawMap(searchRoots);

    if isempty(rawMap)
        status = 'no_raw_files_found_in_search_roots';
        return;
    end

    % Save all candidates for inspection.
    try
        writetable(rawMap, fullfile(outDir, 'STEP08D_AllRawFileCandidates.csv'));
    catch
    end

    M.RawEEGPath = strings(height(M),1);
    M.RawPathMatchMode = strings(height(M),1);
    M.RawPathMatchConfidence = nan(height(M),1);

    subjM = normalizeSubjectString(M.Subject);
    runM = normalizeRunString(M.Run);

    subjMap = normalizeSubjectString(rawMap.Subject);
    runMap = normalizeRunString(rawMap.Run);

    for i = 1:height(M)
        subj = subjM(i);
        run = runM(i);

        % First pass: exact subject + run.
        idx = strcmp(subjMap, subj) & strcmp(runMap, run) & strlength(run) > 0;
        if any(idx)
            cand = rawMap(idx,:);
            [~,best] = max(cand.Confidence);
            M.RawEEGPath(i) = string(cand.RawEEGPath{best});
            M.RawPathMatchMode(i) = "subject_run_exact";
            M.RawPathMatchConfidence(i) = cand.Confidence(best);
            continue;
        end

        % Second pass: subject-only if there is only one high-confidence candidate.
        idx = strcmp(subjMap, subj);
        if any(idx)
            cand = rawMap(idx,:);
            % Prefer files that are not resting EO/EC and have task/run hints.
            [bestConf,best] = max(cand.Confidence);
            if height(cand) == 1 || bestConf >= 4
                M.RawEEGPath(i) = string(cand.RawEEGPath{best});
                M.RawPathMatchMode(i) = "subject_only_best";
                M.RawPathMatchConfidence(i) = cand.Confidence(best);
                continue;
            end
        end
    end

    nMatched = sum(strlength(M.RawEEGPath)>0 & ~ismissing(M.RawEEGPath));
    if nMatched == 0
        status = 'auto_map_built_but_no_rows_matched';
    elseif nMatched < height(M)
        status = sprintf('partial_raw_map_match_%d_of_%d_rows', nMatched, height(M));
    else
        status = 'all_rows_raw_mapped';
    end
end

function rawMap = buildAutoRawMap(searchRoots)
    rows = {};

    for r = 1:numel(searchRoots)
        root = searchRoots{r};
        if ~exist(root, 'dir')
            continue;
        end

        files = [recursiveFiles(root, '*.edf'); recursiveFiles(root, '*.mat')];
        files = unique(files, 'stable');

        for i = 1:numel(files)
            fpath = files{i};
            [subj, runLabel, confidence, reason, isRestingLike] = inferSubjectRunFromPath(fpath);

            if strlength(subj) == 0
                continue;
            end

            if isRestingLike
                confidence = confidence - 5;
                reason = [reason '|resting_or_eye_file_penalty'];
            end

            rows(end+1,:) = {char(subj), char(runLabel), fpath, confidence, reason, isRestingLike}; %#ok<AGROW>
        end
    end

    if isempty(rows)
        rawMap = table();
    else
        rawMap = cell2table(rows, 'VariableNames', {'Subject','Run','RawEEGPath','Confidence','InferenceReason','IsRestingLike'});

        % Prefer likely task files and remove exact duplicate candidates.
        rawMap = deduplicateRawMap(rawMap);
        rawMap = sortrows(rawMap, {'Subject','Run','Confidence','IsRestingLike'}, {'ascend','ascend','descend','ascend'});
    end
end

function [subj, runLabel, confidence, reason, isRestingLike] = inferSubjectRunFromPath(fpath)
    s = lower(string(fpath));
    [~, baseName, ext] = fileparts(char(fpath));
    base = lower(string(baseName));
    subj = "";
    runLabel = "";
    confidence = 0;
    reason = "";
    isRestingLike = false;

    % Resting detection must use filename only, not the full path
    % because paths such as Desktop contain "ec".
    restPatterns = ["eye open","eye-open","eye_open","eyeopen", ...
                    "eye close","eye-close","eye_close","eyeclose", ...
                    "rest","resting"];
    for k = 1:numel(restPatterns)
        if contains(base, restPatterns(k))
            isRestingLike = true;
            break;
        end
    end

    % Very specific EO/EC detection only as separated tokens in filename.
    if ~isRestingLike
        if ~isempty(regexp(base, '(^|[_\-\s])eo($|[_\-\s])', 'once')) || ...
           ~isempty(regexp(base, '(^|[_\-\s])ec($|[_\-\s])', 'once'))
            isRestingLike = true;
        end
    end

    % Subject patterns from full path: s1, s01, subject1, sub1.
    tokens = regexp(s, '(?<![a-z0-9])s[_\-\s]*0*([0-9]{1,3})(?![a-z0-9])', 'tokens', 'once');
    if isempty(tokens)
        tokens = regexp(s, 'subject[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once');
    end
    if isempty(tokens)
        tokens = regexp(s, 'sub[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once');
    end

    if ~isempty(tokens)
        subj = "s" + string(str2double(tokens{1}));
        confidence = confidence + 3;
        reason = reason + "subject_from_path";
    end

    % Run patterns from filename first.
    rtok = regexp(base, 'run[_\-\s]*0*([0-9]{1,2})', 'tokens', 'once');
    if isempty(rtok)
        rtok = regexp(base, '(^|[_\-\s])r[_\-\s]*0*([0-9]{1,2})($|[_\-\s])', 'tokens', 'once');
        if ~isempty(rtok)
            rtok = rtok(2);
        end
    end

    % Important for this dataset: task files often look like
    % ali-shahab1.edf, ali-shahab2.edf, ali-shahab3.edf or workspace_name1.mat.
    if isempty(rtok) && ~isRestingLike
        rtok = regexp(base, '([0-9]{1,2})$', 'tokens', 'once');
    end

    if ~isempty(rtok)
        runLabel = "run" + string(str2double(rtok{1}));
        confidence = confidence + 4;
        reason = reason + "|run_from_filename";
    end

    % Task/working-memory hints.
    if contains(base, 'task') || contains(base, 'wm') || contains(base, 'working') || contains(base, 'memory')
        confidence = confidence + 2;
        reason = reason + "|task_hint";
    end

    if strcmpi(ext, '.edf')
        confidence = confidence + 2;
        reason = reason + "|edf";
    elseif strcmpi(ext, '.mat')
        confidence = confidence + 0.5;
        reason = reason + "|mat";
    end

    % Prefer files whose filename has a trailing run number and not eye/rest.
    if strlength(runLabel) > 0 && ~isRestingLike
        confidence = confidence + 2;
        reason = reason + "|likely_task_run_file";
    end

    % If subject was not found in file path, try parent-folder-based numeric folder.
    if strlength(subj) == 0
        parts = split(s, filesep);
        for k = numel(parts):-1:1
            p = parts(k);
            tok = regexp(p, '^0*([0-9]{1,3})$', 'tokens', 'once');
            if ~isempty(tok)
                subj = "s" + string(str2double(tok{1}));
                confidence = confidence + 1;
                reason = reason + "|subject_from_numeric_folder";
                break;
            end
        end
    end
end

function s = normalizeSubjectString(x)
    x = string(x);
    s = strings(numel(x),1);

    for i = 1:numel(x)
        xi = lower(strtrim(x(i)));
        tok = regexp(xi, 's[_\-\s]*0*([0-9]{1,3})', 'tokens', 'once');
        if isempty(tok)
            tok = regexp(xi, '0*([0-9]{1,3})', 'tokens', 'once');
        end
        if ~isempty(tok)
            s(i) = "s" + string(str2double(tok{1}));
        else
            s(i) = xi;
        end
    end
end

function r = normalizeRunString(x)
    x = string(x);
    r = strings(numel(x),1);

    for i = 1:numel(x)
        xi = lower(strtrim(x(i)));
        tok = regexp(xi, 'run[_\-\s]*0*([0-9]{1,2})', 'tokens', 'once');
        if isempty(tok)
            tok = regexp(xi, 'r[_\-\s]*0*([0-9]{1,2})', 'tokens', 'once');
        end
        if isempty(tok)
            tok = regexp(xi, '0*([0-9]{1,2})', 'tokens', 'once');
        end
        if ~isempty(tok)
            r(i) = "run" + string(str2double(tok{1}));
        else
            r(i) = xi;
        end
    end
end

function Ttrial = extractERPFeatures(M, P, outDir)
    rows = {};

    rawFiles = unique(string(M.RawEEGPath), 'stable');
    rawFiles = rawFiles(strlength(rawFiles)>0 & ~ismissing(rawFiles));

    logRows = {};

    for f = 1:numel(rawFiles)
        rawPath = rawFiles(f);
        fprintf('Reading raw EEG %d/%d: %s\n', f, numel(rawFiles), rawPath);

        if ~exist(rawPath, 'file')
            logRows(end+1,:) = {char(rawPath), 0, 'file_not_found'}; %#ok<AGROW>
            continue;
        end

        try
            [EEG, chanLabels, fs] = readRawEEG(rawPath, P.fsDefault, P.maxChannels);
        catch ME
            logRows(end+1,:) = {char(rawPath), 0, ['read_failed: ' ME.message]}; %#ok<AGROW>
            continue;
        end

        if isempty(EEG)
            logRows(end+1,:) = {char(rawPath), 0, 'empty_eeg'}; %#ok<AGROW>
            continue;
        end

        fileRows = M(strcmp(string(M.RawEEGPath), rawPath), :);

        for r = 1:height(fileRows)
            onset = round(fileRows.PhaseStartSample(r));
            if ~isfinite(onset) || onset <= 0
                continue;
            end

            epochStart = onset + round(P.epochMs(1)/1000*fs);
            epochEnd = onset + round(P.epochMs(2)/1000*fs);

            if epochStart < 1 || epochEnd > size(EEG,1)
                continue;
            end

            epoch = EEG(epochStart:epochEnd, :);
            tMs = ((epochStart:epochEnd) - onset) / fs * 1000;

            baseIdx = tMs >= P.baselineMs(1) & tMs < P.baselineMs(2);
            if sum(baseIdx) < 3
                continue;
            end

            base = mean(epoch(baseIdx,:), 1, 'omitnan');
            epochBC = epoch - base;

            for c = 1:size(P.components,1)
                compName = P.components{c,1};
                winStart = P.components{c,2};
                winEnd = P.components{c,3};
                polarity = P.components{c,4};

                winIdx = tMs >= winStart & tMs <= winEnd;
                if sum(winIdx) < 2
                    continue;
                end

                compROIs = P.primaryROIs.component.(compName);

                for rr = 1:numel(compROIs)
                    roiName = compROIs{rr};
                    roiChans = getfield(P.primaryROIs, roiName); %#ok<GFLD>
                    chanIdx = findChannelIndices(chanLabels, roiChans);

                    if isempty(chanIdx)
                        % Fallback: use all channels if labels do not match.
                        chanIdx = 1:size(epochBC,2);
                        roiUsed = [roiName '_fallback_allChannels'];
                    else
                        roiUsed = roiName;
                    end

                    roiWave = mean(epochBC(:, chanIdx), 2, 'omitnan');
                    meanAmp = mean(roiWave(winIdx), 'omitnan');

                    if strcmp(polarity, 'negative')
                        [peakAmp, loc] = min(roiWave(winIdx));
                    else
                        [peakAmp, loc] = max(roiWave(winIdx));
                    end
                    winTimes = tMs(winIdx);
                    peakLatency = winTimes(loc);

                    rows(end+1,:) = { ...
                        char(fileRows.Subject(r)), getOptionalString(fileRows,'Run',r), getOptionalString(fileRows,'Trial',r), ...
                        char(fileRows.ConditionLabel(r)), char(fileRows.PhaseLabel(r)), char(fileRows.Correctness(r)), ...
                        char(rawPath), compName, roiUsed, winStart, winEnd, meanAmp, peakAmp, peakLatency, ...
                        numel(chanIdx), fs}; %#ok<AGROW>
                end
            end
        end

        logRows(end+1,:) = {char(rawPath), 1, 'ok'}; %#ok<AGROW>
    end

    if ~isempty(logRows)
        Tlog = cell2table(logRows, 'VariableNames', {'RawEEGPath','ReadOK','Status'});
        writetable(Tlog, fullfile(outDir, 'STEP08D2_RawEEG_ReadLog.csv'));
    end

    if isempty(rows)
        Ttrial = table();
    else
        Ttrial = cell2table(rows, 'VariableNames', ...
            {'Subject','Run','Trial','ConditionLabel','PhaseLabel','Correctness','RawEEGPath', ...
            'Component','ROI','WindowStartMs','WindowEndMs','MeanAmplitude','PeakAmplitude','PeakLatencyMs','NChannels','SamplingRate'});
    end
end

function [EEG, chanLabels, fs] = readRawEEG(rawPath, fsDefault, maxChannels)
    EEG = [];
    chanLabels = {};
    fs = fsDefault;

    rawPath = char(rawPath);
    [~,~,ext] = fileparts(rawPath);

    if strcmpi(ext, '.edf')
        if exist('edfread', 'file') ~= 2
            error('edfread is not available in this MATLAB installation.');
        end

        info = [];
        try
            info = edfinfo(rawPath);
        catch
        end

        TT = edfread(rawPath);

        try
            chanLabels = TT.Properties.VariableNames;
        catch
            chanLabels = {};
        end

        EEG = timetableToMatrix(TT);

        if ~isempty(info)
            try
                if isprop(info, 'SignalLabels')
                    chanLabels = cellstr(string(info.SignalLabels));
                end
            catch
            end

            try
                if isprop(info, 'NumSamples') && isprop(info, 'DataRecordDuration')
                    durSec = seconds(info.DataRecordDuration);
                    fsCandidate = double(info.NumSamples(1)) / durSec;
                    if isfinite(fsCandidate) && fsCandidate > 0
                        fs = fsCandidate;
                    end
                end
            catch
            end
        end

    elseif strcmpi(ext, '.mat')
        S = load(rawPath);
        [EEG, chanLabels, fs] = matToEEG(S, fsDefault);

    else
        error('Unsupported raw EEG file extension: %s', ext);
    end

    if isempty(EEG)
        error('Could not convert raw file to numeric EEG matrix.');
    end

    if size(EEG,1) < size(EEG,2)
        % Usually EEG should be samples x channels.
        if size(EEG,2) > 500 && size(EEG,1) <= 128
            EEG = EEG';
        end
    end

    if size(EEG,2) > maxChannels
        EEG = EEG(:,1:maxChannels);
        if numel(chanLabels) >= maxChannels
            chanLabels = chanLabels(1:maxChannels);
        end
    end

    if isempty(chanLabels) || numel(chanLabels) ~= size(EEG,2)
        chanLabels = default64Labels(size(EEG,2));
    end

    EEG = double(EEG);
end

function EEG = timetableToMatrix(TT)
    vars = TT.Properties.VariableNames;
    cols = cell(numel(vars),1);

    for i = 1:numel(vars)
        x = TT.(vars{i});

        if iscell(x)
            try
                x = vertcat(x{:});
            catch
                x = cellfun(@(z) z(:), x, 'UniformOutput', false);
                x = vertcat(x{:});
            end
        elseif istimetable(x) || istable(x)
            x = table2array(x);
        end

        x = double(x(:));
        cols{i} = x;
    end

    minLen = min(cellfun(@numel, cols));
    EEG = nan(minLen, numel(cols));
    for i = 1:numel(cols)
        EEG(:,i) = cols{i}(1:minLen);
    end
end

function [EEG, chanLabels, fs] = matToEEG(S, fsDefault)
    EEG = [];
    chanLabels = {};
    fs = fsDefault;

    names = fieldnames(S);

    % Sampling rate
    for i = 1:numel(names)
        nm = lower(names{i});
        if any(strcmp(nm, {'fs','srate','samplingrate','samplerate'}))
            val = S.(names{i});
            if isnumeric(val) && isscalar(val) && isfinite(val)
                fs = double(val);
            end
        end
    end

    % Channel labels
    for i = 1:numel(names)
        nm = lower(names{i});
        if contains(nm,'chan') && contains(nm,'label')
            try
                chanLabels = cellstr(string(S.(names{i})));
            catch
            end
        end
    end

    % Numeric EEG matrix candidate
    bestName = '';
    bestSize = 0;
    for i = 1:numel(names)
        val = S.(names{i});
        if isnumeric(val) && ismatrix(val)
            [a,b] = size(val);
            if min(a,b) >= 16 && max(a,b) > bestSize
                bestName = names{i};
                bestSize = max(a,b);
            end
        end
    end

    if ~isempty(bestName)
        EEG = S.(bestName);
    end
end

function labels = default64Labels(n)
    base = {'Fp1','Fpz','Fp2','AF7','AF3','AFz','AF4','AF8','F7','F5','F3','F1','Fz','F2','F4','F6','F8', ...
        'FT7','FC5','FC3','FC1','FCz','FC2','FC4','FC6','FT8','T7','C5','C3','C1','Cz','C2','C4','C6','T8', ...
        'TP7','CP5','CP3','CP1','CPz','CP2','CP4','CP6','TP8','P7','P5','P3','P1','Pz','P2','P4','P6','P8', ...
        'PO7','PO3','POz','PO4','PO8','O1','Oz','O2','Iz','M1','M2'};
    if n <= numel(base)
        labels = base(1:n);
    else
        labels = cell(1,n);
        for i = 1:n
            labels{i} = sprintf('Ch%d', i);
        end
    end
end

function idx = findChannelIndices(chanLabels, roiChans)
    idx = [];
    chanClean = lower(regexprep(chanLabels, '[^a-zA-Z0-9]', ''));
    roiClean = lower(regexprep(roiChans, '[^a-zA-Z0-9]', ''));

    for i = 1:numel(roiClean)
        hit = find(strcmp(chanClean, roiClean{i}), 1);
        if ~isempty(hit)
            idx(end+1) = hit; %#ok<AGROW>
        end
    end

    idx = unique(idx);
end

function s = getOptionalString(T, col, row)
    if ismember(col, T.Properties.VariableNames)
        s = char(string(T.(col)(row)));
    else
        s = '';
    end
end

function Tsubj = aggregateSubjectComponents(Ttrial)
    keys = {'Subject','ConditionLabel','PhaseLabel','Correctness','Component','ROI'};
    [G, keyTable] = findgroups(Ttrial(:,keys));

    meanAmp = splitapply(@(x) median(x,'omitnan'), Ttrial.MeanAmplitude, G);
    peakAmp = splitapply(@(x) median(x,'omitnan'), Ttrial.PeakAmplitude, G);
    peakLat = splitapply(@(x) median(x,'omitnan'), Ttrial.PeakLatencyMs, G);
    nTrials = splitapply(@(x) sum(isfinite(x)), Ttrial.MeanAmplitude, G);

    Tsubj = keyTable;
    Tsubj.MedianMeanAmplitude = meanAmp;
    Tsubj.MedianPeakAmplitude = peakAmp;
    Tsubj.MedianPeakLatencyMs = peakLat;
    Tsubj.NTrials = nTrials;
end

function Tstats = primaryCorrectIncorrectStats(Tsubj, P)
    % Collapsed across task condition; primary phase/component/ROI correct vs incorrect.
    keys = {'Subject','PhaseLabel','Correctness','Component','ROI'};
    [G, keyTable] = findgroups(Tsubj(:,keys));
    amp = splitapply(@(x,w) weightedMedian(x,w), Tsubj.MedianMeanAmplitude, Tsubj.NTrials, G);
    ntr = splitapply(@sum, Tsubj.NTrials, G);

    T = keyTable;
    T.Amplitude = amp;
    T.NTrials = ntr;

    testKeys = {'PhaseLabel','Component','ROI'};
    U = unique(T(:,testKeys), 'rows');

    rows = {};
    for i = 1:height(U)
        S = T(strcmp(T.PhaseLabel,U.PhaseLabel{i}) & strcmp(T.Component,U.Component{i}) & strcmp(T.ROI,U.ROI{i}), :);
        W = wideCorrectIncorrect(S, P.minTrialsPerCorrectness);
        if isempty(W)
            continue;
        end

        diffCI = W.CorrectAmp - W.IncorrectAmp;
        n = height(W);
        p = NaN;
        if n >= 3 && any(abs(diffCI)>0)
            try
                p = signrank(W.CorrectAmp, W.IncorrectAmp);
            catch
                p = NaN;
            end
        end

        rows(end+1,:) = {U.PhaseLabel{i}, U.Component{i}, U.ROI{i}, n, ...
            median(W.CorrectAmp,'omitnan'), median(W.IncorrectAmp,'omitnan'), median(diffCI,'omitnan'), ...
            p, strjoin(W.Subject,'|')}; %#ok<AGROW>
    end

    if isempty(rows)
        Tstats = table();
        return;
    end

    Tstats = cell2table(rows, 'VariableNames', ...
        {'PhaseLabel','Component','ROI','NSubjects','MedianCorrect','MedianIncorrect','MedianDiff_CorrectMinusIncorrect','p_Signrank','SubjectsUsed'});

    Tstats.q_FDR = fdrBH(Tstats.p_Signrank);
    Tstats = sortrows(Tstats, {'q_FDR','p_Signrank'}, {'ascend','ascend'});
end

function Tstats = secondaryByConditionStats(Tsubj, P)
    keys = {'ConditionLabel','PhaseLabel','Component','ROI'};
    U = unique(Tsubj(:,keys), 'rows');

    rows = {};
    for i = 1:height(U)
        S = Tsubj(strcmp(Tsubj.ConditionLabel,U.ConditionLabel{i}) & strcmp(Tsubj.PhaseLabel,U.PhaseLabel{i}) & ...
                  strcmp(Tsubj.Component,U.Component{i}) & strcmp(Tsubj.ROI,U.ROI{i}), :);

        W = wideCorrectIncorrect(S, P.minTrialsPerCorrectness);
        if isempty(W)
            continue;
        end

        diffCI = W.CorrectAmp - W.IncorrectAmp;
        n = height(W);
        p = NaN;
        if n >= 3 && any(abs(diffCI)>0)
            try
                p = signrank(W.CorrectAmp, W.IncorrectAmp);
            catch
                p = NaN;
            end
        end

        rows(end+1,:) = {U.ConditionLabel{i}, U.PhaseLabel{i}, U.Component{i}, U.ROI{i}, n, ...
            median(W.CorrectAmp,'omitnan'), median(W.IncorrectAmp,'omitnan'), median(diffCI,'omitnan'), ...
            p, strjoin(W.Subject,'|')}; %#ok<AGROW>
    end

    if isempty(rows)
        Tstats = table();
        return;
    end

    Tstats = cell2table(rows, 'VariableNames', ...
        {'ConditionLabel','PhaseLabel','Component','ROI','NSubjects','MedianCorrect','MedianIncorrect','MedianDiff_CorrectMinusIncorrect','p_Signrank','SubjectsUsed'});

    Tstats.q_FDR = fdrBH(Tstats.p_Signrank);
    Tstats = sortrows(Tstats, {'q_FDR','p_Signrank'}, {'ascend','ascend'});
end


function ampCol = getAmplitudeColumnName(T)
    if ismember('MedianMeanAmplitude', T.Properties.VariableNames)
        ampCol = 'MedianMeanAmplitude';
    elseif ismember('Amplitude', T.Properties.VariableNames)
        ampCol = 'Amplitude';
    elseif ismember('MeanAmplitude', T.Properties.VariableNames)
        ampCol = 'MeanAmplitude';
    else
        error('No amplitude column found. Expected MedianMeanAmplitude, Amplitude, or MeanAmplitude.');
    end
end

function W = wideCorrectIncorrect(S, minTrials)
    subjects = unique(S.Subject, 'stable');
    rows = {};

    for i = 1:numel(subjects)
        subj = subjects{i};
        Sc = S(strcmp(S.Subject, subj) & strcmp(S.Correctness,'correct'), :);
        Si = S(strcmp(S.Subject, subj) & strcmp(S.Correctness,'incorrect'), :);

        if isempty(Sc) || isempty(Si)
            continue;
        end

        nC = sum(Sc.NTrials);
        nI = sum(Si.NTrials);

        if nC < minTrials || nI < minTrials
            continue;
        end

        ampCol = getAmplitudeColumnName(S);
        ampC = weightedMedian(Sc.(ampCol), Sc.NTrials);
        ampI = weightedMedian(Si.(ampCol), Si.NTrials);

        rows(end+1,:) = {subj, ampC, ampI, nC, nI}; %#ok<AGROW>
    end

    if isempty(rows)
        W = table();
    else
        W = cell2table(rows, 'VariableNames', {'Subject','CorrectAmp','IncorrectAmp','NCorrectTrials','NIncorrectTrials'});
    end
end

function Tcorr = accuracyComponentCorrelations(Tsubj, trialCounts)
    % Accuracy per Subject x Condition x Phase.
    if isempty(trialCounts)
        Tcorr = table();
        return;
    end

    Tacc = makeAccuracyTable(trialCounts);

    % Component amplitude collapsed across correctness.
    keys = {'Subject','ConditionLabel','PhaseLabel','Component','ROI'};
    [G, keyTable] = findgroups(Tsubj(:,keys));
    amp = splitapply(@(x,w) weightedMedian(x,w), Tsubj.MedianMeanAmplitude, Tsubj.NTrials, G);
    ntr = splitapply(@sum, Tsubj.NTrials, G);

    Tamp = keyTable;
    Tamp.Amplitude = amp;
    Tamp.NTrials = ntr;

    M = innerjoin(Tamp, Tacc, 'Keys', {'Subject','ConditionLabel','PhaseLabel'});

    U = unique(M(:, {'ConditionLabel','PhaseLabel','Component','ROI'}), 'rows');

    rows = {};
    for i = 1:height(U)
        S = M(strcmp(M.ConditionLabel,U.ConditionLabel{i}) & strcmp(M.PhaseLabel,U.PhaseLabel{i}) & ...
              strcmp(M.Component,U.Component{i}) & strcmp(M.ROI,U.ROI{i}), :);

        ok = isfinite(S.Amplitude) & isfinite(S.Accuracy);
        S = S(ok,:);
        n = height(S);

        rho = NaN; p = NaN;
        if n >= 5 && numel(unique(S.Accuracy)) >= 3 && numel(unique(S.Amplitude)) >= 3
            try
                [rho,p] = corr(S.Amplitude, S.Accuracy, 'Type','Spearman', 'Rows','complete');
            catch
                [rho,p] = corrSpearmanFallback(S.Amplitude, S.Accuracy);
            end
        end

        rows(end+1,:) = {U.ConditionLabel{i}, U.PhaseLabel{i}, U.Component{i}, U.ROI{i}, n, rho, p, strjoin(S.Subject,'|')}; %#ok<AGROW>
    end

    if isempty(rows)
        Tcorr = table();
        return;
    end

    Tcorr = cell2table(rows, 'VariableNames', ...
        {'ConditionLabel','PhaseLabel','Component','ROI','NSubjects','SpearmanRho','p_Spearman','SubjectsUsed'});

    Tcorr.q_FDR = fdrBH(Tcorr.p_Spearman);
    Tcorr = sortrows(Tcorr, {'q_FDR','p_Spearman'}, {'ascend','ascend'});
end

function Tacc = makeAccuracyTable(trialCounts)
    keys = {'Subject','ConditionLabel','PhaseLabel'};
    U = unique(trialCounts(:,keys), 'rows');

    rows = {};
    for i = 1:height(U)
        S = trialCounts(strcmp(trialCounts.Subject,U.Subject{i}) & strcmp(trialCounts.ConditionLabel,U.ConditionLabel{i}) & strcmp(trialCounts.PhaseLabel,U.PhaseLabel{i}), :);

        nCorrect = sum(S.NTrials(strcmp(S.Correctness,'correct')));
        nIncorrect = sum(S.NTrials(strcmp(S.Correctness,'incorrect')));
        nTotal = nCorrect + nIncorrect;

        if nTotal > 0
            acc = nCorrect / nTotal;
        else
            acc = NaN;
        end

        rows(end+1,:) = {U.Subject{i}, U.ConditionLabel{i}, U.PhaseLabel{i}, nCorrect, nIncorrect, nTotal, acc}; %#ok<AGROW>
    end

    Tacc = cell2table(rows, 'VariableNames', {'Subject','ConditionLabel','PhaseLabel','NCorrect','NIncorrect','NTotal','Accuracy'});
end

function m = weightedMedian(x,w)
    x = x(:);
    w = w(:);
    ok = isfinite(x) & isfinite(w) & w > 0;
    x = x(ok);
    w = w(ok);

    if isempty(x)
        m = NaN;
        return;
    end

    [x,idx] = sort(x);
    w = w(idx);
    cw = cumsum(w) / sum(w);
    m = x(find(cw >= 0.5, 1, 'first'));
end

function [rho,p] = corrSpearmanFallback(x,y)
    rho = NaN; p = NaN;
    x = x(:); y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok); y = y(ok);
    if numel(x) < 5
        return;
    end
    rx = tiedrank(x);
    ry = tiedrank(y);
    C = corrcoef(rx, ry);
    rho = C(1,2);
    n = numel(x);
    if n > 2 && abs(rho) < 1
        tval = rho * sqrt((n-2)/(1-rho^2));
        p = 2 * (1 - tcdf(abs(tval), n-2));
    end
end

function q = fdrBH(p)
    p = p(:);
    q = nan(size(p));
    ok = isfinite(p);
    pOK = p(ok);

    if isempty(pOK)
        return;
    end

    [ps, idx] = sort(pOK);
    m = numel(ps);
    qs = ps .* m ./ (1:m)';
    qs = flipud(cummin(flipud(qs)));
    qs(qs>1) = 1;

    qOK = nan(size(pOK));
    qOK(idx) = qs;
    q(ok) = qOK;
end

function Tsummary = makeAnalysisSummary(M, Ttrial, Tsubj, Tprimary, Tsecondary, Tacc)
    rows = {};
    rows(end+1,:) = {'Merged trial-phase rows', height(M)}; %#ok<AGROW>
    rows(end+1,:) = {'Subjects in merged data', numel(unique(M.Subject))}; %#ok<AGROW>
    rows(end+1,:) = {'ERP trial-component rows', height(Ttrial)}; %#ok<AGROW>
    rows(end+1,:) = {'Subject-level component rows', height(Tsubj)}; %#ok<AGROW>
    rows(end+1,:) = {'Primary correct-incorrect tests', height(Tprimary)}; %#ok<AGROW>
    rows(end+1,:) = {'Primary q<0.05 effects', sum(Tprimary.q_FDR < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Secondary by-condition tests', height(Tsecondary)}; %#ok<AGROW>
    rows(end+1,:) = {'Secondary q<0.05 effects', sum(Tsecondary.q_FDR < 0.05, 'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Accuracy-correlation tests', height(Tacc)}; %#ok<AGROW>
    rows(end+1,:) = {'Accuracy-correlation q<0.05 effects', sum(Tacc.q_FDR < 0.05, 'omitnan')}; %#ok<AGROW>

    if ~isempty(Tprimary)
        [~,iBest] = min(Tprimary.q_FDR);
        rows(end+1,:) = {'Top primary effect', sprintf('%s_%s_%s', Tprimary.PhaseLabel{iBest}, Tprimary.Component{iBest}, Tprimary.ROI{iBest})}; %#ok<AGROW>
        rows(end+1,:) = {'Top primary q', Tprimary.q_FDR(iBest)}; %#ok<AGROW>
    end

    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function txt = makeEnglishMethodText()
    txt = ['We performed a phase-specific subsequent-accuracy ERP analysis to test whether trial outcome was associated with event-related voltage deflections during encoding, maintenance, and retrieval. ', ...
        'Single-trial EEG epochs were extracted from -200 to 600 ms around each phase onset and baseline-corrected using the -200 to 0 ms pre-onset interval. ', ...
        'Mean amplitudes were extracted from predefined component windows: N1 (80-140 ms), P2 (150-250 ms), N2 (200-350 ms), and P3 (300-500 ms). ', ...
        'For stimulus and retrieval onsets, these windows were interpreted as conventional ERP component windows. For maintenance onset, the same windows were treated as phase-locked N1-like, P2-like, N2-like, and P3-like amplitude windows rather than canonical sensory components. ', ...
        'Component amplitudes were summarized over component-specific ROIs and aggregated to subject-level medians separately for correct and incorrect trials. ', ...
        'Correct and incorrect trials were compared using paired nonparametric signed-rank tests when both outcomes had sufficient trials within a subject-cell. Spearman correlations were used to test associations between component amplitudes and accuracy. False discovery rate correction was applied across tested component-window families.'];
end

function txt = makePersianMethodText()
    txt = ['در این تحلیل، یک تحلیل ERP مبتنی بر درستی پاسخ و وابسته به فاز انجام شد تا مشخص شود آیا درست یا غلط بودن پاسخ با تغییرات ولتاژ وابسته به رویداد در فازهای encoding، maintenance و retrieval ارتباط دارد یا خیر. ', ...
        'برای هر trial، اپوک EEG از ۲۰۰ میلی‌ثانیه قبل تا ۶۰۰ میلی‌ثانیه بعد از شروع هر فاز استخراج شد و baseline correction با استفاده از بازه ۲۰۰- تا ۰ میلی‌ثانیه انجام شد. ', ...
        'دامنه میانگین در پنجره‌های زمانی از پیش تعریف‌شده استخراج شد: N1 در بازه ۸۰ تا ۱۴۰ میلی‌ثانیه، P2 در بازه ۱۵۰ تا ۲۵۰ میلی‌ثانیه، N2 در بازه ۲۰۰ تا ۳۵۰ میلی‌ثانیه، و P3 در بازه ۳۰۰ تا ۵۰۰ میلی‌ثانیه. ', ...
        'برای فازهای stimulus و retrieval این پنجره‌ها به‌عنوان پنجره‌های ERP کلاسیک تفسیر شدند، اما برای maintenance از اصطلاح N1-like، P2-like، N2-like و P3-like استفاده شد؛ زیرا این فاز الزاماً مؤلفه‌های حسی کلاسیک را بازتاب نمی‌دهد. ', ...
        'دامنه مؤلفه‌ها در ROIهای اختصاصی هر مؤلفه خلاصه شد و سپس برای هر آزمودنی، وضعیت تکلیف، فاز، مؤلفه و درستی پاسخ، میانه subject-level محاسبه شد. ', ...
        'مقایسه correct و incorrect با آزمون ناپارامتری signed-rank زوجی انجام شد، مشروط بر اینکه تعداد trial کافی در هر دو گروه وجود داشته باشد. همچنین ارتباط دامنه مؤلفه‌ها با accuracy با همبستگی Spearman بررسی شد و اصلاح FDR برای خانواده آزمون‌های ERP اعمال شد.'];
end

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Could not write file: %s', fpath);
    end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

function name = getInfoName(info)
    name = '';
    if isstruct(info) && isfield(info,'Name')
        name = info.Name;
    end
end

function path = getInfoPath(info)
    path = '';
    if isstruct(info) && isfield(info,'FilePath')
        path = info.FilePath;
    end
end


%% ===== Guaranteed helper functions added for STEP08D =====

function rawMap = deduplicateRawMap(rawMap)
    % Robust duplicate removal for raw file candidates.
    % This version tolerates nested cells, strings, chars, numerics, and
    % mixed cell/string columns produced by older MATLAB table behavior.

    if isempty(rawMap) || ~istable(rawMap)
        return;
    end

    if ~ismember('RawEEGPath', rawMap.Properties.VariableNames)
        return;
    end

    textCols = {'Subject','Run','RawEEGPath','InferenceReason'};
    for ii = 1:numel(textCols)
        col = textCols{ii};
        if ismember(col, rawMap.Properties.VariableNames)
            rawMap.(col) = safeCellstrColumn(rawMap.(col));
        end
    end

    if ismember('Confidence', rawMap.Properties.VariableNames)
        rawMap.Confidence = localToDoubleColumn(rawMap.Confidence);
    else
        rawMap.Confidence = zeros(height(rawMap),1);
    end

    pathStrings = string(safeCellstrColumn(rawMap.RawEEGPath));
    bad = ismissing(pathStrings) | strlength(pathStrings)==0;
    rawMap(bad,:) = [];
    pathStrings(bad) = [];

    if isempty(rawMap)
        return;
    end

    [uPaths, ~, groupIdx] = unique(pathStrings, 'stable');
    keep = false(height(rawMap),1);

    for g = 1:numel(uPaths)
        rows = find(groupIdx == g);
        if isempty(rows)
            continue;
        end
        conf = rawMap.Confidence(rows);
        conf(~isfinite(conf)) = -Inf;
        [~, bestLocal] = max(conf);
        keep(rows(bestLocal)) = true;
    end

    rawMap = rawMap(keep,:);

    try
        rawMap = sortrows(rawMap, {'Subject','Run','Confidence'}, {'ascend','ascend','descend'});
    catch
        try
            rawMap = sortrows(rawMap, 'Confidence', 'descend');
        catch
        end
    end
end

function out = safeCellstrColumn(v)
    % Convert any table column into an n-by-1 cell array of character vectors.
    % Handles nested cells safely.

    if istable(v)
        try
            v = table2cell(v);
        catch
            v = {};
        end
    end

    if ischar(v)
        out = cellstr(v);
        out = out(:);
        return;
    end

    if isstring(v) || iscategorical(v)
        s = string(v(:));
        out = cell(numel(s),1);
        for i = 1:numel(s)
            if ismissing(s(i))
                out{i} = '';
            else
                out{i} = char(s(i));
            end
        end
        return;
    end

    if isnumeric(v) || islogical(v)
        v = v(:);
        out = cell(numel(v),1);
        for i = 1:numel(v)
            if isfinite(double(v(i)))
                out{i} = char(string(double(v(i))));
            else
                out{i} = '';
            end
        end
        return;
    end

    if iscell(v)
        v = v(:);
        out = cell(numel(v),1);
        for i = 1:numel(v)
            out{i} = safeScalarToChar(v{i});
        end
        return;
    end

    try
        s = string(v(:));
        out = cellstr(s);
        out = out(:);
    catch
        out = repmat({''}, numel(v), 1);
    end
end

function s = safeScalarToChar(x)
    % Convert one possibly nested cell element to one char scalar.

    if isempty(x)
        s = '';
        return;
    end

    if iscell(x)
        % Flatten nested cell and join nonempty pieces.
        pieces = {};
        for k = 1:numel(x)
            piece = safeScalarToChar(x{k});
            if ~isempty(piece)
                pieces{end+1} = piece; %#ok<AGROW>
            end
        end
        if isempty(pieces)
            s = '';
        else
            s = strjoin(pieces, '|');
        end
        return;
    end

    if ischar(x)
        if isrow(x)
            s = x;
        else
            s = strjoin(cellstr(x), '|');
        end
        return;
    end

    if isstring(x) || iscategorical(x)
        xs = string(x(:));
        xs(ismissing(xs)) = "";
        if numel(xs) == 0
            s = '';
        else
            xs = xs(strlength(xs)>0);
            if isempty(xs)
                s = '';
            else
                s = char(strjoin(xs, '|'));
            end
        end
        return;
    end

    if isnumeric(x) || islogical(x)
        x = x(:);
        if isempty(x)
            s = '';
        elseif numel(x) == 1
            if isfinite(double(x))
                s = char(string(double(x)));
            else
                s = '';
            end
        else
            vals = strings(numel(x),1);
            for ii = 1:numel(x)
                if isfinite(double(x(ii)))
                    vals(ii) = string(double(x(ii)));
                else
                    vals(ii) = "";
                end
            end
            vals = vals(strlength(vals)>0);
            s = char(strjoin(vals, '|'));
        end
        return;
    end

    try
        xs = string(x);
        if ismissing(xs)
            s = '';
        else
            s = char(xs);
        end
    catch
        s = '';
    end
end

function x = localToDoubleColumn(v)
    if isnumeric(v) || islogical(v)
        x = double(v(:));
        return;
    end

    if iscell(v)
        v = v(:);
        x = nan(numel(v),1);
        for i = 1:numel(v)
            try
                c = safeScalarToChar(v{i});
                x(i) = str2double(c);
            catch
                x(i) = NaN;
            end
        end
        return;
    end

    if ischar(v)
        x = str2double(cellstr(v));
        x = x(:);
        return;
    end

    try
        x = str2double(string(v(:)));
    catch
        try
            x = nan(numel(v),1);
        catch
            x = NaN;
        end
    end
end


%% STEP03U_TPHASES_TO_EDF_MAP.m
% Map validated T_phases files to local task EDF files.
%
% Run after:
%   STEP03T_TPHASES_ONLY.m
%
% Input:
%   STEP03T_TPhases_SelectedMap.csv
%
% Optional input:
%   STEP03A_TaskEDF_Inventory.csv
%
% Output:
%   STEP03U_TPhases_EDF_Map folder created beside the STEP03T output folder.
%
% Main outputs:
%   STEP03U_TPhases_EDF_Map.csv
%   STEP03U_TPhases_EDF_Map_READY.csv
%   STEP03U_TPhases_EDF_MapSummary.csv
%   STEP03U_TPhases_EDF_Unmapped.csv
%
% Purpose:
%   T_phases is now the trusted epoch/phase map. This script connects each
%   subject/run T_phases file to the corresponding task EDF file. It does
%   not extract EEG features yet.

clear; clc;

%% Paths
% Try the current folder first; otherwise ask the user to select the
% validated STEP03T map. This keeps the public script machine-independent.
tMapFile = fullfile(pwd, 'STEP03T_TPhases_SelectedMap.csv');

if ~exist(tMapFile, 'file')
    [selFile, selPath] = uigetfile('*.csv', ...
        'Select STEP03T_TPhases_SelectedMap.csv');
    if isequal(selFile, 0)
        error('T_phases selected map was not selected.');
    end
    tMapFile = fullfile(selPath, selFile);
end

% Infer the analysis root from:
%   <analysisRoot>/STEP03T_TPhasesOnly/STEP03T_TPhases_SelectedMap.csv
tDir = fileparts(tMapFile);
rootDir = fileparts(tDir);

edfScanDir = fullfile(rootDir, 'STEP03A_TaskEEG_Scan');
edfInventoryFile = fullfile(edfScanDir, 'STEP03A_TaskEDF_Inventory.csv');

outDir = fullfile(rootDir, 'STEP03U_TPhases_EDF_Map');
if ~exist(outDir, 'dir'); mkdir(outDir); end

Tt = readtable(tMapFile);

fprintf('\n=== STEP03U T_PHASES TO EDF MAP ===\n');
fprintf('T_phases subject-run rows: %d\n', height(Tt));

%% Load or create EDF inventory
if exist(edfInventoryFile, 'file')
    Tedf = readtable(edfInventoryFile);
    fprintf('Using existing EDF inventory:\n%s\n', edfInventoryFile);
else
    fprintf('EDF inventory not found. Please select the folder containing task EDF files.\n');
    edfRoot = uigetdir(pwd, 'Select folder containing task EDF files');
    if isequal(edfRoot, 0)
        error('No EDF folder selected.');
    end
    Tedf = scanEDF(edfRoot);
end

fprintf('EDF rows available: %d\n', height(Tedf));

%% Normalize run IDs and task/rest flags
Tt.Run2 = Tt.Run;
for i = 1:height(Tt)
    if ~isfinite(Tt.Run2(i))
        Tt.Run2(i) = inferRunID(Tt.FileName{i});
    end
end

Tedf.LocalRun = nan(height(Tedf),1);
Tedf.IsRestLike2 = false(height(Tedf),1);
Tedf.IsFilteredLike = false(height(Tedf),1);
Tedf.IsTaskLike2 = false(height(Tedf),1);

for i = 1:height(Tedf)
    Tedf.LocalRun(i) = inferRunID(Tedf.FileName{i});
    Tedf.IsRestLike2(i) = isRestFileName(Tedf.FileName{i});
    Tedf.IsFilteredLike(i) = contains(lower(Tedf.FileName{i}), 'filtered');
    Tedf.IsTaskLike2(i) = ~Tedf.IsRestLike2(i);
end

TtaskEDF = Tedf(Tedf.IsTaskLike2 == true & Tedf.IsFilteredLike == false, :);

%% Map each T_phases file to EDF
mapRows = {};

for i = 1:height(Tt)
    subj = Tt.Subject{i};
    runID = Tt.Run2(i);

    selectedEDFName = '';
    selectedEDFPath = '';
    selectedEDFBytes = NaN;
    source = '';
    status = '';
    note = '';

    Es = TtaskEDF(strcmp(TtaskEDF.Subject, subj), :);

    % Priority 1: same subject, same run.
    if isfinite(runID) && height(Es) > 0
        Erun = Es(Es.LocalRun == runID, :);

        if height(Erun) == 1
            selectedEDFName = Erun.FileName{1};
            selectedEDFPath = Erun.FilePath{1};
            selectedEDFBytes = Erun.FileBytes(1);
            source = 'same_subject_same_run';
        elseif height(Erun) > 1
            [~, idxMax] = max(Erun.FileBytes);
            selectedEDFName = Erun.FileName{idxMax};
            selectedEDFPath = Erun.FilePath{idxMax};
            selectedEDFBytes = Erun.FileBytes(idxMax);
            source = 'same_subject_same_run_largest';
            note = sprintf('Multiple EDF candidates for same subject/run: %d. Largest selected.', height(Erun));
        end
    end

    % Priority 2: same folder basename similarity.
    if isempty(selectedEDFPath)
        try
            [tFolder, tBase, ~] = fileparts(Tt.FilePath{i});
            Es2 = Es;
            bestScore = -Inf;
            bestIdx = NaN;
            for e = 1:height(Es2)
                [~, eBase, ~] = fileparts(Es2.FileName{e});
                sc = nameSimilarityScore(tBase, eBase);
                if isfinite(runID) && Es2.LocalRun(e) == runID
                    sc = sc + 10;
                end
                if sc > bestScore
                    bestScore = sc;
                    bestIdx = e;
                end
            end
            if isfinite(bestIdx) && bestScore >= 10
                selectedEDFName = Es2.FileName{bestIdx};
                selectedEDFPath = Es2.FilePath{bestIdx};
                selectedEDFBytes = Es2.FileBytes(bestIdx);
                source = 'same_subject_name_similarity';
                note = appendNote(note, sprintf('Name similarity mapping score %.2f.', bestScore));
            end
        catch ME
            note = appendNote(note, ['Name similarity mapping failed: ' ME.message]);
        end
    end

    % Decision
    if ~isempty(selectedEDFPath) && exist(selectedEDFPath, 'file')
        status = 'ready';
    elseif ~isempty(selectedEDFPath)
        status = 'mapped_but_file_missing';
    else
        status = 'missing_edf_mapping';
    end

    mapRows(end+1,:) = {subj, runID, Tt.FileName{i}, Tt.RelativePath{i}, Tt.FilePath{i}, Tt.NRows(i), ...
        selectedEDFName, selectedEDFPath, selectedEDFBytes, source, status, note}; %#ok<SAGROW>
end

Tmap = cell2table(mapRows, 'VariableNames', ...
    {'Subject','Run','TphasesFileName','TphasesRelativePath','TphasesFilePath','TphasesNRows', ...
     'EDFFileName','EDFFilePath','EDFFileBytes','EDFSource','MapStatus','Note'});

Tready = Tmap(strcmp(Tmap.MapStatus, 'ready'), :);
Tunmapped = Tmap(~strcmp(Tmap.MapStatus, 'ready'), :);

writetable(Tmap, fullfile(outDir, 'STEP03U_TPhases_EDF_Map.csv'));
writetable(Tready, fullfile(outDir, 'STEP03U_TPhases_EDF_Map_READY.csv'));
writetable(Tunmapped, fullfile(outDir, 'STEP03U_TPhases_EDF_Unmapped.csv'));

%% Coverage summary
subjectsAll = unique(Tmap.Subject, 'stable');
covRows = {};

for s = 1:numel(subjectsAll)
    subj = subjectsAll{s};
    M = Tmap(strcmp(Tmap.Subject, subj), :);
    R = M(strcmp(M.MapStatus, 'ready'), :);

    covRows(end+1,:) = {subj, height(M), height(R), joinRuns(M.Run), joinRuns(R.Run), sum(R.TphasesNRows, 'omitnan')}; %#ok<SAGROW>
end

Tcov = cell2table(covRows, 'VariableNames', ...
    {'Subject','NTphasesRuns','NReadyRuns','TphasesRuns','ReadyRuns','ReadyTphasesRows'});
writetable(Tcov, fullfile(outDir, 'STEP03U_TPhases_EDF_Coverage_BySubject.csv'));

%% Duplicate-size warning
dupRows = {};
if height(Tready) > 0
    [G, sizes] = findgroups(Tready.EDFFileBytes);
    for g = 1:max(G)
        idx = find(G == g);
        if numel(idx) > 1
            entries = cell(numel(idx),1);
            for k = 1:numel(idx)
                entries{k} = sprintf('%s_run%d:%s', Tready.Subject{idx(k)}, Tready.Run(idx(k)), Tready.EDFFileName{idx(k)});
            end
            dupRows(end+1,:) = {sizes(g), numel(idx), strjoin(entries, ' | ')}; %#ok<SAGROW>
        end
    end
end

if isempty(dupRows)
    TdupSize = cell2table(cell(0,3), 'VariableNames', {'FileBytes','NFiles','Files'});
else
    TdupSize = cell2table(dupRows, 'VariableNames', {'FileBytes','NFiles','Files'});
end
writetable(TdupSize, fullfile(outDir, 'STEP03U_TPhases_EDF_DuplicateSizeFlags.csv'));

%% Summary
summaryRows = {};
summaryRows(end+1,:) = {'T_phases selected subject-run rows', height(Tmap)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Ready T_phases plus EDF rows', height(Tready)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Subjects with ready T_phases plus EDF', numel(unique(Tready.Subject))}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Unmapped rows', height(Tunmapped)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Total ready T_phases rows', sum(Tready.TphasesNRows, 'omitnan')}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Duplicate EDF file-size warning groups', height(TdupSize)}; %#ok<SAGROW>

Tsummary = cell2table(summaryRows, 'VariableNames', {'Metric','Value'});
writetable(Tsummary, fullfile(outDir, 'STEP03U_TPhases_EDF_MapSummary.csv'));

save(fullfile(outDir, 'STEP03U_TPhases_EDF_Map_Workspace.mat'), ...
    'Tmap','Tready','Tunmapped','Tcov','TdupSize','Tsummary','Tedf','TtaskEDF');

fprintf('\n================ STEP03U SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);

if height(Tunmapped) > 0
    fprintf('\nUnmapped rows:\n');
    disp(Tunmapped(:, {'Subject','Run','TphasesFileName','MapStatus','Note'}));
end

%% ===================== FUNCTIONS =====================
function Tedf = scanEDF(rootDir)
    edfFiles = dir(fullfile(rootDir, '**', '*.edf'));
    if isempty(edfFiles)
        edfFiles = recursiveDir(rootDir, '*.edf');
    end
    rows = {};
    for i = 1:numel(edfFiles)
        fpath = fullfile(edfFiles(i).folder, edfFiles(i).name);
        rel = strrep(fpath, [rootDir filesep], '');
        subj = inferSubject(fpath, rootDir);
        rows(end+1,:) = {subj, edfFiles(i).name, rel, fpath, edfFiles(i).bytes}; %#ok<SAGROW>
    end
    Tedf = cell2table(rows, 'VariableNames', {'Subject','FileName','RelativePath','FilePath','FileBytes'});
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

function subj = inferSubject(filePath, rootDir)
    rel = strrep(filePath, [rootDir filesep], '');
    parts = regexp(rel, filesep, 'split');
    if numel(parts) > 1
        subj = parts{1};
    else
        [~, base, ~] = fileparts(filePath);
        toks = regexp(base, '[_\-\s]+', 'split');
        subj = toks{1};
    end
end

function runID = inferRunID(fname)
    runID = NaN;
    [~, base, ~] = fileparts(fname);
    low = lower(base);

    low = regexprep(low, '(eye[\s_\-]*open|eye[\s_\-]*close|eyes[\s_\-]*open|eyes[\s_\-]*close|rest|filtered|main)', '');

    tok = regexp(low, 'run[\s_\-]*(\d+)', 'tokens', 'once');
    if isempty(tok)
        tok = regexp(low, 'workspace.*?(\d+)', 'tokens', 'once');
    end
    if isempty(tok)
        tok = regexp(low, '[_\-\s](\d+)$', 'tokens', 'once');
    end
    if isempty(tok)
        tok = regexp(low, '([0-9]+)$', 'tokens', 'once');
    end
    if ~isempty(tok)
        runID = str2double(tok{1});
    end
end

function tf = isRestFileName(fname)
    low = lower(fname);
    low2 = regexprep(low, '[\s_\-]+', '');
    tf = contains(low2, 'eyeopen') || contains(low2, 'eyeclose') || ...
         contains(low2, 'eyesopen') || contains(low2, 'eyesclose') || ...
         contains(low2, 'resting') || contains(low2, 'rest');
end

function s = nameSimilarityScore(a,b)
    a = lower(regexprep(a, '[^a-z0-9]', ''));
    b = lower(regexprep(b, '[^a-z0-9]', ''));

    if isempty(a) || isempty(b)
        s = 0;
        return;
    end

    s = 0;
    if contains(a,b) || contains(b,a)
        s = s + 10;
    end

    % common prefix length
    n = min(numel(a), numel(b));
    cp = 0;
    for i = 1:n
        if a(i) == b(i)
            cp = cp + 1;
        else
            break;
        end
    end
    s = s + cp / max(n,1) * 5;
end

function out = appendNote(note, extra)
    if isempty(note)
        out = extra;
    else
        out = [note ' ' extra];
    end
end

function txt = joinRuns(x)
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        txt = '';
        return;
    end
    x = sort(unique(x));
    parts = arrayfun(@(z) sprintf('%g', z), x, 'UniformOutput', false);
    txt = strjoin(parts, ' | ');
end

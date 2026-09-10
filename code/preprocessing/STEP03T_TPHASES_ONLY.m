%% STEP03T_TPHASES_ONLY.m
% Find and map T_phases only.
%
% Purpose:
%   This script ignores preprocessing status and EEG variables completely.
%   It only searches MAT files for a variable named T_phases, inspects its
%   columns, and builds a subject/run T_phases map.
%
% Output:
%   STEP03T_TPhasesOnly under the selected Article2 Analysis folder.

% Main outputs:
%   STEP03T_TPhases_AllFiles.csv
%   STEP03T_TPhases_ValidFiles.csv
%   STEP03T_TPhases_SelectedMap.csv
%   STEP03T_TPhases_Duplicates_BySubjectRun.csv
%   STEP03T_TPhases_Coverage_BySubject.csv
%   STEP03T_TPhases_Summary.csv
%
% Notes:
%   This script does NOT inspect or load EEG data.
%   It loads only T_phases from each MAT file.

clear; clc;

%% Paths
outRoot = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(outRoot, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir = fullfile(outRoot, 'STEP03T_TPhasesOnly');
if ~exist(outDir, 'dir'); mkdir(outDir); end

selectedRoot = uigetdir(pwd, ...
    'Select folder containing subject MAT/workspace files');
if isequal(selectedRoot, 0)
    error('No folder selected.');
end

searchRoot = selectedRoot;

%% Find MAT files
matFiles = dir(fullfile(searchRoot, '**', '*.mat'));
if isempty(matFiles)
    matFiles = recursiveDir(searchRoot, '*.mat');
end
matFiles = matFiles(~[matFiles.isdir]);

% Remove duplicate full paths
if ~isempty(matFiles)
    fullPaths = cell(numel(matFiles),1);
    for i = 1:numel(matFiles)
        fullPaths{i} = fullfile(matFiles(i).folder, matFiles(i).name);
    end
    [~, ia] = unique(fullPaths, 'stable');
    matFiles = matFiles(ia);
end

fprintf('MAT files found: %d\n', numel(matFiles));

%% Scan
allRows = {};

for i = 1:numel(matFiles)
    fpath = fullfile(matFiles(i).folder, matFiles(i).name);
    fname = matFiles(i).name;
    rel = strrep(fpath, [searchRoot filesep], '');

    subj = inferSubject(fpath, searchRoot);
    runID = inferRunID(fname);

    hasT = false;
    status = 'no_T_phases';
    note = '';
    nRows = NaN;
    nCols = NaN;
    columnNames = '';
    hasTrialNum = false;
    hasCondition = false;
    hasStimSample = false;
    hasMaintSample = false;
    hasRetrSample = false;
    hasStimTime = false;
    hasMaintTime = false;
    hasRetrTime = false;
    nConditions = NaN;
    conditionPreview = '';
    minTrial = NaN;
    maxTrial = NaN;
    qualityScore = 0;

    try
        W = whos('-file', fpath);
        varNames = {W.name};

        if any(strcmp(varNames, 'T_phases'))
            hasT = true;

            S = load(fpath, 'T_phases');
            T = S.T_phases;

            if istable(T) || istimetable(T)
                if istimetable(T)
                    T = timetable2table(T);
                end

                status = 'ok';
                nRows = height(T);
                nCols = width(T);
                cols = T.Properties.VariableNames;
                colsLow = lower(cols);
                columnNames = strjoin(cols, ' | ');

                hasTrialNum = hasColumn(colsLow, {'trialnum','trial','trialnumber'});
                hasCondition = hasColumn(colsLow, {'condition','cond'});
                hasStimSample = hasColumn(colsLow, {'stimsample','stim_sample','stimstartsample'});
                hasMaintSample = hasColumn(colsLow, {'maintsample','maint_sample','maintstartsample','maintenancesample'});
                hasRetrSample = hasColumn(colsLow, {'retrsample','retr_sample','retrstartsample','retrievalsample'});
                hasStimTime = hasColumn(colsLow, {'stimtimesec','stim_time_sec','stimtime'});
                hasMaintTime = hasColumn(colsLow, {'mainttimesec','maint_time_sec','mainttime','maintenancetime'});
                hasRetrTime = hasColumn(colsLow, {'retrtimesec','retr_time_sec','retrtime','retrievaltime'});

                % Condition summary
                condCol = findColumn(colsLow, {'condition','cond'});
                if ~isempty(condCol)
                    try
                        c = T.(cols{condCol});
                        c = toNumericVector(c);
                        uc = unique(c(isfinite(c)));
                        nConditions = numel(uc);
                        conditionPreview = joinNumberPreview(uc, 10);
                    catch
                        conditionPreview = '<unreadable>';
                    end
                end

                % Trial summary
                trialCol = findColumn(colsLow, {'trialnum','trial','trialnumber'});
                if ~isempty(trialCol)
                    try
                        tr = T.(cols{trialCol});
                        tr = toNumericVector(tr);
                        minTrial = min(tr, [], 'omitnan');
                        maxTrial = max(tr, [], 'omitnan');
                    catch
                    end
                end

                % Quality score for selecting one T_phases per subject/run.
                qualityScore = 0;
                qualityScore = qualityScore + 10 * hasCondition;
                qualityScore = qualityScore + 10 * hasStimSample;
                qualityScore = qualityScore + 10 * hasMaintSample;
                qualityScore = qualityScore + 10 * hasRetrSample;
                qualityScore = qualityScore + 3 * hasTrialNum;
                qualityScore = qualityScore + 3 * (nConditions >= 3);
                qualityScore = qualityScore + min(nRows, 150) / 10;

                if contains(lower(fname), 'workspace')
                    qualityScore = qualityScore + 2;
                end

            else
                status = 'T_phases_not_table';
                note = ['T_phases class: ' class(T)];
            end
        end

    catch ME
        status = 'error';
        note = ME.message;
    end

    allRows(end+1,:) = {subj, runID, fname, rel, fpath, matFiles(i).bytes, hasT, status, nRows, nCols, ...
        hasTrialNum, hasCondition, hasStimSample, hasMaintSample, hasRetrSample, hasStimTime, hasMaintTime, hasRetrTime, ...
        nConditions, conditionPreview, minTrial, maxTrial, qualityScore, columnNames, note}; %#ok<SAGROW>
end

Tall = cell2table(allRows, 'VariableNames', ...
    {'Subject','Run','FileName','RelativePath','FilePath','FileBytes','Has_T_phases','Status','NRows','NColumns', ...
     'HasTrialNum','HasCondition','HasStimSample','HasMaintSample','HasRetrSample','HasStimTimeSec','HasMaintTimeSec','HasRetrTimeSec', ...
     'NConditions','ConditionPreview','MinTrial','MaxTrial','QualityScore','ColumnNames','Note'});

writetable(Tall, fullfile(outDir, 'STEP03T_TPhases_AllFiles.csv'));

Tvalid = Tall(Tall.Has_T_phases == true & strcmp(Tall.Status, 'ok') & ...
              Tall.HasCondition == true & Tall.HasStimSample == true & ...
              Tall.HasMaintSample == true & Tall.HasRetrSample == true, :);

Tvalid = sortrows(Tvalid, {'Subject','Run','QualityScore','NRows'}, {'ascend','ascend','descend','descend'});
writetable(Tvalid, fullfile(outDir, 'STEP03T_TPhases_ValidFiles.csv'));

%% Select one best T_phases per subject/run
selectedRows = {};
dupRows = {};

if ~isempty(Tvalid)
    keys = unique(Tvalid(:, {'Subject','Run'}), 'stable');

    for k = 1:height(keys)
        idx = strcmp(Tvalid.Subject, keys.Subject{k}) & Tvalid.Run == keys.Run(k);
        Tk = Tvalid(idx, :);
        Tk = sortrows(Tk, {'QualityScore','NRows'}, {'descend','descend'});

        best = Tk(1,:);
        selectedRows(end+1,:) = table2cell(best); %#ok<SAGROW>

        if height(Tk) > 1
            fileList = strjoin(Tk.FileName, ' | ');
            dupRows(end+1,:) = {keys.Subject{k}, keys.Run(k), height(Tk), best.FileName{1}, fileList}; %#ok<SAGROW>
        end
    end
end

if isempty(selectedRows)
    Tselected = Tvalid([]);
else
    Tselected = cell2table(selectedRows, 'VariableNames', Tvalid.Properties.VariableNames);
end

writetable(Tselected, fullfile(outDir, 'STEP03T_TPhases_SelectedMap.csv'));

if isempty(dupRows)
    Tdup = cell2table(cell(0,5), 'VariableNames', {'Subject','Run','NCandidateTphases','SelectedFile','AllCandidateFiles'});
else
    Tdup = cell2table(dupRows, 'VariableNames', {'Subject','Run','NCandidateTphases','SelectedFile','AllCandidateFiles'});
end
writetable(Tdup, fullfile(outDir, 'STEP03T_TPhases_Duplicates_BySubjectRun.csv'));

%% Coverage by subject
subjects = unique(Tall.Subject, 'stable');
covRows = {};

for s = 1:numel(subjects)
    subj = subjects{s};
    Tv = Tselected(strcmp(Tselected.Subject, subj), :);

    runs = Tv.Run;
    runs = runs(isfinite(runs));

    covRows(end+1,:) = {subj, height(Tv), joinNumberPreview(runs, 10), sum(Tv.NRows, 'omitnan')}; %#ok<SAGROW>
end

Tcov = cell2table(covRows, 'VariableNames', {'Subject','NSelectedRunsWithTphases','Runs','TotalTphaseRows'});
writetable(Tcov, fullfile(outDir, 'STEP03T_TPhases_Coverage_BySubject.csv'));

%% Summary
summaryRows = {};
summaryRows(end+1,:) = {'MAT files scanned', height(Tall)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Files containing T_phases', sum(Tall.Has_T_phases)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Valid T_phases files', height(Tvalid)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Selected subject-run T_phases files', height(Tselected)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Subjects with selected T_phases', numel(unique(Tselected.Subject))}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Subject-run duplicate T_phases groups', height(Tdup)}; %#ok<SAGROW>
summaryRows(end+1,:) = {'Total selected T_phases rows', sum(Tselected.NRows, 'omitnan')}; %#ok<SAGROW>

Tsummary = cell2table(summaryRows, 'VariableNames', {'Metric','Value'});
writetable(Tsummary, fullfile(outDir, 'STEP03T_TPhases_Summary.csv'));

save(fullfile(outDir, 'STEP03T_TPhasesOnly_Workspace.mat'), 'Tall','Tvalid','Tselected','Tdup','Tcov','Tsummary');

fprintf('\n================ STEP03T SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);

if height(Tdup) > 0
    fprintf('\nDuplicate T_phases candidates by subject/run:\n');
    disp(Tdup);
end

%% ===================== FUNCTIONS =====================
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
    subj = '';
    if numel(parts) > 1
        subj = parts{1};
    end
    if isempty(subj)
        [~, base, ~] = fileparts(filePath);
        toks = regexp(base, '[_\-\s]+', 'split');
        subj = toks{1};
    end
end

function runID = inferRunID(fname)
    runID = NaN;
    [~, base, ~] = fileparts(fname);
    low = lower(base);

    tok = regexp(low, 'run[\s_\-]*(\d+)', 'tokens', 'once');
    if isempty(tok)
        tok = regexp(low, 'workspace.*?(\d+)', 'tokens', 'once');
    end
    if isempty(tok)
        toks = regexp(low, '(\d+)', 'tokens');
        if ~isempty(toks)
            tok = toks{end};
        end
    end

    if ~isempty(tok)
        runID = str2double(tok{1});
    end
end

function tf = hasColumn(colsLow, candidates)
    tf = ~isempty(findColumn(colsLow, candidates));
end

function idx = findColumn(colsLow, candidates)
    idx = [];
    for c = 1:numel(candidates)
        hit = find(strcmp(colsLow, lower(candidates{c})), 1);
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
    for c = 1:numel(candidates)
        hit = find(contains(colsLow, lower(candidates{c})), 1);
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end

function x = toNumericVector(x)
    if iscell(x)
        try
            x = cellfun(@str2double, x);
        catch
            x = cellfun(@double, x);
        end
    elseif isstring(x) || ischar(x)
        x = str2double(x);
    elseif iscategorical(x)
        x = double(x);
    end
    x = double(x(:));
end

function txt = joinNumberPreview(x, maxN)
    if isempty(x)
        txt = '';
        return;
    end
    x = x(:);
    x = x(isfinite(x));
    if isempty(x)
        txt = '';
        return;
    end
    x = sort(unique(x));
    x = x(1:min(maxN,numel(x)));
    parts = arrayfun(@(z) sprintf('%g', z), x, 'UniformOutput', false);
    txt = strjoin(parts, ' | ');
end

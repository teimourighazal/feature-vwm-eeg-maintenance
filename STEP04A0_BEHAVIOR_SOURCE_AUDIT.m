%% STEP04A0_BEHAVIOR_SOURCE_AUDIT.m
% Audit all possible behavioral sources from the task workspace files.
%
% Purpose:
%   Use this BEFORE behavioral statistics if the behavioral sample count looks
%   wrong. This script does NOT trust previous Behavior_TrialLevel_FINAL files.
%   It goes back to the workspace MAT files and inventories all possible
%   behavioral variables/tables/vectors.
%
% Recommended input:
%   STEP03T T_phases selected map:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP03T_TPhasesOnly/STEP03T_TPhases_SelectedMap.csv
%
% Output:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP04A0_Behavior_SourceAudit
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP04A0_Behavior_SourceAudit
%
% Main outputs:
%   BehaviorSourceAudit_FileLevel.csv
%   BehaviorSourceAudit_TableCandidates.csv
%   BehaviorSourceAudit_VectorCandidates.csv
%   BehaviorSourceAudit_BySubject.csv
%   BehaviorSourceAudit_Summary.csv
%
% This script only audits sources. It does not compute final stats yet.

clear; clc; close all;

%% Paths
rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
tphaseMapDefault = fullfile(rootDir, 'STEP03T_TPhasesOnly', 'STEP03T_TPhases_SelectedMap.csv');

outDir = fullfile(rootDir, 'STEP04A0_Behavior_SourceAudit');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP04A0_Behavior_SourceAudit');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP04A0 BEHAVIOR SOURCE AUDIT ===\n');
fprintf('Stage output:\n%s\n', outDir);
fprintf('Result output:\n%s\n', resultOutDir);

%% Get workspace list
if exist(tphaseMapDefault, 'file')
    Tmap = readtable(tphaseMapDefault);
    workspaceFiles = Tmap.FilePath;
    if ~ismember('Subject', Tmap.Properties.VariableNames)
        error('T_phases map missing Subject column.');
    end
    subjects = Tmap.Subject;
    runs = Tmap.Run;
    fprintf('Using T_phases selected map:\n%s\n', tphaseMapDefault);
else
    fprintf('T_phases selected map not found. Select folder containing workspace MAT files.\n');
    selectedRoot = uigetdir(pwd, 'Select folder containing workspace MAT files');
    if isequal(selectedRoot, 0)
        error('No folder selected.');
    end

    files = dir(fullfile(selectedRoot, '**', '*.mat'));
    if isempty(files)
        files = recursiveDir(selectedRoot, '*.mat');
    end

    workspaceFiles = cell(numel(files),1);
    subjects = cell(numel(files),1);
    runs = nan(numel(files),1);

    for i = 1:numel(files)
        workspaceFiles{i} = fullfile(files(i).folder, files(i).name);
        subjects{i} = inferSubject(workspaceFiles{i}, selectedRoot);
        runs(i) = inferRunID(files(i).name);
    end
end

% Clean
validFile = false(numel(workspaceFiles),1);
for i = 1:numel(workspaceFiles)
    validFile(i) = ischar(workspaceFiles{i}) || isstring(workspaceFiles{i});
    if validFile(i)
        validFile(i) = exist(workspaceFiles{i}, 'file') == 2;
    end
end

workspaceFiles = workspaceFiles(validFile);
subjects = subjects(validFile);
runs = runs(validFile);

fprintf('Workspace MAT files to audit: %d\n', numel(workspaceFiles));

%% Audit
fileRows = {};
tableRows = {};
vectorRows = {};

behaviorTableNameHints = {'trial','trials','allcond','behav','behavior','response','resp','rt','acc','correct','result'};
conditionHints = {'condition','cond','taskcondition','pattern','patternid','type'};
correctHints = {'correct','iscorrect','accuracy','acc','hit','success'};
rtHints = {'rt','reaction','reactiontime','responsetime','response_time','clicktime','latency'};
responseHints = {'response','resp','answer','key','button','choice'};
trialHints = {'trial','trialnum','trialnumber'};

for i = 1:numel(workspaceFiles)
    fpath = char(workspaceFiles{i});
    subj = char(string(subjects{i}));
    runID = runs(i);
    [~, fname, ext] = fileparts(fpath);
    fnameExt = [fname ext];

    status = 'ok';
    note = '';
    nVars = NaN;
    nTableCandidates = 0;
    nVectorCandidates = 0;
    bestTable = '';
    bestTableScore = -Inf;
    bestTableRows = NaN;
    bestTableCols = NaN;

    try
        W = whos('-file', fpath);
        nVars = numel(W);

        % Candidate variables to load:
        % Load all tables/timetables and small/medium structs.
        loadVars = {};
        for v = 1:numel(W)
            vname = W(v).name;
            vclass = W(v).class;
            elems = prod(double(W(v).size));
            lowName = lower(vname);

            if strcmpi(vclass, 'table') || strcmpi(vclass, 'timetable')
                loadVars{end+1} = vname; %#ok<AGROW>
            elseif containsAny(lowName, behaviorTableNameHints) && elems <= 5e6
                loadVars{end+1} = vname; %#ok<AGROW>
            elseif any(strcmpi(vclass, {'double','single','logical','cell','string','categorical'})) && elems >= 10 && elems <= 2e5
                if containsAny(lowName, [conditionHints correctHints rtHints responseHints trialHints])
                    loadVars{end+1} = vname; %#ok<AGROW>
                end
            elseif strcmpi(vclass, 'struct') && elems <= 100
                if containsAny(lowName, behaviorTableNameHints)
                    loadVars{end+1} = vname; %#ok<AGROW>
                end
            end
        end

        loadVars = unique(loadVars, 'stable');
        S = struct();
        if ~isempty(loadVars)
            try
                S = load(fpath, loadVars{:});
            catch ME
                note = appendNote(note, ['Load warning: ' ME.message]);
                S = struct();
            end
        end

        names = fieldnames(S);

        for n = 1:numel(names)
            vname = names{n};
            x = S.(vname);

            % Direct table
            if istable(x) || istimetable(x)
                if istimetable(x); x = timetable2table(x); end
                [score, info] = scoreBehaviorTable(x, vname);
                if score > 0
                    nTableCandidates = nTableCandidates + 1;
                    tableRows(end+1,:) = makeTableRow(subj, runID, fnameExt, fpath, vname, x, score, info); %#ok<SAGROW>
                    if score > bestTableScore
                        bestTableScore = score;
                        bestTable = vname;
                        bestTableRows = height(x);
                        bestTableCols = width(x);
                    end
                end

            % Struct: inspect fields for tables or aligned vectors
            elseif isstruct(x)
                try
                    if numel(x) > 1
                        xx = x(1);
                    else
                        xx = x;
                    end
                    fns = fieldnames(xx);

                    for ff = 1:numel(fns)
                        fv = xx.(fns{ff});
                        fullName = [vname '.' fns{ff}];

                        if istable(fv) || istimetable(fv)
                            if istimetable(fv); fv = timetable2table(fv); end
                            [score, info] = scoreBehaviorTable(fv, fullName);
                            if score > 0
                                nTableCandidates = nTableCandidates + 1;
                                tableRows(end+1,:) = makeTableRow(subj, runID, fnameExt, fpath, fullName, fv, score, info); %#ok<SAGROW>
                                if score > bestTableScore
                                    bestTableScore = score;
                                    bestTable = fullName;
                                    bestTableRows = height(fv);
                                    bestTableCols = width(fv);
                                end
                            end
                        end
                    end
                catch ME
                    note = appendNote(note, ['Struct inspection warning: ' ME.message]);
                end
            end

            % Vector candidate inventory
            if isBehaviorVectorCandidate(vname, x)
                nVectorCandidates = nVectorCandidates + 1;
                vectorRows(end+1,:) = {subj, runID, fnameExt, fpath, vname, class(x), mat2str(size(x)), numel(x), ...
                    vectorType(vname), previewValues(x)}; %#ok<SAGROW>
            end
        end

    catch ME
        status = 'error';
        note = appendNote(note, ME.message);
    end

    fileRows(end+1,:) = {subj, runID, fnameExt, fpath, status, nVars, nTableCandidates, nVectorCandidates, ...
        bestTable, bestTableScore, bestTableRows, bestTableCols, note}; %#ok<SAGROW>
end

Tfile = cell2table(fileRows, 'VariableNames', ...
    {'Subject','Run','FileName','FilePath','Status','NVariables','NTableCandidates','NVectorCandidates', ...
     'BestTableCandidate','BestTableScore','BestTableRows','BestTableColumns','Note'});

if isempty(tableRows)
    Ttables = cell2table(cell(0,25), 'VariableNames', tableVarNames());
else
    Ttables = cell2table(tableRows, 'VariableNames', tableVarNames());
end

if isempty(vectorRows)
    Tvectors = cell2table(cell(0,10), 'VariableNames', ...
        {'Subject','Run','FileName','FilePath','VariableName','Class','Size','Numel','CandidateType','Preview'});
else
    Tvectors = cell2table(vectorRows, 'VariableNames', ...
        {'Subject','Run','FileName','FilePath','VariableName','Class','Size','Numel','CandidateType','Preview'});
end

writetable(Tfile, fullfile(outDir, 'BehaviorSourceAudit_FileLevel.csv'));
writetable(Ttables, fullfile(outDir, 'BehaviorSourceAudit_TableCandidates.csv'));
writetable(Tvectors, fullfile(outDir, 'BehaviorSourceAudit_VectorCandidates.csv'));

%% By-subject summary
subjectsUnique = unique(Tfile.Subject, 'stable');
subjRows = {};
for s = 1:numel(subjectsUnique)
    subj = subjectsUnique{s};
    F = Tfile(strcmp(Tfile.Subject, subj), :);
    C = Ttables(strcmp(Ttables.Subject, subj), :);

    runsAny = unique(F.Run(isfinite(F.Run)));
    runsWithTables = unique(C.Run(isfinite(C.Run)));

    subjRows(end+1,:) = {subj, height(F), joinNums(runsAny), height(C), joinNums(runsWithTables), ...
        sum(F.NTableCandidates > 0), sum(F.NVectorCandidates > 0), sum(C.NRows, 'omitnan')}; %#ok<SAGROW>
end

Tsubj = cell2table(subjRows, 'VariableNames', ...
    {'Subject','NWorkspaceFiles','RunsInWorkspace','NTableCandidates','RunsWithTableCandidates', ...
     'NFilesWithTableCandidates','NFilesWithVectorCandidates','TotalCandidateTableRows'});
writetable(Tsubj, fullfile(outDir, 'BehaviorSourceAudit_BySubject.csv'));

%% Summary
summaryRows = {};
summaryRows(end+1,:) = {'Workspace files audited', height(Tfile)}; %#ok<AGROW>
summaryRows(end+1,:) = {'Files with any table candidate', sum(Tfile.NTableCandidates > 0)}; %#ok<AGROW>
summaryRows(end+1,:) = {'Files with any vector candidate', sum(Tfile.NVectorCandidates > 0)}; %#ok<AGROW>
summaryRows(end+1,:) = {'Total table candidates', height(Ttables)}; %#ok<AGROW>
summaryRows(end+1,:) = {'Total vector candidates', height(Tvectors)}; %#ok<AGROW>
summaryRows(end+1,:) = {'Subjects with table candidates', numel(unique(Ttables.Subject))}; %#ok<AGROW>
summaryRows(end+1,:) = {'Total candidate table rows', sum(Ttables.NRows, 'omitnan')}; %#ok<AGROW>

Tsummary = cell2table(summaryRows, 'VariableNames', {'Metric','Value'});
writetable(Tsummary, fullfile(outDir, 'BehaviorSourceAudit_Summary.csv'));

save(fullfile(outDir, 'STEP04A0_Behavior_SourceAudit_Workspace.mat'), ...
    'Tfile','Ttables','Tvectors','Tsubj','Tsummary');

copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\n================ STEP04A0 SUMMARY ================\n');
disp(Tsummary);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

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

function tf = containsAny(text, hints)
    tf = false;
    text = lower(char(string(text)));
    for i = 1:numel(hints)
        if contains(text, lower(hints{i}))
            tf = true;
            return;
        end
    end
end

function [score, info] = scoreBehaviorTable(T, vname)
    cols = T.Properties.VariableNames;
    colsLow = lower(cols);
    nameLow = lower(vname);

    conditionHints = {'condition','cond','taskcondition','pattern','patternid','type'};
    correctHints = {'correct','iscorrect','accuracy','acc','hit','success'};
    rtHints = {'rt','reaction','reactiontime','responsetime','response_time','clicktime','latency'};
    responseHints = {'response','resp','answer','key','button','choice'};
    trialHints = {'trial','trialnum','trialnumber'};
    sampleHints = {'sample','stim','maint','retr','row','start','end'};

    hasTrial = hasAnyCol(colsLow, trialHints);
    hasCondition = hasAnyCol(colsLow, conditionHints);
    hasCorrect = hasAnyCol(colsLow, correctHints);
    hasRT = hasAnyCol(colsLow, rtHints);
    hasResponse = hasAnyCol(colsLow, responseHints);
    hasSample = hasAnyCol(colsLow, sampleHints);

    score = 0;
    score = score + 4 * hasCondition;
    score = score + 4 * hasCorrect;
    score = score + 4 * hasRT;
    score = score + 2 * hasResponse;
    score = score + 2 * hasTrial;
    score = score + 1 * hasSample;
    score = score + min(height(T), 200) / 50;

    if contains(nameLow, 'trial'); score = score + 2; end
    if contains(nameLow, 'allcond'); score = score + 2; end
    if contains(nameLow, 'behav') || contains(nameLow, 'behavior'); score = score + 2; end
    if contains(nameLow, 'phase'); score = score - 3; end

    % Keep weak candidates too, because some behavior tables have only condition + response.
    if ~(hasCondition || hasCorrect || hasRT || hasResponse)
        score = 0;
    end

    info = struct();
    info.HasTrial = hasTrial;
    info.HasCondition = hasCondition;
    info.HasCorrect = hasCorrect;
    info.HasRT = hasRT;
    info.HasResponse = hasResponse;
    info.HasSample = hasSample;
    info.ConditionColumn = findFirstCol(cols, colsLow, conditionHints);
    info.CorrectColumn = findFirstCol(cols, colsLow, correctHints);
    info.RTColumn = findFirstCol(cols, colsLow, rtHints);
    info.ResponseColumn = findFirstCol(cols, colsLow, responseHints);
    info.TrialColumn = findFirstCol(cols, colsLow, trialHints);
    info.ColumnPreview = strjoin(cols(1:min(numel(cols),40)), ' | ');
    info.ConditionPreview = conditionPreview(T, info.ConditionColumn);
end

function names = tableVarNames()
    names = {'Subject','Run','FileName','FilePath','TableName','NRows','NColumns','BehaviorScore', ...
        'HasTrial','HasCondition','HasCorrect','HasRT','HasResponse','HasSample', ...
        'TrialColumn','ConditionColumn','CorrectColumn','RTColumn','ResponseColumn', ...
        'ConditionPreview','NUniqueConditions','ColumnPreview','LikelyAccuracyOnly','LikelyRTAvailable','Note'};
end

function row = makeTableRow(subj, runID, fnameExt, fpath, vname, T, score, info)
    nUniqueConditions = NaN;
    if ~isempty(info.ConditionColumn) && ismember(info.ConditionColumn, T.Properties.VariableNames)
        try
            c = toNumeric(T.(info.ConditionColumn));
            nUniqueConditions = numel(unique(c(isfinite(c))));
        catch
            nUniqueConditions = NaN;
        end
    end

    likelyAccuracyOnly = info.HasCondition && info.HasCorrect && ~info.HasRT;
    likelyRTAvailable = info.HasRT;

    row = {subj, runID, fnameExt, fpath, vname, height(T), width(T), score, ...
        info.HasTrial, info.HasCondition, info.HasCorrect, info.HasRT, info.HasResponse, info.HasSample, ...
        info.TrialColumn, info.ConditionColumn, info.CorrectColumn, info.RTColumn, info.ResponseColumn, ...
        info.ConditionPreview, nUniqueConditions, info.ColumnPreview, likelyAccuracyOnly, likelyRTAvailable, ''};
end

function tf = hasAnyCol(colsLow, hints)
    tf = false;
    for i = 1:numel(hints)
        if any(strcmp(colsLow, lower(hints{i}))) || any(contains(colsLow, lower(hints{i})))
            tf = true;
            return;
        end
    end
end

function col = findFirstCol(cols, colsLow, hints)
    col = '';
    for i = 1:numel(hints)
        idx = find(strcmp(colsLow, lower(hints{i})), 1);
        if ~isempty(idx); col = cols{idx}; return; end
    end
    for i = 1:numel(hints)
        idx = find(contains(colsLow, lower(hints{i})), 1);
        if ~isempty(idx); col = cols{idx}; return; end
    end
end

function prev = conditionPreview(T, condCol)
    prev = '';
    if isempty(condCol) || ~ismember(condCol, T.Properties.VariableNames)
        return;
    end
    try
        c = toNumeric(T.(condCol));
        uc = unique(c(isfinite(c)));
        if isempty(uc)
            prev = '';
        else
            prev = joinNums(uc(1:min(numel(uc),10)));
        end
    catch
        prev = '<unreadable>';
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

function tf = isBehaviorVectorCandidate(vname, x)
    low = lower(vname);
    hints = {'condition','cond','correct','accuracy','rt','reaction','response','resp','trial','pattern'};
    tf = containsAny(low, hints);

    if ~tf
        return;
    end

    try
        n = numel(x);
        tf = n >= 10 && n <= 2e5;
    catch
        tf = false;
    end
end

function t = vectorType(vname)
    low = lower(vname);
    if contains(low, 'rt') || contains(low, 'reaction')
        t = 'RT';
    elseif contains(low, 'correct') || contains(low, 'acc')
        t = 'CorrectAccuracy';
    elseif contains(low, 'condition') || contains(low, 'cond') || contains(low, 'pattern')
        t = 'Condition';
    elseif contains(low, 'response') || contains(low, 'resp')
        t = 'Response';
    elseif contains(low, 'trial')
        t = 'Trial';
    else
        t = 'BehaviorLike';
    end
end

function txt = previewValues(x)
    txt = '';
    try
        if istable(x) || isstruct(x)
            txt = '<table_or_struct>';
            return;
        end

        if iscell(x)
            vals = x(:);
            vals = vals(1:min(numel(vals),10));
            parts = cellfun(@(z) char(string(z)), vals, 'UniformOutput', false);
        else
            vals = x(:);
            vals = vals(1:min(numel(vals),10));
            parts = cellstr(string(vals));
        end
        txt = strjoin(parts, ' | ');
    catch
        txt = '<unreadable>';
    end
end

function out = appendNote(note, extra)
    if isempty(note)
        out = extra;
    else
        out = [note ' ' extra];
    end
end

function txt = joinNums(x)
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

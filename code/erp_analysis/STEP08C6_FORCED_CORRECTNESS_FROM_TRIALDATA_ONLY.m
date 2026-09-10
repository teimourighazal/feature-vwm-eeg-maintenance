%% STEP08C6_FORCED_CORRECTNESS_FROM_TRIALDATA_ONLY.m
% STEP08C6: Forced correctness recovery from subject workspace trialData
% variables WITHOUT requiring T_trials.
%
% Why this version:
%   STEP08C5 recovered only 6 final-EEG subjects because it required T_trials
%   inside each workspace file. However, most workspace files contain the
%   trialData variables but not T_trials. This version uses:
%
%       workspace_*<number>.mat  -> Run
%       trialData1               -> color condition
%       trialData2               -> orientation condition
%       trialData3               -> conjunction condition
%
% Correctness columns:
%       trialData1: X5 when available; otherwise X1 fallback if it is binary.
%       trialData2: X5 when available.
%       trialData3: X12 as overall conjunction correctness; if unavailable,
%                   fallback X9 then X5.
%
% Output:
%   Result/STEP08C6_ForcedCorrectness_TrialDataOnly under the selected Article2 Analysis folder.
%
% Main outputs:
%   STEP08C6_ForcedCorrectnessTable.csv
%   STEP08C6_SubjectCoverage.csv
%   STEP08C6_WorkspaceTrialDataInventory.csv
%   STEP08C6_RejectedTrialDataVariables.csv
%   STEP08C6_RecommendedNextStep.txt
%
% Next:
%   Use STEP08C6_ForcedCorrectnessTable.csv as forced correctness input for
%   STEP08D ERP rerun if coverage and label mapping are acceptable.

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

articleRoot = fileparts(rootDir);
resultRoot = fullfile(rootDir, 'Result');
outDir = fullfile(resultRoot, 'STEP08C6_ForcedCorrectness_TrialDataOnly');

if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP08C6 FORCED CORRECTNESS FROM TRIALDATA ONLY ===\n');
fprintf('Output folder:\n%s\n', outDir);

%% Parameters
P = struct();

% Mapping assumed from task design.
P.conditionMap = struct();
P.conditionMap.trialData1 = 'color';
P.conditionMap.trialData2 = 'orientation';
P.conditionMap.trialData3 = 'conjunction';

% Correctness and RT mapping inferred from STEP08C4 ColumnPreview.
P.correctCols.trialData1 = {'X5','X1'};      % X5 preferred, X1 fallback
P.correctCols.trialData2 = {'X5'};
P.correctCols.trialData3 = {'X12','X9','X5'}; % X12 overall preferred

P.rtCols.trialData1 = {'X7'};
P.rtCols.trialData2 = {'X7'};
P.rtCols.trialData3 = {'X11'};

% Only these variables are used. trial_Data1 is intentionally ignored to
% avoid double-counting/alternate duplicate variables.
P.trialDataVars = {'trialData1','trialData2','trialData3'};

% Choose one file per subject-run-condition if duplicates exist.
P.chooseBestFilePerSubjectRunCondition = true;

%% Search roots
searchRoots = {
    fullfile(rootDir, 'Subjects');
    fullfile(articleRoot, 'Subjects')
    };

finalEEGSubjects = {'s1','s2','s3','s4','s5','s6','s7','s8','s9','s11','s12','s13','s14','s15','s16','s17','s18','s19','s20','s21','s22','s23'}';

%% Find workspace files
workspaceFiles = {};
for r = 1:numel(searchRoots)
    root = searchRoots{r};
    if exist(root, 'dir')
        workspaceFiles = [workspaceFiles; recursiveFiles(root, 'workspace*.mat')]; %#ok<AGROW>
        workspaceFiles = [workspaceFiles; recursiveFiles(root, 'workspace_*.mat')]; %#ok<AGROW>
        workspaceFiles = [workspaceFiles; recursiveFiles(root, '*workspace*.mat')]; %#ok<AGROW>
    end
end
workspaceFiles = unique(workspaceFiles, 'stable');

if isempty(workspaceFiles)
    extraRoot = uigetdir(pwd, 'Select folder containing subject workspace MAT files');
    if ~isequal(extraRoot, 0)
        workspaceFiles = [recursiveFiles(extraRoot, 'workspace*.mat'); ...
                          recursiveFiles(extraRoot, 'workspace_*.mat'); ...
                          recursiveFiles(extraRoot, '*workspace*.mat')];
        workspaceFiles = unique(workspaceFiles, 'stable');
    end
end

fprintf('Workspace files found: %d\n', numel(workspaceFiles));

AllTables = {};
InvRows = {};
RejectRows = {};

for f = 1:numel(workspaceFiles)
    fpath = workspaceFiles{f};

    subjectID = inferSubjectFromPath(fpath);
    runID = inferRunFromFileName(fpath);

    if strcmp(runID,'')
        RejectRows(end+1,:) = {fpath, '', subjectID, runID, 0, 0, 'no_run_number_in_workspace_filename'}; %#ok<AGROW>
        continue;
    end

    for v = 1:numel(P.trialDataVars)
        varName = P.trialDataVars{v};
        conditionLabel = P.conditionMap.(varName);

        try
            S = load(fpath, varName);
            if ~isfield(S, varName)
                RejectRows(end+1,:) = {fpath, varName, subjectID, runID, 0, 0, 'variable_not_in_file'}; %#ok<AGROW>
                continue;
            end
        catch ME
            RejectRows(end+1,:) = {fpath, varName, subjectID, runID, 0, 0, ['cannot_load_variable: ' ME.message]}; %#ok<AGROW>
            continue;
        end

        [TD, status] = toTable(S.(varName));
        if isempty(TD) || height(TD)==0
            RejectRows(end+1,:) = {fpath, varName, subjectID, runID, 0, 0, ['cannot_convert_variable: ' status]}; %#ok<AGROW>
            continue;
        end

        [Tout, meta] = extractCorrectnessRows(TD, subjectID, runID, conditionLabel, fpath, varName, P.correctCols.(varName), P.rtCols.(varName));

        InvRows(end+1,:) = {fpath, varName, subjectID, runID, conditionLabel, status, ...
            height(TD), width(TD), height(Tout), ...
            meta.CorrectnessColumnUsed, meta.RTColumnUsed, meta.NCorrect, meta.NIncorrect, meta.NUsable, ...
            meta.ColumnList, meta.Note}; %#ok<AGROW>

        if meta.NUsable > 0
            AllTables{end+1} = Tout; %#ok<AGROW>
        else
            RejectRows(end+1,:) = {fpath, varName, subjectID, runID, height(TD), 0, ['no_usable_correctness: ' meta.Note]}; %#ok<AGROW>
        end
    end
end

%% Inventory
if isempty(InvRows)
    Inventory = table();
else
    Inventory = cell2table(InvRows, 'VariableNames', ...
        {'WorkspaceFile','TrialDataVariable','Subject','Run','ConditionLabel','ConvertStatus', ...
        'OriginalRows','OriginalColumns','RecoveredRows', ...
        'CorrectnessColumnUsed','RTColumnUsed','NCorrect','NIncorrect','NUsable', ...
        'ColumnList','Note'});
    try
        Inventory = sortrows(Inventory, {'Subject','Run','ConditionLabel','NUsable'}, {'ascend','ascend','ascend','descend'});
    catch
    end
end

if isempty(RejectRows)
    Rejected = table();
else
    Rejected = cell2table(RejectRows, 'VariableNames', ...
        {'WorkspaceFile','TrialDataVariable','Subject','Run','OriginalRows','NRecoveredRows','Reason'});
end

writetable(Inventory, fullfile(outDir, 'STEP08C6_WorkspaceTrialDataInventory.csv'));
writetable(Rejected, fullfile(outDir, 'STEP08C6_RejectedTrialDataVariables.csv'));

if isempty(AllTables)
    txt = 'No usable trialData correctness rows were recovered.';
    writeText(fullfile(outDir, 'STEP08C6_RecommendedNextStep.txt'), txt);
    error(txt);
end

Tall = vertcat(AllTables{:});

%% Keep best file per subject-run-condition
if P.chooseBestFilePerSubjectRunCondition
    Tall = keepBestFilePerSubjectRunCondition(Tall);
end

%% Deduplicate Subject-Run-Condition-Trial
try
    Tall = sortrows(Tall, {'Subject','Run','ConditionLabel','Trial'}, {'ascend','ascend','ascend','ascend'});
    key = strcat(string(Tall.Subject), "|", string(Tall.Run), "|", string(Tall.ConditionLabel), "|", string(Tall.Trial));
    [~, ia] = unique(key, 'stable');
    Tall = Tall(ia,:);
catch
end

writetable(Tall, fullfile(outDir, 'STEP08C6_ForcedCorrectnessTable.csv'));

Coverage = makeCoverageTable(Tall, finalEEGSubjects);
writetable(Coverage, fullfile(outDir, 'STEP08C6_SubjectCoverage.csv'));

decisionText = makeDecisionText(Tall, Coverage, Inventory, P);
writeText(fullfile(outDir, 'STEP08C6_RecommendedNextStep.txt'), decisionText);

save(fullfile(outDir, 'STEP08C6_ForcedCorrectness_TrialDataOnly_Workspace.mat'), ...
    'Tall','Coverage','Inventory','Rejected','decisionText','workspaceFiles','P');

fprintf('\n================ STEP08C6 SUMMARY ================\n');
fprintf('Recovered final rows: %d\n', height(Tall));
fprintf('Recovered subjects: %d\n', numel(unique(Tall.Subject)));
fprintf('Final EEG overlap: %d\n', sum(Coverage.HasCorrectnessLabels));
fprintf('Subjects:\n%s\n', strjoin(unique(Tall.Subject,'stable')',' | '));
fprintf('\n%s\n', decisionText);

%% ===================== FUNCTIONS =====================

function files = recursiveFiles(rootDir, pattern)
    files = {};
    if ~exist(rootDir, 'dir'); return; end
    d = dir(rootDir);
    for i = 1:numel(d)
        if d(i).isdir
            name = d(i).name;
            if strcmp(name,'.') || strcmp(name,'..'); continue; end
            files = [files; recursiveFiles(fullfile(rootDir, name), pattern)]; %#ok<AGROW>
        end
    end
    dd = dir(fullfile(rootDir, pattern));
    for i = 1:numel(dd)
        files{end+1,1} = fullfile(dd(i).folder, dd(i).name); %#ok<AGROW>
    end
end

function subjectID = inferSubjectFromPath(fpath)
    subjectID = '';
    parts = split(string(fpath), filesep);
    for i = numel(parts):-1:1
        p = lower(strtrim(parts(i)));
        tok = regexp(p, '^s[_\-\s]*0*([0-9]{1,3})$', 'tokens', 'once');
        if isempty(tok); tok = regexp(p, '^subject[_\-\s]*0*([0-9]{1,3})$', 'tokens', 'once'); end
        if isempty(tok); tok = regexp(p, '^sub[_\-\s]*0*([0-9]{1,3})$', 'tokens', 'once'); end
        if isempty(tok); tok = regexp(p, '^0*([0-9]{1,3})$', 'tokens', 'once'); end
        if ~isempty(tok)
            subjectID = ['s' num2str(str2double(tok{1}))];
            return;
        end
    end
    if numel(parts) >= 2
        subjectID = char(lower(strtrim(parts(end-1))));
    else
        subjectID = 'unknown';
    end
end

function runID = inferRunFromFileName(fpath)
    [~, name, ~] = fileparts(fpath);
    runID = '';
    tok = regexp(lower(name), '(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        runID = ['run' num2str(str2double(tok{1}))];
    end
end

function [T, status] = toTable(X)
    T = table();
    status = '';

    unwrapCount = 0;
    while iscell(X) && numel(X)==1 && unwrapCount < 5
        X = X{1};
        unwrapCount = unwrapCount + 1;
    end

    if istable(X)
        T = X;
        status = 'table';
        return;
    end

    if isstruct(X)
        try
            if numel(X) == 1
                T = struct2table(X);
                T2 = scalarStructFieldsToTable(X);
                if ~isempty(T2) && height(T2) > height(T)
                    T = T2;
                    status = 'scalar_struct_fields_expanded';
                else
                    status = 'scalar_struct2table';
                end
            else
                T = struct2table(X(:));
                status = 'struct_array2table';
            end
            return;
        catch ME
            status = ['struct_conversion_failed: ' ME.message];
            return;
        end
    end

    if iscell(X)
        try
            T = cellTrialDataToTable(X);
            status = 'cell_to_table';
            return;
        catch ME
            status = ['cell_conversion_failed: ' ME.message];
            return;
        end
    end

    if isnumeric(X) || islogical(X)
        if ismatrix(X)
            T = array2table(X);
            status = 'numeric_array2table';
            return;
        else
            status = 'numeric_not_matrix';
            return;
        end
    end

    status = ['unsupported_class_' class(X)];
end

function T = scalarStructFieldsToTable(S)
    T = table();
    fields = fieldnames(S);
    data = struct();
    n = NaN;
    for i = 1:numel(fields)
        f = fields{i};
        v = S.(f);
        if isvector(v) && ~ischar(v)
            len = numel(v);
            if isnan(n)
                n = len;
            elseif len ~= n
                continue;
            end
            data.(f) = v(:);
        end
    end
    if ~isnan(n) && n > 1 && ~isempty(fieldnames(data))
        T = struct2table(data);
    end
end

function T = cellTrialDataToTable(C)
    C = squeeze(C);
    if size(C,1) >= 2
        firstRow = C(1,:);
        nText = 0;
        for j = 1:numel(firstRow)
            try
                sj = strtrim(string(firstRow{j}));
                if strlength(sj) > 0 && ~isfinite(str2double(sj))
                    nText = nText + 1;
                end
            catch
            end
        end
        if nText >= max(2, ceil(0.5*numel(firstRow)))
            names = makeValidUniqueNames(firstRow);
            T = cell2table(C(2:end,:), 'VariableNames', names);
            return;
        end
    end
    T = cell2table(C);
end

function names = makeValidUniqueNames(row)
    names = cell(1,numel(row));
    for j = 1:numel(row)
        try
            s = char(strtrim(string(row{j})));
        catch
            s = ['Var' num2str(j)];
        end
        if isempty(s) || strcmpi(s,'missing')
            s = ['Var' num2str(j)];
        end
        s = matlab.lang.makeValidName(s);
        names{j} = s;
    end
    names = matlab.lang.makeUniqueStrings(names);
end

function [Tout, meta] = extractCorrectnessRows(TD, subjectID, runID, conditionLabel, fpath, varName, correctCols, rtCols)
    meta = struct();
    meta.CorrectnessColumnUsed = '';
    meta.RTColumnUsed = '';
    meta.NCorrect = 0;
    meta.NIncorrect = 0;
    meta.NUsable = 0;
    meta.ColumnList = strjoin(TD.Properties.VariableNames, '|');
    meta.Note = '';

    corrCol = chooseFirstUsableCorrectnessColumn(TD, correctCols);
    if strcmp(corrCol,'')
        meta.Note = 'no_preferred_correctness_column_found_or_not_binary';
        Tout = table();
        return;
    end

    rtCol = chooseFirstExistingColumn(TD, rtCols);

    rows = {};
    n = height(TD);

    for i = 1:n
        val = getTableValue(TD, i, corrCol);
        correctness = normalizeCorrectnessScalar(val);

        if ~(strcmp(correctness,'correct') || strcmp(correctness,'incorrect'))
            continue;
        end

        rt = NaN;
        if ~strcmp(rtCol,'')
            rtVal = getTableValue(TD, i, rtCol);
            rt = str2double(stringScalarSafe(rtVal));
            if isfinite(rt) && rt > 0 && rt < 20
                rt = rt * 1000;
            end
        end

        rows(end+1,:) = {subjectID, runID, num2str(i), conditionLabel, correctness, rt, fpath, varName, corrCol}; %#ok<AGROW>
    end

    if isempty(rows)
        Tout = table();
    else
        Tout = cell2table(rows, 'VariableNames', ...
            {'Subject','Run','Trial','ConditionLabel','Correctness','RT_ms','SourceWorkspace','TrialDataVariable','CorrectnessColumn'});
    end

    meta.CorrectnessColumnUsed = corrCol;
    meta.RTColumnUsed = rtCol;
    meta.NCorrect = sum(strcmp(Tout.Correctness,'correct'));
    meta.NIncorrect = sum(strcmp(Tout.Correctness,'incorrect'));
    meta.NUsable = meta.NCorrect + meta.NIncorrect;
    meta.Note = 'ok';
end

function col = chooseFirstUsableCorrectnessColumn(TD, correctCols)
    col = '';
    for i = 1:numel(correctCols)
        candidate = correctCols{i};
        if ismember(candidate, TD.Properties.VariableNames) && looksLikeCorrectnessValues(TD.(candidate))
            col = candidate;
            return;
        end
    end
end

function col = chooseFirstExistingColumn(TD, cols)
    col = '';
    for i = 1:numel(cols)
        if ismember(cols{i}, TD.Properties.VariableNames)
            col = cols{i};
            return;
        end
    end
end

function tf = looksLikeCorrectnessValues(v)
    vals = safeStringVector(v);
    vals = lower(strtrim(vals(:)));
    vals = vals(~ismissing(vals) & strlength(vals)>0);
    if isempty(vals)
        tf = false;
        return;
    end
    u = unique(vals);
    allowed = ["0","1","true","false","correct","incorrect","wrong","yes","no","hit","miss","success","error","accurate","inaccurate"];
    nums = str2double(u);
    tf = (numel(u) >= 2 && numel(u) <= 2 && all(ismember(u, allowed))) || ...
         (numel(u) >= 2 && numel(u) <= 2 && all(isfinite(nums)) && all(ismember(nums, [0 1])));
end

function val = getTableValue(T, rowIdx, col)
    x = T.(col);
    if iscell(x)
        val = x{rowIdx};
    else
        val = x(rowIdx);
    end
end

function c = normalizeCorrectnessScalar(v)
    s = lower(strtrim(stringScalarSafe(v)));
    val = str2double(s);

    if any(strcmp(s, ["1","true","correct","yes","y","hit","success","accurate"]))
        c = 'correct';
    elseif any(strcmp(s, ["0","false","incorrect","wrong","no","n","miss","error","inaccurate"]))
        c = 'incorrect';
    elseif isfinite(val)
        if val == 1
            c = 'correct';
        elseif val == 0
            c = 'incorrect';
        else
            c = 'other';
        end
    else
        c = 'other';
    end
end

function vals = safeStringVector(x)
    try
        if istable(x)
            x = table2cell(x);
        end
        if iscell(x)
            vals = strings(numel(x),1);
            for k = 1:numel(x)
                vals(k) = stringScalarSafe(x{k});
            end
        elseif ischar(x)
            vals = string(cellstr(x));
        elseif isstring(x) || iscategorical(x)
            vals = string(x(:));
        elseif isnumeric(x) || islogical(x)
            vals = string(double(x(:)));
        else
            vals = string(x(:));
        end
    catch
        vals = strings(0,1);
    end
end

function s = stringScalarSafe(x)
    try
        if isempty(x)
            s = "";
        elseif iscell(x)
            pieces = strings(numel(x),1);
            for i = 1:numel(x)
                pieces(i) = stringScalarSafe(x{i});
            end
            pieces = pieces(strlength(pieces)>0);
            if isempty(pieces)
                s = "";
            else
                s = strjoin(pieces, "|");
            end
        elseif ischar(x)
            s = string(x);
        elseif isstring(x) || iscategorical(x)
            xs = string(x(:));
            xs = xs(~ismissing(xs));
            if isempty(xs)
                s = "";
            else
                s = strjoin(xs, "|");
            end
        elseif isnumeric(x) || islogical(x)
            if numel(x)==1
                s = string(double(x));
            else
                s = strjoin(string(double(x(:)))', "|");
            end
        else
            s = string(x);
        end
    catch
        s = "";
    end
end

function Tall2 = keepBestFilePerSubjectRunCondition(Tall)
    Tall2 = table();
    keys = unique(strcat(string(Tall.Subject), "|", string(Tall.Run), "|", string(Tall.ConditionLabel)), 'stable');

    for k = 1:numel(keys)
        parts = split(keys(k), "|");
        subj = char(parts(1));
        run = char(parts(2));
        cond = char(parts(3));

        S = Tall(strcmp(Tall.Subject, subj) & strcmp(Tall.Run, run) & strcmp(Tall.ConditionLabel, cond), :);
        files = unique(S.SourceWorkspace, 'stable');

        bestFile = '';
        bestN = -Inf;
        for f = 1:numel(files)
            n = sum(strcmp(S.SourceWorkspace, files{f}));
            if n > bestN
                bestN = n;
                bestFile = files{f};
            end
        end

        Tall2 = [Tall2; S(strcmp(S.SourceWorkspace, bestFile), :)]; %#ok<AGROW>
    end
end

function Coverage = makeCoverageTable(T, finalEEGSubjects)
    rows = {};
    for i = 1:numel(finalEEGSubjects)
        s = finalEEGSubjects{i};
        S = T(strcmp(T.Subject, s), :);
        nRows = height(S);
        nCorrect = 0; nIncorrect = 0; nRuns = 0; nTrials = 0; nConditions = 0;
        if nRows > 0
            nCorrect = sum(strcmp(S.Correctness,'correct'));
            nIncorrect = sum(strcmp(S.Correctness,'incorrect'));
            nRuns = numel(unique(S.Run));
            nTrials = numel(unique(strcat(S.Run,'_',S.ConditionLabel,'_',S.Trial)));
            nConditions = numel(unique(S.ConditionLabel));
        end
        rows(end+1,:) = {s, nRows>0, nRows, nCorrect, nIncorrect, nRuns, nTrials, nConditions}; %#ok<AGROW>
    end
    Coverage = cell2table(rows, 'VariableNames', ...
        {'Subject','HasCorrectnessLabels','NRows','NCorrect','NIncorrect','NRuns','NUniqueRunConditionTrials','NUniqueConditions'});
end

function txt = makeDecisionText(T, Coverage, Inventory, P)
    nCovered = sum(Coverage.HasCorrectnessLabels);
    subjCovered = Coverage.Subject(Coverage.HasCorrectnessLabels);
    nRows = height(T);
    nCorrect = sum(strcmp(T.Correctness,'correct'));
    nIncorrect = sum(strcmp(T.Correctness,'incorrect'));

    if nCovered == 14
        status = 'The expected 14 final-EEG subjects were recovered from trialData-only correctness labels.';
    elseif nCovered > 14
        status = sprintf('%d final-EEG subjects were recovered, more than the expected 14. Verify whether all should be included.', nCovered);
    elseif nCovered > 6
        status = sprintf('A larger trialData-only subset was recovered: %d final-EEG subjects.', nCovered);
    else
        status = sprintf('Only %d final-EEG subjects were recovered. Inspect inventory/rejected files.', nCovered);
    end

    txt = sprintf(['%s\n\n', ...
        'Mapping used:\n', ...
        'trialData1 -> color, correctness columns: %s\n', ...
        'trialData2 -> orientation, correctness columns: %s\n', ...
        'trialData3 -> conjunction, correctness columns: %s\n\n', ...
        'Recovered rows: %d\n', ...
        'Correct rows: %d\n', ...
        'Incorrect rows: %d\n\n', ...
        'Covered final-EEG subjects:\n%s\n\n', ...
        'Recommended next step:\n', ...
        'Use STEP08C6_ForcedCorrectnessTable.csv as the forced correctness table for STEP08D ERP rerun if this trialData-to-condition mapping is correct. ', ...
        'If the expected subset is exactly 14 but this output recovers more, decide whether to keep all recovered final-EEG subjects or restrict to the known 14-subject set before ERP statistics.'], ...
        status, strjoin(P.correctCols.trialData1, '|'), strjoin(P.correctCols.trialData2, '|'), strjoin(P.correctCols.trialData3, '|'), ...
        nRows, nCorrect, nIncorrect, strjoin(subjCovered',' | '));
end

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0; error('Could not write file: %s', fpath); end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

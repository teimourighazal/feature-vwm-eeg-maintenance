%% STEP02B_BEHAVIOR_TABLE_INSPECT.m
% Inspect behavioral tables inside candidate workspace MAT files.
%
% Run after:
%   STEP02_BEHAVIOR_SCAN.m
%
% Input:
%   STEP02_Behavior_Scan/STEP02_Behavior_CandidateFiles.csv under the selected Article2 Analysis folder.
%
% Output:
%   STEP02B_Behavior_TableInspect under the selected Article2 Analysis folder.
%
% Purpose:
%   Find the actual behavioral tables and their columns before extracting
%   accuracy, RT, run, and condition. This script does NOT compute final
%   behavioral results yet. It only inspects the internal MAT tables.

clear; clc;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end

scanDir = fullfile(rootDir, 'STEP02_Behavior_Scan');
outDir  = fullfile(rootDir, 'STEP02B_Behavior_TableInspect');

if ~exist(outDir, 'dir'); mkdir(outDir); end

candidateFile = fullfile(scanDir, 'STEP02_Behavior_CandidateFiles.csv');

if ~exist(candidateFile, 'file')
    error('Candidate file not found. Run STEP02_BEHAVIOR_SCAN first.');
end

Tcand = readtable(candidateFile);

fprintf('\n=== STEP02B BEHAVIOR TABLE INSPECT ===\n');
fprintf('Candidate files: %d\n', height(Tcand));
fprintf('Output folder:\n%s\n', outDir);

%% Keywords
tableNameKeywords = {'trial','trials','allcond','accuracy','acc','response','resp','rt','cond','condition','reject','valid'};
columnKeywords = {'trial','index','run','condition','cond','color','orientation','ori','conj','accuracy','acc','correct','response','resp','rt','reaction','time','error','angle','reject','valid','phase','start','end'};

ignoreVarPrefixes = {'EEG_Raw','EEG_Filtered'};
ignoreFileKeywords = {'eye open','eye close','eyes open','eyes close','rest','resting','features'};

%% Inspect
tableRows = {};
columnRows = {};
structRows = {};
fileRows = {};

for i = 1:height(Tcand)
    filePath = Tcand.FilePath{i};
    fileName = Tcand.FileName{i};
    subj = Tcand.Subject{i};

    lowName = lower([fileName ' ' Tcand.RelativePath{i}]);
    ignoreFile = false;
    for k = 1:numel(ignoreFileKeywords)
        if contains(lowName, ignoreFileKeywords{k})
            ignoreFile = true;
        end
    end
    if ignoreFile
        continue;
    end

    if ~exist(filePath, 'file')
        fileRows(end+1,:) = {subj, fileName, filePath, 'missing_file', 0, 0, ''}; %#ok<SAGROW>
        continue;
    end

    fprintf('\n[%d/%d] %s\n', i, height(Tcand), filePath);

    try
        W = whos('-file', filePath);
        varNames = {W.name};
        nTables = 0;
        nCandidateTables = 0;

        S = load(filePath);

        for v = 1:numel(varNames)
            vname = varNames{v};

            skipVar = false;
            for p = 1:numel(ignoreVarPrefixes)
                if startsWith(vname, ignoreVarPrefixes{p}, 'IgnoreCase', true)
                    skipVar = true;
                end
            end
            if skipVar
                continue;
            end

            x = S.(vname);
            vclass = class(x);

            if istable(x) || istimetable(x)
                nTables = nTables + 1;
                if istimetable(x)
                    T = timetable2table(x);
                else
                    T = x;
                end

                [score, matched] = scoreBehaviorTable(vname, T.Properties.VariableNames, tableNameKeywords, columnKeywords);
                if score > 0
                    nCandidateTables = nCandidateTables + 1;
                end

                nRows = height(T);
                nCols = width(T);
                colPreview = strjoin(T.Properties.VariableNames(1:min(30,nCols)), ' | ');

                tableRows(end+1,:) = {subj, fileName, filePath, vname, vclass, nRows, nCols, score, strjoin(matched,'|'), colPreview}; %#ok<SAGROW>

                for c = 1:nCols
                    cname = T.Properties.VariableNames{c};
                    col = T.(cname);
                    cclass = class(col);
                    csize = mat2str(size(col));
                    nMissing = countMissing(col);
                    uniquePreview = previewValues(col, 8);
                    [cScore, cMatched] = scoreColumn(cname, columnKeywords);

                    columnRows(end+1,:) = {subj, fileName, filePath, vname, cname, cclass, csize, nMissing, cScore, strjoin(cMatched,'|'), uniquePreview}; %#ok<SAGROW>
                end

            elseif isstruct(x)
                fns = fieldnames(x);
                [sScore, sMatched] = scoreNameList([vname; fns], [tableNameKeywords columnKeywords]);
                if sScore > 0
                    structRows(end+1,:) = {subj, fileName, filePath, vname, vclass, mat2str(size(x)), numel(fns), sScore, strjoin(sMatched,'|'), strjoin(fns(1:min(30,end)), ' | ')}; %#ok<SAGROW>
                end
            end
        end

        fileRows(end+1,:) = {subj, fileName, filePath, 'ok', nTables, nCandidateTables, ''}; %#ok<SAGROW>

    catch ME
        fileRows(end+1,:) = {subj, fileName, filePath, ['error: ' ME.message], NaN, NaN, ''}; %#ok<SAGROW>
    end
end

%% Save
if isempty(tableRows)
    Ttables = cell2table(cell(0,10), 'VariableNames', {'Subject','FileName','FilePath','VariableName','VariableClass','NRows','NColumns','BehaviorTableScore','MatchedKeywords','ColumnPreview'});
else
    Ttables = cell2table(tableRows, 'VariableNames', {'Subject','FileName','FilePath','VariableName','VariableClass','NRows','NColumns','BehaviorTableScore','MatchedKeywords','ColumnPreview'});
end

if isempty(columnRows)
    Tcols = cell2table(cell(0,11), 'VariableNames', {'Subject','FileName','FilePath','TableVariable','ColumnName','ColumnClass','ColumnSize','NMissing','BehaviorColumnScore','MatchedKeywords','ValuePreview'});
else
    Tcols = cell2table(columnRows, 'VariableNames', {'Subject','FileName','FilePath','TableVariable','ColumnName','ColumnClass','ColumnSize','NMissing','BehaviorColumnScore','MatchedKeywords','ValuePreview'});
end

if isempty(structRows)
    Tstruct = cell2table(cell(0,10), 'VariableNames', {'Subject','FileName','FilePath','VariableName','VariableClass','VariableSize','NFields','BehaviorStructScore','MatchedKeywords','FieldPreview'});
else
    Tstruct = cell2table(structRows, 'VariableNames', {'Subject','FileName','FilePath','VariableName','VariableClass','VariableSize','NFields','BehaviorStructScore','MatchedKeywords','FieldPreview'});
end

if isempty(fileRows)
    Tfiles = cell2table(cell(0,7), 'VariableNames', {'Subject','FileName','FilePath','Status','NTables','NCandidateTables','Note'});
else
    Tfiles = cell2table(fileRows, 'VariableNames', {'Subject','FileName','FilePath','Status','NTables','NCandidateTables','Note'});
end

writetable(Ttables, fullfile(outDir, 'STEP02B_Behavior_TableInventory.csv'));
writetable(Tcols,   fullfile(outDir, 'STEP02B_Behavior_TableColumnInventory.csv'));
writetable(Tstruct, fullfile(outDir, 'STEP02B_Behavior_StructInventory.csv'));
writetable(Tfiles,  fullfile(outDir, 'STEP02B_Behavior_FileInspectLog.csv'));

% Candidate tables sorted
if ~isempty(Ttables)
    TcandidateTables = Ttables(Ttables.BehaviorTableScore > 0 & Ttables.NRows > 0, :);
    TcandidateTables = sortrows(TcandidateTables, {'BehaviorTableScore','NRows'}, {'descend','descend'});
else
    TcandidateTables = Ttables;
end
writetable(TcandidateTables, fullfile(outDir, 'STEP02B_Behavior_CandidateTables.csv'));

fprintf('\n================ STEP02B SUMMARY ================\n');
fprintf('Files inspected: %d\n', height(Tfiles));
fprintf('Tables found: %d\n', height(Ttables));
fprintf('Candidate behavioral tables: %d\n', height(TcandidateTables));
fprintf('Columns inventoried: %d\n', height(Tcols));
fprintf('Outputs saved in:\n%s\n', outDir);

if height(TcandidateTables) > 0
    fprintf('\nTop candidate tables:\n');
    disp(TcandidateTables(1:min(20,height(TcandidateTables)), {'Subject','FileName','VariableName','NRows','NColumns','BehaviorTableScore'}));
end

%% Functions
function [score, matched] = scoreBehaviorTable(vname, colNames, tableNameKeywords, columnKeywords)
    score = 0;
    matched = {};

    lowV = lower(vname);
    for k = 1:numel(tableNameKeywords)
        kw = lower(tableNameKeywords{k});
        if contains(lowV, kw)
            score = score + 2;
            matched{end+1} = ['var:' kw]; %#ok<AGROW>
        end
    end

    for c = 1:numel(colNames)
        [cs, cm] = scoreColumn(colNames{c}, columnKeywords);
        score = score + cs;
        for j = 1:numel(cm)
            matched{end+1} = ['col:' cm{j}]; %#ok<AGROW>
        end
    end

    matched = unique(matched, 'stable');
end

function [score, matched] = scoreColumn(cname, keywords)
    score = 0;
    matched = {};
    low = lower(cname);
    for k = 1:numel(keywords)
        kw = lower(keywords{k});
        if contains(low, kw)
            score = score + 1;
            matched{end+1} = kw; %#ok<AGROW>
        end
    end
end

function [score, matched] = scoreNameList(names, keywords)
    score = 0;
    matched = {};
    for i = 1:numel(names)
        low = lower(names{i});
        for k = 1:numel(keywords)
            kw = lower(keywords{k});
            if contains(low, kw)
                score = score + 1;
                matched{end+1} = [names{i} ':' kw]; %#ok<AGROW>
            end
        end
    end
    matched = unique(matched, 'stable');
end

function n = countMissing(x)
    try
        if isnumeric(x) || islogical(x)
            n = sum(isnan(double(x(:))));
        elseif iscell(x)
            n = sum(cellfun(@(z) isempty(z) || (isstring(z) && strlength(z)==0), x(:)));
        elseif isstring(x)
            n = sum(ismissing(x(:)) | strlength(x(:))==0);
        elseif iscategorical(x)
            n = sum(isundefined(x(:)));
        else
            n = NaN;
        end
    catch
        n = NaN;
    end
end

function txt = previewValues(x, maxN)
    txt = '';
    try
        if istable(x) || istimetable(x)
            txt = '<nested table>';
            return;
        end

        if iscell(x)
            vals = x(:);
            vals = vals(1:min(maxN,numel(vals)));
            parts = cell(size(vals));
            for i = 1:numel(vals)
                parts{i} = valueToText(vals{i});
            end
            txt = strjoin(parts, ' | ');
        elseif isnumeric(x) || islogical(x)
            vals = x(:);
            vals = vals(isfinite(double(vals)));
            vals = vals(1:min(maxN,numel(vals)));
            parts = arrayfun(@(z) sprintf('%.6g', z), vals, 'UniformOutput', false);
            txt = strjoin(parts, ' | ');
        elseif isstring(x)
            vals = x(:);
            vals = vals(1:min(maxN,numel(vals)));
            txt = strjoin(cellstr(vals), ' | ');
        elseif iscategorical(x)
            vals = cellstr(x(:));
            vals = vals(1:min(maxN,numel(vals)));
            txt = strjoin(vals, ' | ');
        else
            txt = ['<' class(x) '>'];
        end

        if strlength(string(txt)) > 300
            txt = char(extractBefore(string(txt), 301));
        end
    catch ME
        txt = ['preview_error: ' ME.message];
    end
end

function txt = valueToText(v)
    try
        if isnumeric(v) || islogical(v)
            if isempty(v)
                txt = '';
            elseif isscalar(v)
                txt = sprintf('%.6g', double(v));
            else
                txt = ['[' mat2str(size(v)) ' numeric]'];
            end
        elseif ischar(v)
            txt = v;
        elseif isstring(v)
            txt = char(v);
        else
            txt = ['<' class(v) '>'];
        end
    catch
        txt = '<unreadable>';
    end
end

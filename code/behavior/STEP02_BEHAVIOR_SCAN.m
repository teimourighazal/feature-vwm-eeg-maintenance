%% STEP02_BEHAVIOR_SCAN.m
% Behavioral data inventory for Article2.
%
% Purpose:
%   This is the first behavioral step after resting-state finalization.
%   It scans the selected Subjects/project folder recursively and looks for
%   likely behavioral/task files and variables.
%
% Output:
%   STEP02_Behavior_Scan under the selected Article2 Analysis folder.
%
% Outputs:
%   STEP02_Behavior_FileInventory.csv
%   STEP02_Behavior_MAT_VariableInventory.csv
%   STEP02_Behavior_TableColumnInventory.csv
%   STEP02_Behavior_CandidateFiles.csv
%
% This script does NOT modify data. It only identifies where behavioral data are.

clear; clc;

%% Config
selectedRoot = uigetdir(pwd, 'Select Subjects folder or project folder containing behavioral/task files');
if isequal(selectedRoot, 0)
    error('No folder selected.');
end

if exist(fullfile(selectedRoot, 'Subjects'), 'dir')
    searchRoot = fullfile(selectedRoot, 'Subjects');
else
    searchRoot = selectedRoot;
end

outRoot = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(outRoot, 0)
    error('Article2 Analysis folder was not selected.');
end

outDir  = fullfile(outRoot, 'STEP02_Behavior_Scan');
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP02 BEHAVIOR SCAN ===\n');
fprintf('Search root:\n%s\n', searchRoot);
fprintf('Output folder:\n%s\n', outDir);

behaviorKeywords = {'behavior','behaviour','behav','task','trial','trials','response','resp','reaction','rt','accuracy','correct','result','run','condition','color','orientation','conjunction','ori','conj'};
ignoreKeywords = {'rest','resting','eye open','eye close','eyes open','eyes close','edf','STEP00','STEP01','STEP02','output','outputs','__MACOSX'};

patterns = {'*.mat','*.csv','*.xlsx','*.xls','*.txt','*.tsv'};
files = [];

for p = 1:numel(patterns)
    files = [files; dir(fullfile(searchRoot, patterns{p})); dir(fullfile(searchRoot, '**', patterns{p}))]; %#ok<AGROW>
end

files = files(~[files.isdir]);

% remove duplicates
if ~isempty(files)
    fullPaths = cell(numel(files),1);
    for i = 1:numel(files)
        fullPaths{i} = fullfile(files(i).folder, files(i).name);
    end
    [~, ia] = unique(fullPaths, 'stable');
    files = files(ia);
end

fileRows = {};
matRows = {};
tableRows = {};

for i = 1:numel(files)
    fileName = files(i).name;
    filePath = fullfile(files(i).folder, fileName);
    relPath = strrep(filePath, [searchRoot filesep], '');
    [~,~,ext] = fileparts(fileName);
    ext = lower(ext);

    lowText = lower([fileName ' ' relPath]);
    isIgnored = false;
    for k = 1:numel(ignoreKeywords)
        if contains(lowText, lower(ignoreKeywords{k}))
            isIgnored = true;
        end
    end

    score = 0;
    matched = {};
    for k = 1:numel(behaviorKeywords)
        kw = lower(behaviorKeywords{k});
        if contains(lowText, kw)
            score = score + 1;
            matched{end+1} = kw; %#ok<AGROW>
        end
    end

    subject = inferSubject(filePath, searchRoot);

    fileDecision = 'unknown';
    if isIgnored
        fileDecision = 'ignored_by_name';
    elseif score > 0
        fileDecision = 'candidate_behavior_by_name';
    end

    nRows = NaN; nCols = NaN; preview = '';

    try
        if strcmp(ext, '.mat')
            W = whos('-file', filePath);
            varNames = {W.name};
            preview = strjoin(varNames(1:min(20,end)), ' | ');

            vscore = 0;
            vmatched = {};
            for v = 1:numel(varNames)
                vn = lower(varNames{v});
                for k = 1:numel(behaviorKeywords)
                    kw = lower(behaviorKeywords{k});
                    if contains(vn, kw)
                        vscore = vscore + 1;
                        vmatched{end+1} = [varNames{v} ':' kw]; %#ok<AGROW>
                    end
                end

                matRows(end+1,:) = {subject, fileName, relPath, filePath, varNames{v}, classFromWhos(W(v)), mat2str(W(v).size), prod(W(v).size)}; %#ok<SAGROW>
            end

            score = score + vscore;
            if ~isIgnored && score > 0
                fileDecision = 'candidate_behavior_by_name_or_variables';
            end

        elseif any(strcmp(ext, {'.csv','.tsv','.txt','.xlsx','.xls'}))
            try
                opts = detectImportOptions(filePath);
                colNames = opts.VariableNames;
                preview = strjoin(colNames(1:min(20,end)), ' | ');
                nCols = numel(colNames);

                Tpreview = readtable(filePath, opts);
                nRows = height(Tpreview);

                cscore = 0;
                for c = 1:numel(colNames)
                    cn = lower(colNames{c});
                    colHit = false;
                    hitWords = {};
                    for k = 1:numel(behaviorKeywords)
                        kw = lower(behaviorKeywords{k});
                        if contains(cn, kw)
                            cscore = cscore + 1;
                            colHit = true;
                            hitWords{end+1} = kw; %#ok<AGROW>
                        end
                    end
                    tableRows(end+1,:) = {subject, fileName, relPath, filePath, colNames{c}, colHit, strjoin(hitWords, '|')}; %#ok<SAGROW>
                end

                score = score + cscore;
                if ~isIgnored && score > 0
                    fileDecision = 'candidate_behavior_by_name_or_columns';
                end
            catch ME
                preview = ['table_read_error: ' ME.message];
            end
        end
    catch ME
        preview = ['inspection_error: ' ME.message];
    end

    fileRows(end+1,:) = {subject, fileName, relPath, filePath, files(i).bytes, ext, isIgnored, score, strjoin(matched,'|'), nRows, nCols, preview, fileDecision}; %#ok<SAGROW>
end

Tfiles = cell2table(fileRows, 'VariableNames', ...
    {'Subject','FileName','RelativePath','FilePath','FileBytes','Extension','IgnoredByName','BehaviorScore','MatchedNameKeywords','NRows','NColumns','Preview','FileDecision'});
writetable(Tfiles, fullfile(outDir, 'STEP02_Behavior_FileInventory.csv'));

if isempty(matRows)
    Tmat = cell2table(cell(0,8), 'VariableNames', {'Subject','FileName','RelativePath','FilePath','VariableName','VariableClass','VariableSize','ElementCount'});
else
    Tmat = cell2table(matRows, 'VariableNames', {'Subject','FileName','RelativePath','FilePath','VariableName','VariableClass','VariableSize','ElementCount'});
end
writetable(Tmat, fullfile(outDir, 'STEP02_Behavior_MAT_VariableInventory.csv'));

if isempty(tableRows)
    Ttab = cell2table(cell(0,7), 'VariableNames', {'Subject','FileName','RelativePath','FilePath','ColumnName','BehaviorColumnHit','MatchedColumnKeywords'});
else
    Ttab = cell2table(tableRows, 'VariableNames', {'Subject','FileName','RelativePath','FilePath','ColumnName','BehaviorColumnHit','MatchedColumnKeywords'});
end
writetable(Ttab, fullfile(outDir, 'STEP02_Behavior_TableColumnInventory.csv'));

Tcand = Tfiles(~Tfiles.IgnoredByName & Tfiles.BehaviorScore > 0, :);
Tcand = sortrows(Tcand, {'BehaviorScore','FileBytes'}, {'descend','descend'});
writetable(Tcand, fullfile(outDir, 'STEP02_Behavior_CandidateFiles.csv'));

fprintf('\n================ STEP02 SCAN SUMMARY ================\n');
fprintf('Total files inspected: %d\n', height(Tfiles));
fprintf('Candidate behavioral files: %d\n', height(Tcand));
fprintf('MAT variables inventoried: %d\n', height(Tmat));
fprintf('Table columns inventoried: %d\n', height(Ttab));
fprintf('Outputs saved in:\n%s\n', outDir);

if height(Tcand) > 0
    fprintf('\nTop candidate files:\n');
    disp(Tcand(1:min(10,height(Tcand)), {'Subject','FileName','BehaviorScore','FileDecision'}));
end

%% Functions
function subj = inferSubject(filePath, root)
    subj = '';
    rel = strrep(filePath, [root filesep], '');
    parts = regexp(rel, filesep, 'split');

    if numel(parts) > 1
        cand = parts{1};
        low = lower(cand);
        if ~contains(low, 'step') && ~contains(low, 'output') && ~contains(low, 'analysis')
            subj = cand;
        end
    end

    if isempty(subj)
        [~,base,~] = fileparts(filePath);
        base = regexprep(base, '[_\-]+', ' ');
        base = strtrim(base);
        tokens = split(base);
        if ~isempty(tokens)
            subj = tokens{1};
        end
    end
end

function cls = classFromWhos(w)
    if isfield(w, 'class')
        cls = w.class;
    else
        cls = '';
    end
end

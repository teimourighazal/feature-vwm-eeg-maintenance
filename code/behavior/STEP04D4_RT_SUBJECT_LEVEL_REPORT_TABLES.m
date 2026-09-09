%% STEP04D4_RT_SUBJECT_LEVEL_REPORT_TABLES.m
% Corrected subject-level report tables for reconstructed RT.
%
% Why this script:
%   STEP04D created useful outputs, but the condition table was based on
%   pooled trial-level RT. Since Friedman and Wilcoxon tests are performed
%   on subject-level condition medians, the primary descriptive table for
%   the manuscript should also be subject-level.
%
% Input:
%   STEP04D_RT_FinalReport/RT_FinalReport_SubjectWide_EEG_ALIGNED.csv
%   STEP04C_RT_EEG_Alignment/STEP04C_RT_Friedman_EEG_ALIGNED.csv
%   STEP04D_RT_FinalReport/RT_FinalReport_PairwiseTable_EEG_ALIGNED.csv
%
% Output:
%   /Users/ghazal/Desktop/Article2/Analysis/STEP04D4_RT_SubjectLevelReport
%   /Users/ghazal/Desktop/Article2/Analysis/Result/STEP04D4_RT_SubjectLevelReport
%
% Main outputs:
%   RT_SubjectLevel_ConditionDescriptives_EEG_ALIGNED.csv
%   RT_SubjectLevel_KeyResults_EEG_ALIGNED.csv
%   RT_SubjectLevel_ResultsText_English.txt
%   RT_SubjectLevel_ResultsText_Persian.txt

clear; clc; close all;

rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
outDir = fullfile(rootDir, 'STEP04D4_RT_SubjectLevelReport');
resultRoot = fullfile(rootDir, 'Result');
resultOutDir = fullfile(resultRoot, 'STEP04D4_RT_SubjectLevelReport');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(resultRoot, 'dir'); mkdir(resultRoot); end
if ~exist(resultOutDir, 'dir'); mkdir(resultOutDir); end

fprintf('\n=== STEP04D4 RT SUBJECT-LEVEL REPORT TABLES ===\n');

wideFile = findInput(rootDir, 'STEP04D_RT_FinalReport', 'RT_FinalReport_SubjectWide_EEG_ALIGNED.csv');
friedFile = findInput(rootDir, 'STEP04C_RT_EEG_Alignment', 'STEP04C_RT_Friedman_EEG_ALIGNED.csv');
pairFile = findInput(rootDir, 'STEP04D_RT_FinalReport', 'RT_FinalReport_PairwiseTable_EEG_ALIGNED.csv');
keyFile = findInput(rootDir, 'STEP04D_RT_FinalReport', 'RT_FinalReport_KeyNumbers.csv');
alignFile = findInput(rootDir, 'STEP04C_RT_EEG_Alignment', 'STEP04C_RT_EEG_SubjectAlignment.csv');

Twide = readtable(wideFile);
Tfried = readtable(friedFile);
Tpair = readtable(pairFile);
TkeyOld = readtable(keyFile);
Talign = readtable(alignFile);

%% Subject-level condition descriptives
condNames = {'color','orientation','conjunction'};
varNames = {'color_MedianRT_ms','orientation_MedianRT_ms','conjunction_MedianRT_ms'};

rows = {};
for c = 1:numel(condNames)
    vals = Twide.(varNames{c});
    rows(end+1,:) = {condNames{c}, sum(isfinite(vals)), ...
        median(vals,'omitnan'), mean(vals,'omitnan'), std(vals,'omitnan'), ...
        prctile(vals(isfinite(vals)),25), prctile(vals(isfinite(vals)),75), ...
        min(vals,[],'omitnan'), max(vals,[],'omitnan')}; %#ok<AGROW>
end

Tdesc = cell2table(rows, 'VariableNames', ...
    {'Condition','NSubjects','MedianOfSubjectMedians_ms','MeanOfSubjectMedians_ms','SDSubjectMedians_ms', ...
     'Q1SubjectMedians_ms','Q3SubjectMedians_ms','MinSubjectMedian_ms','MaxSubjectMedian_ms'});

writetable(Tdesc, fullfile(outDir, 'RT_SubjectLevel_ConditionDescriptives_EEG_ALIGNED.csv'));

%% Key results
nEEG = getKey(TkeyOld, 'Final EEG subjects');
nRT = getKey(TkeyOld, 'EEG-aligned RT subjects');
nValid = getKey(TkeyOld, 'EEG-aligned valid RT rows');
nComplete = Tfried.NCompleteSubjects(1);
pF = Tfried.p_Friedman(1);
W = Tfried.KendallW(1);

% Subject lists are computed directly from alignment file to avoid <missing>
% conversion issues in older KeyNumbers CSVs.
rtOnlyList = subjectListFromAlignment(Talign, 'rt_only');
eegOnlyList = subjectListFromAlignment(Talign, 'eeg_only');

Tkey = table();
Tkey.Metric = {
    'Final EEG subjects';
    'EEG-aligned RT subjects';
    'Valid RT observations';
    'Friedman complete-case N';
    'Friedman p';
    'Kendall W';
    'Subject-level color median ms';
    'Subject-level orientation median ms';
    'Subject-level conjunction median ms';
    'Subject-level conjunction mean ms';
    'Subjects with conjunction median > 2000 ms';
    'RT-only subject list';
    'EEG-only subject list'
    };
Tkey.Value = {
    nEEG;
    nRT;
    nValid;
    nComplete;
    pF;
    W;
    Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'color'));
    Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'orientation'));
    Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'conjunction'));
    Tdesc.MeanOfSubjectMedians_ms(strcmp(Tdesc.Condition,'conjunction'));
    sum(Twide.conjunction_MedianRT_ms > 2000);
    rtOnlyList;
    eegOnlyList
    };

writetable(Tkey, fullfile(outDir, 'RT_SubjectLevel_KeyResults_EEG_ALIGNED.csv'));

%% Text outputs
pCO = Tpair.p_Signrank(strcmp(Tpair.Contrast,'color_vs_orientation'));
qCO = Tpair.q_FDR_threeContrasts(strcmp(Tpair.Contrast,'color_vs_orientation'));
pCC = Tpair.p_Signrank(strcmp(Tpair.Contrast,'color_vs_conjunction'));
qCC = Tpair.q_FDR_threeContrasts(strcmp(Tpair.Contrast,'color_vs_conjunction'));
pOC = Tpair.p_Signrank(strcmp(Tpair.Contrast,'orientation_vs_conjunction'));
qOC = Tpair.q_FDR_threeContrasts(strcmp(Tpair.Contrast,'orientation_vs_conjunction'));

medColor = Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'color'));
medOri = Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'orientation'));
medConj = Tdesc.MedianOfSubjectMedians_ms(strcmp(Tdesc.Condition,'conjunction'));

englishText = sprintf(['Reconstructed response-interval data were available for %.0f of the %.0f final task-EEG participants, ', ...
    'yielding %.0f valid observations. Subject-level median response interval differed across conditions, Friedman p = %.3g, ', ...
    'Kendall''s W = %.2f, based on %.0f complete-case participants. Median subject-level response intervals were %.0f ms for color-only, ', ...
    '%.0f ms for orientation-only, and %.0f ms for conjunction trials. Color-only trials were faster than orientation-only trials ', ...
    '(p = %.3g, FDR q = %.3g) and conjunction trials (p = %.3g, FDR q = %.3g). The orientation-versus-conjunction contrast was ', ...
    'borderline after correction (p = %.3g, FDR q = %.3g), although the median subject-level difference was small.'], ...
    nRT, nEEG, nValid, pF, W, nComplete, medColor, medOri, medConj, pCO, qCO, pCC, qCC, pOC, qOC);

persianText = sprintf(['داده‌های شاخص زمان‌بندی بازسازی‌شده برای %.0f نفر از %.0f شرکت‌کننده نهایی تحلیل EEG تکلیف در دسترس بود و در مجموع %.0f مشاهده معتبر باقی ماند. ', ...
    'میانه subject-level این شاخص بین سه وضعیت تکلیف تفاوت معنادار داشت  Friedman p = %.3g, Kendall''s W = %.2f  و این آزمون بر اساس %.0f شرکت‌کننده دارای داده کامل در هر سه وضعیت انجام شد. ', ...
    'میانه‌های subject-level برابر با %.0f میلی‌ثانیه برای color-only، %.0f میلی‌ثانیه برای orientation-only و %.0f میلی‌ثانیه برای conjunction بودند. ', ...
    'تریال‌های color-only سریع‌تر از orientation-only  p = %.3g, FDR q = %.3g  و سریع‌تر از conjunction  p = %.3g, FDR q = %.3g  بودند. ', ...
    'مقایسه orientation-versus-conjunction پس از اصلاح آماری به‌صورت مرزی معنادار بود  p = %.3g, FDR q = %.3g  اما تفاوت میانه subject-level آن کوچک بود.'], ...
    nRT, nEEG, nValid, pF, W, nComplete, medColor, medOri, medConj, pCO, qCO, pCC, qCC, pOC, qOC);

writeText(fullfile(outDir, 'RT_SubjectLevel_ResultsText_English.txt'), englishText);
writeText(fullfile(outDir, 'RT_SubjectLevel_ResultsText_Persian.txt'), persianText);

%% Copy
copyOutputsToResultFolder(outDir, resultOutDir);

fprintf('\nSubject-level descriptives:\n');
disp(Tdesc);
fprintf('\nKey results:\n');
disp(Tkey);
fprintf('\nOutputs saved in:\n%s\n', outDir);
fprintf('\nClean result copy saved in:\n%s\n', resultOutDir);

%% Functions
function fpath = findInput(rootDir, folderName, fileName)
    candidates = {
        fullfile(rootDir, folderName, fileName);
        fullfile(rootDir, 'Result', folderName, fileName);
        fullfile(rootDir, fileName);
        fullfile(pwd, fileName)
    };

    fpath = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            fpath = candidates{i};
            return;
        end
    end

    [selFile, selPath] = uigetfile('*.csv', ['Select ' fileName]);
    if isequal(selFile,0)
        error('Input file not selected: %s', fileName);
    end
    fpath = fullfile(selPath, selFile);
end

function val = getKey(Tkey, name)
    % Robust key reader for MATLAB tables where Value may be numeric,
    % string, char, categorical, cell, or missing.
    val = NaN;

    if isempty(Tkey) || ~ismember('Metric', Tkey.Properties.VariableNames) || ~ismember('Value', Tkey.Properties.VariableNames)
        return;
    end

    metricVals = string(Tkey.Metric);
    idx = find(metricVals == string(name), 1);
    if isempty(idx)
        return;
    end

    V = Tkey.Value;

    try
        if iscell(V)
            raw = V{idx};
        elseif isnumeric(V) || islogical(V)
            raw = V(idx);
        elseif isstring(V)
            raw = V(idx);
        elseif iscategorical(V)
            raw = string(V(idx));
        elseif ischar(V)
            raw = V(idx,:);
        else
            raw = V(idx);
        end
    catch
        val = NaN;
        return;
    end

    if isnumeric(raw) || islogical(raw)
        val = double(raw);
        if numel(val) > 1
            val = val(1);
        end
        return;
    end

    rawStr = string(raw);
    if ismissing(rawStr) || strlength(rawStr) == 0 || strcmpi(rawStr, "<missing>")
        val = NaN;
        return;
    end

    n = str2double(rawStr);
    if isfinite(n)
        val = n;
    else
        val = rawStr;
    end
end

function txt = subjectListFromAlignment(Talign, statusName)
    txt = '';

    if isempty(Talign) || ~ismember('AlignmentStatus', Talign.Properties.VariableNames) || ~ismember('Subject', Talign.Properties.VariableNames)
        return;
    end

    statusVals = string(Talign.AlignmentStatus);
    idx = statusVals == string(statusName);

    if ~any(idx)
        return;
    end

    subs = string(Talign.Subject(idx));
    subs = subs(~ismissing(subs) & strlength(subs) > 0);

    if isempty(subs)
        txt = '';
    else
        txt = char(strjoin(subs, ','));
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

    patterns = {'*.csv','*.txt','*.mat','*.png','*.fig','*.pdf'};
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

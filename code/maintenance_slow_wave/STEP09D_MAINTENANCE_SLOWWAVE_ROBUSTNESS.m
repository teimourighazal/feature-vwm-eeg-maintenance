%% STEP09D_MAINTENANCE_SLOWWAVE_ROBUSTNESS.m
% STEP09D: Robustness checks for maintenance slow-wave condition effects.
%
% Run after:
%   STEP09B3_MAINTENANCE_SLOWWAVE_N22_PATHFIX.m
%
% Goal:
%   Check whether the strong maintenance slow-wave effects are robust across:
%     1) subject-level direction consistency
%     2) leave-one-subject-out stability
%     3) run-level replication
%
% Main input:
%   Result/STEP09B3_MaintenanceSlowWave_N22
%
% Outputs:
%   Result/STEP09D_MaintenanceSlowWave_Robustness
%
% Main outputs:
%   STEP09D_RobustnessSummary.csv
%   STEP09D_CoreEffectRobustness.csv
%   STEP09D_PairwiseDirectionConsistency.csv
%   STEP09D_LeaveOneSubjectOut.csv
%   STEP09D_RunLevelReplication.csv
%   STEP09D_RecommendedInterpretation.txt

clear; clc; close all;

%% Paths
rootDir = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(rootDir, 0)
    error('Article2 Analysis folder was not selected.');
end
resultRoot = fullfile(rootDir, 'Result');
step09BOut = fullfile(resultRoot, 'STEP09B3_MaintenanceSlowWave_N22');
outDir = fullfile(resultRoot, 'STEP09D_MaintenanceSlowWave_Robustness');

if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=== STEP09D MAINTENANCE SLOW-WAVE ROBUSTNESS ===\n');
fprintf('Output folder:\n%s\n', outDir);

%% Input files
subjFile = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_SubjectCondition.csv');
trialFile = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_TrialFeatures.csv');
omniFile = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_Omnibus.csv');
pairFile = fullfile(step09BOut, 'STEP09B3_MaintenanceSlowWave_Pairwise.csv');

if exist(subjFile,'file') ~= 2
    error('Missing STEP09B3 subject-condition file. Run STEP09B3 first.');
end
if exist(trialFile,'file') ~= 2
    error('Missing STEP09B3 trial-feature file. Run STEP09B3 first.');
end
if exist(omniFile,'file') ~= 2
    error('Missing STEP09B3 omnibus file. Run STEP09B3 first.');
end

Tsubj = readtable(subjFile, 'VariableNamingRule','preserve');
Ttrial = readtable(trialFile, 'VariableNamingRule','preserve');
Tomni = readtable(omniFile, 'VariableNamingRule','preserve');
Tpair = readtable(pairFile, 'VariableNamingRule','preserve');

% Normalize strings
stringCols = intersect({'Subject','Run','ConditionLabel','Window','ROI'}, Tsubj.Properties.VariableNames);
for i = 1:numel(stringCols); Tsubj.(stringCols{i}) = cellstr(string(Tsubj.(stringCols{i}))); end
stringCols = intersect({'Subject','Run','ConditionLabel','Window','ROI'}, Ttrial.Properties.VariableNames);
for i = 1:numel(stringCols); Ttrial.(stringCols{i}) = cellstr(string(Ttrial.(stringCols{i}))); end
stringCols = intersect({'Window','ROI','MaxCondition'}, Tomni.Properties.VariableNames);
for i = 1:numel(stringCols); Tomni.(stringCols{i}) = cellstr(string(Tomni.(stringCols{i}))); end

%% Sort core effects by q and p
Tomni = sortrows(Tomni, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
coreEffects = Tomni;  % all 24 effects are evaluated

%% Direction consistency for all pairwise contrasts
Tdir = pairwiseDirectionConsistency(Tsubj);
writetable(Tdir, fullfile(outDir, 'STEP09D_PairwiseDirectionConsistency.csv'));

%% Leave-one-subject-out for all omnibus effects
Tloo = leaveOneSubjectOut(Tsubj, coreEffects);
writetable(Tloo, fullfile(outDir, 'STEP09D_LeaveOneSubjectOut.csv'));

%% Run-level replication
Trun = runLevelReplication(Ttrial, coreEffects);
writetable(Trun, fullfile(outDir, 'STEP09D_RunLevelReplication.csv'));

%% Combine robustness summary
Tcore = makeCoreRobustnessTable(coreEffects, Tdir, Tloo, Trun);
writetable(Tcore, fullfile(outDir, 'STEP09D_CoreEffectRobustness.csv'));

Tsummary = makeSummary(Tcore, Tdir, Tloo, Trun);
writetable(Tsummary, fullfile(outDir, 'STEP09D_RobustnessSummary.csv'));

txt = makeInterpretation(Tcore, Tsummary);
writeText(fullfile(outDir, 'STEP09D_RecommendedInterpretation.txt'), txt);

save(fullfile(outDir, 'STEP09D_MaintenanceSlowWave_Robustness_Workspace.mat'), ...
    'Tsubj','Ttrial','Tomni','Tpair','Tdir','Tloo','Trun','Tcore','Tsummary','txt');

fprintf('\n================ STEP09D SUMMARY ================\n');
disp(Tsummary);
fprintf('\n%s\n', txt);
fprintf('\nOutputs saved in:\n%s\n', outDir);

%% ===================== local functions =====================

function Tdir = pairwiseDirectionConsistency(Tsubj)
    pairs = {'color','orientation'; 'color','conjunction'; 'conjunction','orientation'};
    U = unique(Tsubj(:, {'Window','ROI'}), 'rows');
    rows = {};

    for i = 1:height(U)
        S = Tsubj(strcmp(Tsubj.Window,U.Window{i}) & strcmp(Tsubj.ROI,U.ROI{i}), :);
        W = wideConditions(S, 'SubjectMedianMeanAmplitude');
        if height(W)==0; continue; end

        for p = 1:size(pairs,1)
            a = pairs{p,1};
            b = pairs{p,2};
            d = W.(a) - W.(b);
            n = sum(isfinite(d));
            nPositive = sum(d > 0);
            nNegative = sum(d < 0);
            propPositive = nPositive / n;
            propNegative = nNegative / n;

            if median(d,'omitnan') > 0
                medianDirection = [a '_greater_than_' b];
                expectedProp = propPositive;
                expectedCount = nPositive;
            elseif median(d,'omitnan') < 0
                medianDirection = [b '_greater_than_' a];
                expectedProp = propNegative;
                expectedCount = nNegative;
            else
                medianDirection = 'no_median_difference';
                expectedProp = NaN;
                expectedCount = NaN;
            end

            pSign = NaN;
            try
                pSign = signrank(W.(a), W.(b));
            catch
            end

            rows(end+1,:) = {U.Window{i}, U.ROI{i}, [a '_vs_' b], n, ...
                median(W.(a),'omitnan'), median(W.(b),'omitnan'), median(d,'omitnan'), ...
                pSign, medianDirection, expectedCount, expectedProp, ...
                strjoin(W.Subject,'|')}; %#ok<AGROW>
        end
    end

    Tdir = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','Contrast','NSubjects','Median_A','Median_B','MedianDiff_AminusB', ...
        'p_Signrank','MedianDirection','NSubjectsInMedianDirection','PropSubjectsInMedianDirection','SubjectsUsed'});
    Tdir.q_FDR = fdrBH(Tdir.p_Signrank);
    Tdir = sortrows(Tdir, {'q_FDR','p_Signrank'}, {'ascend','ascend'});
end

function Tloo = leaveOneSubjectOut(Tsubj, coreEffects)
    rows = {};
    for i = 1:height(coreEffects)
        win = coreEffects.Window{i};
        roi = coreEffects.ROI{i};

        S = Tsubj(strcmp(Tsubj.Window,win) & strcmp(Tsubj.ROI,roi), :);
        W = wideConditions(S, 'SubjectMedianMeanAmplitude');
        if height(W)==0; continue; end

        allSubjects = W.Subject;
        pVals = NaN(height(W),1);
        wVals = NaN(height(W),1);
        maxConds = cell(height(W),1);

        for s = 1:height(W)
            Wloo = W;
            leftOut = W.Subject{s};
            Wloo(s,:) = [];
            X = [Wloo.color, Wloo.orientation, Wloo.conjunction];

            try
                [p,tbl] = friedman(X,1,'off');
                chi2 = tbl{2,5};
                kendallW = chi2/(height(Wloo)*(3-1));
            catch
                p = NaN; kendallW = NaN;
            end

            meds = median(X,1,'omitnan');
            conds = {'color','orientation','conjunction'};
            [~,mx] = max(meds);

            pVals(s) = p;
            wVals(s) = kendallW;
            maxConds{s} = conds{mx};
        end

        sameMax = strcmp(maxConds, coreEffects.MaxCondition{i});
        rows(end+1,:) = {win, roi, coreEffects.NSubjects(i), coreEffects.p_Friedman(i), coreEffects.q_FDR(i), coreEffects.KendallW(i), ...
            coreEffects.MaxCondition{i}, ...
            min(pVals,[],'omitnan'), max(pVals,[],'omitnan'), median(pVals,'omitnan'), ...
            min(wVals,[],'omitnan'), median(wVals,'omitnan'), ...
            sum(pVals < 0.05), mean(pVals < 0.05), sum(sameMax), mean(sameMax), ...
            strjoin(allSubjects,'|')}; %#ok<AGROW>
    end

    Tloo = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','NSubjects','Original_p','Original_q','Original_KendallW','OriginalMaxCondition', ...
        'LOO_MinP','LOO_MaxP','LOO_MedianP','LOO_MinKendallW','LOO_MedianKendallW', ...
        'N_LOO_p_lt_05','Prop_LOO_p_lt_05','N_LOO_SameMaxCondition','Prop_LOO_SameMaxCondition','SubjectsUsed'});
    Tloo = sortrows(Tloo, {'Original_q','Original_p'}, {'ascend','ascend'});
end

function Trun = runLevelReplication(Ttrial, coreEffects)
    % Aggregate trial-level features to Subject x Run x Condition x Window x ROI.
    keys = {'Subject','Run','ConditionLabel','Window','ROI'};
    [G,K] = findgroups(Ttrial(:,keys));
    meanAmp = splitapply(@(x) median(x,'omitnan'), Ttrial.MeanAmplitude, G);
    nTrials = splitapply(@(x) sum(isfinite(x)), Ttrial.MeanAmplitude, G);
    Rsubj = K;
    Rsubj.MedianMeanAmplitude = meanAmp;
    Rsubj.NTrials = nTrials;

    rows = {};
    runs = unique(Rsubj.Run, 'stable');

    for i = 1:height(coreEffects)
        win = coreEffects.Window{i};
        roi = coreEffects.ROI{i};

        for r = 1:numel(runs)
            run = runs{r};
            S = Rsubj(strcmp(Rsubj.Window,win) & strcmp(Rsubj.ROI,roi) & strcmp(Rsubj.Run,run), :);
            W = wideConditions(S, 'MedianMeanAmplitude');

            if height(W) < 8
                continue;
            end

            X = [W.color, W.orientation, W.conjunction];
            try
                [p,tbl] = friedman(X,1,'off');
                chi2 = tbl{2,5};
                kendallW = chi2/(height(W)*(3-1));
            catch
                p = NaN; kendallW = NaN;
            end

            meds = median(X,1,'omitnan');
            conds = {'color','orientation','conjunction'};
            [~,mx] = max(meds);

            rows(end+1,:) = {win, roi, run, height(W), ...
                meds(1), meds(2), meds(3), conds{mx}, p, kendallW, ...
                strcmp(conds{mx}, coreEffects.MaxCondition{i}), strjoin(W.Subject,'|')}; %#ok<AGROW>
        end
    end

    if isempty(rows)
        Trun = table();
        return;
    end

    Trun = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','Run','NSubjects','Median_color','Median_orientation','Median_conjunction', ...
        'MaxCondition','p_Friedman','KendallW','SameAsOverallMaxCondition','SubjectsUsed'});
    Trun.q_FDR = fdrBH(Trun.p_Friedman);
    Trun = sortrows(Trun, {'Window','ROI','Run'});
end

function Tcore = makeCoreRobustnessTable(coreEffects, Tdir, Tloo, Trun)
    rows = {};

    for i = 1:height(coreEffects)
        win = coreEffects.Window{i};
        roi = coreEffects.ROI{i};
        maxCond = coreEffects.MaxCondition{i};

        L = Tloo(strcmp(Tloo.Window,win) & strcmp(Tloo.ROI,roi), :);

        R = Trun(strcmp(Trun.Window,win) & strcmp(Trun.ROI,roi), :);
        nRuns = height(R);
        nRuns_p05 = sum(R.p_Friedman < 0.05, 'omitnan');
        nRuns_sameMax = sum(R.SameAsOverallMaxCondition == 1, 'omitnan');

        % Primary direction of interest: color > orientation and color > conjunction.
        Dco = Tdir(strcmp(Tdir.Window,win) & strcmp(Tdir.ROI,roi) & strcmp(Tdir.Contrast,'color_vs_orientation'), :);
        Dcc = Tdir(strcmp(Tdir.Window,win) & strcmp(Tdir.ROI,roi) & strcmp(Tdir.Contrast,'color_vs_conjunction'), :);
        Dci = Tdir(strcmp(Tdir.Window,win) & strcmp(Tdir.ROI,roi) & strcmp(Tdir.Contrast,'conjunction_vs_orientation'), :);

        propColorOri = getProp(Dco, 'color_greater_than_orientation');
        propColorConj = getProp(Dcc, 'color_greater_than_conjunction');
        propConjOri = getProp(Dci, 'conjunction_greater_than_orientation');

        robustLOO = ~isempty(L) && L.Prop_LOO_p_lt_05 >= 0.80 && L.Prop_LOO_SameMaxCondition >= 0.80;
        robustRun = nRuns >= 2 && nRuns_p05 >= 2 && nRuns_sameMax >= 2;
        directionOK = false;

        if strcmp(maxCond,'color')
            directionOK = propColorOri >= 0.70 && propColorConj >= 0.70;
        elseif strcmp(maxCond,'conjunction')
            directionOK = propConjOri >= 0.70;
        end

        robustCore = coreEffects.q_FDR(i) < 0.05 && robustLOO && directionOK;

        rows(end+1,:) = {win, roi, coreEffects.NSubjects(i), coreEffects.p_Friedman(i), coreEffects.q_FDR(i), coreEffects.KendallW(i), maxCond, ...
            propColorOri, propColorConj, propConjOri, ...
            getVal(L,'LOO_MaxP'), getVal(L,'LOO_MedianP'), getVal(L,'Prop_LOO_p_lt_05'), getVal(L,'Prop_LOO_SameMaxCondition'), ...
            nRuns, nRuns_p05, nRuns_sameMax, robustLOO, robustRun, directionOK, robustCore}; %#ok<AGROW>
    end

    Tcore = cell2table(rows, 'VariableNames', ...
        {'Window','ROI','NSubjects','p_Friedman','q_FDR','KendallW','MaxCondition', ...
        'Prop_color_gt_orientation','Prop_color_gt_conjunction','Prop_conjunction_gt_orientation', ...
        'LOO_MaxP','LOO_MedianP','Prop_LOO_p_lt_05','Prop_LOO_SameMaxCondition', ...
        'NRunsTested','NRuns_p_lt_05','NRuns_SameMaxCondition', ...
        'Robust_LOO','Robust_RunLevel','Robust_Direction','RobustCore'});
    Tcore = sortrows(Tcore, {'q_FDR','p_Friedman'}, {'ascend','ascend'});
end

function prop = getProp(T, expectedDirection)
    if isempty(T)
        prop = NaN;
        return;
    end
    if strcmp(T.MedianDirection{1}, expectedDirection)
        prop = T.PropSubjectsInMedianDirection(1);
    else
        % If median direction is opposite, compute as 1 - reported proportion
        prop = 1 - T.PropSubjectsInMedianDirection(1);
    end
end

function v = getVal(T, col)
    if isempty(T)
        v = NaN;
    else
        v = T.(col)(1);
    end
end

function Tsummary = makeSummary(Tcore, Tdir, Tloo, Trun)
    rows = {};
    rows(end+1,:) = {'Core effects tested', height(Tcore)}; %#ok<AGROW>
    rows(end+1,:) = {'Core effects q<0.05', sum(Tcore.q_FDR < 0.05,'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'RobustCore effects', sum(Tcore.RobustCore == 1,'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Robust LOO effects', sum(Tcore.Robust_LOO == 1,'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Robust direction effects', sum(Tcore.Robust_Direction == 1,'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Run-level tested rows', height(Trun)}; %#ok<AGROW>
    rows(end+1,:) = {'Run-level p<0.05 rows', sum(Trun.p_Friedman < 0.05,'omitnan')}; %#ok<AGROW>
    rows(end+1,:) = {'Pairwise direction rows', height(Tdir)}; %#ok<AGROW>
    rows(end+1,:) = {'LOO rows', height(Tloo)}; %#ok<AGROW>
    Tsummary = cell2table(rows, 'VariableNames', {'Metric','Value'});
end

function txt = makeInterpretation(Tcore, Tsummary)
    nRobust = sum(Tcore.RobustCore == 1,'omitnan');
    nTotal = height(Tcore);
    nColorMax = sum(strcmp(Tcore.MaxCondition,'color'));
    nConjMax = sum(strcmp(Tcore.MaxCondition,'conjunction'));

    top = Tcore(1:min(5,height(Tcore)), :);
    lines = {};
    lines{end+1} = 'STEP09D interpretation';
    lines{end+1} = '';
    lines{end+1} = sprintf('RobustCore effects: %d / %d', nRobust, nTotal);
    lines{end+1} = sprintf('Overall MaxCondition distribution: color=%d, conjunction=%d', nColorMax, nConjMax);
    lines{end+1} = '';
    lines{end+1} = 'Top effects:';
    for i = 1:height(top)
        lines{end+1} = sprintf('%s | %s | q=%.6g | W=%.3f | max=%s | RobustCore=%d', ...
            top.Window{i}, top.ROI{i}, top.q_FDR(i), top.KendallW(i), top.MaxCondition{i}, top.RobustCore(i));
    end
    lines{end+1} = '';
    lines{end+1} = 'Recommended reporting:';
    if nRobust >= 8
        lines{end+1} = ['The maintenance slow-wave condition effect appears robust across subject-level direction checks and leave-one-subject-out tests. ' ...
            'Report it as a robust sustained maintenance-period amplitude effect, while avoiding mechanistic overclaiming.'];
    elseif nRobust >= 3
        lines{end+1} = ['The strongest maintenance slow-wave effects are robust, but not all significant omnibus effects meet robustness criteria. ' ...
            'Report the strongest posterior/parietal effects as primary and the broader ROI effects as supportive.'];
    else
        lines{end+1} = ['The omnibus slow-wave effects are statistically significant but robustness is limited. ' ...
            'Report them cautiously and emphasize the ERP component-window results more strongly.'];
    end

    txt = strjoin(lines, newline);
end

function W = wideConditions(S, valueCol)
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
                ok = false;
                break;
            end
            vals(c) = median(Sc.(valueCol), 'omitnan');
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

function q = fdrBH(p)
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

function writeText(fpath, txt)
    fid = fopen(fpath, 'w');
    if fid < 0
        error('Could not write file: %s', fpath);
    end
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end

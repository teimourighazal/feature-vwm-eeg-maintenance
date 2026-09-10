%% STEP01B_RESTING_QC_FINAL.m
% Final strict QC for resting-state outputs.
%
% Purpose:
%   Reads STEP01_Resting_Outputs and creates a strict paired subset.
%   Inclusion rule:
%       1) Subject has both EO and EC successfully analyzed.
%       2) EO and EC each have at least cfg.minChannels channels after non-EEG removal.
%
% Input:
%   STEP01_Resting_Outputs under the selected Article2 Analysis folder.
%
% Output:
%   STEP01B_Resting_QC_Final under the selected Article2 Analysis folder.

clear; clc;

cfg = struct();

cfg.analysisRoot = uigetdir(pwd, 'Select the Article2 Analysis folder');
if isequal(cfg.analysisRoot, 0)
    error('Article2 Analysis folder was not selected.');
end

cfg.inDir  = fullfile(cfg.analysisRoot, 'STEP01_Resting_Outputs');
cfg.outDir = fullfile(cfg.analysisRoot, 'STEP01B_Resting_QC_Final');
cfg.minChannels = 16;

if ~exist(cfg.outDir, 'dir'); mkdir(cfg.outDir); end

summaryFile = fullfile(cfg.inDir, 'Rest_SubjectCondition_Summary.csv');
reactFile   = fullfile(cfg.inDir, 'Rest_EC_EO_AlphaReactivity.csv');
logFile     = fullfile(cfg.inDir, 'Rest_Loading_QC_Log.csv');
channelFile = fullfile(cfg.inDir, 'Rest_ChannelBandPower_Long.csv');

Tsummary = readtable(summaryFile);
Treact   = readtable(reactFile);
Tlog     = readtable(logFile);
Tchannel = readtable(channelFile);

subjects = unique(Tlog.Subject, 'stable');

qcRows = {};
strictSubjects = {};

for i = 1:numel(subjects)
    subj = subjects{i};

    Lsub = Tlog(strcmp(Tlog.Subject, subj), :);
    Seo = Tsummary(strcmp(Tsummary.Subject, subj) & strcmp(Tsummary.Condition, 'EO'), :);
    Sec = Tsummary(strcmp(Tsummary.Subject, subj) & strcmp(Tsummary.Condition, 'EC'), :);

    hasEO = height(Seo) > 0;
    hasEC = height(Sec) > 0;

    eoStatus = '';
    ecStatus = '';
    eoCh = NaN;
    ecCh = NaN;
    eoCleanRatio = NaN;
    ecCleanRatio = NaN;

    Leo = Lsub(strcmp(Lsub.Condition, 'EO'), :);
    Lec = Lsub(strcmp(Lsub.Condition, 'EC'), :);

    if height(Leo) > 0; eoStatus = Leo.Status{1}; end
    if height(Lec) > 0; ecStatus = Lec.Status{1}; end

    if hasEO
        eoCh = Seo.NChannels(1);
        eoCleanRatio = Seo.CleanEpochRatio(1);
    end
    if hasEC
        ecCh = Sec.NChannels(1);
        ecCleanRatio = Sec.CleanEpochRatio(1);
    end

    include = false;
    reason = '';

    if ~hasEO || ~hasEC
        reason = 'Missing successful EO or EC analysis.';
    elseif eoCh < cfg.minChannels || ecCh < cfg.minChannels
        reason = sprintf('Low channel count after loading/removal: EO=%g, EC=%g.', eoCh, ecCh);
    else
        include = true;
        reason = 'Included: paired EO/EC and sufficient channel count.';
        strictSubjects{end+1,1} = subj; %#ok<SAGROW>
    end

    qcRows(end+1,:) = {subj, hasEO, hasEC, eoStatus, ecStatus, eoCh, ecCh, eoCleanRatio, ecCleanRatio, include, reason}; %#ok<SAGROW>
end

Tqc = cell2table(qcRows, 'VariableNames', ...
    {'Subject','HasEO','HasEC','EO_Status','EC_Status','EO_NChannels','EC_NChannels', ...
     'EO_CleanEpochRatio','EC_CleanEpochRatio','StrictInclude','Reason'});

writetable(Tqc, fullfile(cfg.outDir, 'Resting_QC_FinalInclusion.csv'));

% Strict filtered tables
keepSummary = ismember(Tsummary.Subject, strictSubjects);
TsummaryStrict = Tsummary(keepSummary, :);
writetable(TsummaryStrict, fullfile(cfg.outDir, 'Rest_SubjectCondition_Summary_STRICT.csv'));

keepReact = ismember(Treact.Subject, strictSubjects);
TreactStrict = Treact(keepReact, :);
writetable(TreactStrict, fullfile(cfg.outDir, 'Rest_EC_EO_AlphaReactivity_STRICT.csv'));

keepChannel = ismember(Tchannel.Subject, strictSubjects);
TchannelStrict = Tchannel(keepChannel, :);
writetable(TchannelStrict, fullfile(cfg.outDir, 'Rest_ChannelBandPower_Long_STRICT.csv'));

% Strict paired stats
statsRows = {};
if height(TreactStrict) >= 3
    [p,h,txt] = safeT(TreactStrict.EC_PosteriorAlphaAbs, TreactStrict.EO_PosteriorAlphaAbs);
    statsRows(end+1,:) = {'PosteriorAlphaAbs','paired_ttest',p,h,txt}; %#ok<SAGROW>

    [p,h,txt] = safeW(TreactStrict.EC_PosteriorAlphaAbs, TreactStrict.EO_PosteriorAlphaAbs);
    statsRows(end+1,:) = {'PosteriorAlphaAbs','signrank',p,h,txt}; %#ok<SAGROW>

    [p,h,txt] = safeT(TreactStrict.EC_PosteriorAlphaRel, TreactStrict.EO_PosteriorAlphaRel);
    statsRows(end+1,:) = {'PosteriorAlphaRel','paired_ttest',p,h,txt}; %#ok<SAGROW>

    [p,h,txt] = safeW(TreactStrict.EC_PosteriorAlphaRel, TreactStrict.EO_PosteriorAlphaRel);
    statsRows(end+1,:) = {'PosteriorAlphaRel','signrank',p,h,txt}; %#ok<SAGROW>
end

TstatsStrict = cell2table(statsRows, 'VariableNames', {'Feature','Test','pValue','h','StatsText'});
writetable(TstatsStrict, fullfile(cfg.outDir, 'Rest_EC_vs_EO_BasicStats_STRICT.csv'));

% Descriptive paired summary
descRows = {};
features = {'PosteriorAlphaAbs','PosteriorAlphaRel','AlphaPeakHz'};

% abs
descRows(end+1,:) = describePair('PosteriorAlphaAbs', TreactStrict.EO_PosteriorAlphaAbs, TreactStrict.EC_PosteriorAlphaAbs); %#ok<SAGROW>
descRows(end+1,:) = describePair('PosteriorAlphaRel', TreactStrict.EO_PosteriorAlphaRel, TreactStrict.EC_PosteriorAlphaRel); %#ok<SAGROW>
descRows(end+1,:) = describePair('AlphaPeakHz', TreactStrict.EO_AlphaPeakHz, TreactStrict.EC_AlphaPeakHz); %#ok<SAGROW>

Tdesc = cell2table(descRows, 'VariableNames', ...
    {'Feature','N','EO_Mean','EO_Median','EC_Mean','EC_Median','ECminusEO_Mean','ECminusEO_Median','N_ECgreaterEO'});
writetable(Tdesc, fullfile(cfg.outDir, 'Rest_PairedDescriptives_STRICT.csv'));

save(fullfile(cfg.outDir, 'STEP01B_Resting_QC_Final_Workspace.mat'), ...
     'cfg','Tqc','TsummaryStrict','TreactStrict','TchannelStrict','TstatsStrict','Tdesc');

fprintf('\n================ STEP01B FINAL QC ================\n');
fprintf('Subjects in log: %d\n', numel(subjects));
fprintf('Strict included paired subjects: %d\n', numel(strictSubjects));
fprintf('Excluded subjects: %d\n', height(Tqc) - numel(strictSubjects));
fprintf('Outputs saved in:\n%s\n', cfg.outDir);

%% Functions
function [p,h,txt] = safeT(x,y)
    ok = isfinite(x) & isfinite(y);
    x=x(ok); y=y(ok);
    if numel(x)<3
        p=NaN; h=NaN; txt='not enough paired observations'; return;
    end
    try
        [h,p,~,st] = ttest(x,y);
        txt = sprintf('t(%d)=%.4f', st.df, st.tstat);
    catch ME
        p=NaN; h=NaN; txt=['ttest failed: ' ME.message];
    end
end

function [p,h,txt] = safeW(x,y)
    ok = isfinite(x) & isfinite(y);
    x=x(ok); y=y(ok);
    if numel(x)<3
        p=NaN; h=NaN; txt='not enough paired observations'; return;
    end
    try
        p = signrank(x,y);
        h = p < 0.05;
        txt = 'Wilcoxon signed-rank test';
    catch ME
        p=NaN; h=NaN; txt=['signrank failed: ' ME.message];
    end
end

function row = describePair(name, eo, ec)
    ok = isfinite(eo) & isfinite(ec);
    eo = eo(ok);
    ec = ec(ok);
    d = ec - eo;
    row = {name, numel(eo), mean(eo,'omitnan'), median(eo,'omitnan'), ...
           mean(ec,'omitnan'), median(ec,'omitnan'), ...
           mean(d,'omitnan'), median(d,'omitnan'), sum(d > 0)};
end

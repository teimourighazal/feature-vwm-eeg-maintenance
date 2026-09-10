%% STEP14_SAMPLE_STABILITY_LOO_N22.m
% Participant-level stability analysis for Article2.
%
% PURPOSE
% -------
% Evaluate whether the principal maintenance-centered and focused spectral
% findings are unusually dependent on any single participant.
%
% Analyses:
%   A) Leave-one-participant-out (LOO) re-analysis of the full primary
%      channel and ROI condition-effect families.
%   B) LOO re-analysis of the three focused maintenance indices.
%
% IMPORTANT
% ---------
% This script uses ICA-cleaned STEP12B subject-level outputs only.
% Trials/runs are NOT treated as independent participants.
%
% Outputs:
%   STEP14_SAMPLE_STABILITY_LOO_N22
%
% MATLAB: R2021a+

clear; clc;

%% -------------------------- PATHS ----------------------------------
% The STEP12B output folder is not distributed with this repository.
% Select the local folder containing the required STEP12B subject-level
% output CSV files. STEP14 output will be written beside that folder.

step12bDir = uigetdir(pwd, ...
    'Select STEP12B_ICA_RECOVERY_COMPLETE66_N22 output folder');

if isequal(step12bDir,0)
    error('STEP12B output folder was not selected.');
end

resultRoot = fileparts(step12bDir);
outDir = fullfile(resultRoot,'STEP14_SAMPLE_STABILITY_LOO_N22');
if exist(outDir,'dir')~=7; mkdir(outDir); end

diaryFile=fullfile(outDir,'STEP14_RunReport.txt');
if exist(diaryFile,'file')==2; delete(diaryFile); end
diary(diaryFile);
cleanupDiary=onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('\n============================================================\n');
fprintf('STEP14: PARTICIPANT-LEVEL LEAVE-ONE-OUT STABILITY\n');
fprintf('Source: %s\n',step12bDir);
fprintf('Output: %s\n',outDir);
fprintf('============================================================\n');

%% -------------------------- INPUTS ---------------------------------
fChan = fullfile(step12bDir, ...
    'STEP12BICA_PRIMARY_Article1Matched_SubjectChannelFeatures_N22.csv');
fROI = fullfile(step12bDir, ...
    'STEP12BICA_PRIMARY_Article1Matched_SubjectROIFeatures_N22.csv');
fFocus = fullfile(step12bDir, ...
    'STEP12BICA_PRIMARY_Article1Matched_FocusedIndices_SubjectConditionPhase.csv');
fCoverage = fullfile(step12bDir, ...
    'STEP12BICA_ICA_RunCoverage_Summary.csv');

mustExist({fChan,fROI,fFocus,fCoverage});

Cov=readtable(fCoverage);
if ~logical(Cov.CompleteCoverage(1)) || Cov.NBothBranchesSuccessful(1)~=66
    error('STEP12B complete 66/66 coverage is required.');
end

C=normalizeFeatureSource(readtable(fChan),"channel");
R=normalizeFeatureSource(readtable(fROI),"roi");
F=normalizeFocused(readtable(fFocus));

subjects=unique(C.Subject,'stable');
if numel(subjects)~=22
    warning('Expected 22 subjects, found %d.',numel(subjects));
end

fprintf('Subjects: %d\n',numel(subjects));

%% ---------------- A) BROAD LOO PRIMARY RE-ANALYSIS ----------------
looRows=cell(0,13);

for i=1:numel(subjects)
    leftOut=subjects(i);
    fprintf('Broad LOO %d/%d: leaving out %s\n',i,numel(subjects),leftOut);

    Cloo=C(C.Subject~=leftOut,:);
    Rloo=R(R.Subject~=leftOut,:);

    Oc=conditionOmnibusOnly(Cloo);
    Or=conditionOmnibusOnly(Rloo);

    Sc=phaseCounts(Oc);
    Sr=phaseCounts(Or);

    [cs,cm,cr]=aggregateCounts(Sc);
    [rs,rm,rr]=aggregateCounts(Sr);

    looRows(end+1,:)={leftOut, ...
        cs,cm,cr,cm>cs&&cm>cr,cm/max(cs+cm+cr,1), ...
        rs,rm,rr,rm>rs&&rm>rr,rm/max(rs+rm+rr,1), ...
        height(Oc),height(Or)}; %#ok<AGROW>
end

Tloo=cell2table(looRows,'VariableNames', ...
    {'LeftOutSubject', ...
     'Channel_StimulusFDR','Channel_MaintenanceFDR','Channel_RetrievalFDR', ...
     'Channel_MaintenanceHasMost','Channel_MaintenanceShare', ...
     'ROI_StimulusFDR','ROI_MaintenanceFDR','ROI_RetrievalFDR', ...
     'ROI_MaintenanceHasMost','ROI_MaintenanceShare', ...
     'Channel_NTests','ROI_NTests'});

writetable(Tloo,fullfile(outDir,'STEP14_BroadPrimary_LOO_22Folds.csv'));

TbroadSummary=table( ...
    numel(subjects), ...
    sum(Tloo.Channel_MaintenanceHasMost), ...
    sum(Tloo.ROI_MaintenanceHasMost), ...
    min(Tloo.Channel_MaintenanceShare), ...
    median(Tloo.Channel_MaintenanceShare), ...
    max(Tloo.Channel_MaintenanceShare), ...
    min(Tloo.ROI_MaintenanceShare), ...
    median(Tloo.ROI_MaintenanceShare), ...
    max(Tloo.ROI_MaintenanceShare), ...
    'VariableNames',{'NFolds', ...
    'Channel_MaintenanceMost_NFolds','ROI_MaintenanceMost_NFolds', ...
    'Channel_MaintenanceShare_Min','Channel_MaintenanceShare_Median', ...
    'Channel_MaintenanceShare_Max','ROI_MaintenanceShare_Min', ...
    'ROI_MaintenanceShare_Median','ROI_MaintenanceShare_Max'});

writetable(TbroadSummary,fullfile(outDir, ...
    'STEP14_BroadPrimary_LOO_Summary.csv'));

%% ---------------- B) FOCUSED INDEX LOO -----------------------------
focusNames=["posterior_alpha_log_power", ...
            "posterior_gamma_relative_power", ...
            "posterior_minus_anterior_alpha_relative_power"];

focusRows=cell(0,9);

for i=1:numel(subjects)
    leftOut=subjects(i);
    Floo=F(F.Subject~=leftOut & F.PhaseLabel=="maintenance",:);

    [O,P]=focusedStats(Floo);

    for j=1:numel(focusNames)
        fn=focusNames(j);
        o=O(O.FeatureName==fn,:);
        if isempty(o); continue; end

        if fn=="posterior_alpha_log_power"
            expectedMax="color";
        elseif fn=="posterior_gamma_relative_power"
            expectedMax="orientation";
        else
            expectedMax="none";
        end

        if expectedMax=="none"
            expectedDirection=true;
        else
            expectedDirection=(o.MaxCondition(1)==expectedMax);
        end

        focusRows(end+1,:)={leftOut,fn,o.p_Friedman(1),o.q_FDR(1), ...
            o.KendallW(1),o.MaxCondition(1), ...
            o.q_FDR(1)<0.05,expectedDirection,height(P)}; %#ok<AGROW>
    end
end

Tfloo=cell2table(focusRows,'VariableNames', ...
    {'LeftOutSubject','FeatureName','p_Friedman','q_FDR', ...
     'KendallW','MaxCondition','OmnibusSignificantFDR', ...
     'ExpectedDirection','NPairwiseRows'});

writetable(Tfloo,fullfile(outDir,'STEP14_FocusedIndices_LOO_AllFolds.csv'));

summaryRows=cell(0,10);
for j=1:numel(focusNames)
    fn=focusNames(j);
    X=Tfloo(Tfloo.FeatureName==fn,:);
    if fn=="posterior_minus_anterior_alpha_relative_power"
        robustCriterion=~X.OmnibusSignificantFDR;
        criterionName="remains_nonsignificant";
    else
        robustCriterion=X.OmnibusSignificantFDR & X.ExpectedDirection;
        criterionName="significant_and_expected_max";
    end

    summaryRows(end+1,:)={fn,height(X),sum(X.OmnibusSignificantFDR), ...
        sum(~X.OmnibusSignificantFDR),sum(X.ExpectedDirection), ...
        sum(robustCriterion),min(X.KendallW),median(X.KendallW), ...
        max(X.KendallW),criterionName}; %#ok<AGROW>
end

TfSummary=cell2table(summaryRows,'VariableNames', ...
    {'FeatureName','NFolds','NSignificantFDR','NNonsignificantFDR', ...
     'NExpectedDirection','NMeetsRobustCriterion', ...
     'KendallW_Min','KendallW_Median','KendallW_Max','RobustCriterion'});

writetable(TfSummary,fullfile(outDir,'STEP14_FocusedIndices_LOO_Summary.csv'));

%% ----------------------- FINAL DECISION ----------------------------
broadChannelRobust = all(Tloo.Channel_MaintenanceHasMost);
broadROIRobust = all(Tloo.ROI_MaintenanceHasMost);

alphaRow=TfSummary(TfSummary.FeatureName=="posterior_alpha_log_power",:);
gammaRow=TfSummary(TfSummary.FeatureName=="posterior_gamma_relative_power",:);
gradRow=TfSummary(TfSummary.FeatureName== ...
    "posterior_minus_anterior_alpha_relative_power",:);

alphaLOORobust = ~isempty(alphaRow) && ...
    alphaRow.NMeetsRobustCriterion==alphaRow.NFolds;
gammaLOORobust = ~isempty(gammaRow) && ...
    gammaRow.NMeetsRobustCriterion==gammaRow.NFolds;
gradientLOORobust = ~isempty(gradRow) && ...
    gradRow.NMeetsRobustCriterion==gradRow.NFolds;

SampleStabilitySupported = broadChannelRobust && broadROIRobust && ...
    alphaLOORobust && gammaLOORobust && gradientLOORobust;

if SampleStabilitySupported
    Decision="stable_at_observed_sample";
    RecommendedWording = ...
        "Participant-level leave-one-out analyses showed that the principal maintenance-centered and focused spectral findings were not driven by any single participant.";
else
    Decision="partial_stability";
    RecommendedWording = ...
        "Participant-level leave-one-out robustness was mixed; the modest sample size remains an important limitation and unstable findings should be interpreted cautiously.";
end

Tdecision=table(Decision,SampleStabilitySupported, ...
    broadChannelRobust,broadROIRobust,alphaLOORobust,gammaLOORobust, ...
    gradientLOORobust,RecommendedWording, ...
    'VariableNames',{'Decision','SampleStabilitySupported', ...
    'BroadChannel_LOO_AllFoldsMaintenanceCentered', ...
    'BroadROI_LOO_AllFoldsMaintenanceCentered', ...
    'PosteriorAlpha_LOO_AllFoldsRobust', ...
    'PosteriorGamma_LOO_AllFoldsRobust', ...
    'PosteriorAnteriorAlpha_LOO_AllFoldsNonsignificant', ...
    'RecommendedWording'});

writetable(Tdecision,fullfile(outDir,'STEP14_FINAL_DECISION.csv'));

fprintf('\n================ BROAD LOO SUMMARY ==================\n');
disp(TbroadSummary);
fprintf('\n============== FOCUSED LOO SUMMARY ==================\n');
disp(TfSummary);
fprintf('\n================ FINAL DECISION ======================\n');
disp(Tdecision);

fprintf('\nSTEP14 completed.\n');

%% ========================== HELPERS ================================

function mustExist(files)
for i=1:numel(files)
    if exist(files{i},'file')~=2
        error('Required file not found:\n%s',files{i});
    end
end
end

function T = normalizeFeatureSource(T,level)
strvars={'Subject','ConditionLabel','PhaseLabel','Band','ChannelName','ROI'};
for i=1:numel(strvars)
    v=strvars{i};
    if ismember(v,T.Properties.VariableNames)
        T.(v)=lower(strtrim(string(T.(v))));
    end
end

rows=cell(0,8);
if level=="channel"
    featureVar='ChannelName';
else
    featureVar='ROI';
end

for i=1:height(T)
    rows(end+1,:)={T.Subject(i),T.ConditionLabel(i),T.PhaseLabel(i), ...
        T.Band(i),string(T.(featureVar)(i)),"log_absolute_power", ...
        T.LogAbsPower(i),string(level)}; %#ok<AGROW>
    rows(end+1,:)={T.Subject(i),T.ConditionLabel(i),T.PhaseLabel(i), ...
        T.Band(i),string(T.(featureVar)(i)),"relative_power", ...
        T.RelPower(i),string(level)}; %#ok<AGROW>
end

T=cell2table(rows,'VariableNames', ...
    {'Subject','ConditionLabel','PhaseLabel','Band','FeatureName', ...
     'EEGMetric','FeatureValue','AnalysisLevel'});
end

function T = normalizeFocused(T)
vars={'Subject','ConditionLabel','PhaseLabel','Band','FeatureName', ...
    'EEGMetric','AnalysisLevel'};
for i=1:numel(vars)
    if ismember(vars{i},T.Properties.VariableNames)
        T.(vars{i})=lower(strtrim(string(T.(vars{i}))));
    end
end
end

function O = conditionOmnibusOnly(T)
metrics=unique(T.EEGMetric,'stable');
phases=["stimulus","maintenance","retrieval"];
bands=unique(T.Band,'stable');
features=unique(T.FeatureName,'stable');

rows=cell(0,9);

for im=1:numel(metrics)
for ip=1:numel(phases)
for ib=1:numel(bands)
for jf=1:numel(features)
    S=T(T.EEGMetric==metrics(im)&T.PhaseLabel==phases(ip)& ...
        T.Band==bands(ib)&T.FeatureName==features(jf),:);

    [X,~]=wideConditions(S);
    ok=all(isfinite(X),2);
    X=X(ok,:);
    if size(X,1)<10; continue; end

    [p,W]=friedmanPW(X);
    med=median(X,1,'omitnan');
    [~,mx]=max(med);
    conds=["color","orientation","conjunction"];

    rows(end+1,:)={metrics(im),phases(ip),bands(ib),features(jf), ...
        size(X,1),p,W,conds(mx),NaN}; %#ok<AGROW>
end
end
end
end

O=cell2table(rows,'VariableNames', ...
    {'EEGMetric','PhaseLabel','Band','FeatureName','NSubjects', ...
     'p_Friedman','KendallW','MaxCondition','q_FDR'});

for im=1:numel(metrics)
    idx=O.EEGMetric==metrics(im);
    O.q_FDR(idx)=bhFDR(O.p_Friedman(idx));
end
end

function S = phaseCounts(O)
metrics=unique(O.EEGMetric,'stable');
phases=["stimulus","maintenance","retrieval"];
rows=cell(0,4);

for im=1:numel(metrics)
    for ip=1:numel(phases)
        X=O(O.EEGMetric==metrics(im)&O.PhaseLabel==phases(ip),:);
        rows(end+1,:)={metrics(im),phases(ip),height(X), ...
            sum(X.q_FDR<0.05,'omitnan')}; %#ok<AGROW>
    end
end

S=cell2table(rows,'VariableNames', ...
    {'EEGMetric','PhaseLabel','NTests','NSignificantFDR'});
end

function [s,m,r] = aggregateCounts(S)
s=sum(S.NSignificantFDR(S.PhaseLabel=="stimulus"));
m=sum(S.NSignificantFDR(S.PhaseLabel=="maintenance"));
r=sum(S.NSignificantFDR(S.PhaseLabel=="retrieval"));
end

function [O,P] = focusedStats(F)
features=unique(F.FeatureName,'stable');
conds=["color","orientation","conjunction"];
pairs={1,2,"color_vs_orientation"; ...
       1,3,"color_vs_conjunction"; ...
       2,3,"orientation_vs_conjunction"};

orows=cell(0,7);
prows=cell(0,5);

for j=1:numel(features)
    S=F(F.FeatureName==features(j),:);
    [X,~]=wideConditions(S);
    ok=all(isfinite(X),2);
    X=X(ok,:);
    if size(X,1)<10; continue; end

    [p,W]=friedmanPW(X);
    med=median(X,1,'omitnan');
    [~,mx]=max(med);

    orows(end+1,:)={features(j),size(X,1),p,NaN,W,conds(mx), ...
        strjoin(string(find(ok)),'|')}; %#ok<AGROW>

    for k=1:3
        ia=pairs{k,1}; ib=pairs{k,2};
        try
            pp=signrank(X(:,ia),X(:,ib));
        catch
            pp=NaN;
        end
        prows(end+1,:)={features(j),string(pairs{k,3}),pp,NaN, ...
            median(X(:,ia)-X(:,ib),'omitnan')}; %#ok<AGROW>
    end
end

O=cell2table(orows,'VariableNames', ...
    {'FeatureName','NSubjects','p_Friedman','q_FDR','KendallW', ...
     'MaxCondition','SubjectsUsed'});
O.q_FDR=bhFDR(O.p_Friedman);

P=cell2table(prows,'VariableNames', ...
    {'FeatureName','Contrast','p_Signrank','q_FDR','MedianDifference'});
P.q_FDR=bhFDR(P.p_Signrank);
end

function [X,subjects] = wideConditions(S)
conds=["color","orientation","conjunction"];
subjects=unique(S.Subject,'stable');
X=nan(numel(subjects),3);

for i=1:numel(subjects)
    for c=1:3
        v=S.FeatureValue(S.Subject==subjects(i)&S.ConditionLabel==conds(c));
        if any(isfinite(v))
            X(i,c)=median(v,'omitnan');
        end
    end
end
end

function [p,W] = friedmanPW(X)
p=NaN;W=NaN;
try
    [p,tbl]=friedman(X,1,'off');
    chi2=tbl{2,5};
    W=chi2/(size(X,1)*(size(X,2)-1));
catch
    n=size(X,1); k=size(X,2);
    R=zeros(size(X));
    for i=1:n
        R(i,:)=tiedrank(X(i,:));
    end
    Rj=sum(R,1);
    chi2=12/(n*k*(k+1))*sum(Rj.^2)-3*n*(k+1);
    W=chi2/(n*(k-1));
    p=1-chi2cdf(chi2,k-1);
end
end

function q = bhFDR(p)
q=nan(size(p));
good=find(isfinite(p));
if isempty(good); return; end
pv=p(good);
[ps,ord]=sort(pv);
m=numel(ps);
qs=ps.*m./(1:m)';
for i=m-1:-1:1
    qs(i)=min(qs(i),qs(i+1));
end
qs=min(qs,1);
tmp=nan(m,1);
tmp(ord)=qs;
q(good)=tmp;
end

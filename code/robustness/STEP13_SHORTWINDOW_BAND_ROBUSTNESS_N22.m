%% STEP13_SHORTWINDOW_BAND_ROBUSTNESS_N22.m
% Article2 reviewer-gap analysis #1
%
% PURPOSE
% -------
% Address the concern that 0-0.6 s spectral windows provide limited cycle
% support for the lowest frequencies (especially delta/theta).
%
% IMPORTANT
% ---------
% This script DOES NOT rerun ICA and DOES NOT change the primary analysis.
% It uses the completed STEP12B ICA-cleaned outputs (66/66 task runs).
%
% The robustness branch asks:
%   1) Does the maintenance-centered primary result remain when delta/theta
%      are excluded and only alpha/beta/gamma are considered?
%   2) Does the equal-0.6-s direct-phase sensitivity still show a
%      maintenance-centered distribution among alpha/beta/gamma features?
%
% To keep this sensitivity analysis conservative, significance is defined
% using the q-values already obtained in STEP12B after correction across
% the FULL original five-band family. We do NOT relax the FDR family after
% removing delta/theta.
%
% Outputs are written to:
%   Result/STEP13_SHORTWINDOW_BAND_ROBUSTNESS_N22
%
% MATLAB: designed for R2021a+

clear; clc;

%% -------------------------- PATHS ----------------------------------
resultRoot = '/Users/ghazal/Desktop/Article2/Analysis/Result';
step12bDir = fullfile(resultRoot,'STEP12B_ICA_RECOVERY_COMPLETE66_N22');

if exist(step12bDir,'dir')~=7
    step12bDir = uigetdir(pwd, ...
        'Select STEP12B_ICA_RECOVERY_COMPLETE66_N22 output folder');
    if isequal(step12bDir,0)
        error('STEP12B output folder was not selected.');
    end
end

outDir = fullfile(resultRoot,'STEP13_SHORTWINDOW_BAND_ROBUSTNESS_N22');
if exist(outDir,'dir')~=7; mkdir(outDir); end

diaryFile = fullfile(outDir,'STEP13_RunReport.txt');
if exist(diaryFile,'file')==2; delete(diaryFile); end
diary(diaryFile);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('\n============================================================\n');
fprintf('STEP13: SHORT-WINDOW / BAND-RESTRICTED ROBUSTNESS\n');
fprintf('Source: %s\n',step12bDir);
fprintf('Output: %s\n',outDir);
fprintf('============================================================\n');

%% -------------------------- INPUTS ---------------------------------
fChanPrimary = fullfile(step12bDir, ...
    'STEP12BICA_PRIMARY_Article1Matched_Channel_Omnibus.csv');
fROIPrimary = fullfile(step12bDir, ...
    'STEP12BICA_PRIMARY_Article1Matched_ROI_Omnibus.csv');
fChanDirect = fullfile(step12bDir, ...
    'STEP12BICA_EQUAL0600_Channel_DirectPhase_Omnibus.csv');
fROIDirect = fullfile(step12bDir, ...
    'STEP12BICA_EQUAL0600_ROI_DirectPhase_Omnibus.csv');
fCoverage = fullfile(step12bDir, ...
    'STEP12BICA_ICA_RunCoverage_Summary.csv');

mustExist({fChanPrimary,fROIPrimary,fChanDirect,fROIDirect,fCoverage});

Cov = readtable(fCoverage);
if ~logical(Cov.CompleteCoverage(1)) || Cov.NBothBranchesSuccessful(1)~=66
    error('STEP12B complete 66/66 ICA coverage is required before STEP13.');
end

C = normalizeTable(readtable(fChanPrimary));
R = normalizeTable(readtable(fROIPrimary));
CD = normalizeTable(readtable(fChanDirect));
RD = normalizeTable(readtable(fROIDirect));

%% -------------------- WINDOW / CYCLE SUMMARY -----------------------
% Cycle counts are descriptive. A 0.6-s window contains f*0.6 cycles.
bandNames = ["delta";"theta";"alpha";"beta";"gamma"];
fLow  = [1;4;8;13;30];
fHigh = [4;8;13;30;45];
fMid  = (fLow+fHigh)/2;
winSec = 0.6;

Tcycles = table(bandNames,fLow,fHigh,fMid, ...
    fLow*winSec,fMid*winSec,fHigh*winSec, ...
    'VariableNames',{'Band','LowHz','HighHz','MidHz', ...
    'CyclesAtLowEdge_0p6s','CyclesAtBandMid_0p6s', ...
    'CyclesAtHighEdge_0p6s'});

Tcycles.BandGroup = repmat("low_frequency_caution",height(Tcycles),1);
Tcycles.BandGroup(ismember(Tcycles.Band,["alpha","beta","gamma"])) = ...
    "higher_frequency_robustness";

writetable(Tcycles,fullfile(outDir,'STEP13_BandCycleSupport_0p6s.csv'));

%% ------------------ PRIMARY BAND-RESTRICTED COUNTS -----------------
% Use STEP12B q-values from the complete five-band correction family.
highBands = ["alpha","beta","gamma"];
lowBands = ["delta","theta"];

TpHigh = [primaryBandSummary(C,"channel",highBands,"alpha_beta_gamma"); ...
          primaryBandSummary(R,"roi",highBands,"alpha_beta_gamma")];
TpLow  = [primaryBandSummary(C,"channel",lowBands,"delta_theta"); ...
          primaryBandSummary(R,"roi",lowBands,"delta_theta")];

Tprimary = [TpHigh;TpLow];
writetable(Tprimary,fullfile(outDir, ...
    'STEP13_Primary_BandRestricted_PhaseCounts.csv'));

TprimaryDecision = primaryMaintenanceDecision(Tprimary);
writetable(TprimaryDecision,fullfile(outDir, ...
    'STEP13_Primary_MaintenanceCentered_Decision.csv'));

%% ------------- EQUAL-0.6 DIRECT-PHASE BAND CHECK ------------------
TdirectHigh = [directBandSummary(CD,"channel",highBands,"alpha_beta_gamma"); ...
               directBandSummary(RD,"roi",highBands,"alpha_beta_gamma")];
TdirectLow = [directBandSummary(CD,"channel",lowBands,"delta_theta"); ...
              directBandSummary(RD,"roi",lowBands,"delta_theta")];

Tdirect = [TdirectHigh;TdirectLow];
writetable(Tdirect,fullfile(outDir, ...
    'STEP13_Equal0600_DirectPhase_BandRestricted_Summary.csv'));

%% ----------------------- FINAL DECISION ----------------------------
% Main question: is the primary maintenance concentration still present
% without delta/theta at BOTH channel and ROI levels?
H = TprimaryDecision(TprimaryDecision.BandGroup=="alpha_beta_gamma",:);

channelOK = any(H.AnalysisLevel=="channel" & H.MaintenanceHasMostEffects);
roiOK = any(H.AnalysisLevel=="roi" & H.MaintenanceHasMostEffects);

% Additional descriptive direct-phase evidence.
DH = Tdirect(Tdirect.BandGroup=="alpha_beta_gamma",:);
channelDirectPhaseEffects = sum(DH.NPhaseFDRSignificant(DH.AnalysisLevel=="channel"));
roiDirectPhaseEffects = sum(DH.NPhaseFDRSignificant(DH.AnalysisLevel=="roi"));
channelMaintDominant = sum(DH.NMaintenanceDominantAmongAll(DH.AnalysisLevel=="channel"));
roiMaintDominant = sum(DH.NMaintenanceDominantAmongAll(DH.AnalysisLevel=="roi"));

ShortWindowConcernAddressed = channelOK && roiOK;

if ShortWindowConcernAddressed
    Decision = "robust_without_delta_theta";
    RecommendedWording = ...
        "The maintenance-centered spectral distribution persisted in a conservative alpha/beta/gamma-only sensitivity analysis.";
else
    Decision = "requires_caution";
    RecommendedWording = ...
        "The maintenance-centered distribution was not fully preserved after excluding delta/theta and should be interpreted cautiously.";
end

Tdecision = table(Decision,ShortWindowConcernAddressed,channelOK,roiOK, ...
    channelDirectPhaseEffects,roiDirectPhaseEffects, ...
    channelMaintDominant,roiMaintDominant,RecommendedWording, ...
    'VariableNames',{'Decision','ShortWindowConcernAddressed', ...
    'PrimaryChannelMaintenanceCentered_HighBands', ...
    'PrimaryROIMaintenanceCentered_HighBands', ...
    'DirectPhase_Channel_NFDR_HighBands', ...
    'DirectPhase_ROI_NFDR_HighBands', ...
    'DirectPhase_Channel_NMaintenanceDominant_HighBands', ...
    'DirectPhase_ROI_NMaintenanceDominant_HighBands', ...
    'RecommendedWording'});

writetable(Tdecision,fullfile(outDir,'STEP13_FINAL_DECISION.csv'));

fprintf('\n================ BAND CYCLE SUPPORT =================\n');
disp(Tcycles);
fprintf('\n=========== PRIMARY BAND-RESTRICTED COUNTS ==========\n');
disp(Tprimary);
fprintf('\n============= PRIMARY DECISION SUMMARY ==============\n');
disp(TprimaryDecision);
fprintf('\n============ DIRECT-PHASE BAND SUMMARY ==============\n');
disp(Tdirect);
fprintf('\n================ FINAL DECISION ======================\n');
disp(Tdecision);

fprintf('\nSTEP13 completed.\n');

%% ========================== HELPERS ================================

function mustExist(files)
for i=1:numel(files)
    if exist(files{i},'file')~=2
        error('Required file not found:\n%s',files{i});
    end
end
end

function T = normalizeTable(T)
vars=T.Properties.VariableNames;
stringCandidates={'AnalysisLevel','EEGMetric','PhaseLabel','Band', ...
    'FeatureName','MaxCondition'};
for i=1:numel(stringCandidates)
    v=stringCandidates{i};
    if ismember(v,vars)
        T.(v)=lower(strtrim(string(T.(v))));
    end
end
end

function S = primaryBandSummary(O,level,bands,groupName)
phases=["stimulus","maintenance","retrieval"];
metrics=unique(O.EEGMetric,'stable');
rows=cell(0,8);

for im=1:numel(metrics)
    for ip=1:numel(phases)
        idx=O.EEGMetric==metrics(im) & O.PhaseLabel==phases(ip) & ...
            ismember(O.Band,bands);
        X=O(idx,:);
        n=height(X);
        if n==0
            nsig=0; medW=NaN;
        else
            nsig=sum(X.q_FDR_metricFamily<0.05,'omitnan');
            medW=median(X.KendallW,'omitnan');
        end
        rows(end+1,:)={string(level),metrics(im),string(groupName), ...
            phases(ip),n,nsig,nsig/max(n,1),medW}; %#ok<AGROW>
    end
end

S=cell2table(rows,'VariableNames', ...
    {'AnalysisLevel','EEGMetric','BandGroup','PhaseLabel', ...
     'NTests','NSignificantFDR','ProportionSignificant','MedianKendallW'});
end

function D = primaryMaintenanceDecision(T)
levels=unique(T.AnalysisLevel,'stable');
groups=unique(T.BandGroup,'stable');
rows=cell(0,8);

for il=1:numel(levels)
    for ig=1:numel(groups)
        X=T(T.AnalysisLevel==levels(il)&T.BandGroup==groups(ig),:);
        stim=sum(X.NSignificantFDR(X.PhaseLabel=="stimulus"));
        maint=sum(X.NSignificantFDR(X.PhaseLabel=="maintenance"));
        retr=sum(X.NSignificantFDR(X.PhaseLabel=="retrieval"));
        total=stim+maint+retr;
        prop=maint/max(total,1);
        ok=maint>stim && maint>retr;
        rows(end+1,:)={levels(il),groups(ig),stim,maint,retr,total,prop,ok}; %#ok<AGROW>
    end
end

D=cell2table(rows,'VariableNames', ...
    {'AnalysisLevel','BandGroup','StimulusSignificant', ...
     'MaintenanceSignificant','RetrievalSignificant', ...
     'TotalSignificant','MaintenanceShare','MaintenanceHasMostEffects'});
end

function S = directBandSummary(O,level,bands,groupName)
metrics=unique(O.EEGMetric,'stable');
rows=cell(0,9);

for im=1:numel(metrics)
    X=O(O.EEGMetric==metrics(im)&ismember(O.Band,bands),:);
    n=height(X);
    if n==0
        nPhase=0;nDom=0;nDomSig=0;nStrong=0;
    else
        sig=X.q_PhaseFDR<0.05;
        nPhase=sum(sig,'omitnan');
        nDom=sum(X.MaintenanceDominant,'omitnan');
        nDomSig=sum(sig & X.MaintenanceDominant,'omitnan');
        nStrong=sum(X.StrongSupport,'omitnan');
    end
    rows(end+1,:)={string(level),metrics(im),string(groupName), ...
        n,nPhase,nDom,nDomSig,nStrong,nPhase/max(n,1)}; %#ok<AGROW>
end

S=cell2table(rows,'VariableNames', ...
    {'AnalysisLevel','EEGMetric','BandGroup','NTests', ...
     'NPhaseFDRSignificant','NMaintenanceDominantAmongAll', ...
     'NMaintenanceDominantAmongFDR','NStrongSupport', ...
     'ProportionPhaseFDR'});
end

%% STEP11_FINAL_RESULTS_MANUSCRIPT_AUDIT_V2_ARTICLE1_WINDOWS.m
% STEP11 V2: Final consistency audit after STEP10 Article1-matched re-analysis.
%
% NO new inferential statistics are performed.
%
% Authoritative spectral definitions:
%   PRIMARY:
%     stimulus / early encoding = 0-0.6 s
%     maintenance               = 0-1.0 s
%     retrieval                 = 0-0.6 s
%     pre-event baseline is NOT included in spectral feature calculation
%
%   DIRECT-PHASE SENSITIVITY:
%     stimulus / maintenance / retrieval = identical 0-0.6 s post-onset
%
% Main inputs:
%   STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22 outputs
%   STEP09D maintenance slow-wave robustness outputs
%   STEP08D2 correct-vs-incorrect ERP outputs
%   current Article2*.docx
%
% Main outputs:
%   STEP11V2_FileInventory.csv
%   STEP11V2_FinalAudit.csv
%   STEP11V2_FREEZE_DECISION.txt
%   STEP11V2_ManuscriptWindowHits.txt
%
% MATLAB R2021a compatible.

clear; clc; close all;

%% ============================= CONFIG =============================
cfg = struct();
cfg.rootDir = '/Users/ghazal/Desktop/Article2/Analysis';
cfg.articleRoot = '/Users/ghazal/Desktop/Article2';
cfg.resultRoot = fullfile(cfg.rootDir,'Result');
cfg.outDir = fullfile(cfg.resultRoot, ...
    'STEP11V2_FinalAudit_Article1MatchedWindows');

if ~exist(cfg.outDir,'dir'); mkdir(cfg.outDir); end

cfg.expectedN = 22;
cfg.expectedRuns = 66;
cfg.expectedChannels = 64;
cfg.expectedCorrectERP_N = 14;

cfg.primary.stimulus = 600;
cfg.primary.maintenance = 1000;
cfg.primary.retrieval = 600;
cfg.sensitivityMs = 600;

cfg.slowwave.NCore = 24;
cfg.slowwave.NCoreQ05 = 24;
cfg.slowwave.NRobust = 22;
cfg.slowwave.NRunRows = 72;
cfg.slowwave.NRunP05 = 60;
cfg.slowwave.NRunSameMax = 66;

reportFile = fullfile(cfg.outDir,'STEP11V2_FinalAuditReport.txt');
if exist(reportFile,'file'); delete(reportFile); end
diary(reportFile);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('============================================================\n');
fprintf('STEP11 V2 FINAL AUDIT - ARTICLE1 MATCHED WINDOWS\n');
fprintf('Generated: %s\n',datestr(now));
fprintf('============================================================\n');

%% ========================== LOCATE FILES ==========================
F = struct();

F.manuscript = findNewestRecursive(cfg.articleRoot,'Article2*.docx');

step10Root = fullfile(cfg.resultRoot,'STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22');

F.primaryChan = firstExisting({ ...
    fullfile(step10Root,'STEP10A_Article1Matched_SubjectChannelFeatures_N22.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10A_Article1Matched_SubjectChannelFeatures_N22.csv')});

F.primaryROI = firstExisting({ ...
    fullfile(step10Root,'STEP10A_Article1Matched_SubjectROIFeatures_N22.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10A_Article1Matched_SubjectROIFeatures_N22.csv')});

F.sensChan = firstExisting({ ...
    fullfile(step10Root,'STEP10S_Equal0600_SubjectChannelFeatures_N22.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10S_Equal0600_SubjectChannelFeatures_N22.csv')});

F.sensROI = firstExisting({ ...
    fullfile(step10Root,'STEP10S_Equal0600_SubjectROIFeatures_N22.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10S_Equal0600_SubjectROIFeatures_N22.csv')});

F.directSummary = firstExisting({ ...
    fullfile(step10Root,'STEP10E_DirectPhase_SupportSummary.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10E_DirectPhase_SupportSummary.csv')});

F.decision = firstExisting({ ...
    fullfile(step10Root,'STEP10E_ManuscriptDecisionSummary.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10E_ManuscriptDecisionSummary.csv')});

F.coverage = firstExisting({ ...
    fullfile(step10Root,'STEP10Q_TrialPhaseCoverage_BeforeExtraction.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10Q_TrialPhaseCoverage_BeforeExtraction.csv')});

F.primaryRetention = firstExisting({ ...
    fullfile(step10Root,'STEP10Q_Primary_PhaseRetentionSummary.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10Q_Primary_PhaseRetentionSummary.csv')});

F.sensRetention = firstExisting({ ...
    fullfile(step10Root,'STEP10Q_Sensitivity_PhaseRetentionSummary.csv'), ...
    findNewestRecursive(cfg.resultRoot,'STEP10Q_Sensitivity_PhaseRetentionSummary.csv')});

F.step09Summary = findNewestRecursive(cfg.resultRoot,'STEP09D_RobustnessSummary.csv');
F.step09Run = findNewestRecursive(cfg.resultRoot,'STEP09D_RunLevelReplication.csv');

F.step08Summary = findNewestRecursive(cfg.resultRoot,'STEP08D2_ERP_AnalysisSummary.csv');

%% ========================= FILE INVENTORY =========================
names = fieldnames(F);
rows = cell(0,4);
for i=1:numel(names)
    p = F.(names{i});
    if isempty(p)
        rows(end+1,:)={names{i},false,'','NOT FOUND'}; %#ok<AGROW>
    else
        d=dir(p);
        if isempty(d); stamp=''; else; stamp=datestr(d.datenum); end
        rows(end+1,:)={names{i},true,p,stamp}; %#ok<AGROW>
    end
end
Tinv=cell2table(rows,'VariableNames',{'Source','Found','Path','Modified'});
writetable(Tinv,fullfile(cfg.outDir,'STEP11V2_FileInventory.csv'));

%% ============================ READ ================================
P = safeRead(F.primaryChan);
S = safeRead(F.sensChan);
D = safeRead(F.directSummary);
Mdec = safeRead(F.decision);
R09 = safeRead(F.step09Summary);
Run09 = safeRead(F.step09Run);
R08 = safeRead(F.step08Summary);

audit = cell(0,7);

%% ====================== CRITICAL FILE CHECKS ======================
critical = { ...
    'Primary channel table',F.primaryChan; ...
    'Sensitivity channel table',F.sensChan; ...
    'Direct phase support summary',F.directSummary; ...
    'Manuscript decision summary',F.decision; ...
    'STEP09D robustness summary',F.step09Summary; ...
    'STEP08D2 summary',F.step08Summary};

for i=1:size(critical,1)
    audit=addAudit(audit,'Files',critical{i,1}, ...
        passFail(~isempty(critical{i,2})),'present', ...
        displayPath(critical{i,2}),critical{i,2}, ...
        'Required for final automated audit.');
end

%% ====================== PRIMARY WINDOW AUDIT ======================
if ~isempty(P)
    subjCol=firstColumn(P,{'Subject','SubjectID','Participant'});
    chanCol=firstColumn(P,{'ChannelName','Channel','Electrode'});
    phaseCol=firstColumn(P,{'PhaseLabel','Phase'});
    startCol=firstColumn(P,{'WindowStartMs'});
    endCol=firstColumn(P,{'WindowEndMs','EpochDurationMs'});

    if ~isempty(subjCol)
        n=numel(unique(string(P.(subjCol))));
        audit=addAudit(audit,'Sample','Primary N',passFail(n==cfg.expectedN), ...
            num2str(cfg.expectedN),num2str(n),F.primaryChan,'Unique subjects.');
    end

    if ~isempty(chanCol)
        n=numel(unique(string(P.(chanCol))));
        audit=addAudit(audit,'Sample','Primary channel count', ...
            passFail(n==cfg.expectedChannels),num2str(cfg.expectedChannels), ...
            num2str(n),F.primaryChan,'Unique EEG channels.');
    end

    if isempty(phaseCol) || isempty(endCol)
        audit=addAudit(audit,'Windows','Primary phase windows','FAIL', ...
            '600/1000/600 ms','required columns missing',F.primaryChan, ...
            'Need PhaseLabel and WindowEndMs/EpochDurationMs.');
    else
        phases={'stimulus','maintenance','retrieval'};
        expv=[cfg.primary.stimulus cfg.primary.maintenance cfg.primary.retrieval];

        for i=1:3
            idx=strcmpi(strtrim(string(P.(phaseCol))),phases{i});
            obs=unique(toNumeric(P.(endCol)(idx)));
            obs=obs(isfinite(obs));
            ok=numel(obs)==1 && abs(obs-expv(i))<1e-9;

            audit=addAudit(audit,'Windows', ...
                ['Primary ' phases{i} ' duration'],passFail(ok), ...
                sprintf('%g ms',expv(i)),vectorText(obs),F.primaryChan, ...
                'Must match revised Article1.');
        end
    end

    if ~isempty(startCol)
        x=unique(toNumeric(P.(startCol)));
        x=x(isfinite(x));
        ok=numel(x)==1 && abs(x)<1e-9;
        audit=addAudit(audit,'Windows','Primary spectral window starts at event onset', ...
            passFail(ok),'0 ms',vectorText(x),F.primaryChan, ...
            'Pre-event baseline must not be included in feature calculation.');
    else
        audit=addAudit(audit,'Windows','Primary spectral window starts at event onset', ...
            'REVIEW','0 ms','WindowStartMs missing',F.primaryChan, ...
            'Verify manually.');
    end
else
    audit=addAudit(audit,'Windows','Primary phase windows','FAIL', ...
        'stimulus 600; maintenance 1000; retrieval 600','primary table missing', ...
        F.primaryChan,'Run STEP10 final first.');
end

%% ==================== SENSITIVITY WINDOW AUDIT ====================
if ~isempty(S)
    phaseCol=firstColumn(S,{'PhaseLabel','Phase'});
    startCol=firstColumn(S,{'WindowStartMs'});
    endCol=firstColumn(S,{'WindowEndMs','EpochDurationMs'});

    if ~isempty(endCol)
        x=unique(toNumeric(S.(endCol)));
        x=x(isfinite(x));
        ok=numel(x)==1 && abs(x-cfg.sensitivityMs)<1e-9;
        audit=addAudit(audit,'Windows','Equal direct-phase sensitivity duration', ...
            passFail(ok),sprintf('%g ms for all phases',cfg.sensitivityMs), ...
            vectorText(x),F.sensChan, ...
            'Only this branch is used for direct spectral phase-magnitude comparison.');
    end

    if ~isempty(startCol)
        x=unique(toNumeric(S.(startCol)));
        x=x(isfinite(x));
        ok=numel(x)==1 && abs(x)<1e-9;
        audit=addAudit(audit,'Windows','Sensitivity starts at event onset', ...
            passFail(ok),'0 ms',vectorText(x),F.sensChan, ...
            'No pre-event baseline included.');
    end

    if ~isempty(phaseCol)
        nPh=numel(unique(lower(strtrim(string(S.(phaseCol))))));
        audit=addAudit(audit,'Windows','Sensitivity includes all three phases', ...
            passFail(nPh==3),'3',num2str(nPh),F.sensChan,'stimulus/maintenance/retrieval.');
    end
else
    audit=addAudit(audit,'Windows','Equal direct-phase sensitivity duration', ...
        'FAIL','600 ms for all phases','sensitivity table missing',F.sensChan, ...
        'Run STEP10 final first.');
end

%% ===================== DIRECT SUMMARY SCHEMA ======================
if ~isempty(D)
    levels={'channel','roi','focused_index','erp'};
    expTests=[640 80 3 10];

    for i=1:numel(levels)
        idx=findTextRow(D,'AnalysisLevel',levels{i});
        if isempty(idx)
            audit=addAudit(audit,'STEP10', ...
                ['Direct summary ' levels{i}],'REVIEW', ...
                sprintf('%d tests',expTests(i)),'level missing',F.directSummary, ...
                'Check whether source family was available.');
        else
            n=getNumericCell(D,idx(1),'NTests');
            audit=addAudit(audit,'STEP10', ...
                ['Direct summary ' levels{i}],passFail(n==expTests(i)), ...
                sprintf('%d tests',expTests(i)),num2str(n),F.directSummary, ...
                'Number of prespecified feature combinations.');
        end
    end
end

if ~isempty(Mdec)
    decision=getTextCell(Mdec,1,'Decision');
    wording=getTextCell(Mdec,1,'RecommendedWording');

    audit=addAudit(audit,'STEP10','Manuscript decision available', ...
        passFail(~isempty(decision)),'nonempty',decision,F.decision,wording);
end

%% =========================== STEP09D ===============================
if ~isempty(R09)
    metrics={ ...
        'Core effects tested',cfg.slowwave.NCore; ...
        'Core effects q<0.05',cfg.slowwave.NCoreQ05; ...
        'RobustCore effects',cfg.slowwave.NRobust; ...
        'Run-level tested rows',cfg.slowwave.NRunRows; ...
        'Run-level p<0.05 rows',cfg.slowwave.NRunP05};

    for i=1:size(metrics,1)
        obs=summaryMetric(R09,metrics{i,1});
        audit=addAudit(audit,'STEP09D',metrics{i,1}, ...
            passFail(obs==metrics{i,2}),num2str(metrics{i,2}), ...
            num2str(obs),F.step09Summary,'Must remain consistent with slow-wave Results.');
    end
end

if ~isempty(Run09)
    c=firstColumn(Run09,{'SameAsOverallMaxCondition'});
    if ~isempty(c)
        x=toNumeric(Run09.(c));
        obs=sum(x==1);
        audit=addAudit(audit,'STEP09D','Run summaries same max condition', ...
            passFail(obs==cfg.slowwave.NRunSameMax), ...
            num2str(cfg.slowwave.NRunSameMax),num2str(obs),F.step09Run, ...
            'Current validated slow-wave robustness result.');
    end
end

%% =========================== STEP08D2 ==============================
if ~isempty(R08)
    n=summaryMetric(R08,'Subjects in merged data');
    q1=summaryMetric(R08,'Primary q<0.05 effects');
    q2=summaryMetric(R08,'Secondary q<0.05 effects');
    q3=summaryMetric(R08,'Accuracy-correlation q<0.05 effects');

    audit=addAudit(audit,'STEP08D2','Correct/incorrect subset N', ...
        passFail(n==cfg.expectedCorrectERP_N),num2str(cfg.expectedCorrectERP_N), ...
        num2str(n),F.step08Summary,'Complete three-condition correctness subset.');

    audit=addAudit(audit,'STEP08D2','Primary FDR effects',passFail(q1==0), ...
        '0',num2str(q1),F.step08Summary,'Negative corrected result expected.');
    audit=addAudit(audit,'STEP08D2','Secondary FDR effects',passFail(q2==0), ...
        '0',num2str(q2),F.step08Summary,'Negative corrected result expected.');
    audit=addAudit(audit,'STEP08D2','Accuracy-correlation FDR effects', ...
        passFail(q3==0),'0',num2str(q3),F.step08Summary, ...
        'Negative corrected result expected.');
end

%% ====================== MANUSCRIPT WORDING ========================
articleText='';
articleNorm='';

if ~isempty(F.manuscript)
    try
        articleText=readDocxText(F.manuscript);
        articleNorm=normalizeText(articleText);

        % Accept the exact final manuscript wording as well as equivalent
        % scientifically identical formulations.
        primaryOK = ...
            containsAny(articleNorm,{ ...
            '0-0.6 s from stimulus onset', ...
            'stimulus/early-encoding period (0-0.6 s', ...
            'stimulus presentation, 0-0.6 s', ...
            'stimulus presentation: 0-0.6 s', ...
            '0-0.6 s for stimulus/early encoding'}) && ...
            containsAny(articleNorm,{ ...
            '0-1.0 s from maintenance onset', ...
            'maintenance, 0-1.0 s', ...
            'maintenance interval, 0-1.0 s', ...
            'maintenance: 0-1.0 s', ...
            '0-1.0 s for maintenance'}) && ...
            containsAny(articleNorm,{ ...
            '0-0.6 s from retrieval onset', ...
            'retrieval, 0-0.6 s', ...
            'retrieval period, 0-0.6 s', ...
            'retrieval: 0-0.6 s', ...
            '0-0.6 s for retrieval'});

        audit=addAudit(audit,'Manuscript','Primary spectral windows match Article1', ...
            passFail(primaryOK),'0-0.6 / 0-1.0 / 0-0.6 s', ...
            yesNo(primaryOK),F.manuscript, ...
            'Final manuscript must use revised Article1 task-period definitions.');

        stale500 = containsAny(articleNorm,{ ...
            'identical 0-500-ms post-onset intervals across stimulus', ...
            'identical 0-500 ms post-onset intervals across stimulus', ...
            'identical 0-500-ms intervals across stimulus', ...
            'identical 0-500 ms intervals across stimulus'});

        audit=addAudit(audit,'Manuscript','No stale 0-500-ms equal-window claim', ...
            passFail(~stale500),'none',yesNo(stale500),F.manuscript, ...
            'Old sensitivity wording must be removed.');

        sensOK = containsAny(articleNorm,{ ...
            'identical 0-0.6-s post-onset intervals', ...
            'identical 0-0.6 s post-onset intervals', ...
            'identical 0-600-ms post-onset intervals', ...
            'identical 0-600 ms post-onset intervals'});

        audit=addAudit(audit,'Manuscript','Equal 0-0.6-s sensitivity stated', ...
            passFail(sensOK),'0-0.6 s post-onset for all phases',yesNo(sensOK), ...
            F.manuscript,'Used only for direct phase sensitivity.');

        noBaselineOK = containsAny(articleNorm,{ ...
            'pre-event baseline interval was not included in feature calculation', ...
            'pre-event baseline was not included in feature calculation', ...
            'pre-event baseline interval was not included in spectral feature calculation'});

        audit=addAudit(audit,'Manuscript','No-baseline spectral wording present', ...
            passFail(noBaselineOK),'explicit no-baseline statement',yesNo(noBaselineOK), ...
            F.manuscript,'Should match revised Article1 methods.');

        if ~isempty(Mdec)
            decision=getTextCell(Mdec,1,'Decision');
            if strcmpi(decision,'predominantly_observed')
                ok=contains(articleNorm,'predominantly observed during maintenance');
                audit=addAudit(audit,'Manuscript','STEP10 recommended wording', ...
                    passFail(ok),'predominantly observed during maintenance', ...
                    yesNo(ok),F.manuscript,'Follow final STEP10 decision.');
            elseif strcmpi(decision,'phase_specific_only')
                ok=contains(articleNorm,'phase-specific');
                audit=addAudit(audit,'Manuscript','STEP10 recommended wording', ...
                    passFail(ok),'phase-specific wording',yesNo(ok), ...
                    F.manuscript,'Follow final STEP10 decision.');
            elseif strcmpi(decision,'strongest_supported')
                ok=contains(articleNorm,'strongest during maintenance');
                audit=addAudit(audit,'Manuscript','STEP10 recommended wording', ...
                    passFail(ok),'strongest during maintenance',yesNo(ok), ...
                    F.manuscript,'Use only if final sensitivity truly supports it.');
            end
        end

        hits=extractKeywordContexts(articleText, ...
            {'0–500','0-500','0–0.6','0-0.6','0–1.0','0-1.0', ...
             'equal-window','equal window','baseline'},220);
        writeLines(fullfile(cfg.outDir,'STEP11V2_ManuscriptWindowHits.txt'),hits);

    catch ME
        audit=addAudit(audit,'Manuscript','DOCX text extraction','FAIL', ...
            'readable DOCX',ME.message,F.manuscript,'Cannot audit wording.');
    end
else
    audit=addAudit(audit,'Manuscript','Current Article2 DOCX','REVIEW', ...
        'present','not found','','Place current manuscript under Article2 root.');
end

%% ========================== FINAL TABLE ============================
Taudit=cell2table(audit,'VariableNames', ...
    {'Category','Check','Status','Expected','Observed','Source','Note'});

statusOrder=categorical(string(Taudit.Status), ...
    {'FAIL','REVIEW','PASS','INFO'},'Ordinal',true);
Taudit.StatusOrder=statusOrder;
Taudit=sortrows(Taudit,{'StatusOrder','Category','Check'});
Taudit.StatusOrder=[];

writetable(Taudit,fullfile(cfg.outDir,'STEP11V2_FinalAudit.csv'));

nFail=sum(strcmpi(string(Taudit.Status),'FAIL'));
nReview=sum(strcmpi(string(Taudit.Status),'REVIEW'));
nPass=sum(strcmpi(string(Taudit.Status),'PASS'));

if nFail>0
    decision='DO_NOT_FREEZE';
    reason=sprintf('%d FAIL row(s) remain.',nFail);
elseif nReview>0
    decision='CONDITIONAL_FREEZE_AFTER_REVIEW';
    reason=sprintf('No FAIL rows, but %d REVIEW row(s) remain.',nReview);
else
    decision='FREEZE_APPROVED';
    reason='All configured checks passed.';
end

txt=sprintf([ ...
    'STEP11 V2 FREEZE DECISION\n\n' ...
    'Decision: %s\nPASS: %d\nFAIL: %d\nREVIEW: %d\n\n%s\n'], ...
    decision,nPass,nFail,nReview,reason);

writeText(fullfile(cfg.outDir,'STEP11V2_FREEZE_DECISION.txt'),txt);

fprintf('\n================ STEP11 V2 SUMMARY ================\n');
fprintf('PASS: %d | FAIL: %d | REVIEW: %d\n',nPass,nFail,nReview);
fprintf('Decision: %s\n',decision);

if nFail>0
    disp(Taudit(strcmpi(string(Taudit.Status),'FAIL'), ...
        {'Category','Check','Expected','Observed','Source'}));
end

fprintf('Outputs saved in:\n%s\n',cfg.outDir);
diary off;

%% ========================= LOCAL FUNCTIONS ========================

function rows=addAudit(rows,cat,check,status,expected,observed,source,note)
if isempty(source); source=''; end
rows(end+1,:)={char(string(cat)),char(string(check)),char(string(status)), ...
    char(string(expected)),char(string(observed)),char(string(source)), ...
    char(string(note))}; %#ok<AGROW>
end

function s=passFail(tf)
if islogical(tf)&&isscalar(tf)&&tf; s='PASS'; else; s='FAIL'; end
end

function s=yesNo(tf)
if tf; s='YES'; else; s='NO'; end
end

function s=displayPath(p)
if isempty(p); s='NOT FOUND'; else; s=p; end
end

function p=firstExisting(C)
p='';
for i=1:numel(C)
    if ~isempty(C{i}) && exist(C{i},'file')==2
        p=C{i}; return;
    end
end
end

function p=findNewestRecursive(rootDir,pattern)
p='';
if isempty(rootDir)||exist(rootDir,'dir')~=7; return; end
try
    D=dir(fullfile(rootDir,'**',pattern));
catch
    D=recursiveDirFallback(rootDir,pattern);
end
D=D(~[D.isdir]);
if isempty(D); return; end
[~,i]=max([D.datenum]);
p=fullfile(D(i).folder,D(i).name);
end

function D=recursiveDirFallback(rootDir,pattern)
D=dir(fullfile(rootDir,pattern));
d=dir(rootDir);
for i=1:numel(d)
    if d(i).isdir && ~strcmp(d(i).name,'.') && ~strcmp(d(i).name,'..')
        D=[D;recursiveDirFallback(fullfile(rootDir,d(i).name),pattern)]; %#ok<AGROW>
    end
end
end

function T=safeRead(p)
T=table();
if isempty(p)||exist(p,'file')~=2; return; end
try
    T=readtable(p,'VariableNamingRule','preserve');
catch
    try
        T=readtable(p);
    catch
        T=table();
    end
end
end

function c=firstColumn(T,candidates)
c='';
if isempty(T); return; end
v=T.Properties.VariableNames;
for i=1:numel(candidates)
    j=find(strcmpi(v,candidates{i}),1);
    if ~isempty(j); c=v{j}; return; end
end
end

function x=toNumeric(v)
if isnumeric(v)||islogical(v)
    x=double(v);
else
    x=str2double(string(v));
end
end

function s=vectorText(x)
if isempty(x)
    s='[]';
else
    s=strtrim(sprintf('%.15g ',x(:)));
end
end

function idx=findTextRow(T,col,target)
idx=[];
c=firstColumn(T,{col});
if isempty(c); return; end
idx=find(lower(strtrim(string(T.(c))))==lower(strtrim(string(target))));
end

function v=getNumericCell(T,row,col)
v=NaN;
c=firstColumn(T,{col});
if isempty(c)||isempty(T)||row<1||row>height(T); return; end
x=T.(c);
if isnumeric(x)||islogical(x)
    v=double(x(row));
else
    v=str2double(string(x(row)));
end
end

function s=getTextCell(T,row,col)
s='';
c=firstColumn(T,{col});
if isempty(c)||isempty(T)||row<1||row>height(T); return; end
try
    sv=string(T.(c)(row));
    if ismissing(sv); s=''; else; s=char(sv); end
catch
    s='';
end
end

function v=summaryMetric(T,name)
v=NaN;
mc=firstColumn(T,{'Metric'});
vc=firstColumn(T,{'Value'});
if isempty(mc)||isempty(vc); return; end
idx=find(strcmpi(strtrim(string(T.(mc))),strtrim(string(name))),1);
if isempty(idx); return; end
v=toNumeric(T.(vc)(idx));
end

function txt=readDocxText(docxPath)
tmp=tempname;
mkdir(tmp);
cleaner=onCleanup(@() safeRemoveDir(tmp)); %#ok<NASGU>
unzip(docxPath,tmp);
xmlPath=fullfile(tmp,'word','document.xml');
if exist(xmlPath,'file')~=2
    error('word/document.xml not found.');
end
xml=fileread(xmlPath);
xml=regexprep(xml,'</w:p>','\n');
xml=regexprep(xml,'<w:tab[^>]*/>','\t');
xml=regexprep(xml,'<w:br[^>]*/>','\n');
xml=regexprep(xml,'<[^>]+>','');
xml=strrep(xml,'&amp;','&');
xml=strrep(xml,'&lt;','<');
xml=strrep(xml,'&gt;','>');
xml=strrep(xml,'&quot;','"');
xml=strrep(xml,'&apos;','''');
txt=xml;
end

function safeRemoveDir(p)
if exist(p,'dir')==7
    try; rmdir(p,'s'); catch; end
end
end

function s=normalizeText(txt)
s=lower(txt);
s=strrep(s,'–','-');
s=strrep(s,'—','-');
s=strrep(s,'−','-');
s=regexprep(s,'\s+',' ');
s=strtrim(s);
end

function tf=containsAny(txt,patterns)
tf=false;
for i=1:numel(patterns)
    if contains(txt,patterns{i}); tf=true; return; end
end
end

function lines=extractKeywordContexts(txt,keywords,halfWidth)
if nargin<3; halfWidth=180; end
lines={};
if isempty(txt); return; end
low=normalizeText(txt);

for k=1:numel(keywords)
    key=normalizeText(keywords{k});
    starts=strfind(low,key);
    for j=1:numel(starts)
        a=max(1,starts(j)-halfWidth);
        b=min(numel(txt),starts(j)+numel(key)+halfWidth);
        c=strtrim(regexprep(txt(a:b),'\s+',' '));
        lines{end+1}=sprintf('[%s] %s',keywords{k},c); %#ok<AGROW>
    end
end
if isempty(lines); lines={'No requested contexts found.'}; end
end

function writeLines(p,lines)
fid=fopen(p,'w');
if fid<0; return; end
cleaner=onCleanup(@() fclose(fid)); %#ok<NASGU>
for i=1:numel(lines); fprintf(fid,'%s\n\n',lines{i}); end
end

function writeText(p,txt)
fid=fopen(p,'w');
if fid<0; error('Could not write %s',p); end
cleaner=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',txt);
end

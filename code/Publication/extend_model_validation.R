# Paired refitting bootstrap and repeated CV for the existing eight specifications.
if (.Platform$OS.type == 'windows') invisible(Sys.setlocale('LC_CTYPE','Chinese_China.utf8'))
if (nzchar(Sys.getenv('MBR_R_LIB'))) .libPaths(c(Sys.getenv('MBR_R_LIB'), .libPaths()))
suppressPackageStartupMessages({library(readr);library(dplyr);library(jsonlite);library(pROC)})
args <- enc2utf8(commandArgs(TRUE))
stopifnot(length(args) %in% c(3L,6L), args[3] %in% c('pilot','run','summarize'))
root <- normalizePath(args[1],winslash='/',mustWork=TRUE)
out <- args[2]; mode <- args[3]
dir.create(out,recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(out,'private'),showWarnings=FALSE)
nh_input<-if(length(args)==6)args[4] else file.path(root,'外部数据/cleaned/01_NHANES/NHANES_2013_2014_outcome_bundle.csv.gz')
kn_input<-if(length(args)==6)args[5] else file.path(root,'外部数据/cleaned/02_KNHANES/KNHANES_2008_2011_ALL_DXA_merged.rds')
reference_input<-if(length(args)==6)args[6] else file.path(root,'工作记录/32_发表前科学修订_2026-09-26/results/component_cv_performance.csv')
old <- read_csv(reference_input,show_col_types=FALSE)
nh_columns <- c('SEQN','DEMO_H__RIDAGEYR','DEMO_H__RIAGENDR','BMX_H__BMXWT','DXX_H__DXDTOLE','DXX_H__DXDTOBMC','DXXFRX_H__DXXPRVFX','DXXFRX_H__DXXFRAX1','DXXFRX_H__DXXFRAX2','DXXFRX_H__DXXFRAX3','DXXFRX_H__DXXFRAX4','OSQ_H__OSQ060','OSQ_H__OSQ010A','OSQ_H__OSQ010C','DXXVFA_H__DXXVFAST')
nh0 <- read_csv(nh_input,col_select=all_of(nh_columns),show_col_types=FALSE)
stopifnot(nrow(problems(nh0))==0,!anyDuplicated(nh0$SEQN))
yn <- function(x) ifelse(x==1,1,ifelse(x==2,0,NA_real_))
nh <- nh0 %>% transmute(id=SEQN,age=DEMO_H__RIDAGEYR,male=yn(DEMO_H__RIAGENDR),weight=BMX_H__BMXWT,
 lean=DXX_H__DXDTOLE,bmc=DXX_H__DXDTOBMC,
 hip_frax=ifelse(DXXFRX_H__DXXPRVFX==1,DXXFRX_H__DXXFRAX1,ifelse(DXXFRX_H__DXXPRVFX==2,DXXFRX_H__DXXFRAX3,NA)),
 major_frax=ifelse(DXXFRX_H__DXXPRVFX==1,DXXFRX_H__DXXFRAX2,ifelse(DXXFRX_H__DXXPRVFX==2,DXXFRX_H__DXXFRAX4,NA)),
 prev_fracture=yn(DXXFRX_H__DXXPRVFX),self_report_osteoporosis=yn(OSQ_H__OSQ060),
 hip=yn(OSQ_H__OSQ010A),spine=yn(OSQ_H__OSQ010C),vfa=ifelse(DXXVFA_H__DXXVFAST==2,1,ifelse(DXXVFA_H__DXXVFAST==1,0,NA))) %>%
 mutate(direct_fx_any=ifelse(hip==1|spine==1|vfa==1,1,ifelse(hip==0 & spine==0 & vfa==0,0,NA)),eligible=age>=40 & age<=59 & lean>0 & bmc>0,mbr=lean/bmc)
kn0 <- readRDS(kn_input)
stopifnot(!anyDuplicated(paste(kn0$id,kn0$survey_year)))
kn <- kn0 %>% transmute(id=paste(id,survey_year,sep='_'),age=as.numeric(age),male=yn(sex),weight=as.numeric(he_wt),year=factor(survey_year),
 lean=as.numeric(dw_wbt_ln)-as.numeric(dw_wbt_bmc),bmc=as.numeric(dw_wbt_bmc),
 osteoporosis_any=ifelse(dx_ost==3,1,ifelse(dx_ost %in% c(1,2),0,NA)),low_bone_mass=ifelse(dx_ost %in% c(2,3),1,ifelse(dx_ost==1,0,NA)),
 osteoporosis_tf=ifelse(dx_ost_tf==3,1,ifelse(dx_ost_tf %in% c(1,2),0,NA)),
 osteoporosis_fn=ifelse(dx_ost_fn==3,1,ifelse(dx_ost_fn %in% c(1,2),0,NA)),
 osteoporosis_ls=ifelse(dx_ost_ls==3,1,ifelse(dx_ost_ls %in% c(1,2),0,NA))) %>%
 mutate(eligible=age>=50 & lean>0 & bmc>0,mbr=lean/bmc)
datasets <- list(NHANES=nh,KNHANES=kn)
outcomes <- list(NHANES=c('hip_frax','major_frax','prev_fracture','direct_fx_any','self_report_osteoporosis'),KNHANES=c('osteoporosis_any','low_bone_mass','osteoporosis_tf','osteoporosis_fn','osteoporosis_ls'))
models <- c('base','mbr','log_mbr','lean','bmc','components','log_components','flexible_components')
make_folds <- function(y,binary,seed) {
 set.seed(seed); f<-integer(length(y))
 if(binary) for(v in 0:1){i<-which(y==v);f[i]<-sample(rep(1:10,length.out=length(i)))} else f<-sample(rep(1:10,length.out=length(y)))
 f
}
performance <- function(y,p,w,binary) {
 if(!binary) return(1-sum(w*(y-p)^2)/sum(w*(y-sum(w*y)/sum(w))^2))
 # The original weighted midrank concordance, with multiplicities as weights.
 o<-order(p); s<-p[o]; yy<-y[o]; ww<-w[o]
 g<-cumsum(c(TRUE,diff(s)!=0)); a<-rowsum(cbind(ww*yy,ww*(1-yy)),g,reorder=FALSE)
 pos<-a[,1];neg<-a[,2];P<-sum(pos);N<-sum(neg)
 sum(pos*(cumsum(neg)-.5*neg))/(P*N)
}
cv_fit <- function(d,X,terms,folds,counts,binary,keep_predictions=FALSE) {
 y<-d$y; family<-if(binary) binomial() else gaussian()
 pred<-matrix(NA_real_,nrow(d),length(models),dimnames=list(NULL,models))
 warnings<-convergence_retry<-nonconverged<-integer(length(models));names(warnings)<-names(convergence_retry)<-names(nonconverged)<-models
 for(k in 1:10) {
  train<-which(folds!=k & counts>0);test<-which(folds==k)
  stopifnot(length(intersect(train,test))==0,all(counts[train]>0))
  # Bootstrap copies of a participant retain the original fold. Spline knots
  # are estimated from training copies only, never from held-out observations.
  expanded<-rep(train,counts[train])
  A<-splines::ns(d$log_lean[expanded],df=3);B<-splines::ns(d$log_bmc[expanded],df=3)
  spl<-cbind(predict(A,d$log_lean),predict(B,d$log_bmc))
  for(j in seq_along(models)) {
   mat<-if(models[j]=='flexible_components') cbind(X[,terms$base,drop=FALSE],spl) else X[,terms[[models[j]]],drop=FALSE]
   fit<-withCallingHandlers(glm.fit(mat[train,,drop=FALSE],y[train],weights=counts[train],family=family),warning=function(w){warnings[j]<<-warnings[j]+1L;invokeRestart('muffleWarning')})
   if(!fit$converged) {
    convergence_retry[j]<-convergence_retry[j]+1L
    fit<-withCallingHandlers(glm.fit(mat[train,,drop=FALSE],y[train],weights=counts[train],family=family,control=glm.control(maxit=100)),warning=function(w){warnings[j]<<-warnings[j]+1L;invokeRestart('muffleWarning')})
   }
   if(!fit$converged) nonconverged[j]<-nonconverged[j]+1L
   co<-fit$coefficients;co[is.na(co)]<-0
   pred[test,j]<-family$linkinv(as.numeric(mat[test,,drop=FALSE]%*%co))
  }
 }
 stopifnot(all(is.finite(pred)))
 values<-vapply(seq_along(models),function(j)performance(y,pred[,j],counts,binary),numeric(1));names(values)<-models
 list(values=values,predictions=if(keep_predictions)pred else NULL,warnings=warnings,retries=convergence_retry,nonconverged=nonconverged)
}
jobs<-list()
for(ds in names(outcomes)) for(oc in outcomes[[ds]]) {
 d<-datasets[[ds]];d$y<-d[[oc]];covars<-c('age','male','weight',if(ds=='KNHANES')'year')
 d<-as.data.frame(d[!is.na(d$eligible) & d$eligible & complete.cases(d[,c('y','lean','bmc',covars)]),])
 d$mbr_z<-as.numeric(scale(d$mbr));d$log_mbr<-log(d$mbr);d$log_lean<-log(d$lean);d$log_bmc<-log(d$bmc)
 fm<-list(base=covars,mbr=c(covars,'mbr_z'),log_mbr=c(covars,'log_mbr'),lean=c(covars,'lean'),bmc=c(covars,'bmc'),components=c(covars,'lean','bmc'),log_components=c(covars,'log_lean','log_bmc'),flexible_components=c(covars,'splines::ns(log_lean,df=3)','splines::ns(log_bmc,df=3)'))
 X<-model.matrix(reformulate(unique(c(covars,'mbr_z','log_mbr','lean','bmc','log_lean','log_bmc'))),d)
 terms<-lapply(fm,function(v){cn<-colnames(model.matrix(reformulate(v[!grepl('splines',v)]),d));match(cn,colnames(X))})
 binary<-!grepl('frax',oc);f<-make_folds(d$y,binary,20260804)
 ref<-old[old$dataset==ds & old$outcome==oc,]
 stopifnot(nrow(d)==unique(ref$n),!anyDuplicated(d$id))
 jobs[[length(jobs)+1]]<-list(dataset=ds,outcome=oc,d=d,X=X,terms=terms,formula_terms=fm,binary=binary,folds=f,reference=ref)
}
run_job <- function(job,index,R,B,folder) {
 ds<-job$dataset;oc<-job$outcome
 prefix<-file.path(folder,paste(ds,oc,sep='_'))
 if(file.exists(paste0(prefix,'_complete.rds'))) return(readRDS(paste0(prefix,'_complete.rds')))
 d<-job$d;n<-nrow(d);start<-proc.time()[3]
 original<-cv_fit(d,job$X,job$terms,job$folds,rep(1L,n),job$binary,TRUE)
 expected<-setNames(job$reference$value,job$reference$model)[models]
 stopifnot(max(abs(original$values-expected))<1e-10)
 # Independent glm/pROC reference check against the original implementation.
 reference_pred<-matrix(NA_real_,n,8,dimnames=list(NULL,models))
 for(m in models) for(k in 1:10) {
  ft<-glm(reformulate(job$formula_terms[[m]],'y'),data=d[job$folds!=k,],family=if(job$binary)'binomial' else 'gaussian')
  reference_pred[job$folds==k,m]<-predict(ft,d[job$folds==k,],type='response')
 }
 stopifnot(max(abs(reference_pred-original$predictions))<1e-7)
 if(job$binary) for(m in models) stopifnot(abs(original$values[m]-as.numeric(auc(roc(d$y,reference_pred[,m],direction='<',quiet=TRUE))))<1e-12)
 # Weighted ties and copy equivalence are checked separately in the pilot audit.
 set.seed(202610100+index)
 boot_counts<-lapply(seq_len(B),function(b){
  if(job$binary) s<-c(sample(which(d$y==0),sum(d$y==0),TRUE),sample(which(d$y==1),sum(d$y==1),TRUE)) else s<-sample.int(n,n,TRUE)
  tabulate(s,nbins=n)
 })
 repeated<-matrix(NA_real_,R,8,dimnames=list(NULL,models));bootstrap<-matrix(NA_real_,B,8,dimnames=list(NULL,models))
 diagnostics<-list()
 append_diag<-function(ft,stage,iteration) data.frame(dataset=ds,outcome=oc,stage,iteration,model=models,warnings=ft$warnings,retries=ft$retries,nonconverged=ft$nonconverged)
 diagnostics[[1]]<-append_diag(original,'original',0)
 checkpoint<-paste0(prefix,'_checkpoint.rds')
 completed_r<-completed_b<-0L
 if(file.exists(checkpoint)) {
  ch<-readRDS(checkpoint);stopifnot(nrow(ch$repeated)==R,nrow(ch$bootstrap)==B)
  repeated<-ch$repeated;bootstrap<-ch$bootstrap;diagnostics<-ch$diagnostics
  completed_r<-ch$completed_r;completed_b<-ch$completed_b
 }
 save_checkpoint<-function(cr,cb)saveRDS(list(repeated=repeated,bootstrap=bootstrap,diagnostics=diagnostics,completed_r=cr,completed_b=cb),checkpoint)
 for(r in seq_len(R)) {
  if(r<=completed_r)next
  f<-make_folds(d$y,job$binary,20261010+r)
  ft<-cv_fit(d,job$X,job$terms,f,rep(1L,n),job$binary)
  repeated[r,]<-ft$values;diagnostics[[length(diagnostics)+1]]<-append_diag(ft,'repeated_cv',r)
  if(r%%20==0) cat('Repeated CV',r,'/',R,'\n',file=paste0(prefix,'_progress.log'),append=TRUE)
  if(r%%20==0)save_checkpoint(r,0L)
 }
 for(b in seq_len(B)) {
  if(b<=completed_b)next
  ft<-cv_fit(d,job$X,job$terms,job$folds,boot_counts[[b]],job$binary)
  bootstrap[b,]<-ft$values;diagnostics[[length(diagnostics)+1]]<-append_diag(ft,'refit_bootstrap',b)
  if(b%%50==0) cat('Refit bootstrap',b,'/',B,'elapsed',round(proc.time()[3]-start),'s\n',file=paste0(prefix,'_progress.log'),append=TRUE)
  if(b%%100==0)save_checkpoint(R,b)
 }
 saveRDS(list(id=d$id,y=d$y,original_folds=job$folds,original_predictions=original$predictions,bootstrap_counts=boot_counts),file.path(folder,'private',paste0(ds,'_',oc,'_private.rds')),compress='gzip')
 ans<-list(dataset=ds,outcome=oc,n=n,events=if(job$binary)sum(d$y) else NA,metric=if(job$binary)'AUC' else 'R2',original=original$values,repeated=repeated,bootstrap=bootstrap,diagnostics=bind_rows(diagnostics),match_max_error=max(abs(original$values-expected)),prediction_match_error=max(abs(reference_pred-original$predictions)),seconds=proc.time()[3]-start)
 saveRDS(ans,paste0(prefix,'_complete.rds'));ans
}
R<-if(mode=='pilot')2L else 100L;B<-if(mode=='pilot')2L else 1000L
folder<-if(mode=='pilot')file.path(out,'pilot') else out
dir.create(folder,showWarnings=FALSE);dir.create(file.path(folder,'private'),showWarnings=FALSE)
if(mode=='summarize') {
 results<-lapply(jobs,function(j)readRDS(file.path(out,paste0(j$dataset,'_',j$outcome,'_complete.rds'))))
} else {
 workers<-min(6L,length(jobs));cl<-parallel::makePSOCKcluster(workers)
 parallel::clusterExport(cl,c('models','make_folds','performance','cv_fit','run_job'),envir=.GlobalEnv)
 parallel::clusterEvalQ(cl,{if(.Platform$OS.type=='windows')invisible(Sys.setlocale('LC_CTYPE','Chinese_China.utf8'));suppressPackageStartupMessages({library(dplyr);library(pROC)});NULL})
 results<-tryCatch(parallel::parLapplyLB(cl,seq_along(jobs),function(i,jobs,R,B,folder)run_job(jobs[[i]],i,R,B,folder),jobs=jobs,R=R,B=B,folder=folder,chunk.size=1L),finally=parallel::stopCluster(cl))
}
q<-function(x)as.numeric(quantile(x,c(.025,.975),type=7))
perf<-diffs<-repeat_long<-boot_long<-diag<-list()
for(a in results) {
 for(m in models) {
  ci<-2*a$original[m]-rev(q(a$bootstrap[,m]));range<-q(a$repeated[,m]);pci<-q(a$bootstrap[,m])
  perf[[length(perf)+1]]<-data.frame(dataset=a$dataset,outcome=a$outcome,n=a$n,events=a$events,metric=a$metric,model=m,original=a$original[m],refit_basic_low=ci[1],refit_basic_high=ci[2],refit_percentile_low=pci[1],refit_percentile_high=pci[2],repeated_mean=mean(a$repeated[,m]),repeated_sd=sd(a$repeated[,m]),split_p025=range[1],split_p975=range[2],repetitions=nrow(a$repeated),bootstrap_replicates=nrow(a$bootstrap))
  repeat_long[[length(repeat_long)+1]]<-data.frame(dataset=a$dataset,outcome=a$outcome,model=m,repeat_id=seq_len(nrow(a$repeated)),seed=20261010+seq_len(nrow(a$repeated)),value=a$repeated[,m])
  boot_long[[length(boot_long)+1]]<-data.frame(dataset=a$dataset,outcome=a$outcome,model=m,bootstrap_id=seq_len(nrow(a$bootstrap)),value=a$bootstrap[,m])
  if(m!='mbr') {
   delta<-a$original[m]-a$original['mbr'];bb<-a$bootstrap[,m]-a$bootstrap[,'mbr'];rr<-a$repeated[,m]-a$repeated[,'mbr']
   ci<-2*delta-rev(q(bb));range<-q(rr);pci<-q(bb)
   diffs[[length(diffs)+1]]<-data.frame(dataset=a$dataset,outcome=a$outcome,n=a$n,events=a$events,metric=a$metric,comparator=m,reference='mbr',delta=delta,refit_basic_low=ci[1],refit_basic_high=ci[2],refit_percentile_low=pci[1],refit_percentile_high=pci[2],repeated_mean_delta=mean(rr),repeated_sd_delta=sd(rr),split_delta_p025=range[1],split_delta_p975=range[2],positive_repeats=sum(rr>0),negative_repeats=sum(rr<0),tied_repeats=sum(rr==0),repetitions=length(rr),bootstrap_replicates=length(bb))
  }
 }
 diag[[length(diag)+1]]<-a$diagnostics
}
write_csv(bind_rows(perf),file.path(folder,'validation_performance_summary.csv'))
write_csv(bind_rows(diffs),file.path(folder,'validation_paired_differences.csv'))
write_csv(bind_rows(repeat_long),file.path(folder,'validation_repeated_cv.csv'))
write_csv(bind_rows(boot_long),file.path(folder,'validation_refit_bootstrap.csv'))
write_csv(bind_rows(diag),file.path(folder,'validation_fit_diagnostics.csv'))
audit<-list(original_values_reproduced=TRUE,maximum_absolute_performance_error=max(vapply(results,function(x)x$match_max_error,numeric(1))),maximum_absolute_prediction_error=max(vapply(results,function(x)x$prediction_match_error,numeric(1))),repetitions=R,bootstrap_replicates=B,bootstrap='Paired participant resampling; binary outcomes stratified by event; fixed original participant fold membership; all eight models refitted with training-only spline estimation; basic intervals primary, percentile intervals sensitivity.',estimand='Unweighted empirical complete-case internal CV comparison, conditional on outcome prevalence for binary endpoints; not national survey-design inference or prospective/external performance.',interval_limitations='Approximate bootstrap intervals, conditional on original fold membership. Not simultaneous or multiplicity-adjusted; repeated split ranges are not confidence intervals. Survey clusters are not resampled.',nonconverged_fits=sum(bind_rows(diag)$nonconverged),retry_fits=sum(bind_rows(diag)$retries),elapsed_seconds_by_outcome=setNames(vapply(results,function(x)x$seconds,numeric(1)),vapply(results,function(x)paste(x$dataset,x$outcome),character(1))))
write_json(audit,file.path(folder,'validation_audit.json'),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(folder,'sessionInfo.txt'))
print(audit[c('maximum_absolute_performance_error','maximum_absolute_prediction_error','repetitions','bootstrap_replicates','nonconverged_fits')])

# Reproduce revised aggregate results without modifying any input data.
if (.Platform$OS.type == 'windows') invisible(Sys.setlocale('LC_CTYPE','Chinese_China.utf8'))
if (nzchar(Sys.getenv('MBR_R_LIB'))) .libPaths(c(Sys.getenv('MBR_R_LIB'), .libPaths()))
suppressPackageStartupMessages({library(readr);library(dplyr);library(tidyr);library(survey);library(mitools);library(ggplot2);library(pROC)})
options(survey.lonely.psu='adjust', survey.adjust.domain.lonely=TRUE)
options(warn=1)
a <- enc2utf8(commandArgs(TRUE))
stopifnot(length(a)==4)
out <- a[4]
dir.create(out,recursive=TRUE,showWarnings=FALSE)
put <- function(x,n) write_csv(x,file.path(out,paste0(n,'.csv')))
theme_set(theme_bw(base_size=14,base_family='Arial')+theme(panel.grid.minor=element_blank(),axis.text=element_text(colour='black'),strip.background=element_rect(fill='white')))
saveplot <- function(p,n,w=12,h=6.75){
  ggsave(file.path(out,paste0(n,'.pdf')),p,width=w,height=h,device=cairo_pdf)
  ggsave(file.path(out,paste0(n,'.png')),p,width=w,height=h,dpi=180,bg='white')
}
z <- function(x) as.numeric(scale(x))
yn <- function(x) ifelse(x==1,1,ifelse(x==2,0,NA_real_))
design <- function(d) svydesign(ids=~psu,strata=~strata,weights=~w,data=d,nest=TRUE)
nh_columns <- c('SEQN','DEMO_H__RIDAGEYR','DEMO_H__RIAGENDR','BMX_H__BMXWT','DXX_H__DXDTOLE','DXX_H__DXDTOBMC','DXXFRX_H__DXXPRVFX','DXXFRX_H__DXXFRAX1','DXXFRX_H__DXXFRAX2','DXXFRX_H__DXXFRAX3','DXXFRX_H__DXXFRAX4','OSQ_H__OSQ060','OSQ_H__OSQ010A','OSQ_H__OSQ010C','DXXVFA_H__DXXVFAST','DEMO_H__WTMEC2YR','DEMO_H__SDMVPSU','DEMO_H__SDMVSTRA')
nh0 <- read_csv(a[1],show_col_types=FALSE,col_select=all_of(nh_columns))
stopifnot(nrow(problems(nh0))==0)
stopifnot(!anyDuplicated(nh0$SEQN))
nh <- nh0 %>% transmute(id=SEQN,age=DEMO_H__RIDAGEYR,male=ifelse(DEMO_H__RIAGENDR==1,1,ifelse(DEMO_H__RIAGENDR==2,0,NA)),weight=BMX_H__BMXWT,
 lean=DXX_H__DXDTOLE,bmc=DXX_H__DXDTOBMC,
 hip_frax=ifelse(DXXFRX_H__DXXPRVFX==1,DXXFRX_H__DXXFRAX1,ifelse(DXXFRX_H__DXXPRVFX==2,DXXFRX_H__DXXFRAX3,NA)),
 major_frax=ifelse(DXXFRX_H__DXXPRVFX==1,DXXFRX_H__DXXFRAX2,ifelse(DXXFRX_H__DXXPRVFX==2,DXXFRX_H__DXXFRAX4,NA)),
 prev_fracture=yn(DXXFRX_H__DXXPRVFX),self_report_osteoporosis=yn(OSQ_H__OSQ060),
 hip=yn(OSQ_H__OSQ010A),spine=yn(OSQ_H__OSQ010C),vfa=ifelse(DXXVFA_H__DXXVFAST==2,1,ifelse(DXXVFA_H__DXXVFAST==1,0,NA)),
 w=DEMO_H__WTMEC2YR,psu=DEMO_H__SDMVPSU,strata=DEMO_H__SDMVSTRA) %>%
 mutate(direct_fx_any=ifelse(hip==1|spine==1|vfa==1,1,ifelse(hip==0 & spine==0 & vfa==0,0,NA)),eligible=age>=40 & age<=59 & lean>0 & bmc>0,mbr=lean/bmc)
kn0 <- readRDS(a[2])
stopifnot(!anyDuplicated(paste(kn0$id,kn0$survey_year)))
kn <- kn0 %>% transmute(id=id,age=as.numeric(age),male=ifelse(sex==1,1,ifelse(sex==2,0,NA)),weight=as.numeric(he_wt),year=factor(survey_year),
 lean=as.numeric(dw_wbt_ln)-as.numeric(dw_wbt_bmc),bmc=as.numeric(dw_wbt_bmc),
 osteoporosis_any=ifelse(dx_ost==3,1,ifelse(dx_ost %in% c(1,2),0,NA)),low_bone_mass=ifelse(dx_ost %in% c(2,3),1,ifelse(dx_ost==1,0,NA)),
 osteoporosis_tf=ifelse(dx_ost_tf==3,1,ifelse(dx_ost_tf %in% c(1,2),0,NA)),
 osteoporosis_fn=ifelse(dx_ost_fn==3,1,ifelse(dx_ost_fn %in% c(1,2),0,NA)),
 osteoporosis_ls=ifelse(dx_ost_ls==3,1,ifelse(dx_ost_ls %in% c(1,2),0,NA)),
 w=as.numeric(wt_itvex)/4,psu=interaction(survey_year,psu,drop=TRUE),strata=interaction(survey_year,kstrata,drop=TRUE)) %>%
 mutate(eligible=age>=50 & lean>0 & bmc>0,mbr=lean/bmc)
put(kn0 %>% group_by(survey_year) %>% summarise(records=n(),body_composition=sum(age>=50 & dw_wbt_ln>0 & dw_wbt_bmc>0,na.rm=TRUE),old_weight_positive=sum(age>=50 & dw_wbt_ln>0 & dw_wbt_bmc>0 & wt_ex>0,na.rm=TRUE),harmonized_weight_positive=sum(age>=50 & dw_wbt_ln>0 & dw_wbt_bmc>0 & wt_itvex>0,na.rm=TRUE)), 'weight_coverage_audit')
datasets <- list(NHANES=nh,KNHANES=kn)
outcomes <- list(NHANES=c('hip_frax','major_frax','prev_fracture','direct_fx_any','self_report_osteoporosis'),KNHANES=c('osteoporosis_any','low_bone_mass','osteoporosis_tf','osteoporosis_fn','osteoporosis_ls'))
labels <- c(hip_frax='Hip FRAX',major_frax='Major fracture FRAX',prev_fracture='Previous fracture',direct_fx_any='Direct fracture indicator',self_report_osteoporosis='Self-reported osteoporosis',osteoporosis_any='Overall osteoporosis',low_bone_mass='Low bone mass',osteoporosis_tf='Total femur osteoporosis',osteoporosis_fn='Femoral neck osteoporosis',osteoporosis_ls='Lumbar spine osteoporosis')
associations <- flows <- cv <- curves <- tests <- thresholds <- list()
counter <- 0
weighted_roc <- function(y,s,w){
  t <- tibble(s=s,pos=w*y,neg=w*(1-y)) %>% group_by(s) %>% summarise(pos=sum(pos),neg=sum(neg),.groups='drop') %>% arrange(desc(s))
  P <- sum(t$pos); N <- sum(t$neg)
  t <- t %>% mutate(tp=cumsum(pos),fp=cumsum(neg),sensitivity=tp/P,specificity=1-fp/N,ppv=tp/(tp+fp),npv=(N-fp)/(N-fp+P-tp))
  # Midrank concordance counts ties as one half, including all observed thresholds.
  auc <- sum(t$pos*(N-cumsum(t$neg)+0.5*t$neg))/(P*N)
  list(table=t,auc=auc)
}
toy <- weighted_roc(c(0,1,1),c(1,1,2),c(1,2,1))
stopifnot(abs(toy$auc-2/3)<1e-12)
for (dataset in names(datasets)) {
 d <- datasets[[dataset]]
 covars <- c('age','male','weight',if(dataset=='KNHANES') 'year')
 for (outcome in outcomes[[dataset]]) {
  counter <- counter+1
  fam <- if(grepl('frax',outcome)) 'gaussian' else 'binomial'
  d$y <- d[[outcome]]
  d$ok <- !is.na(d$eligible) & d$eligible & complete.cases(d[,c('y','lean','bmc',covars)])
  model <- d[d$ok,]
  centre <- mean(model$mbr); scale <- sd(model$mbr)
  d$mbr_z <- (d$mbr-centre)/scale
  model$mbr_z <- d$mbr_z[d$ok]
  model$log_mbr <- log(model$mbr); model$log_lean<-log(model$lean);model$log_bmc<-log(model$bmc)
  f <- reformulate(c(covars,'mbr_z'),response='y')
  fit <- glm(f,data=model,family=fam)
  ds <- d %>% filter(is.finite(w),w>0,!is.na(psu),!is.na(strata))
  des <- subset(design(ds),ok)
  wf <- svyglm(f,design=des,family=if(fam=='binomial') quasibinomial() else gaussian())
  for(method in c('Unweighted','Survey-weighted')) {
   ft <- if(method=='Unweighted') fit else wf
   ci <- confint.default(ft,'mbr_z'); coef <- coef(ft)['mbr_z']; se<-sqrt(vcov(ft)['mbr_z','mbr_z'])
   p <- if(method=='Survey-weighted') summary(ft)$coefficients['mbr_z',4] else summary(ft)$coefficients['mbr_z',4]
   # Use t-based design confidence intervals for survey fits.
   if(method=='Survey-weighted') ci <- confint(ft,'mbr_z')
   associations[[length(associations)+1]] <- tibble(dataset,outcome,label=labels[outcome],method,n=nobs(ft),events=if(fam=='binomial') sum(ft$y) else NA_real_,metric=if(fam=='binomial')'OR' else 'Beta',estimate=if(fam=='binomial')exp(coef) else coef,conf_low=if(fam=='binomial')exp(ci[1]) else ci[1],conf_high=if(fam=='binomial')exp(ci[2]) else ci[2],p_value=p,mbr_sd=scale)
  }
  flows[[counter]] <- tibble(dataset,outcome,source_records=nrow(d),eligible=sum(d$eligible,na.rm=TRUE),complete_cases=nrow(model),events=if(fam=='binomial')sum(model$y) else NA_real_,survey_complete=nrow(des$variables),mbr_mean=centre,mbr_sd=scale)
  terms <- list(base=covars,mbr=c(covars,'mbr_z'),log_mbr=c(covars,'log_mbr'),lean=c(covars,'lean'),bmc=c(covars,'bmc'),components=c(covars,'lean','bmc'),log_components=c(covars,'log_lean','log_bmc'),flexible_components=c(covars,'splines::ns(log_lean,df=3)','splines::ns(log_bmc,df=3)'))
  # Exploratory internal validation; identical outcome-stratified folds for all models.
  set.seed(20260804)
  folds <- integer(nrow(model))
  if(fam=='binomial') for(v in 0:1){i<-which(model$y==v);folds[i]<-sample(rep(1:10,length.out=length(i)))} else folds <- sample(rep(1:10,length.out=nrow(model)))
  for(m in names(terms)){
   predictions<-rep(NA_real_,nrow(model))
   for(k in 1:10){
    train<-model[folds!=k,];test<-model[folds==k,]
    ft<-glm(reformulate(terms[[m]],'y'),data=train,family=fam)
    predictions[folds==k]<-predict(ft,newdata=test,type='response')
   }
   stopifnot(all(is.finite(predictions)))
   performance_value<-if(fam=='binomial') as.numeric(auc(roc(model$y,predictions,direction='<',quiet=TRUE))) else 1-sum((model$y-predictions)^2)/sum((model$y-mean(model$y))^2)
   n_total<-nrow(model)
   cv[[length(cv)+1]]<-tibble(dataset,outcome,model=m,n=n_total,metric=if(fam=='binomial')'CV AUC' else 'CV R2',value=performance_value,seed=20260804,folds=10)
  }
  if(outcome %in% c('prev_fracture','self_report_osteoporosis','osteoporosis_any','low_bone_mass')){
   # Reparameterize the natural spline space as a linear term plus nonlinear contrasts.
   dd<-des$variables
   x<-dd$mbr_z
   knots<-as.numeric(quantile(x,c(.1,.5,.9)));bounds<-range(x)
   B<-splines::ns(x,knots=knots,Boundary.knots=bounds)
   Q<-cbind(1,x)
   proj<-qr.coef(qr(Q),B)
   residual<-B-Q%*%proj
   q<-qr(residual,tol=1e-8);stopifnot(q$rank==3)
   use<-q$pivot[1:3]
   nl<-residual[,use,drop=FALSE];colnames(nl)<-paste0('nl',1:3)
   for(j in 1:3) des$variables[[paste0('nl',j)]]<-nl[,j]
   sf<-svyglm(reformulate(c(covars,'mbr_z',colnames(nl)),'y'),design=des,family=quasibinomial())
   ptotal<-as.numeric(regTermTest(sf,~mbr_z+nl1+nl2+nl3)$p)
   pnon<-as.numeric(regTermTest(sf,~nl1+nl2+nl3)$p)
   tests[[length(tests)+1]]<-tibble(dataset,outcome,n=length(x),events=sum(dd$y),p_overall=ptotal,p_nonlinear=pnon,internal_knot_10=knots[1],internal_knot_50=knots[2],internal_knot_90=knots[3],boundary_low=bounds[1],boundary_high=bounds[2])
   grid<-seq(quantile(x,.02),quantile(x,.98),length.out=120)
   basis<-function(t)cbind(t,(splines::ns(t,knots=knots,Boundary.knots=bounds)-cbind(1,t)%*%proj)[,use,drop=FALSE])
   X<-sweep(basis(grid),2,as.numeric(basis(0)),'-')
   idx<-c('mbr_z','nl1','nl2','nl3');b<-coef(sf)[idx];V<-vcov(sf)[idx,idx]
   lp<-as.numeric(X%*%b);se<-sqrt(rowSums((X%*%V)*X))
   curves[[length(curves)+1]]<-tibble(dataset,outcome,mbr_z=grid,or=exp(lp),low=exp(lp-1.96*se),high=exp(lp+1.96*se))
   for(weighted in c(FALSE,TRUE)){
    rdat<-if(weighted) des$variables else model
    for(score in c('MBR','OSTA risk')){
     ss<-if(score=='MBR') rdat$mbr else .2*(rdat$age-rdat$weight)
     rr<-weighted_roc(rdat$y,ss,if(weighted) rdat$w else rep(1,nrow(rdat)))
     if(!weighted)stopifnot(abs(rr$auc-as.numeric(auc(roc(rdat$y,ss,direction='<',quiet=TRUE))))<1e-10)
     tab<-rr$table
     selected<-bind_rows(tab %>% slice_max(sensitivity+specificity-1,n=1,with_ties=FALSE) %>% mutate(strategy='Youden'),tab %>% filter(sensitivity>=.9) %>% slice_max(specificity,n=1,with_ties=FALSE) %>% mutate(strategy='Sensitivity >=90%'))
     thresholds[[length(thresholds)+1]]<-selected %>% transmute(dataset,outcome,score,weighted,n=nrow(rdat),events=sum(rdat$y),auc=rr$auc,strategy,threshold=s,sensitivity,specificity,ppv,npv)
    }
   }
  }
 }
}
assoc<-bind_rows(associations);cv<-bind_rows(cv);flows<-bind_rows(flows);tests<-bind_rows(tests);curves<-bind_rows(curves);thresholds<-bind_rows(thresholds)
put(assoc,'adjusted_associations');put(cv,'component_cv_performance');put(flows,'sample_flow');put(tests,'spline_tests');put(curves,'spline_curves');put(thresholds,'threshold_performance')
stopifnot(nrow(cv)==80,all(is.finite(cv$value)),all(thresholds$auc>=0 & thresholds$auc<=1),all(tests$p_nonlinear>=0 & tests$p_nonlinear<=1))
for(dataset in names(datasets)){
 dd<-datasets[[dataset]] %>% filter(eligible,!is.na(male)) %>% mutate(sex=ifelse(male==1,'Men','Women'))
 put(dd %>% group_by(sex) %>% summarise(n=n(),age_mean=mean(age),mbr_median=median(mbr),mbr_q1=quantile(mbr,.25),mbr_q3=quantile(mbr,.75),lean_mean=mean(lean),bmc_mean=mean(bmc)),paste0(dataset,'_description'))
 if(dataset=='KNHANES'){
  saveplot(ggplot(dd,aes(mbr,colour=sex))+geom_density(linewidth=.9)+scale_colour_manual(values=c('#0072B5','#BC3C29'))+labs(x='Lean soft tissue / BMC',y='Density',colour=NULL),'KNHANES_distribution')
 }
 for(metric in unique(assoc$metric[assoc$dataset==dataset])){
  ad<-assoc %>% filter(.data$dataset==.env$dataset,.data$metric==.env$metric)
  saveplot(ggplot(ad,aes(estimate,label,colour=method))+geom_vline(xintercept=if(metric=='OR')1 else 0,linetype=2)+geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.15,position=position_dodge(.4))+geom_point(position=position_dodge(.4),size=2.6)+scale_colour_manual(values=c('#0072B5','#BC3C29'))+labs(x=paste(metric,'per sample SD higher MBR'),y=NULL,colour=NULL)+theme(legend.position='top'),paste0(dataset,'_',metric))
 }
}
saveplot(ggplot(curves,aes(mbr_z,or))+geom_hline(yintercept=1,linetype=2)+geom_ribbon(aes(ymin=low,ymax=high),fill='#0072B5',alpha=.15)+geom_line(colour='#0072B5',linewidth=.9)+facet_wrap(~dataset+outcome,scales='free_y',labeller=labeller(outcome=labels))+scale_y_log10()+labs(x='DXA-derived MBR z-score',y='Adjusted odds ratio'),'spline_figure',12,8)
saveplot(ggplot(cv %>% filter(model %in% c('mbr','bmc','components','flexible_components')),aes(model,value,colour=dataset))+geom_point(size=3)+facet_wrap(~outcome,scales='free_y',ncol=3,labeller=labeller(outcome=labels))+scale_x_discrete(labels=c(mbr='MBR',bmc='BMC',components='Joint',flexible_components='Flexible'))+scale_colour_manual(values=c('#0072B5','#BC3C29'))+labs(x=NULL,y='Out-of-fold AUC or R-squared')+theme(axis.text.x=element_text(angle=30,hjust=1),legend.position='top'),'component_comparison',13,10)
saveplot(ggplot(thresholds %>% filter(score=='MBR',weighted) %>% pivot_longer(c(sensitivity,specificity),names_to='metric',values_to='value'),aes(strategy,value,colour=metric,group=metric))+geom_line()+geom_point(size=3)+facet_wrap(~dataset+outcome,labeller=labeller(outcome=labels))+scale_colour_manual(values=c('#0072B5','#BC3C29'),labels=c('Sensitivity','Specificity'))+scale_y_continuous(limits=c(0,1))+labs(x=NULL,y='Weighted performance',colour=NULL)+theme(legend.position='top'),'threshold_figure',12,8)

# NHANES five-imputation bridge: all original MEC records retained for domain variance.
b0<-read_csv(a[3],show_col_types=FALSE,col_select=matches('^SEQN$|nhanes_cycle|MULT|RIDAGEYR|WTMEC|SDMV|BIDFFM|BIDFAT|DXDTOLE|DXDTOFAT'))
co<-function(suffix){v<-rep(NA_real_,nrow(b0));for(n in grep(paste0(suffix,'$'),names(b0),value=TRUE))v<-coalesce(v,as.numeric(b0[[n]]));v}
bridge<-tibble(id=b0$SEQN,cycle=b0$nhanes_cycle,imp=co('_MULT_'),age=co('RIDAGEYR'),ffm=co('BIDFFM'),fat=co('BIDFAT'),lean=co('DXDTOLE')/1000,dxa_fat=co('DXDTOFAT')/1000,wt4=co('WTMEC4YR'),wt2=co('WTMEC2YR'),psu=co('SDMVPSU'),strata=co('SDMVSTRA')) %>% mutate(w=ifelse(grepl('2003',cycle),wt2/3,wt4*2/3))
stopifnot(!anyDuplicated(paste(bridge$id,bridge$imp)))
imputed<-bridge %>% filter(!is.na(imp)) %>% count(id)
stopifnot(all(imputed$n==5))
individual<-pooled<-list()
for(pair in c('Fat-free mass versus lean soft tissue','Fat mass')){
 for(weighted in c(FALSE,TRUE)){
  zs<-vars<-dfs<-ns<-numeric(5)
  for(k in 1:5){
   bd<-bridge %>% filter(is.na(imp)|imp==k) %>% mutate(x=if(pair=='Fat mass') fat else ffm,y=if(pair=='Fat mass')dxa_fat else lean,ok=age>=8 & age<=49 & !is.na(x) & !is.na(y))
   stopifnot(!anyDuplicated(bd$id))
   bd<-bd %>% filter(!is.na(w),w>0,!is.na(psu),!is.na(strata))
   bd$x2<-bd$x^2;bd$y2<-bd$y^2;bd$xy<-bd$x*bd$y
   bd$one<-1
   bs<-if(weighted) subset(design(bd),ok) else subset(svydesign(ids=~1,weights=~one,data=bd),ok)
   moments<-svymean(~x+y+x2+y2+xy,bs)
   rr<-svycontrast(moments,quote((xy-x*y)/sqrt((x2-x*x)*(y2-y*y))))
   r<-as.numeric(coef(rr)); zs[k]<-atanh(r);vars[k]<-as.numeric(vcov(rr))/(1-r^2)^2;dfs[k]<-degf(bs);ns[k]<-nrow(bs$variables)
   individual[[length(individual)+1]]<-tibble(pair,weighted,imputation=k,n=ns[k],r,z=zs[k],variance_z=vars[k],design_df=dfs[k])
  }
  stopifnot(length(unique(ns))==1)
  comb<-MIcombine(lapply(zs,function(x)c(z=x)),lapply(vars,function(x)matrix(x,1,1)),df.complete=min(dfs))
  est<-comb$coefficients;se<-sqrt(comb$variance);crit<-qt(.975,comb$df)
  pooled[[length(pooled)+1]]<-tibble(pair,weighted,n=ns[1],imputations=5,r=tanh(est),conf_low=as.numeric(tanh(est-crit*se)),conf_high=as.numeric(tanh(est+crit*se)),within_variance=mean(vars),between_variance=var(zs))
 }
}
put(bind_rows(individual),'bridge_per_imputation');bp<-bind_rows(pooled);put(bp,'bridge_pooled')
saveplot(ggplot(bp,aes(r,pair,colour=weighted))+geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.15,position=position_dodge(.45))+geom_point(position=position_dodge(.45),size=3)+scale_colour_manual(values=c('#0072B5','#BC3C29'),labels=c('Unweighted','Survey-weighted'))+labs(x='Correlation (Rubin-pooled 95% CI)',y=NULL,colour=NULL)+theme(legend.position='top'),'bridge_figure')
capture.output(sessionInfo(),file=file.path(out,'sessionInfo.txt'))
capture.output(warnings(),file=file.path(out,'warnings.txt'))
message('Completed revised results: ',out)

# Cluster repeated survey observations by respondent; never export individual records.
if (.Platform$OS.type=='windows') invisible(Sys.setlocale('LC_CTYPE','Chinese_China.utf8'))
if(nzchar(Sys.getenv('MBR_R_LIB'))) .libPaths(c(Sys.getenv('MBR_R_LIB'),.libPaths()))
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(haven);library(survey);library(ggplot2)})
a<-enc2utf8(commandArgs(TRUE));stopifnot(length(a)==6)
out<-a[6];dir.create(out,recursive=TRUE,showWarnings=FALSE)
h<-readRDS(a[1]);c<-readRDS(a[2]);s<-readRDS(a[3])
hw<-read_sas(a[4],col_select=all_of(c('HHIDPN',paste0('R',11:16,'WTRESP')))) %>%
 mutate(HHIDPN=as.character(HHIDPN)) %>% pivot_longer(-HHIDPN,names_to='v',values_to='w') %>%
 mutate(survey_year=2012+2*(as.numeric(gsub('[^0-9]','',v))-11)) %>% select(-v)
stopifnot(!anyDuplicated(paste(hw$HHIDPN,hw$survey_year)))
h<-h %>% mutate(HHIDPN=as.character(HHIDPN)) %>% left_join(hw,by=c('HHIDPN','survey_year'),relationship='many-to-one')
normalize_id<-function(x){x<-as.character(x);ifelse(nchar(x)==11,paste0(substr(x,1,9),'0',substr(x,10,11)),x)}
wf<-list.files(a[5],pattern='^weights?\\.dta$',full.names=TRUE,recursive=TRUE,ignore.case=TRUE)
stopifnot(length(wf)==5)
cw<-bind_rows(lapply(wf,function(f){
 d<-read_dta(f);yr<-as.numeric(sub('.*(20[0-9]{2}).*','\\1',basename(dirname(f))))
 ns<-intersect(c('INDV_weight','ind_weight','INDV_weight_ad2','ind_weight_ad2'),names(d));stopifnot(length(ns)>0)
 w<-rep(NA_real_,nrow(d));for(n in ns)w<-coalesce(w,as.numeric(d[[n]]))
 tibble(ID=normalize_id(d$ID),survey_year=yr,w=w) %>% filter(!is.na(ID),nchar(ID)==12)
}))
stopifnot(!anyDuplicated(paste(cw$ID,cw$survey_year)))
c<-c %>% mutate(ID=as.character(ID)) %>% left_join(cw,by=c('ID','survey_year'),relationship='many-to-one')
h<-h %>% mutate(pid=HHIDPN,age10=age/10,female=ifelse(sex=='Female',1,0),wave=factor(survey_year)) %>% filter(age>=50,!is.na(female))
c<-c %>% mutate(pid=ID,age10=age/10,female=ifelse(sex=='Female',1,0),wave=factor(survey_year)) %>% filter(age>=50,!is.na(female))
s<-s %>% mutate(pid=as.character(mergeid),w=wtresp_valid,country=factor(country),wave=factor(wave)) %>% filter(age>=50,!is.na(female))
for(d in list(h,c,s))stopifnot(!anyDuplicated(paste(d$pid,d$wave)))
labels<-c(fall_past2y='Fall in past 2 years',fall_injury='Fall-related injury',broken_hip='Reported hip fracture',osteoporosis='Self-reported osteoporosis',fall_recent='Recent fall',fall_medical_treat='Fall requiring medical treatment',hip_fracture='Reported hip fracture',fall_s='Fall-related limitation',hip_ever='Ever hip fracture',osteoporosis_med='Osteoporosis medication')
spec<-list(HRS=list(data=h,outcomes=c('fall_past2y','fall_injury','broken_hip','osteoporosis'),scope='2012-2022'),CHARLS=list(data=c,outcomes=c('fall_recent','hip_fracture'),scope='2011-2020'),CHARLS_recent=list(data=filter(c,survey_year %in% c(2018,2020)),outcomes=c('fall_recent','fall_medical_treat','hip_fracture'),scope='2018-2020'),SHARE=list(data=s,outcomes=c('fall_s','hip_ever','osteoporosis_med'),scope='Waves 1,2,4-9'))
ans<-list()
for(nm in names(spec)){
 sp<-spec[[nm]];d<-sp$data
 for(y in sp$outcomes){
  covars<-c('age10','female','wave',if(nm=='SHARE')'country')
  dd<-d[complete.cases(d[,c('pid',y,covars)]),];dd$y<-dd[[y]]
  for(weighted in c(FALSE,TRUE)){
   dat<-if(weighted)dd[is.finite(dd$w)&dd$w>0,] else dd
   dat$weight<-if(weighted)dat$w/mean(dat$w) else 1
   des<-svydesign(ids=~pid,weights=~weight,data=dat)
   fit<-svyglm(reformulate(covars,'y'),design=des,family=quasibinomial(),control=list(maxit=100))
   stopifnot(isTRUE(fit$converged))
   for(term in c('age10','female')){
    ci<-confint(fit,term);co<-summary(fit)$coefficients[term,]
    ans[[length(ans)+1]]<-tibble(dataset=sub('_recent','',nm),scope=sp$scope,outcome=unname(labels[y]),contrast=ifelse(term=='age10','Per 10-year age increase','Female vs male'),weighted=weighted,n=nrow(dat),participants=n_distinct(dat$pid),events=sum(dat$y),estimate=exp(co[1]),conf_low=exp(ci[1]),conf_high=exp(ci[2]),p_value=unname(co[4]))
   }
  }
 }
 message('Completed clustered context: ',nm)
}
ans<-bind_rows(ans);write_csv(ans,file.path(out,'context_clustered_associations.csv'))
coverage<-bind_rows(h %>% mutate(dataset='HRS'),c %>% mutate(dataset='CHARLS')) %>% group_by(dataset,survey_year) %>% summarise(records=n(),participants=n_distinct(pid),positive_weight=sum(is.finite(w)&w>0),.groups='drop')
write_csv(coverage,file.path(out,'context_weight_coverage.csv'))
theme_set(theme_bw(base_size=14,base_family='Arial')+theme(panel.grid.minor=element_blank(),axis.text=element_text(colour='black'),strip.background=element_rect(fill='white')))
for(nm in c('HRS','CHARLS_recent','SHARE')){
 sp<-spec[[nm]];ds<-sub('_recent','',nm)
 dd<-ans %>% filter(dataset==ds,scope==sp$scope) %>% mutate(method=ifelse(weighted,'Response-weighted','Unweighted'))
 p<-ggplot(dd,aes(estimate,outcome,colour=method))+geom_vline(xintercept=1,linetype=2)+geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.15,position=position_dodge(.4))+geom_point(position=position_dodge(.4),size=2.5)+facet_wrap(~contrast,scales='free_x')+scale_colour_manual(values=c('#0072B5','#BC3C29'))+labs(x='Odds ratio (respondent-clustered 95% CI)',y=NULL,colour=NULL)+theme(legend.position='top')
 for(ext in c('pdf','png'))ggsave(file.path(out,paste0(nm,'_clustered.',ext)),p,width=13,height=7,dpi=180,bg='white',device=if(ext=='pdf')cairo_pdf else 'png')
}
capture.output(sessionInfo(),file=file.path(out,'context_sessionInfo.txt'))

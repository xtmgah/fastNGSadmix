## du -cksh *

########### do not change ################3
l<-commandArgs(TRUE)
getArgs<-function(x,l)
  unlist(strsplit(grep(paste("^",x,"=",sep=""),l,val=T),"="))[2]
Args<-function(l,args){
  if(! all(sapply(strsplit(l,"="),function(x)x[1])%in%names(args))){
    cat("Error -> ",l[!sapply(strsplit(l,"="),function(x)x[1])%in%names(args)]," is not a valid argument")
    q("no")
  }
  arguments<-list()
  for(a in names(args)){
    arguments[[a]]<-getArgs(a,l)
    
  }
  ## check for plinkFile or beagle file
  if(!any(c("plinkFile","likes")%in%names(arguments))){
    cat("Error -> plinkFile or likes argument has to be supplied!\n")
    q("no")  
  } else if(all(c("plinkFile","likes")%in%names(arguments))){
    cat("Error -> plinkFile and likes argument have both been supplied, only one please!\n")
    q("no")  
  } else if(!all(c("qopt")%in%names(arguments))){
    cat("Error -> estimated admixture proporotions have to be supplied from fastNGSadmix, as .qopt file!\n")
    q("no")  
  } else if(!all(c("geno")%in%names(arguments))){
    cat("Error -> genotypes of reference populations have to be supplied as plinkFile binary files!\n")
    q("no")
  } else if(c("plinkFile")%in%names(arguments)){
    arguments$likes<-""
  } else if(c("likes")%in%names(arguments)){
    arguments$plinkFile<-""
  } else if(c("qopt")%in%names(arguments)){
    arguments$qopt<-""
  }
  
  if(any(!names(args)%in%names(arguments)&sapply(args,is.null))){
    cat("Error -> ",names(args)[!names(args)%in%names(arguments)&sapply(args,is.null)]," is not optional!\n")
    q("no")
  }
  
  for(a in names(args))
    if(is.null(arguments[[a]]))
      arguments[[a]]<-args[[match(a,names(args))]]
  return(arguments)
}

print.args<-function(args,des){
  if(missing(des)){
    des<-as.list(rep("",length(args)))
    names(des)<-names(args)
  }
  cat("->  needed arguments:\n")
  mapply(function(x)cat("\t",x,":",des[[x]],"\n"),cbind(names(args)[sapply(args,is.null)]))
  cat("->  optional arguments (defaults):\n")
  mapply(function(x)cat("\t",x," (",args[[x]],")",":",des[[x]],"\n"),cbind(names(args)[!sapply(args,is.null)]))
  q("no")
}
###### ####### ###### ###### ###### #######
## choose your parameters and defaults
## NULL is an non-optional argument, NA is an optional argument with no default, others are the default arguments

## getting arguments for run

args<-list(likes=NULL,
           plinkFile=NULL,
           ## called genotype of reference panel 
           geno = NULL, 
           qopt = NULL,
           dryrun = FALSE,
           out = 'output',
           PCs="1,2"
)
## if no argument aree given prints the need arguments and the optional ones with default
des<-list(likes="input GL in beagle format",
          plinkFile="input binary plink in bed format",
          geno = 'plink binary files filename with reference individuals for PCA',
          qopt= "estimated admixture proportions from fastNGSadmix, as .qopt file",
          dryrun = '',
          out= "output filename prefix",
          PCs= "which Principal components to be ploted default 1 and 2"
          
          
)

######################################
#######get arguments and add to workspace
### do not change
if(length(l)==0) print.args(args,des)
attach(Args(l,args))
args <- commandArgs(TRUE)
if(length(args)==0){
  cat("Arguments: output prefix\n")
  q("no")
}
###################################


## for reading plink files using snpStats
plinkV2<-function(plinkFile){
  pl<-snpStats::read.plink(plinkFile)
  pl2<-matrix(methods::as(pl$genotypes,"numeric"),nrow=nrow(pl$genotypes),ncol=ncol(pl$genotypes))
  colnames(pl2)<-colnames(pl$genotypes)  
  ind<-rownames(pl2)
  snp<-colnames(pl2)
  bim<-read.table(paste0(plinkFile,".bim"),as.is=T,header=F)
  fam<-read.table(paste0(plinkFile,".fam"),as.is=T,header=F)
  ## fam has groupID and then individualID
  rownames(pl2)<-fam$V2
  list(geno=pl2,bim=bim,fam=fam,pl=pl)
}

pl<-plinkV2(geno)
admix<-read.table(qopt,h=T,as.is=T)
## refpops are analyzed pops for admixture estimation
refpops<-colnames(admix)

if(dryrun){
  print(table(pl$fam$V1))
  cat('dryrun must be assign to default, FALSE, to execute FastNGSAdmixPCA\n')
  stop()
}

if(!all(k<-refpops%in%unique(pl$fam$V1))){   

    cat("These are not part of the genos:\n")
    print(refpops[!k])
    cat("use these pops from the genos instead\n")
    print(unique(pl$fam$V1))
    stop()
}

grDevices::palette(ccol)
gar<-grDevices::dev.off()
require(methods)

## used for calculating the covariance entries between input data and ref indis without normalizing
glfunc <- function(x,G_mat,my,pre_norm,geno_test) {
  freq <- my/2
  abc <- (G_mat-my)*(geno_test[,x]-my)*pre_norm
  abcr <- (rowSums(abc))/((freq*(1-freq)))
  sum(abcr)
}

## generates barplot of admixture proportions with conf intervals
generateBarplot<-function(admix,sorting,out,quantiles=T){
  margins=c(5.1, 4.1, 8.1, 2.1)
  admix<-admix[,match(sorting,colnames(admix))]
  if(nrow(admix)>10){
    
    if(quantiles){
      m<-matrix(0,nrow=2,ncol=ncol(admix))
      m[1,]<-as.numeric(apply(admix,2,function(x) quantile(x[2:length(x)],probs=c(0.025))))
      m[2,]<-as.numeric(apply(admix,2,function(x) quantile(x[2:length(x)],probs=c(0.975))))
    } else{
      m<-matrix(0,nrow=2,ncol=ncol(admix))
      m[1,]<-as.numeric(admix[1,]-apply(admix,2,function(x) sqrt(sum((x[-1]-mean(x[-1]))**2)/(length(x[-1])-1))))
      m[2,]<-as.numeric(admix[1,]+apply(admix,2,function(x) sqrt(sum((x[-1]-mean(x[-1]))**2)/(length(x[-1])-1))))
    }
    
    bitmap(paste(out,"_",ifelse(quantiles,"quantile_","SE_"),"admixBarplot.png",sep=""),res=300)
    par(mar=margins)
    b1<-barplot(as.numeric(admix[1,]) ,col=as.factor(colnames(admix)),ylim=c(0,1.1))
    
    segments(b1,m[1,],b1,m[2,])
    segments(b1-0.2,m[1,],b1+0.2,m[1,])
    segments(b1-0.2,m[2,],b1+0.2,m[2,])
    par(xpd=T)
    legend("topright",inset=c(0.0,-0.2),colnames(admix),fill=as.factor(colnames(admix)),cex=1.5)
    garbage<-dev.off()
  } else{
    
    bitmap(paste(out,"_admixBarplot.png",sep=""),res=300)
    par(mar=margins)
    b1<-barplot(as.numeric(admix[1,]) ,col=as.factor(colnames(admix)),ylim=c(0,1.1))
    par(xpd=T)
    legend("topright",inset=c(0.0,-0.),colnames(admix),fill=as.factor(colnames(admix)),cex=1.5)
    garbage<-dev.off()
  }
}

estimateAdmixPCA<-function(likes=NULL,plinkFile=NULL,admix,refpops,out){
    
    ## first PCA for ref pops based on all SNPs
    geno_test<-pl$geno[ pl$fam[  pl$fam$V1%in%refpops,"V2"],]
    ##snp row::sample col
    geno_test <- t(geno_test)
    ## too many NA, so put NA to 2 (major major) instead of removing column
    geno_test[is.na(geno_test)] = 2 
    my <- rowMeans(geno_test,na.rm=T)
    freq<-my/2    
    ind <- pl$fam[ pl$fam$V1%in%refpops,"V1"]    
    table(ind)
    ##normalizing the genotype matrix
    M <- (geno_test-my)/sqrt(freq*(1-freq))      
    ##M[is.na(M)] <- 2
    ##get the (almost) covariance matrix
    Xtmp<-(t(M)%*%M)
    ## normalizing the covariance matrix
    X<-(1/nrow(geno_test))*Xtmp 

    ## if plink files reads and convert to beagle file
    if(plinkFile!=""){
        plInput<-plinkV2(paste(plinkFile,sep=""))
        GL.raw<-cbind(paste(plInput$bim$V1,plInput$bim$V4,sep="_"),plInput$bim$V6,plInput$bim$V5,0,0,0)
        GL.raw[ which(plInput$geno[1,]==2),4]<-1
        GL.raw[ which(plInput$geno[1,]==1),5]<-1
        GL.raw[ which(plInput$geno[1,]==0),6]<-1
        GL.raw<-GL.raw[ !is.na(plInput$geno[1,]),]
        GL.raw2<-as.data.frame(GL.raw,stringsAsFactors=F)
        colnames(GL.raw2)<-c("marker", "allele1", "allele2", "Ind0", "Ind0.1", "Ind0.2")
        
    } else{
        GL.raw2 <- read.table(paste(likes,sep=""),as.is=T,h=T,colC=c("character","integer","numeric")[c(1,1,1,3,3,3)])
    }
    if(any(duplicated(GL.raw2[,1]))){    
        print("Duplicate markers in beagle or plinkFile file - fix this!")
    }

    ## overlapping sites with ref genos
    rownames(GL.raw2) <- GL.raw2[,1]
    GL.raw2<-GL.raw2[ GL.raw2[,1]%in%paste(pl$bim$V1,pl$bim$V4,sep="_"),]
    bim2<-pl$bim[ paste(pl$bim$V1,pl$bim$V4,sep="_")%in%GL.raw2[,1],]
    geno2<-pl$geno[ ,colnames(pl$geno)%in%bim2$V2]
    
    ## if alleles coded as 0,1,2,3 instead of A,C,G,T
    if(any(c(0,1,2,3)%in%GL.raw2[,2]) | any(c(0,1,2,3)%in%GL.raw2[,3])){
        GL.raw2[,2]<-sapply(GL.raw2[,2], function(x) ifelse(x==0,"A",ifelse(x==1,"C",ifelse(x==2,"G",ifelse(x==3,"T",x)))))
        GL.raw2[,3]<-sapply(GL.raw2[,3], function(x) ifelse(x==0,"A",ifelse(x==1,"C",ifelse(x==2,"G",ifelse(x==3,"T",x)))))
    
    }
    
    print("The overlap between input and genos is:")
    print(ncol(geno2))
    
    ## those were alleles agree should be flipped like for refPanel, so all genotypes point in same direction
    flip<-sapply(1:nrow(GL.raw2),function(x) GL.raw2[x,2]==bim2[x,6] & GL.raw2[x,3]==bim2[x,5])  
    geno_test2<-geno2[ pl$fam[  pl$fam$V1%in%refpops,"V2"],]
        
    ## hereby only constructing ref panel of individuals/pops in admix file
    popFreqs<-sapply(colnames(admix), function(x) colMeans(geno_test2[pl$fam[ pl$fam[,1]==x,2],],na.rm=T)/2)
    popFreqs2<-popFreqs[,match(colnames(popFreqs),colnames(admix))]
    ##snp row::sample col
    geno_test2 <- t(geno_test2) 
    geno_test2[is.na(geno_test2)] = 2  
    geno_test2[flip,]<-2-geno_test2[flip,]
    popFreqs2[!flip,]<-1-popFreqs2[!flip,]
    
    ## recalculating for the new genotype matrix with individual
    my2 <- rowMeans(geno_test2,na.rm=T)
    freq2<-my2/2
    
    ## calculating admixture adjusted freqs
    hj <- as.matrix(popFreqs2) %*% t(admix[1,])
    hj_inv <- 1-hj ## sites X 1
    gs <- cbind(hj**2,2*hj*hj_inv,hj_inv**2) ## Sites X 3
    ## likelihood P(X|G=g)P(G=g|Q,F)
    pre <- as.numeric(as.matrix(GL.raw2[,4:6]))*gs
    ## normalizing likelihoods
    pre_norm <- pre/rowSums(pre)
    ## can have issues of pre being only 0's and thereby dividing by 0, yeilding NAs
    pre_norm[is.na(pre_norm)]<-0 
    size <- nrow(pre_norm)
    G_mat <- data.frame(x=rep(0,size),y=rep(1,size),z=rep(2,size))
    
    ## calculating covariances between input individual and ref individuals 
    GL_called <- unlist(lapply(colnames(geno_test2),glfunc,G_mat=G_mat,my=my2,pre_norm=pre_norm,geno_test=geno_test2))
    ## calculating covariances
    abc_single <- (G_mat-my2)*(G_mat-my2)*pre_norm
    abcr_single <- (rowSums(abc_single))/((freq2*(1-freq2)))
    GL_called_diag <- c(as.numeric(GL_called),sum(abcr_single))   
    ## normalizing input, putting on last row of data, X is normalized covariance matrix only from ref genos
    X_1 <- rbind(X,'GL'=(1/nrow(geno_test2))*as.numeric(GL_called))
    X_2 <- as.data.frame(cbind(X_1,GL=(1/nrow(geno_test2))*GL_called_diag))   
    ## final normalized covariance matrix
    X_norm <- X_2  
    return(list(covar = X_norm,indi=ind))
}




PCAplotV2 = function(cova,ind,admix,out,PCs) {
    ## eigen decomposition of covariance matrix for PCA
    E<-eigen(cova)
    ## extracts chosen PCs
    PC_12 = round(as.numeric(E$values/sum(E$values))[PCs],3)*100
    a <- data.frame(E$vectors[,PCs])
    a$pop = c(ind,'SAMPLE')
    colnames(a) = c(paste('PC',1,sep=""),paste('PC',2,sep=""),'pop')
    pdf(paste0(out,'_PCAplot.pdf'))
    par(mar=c(5, 4, 4, 8) + 0.1)
    plot(a$PC1[1:(nrow(a)-1)],a$PC2[1:(nrow(a)-1)],xlab=paste('PC',PCs[1],' (%)',PC_12[PCs[1]]),ylab=paste('PC',PCs[2],' (%)',PC_12[2]),col=as.factor(a$pop[1:(nrow(a)-1)]),pch=16,ylim=c(min(a$PC2),max(a$PC2)),xlim=c(min(a$PC1),max(a$PC1)))
    points(a$PC1[nrow(a)],a$PC2[nrow(a)],pch=4,cex=2,lwd=4)
    print(paste(a$PC1[nrow(a)],a$PC2[nrow(a)]))
    par(xpd=TRUE)
    legend("topright",inset=c(-0.3,0),legend=unique(as.factor(a$pop[1:(nrow(a)-1)])),fill=unique(as.factor(a$pop[1:(nrow(a)-1)])))
    garbage<-dev.off()
}

pop_list<- estimateAdmixPCA(likes=likes,plinkFile=plinkFile,admix=admix,refpops = refpops,out = out)
write.table(pop_list$covar, file=paste0(out,'_pca.txt'),quote=F)
write.table(cbind(rownames(pop_list$covar),c(pop_list$ind,"SAMPLE")), file=paste0(out,'_indi.txt'),quote=F,col=F,row=F)
generateBarplot(admix=admix,sorting = unique(pop_list$ind),out = out)
generateBarplot(admix=admix,sorting = unique(pop_list$ind),out = out,quantiles = F)
PCAplotV2(pop_list$covar,pop_list$indi,admix=admix,out,PCs=sort(as.numeric(unlist(strsplit(PCs,",")))))
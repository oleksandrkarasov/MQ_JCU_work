#script to evaluate distribution models

# read in the arguments listed at the command line in shell script
args=(commandArgs(TRUE))  
# check to see if arguments are passed
if(length(args)==0){
    print("No arguments supplied.")
    # leave all args as default values
} else {
	for(i in 1:length(args)) { 
		eval(parse(text=args[[i]])) 
	}
	# expecting wd and species to be able to locate arguments file
}

# load arguments file
load(paste(wd, "/03.init.args.evaluate.", species, ".RData", sep=""))

### check if libraries are installed, install if necessary and then load them
necessary=c("dismo") #list the libraries needed
installed = necessary %in% installed.packages() #check if library is installed
if (length(necessary[!installed]) >=1) install.packages(necessary[!installed], dep = T) #if library is not installed, install it
for (lib in necessary) library(lib,character.only=T)#load the libraries

###load in the data
if (file.exists(occur.data) && file.exists(bkgd.data)) {
	load(occur.data); load(bkgd.data);
} else {
	stop("No occurrence or background data available for model evaulation!")
}

# source helper functions (saveModelEvaluation, createMarginalResponseCurves, calculateVariableImpt, calculatePermutationVarImpt)
source(paste(function.path, "/my.Helper.Functions.R", sep=""))

# source my modified version of biomod2's Evaluate.models.R for consistent model accuracy statistics
source(paste(function.path, "/my.Evaluate.models.R", sep=""))

# model accuracy statistics - combine stats from dismo and biomod2 for consistent output
model.accuracy = c(dismo.eval.method, biomod.models.eval.meth)

###evaluate the models and save the outputs
###############
#
# evaluate(p, a, model, x, tr, ...)
#
# p presence points (x and y coordinate or SpatialPoints* object)
#	Or, if x is missing, values at presence points (EMG: values returned by a predict())
#	Or, a matrix with values to compute predictions for
# a absence points (x and y coordinate or SpatialPoints* object)
#	Or, if x is missing, values at absence points (EMG: values returned by a predict())
#	Or, a matrix with values to compute predictions for
# model any fitted model, including objects inheriting from 'DistModel'; not used when x is missing
# x 	Optional. Predictor values (object of class Raster*). If present, p and a are interpreted
#	as (spatial) points (EMG: lon/lat)
# tr 	Optional. a vector of threshold values to use for computing the confusion matrices
# ...	Additional arguments for the predict function (EMG: evaluate() calls predict())
#
# 'ModelEvaluation' output based on Fielding and Bell (1997) with attributes:
# presence - presence data used 
# absence - absence data used
# np - number of presence points
# na - number of absence points
# auc - Area under the receiver operator (ROC) curve
# pauc - p-value for the AUC (for the Wilcoxon test W statistic
# cor - Correlation coefficient
# pcor - p-value for correlation coefficient 
# t - vector of thresholds used to compute confusion matrices 
# confusion - confusion matrices 
# prevalence - Prevalence 
# ODP - Overall diagnostic power 
# CCR - Correct classification rate 
# TPR - True positive rate 
# TNR - True negative rate 
# FPR - False positive rate 
# FNR - False negative rate 
# PPP - Positive predictive power 
# NPP - Negative predictive power 
# MCR - Misclassification rate 
# OR - Odds-ratio 
# kappa - Cohen's kappa 
#
###############

if (evaluate.bioclim) {
	bioclim.obj = getModelObject("bioclim")	# get the model object
	if (!is.null(bioclim.obj)) {
	
		outdir = paste(wd,'/output_bioclim',sep=''); setwd(outdir)
		
		bioclim.eval = evaluate(p=occur, a=bkgd, model=bioclim.obj)	# evaluate model using dismo's evaluate
		
		# extract (COR) coefficient to add to evaluation output for easy access (Elith et al 2006)
		correlation = bioclim.eval@cor; correlation.pvalue = bioclim.eval@pcor
		COR = c(as.numeric(correlation), correlation.pvalue, NA, NA)
		
		# need predictions and observed values to create confusion matrices for accuracy statistics
		bioclim.fit = c(bioclim.eval@presence, bioclim.eval@absence)
		bioclim.obs = c(rep(1, length(bioclim.eval@presence)), rep(0, length(bioclim.eval@absence)))
		
		# get the model accuracy statistics using a modified version of biomod2's Evaluate.models.R
		bioclim.combined.eval = sapply(model.accuracy, function(x){
			return(my.Find.Optim.Stat(Stat = x, Fit = bioclim.fit, Obs = bioclim.obs))
		})
		# add correlation column to output
		bioclim.combined.eval = cbind(bioclim.combined.eval, COR)
		saveModelEvaluation(bioclim.eval, bioclim.combined.eval)	# save output
		
		# create response curves
		createMarginalResponseCurves(bioclim.obj, "bioclim")

		# calculate variable importance (like biomod2, using correlations between predictions)
		calculateVariableImpt(bioclim.obj, "bioclim", 3)
		
		# calculate variable importance (like maxent, using decrease in AUC)
		calculatePermutationVarImpt(bioclim.obj, bioclim.eval, "bioclim")

	} else {
		write(paste("FAIL!", species, "Cannot load bioclim.obj from", wd, "/output_bioclim", sep=": "), stdout())
	}
} # end if bioclim
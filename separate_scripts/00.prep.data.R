# this script prepares the occurrence and background data at three spatial resolutions
# A. creates taxon occurrence csv for each scale using original data files
# B. creates taxon background csv using newly created occurrence csv
# C. replace background csv's with SWDs (associated climate data)
# D. creates species specific occurrence files at each scale
# E. replace occurrence csv's with SWDs (associated climate data)


# define data directory
taxa.dir = "/rdsi/ccimpacts/SDM_assessment/mission_critical_data/DATA_from_refugia_project"

# define taxa
taxa = c("mammals", "birds", "reptiles", "amphibians")

# define spatial scales
scales = c("5km", "1km", "250m"); cellsizes = c(0.05, 0.01, 0.0025)

# define working dir
wd = "/rdsi/ccimpacts/SDM_assessment"

# decide which parts to run
doPartA = FALSE
doPartB = FALSE
doPartC = TRUE
doPartD = FALSE
doPartE = TRUE

# A. create taxon occurrence data for each scale
if (doPartA) {
	for (taxon in taxa[1]) {

		# read in original data file
		taxa.data = read.csv(paste(taxa.dir, "", "/", taxon, ".csv", sep=""))
		
		# create an occur for each scale
#		for (i in 1:length(scales)) {
i=3		
			# create temporary object to hold data (just SPPCODE, lon and lat)
			temp.taxa.data = taxa.data[, c("SPPCODE", "lon", "lat")]
			
			# rescale lon lat
			temp.taxa.data$lat = round(temp.taxa.data$lat/cellsizes[i])*cellsizes[i]
			temp.taxa.data$lon = round(temp.taxa.data$lon/cellsizes[i])*cellsizes[i]
			
			# remove unique occurrences
			temp.taxa.data = unique(temp.taxa.data)
		
			# write out new file
			write.csv(temp.taxa.data, file=paste(wd, "/", taxon, "/", scales[i], "_occur.csv", sep=""), row.names=FALSE)
			
#		}	# end for scale
	} # end for taxa
	rm(list=c("taxon", "taxa.data", "i", "temp.taxa.data"))
}
# B. create taxon background data for each scale using rescaled occurrence data
if (doPartB) {
	for (taxon in taxa[1]) {

		# for each scale
#		for (j in 1:length(scales)) {
j=3
			# read in rescaled occurence file
			rescaled.data = read.csv(paste(wd, "/", taxon, "/", scales[j], "_occur.csv", sep=""))
		
			# create temporary object to hold bkgd data 
			temp.bkgd.data = rescaled.data
			
			# change species' names to "bkgd"
			temp.bkgd.data$SPPCODE = rep("bkgd", length(temp.bkgd.data$SPPCODE))
			
			# remove unique occurrences
			temp.bkgd.data = unique(temp.bkgd.data)
		
			# write out new file
			write.csv(temp.bkgd.data, file=paste(wd, "/", taxon, "/", scales[j], "_bkgd.csv", sep=""), row.names=FALSE)
#		}	# end for scale
	} # end for taxa
	rm(list=c("taxon", "j", "rescaled.data", "temp.bkgd.data"))
}

# C. replace bkgd csv's with SWD's
if (doPartC) {
	library(SDMTools)
	enviro.data.dir = "/rdsi/ctbcc_data/Climate/CIAS/Australia" #define the enviro data to use
	enviro.data.names = c("bioclim_01","bioclim_04","bioclim_05","bioclim_06",
	"bioclim_12","bioclim_15","bioclim_16","bioclim_17") #define the names of the enviro data

	for (taxon in taxa[1]) {

		# for each scale
#		for (m in 1:length(scales)) {
m=3			
			# get all the environmental data in the folder
			if (scales[m] %in% c("5km", "1km")) {
				enviro.data.all = list.files(paste(enviro.data.dir, "/", scales[m], "/bioclim_asc/current.76to05", sep=""), 
					full.names=TRUE)
			} else {
				enviro.data.all = list.files(paste(enviro.data.dir, "/", scales[m], "/baseline.76to05/bioclim", sep=""), 
					full.names=TRUE)
			}
			# pull out the layers we are interested in
			enviro.data = enviro.data.all[which(gsub(".asc", "", basename(enviro.data.all)) %in% enviro.data.names)]

			# get the rescaled bkgd csv
			rescaled.bkgd.data = read.csv(paste(wd, "/", taxon, "/", scales[m], "_bkgd.csv", sep=""))

			# create SWD
			for (ii in 1:length(enviro.data)) { #cycle through each of the environmental datasets and append the data
				basc = read.asc(enviro.data[ii]) #read in the envirodata
				rescaled.bkgd.data[,enviro.data.names[ii]] = 
					extract.data(cbind(rescaled.bkgd.data$lon,rescaled.bkgd.data$lat),basc) #extract envirodata for background data
			} # end for enviro.data layers

			# remove any rows with NA
			rescaled.bkgd.data = na.omit(rescaled.bkgd.data)
				
			# replace bkgd.csv with SWD
			write.csv(rescaled.bkgd.data, file=paste(wd, "/", taxon, "/", scales[m], "_bkgd.csv", sep=""), row.names=FALSE)
#		} # end for scales
	}# end for taxa
	rm(list=c("taxon", "m", "rescaled.bkgd.data", "basc"))
}

# D. create sp specific occurrence csv's
if (doPartD) {
	for (taxon in taxa[1]) {

		# for each scale
#		for (k in 1:length(scales)) {
k=3		
			# read in rescaled data file
			rescaled.data = read.csv(paste(wd, "/", taxon, "/", scales[k], "_occur.csv", sep=""))
		
			# get a list of species names
			sp.names = unique(rescaled.data$SPPCODE)
		
			# for each species, create a directory and add sp specific occurrence data
			for (sp in sp.names) {
		
				# create directory
				dir.name = paste(wd, "/", taxon, "/models/", sp, "/", scales[k], sep="")
				dir.create(dir.name, recursive=TRUE, showWarnings = FALSE)

				# get that species' records
				sp.occur = rescaled.data[rescaled.data$SPPCODE == sp,]

				# write new occur csv file
				write.csv(sp.occur, file=paste(dir.name, "/occur.csv", sep=""), row.names=FALSE)
			} # end for species
#		} # end for scales
	}# end for taxa
	rm(list=c("taxon", "k", "rescaled.data", "sp.occur"))
}


# E. replace occur csv's with SWD's
if (doPartE) {
	library(SDMTools)
	enviro.data.dir = "/rdsi/ctbcc_data/Climate/CIAS/Australia" #define the enviro data to use
	enviro.data.names = c("bioclim_01","bioclim_04","bioclim_05","bioclim_06",
	"bioclim_12","bioclim_15","bioclim_16","bioclim_17") #define the names of the enviro data

	for (taxon in taxa[1]) {

		# for each scale
#		for (l in 1:length(scales)) {	
l=3			
			# get all the environmental data in the folder
			enviro.data.all = list.files(paste(enviro.data.dir, "/", scales[l], "/bioclim_asc/current.76to05", sep=""), 
				full.names=TRUE)
			# pull out the layers we are interested in
			enviro.data = enviro.data.all[which(gsub(".asc", "", basename(enviro.data.all)) %in% enviro.data.names)]
		
			# get a list of species names using folders created in step C. above
			sp.names = list.files(paste(wd, "/", taxon, "/models/", sep=""))
		
			# for each species, get the sp specific occurrence data
			for (sp in sp.names) {
			
				sp.occur = read.csv(paste(wd, "/", taxon, "/models/", sp, "/", scales[l], "/occur.csv", sep=""))
						
				for (jj in 1:length(enviro.data)) { #cycle through each of the environmental datasets and append the data
					oasc = read.asc(enviro.data[jj]) #read in the envirodata
					sp.occur[,enviro.data.names[jj]] = 
						extract.data(cbind(sp.occur$lon,sp.occur$lat),oasc) #extract envirodata for observations
				} # end for enviro.data layers
				
				# remove any rows with NA
				sp.occur = na.omit(sp.occur)
				
				# replace occur.csv with SWD
				write.csv(sp.occur, file=paste(wd, "/", taxon, "/models/", sp, "/", scales[l], "/occur.csv", sep=""), row.names=FALSE)
			} # end for species
#		} # end for scales
	}# end for taxa
	rm(list=c("taxon", "l", "sp.occur", "oasc"))
}
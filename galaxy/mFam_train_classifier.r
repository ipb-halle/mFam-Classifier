#!/usr/bin/env Rscript

# Setup R error handling to go to stderr
options(show.error.messages=F, error=function() { cat(geterrmessage(), file=stderr()); q("no",1,F) } )

# Set locales and encoding
loc <- Sys.setlocale("LC_MESSAGES", "en_US.UTF-8")
loc <- Sys.setlocale(category="LC_ALL", locale="C")
options(encoding="UTF-8")

# Set options
options(stringAsfactors=FALSE, useFancyQuotes=FALSE)



# ---------- Preparations ----------
# Load libraries
library(SparseM)
library(slam)
library(matrixStats)
library(Matrix)
library(plotrix)
library(MASS)
library(RMassBank)
library(rinchi)
library(stringr)
library(stringi)
library(ROCR)
library(PRROC)
library(klaR)
library(e1071)
library(kohonen)
library(nnet)
library(rda)
library(caret)
library(caretEnsemble)
library(squash)
library(RCurl)
library(ontologyIndex)
library(tools)



# ---------- Arguments and user variables ----------
# Take in trailing command line arguments
args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 3) {
	print("Error! No or not enough arguments given.")
	print("Usage: $0 working_dir classifier_library annotation_file output_dir")
	quit(save="no", status=1, runLast=FALSE)
}

# Working directory
workdir <- as.character(args[1])
setwd(workdir)

# Classifier Library, "./data/2018-02-13_neg_11328_MoNA_Spectra.msp", "./data/2018-02-13_pos_21908_MoNA_Spectra.msp"
thisLibrary <- as.character(args[2])

# Annotation file, "./data/2019-05-23_Scaffolds.tsv"
annoFile <- as.character(args[3])

# Output directory with results, "./data/Classifier_ROC_Analysis"
resultFolderForClassifiers <- as.character(args[4])



# ---------- Global variables ----------
# Working directory
#setwd("~/Desktop/Projekte/Habilitation/de.NBI/mFam-Classifier/")



# ---------- Load MetFamily ----------
# Load MetFamily
source(paste0(workdir,"/MetFamily/FragmentMatrixFunctions.R"))
source(paste0(workdir,"/MetFamily/Annotation.R"))
source(paste0(workdir,"/MetFamily/DataProcessing.R"))

# Load MFam Classifier
source(paste0(workdir,"/mFam/SubstanceClassClassifier.R"))
source(paste0(workdir,"/mFam/SubstanceClassClassifier_classifier.R"))



# ---------- MetFamily and MFam Parameter ----------
# Library
#thisLibrary <- "./data/2018-02-13_neg_11328_MoNA_Spectra.msp"
#thisLibrary <- "./data/2018-02-13_pos_21908_MoNA_Spectra.msp"
#annoFile <- "./data/2019-05-23_Scaffolds.tsv"

# Repeated random subsampling validation
minimumNumberOfPosSpectraPerClass <- 10
minimumNumberOfNegSpectraPerClass <- 10
numberOfDataSetDecompositions <- 10
proportionTraining <- 0.7
#fragmentColumnSelectionMethod <- "AbsoluteProportion"
#fragmentColumnSelectionMethod <- "ProportionOfSumOfFragmentPresence"
fragmentColumnSelectionMethod <- "ProportionOfHighestFragmentPresence"
minimumProportionOfPositiveFragments <- 0.05

thisMethod <- "method=ColSumsPos; smoothIntensities=FALSE"
#thisMethod <- "method=caret; smoothIntensities=FALSE, modelName=binda"

# I/O
#resultFolderForClassifiers       <- "./data/Classifier_ROC_Analysis"
resultFolderForMetfamilyProjects <- "./data/MetFamily_class_projects"

# Cache
reParseMsp              <- FALSE
reProcessAnno           <- FALSE
reProcessFragmentMatrix <- FALSE
reProcessLibrary        <- FALSE

# MetFamily
progress <- FALSE
outDetail <- FALSE
maximumNumberOfScores <- 10000
removeRareFragments <- FALSE

builtClassifiers       <- TRUE
writeMetFamilyProjects <- FALSE ###################TRUE
calculateRMDstatistics <- FALSE
computeFragmentFisherTest <- FALSE

writeClassifiers <- TRUE
writeResults     <- TRUE

outSuffix <- ""

# Replicates
mergeDuplicatedSpectra              <- TRUE
takeSpectraWithMaximumNumberOfPeaks <- FALSE

# Classes
classOfClass <- c(
	"ChemOnt|MainClass",   # 1
	"ChemOnt|AllClasses",  # 2
	"ChemOnt|Substituent", # 3
	"ChEBI|Identified",    # 4
	"ChEBI|Predicted",     # 5
	"Scaffold"             # 6
)[[2]]
#thisClass <- "Organic compounds; Lipids and lipid-like molecules; Prenol lipids; Terpene lactones; Sesquiterpene lactones"
thisClass <- NULL

# Postprocessing
unitResolution <- FALSE

# Constraints
splitClasses <- FALSE
splitClassesParameterSet <- list(
	minimumNumberOfChildren = 5,
	maximumNumberOfPrecursors = 1000,
	distanceMeasure = "Jaccard (intensity-weighted)",
	#distanceMeasure = "Jaccard",
	clusterMethod = "ward.D"
)

thisParameterSet <- list(
	## parse msp
	minimumIntensityOfMaximalMS2peak                  = 000,
	minimumProportionOfMS2peaks                       = 0.05,
	neutralLossesPrecursorToFragments                 = TRUE,
	neutralLossesFragmentsToFragments                 = FALSE,
	## built fragment matrix
	mzDeviationAbsolute_grouping                      = 0.01,
	mzDeviationInPPM_grouping                         = 10,
	doMs2PeakGroupDeisotoping                         = TRUE,
	mzDeviationAbsolute_ms2PeakGroupDeisotoping       = 0.01,
	mzDeviationInPPM_ms2PeakGroupDeisotoping          = 10,
	proportionOfMatchingPeaks_ms2PeakGroupDeisotoping = 0.9
)

# Box parameters
parameterSetAll <- list(
	# I/O
	progress                          = progress,
	outDetail                         = outDetail,
	resultFolderForClassifiers        = resultFolderForClassifiers,
	resultFolderForMetfamilyProjects  = resultFolderForMetfamilyProjects,
	writeClassifiers                  = writeClassifiers,
	writeResults                      = writeResults,
	outSuffix                         = outSuffix,
	maximumNumberOfScores             = maximumNumberOfScores,
	removeRareFragments               = removeRareFragments,
	builtClassifiers                  = builtClassifiers,
	writeMetFamilyProjects            = writeMetFamilyProjects,
	calculateRMDstatistics            = calculateRMDstatistics,
	
	# Classes
	mergeDuplicatedSpectra              = mergeDuplicatedSpectra,
	takeSpectraWithMaximumNumberOfPeaks = takeSpectraWithMaximumNumberOfPeaks,
	classOfClass                        = classOfClass,
	thisClass                           = thisClass,
	splitClasses                        = splitClasses,
	splitClassesParameterSet            = splitClassesParameterSet,
	##computeFragmentFisherTest         = computeFragmentFisherTest,
	
	# Repeated random subsampling validation
	minimumNumberOfPosSpectraPerClass    = minimumNumberOfPosSpectraPerClass,
	minimumNumberOfNegSpectraPerClass    = minimumNumberOfNegSpectraPerClass,
	numberOfDataSetDecompositions        = numberOfDataSetDecompositions,
	proportionTraining                   = proportionTraining,
	fragmentColumnSelectionMethod        = fragmentColumnSelectionMethod,
	minimumProportionOfPositiveFragments = minimumProportionOfPositiveFragments,
	
	# Postprocessing
	unitResolution = unitResolution,
	
	# Cache
	reParseMsp              = reParseMsp,
	reProcessAnno           = reProcessAnno,
	reProcessLibrary        = reProcessLibrary,
	reProcessFragmentMatrix = reProcessFragmentMatrix,
	
	# Constraints
	# Library one
	annoFile          = annoFile,
	thisLibrary       = thisLibrary,
	thisParameterSet  = thisParameterSet,
	thisMethod        = thisMethod
)



# ---------- MFam Classifier ----------
runTest(parameterSetAll = parameterSetAll)


# Usage: type in command line: Rscript imageSynth.R [filenames of images]
#
Arguments <- commandArgs(trailingOnly = T)
setwd('.')
library(png)
library(jpeg)
library(tiff)
#-------- Parse arguments
parseArg <- function( args ){
	Xtr <- 0; Ytr <- 0; FoV <- 0; calFlag <- F; LCH <- c(); tfnFlag <- F
	argNum <- length(args)
	fileNum <- argNum
	for( index in 1:argNum ){
		if(substr(args[index], 1,2) == "-X"){ Xtr <- as.numeric(substring(args[index], 3));  fileNum <- fileNum - 1}
		if(substr(args[index], 1,2) == "-Y"){ Ytr <- as.numeric(substring(args[index], 3));  fileNum <- fileNum - 1}
		if(substr(args[index], 1,2) == "-F"){ FoV <- as.numeric(substring(args[index], 3));  fileNum <- fileNum - 1}
		if(substr(args[index], 1,2) == "-L"){ LCH <- as.integer(unlist(strsplit(substring(args[index], 3),',')));  fileNum <- fileNum - 1} # LRGB L channel frames
		if(substr(args[index], 1,2) == "-C"){ calFlag <- T;  fileNum <- fileNum - 1}    # commet tracking calibration
		if(substr(args[index], 1,2) == "-T"){ tfnFlag <- T;  fileNum <- fileNum - 1}    # transfer function for contrast
	}
	return( list(calFlag = calFlag, tfnFlag = tfnFlag, Xtr = Xtr, Ytr = Ytr, LCH = LCH, FoV = FoV, fname = args[(argNum - fileNum + 1):argNum]))
}
#-------- Identify image file format and read
imageType <- function(fname){
	header <- readBin(fname, what='raw', n=8)
	if( isJPEG(header) ){	return(readJPEG(fname))}
	if( isPNG(header) ){	return(readPNG(fname)[,,1:3])}
	if( isTIFF(header) ){	return(readTIFF(fname)[,,1:3])}
	cat("Format is other than JPEG, PNG, or TIFF\n");	return(-1)
}
#-------- Identify image format (JPEG?)
isJPEG <- function(header){
	headKey <- as.raw(c(0xff, 0xd8))
	for( index in 1:length(headKey)){
		if( headKey[index] != header[index] ){	return(FALSE)}
	}
	return(TRUE)
}
#-------- Identify image format (PNG?)
isPNG <- function(header){
	headKey <- as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))
	for( index in 1:length(headKey)){
		if( headKey[index] != header[index] ){	return(FALSE)}
	}
	return(TRUE)
}
#-------- Identify image format (TIFF?)
isTIFF <- function(header){
	headKey <- as.raw(c(0x00, 0x2a))
	for( index in 1:length(headKey)){
		if( headKey[index] != header[index+2] ){	return(FALSE)}
	}
	return(TRUE)
}
#-------- Extract image profile to register multiple images
XYprofile <- function(intensity){
	Xprofile <- apply(intensity, 2, which.max)
	Yprofile <- apply(intensity, 1, which.max)
	return( list(X=Xprofile, Y=Yprofile) )
}
#-------- Determine image shifts using cross correlation functions
crossCorr <- function( X, Y ){
	pixNum <- length(X)
	halfNum <- floor(pixNum/2)
	XF <- fft(X, inverse=F);	XF[1] <- 0.0
	YF <- fft(Y, inverse=F);	YF[1] <- 0.0
	XYF <- XF * Conj(YF)
	CF <- fft( XYF, inverse=T)
	index <- c( 0:halfNum, (halfNum-pixNum+1):(-1))
	# plot(index, Mod(CF), type='s')
	return( index[which.max(Mod(CF))] )
}
#-------- Indexing image pointer for shifting
shiftRange <- function( dimension, shift=0 ){
	if(shift == 0){	return(1:dimension)}
	if(shift > 0){ return( c( (shift+1):dimension, (1:shift))) }
	return(c( (dimension+shift+1):dimension, 1:(dimension+shift)) )
}
#-------- Shift image in X and Y direction
imXYshift <- function(image, shiftX=0, shiftY=0){
	Xrange <- shiftRange( nrow(image), shiftX)
	Yrange <- shiftRange( ncol(image), shiftY)
	return( image[Xrange, Yrange] )
}
#-------- Image Flatter
imFlat <- function(image, FoV){
    NX <- nrow(image); NY <- ncol(image)
    pitch <- pi* FoV / sqrt(NX^2 + NY^2) / 180.0              # radian per pixel
    Correction <- 1.0 / cos(pitch* sqrt(outer( ((-NX/2 + 0.5):(NX/2 - 0.5))^2, rep(1.0, NY)) + outer( rep(1.0, NX), ((-NY/2 + 0.5):(NY/2 - 0.5))^2)))^2
    cat(sprintf('Correction[max, min] = %f %f\n', max(Correction), min(Correction)))
    return(Correction* (image - min(image)))
}
#-------- Image Scale : set (0, 1]
imScale <- function(image){
    offset <- range(image)
    scale <- diff(offset)
    scaleImage <- image - offset[1]
    return(scaleImage/scale)
}
#-------- Image Contrast
imContrast <- function(image){
    refLevel <- mean(image)
    sdLevel  <- sd(image)
    contImage <- atan( (image - refLevel)/ sdLevel )
    offset <- range(contImage)
    return((contImage - offset[1]) / diff(offset))
}
#-------- Procedure
argList <- parseArg(Arguments)
fileNum <- length(argList$fname)
FoV     <- argList$FoV
outFname <- sprintf("%s_synth.tiff", argList$fname[1])
cat(sprintf('Stack %d frames and save as %s.\n', fileNum, outFname))
#-------- Classify L and RGB files
LCHList <- argList$LCH
numLCH <- length(LCHList)
RGBList <- setdiff(seq(fileNum), LCHList)
numRGB <- length(RGBList)
#-------- Reference Image
refRGB <- imageType(argList$fname[RGBList[1]])			# Read reference image
refProfile <- XYprofile(refRGB[,,1] + refRGB[,,2] + refRGB[,,3])	# Use green channel
accumRGB <- refRGB						# Image buffer to accumulate
if( argList$calFlag ){ accumRGB[,,1] <- 0.5*accumRGB[,,1];  accumRGB[,,2] <- 0.7*accumRGB[,,2]}
#-------- RGB Loop for non-reference images
for(index in 2:numRGB){
	currentRGB <- imageType(argList$fname[RGBList[index]])		# Read image
	if( argList$calFlag ){ currentRGB[,,3] <- 0.5* currentRGB[,,3]; currentRGB[,,2] <- 0.7* currentRGB[,,2]}
	currentProfile <- XYprofile( currentRGB[,,1] + currentRGB[,,2] + currentRGB[,,3] )		# Use green channel for image shift
	Xlag <- crossCorr( refProfile$X, currentProfile$X)	# Image shift in X axis
	Ylag <- crossCorr( refProfile$Y, currentProfile$Y)	# Image shift in Y axis
	#---- Comet Tracker
	Xlag <- Xlag - floor( (RGBList[index] - 1)* argList$Xtr / (fileNum - 1))
	Ylag <- Ylag + floor( (RGBList[index] - 1)* argList$Ytr / (fileNum - 1))
	cat(sprintf("RGB[%d/%d] %s: Shift (%d, %d) pixels in (X, Y).\n", index, numRGB, argList$fname[RGBList[index]], Xlag, Ylag))
	#-------- Shift and Accumurate image
	for(colIndex in 1:3){
		accumRGB[,,colIndex] <- accumRGB[,,colIndex] + imXYshift(currentRGB[,,colIndex], -Ylag, -Xlag)
	}
}
#-------- LCH Loop
if(numLCH > 0){
    accumLCH <- 0.0* accumRGB[,,1]
    for(index in 1:numLCH){
    	currentLCH <- imageType(argList$fname[LCHList[index]])		# Read image
    	currentProfile <- XYprofile( currentLCH[,,1] + currentLCH[,,2] + currentLCH[,,3] )		# Use red channel for image shift
    	Xlag <- crossCorr( refProfile$X, currentProfile$X)	# Image shift in X axis
    	Ylag <- crossCorr( refProfile$Y, currentProfile$Y)	# Image shift in Y axis
    	cat(sprintf("LCH[%d/%d] %s: Shift (%d, %d) pixels in (X, Y).\n", index, numLCH, argList$fname[LCHList[index]], Xlag, Ylag))
        accumLCH <- accumLCH + imXYshift(currentLCH[,,1], -Ylag, -Xlag)
    }
}
#------- Image Flattener
if( FoV > 0.0 ){
    cat('Image flattening...\n')
    for(color_index in 1:3){
        accumRGB[,,color_index] <- imFlat( accumRGB[,,color_index], FoV )
    }
    if(numLCH > 0){ accumLCH <- imFlat(accumLCH, FoV) }
}
#------- Image normalization
transferFn <- imScale
if(argList$tfnFlag){ transferFn <- imContrast }
scaleRGB <- transferFn(accumRGB)
#------- LRGB composit
if(numLCH > 0){
    sumRGB <- (accumRGB[,,1] + accumRGB[,,2] + accumRGB[,,3])
    scaleLCH <- transferFn(accumLCH)
    scaleSUM <- transferFn(sumRGB) 
    LCH <- 0.5*(scaleLCH + scaleSUM)
    for(color_index in 1:3){
        accumRGB[,,color_index] <- LCH* scaleRGB[,,color_index]
    }
} else { accumRGB <- scaleRGB }
if(argList$tfnFlag){ accumRGB <- accumRGB^0.6 }
#-------- Save to PNG
#writePNG(accumRGB, outFname)
writeTIFF(accumRGB, sprintf("%s_synth.tiff", outFname), bits.per.sample=16 )

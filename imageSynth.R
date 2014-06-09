# Usage: type in command line: Rscript imageSynth.R [filenames of images]
#
fname <- commandArgs(trailingOnly = T)
setwd('.')
library(png)
#-------- Identify image file format and read
imageType <- function(fname){
	header <- readBin(fname, what='raw', n=8)
	if( isJPEG(header) ){	library(jpeg);	return(readJPEG(fname))}
	if( isPNG(header) ){	library(png);	return(readPNG(fname))}
	if( isTIFF(header) ){	library(tiff);	return(readTIFF(fname))}
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
	headKey <- headKey <- as.raw(c(0x00, 0x2a))
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

#-------- Procedure
fileNum <- length(fname)

#-------- Reference Image
refRGB <- imageType(fname[1])			# Read reference image
refProfile <- XYprofile(refRGB[,,2])	# Use Green channel
accumRGB <- refRGB						# Image buffer to accumulate

#-------- Loop for non-reference images
for(index in 2:fileNum){
	currentRGB <- imageType(fname[index])				# Read image
	currentProfile <- XYprofile( currentRGB[,,2] )		# Use green channel for image shift
	Xlag <- crossCorr( refProfile$X, currentProfile$X)	# Image shift in X axis
	Ylag <- crossCorr( refProfile$Y, currentProfile$Y)	# Image shift in Y axis
	cat(sprintf("[%d] %s: %d pixel shift in X,  %d pixel shift in Y\n", index, fname[index], Xlag, Ylag))
	
	#-------- Shift and Accumurate image
	for(colIndex in 1:3){
		accumRGB[,,colIndex] <- accumRGB[,,colIndex] + imXYshift(currentRGB[,,colIndex], -Ylag, -Xlag)
	}
}

#------- Image normalization
imageRange <- range(accumRGB)
accumRGB <- (accumRGB - imageRange[1]) / diff(imageRange)

#-------- Save to PNG
writePNG(accumRGB, sprintf("%s_synth.png", fname[1]))
#writeTIFF(accumRGB, sprintf("%s_synth.tiff", fname[1]), bits.per.sample=16 )

imageSynth
==========

Shift and average multiple images (JPEG, PNG, or TIFF), mainly for astrophotos

Function:
	Read specified images, determine image shifts, average them, and write into a new PNG file.

Requirements:
	R with libraries of jpeg, png, and tiff

Usage: in command line, type
	Rscript imageSynth.R [file names of images]
	e.g. Rscript imageSynth.R *.jpg

Limitations
 1. Pixel sizes of image files must be the same.


See also:
	Usage in Japanese: http://d.hatena.ne.jp/kamenoseiji/20140609/1402309169
	GitHub repository: https://github.com/kamenoseiji/imageSynth

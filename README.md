imageSynth
==========

Shift and average multiple images (JPEG, PNG, or TIFF), mainly for astrophotos

Function:
	Read specified images, determine image shifts, average them, and write into a new PNG file.

New Feature:
    Comet tracking is now capable. Use -C option to measure the motion, and then -X -Y options to track the comet motion.

Requirements:
	R with libraries of jpeg, png, and tiff

Usage: in command line, type
	Rscript imageSynth.R [-Xxtr] [-Yytr] [-C] [file names of images]
	e.g. (1) Rscript imageSynth.R *.jpg
              This is a standard use to stack all jpg files in the working directory.

         (2) Rscript imageSynth.R -C FirstFrame.jpg LastFrame.jpg
              To measure the motion of a comet between the first and the last frame. The first and last frame images are registered in blue and red colors, respectively. Measure the positional difference in the registered image and put in the -X and -Y options as described in (3).

         (3) Rscript imageSynth.R -X-45 -Y29 *.jpg
              To track comet motion. The pixel values should be specified with the -X and -Y options (without space).

Limitations
 1. Pixel sizes of image files must be the same.
 2. For the comet tracking, the motion is presumed to be straight at a constant speed. Time intervals of multiple frames should be constant.

See also:
	Usage in Japanese: http://d.hatena.ne.jp/kamenoseiji/20140609/1402309169
	GitHub repository: https://github.com/kamenoseiji/imageSynth

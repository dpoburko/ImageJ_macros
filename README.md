# ImageJ_macros
Usefull macros for ImageJ (Fiji) for a variety of jobs.

This repository holds a collection of macros that our lab has written for ImageJ to facility daily Image analysis tasks. The degree of documentation for each macro varies. Most will have explanatory notes in the initial comments of the code. 

Almost all are written to work on 2D images or image stacks and hyperstacks. 

Feel free to contact us if you run into problems with these macros. dpoburko@sfu.ca

## addFormFactorToResults_.ijm

Does what it says. Add Form Factor of ROIs to the results table.

```ff = pow( getResult("Perim.", j),2) / ( 4*PI*getResult("Area", j)  );```

## findNearestROIs_v2.ijm

This macro uses a brute force approach to determine the nearest neighbour distance between ImageJ ROIs. 
Upto ~1000 ROIs, this is pretty quick, comparable to using [R's nn2](https://www.rdocumentation.org/packages/RANN/versions/2.6.1/topics/nn2) k-tree based nearest neighbour search.

### Usage:
1. Select the number of nearest neighbours to be calculated for each ROI.
2. Select whether distances are calculated from the center of ROIs or betweeen the perimeter of ROIs. The later can be really useful for objects like cell nuclei.

![multi-panel figure shows find Nearest ROIs dialog, labelled image and results table](https://github.com/dpoburko/ImageJ_macros/blob/master/images/findNearestROIs_v2_composite.png)
 
## FFT_Aligner_v5d.ijm & FFT_Aligner_v5d_batchInterface.ijm

The FFT_Aligner uses the principle of Fourier Transform and cross-correlation to determine the optimal rigid translation to align a stack of images across color channels, slices or frames. It is similiar in function to Guillaume Jacquemet's [Fast4DReg](https://github.com/guijacquemet/Fast4DReg). Fast4DReg typically runs slightly faster than FFT_Aligner and can be installed using the Fiji updating system. FFT_Aligner handles some stacks slightly more faithfully in our hands and uses ImageJ's native Fourier Math functions. 

### Example: HeLa cells expressing H2B-RFP imaged at 10x on a IncuCyte microscope system over 50 hours.
![HeLa cells expressing H2B-RFP. Left is the raw movie. Right is aligned](https://github.com/dpoburko/ImageJ_macros/blob/master/images/DPC181_A3_1_crop_byFrame%2BfftAligned.gif)

### Usage & Performance:
A simple user interface for an open image allows the user to select:
1. determine whethe the stack will be alinged by color, slice (Z), or frame (t). 
2. The reference image (speficic or image-by-image)
3. The size of the portion of the image used for alignment. Smaller is fast but often less accurate.
4. Whether the subregion aligned is centred or positions by the user
5. The ability to sub or super sample the image for faster or more accurate alignment
6. size of fonts used to label of offsets as overlays on the aligned image
7. Bandpass filtering which can sometimes improve accuracy at the cost of time.
8. Cropping the image to the minimum size with no blank borders
9. Whether or not to plot the x & y offset

Accuracy tends to be comparable with FAST4DReg in our hands. Some images register better with FAST4DReg, others align better with FFT Aligner. FAST4DReg is however just about always faster. This is likely related to FFT Aligner using ImageJ's native FFT math. 

![User dialog box, summary of execution time, and summary of accuracy of the macro](https://github.com/dpoburko/ImageJ_macros/blob/master/images/fftAligner_composite.png)

## multiChannel_profiles.ijm

This macro quickly plots a line profile on the current frame and slice of a mulichannel image (update 5 channels currenty). The line profile can be drawn with  raw intensity values or intensity values normalized between 0 -1 for each channel. Results show line intensity values and r<sup>2</sup> correlation coefficients for the profile of each channel pair.

![Multi-channel image of a cell labelled for its membrane, nucelus and phagocytosed cells with a line drawn across it. Plots of raw and normalized intensity profiles are shown with an example of the results available in the Results table](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-img%26plots%26results.png)

The user dialog allow setting the output graph size, running background subtraction before measuring profiles and selecting which channels to plot and what color to plot them as. 

![User dialog for multiChannel_profiles.ijm](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-dialog.png)



## ND2_open_multisite_and_save_tif_v1b.ijm

Using the [Bioformats plugin](https://imagej.net/formats/bio-formats) to read in multi-position .ND2 from a Nikon microscope, this macro will batch process a folder of .ND2 and save the individual positions as .tiff stacks (multi-channel, Z-stacks if present). 



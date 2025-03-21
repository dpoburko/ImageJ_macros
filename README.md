# ImageJ_macros
Usefull macros for ImageJ (Fiji) for a variety of jobs.

This repository holds a collection of macros that our lab has written for ImageJ to facility daily Image analysis tasks. The degree of documentation for each macro varies. Most will have explanatory notes in the initial comments of the code. 

Almost all are written to work on 2D images or image stacks and hyperstacks. 

Feel free to contact us if you run into problems with these macros. dpoburko@sfu.ca

## addFormFactorToResults_.ijm

Does what it says. Add Form Factor of ROIs to the results table.

```ff = pow( getResult("Perim.", j),2) / ( 4*PI*getResult("Area", j)  );```

## assignROIsToLargerROIs_batch_v1b.ijm

This macro asks the user to provide parts of ROI set file names that are unique to small and large ROIs based on whether the centroid of a smaller ROI lies within a larger ROI. This was written for fairly small subcellular puncta, and this approach might not be suitable for some applications where a significant portion of a smaller ROI sits outside the larger ROI. For those cases, we suggest you have a look at our [MINER macro](https://github.com/dpoburko/MINER) described in [Kalkhoran et al 2018 AJP Heart and Circ Physiol](https://pubmed.ncbi.nlm.nih.gov/30311774/).  

It will try to match ROIs to a series of images assuming that images have a name like image1.tif, image2.tif (etc.) and ROI files are named as image1_A.zip, image2_A.zip... and image1_B.zip, image2_B.zip..

The set of "smaller" ROIs (e.g. mitochondria or nuclei) for each image in the working folder will be assigned to "larger" ROIs (e.g. cell membrane). ROIs that are outside of any larger ROI are abandoned.  

Images coming.

## findNearestROIs_v2.ijm

This macro uses a brute force approach to determine the nearest neighbour distance between ImageJ ROIs. 
Upto ~1000 ROIs, this is pretty quick, comparable to using [R's nn2](https://www.rdocumentation.org/packages/RANN/versions/2.6.1/topics/nn2) k-tree based nearest neighbour search.

### Usage:
1. Select the number of nearest neighbours to be calculated for each ROI.
2. Select whether distances are calculated from the center of ROIs or betweeen the perimeter of ROIs. The later can be really useful for objects like cell nuclei. Both measures will be shown in the results, but distance ranking uses one of the other.

![multi-panel figure shows find Nearest ROIs dialog, labelled image and results table](https://github.com/dpoburko/ImageJ_macros/blob/master/images/findNearestROIs_v2_composite.png)
 
## FFT_Aligner_v5d.ijm & FFT_Aligner_v5d_batchInterface.ijm

The FFT_Aligner uses the principle of Fourier Transform and cross-correlation to determine the optimal rigid translation to align a stack of images across color channels, slices or frames. It is similiar in function to Guillaume Jacquemet's [Fast4DReg](https://github.com/guijacquemet/Fast4DReg). Fast4DReg typically runs slightly faster than FFT_Aligner and can be installed using the Fiji updating system. FFT_Aligner handles some stacks slightly more faithfully in our hands and uses ImageJ's native Fourier Math functions. 

### Example: HeLa cells expressing H2B-RFP imaged at 10x on a IncuCyte microscope system over 50 hours.
![HeLa cells expressing H2B-RFP. Left is the raw movie. Right is aligned](https://github.com/dpoburko/ImageJ_macros/blob/master/images/DPC181_A3_1_crop_byFrame%2BfftAligned.gif)

### Usage:
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

### Performance:
Accuracy tends to be comparable with FAST4DReg in our hands. Some images register better with FAST4DReg, others align better with FFT Aligner. FAST4DReg is however just about always faster. This is likely related to FFT Aligner using ImageJ's native FFT math. 

### Batch Processing:
Run FFT_Aligner_v5d_batchInterface.ijm with FFT_Aligner_v5d.ijm saved in the same folder
A very similar user dialog will prompt you to select a folder of images to analyze.

![User dialog box, summary of execution time, and summary of accuracy of the macro](https://github.com/dpoburko/ImageJ_macros/blob/master/images/fftAligner_composite.png)

## IncuCyte Helper Macro:
We have created a series of macros to help with turning exported IncuCyte images into multi-channel stacks. We assume that individual images have been exported from an Incucyte

### IncuCyte_0_listWellsAndPositions_v2c.ijm
 Assumes file names are formatted as ExperimentName_channelName_Well_Position_00d00h00m.tif
 Parses file names, giving use option to indicate which channelNames are Channel1, Channel2, etc, and the associate wells
 Creates a .csv file used by IncuCyte_1_imgsToStacks_1f.ijm
 
### IncuCyte_1_imgsToStacks_1f.ijm
 Prompts user to select a folder containing images and the .csv file generated by IncuCyte_0_listWellsAndPositions_v2c.ijm
 Creates times series tif stacks

### IncuCyte_labelSlicesWithTime.ijm
 
## measureAllChannelsWithMatchedROIs_2.4.3.ijm
 Prompts user to select a folder
 Options to analyze any of up to 6 channels
 Can measure best focus plane or maximal intensity projection for Z-stacks
 ROIs must contain an images file name less the file extension
 ROIs can contain some unique text that defines one of several sets of ROIs that match the images (i.e. nucleus_, nucSurround_)
 ROI.zip files that have a single real ROI can also contain a dummy ROI to allow the common .zip file type to be used, where dummy ROIs are recognized and ignored based on a name or small size
 Rolling ball substraction can be executed during measurement
 
## multiChannel_profiles.ijm

This macro quickly plots a line profile on the current frame and slice of a mulichannel image (update 5 channels currenty). The line profile can be plotted with  raw intensity values or intensity values normalized between 0 -1 for each channel. 

**Results:** show line intensity values and r<sup>2</sup> correlation coefficients for the profile of each channel pair.

![Multi-channel image of a cell labelled for its membrane, nucelus and phagocytosed cells with a line drawn across it. Plots of raw and normalized intensity profiles are shown with an example of the results available in the Results table](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-img%26plots%26results.png)

The user dialog allow setting the output graph size, running background subtraction before measuring profiles and selecting which channels to plot and what color to plot them as. 

![User dialog for multiChannel_profiles.ijm](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-dialog.png)


## ND2_open_multisite_and_save_tif_v1b.ijm

Using the [Bioformats plugin](https://imagej.net/formats/bio-formats) to read in multi-position .ND2 from a Nikon microscope, this macro will batch process a folder of .ND2 and save the individual positions as .tiff stacks (multi-channel, Z-stacks if present). 

## plotMultipleZaxisProfiles_v1.ijm
This macros needs a Z-stack or time series with ROIs in the ROI manager. 
The user can choose:
1. Color palettes for the resulting plot of each ROI's intensity
2. Background color of the plot
3. Line thickness to be plotted
4. To plot raw values or values normalized to the min and max of each ROI.
![User Dialog box, time or z stack with 5 regions of interest, resulting plot](https://github.com/dpoburko/ImageJ_macros/blob/master/images/plotMultipleZaxisProfiles_v1.ijm_triple.png)

## renameFiles.ijm
While ImageJ might seem like an odd environment to batch process file names, that can be extremely usedful when preparing images and roi files for batch processing. 
1. 'Old string' is replaced with 'New string' in a selected folders, with the option to recursively replace in subfolders too.
2. adding ~ symbols before or after your old string will replace flanking wildcards
3. adding # at the end of New string will add a padded sequence of numbers with a user-defined start index from alphabetically sorted file names
4. User can specify whether to modify all files or only a specific type (currently .tif, .tiff, .zip., .csv,.nd2,.jpg, .doc, .docx)
5. The user can opt to include the file extension in the name changes (e.g. output.log → results.txt)

![User Dialog Box for rename files macro](https://github.com/dpoburko/ImageJ_macros/blob/master/images/renameFiles.png)

## stardist_on_folder_v1m.ijm
This macro allows the user to run stardist (https://github.com/stardist/stardist) on folder of multi-channel images, with the user dialog largely replicating the layout of the standard stardist user interface
The user can specify the channel that is analyzed
Users can use the versatile_fluorescent_nuclei model or specify their own model by indicating the folder where it is located.
A .csv file can be saved with basic metrics determined for the new stardist ROIs along with intensity information for all other channels in the images.
Time series are automatically supported.

![User dialog box for startdist on folder](https://github.com/dpoburko/ImageJ_macros/blob/master/images/stardist_on_folder_UI.png)

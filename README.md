# ImageJ_macros
A Usefull macros for ImageJ (Fiji)

This repository holds a collection of macros that our lab has written for ImageJ to facility daily Image analysis tasks. The degree of documentation for each macro varies. Most will have explanatory notes in the initial comments of the code. 

Almost all are written to work on 2D images or image stacks and hyperstacks. 

Feel free to contact us if you run into problems with these macros. dpoburko@sfu.ca

## multiChannel_profiles.ijm

This macro quickly plots a line profile on the current frame and slice of a mulichannel image (update 5 channels currenty)

![Multi-channel image of a cell labelled for its membrane, nucelus and phagocytosed cells with a line drawn across it ](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-rotated.png))


The line profile can be drawn with intensity values normalized between 0 -1 for each channel: 

![Resulting line profile where each channel is shown normalized from min to max as 0 to 1](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-plot_norm.png)

Or the line profile can be drawn with raw intensity values : 

![Resulting line profiled with raw values](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-plot_raw.png)

The user dialog allow setting the output graph size, running background subtraction before measuring profiles and selecting which channels to plot and what color to plot them as. 

![User dialog for multiChannel_profiles.ijm](https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-dialog.png)

Results show line intensity values and r<sub>2</sup> correlation coefficients for the profile of each channel pair

![Example of output results] (https://github.com/dpoburko/ImageJ_macros/blob/master/images/multiChannel_profiles_Example-Results66pct.png)

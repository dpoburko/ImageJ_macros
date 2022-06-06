/*
SENAN F. 
Created Mar-2014
Edited and modified - D Poburko 
v1.1 DP - added minimum pixel & rolling ball subtraction for image to be analyzed
v1.4.8.3 - replace dilation with distance map for dilated nucleus
v2.0 - re-arranging to allow selection of multiple ROI types per channel
	- so far have modified dialog
	- need to laop through all analysis options in one large array
	- add choice to make cell ROIs from nuclear voronoi (effectively v lg radius of nuclear surround)
	- add options to use local max as particle search .... on second thought, this should be roled into mulitple thresholds batch, where cell ROIs are generated here
	- sort out how to have multiple analyses show up on same line of the results table (probably requires searching results table for given image name) and add col for ch, roi Shape, and metrics
	- restore option to find nuc ROIs from z-stack
	- modified method of creating nuc surroundsvoMuch faster now.
v2.5p - need to figur out how to convert text window to results table
v2.6 - 
v2.7 - add ability to call seededClustR from this macro to generate concave hull around nuclei 
	- NB - this was not implemented
v2.8 - fixed bug that prevented nuclear surrounds from being made correctly
     - added option in simple threshold to exclude ROIs on edge of images. Also add indicator colum if ROI touches image edge
v2.9 - fixed previously unrecognized issue with dilated nuclei and presumbaly nuclear surrounds with size >254 resulting in not limit to size     
v3.0 - builds in function to call user defined ROIs. 
v3.1-3.4 - adds option to calculate nuclear NN ROI distances
v3.7 - allow analysis of only custom ROIs (no need for nuclei)
v3.8 - add listing of ROI names in a new column if using user-defined ROIs.
*/

/*------------------------------
Support functions
------------------------------*/
var version = "v3.8";
var RIPAversion = "v1.1";
var gImageNumber = -1;
var gImageFolder  = call("ij.Prefs.get", "dialogDefaults.imageDirectory", "");
var gCurrentImageName = "";
var gOutputImageFolder = "";
var gNuclearImageFolder = "";
var gFftImageFolder = "";
var gImageList;
var gResultFileName = "ROI Intensities.xls";
var gKi67Channel = 2;
var gNuclearChannel = 1;
var gNuclearMinArea = 14000;
var gBallSize = -1;
var gBallSizeMeasured = -1;
var gNucSurroundOrBox = -1;
var gNucSurround = "";
var gKi67ChannelGauss = -1;
var gAnalyzeFFTsets = false;
var excludeOnEdges = true;
var items = newArray("nucleus","box_around_nucleus","dilated_nucleus","nuclear_surround","specifyLabel");
var roiLabels = newArray("nucleus","nucBox","nucDilated","nucSurround","userDefined");
var overwriteROIs = false;
var nucThreshold = -1;
var circThreshold = -1;
var gaussRad = -1;
var minSolid = -1;
var gExpCellNumberStart = 0;
var gUniqueCellIndex = 0;
var gPreviousImgName = "";
var gDoMultipleThresholds = false;
var gDoWaterShed = false;
var gNumAnalyses = 1;
var gDefineNucROIs ="No";
var firstChannel = 1;
var firstRoiShape = items[0];
var endCellsAnalysis1 = 0;
var startCellsAnalysis1 = 0;
var nImgsToProcess = 0;
var usRadius = 1;
var usMask = 1;
var clearFlags = false;
var nucOffSet = 6;
var slices2channels = false;
var verbose = false;
var cellIDBase = 0;
var nNN = 6;
var dMethChoices = newArray("COMs only","COMs & perimeters");
var gRIPAParameters = "[nsds]=2 [stepmthd]=[step size] [nthrorsize]=50 [umt]=-1 [lmt]=100 [trmtd]=none [minps]=400 [maxps]=6000 [mincirc]=0.100 [maxcirc]=1 [minSolidity]=0.100 [maxSolidity]=1 [bgsub]=-1 exclude=20 [nomrg] [svrois] [called]";
// run("RIPA v4.9.1", "[nsds]=2 [stepmthd]=[step size] [nthrorsize]=200 [umt]=4000 [lmt]=200 [trmtd]=none [minps]=400 [maxps]=8000 [mincirc]=0.300 [maxcirc]=1 [minround]=0 [maxround]=1 [bgsub]=-1 [wtshd] exclude=20 [nomrg]");

c1ShapesSelection = items;
analysesToDo = newArray(4*items.length);
itemsDefaults = newArray(items.length);
itemsDefaults = Array.fill(itemsDefaults,-1);
print("\\Clear");
macro "Image Intensity Process" {
	
	requires("1.48h");
	doSetImageFolder();

	//check for current versio of RIPA in Plugins/macros folder
	macrosDir = getDirectory("imagej") + File.separator + "plugins" + File.separator + "Macros";
	macroList = getFileList(macrosDir);
	currRV = newArray();
	for (i = 0; i< macroList.length; i++) {
		m = macroList[i];
		if ((indexOf(m,"RIPA")!=-1) && (indexOf(m,".ijm")!=-1)) {
			currRV = Array.concat(currRV,m);
		}
	}
	
	if (currRV.length == 0) {
		exit("It appears that you do not have a version of RIPA_vX.Y.ijm \n in your Macros folder. Please install this macro \n before continuing \n add link to gitHub");
	}

	// check for a prefs file
	run("Clear Results");
	paraFlist = getParameterFiles(); //checks for a file in the image folder containing preferred image analysis parameters
	Array.print(paraFlist);
	useDefaultsStr = "Define my own parameters or use current defaults";
	if (paraFlist[0]!="") {
			paraFlist = Array.concat(paraFlist,useDefaultsStr);
		if (paraFlist.length==1) {
			pFile = paraFlist[0];
		}
		if (paraFlist.length>=2) {
			Dialog.create("select parameters file");
			Dialog.addChoice("select parameters file",paraFlist,paraFlist[paraFlist.length-1]);
			Dialog.show();
			pFile = Dialog.getChoice();
		}
		run("Clear Results");
		if (pFile!=useDefaultsStr) {
		    open(gImageFolder+pFile);
		    Table.rename(pFile,"Results");
			getParameters();
		}
	}
	
	nucROIsExist = "No";
doNucROIsPrevious = call("ij.Prefs.get", "dialogDefaults.gDefineNucROIs","No");
var doNucROIs = newArray(doNucROIsPrevious,"No","RIPA","simple threshold","user defined");
var gDefineNucROIs = doNucROIs[0]; 
	
	
	for ( i =0; i< gImageList.length; i++) {
		if (( endsWith(gImageList[i], ".zip") == true) || ( indexOf(gImageList[i], "nuc") == true) ) {
			nucROIsExist = "Likely";
			i = gImageList.length;
		}
	}
	
 	// === DIALOG 0 ===================================================================================================================================================
 	// ================================================================================================================================================================
	help1 = "<html>"
     +"<h2>HTML formatted help</h2>"
     +"<font size=+1>
     +"In ImageJ 1.46b or later, dialog boxes<br>"
     +"can have a <b>Help</b> button that displays<br>"
     +"<font color=red>HTML</font> formatted text.<br>"
     +"</font>";

	message = "This macro will help to generate ROIs around puncta of interest in up to 6-channel images \n"
	+ "with up to 12 analysis/channel pairings. It is strongly recommended to start with nuclear ROIs. \n"
	+ "• ROI around reference puncta can be simepl ROIs, boxes, dilated ROIs or 'surrounds' of your ROIs. \n"
	+ "• Large folders of images can be analyzed by multiple instances of ImageJ or computers in parallel. \n"
	+ "• Paste the '0_parameters' file to a new folder to re-use previous options";
	
	Dialog.create("1/4 Set Channels & Regions to Analyze " + version);
	Dialog.addMessage(message );
	Dialog.addSlider("Nuclear or main ROI Channel", 1, 6, parseInt(call("ij.Prefs.get", "dialogDefaults.gNuclearChannel",gNuclearChannel)));
	Dialog.addNumber("number of channel / ROI shape pairings to analyze ",  parseInt(call("ij.Prefs.get", "dialogDefaults.gNumAnalyses",gNumAnalyses)));
	//Dialog.setInsets(0, 20, 0);
	Dialog.addChoice(nucROIsExist + " nuclear ROIs found. (Re)define nuclear ROIs?",doNucROIs,doNucROIs[0]);
	Dialog.addNumber("Find n Nearest Neighbours for each nuclear ROI (0 = off)", parseInt(call("ij.Prefs.get", "dialogDefaults.nNN", "0")));
    Dialog.addChoice("NN distance between reported as: ",dMethChoices,call("ij.Prefs.get", "dialogDefaults.dMethod",  dMethChoices[0]) );
	//Dialog.addCheckbox("use kNN.R script for NN calculations",call("ij.Prefs.get", "dialogDefaults.dokNNR",false));

	Dialog.addCheckbox("run in Batch Mode (doesn't work with multipleThresholds / RIPA) ",call("ij.Prefs.get", "dialogDefaults.gDoBatchMode",true));
	Dialog.addCheckbox("Notify by email when done (requires PC system modifications)", false);
	Dialog.addCheckbox("clear previous analysis 'done' flags", false);
	Dialog.addCheckbox("use verbose logging", false);
	//Dialog.addCheckbox("convert Matlab AIF slices to channels", call("ij.Prefs.get", "dialogDefaults.slices2channels",false));
	Dialog.show();
	gNuclearChannel = Dialog.getNumber();     	call("ij.Prefs.set", "dialogDefaults.gNuclearChannel",gNuclearChannel);
	gNumAnalyses = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.gNumAnalyses",gNumAnalyses); 	
	gDefineNucROIs = Dialog.getChoice();		call("ij.Prefs.set", "dialogDefaults.gDefineNucROIs",gDefineNucROIs); 	  	
	nNN = Dialog.getNumber(); 					call("ij.Prefs.set", "dialogDefaults.nNN", nNN);
	dMethod = Dialog.getChoice(); 				call("ij.Prefs.set", "dialogDefaults.dMethod", dMethod);
	//dokNNR = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.dokNNR", dokNNR);
	dokNNR = false;
	gDoBatchMode = Dialog.getCheckbox();		call("ij.Prefs.set", "dialogDefaults.gDoBatchMode",gDoBatchMode); 	  	
	doSendEmail = Dialog.getCheckbox();  		call("ij.Prefs.set", "dialogDefaults.doSendEmail",doSendEmail); 	
	//doSendEmail = false;
	clearFlags = Dialog.getCheckbox();  		call("ij.Prefs.set", "dialogDefaults.clearFlags",clearFlags); 	
	verbose = Dialog.getCheckbox();  		call("ij.Prefs.set", "dialogDefaults.verbose",verbose); 	
	//slices2channels = Dialog.getCheckbox();  	call("ij.Prefs.set", "dialogDefaults.slices2channels",slices2channels); 	  	
    slices2channels = false;

	//Save parameters to result table for saving in separate file
	run("Clear Results"); //Closes Results table

	setResult("Parameter",nResults,"gNuclearChannel");
	setResult("Values00",nResults-1,gNuclearChannel);
	setResult("Parameter",nResults,"gNumAnalyses");
	setResult("Values00",nResults-1,gNumAnalyses);
	setResult("Parameter",nResults,"gDefineNucROIs");
	setResult("Values00",nResults-1,gDefineNucROIs);
	setResult("Parameter",nResults,"nNN");
	setResult("Values00",nResults-1,nNN);
	setResult("Parameter",nResults,"dMethod");
	setResult("Values00",nResults-1,dMethod);
	setResult("Parameter",nResults,"dokNNR");
	setResult("Values00",nResults-1,dokNNR);
	setResult("Parameter",nResults,"gDoBatchMode");
	setResult("Values00",nResults-1,gDoBatchMode);
	setResult("Parameter",nResults,"doSendEmail");
	setResult("Values00",nResults-1,doSendEmail);
	setResult("Parameter",nResults,"clearFlags");
	setResult("Values00",nResults-1,clearFlags);
	setResult("Parameter",nResults,"slices2channels");
	setResult("Values00",nResults-1,slices2channels);

		
 	// === DIALOG 1 = define nuclear ROIs ==================================================================================================================================================
 	// ================================================================================================================================================================
	help2 = "<html>"
     
     +"<font size=+1>
     +"<b>Typical nuclear areas in pixels for Nikon TiE and Andor Zyla5.5:</b><br>"
     +"<font size=-1>
     +" <br>"
     +"<b>A7r5:</b> 2N cells 150-300 µm<sup>2</sup>. 8N cells 600-1200 µm<sup>2</sup> <br>"
     +"minimum nucleae area in pixel<sup>2</sup>: >300 @ 10X, >1400 20X, >3000 @ 30X, >35,000 @ 100x <br>" 
	 +" <br>"
     +"<b>N2a cells:</b> min ~### µm<sup>2</sup> <br>"
     +"minimum nucleae area in pixel<sup>2</sup>: 10X ?, 20X ?, 30X ?, 100x ?  <br>"
     +" <br>"
     +"<font color=blue> Consider smaller sizes if you suspect cells are apoptotic.</font> <br>" ;

	if (gDefineNucROIs == doNucROIs[3]) {
		Dialog.create("2/4 Define nuclear ROIs by a simple threshold");
		Dialog.setInsets(0, 20, 0);
		Dialog.addNumber("_Nuclear Min Area (pixels^2). Examples in help", parseInt( call("ij.Prefs.get", "dialogDefaults.gNuclearMinArea",gNuclearMinArea)));
		Dialog.addToSameRow();
		Dialog.setInsets(0, 20, 0);
		Dialog.addNumber("Threshold for nuclear binarization (-1 = off)",  parseInt(call("ij.Prefs.get", "dialogDefaults.nucThreshold",nucThreshold)));
		Dialog.setInsets(0, 20, 0);
		Dialog.addNumber("Rolling Ball Subtraction diameter for nuclei (-1 = off)",  parseFloat(call("ij.Prefs.get", "dialogDefaults.gBallSize",gBallSize)));
		Dialog.addToSameRow();
		Dialog.addNumber("Guassian blur radius  (-1 = off)",  parseFloat(call("ij.Prefs.get", "dialogDefaults.guassRad",gaussRad)));
		Dialog.setInsets(0, 20, 0);
		Dialog.addNumber("Unsharp Mask: Radius in pixels (-1 = off)",  parseInt(call("ij.Prefs.get", "dialogDefaults.usRadius",usRadius)));
		Dialog.addToSameRow();
		Dialog.addNumber("Strength (0.1-0.9)",  parseFloat(call("ij.Prefs.get", "dialogDefaults.usMask",usMask)));
		Dialog.setInsets(0, 20, 0);
		Dialog.addCheckbox("Watershed close nuclei ",call("ij.Prefs.get", "dialogDefaults.gDoWaterShed",false));
		Dialog.setInsets(0, 20, 0);
	
		Dialog.addNumber("... if circularity < (0.0-1.0) (0 = off)",  parseFloat(call("ij.Prefs.get", "dialogDefaults.circThreshold",circThreshold)));
	
		Dialog.setInsets(0, 20, 0);
		Dialog.addToSameRow();
		Dialog.addNumber("... if solidity < (0.0-1.0) (0 = off)",  parseFloat(call("ij.Prefs.get", "dialogDefaults.minSolid",minSolid)));
		Dialog.addCheckbox("overwrite ROI files ",call("ij.Prefs.get", "dialogDefaults.overwriteROIs",false));
		Dialog.addToSameRow();
		Dialog.addCheckbox("exclude nuclei on edges of images ",call("ij.Prefs.get", "dialogDefaults.excludeOnEdges",false));
		Dialog.addHelp(help2);
		Dialog.show();
		
		gNuclearMinArea = Dialog.getNumber();    	call("ij.Prefs.set", "dialogDefaults.gNuclearMinArea",gNuclearMinArea);
		nucThreshold =  Dialog.getNumber();	      	call("ij.Prefs.set", "dialogDefaults.nucThreshold",nucThreshold);
		gBallSize =  Dialog.getNumber();	      	call("ij.Prefs.set", "dialogDefaults.gBallSize",gBallSize);
		gaussRad =  Dialog.getNumber();		      	call("ij.Prefs.set", "dialogDefaults.gaussRad",gaussRad);
		usRadius =  Dialog.getNumber();	    	  	call("ij.Prefs.set", "dialogDefaults.usRadius",usRadius);
		usMask =  Dialog.getNumber();	      		call("ij.Prefs.set", "dialogDefaults.usMask",usMask);
		gDoWaterShed = Dialog.getCheckbox();	    call("ij.Prefs.set", "dialogDefaults.gDoWaterShed",gDoWaterShed);
		circThreshold =  Dialog.getNumber();	    call("ij.Prefs.set", "dialogDefaults.circThreshold",circThreshold);
		minSolid =  Dialog.getNumber();	  			call("ij.Prefs.set", "dialogDefaults.minSolid",minSolid);
		overwriteROIs = Dialog.getCheckbox();	    call("ij.Prefs.set", "dialogDefaults.overwriteROIs",overwriteROIs);
		excludeOnEdges = Dialog.getCheckbox();	    call("ij.Prefs.set", "dialogDefaults.excludeOnEdges",excludeOnEdges);

		//Save parameters to result table for saving in separate file
		setResult("Parameter", nResults,"define_Nuc_ROIs");
		setResult("Values00", nResults,"simpleThreshold");
		setResult("Parameter",nResults,"gNuclearMinArea");
		setResult("Values00",nResults-1,gNuclearMinArea);
		setResult("Parameter",nResults,"nucThreshold");
		setResult("Values00",nResults-1,nucThreshold);
		setResult("Parameter",nResults,"gBallSize");
		setResult("Values00",nResults-1,gBallSize);
		setResult("Parameter",nResults,"gaussRad");
		setResult("Values00",nResults-1,gaussRad);
		setResult("Parameter",nResults,"usRadius");
		setResult("Values00",nResults-1,usRadius);
		setResult("Parameter",nResults,"usMask");
		setResult("Values00",nResults-1,usMask);
		setResult("Parameter",nResults,"gDoWaterShed");
		setResult("Values00",nResults-1,gDoWaterShed);
		setResult("Parameter",nResults,"circThreshold");
		setResult("Values00",nResults-1,circThreshold);
		setResult("Parameter",nResults,"minSolid");
		setResult("Values00",nResults-1,minSolid);
		setResult("Parameter",nResults,"overwriteROIs");
		setResult("Values00",nResults-1,overwriteROIs);	
		setResult("Parameter",nResults,"excludeOnEdges");
		setResult("Values00",nResults-1,excludeOnEdges);	
	} 

 	// === DIALOG 2a ===================================================================================================================================================
 	// ================================================================================================================================================================

	if (gDefineNucROIs == doNucROIs[2]) {
		gDoMultipleThresholds = true;
		gRIPAParameters1 = call("ij.Prefs.get", "dialogDefaults.gRIPAParameters1","[nsds]=2 [stepmthd]=[step size] [nthrorsize]=100 [umt]=-1 [lmt]=50 [trmtd]=none");
		gRIPAParameters2 = call("ij.Prefs.get", "dialogDefaults.gRIPAParameters2", "[minps]=400 [maxps]=6000 [mincirc]=0.100 [maxcirc]=1 [minsolidity]=0.100 [maxolidity]=1");
		gRIPAParameters3 = call("ij.Prefs.get", "dialogDefaults.gRIPAParameters3", "[bgsub]=-1 exclude=20 [nomrg] [svrois] [called]");
		Dialog.create("2/4 Confirm MultipleThresholds Parameters");
	    Dialog.addMessage("WARNING! Do not select options [svrois] or [called] below. \n This will cause a crash");
	    Dialog.addChoice("version of multipleThresholds used: ",currRV);
	    Dialog.addMessage("Define thresholds: [nsds]=2 [stepmthd]=[step size] [nthrorsize]=100 [umt]=-1 [lmt]=50 [trmtd]=none");
		Dialog.addString("mandatory fields: ", gRIPAParameters1,90);
		Dialog.addMessage("Puncta shapes collected: [minps]=400 [maxps]=6000 [mincirc]=0.100 [maxcirc]=1 [minsolidity]=0.100 [maxsolidity]=1");
		Dialog.addString("mandatory fields",gRIPAParameters2,90);
		Dialog.addMessage("Extra Options: [bgsub]=-1 [wtshd] exclude=20 [cntrs] [nomrg] show [svmsk] thresholds [svrois] [called]");
		Dialog.addString("Simply omit if no value in template: ", gRIPAParameters3,90);
		Dialog.addCheckbox("overwrite ROI files ",call("ij.Prefs.get", "dialogDefaults.overwriteROIs",false));
		Dialog.show();
		RIPAversion = Dialog.getChoice();      call("ij.Prefs.set", "dialogDefaults.RIPAversion",RIPAversion);
		gRIPAParameters1 = Dialog.getString(); call("ij.Prefs.set", "dialogDefaults.gRIPAParameters1",gRIPAParameters1);
		gRIPAParameters2 = Dialog.getString(); call("ij.Prefs.set", "dialogDefaults.gRIPAParameters2",gRIPAParameters2);
		gRIPAParameters3 = Dialog.getString(); call("ij.Prefs.set", "dialogDefaults.gRIPAParameters3",gRIPAParameters3);
		gRIPAParameters = gRIPAParameters1 + " " + gRIPAParameters2 + " " + gRIPAParameters3;
		gRIPAParameters = replace(gRIPAParameters, "  ", " ");
		overwriteROIs = Dialog.getCheckbox();	    call("ij.Prefs.set", "dialogDefaults.gDoWaterShed",overwriteROIs);

		dirIJ = getDirectory("imagej");
		path =  dirIJ+  "plugins" + File.separator + "Macros" + File.separator + "DTP_multiple_thresholdsMacro_"+RIPAversion+".ijm";
		//print(path);
		if (File.exists(path)== false) exit("please install DTP_multiple_thresholdsMacro_"+RIPAversion+" \n to your Macros folder.");

		//Save parameters to result table for saving in separate file
		setResult("Parameter", nResults,"define_Nuc_ROIs");
		setResult("Values00", nResults-1,"RIPA");
		setResult("Parameter",nResults,"gRIPAParameters1");
		setResult("Values00",nResults-1,gRIPAParameters1);
		setResult("Parameter",nResults,"gRIPAParameters2");
		setResult("Values00",nResults-1,gRIPAParameters2);
		setResult("Parameter",nResults,"gRIPAParameters3");
		setResult("Values00",nResults-1,gRIPAParameters3);
	}
	call("ij.Prefs.set", "dialogDefaults.gRIPAParameters",gRIPAParameters); 

	stamp = timeStamp(); //getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);

 	// === DIALOG 2 ===================================================================================================================================================
 	// ================================================================================================================================================================

	minus1 = "-1";
	var roiShapes = newArray(gNumAnalyses);
	var channels = newArray(gNumAnalyses);
	var ballSizes = newArray(gNumAnalyses);
	var gaussRadii = newArray(gNumAnalyses);
	var roiSizes = newArray(gNumAnalyses);
	var threshold32s = newArray(gNumAnalyses);

	  html1 = "<html>"
     +"<h2>Use of rolling ball size:</h2>"
     +".   nucleus - not used <br>"
     +".   box = edge length <br>"
     +".  dilated_nucleus  - pixels of dilation around nucleus with Voronoi limits <br>"
     +".  nuclear_surround - pixels of dilation around nucleus with Voronoi limits <br>"
     +"<br>"
     +"<h2>Typical nuclear sizes</h2>"
     +".    (A7r5, diploid) = ~300 µm diameter<br>"
     +".     ~200px @ 20X, ~300px @ 30X, ~400px @ 40X, ~600px @ 100X "
	 +"</font>";

	dialogName = "3/4 Select Channel & ROI shape pairs";
	if (gNumAnalyses>7) { 
		dialogName= "3/4 Select Channel & ROI shape pairs for first "+minOf(gNumAnalyses,6)+" options";
	}

	it = "initial text";
	
    Dialog.create(dialogName);
	for (i=0; i<minOf(gNumAnalyses,6); i++) {
		Dialog.setLocation(20,20); 
		fallBackShape = items[0];
		defaultShape = call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"shape",items[0]);
		if (arrayFind(items,defaultShape) == false ) defaultShape = items[4]; 
		Dialog.setInsets(15, 0, 0);
		Dialog.addChoice("CHANNEL-SHAPE PAIR "+(i+1)+":  ROI shape", items, defaultShape);	
		Dialog.addToSameRow();
		Dialog.addSlider("Channel", 1, 6, parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"channel",minus1)));
		Dialog.addNumber("Rolling ball subtraction (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"ballSize",minus1)));
		Dialog.addToSameRow();
		Dialog.addNumber("Gaussian blur radius (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"gaussRadii",minus1)));
		Dialog.addNumber("Size (not used for 'nucleus' ROIs): ",parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"roiSize",minus1)));
		Dialog.addToSameRow();
		Dialog.addNumber("32bit threshold (-1=off):" ,parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"threshold32",minus1)));
	}
	
	//Dialog.addMessage("Size for: nucleus - not used, box - edge length \n dilated_nucleus and nuclear_surround - pixels of dilation around nucleus with Voronoi limits");
	Dialog.addMessage("See help for guidelines");
	Dialog.addHelp(html1);
	Dialog.show;
	roiShapes = newArray(gNumAnalyses);  //re-cast roiShapes - bad practice. Try to clean up later

    for (i=0; i<minOf(gNumAnalyses,6); i++) {
    	//print("i: "+i+" roiShapes[i]: "+roiShapes[i]);
		roiShapes[i] = Dialog.getChoice();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"shape",roiShapes[i]);
		channels[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"channel",channels[i]);
		ballSizes[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"ballSize",ballSizes[i]);
		gaussRadii[i] = Dialog.getNumber(); call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"gaussRadii",gaussRadii[i]);
		roiSizes[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"roiSize",roiSizes[i]);
		threshold32s[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"threshold32",threshold32s[i]);
    }

    if (gNumAnalyses>6) {
		dialogName= "3/4 Select Channel & ROI shape pairs for options 7 to " + minOf(gNumAnalyses,12);
	    Dialog.create(dialogName);
		for (i=6; i<minOf(gNumAnalyses,12); i++) {
			Dialog.setLocation(20,20); 
			defaultShape = call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"shape",items[0]);
			if (arrayFind(items,defaultShape) == false ) defaultShape = items[4]; 
			Dialog.setInsets(15, 0, 0);
			Dialog.addChoice("CHANNEL-SHAPE PAIR "+(i+1)+":  ROI shape", items, defaultShape);	
			Dialog.addToSameRow();
			Dialog.addSlider("Channel", 1, 6, parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"channel",minus1)));
			Dialog.addNumber("Rolling ball subtraction (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"ballSize",minus1)));
			Dialog.addToSameRow();
			Dialog.addNumber("Gaussian blur radius (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"gaussRadii",minus1)));
			Dialog.addNumber("Size (not used for 'nucleus' ROIs): ",parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"roiSize",minus1)));
			Dialog.addToSameRow();
			Dialog.addNumber("32bit threshold (-1=off):" ,parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"threshold32",minus1)));
		}
		//Dialog.addMessage("Size for: nucleus - not used, box - edge length \n dilated_nucleus and nuclear_surround - pixels of dilation around nucleus with Voronoi limits");
		Dialog.addMessage("See help for guidelines");
		Dialog.addHelp(html1);
		Dialog.show;
	    for (i=6; i<minOf(gNumAnalyses,12); i++) {
			roiShapes[i] = Dialog.getChoice();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"shape",roiShapes[i]);
			channels[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"channel",channels[i]);
			ballSizes[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"ballSize",ballSizes[i]);
			gaussRadii[i] = Dialog.getNumber(); call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"gaussRadii",gaussRadii[i]);
			roiSizes[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"roiSize",roiSizes[i]);
			threshold32s[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"threshold32",threshold32s[i]);
	    }
    }
		//print("gNumAnalyses: "+gNumAnalyses);
    if (gNumAnalyses>12) {
		dialogName= "3/4 Select Channel & ROI shape pairs for options 13 to " + gNumAnalyses;
	    Dialog.create(dialogName);
		for (i=12; i<gNumAnalyses; i++) {
			Dialog.setLocation(20,20); 
			defaultShape = call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"shape",items[0]);
			if (arrayFind(items,defaultShape) == false ) defaultShape = items[4]; 
			Dialog.setInsets(15, 0, 0);
			Dialog.addChoice("CHANNEL-SHAPE PAIR "+(i+1)+":  ROI shape", items, defaultShape);	
			Dialog.addToSameRow();
			Dialog.addSlider("Channel", 1, 6, parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"channel",minus1)));
			Dialog.addNumber("Rolling ball subtraction (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"ballSize",minus1)));
			Dialog.addToSameRow();
			Dialog.addNumber("Gaussian blur radius (-1=off):",parseFloat(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"gaussRadii",minus1)));
			Dialog.addNumber("Size (not used for 'nucleus' ROIs): ",parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"roiSize",minus1)));
			Dialog.addToSameRow();
			Dialog.addNumber("32bit threshold (-1=off):" ,parseInt(call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"threshold32",minus1)));
		}
		//Dialog.addMessage("Size for: nucleus - not used, box - edge length \n dilated_nucleus and nuclear_surround - pixels of dilation around nucleus with Voronoi limits");
		Dialog.addMessage("See help for guidelines");
		Dialog.addHelp(html1);
		Dialog.show;
	    for (i=12; i<gNumAnalyses; i++) {
			roiShapes[i] = Dialog.getChoice();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"shape",roiShapes[i]);
			channels[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"channel",channels[i]);
			ballSizes[i] = Dialog.getNumber();	call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"ballSize",ballSizes[i]);
			gaussRadii[i] = Dialog.getNumber(); call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"gaussRad",gaussRadii[i]);
			roiSizes[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"roiSize",roiSizes[i]);
			threshold32s[i] = Dialog.getNumber();   call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"threshold32",threshold32s[i]);
	    }
	}
	//Save parameters to result table for saving in separate File.append(string, path)
	roiShapesTxt = ""; channelsTxt = ""; ballSizesTxt = ""; gaussRadiiTxt=""; roiSizesTxt = ""; threshold32sTxt="";
	
	// === DIALOG 3 - optional - GET USER-DEFINED ROI SUFFIXES=========================================================================================================
 	// ================================================================================================================================================================
	getUserShapes = false;
	nUserShapes = 0;
	chForUserShapes = newArray();
	analysesForUserShapes = newArray();
	for (i=0; i<gNumAnalyses; i++) {
		if (indexOf(roiShapes[i],items[4])!=-1) {
			getUserShapes = true;
			nUserShapes++;
			chForUserShapes = Array.concat(chForUserShapes,channels[i]);
			analysesForUserShapes = Array.concat(analysesForUserShapes,i);
		}
	}

var userShapes = newArray(gNumAnalyses);


	if (getUserShapes==true) {	 
		Dialog.create("4/4 Provide names of ROI shapes");
		Dialog.addMessage("This macro will assume that you have defined additional ROIsets with the format suffix_image.zip");
		Dialog.addMessage("If ROI names end in sequential numbers, even if they aren't sorted, they will normally be match to their appropriate nucleus");
		Dialog.addMessage("If an image has no ROIs for this shape, it will be skipped in the analysis.");
		for (i=0; i<nUserShapes;i++) {
			Dialog.addString("roi prefix for analysis " + (analysesForUserShapes[i]+1)+ " on channel " +chForUserShapes[i] , call("ij.Prefs.get", "dialogDefaults.c"+(i+1)+"userShape","someshape_"),30);
		}
		Dialog.show();

		for (i=0; i<nUserShapes;i++) {
			// User-defined ROI suffixes are stored in the roiLabels array for susequent reference
			userShapes[analysesForUserShapes[i]] = Dialog.getString();
			call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"userShape",userShapes[analysesForUserShapes[i]]);
		}
	}
	
	for (i=0; i<gNumAnalyses; i++) {
		rs = roiShapes[i];
		//if (roiShapes[i]!=items[4]) rs = roiShapes[i];
		//if (roiShapes[i]==items[4]) rs = roiLabels[i];
		roiShapesTxt = roiShapesTxt  + rs+ ", ";
		channelsTxt = channelsTxt  + channels[i]+ ", ";
		ballSizesTxt = ballSizesTxt  + ballSizes[i]+ ", ";
		gaussRadiiTxt = gaussRadiiTxt  + gaussRadii[i]+ ", ";
		roiSizesTxt = roiSizesTxt  + roiSizes[i]+ ", ";
		threshold32sTxt = threshold32sTxt  + threshold32s[i]+ ", ";
	}
	
	setResult("Parameter", nResults,"roiShapes");
	setResult("Parameter", nResults,"channels");
	setResult("Parameter", nResults,"ballSizes");
	setResult("Parameter", nResults,"gaussRadii");
	setResult("Parameter", nResults,"roiSizes");
	setResult("Parameter", nResults,"threshold32s");
	setResult("Parameter", nResults,"version");
	setResult("Values00", nResults-7,roiShapesTxt);
	setResult("Values00", nResults-6,channelsTxt);
	setResult("Values00", nResults-5,ballSizesTxt);
	setResult("Values00", nResults-4,gaussRadiiTxt);
	setResult("Values00", nResults-3,roiSizesTxt);
	setResult("Values00", nResults-2,threshold32sTxt);
	setResult("Values00", nResults-1,version);
		
startTime = timeStamp();
saveAs("Results", gImageFolder  + "0parameters_nAnalyses_" + gNumAnalyses +"_rois_" +gDefineNucROIs + "_" + version + "_" + startTime + ".csv");//save to folder with timestamp
updateResults();


	//====== DIALOG 4.: email setings =================================================================================================================================
	//====== DIALOG 4.: email setings =================================================================================================================================
	
	if (doSendEmail == true) {
		  html = "<html>"
	     +"<h2>Windows requirement for sending email via ImageJ</h2>"
    	 +"<font size=+1>
     	+"run powershell.exe as an administator"
	     +"To do this: Type powershell.exe in windows search bar"
    	 +"... right click and select Run as Administrator"
	     +"type: 'Set-ExecutionPolicy RemoteSigned' "
    	 +"</font>";
  
		// Send Emamil Module 1: Place near beginning of code. Might want as an extra option after first dialog
		Dialog.create("Email password");
		Dialog.addMessage("Security Notice: User name and password will not be stored for this operation");
		Dialog.addString("Gmail address to send email - joblo@gmail.com", "polabsfu@gmail.com",60);
		Dialog.addString("Password for sign-in", "password",60);
		Dialog.addString("Email notification to:", "dpoburko@sfu.ca",60);
		Dialog.addString("Subject:", "Extended Depth of Field Conversion Complete",70);
		Dialog.addString("Body:", "Your Extended Depth of Field job is done.",70);
		Dialog.addHelp(html);
		Dialog.show();
		usr = Dialog.getString();
		pw = Dialog.getString();
		sendTo = Dialog.getString();
		subjectText = Dialog.getString();
		bodyText = Dialog.getString();
	}
	
	//prep logs and results table & IJ settings
	roiManager("reset");
	IJ.deleteRows(0, nResults);
	gImageNumber = 0;

	//run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated display redirect=None decimal=3");
	//v2.8 = add inclusion of measurement of ROI bounding boxes for quick annotation of whether ROIs touch image edges
	run("Set Measurements...", "area mean standard min centroid center perimeter bounding fit shape integrated display redirect=None decimal=3");
 	oBackGroundColor = getValue("color.background");
	oForeGroundColor = getValue("color.foreground");
	run("Colors...", "foreground=white background=black selection=cyan");
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv use_file copy_column copy_row save_column save_row");

	if (gDoBatchMode == true) setBatchMode(true);

	// make list of images
    validImgList = newArray(gImageList.length);
	nImgs = 0;

	// rename files containing the ### flag
	if (clearFlags == true) {
		for ( i =0; i< gImageList.length; i++) {
			if (indexOf(gImageList[i],"###")!=-1) {
				correctName = replace(gImageList[i],"###","");
				fr = File.rename(gImageFolder + gImageList[i],gImageFolder + correctName);
				gImageList[i] = correctName;
			}
		}
	}
	
	for ( i =0; i< gImageList.length; i++) {
		if ( (indexOf(gImageList[i],"###")==-1) && ( ( endsWith(gImageList[i], ".tif") == true) || ( endsWith(gImageList[i], ".nd2") == true) ) ) {
					validImgList[nImgs] = gImageList[i];
					nImgs++;
		}
	}
	validImgList = Array.slice(validImgList,0,nImgs);
	nValidImages =validImgList.length;
	Array.sort(validImgList);
	
	t0 = getTime();
	// cycle through image list and all analyses
	nImgsDone = 0;

	//set up foler to store txt files marking which images have been analyzed
	donePath = gImageFolder +  File.separator + "doneFlags" + File.separator;
	print("\\Update3: doneFlags folder: " + donePath);
		
	nDel = 0;
	if ((clearFlags == true)||(File.exists(donePath+ "allDone.txt"))) {
		if (File.isDirectory(donePath)) {
			doneList = getFileList(donePath);
			
			for(j=0;j<doneList.length;j++) {
				del = File.delete(donePath+doneList[j]);
				nDel++;
				print("\\Update3: "+nDel+" doneFlags deleted");
			}
		}
	}			

	if (!File.isDirectory(donePath)) File.makeDirectory(donePath);		

	analyzedChannels = "none";
	
	if (nValidImages==0) exit("Seems like there are no valid images to process inthe selected folder.\nCheck that you selected the right folder and re-try.");
	
    for (nImgsToProcess=0; nImgsToProcess<nValidImages; nImgsToProcess++) {

		t1= getTime();
		currImageName = validImgList[nImgsToProcess];
		print("\\Update4: working on " + currImageName );
		skipImage = false;
		oSuffix = substring(currImageName, lastIndexOf(currImageName, "."),lengthOf(currImageName));
		tempSuffix = "###"+oSuffix;
		tempName = replace(replace(currImageName,"###",""), oSuffix, tempSuffix);
        doneTxtName = replace(currImageName, oSuffix, "###.txt");
		
		if ( ( File.exists(gImageFolder + tempName) ) || ( File.exists(donePath + doneTxtName ))  ) {
			print("\\Update2: Image exists in output directory");
			analyzedChannels = "fileExistsOrDone";
			skipImage = true;
		}
				
		if (skipImage == false) {

    	    fr = File.rename(gImageFolder + currImageName,gImageFolder + tempName);
			fs = File.saveString("done",donePath  + doneTxtName);
			wait(500); 	//just in case another computer has already started working with this file
			if ( File.exists(gImageFolder + tempName) ) { 
		   		open(gImageFolder + tempName);
		   		rename(currImageName);
		   		getDimensions(width, height, ch, slc, frm);
				if ((ch == 1)&&(slc==1)) {
					run("Merge Channels...", "c1="+ currImageName + " c2="+ currImageName + " create");
					rename(currImageName);
				}
				//added in v2.5f to accomodate AIF processes extended depth of field from Matlab that are saved with channels as slices
				if ((ch == 1)&&(slices2channels==true)) {
					run("Stack to Images");
					mergeText = "";
					namesFromStack = newArray(nImages);
					for (m=1;m<=nImages();m++) {
						selectImage(m);
						namesFromStack[m-1] = getTitle;
						//print(getTitle());
					}
					for (m = 1; m<=slc;m++){
						mergeText = mergeText + "c"+m+"="+namesFromStack[m-1]+" ";
					}
					mergeText = mergeText + "create";
					run("Merge Channels...", mergeText);
					rename(currImageName);
				}
				
		   		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
		    	currLabelStart = nResults;
		   		roiManager("reset");
			    if (!isCompositeImage()) {
			        run("Channels Tool...");
			        run("Make Composite", "display=Composite");
			        selectWindow(currImageName);
			    }
		
		    	analyzedChannels = "";
		    	
				for (currAnalysis = 0; currAnalysis<gNumAnalyses; currAnalysis++) {
					currChannel = channels[currAnalysis];
					print("\\Update1: working on img " +nImgsToProcess+1+" of " + nValidImages + ", analysis " + currAnalysis+1 + " of " +gNumAnalyses +  ", Ch " + currChannel +" shape: " + roiShapes[currAnalysis]);
					roiLabelIndex = 0;
					for (i=0;i<items.length;i++) {
						if (roiShapes[currAnalysis] == items[i]) roiLabelIndex = i;
					}
					roiLabel = roiLabels[roiLabelIndex];
					
					//===== Send call to main processing function ====================================================================================================================================================
					//================================================================================================================================================================================================
					processSingleImage(currAnalysis, currImageName,currChannel,roiShapes[currAnalysis],roiSizes[currAnalysis], roiLabel, gaussRadii[currAnalysis], ballSizes[currAnalysis],threshold32s[currAnalysis],excludeOnEdges, nNN, dMethod);
					analyzedChannels = analyzedChannels+"C"+currChannel+"_"+roiShapes[currAnalysis]+"_";
					//================================================================================================================================================================================================
					//================================================================================================================================================================================================
				}
				
				close("*");
				if (isOpen(currImageName)) {
					close(currImageName);
				}
				variantOfCurrImage = replace(currImageName,".","-1.");
				if (isOpen(variantOfCurrImage)) {
					close(variantOfCurrImage);
				}		
				
				fr = File.rename(gImageFolder + tempName,gImageFolder + currImageName);  // from failed attempt at parallel processing
		
				//Create progress bar in log
				lapTime = (getTime() - t1)/1000;
				t1 = getTime();
				nImgsDone++;
				LapsLeft = (nValidImages-1) - nImgsToProcess;
				tLeft = (  (t1-t0) / (nImgsDone) ) *  (LapsLeft)  / 1000 ;
				progress = ( nImgsToProcess + 1)/nValidImages ;
				pctDoneLength = 40;
				pctDone = progress*pctDoneLength;
				pctDoneString = "";
				pctLeftString = "";
				for(bb = 0; bb<pctDoneLength;bb++) {
					pctDoneString = pctDoneString + "|";
					pctLeftString = pctLeftString + ".";
				}
				pctDoneString = substring(pctDoneString ,0,pctDone);
				pctLeftString = substring(pctLeftString ,0,pctDoneLength - pctDone);
				
				if (tLeft>3600) {
					tLeftUnits = "hrs";
					tLeftString = d2s(tLeft/3600,1);
				}
				if ( (tLeft<3600)&&(tLeft>60)) {
					tLeftUnits = "min";
					tLeftString = d2s(tLeft/60,1);
				}
				if (tLeft<=60) {
					tLeftUnits = "sec";
					tLeftString = d2s(tLeft,1);
				}
				// v2.5l save results with each image to not lose progress on crash
				saveAs("Results", gImageFolder  + "0results_nAnalyses_" + gNumAnalyses +"_rois_" +gDefineNucROIs + "_" + version + "_" + startTime + ".csv");
			} // if file exists	
			print ("\\Update0: image list: " + pctDoneString + pctLeftString + " " +  (nImgsToProcess+1) + " of " + nValidImages + " lap time: " + d2s(lapTime,3) + " s, loop time: " + tLeftString + " " + tLeftUnits +" left for img set" );
		} // close skip image
    }
//need to clean up done txt files


    gResultFileName = replace(gResultFileName,".xls","");
    gResultFileName = analyzedChannels + gResultFileName +"_"+ version;
    gResultFileName = replace(gResultFileName," ","_");
    //saveAs("Results", gImageFolder  + gResultFileName +  stamp + ".txt");
	saveAs("Results", gImageFolder  + "0results_nAnalyses_" + gNumAnalyses +"_rois_" +gDefineNucROIs + "_" + version + "_" + startTime + ".csv");


	while (isOpen("mtTable")) {
		selectWindow("mtTable");
		run("Close");
	}
	fs = File.saveString("done",donePath  + "allDone.txt");

 
	if (gDoBatchMode == true) setBatchMode("exit and display");
	print("\\Update1: Analysis of ROI intensities is complete in " + d2s((getTime-t0)/60000,2) + " min");
	run("Colors...", "foreground="+oForeGroundColor+" background="+oBackGroundColor+" selection=cyan");

	
	// ===== EMAIL COMPOSITION =================================================================================================================================
	if (doSendEmail == true) {
	
		// Module 2: Place at end of code once all other operations are complete
		pShellString = "$EmailFrom = \“"+usr+"\”";
		//pShellString = pShellString+"\n$EmailTo = \“dpoburko@sfu.ca\”";
		pShellString = pShellString+"\n$EmailTo = \“"+sendTo+"\”";
		pShellString = pShellString+"\n$Subject = \“"+subjectText+"\”";
		pShellString = pShellString+"\n$Body = \“"+bodyText+"\”";
		pShellString = pShellString+"\n$SMTPServer = \“smtp.gmail.com\”";
		pShellString = pShellString+"\n$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)";
		pShellString = pShellString+"\n$SMTPClient.EnableSsl = $true";
		pShellString = pShellString+"\n$SMTPClient.Credentials = New-Object System.Net.NetworkCredential(\“"+usr+"\”, \“"+pw+"\”)";
		pShellString = pShellString+"\n$SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)";
		//print(pShellString);
		path =getDirectory("imagej") + "powerShellEmail.ps1";
		if (indexOf(path," ")!=-1) path = getDirectory("home") + "powerShellEmail.ps1";
		File.saveString(pShellString, path);
		exec("cmd", "/c", "start", "Powershell.exe", path);
		File.delete(path);
		print("email should be sent to " + sendTo);
	}
  
    
}  //close macro

//====== MACRO END ==================================================================================================================================================

//----------------------------------------------------------------------
function processSingleImage(currAnalysisIndex, currImageName, measuredChannel, roiShape, roiSize, roiLabel, mGauss, mBallSize,threshold32b,excludeOnEdges, nNN, dMethod) {

    currLabelStart = nResults;
    Stack.getDimensions(imgWidth, imgHeight, channels, slices, frames) ;
    Stack.getPosition(channel, slice, frame) ;
    currSlice = slice;
    maxSD = 0;
    bestSlice = 1;
	selectWindow(currImageName);
	dupImageName = "DupOf"+currImageName;

	// if nuclear ROIset exist, skip remaking nuclear ROIs
	currImageNameForROIs = substring(currImageName,0, lastIndexOf(currImageName,"."));
	nucRoiFile = gImageFolder + items[0]+"_"+currImageNameForROIs+".zip";

    //v3.7 - permit initial ROI to be a user defined shape
    if ((gDefineNucROIs == doNucROIs[4]) && (roiShape == items[4])) {

    	nucRoiFile = gImageFolder + userShapes[currAnalysisIndex] + currImageNameForROIs+".zip";
		print(nucRoiFile + " exists: " + File.exists(nucRoiFile));
     	if ( File.exists(nucRoiFile)==false) {

    		nucRoiFile = gImageFolder + userShapes[currAnalysisIndex] + currImageNameForROIs+".roi";
    		print(nucRoiFile + " exists: " + File.exists(nucRoiFile));
    	}
		if ( File.exists(nucRoiFile)==true) {
			roiManager("Open",nucRoiFile);
			newImage("Mask of "+dupImageName, "8-bit black", width, height, 1);
			for (iROI = 0; iROI < roiManager("count"); iROI++) { 
				roiManager("Select",iROI);
				run("Fill", "slice");
			}
			roiManager("Deselect");
		}
		//print("used new path");
    	//waitForUser("rois opened?");
    } else {
	
		//print("looking for ROI file: "  + nucRoiFile);
		roiManager("reset"); //170122

		// ==== Open nucROI file or define nuclear ROIs ================================================================================
		nucROIsFromFile = true;
		if ( ( File.exists(nucRoiFile)==false) || (overwriteROIs==true) ) {
			nucROIsFromFile = false;
	    	Stack.setChannel(gNuclearChannel);
	    	Stack.getDimensions(width, height, channels, slices, frames);
			if (slices > 1) {
				bestFocusSlice(currImageName);
				Stack.getPosition(channel, slice, frame) ;
		 	    	run("Duplicate...", "title=[" + dupImageName + "] duplicate channels=" + gNuclearChannel + "  slices="+slice);
			}
	
			if (slices == 1) run("Duplicate...", "" + dupImageName + " duplicate channels=" + gNuclearChannel);
			getStatistics(nPixels, mean, min, max, std, histogram);
			if (gBallSize!=-1) run("Subtract Background...", "rolling="+gBallSize);   //v1.4.3
			if (mGauss!= -1) run("Gaussian Blur...", "sigma="+mGauss);
	
			if (gDoMultipleThresholds == false) {
				
				if ( (usRadius!=-1) ) 		run("Unsharp Mask...", "radius="+usRadius+" mask="+ usMask);  // v2.5d
				if ( (gaussRad!=-1) )	  	run("Gaussian Blur...", "sigma="+gaussRad);  // v2.6
				if (nucThreshold != -1) 	setThreshold(nucThreshold, 65555);
				if (nucThreshold == -1) 	setAutoThreshold("Default dark");
				setOption("BlackBackground", false);
				run("Convert to Mask");
				imgMask0 = getTitle();
				
				excludeString = "exclude "; //space after 'exclude' is required
				if (excludeOnEdges == false) excludeString = "";
				run("Analyze Particles...", "size=" + gNuclearMinArea + "-Infinity circularity=0.00-1.00 show=Masks "+excludeString+"include add");
				
				foundNuclei = true;
				if (roiManager("count")==0) { 
					foundNuclei = false;
				} else {
					if (gDoWaterShed == true) { // to watershed based on Solidity, would have to look at each ROI, water shed, then file ROI areas if the previous ROI had a solidity above the threshold. Pretty easy. 
						if (circThreshold == 0) run("Watershed");
						if (circThreshold > 0.001) {
							run("Analyze Particles...", "  circularity=0.0-"+circThreshold+" show=Masks "+excludeString+"include");
							run("Watershed");
							rename("imgMask1");
							selectWindow(imgMask0);
							run("Analyze Particles...", "  circularity="+circThreshold+0.001+"-1.0 show=Masks "+excludeString+"include");
							rename("imgMask2");
							imageCalculator("Add", "imgMask2","imgMask1");
							selectWindow("imgMask1");
							close();
							selectWindow(imgMask0);
							close();
							selectWindow("imgMask2");
							rename(imgMask0);
						}
							
						// should be able to watershed based on solidity too by quickly measuring all ROIs. Create combine(OR) of all with solidity above some cutoff and "clear" to fill in the gaps created by watershed above.
						if (minSolid>0.001) {
							solidityIndex = newArray(0);
							nResI = nResults;
							roiManager("measure"); 
							nResF = nResults;
							ntempROIs = roiManager("count");
							for (nr = 0; nr<ntempROIs; nr++) {
								solidityNR = getResult("Solidity",nr);
								if ((solidityNR>minSolid)||(circThreshold > 0.001)) {
									solidityIndex = Array.concat(solidityIndex,nr);
								}
							}
							if (solidityIndex.length>0) {
								roiManager("select",solidityIndex);
								roiManager("Combine");
								run("Clear", "slice");
								roiManager("deselect");
								run("Select None");
							}
						}
					roiManager("reset");
					run("Analyze Particles...", "size=" + gNuclearMinArea + "-Infinity circularity=0.00-1.00 show=Masks "+excludeString+"include add");
					}
					if (roiManager("count")==1) { 
						makeRectangle(0,0,2,2);
						roiManager("add");
						roiManager("select",1);
						roiManager("rename","dummy");
						roiManager("deselect");
						print("\\Update6: Only 1 nuclear ROI found. Saving extra dummy ROI to make .zip file");
					}
					
					if (roiManager("count")>0) { 
						roiManager("Save", gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");
					} else {
						foundNuceli = false;
					}				
				}
				if (foundNuclei == false ) {
					print("\\Update6: No ROIs found in " + currImageNameForROIs);
				}
			}
	
			if (gDoMultipleThresholds == true) {
				mainTable = "mainTable";
				mtTable = "mtTable";
				currTable = "Results";
				if (isOpen("Results")) IJ.renameResults(currTable,mainTable);
				print("\\Update4: doing multiple thretholds");
				run("RIPA "+RIPAversion, gRIPAParameters);
				print("\\Update4: multiple thretholds done");
				nROIs = roiManager("count");
	
				if (nROIs!=0) { 
					roiManager("Save", gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");
					print("\\Update4: saving " + gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");
					wait(300);
	// am not sure if this close call should be run("Close"); toi close a non-image window
					close();
					selectWindow("Results"); 
					IJ.renameResults(mtTable);
					selectWindow(mainTable);
					IJ.renameResults("Results");
					selectWindow(mtTable);
					run("Close");
				} else {
					print("\\Update6: No ROIs found in " + currImageNameForROIs);
					if (isOpen("Results")==true) {
						selectWindow("Results"); 
						IJ.renameResults(mtTable);
						selectWindow(mainTable);
						IJ.renameResults("Results");
						selectWindow(mtTable);
						run("Close");
					}
				}
				close("*uncta");
			}
	
		} else {
			// If nuclear ROIs already exist
			roiManager("Open",nucRoiFile);
			newImage("Mask of "+dupImageName, "8-bit black", width, height, 1);
			for (iROI = 0; iROI < roiManager("count"); iROI++) { 
				roiManager("Select",iROI);
				run("Fill", "slice");
			}
			roiManager("Deselect");
		}
	}
		
	nNuclei = roiManager("count");
	
	// ==== Analyze other cell ROI shapes if there is at least one nuclear ROI. Otherwise, skip analysis.
    if ( roiManager("Count")!=0) {
		    roiManager("Show All with labels");

			// Load OR generate specified ROI shapes ROIs
    		
			//===== option 1: analyze nuclear ROI ================================================
			if (roiShape == items[0]) {
				print("\\Update5: analyzing original nuclei");
				nROIs = roiManager("count");
				run("Select None");
			}
			
			if (roiShape != items[0]) {
				
				print("\\Update5: analyzing modified nuclear ROIs");
				nROIs = roiManager("count");
				
					//option 2: define boxes around center of each ROI
					 if (roiShape == items[1]) {
						if (( File.exists(""+gImageFolder + roiLabels[1]+"-"+roiSize+"_"+currImageNameForROIs+".zip")==false) || (overwriteROIs==true) ) {					 	
							for (iROI = 0; iROI < nROIs; iROI++) { 
								roiManager("Select",0);
								getSelectionBounds(x, y, width, height);
								roiManager("Delete");
								makeRectangle((x+width/2) -roiSize/2, (y+height/2)-roiSize/2, roiSize, roiSize);
								roiManager("Add");
								roiManager("select", nROIs-1);
								roiManager("Rename", roiLabels[1]+"_"+iROI);
							}
			    			roiManager("Deselect");
			    			roiManager("Save", ""+gImageFolder + roiLabels[1]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
						    roiManager("Show All with labels");
						} else {
							roiManager("reset");
							roiManager("Open",""+gImageFolder + roiLabels[1]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
						}
						
					 }
				 	//======== option 3: define "dilated nucleus" ==========================================================
					 if (roiShape == items[2]) {
					 	if (( File.exists(""+gImageFolder + roiLabels[2]+"-"+roiSize+"_"+currImageNameForROIs+".zip")==false) || (overwriteROIs==true) ) {		
							print("\\Update5: dilating nuclei");
							dilateROIs(roiSize, imgWidth,imgHeight);  // new methods introduced in v1.4.8.4
			    			roiManager("Save", ""+gImageFolder + roiLabels[2]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
			    			roiManager("Show All with labels");
					 	} else {
					 		roiManager("reset");
							roiManager("Open",""+gImageFolder + roiLabels[2]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
					 	}
					 }
					 nROIs = roiManager("count");
					 
				 	//======= option 4: define "nuclear surround" - ====================
			  		if (roiShape == items[3]) {

			  			//print("n Images open at start of surround block: " + nImages);
			  			print("\\Update5: entered nuc surround block");
					 	if (( File.exists(""+gImageFolder + roiLabels[3]+"-"+roiSize+"_"+currImageNameForROIs+".zip")==false) || (overwriteROIs==true) ) {		
							dummy = "dummy";
							newImage(dummy, "8-bit black", width, height, 1);
							if (File.exists(""+gImageFolder + roiLabels[2]+"-"+roiSize+"_"+currImageNameForROIs+".zip")==true) {
								print("\\Update5: creating surrounds from existing dilated nuclei");
								roiManager("reset");

								roiManager("reset");
								roiManager("Open", gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");
								tStartDil = getTime();
								dilateROIs(nucOffSet,imgWidth,imgHeight);  //function
								roiManager("Save", ""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");
								roiManager("reset");
								
								roiManager("Open",""+gImageFolder + roiLabels[2]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
								roiManager("Open", ""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");
								hide1 = File.delete(""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");

								/*
								 * THERE IS A BIG PROBLEM HERE IN THAT NO "INNER" ROIS IS MADE WITH THIS METHOD. NEED TO SORT THAT OUT!
								 * Hopefully the new code in v3.5 fixes the issue
								 */
								
							} else {
								
								print("\\Update5: creating surrounds from nuclei");
								roiManager("reset");
								roiManager("Open", gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");
								tStartDil = getTime();
								//nucOffSet = 3;   // v2.5f - moved to global variable.
								//print("\\Update5:  dilating nuclei by : " + nucOffSet + " pixels");
								//print("\\Update8: n images at first call of dilateROIs: " + nImages);
								dilateROIs(nucOffSet,imgWidth,imgHeight);  //function
								//showImageList();
								roiManager("Save", ""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");
								roiManager("reset");
								roiManager("Open", gImageFolder + items[0]+"_"+currImageNameForROIs+".zip");

								tStartDil = getTime();
								//print("\\Update5:  dilating nuclei by : " + roiSize+nucOffSet + " pixels");
								//print("\\Update9: n images at 2nd call of dilateROIs: " + nImages);
								dilateROIs(roiSize+nucOffSet,imgWidth,imgHeight);  //function
								print("\\Update7:  time to dilate nuclei for surrounds: " + (getTime()-tStartDil)/1000);
								//showImageList();
								roiManager("Open", ""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");
								hide1 = File.delete(""+gImageFolder + "_inner-"+roiSize+"_"+currImageNameForROIs+".zip");
								//delete "inner" file
							}

							// creating surrounds as XOR of nuclei and dilated nuclei
							if (roiManager("count")%2 != 0) exit("number of nuclear ROIs != number of dilated nuclei for making surrounds in image \n " +currImageNameForROIs);
							nCells = roiManager("count")/2;
							print("\\Update6: nCells: " + nCells);
							roiPair = newArray(2);
							noSurround = 0;
							selectWindow(dummy);
							for (j=0;j<nCells;j++) {
								showProgress(j/nCells);
							    roiPair[0] = j + nCells;
								roiPair[1] = j;
							
								roiManager("select",roiPair);
								nROIsBefore = roiManager("count");
								roiManager("XOR");
								roiManager("ADD"); // moved out of 'if ((nROIsAfter - nROIsBefore)>=1) {' block in v2.8
								nROIsAfter = roiManager("count");
								
								if ((nROIsAfter - nROIsBefore)>=1) {
									roiManager("select", roiManager("count")-1);
									roiManager("Rename", "surround_"+IJ.pad(j,4));
								} else {
									noSurround++;
								}
							}
							
							for (j=0;j<(nCells*2-noSurround);j++) {
								roiManager("select",0);
								roiManager("Delete");
							}

							if (isOpen("dummy")) {
								selectWindow(dummy);
								close();
							}
			    			roiManager("Deselect");
			    			roiManager("Save", ""+gImageFolder + roiLabels[3]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
							roiManager("Show All with labels");
						} else {
							roiManager("reset");
							roiManager("Open",""+gImageFolder + roiLabels[3]+"-"+roiSize+"_"+currImageNameForROIs+".zip");
					 	}
					 	nROIs = roiManager("count");
					 	//print("n Images open at end of surround block: " + nImages);
					}
					
					//======= option 5: analyze user defined ROIs   ====================
					if (roiShape == items[4]) {
						/* Purpose - The user can call any ROIs that created by any other approach
						 * Limitations - The user most verify independently that each user-defined ROI coincides by number/order with a "nucleus" ROI 
						 * Use - the user gives the prefix of the set of ROI files that follows the format prefix_[imageName].zip
						 *     - nuclear ROIs would look like nucleus_[imageName].zip
						 * 		- for other shapes, this section serves to open or create specific shape of ROIs. In this case, it will simply open the user-defined ROIs. 	
						 */
						udSuffix = userShapes[currAnalysisIndex]; //user defined ROI suffix
						udROI = ""+gImageFolder + udSuffix +currImageNameForROIs+".zip"; // user defined ROI path
						
						if (File.exists(udROI)==true) {
							print("\\Update7: user defined ROIs found - " + udSuffix + currImageNameForROIs+".zip");
							roiManager("reset");
							roiManager("Open",udROI);
						} else {
							udROI = ""+gImageFolder + udSuffix + currImageNameForROIs+".roi"; // user defined ROI path
							if (File.exists(udROI)==true) {
							
								print("\\Update7: user defined ROIs found - " + udSuffix + currImageNameForROIs+".roi");
								roiManager("reset");
								roiManager("Open",udROI);
							} else {
								roiManager("reset");
								print("\\Update7: CANNOT LOCATE USER DEFINED ROIs " + udSuffix + currImageNameForROIs+".zip");
							}
						}
						nROIs = roiManager("count");
					 }
					
			} // close if 	(roiShape != items[1])

		//check that number of ROIs matches number of nuclei. Have to assume that ROIs are named with serial numbers. 
		roiNumbers = newArray(nROIs);  //need to increment from first number. 
		roiCellIDIndex = newArray(nNuclei);
		roiCellIDIndex = Array.fill(roiCellIDIndex,-1);  //fill with -1, which will indicate any indices where the ROI number does not match sequential nuclear ROI numbering from 0
			
        // Mainly for user-defined ROIs. Test that numbering of ROIs (assuming roi names contain a serial number) is equal to nuclear ROIs. 
		//Collect list of numbers from ROI names
		udROIbase = 0;
		for (j=0; j<nROIs; j++) {
        	roiManager("select",j);
        	roiString = Roi.getName;
        	number = getNumberAtRight(roiString);
        	if ((j==0) && (number==0)) udROIbase = 0; // test if user-defined numbers start at 0 or 1 
        	if ((j==0) && (number==1)) udROIbase = 1; // test if user-defined numbers start at 0 or 1 
			if ((j==0) && ( (number!=0) && (number!=1) )) udROIbase = -1; // signals that userdefined ROIs are not numbered
        	roiNumbers[j] = number-udROIbase ;
		}
		if (nROIs==0) udROIbase = -1;

        if (udROIbase>-1) { //if ROIs unnames, leave roiCellIDIndex as -1's, cannot be sure that ROIs match cells. leave rows a -1
	        for (k=0; k<nNuclei; k++) {				        	
	        	for (j=0; j<nROIs; j++) {
		        	if (roiNumbers[j]==k) roiCellIDIndex[j] = j - udROIbase; // test if user-defined numbers start at 0 or 1 
		        	j = nROIs;
	        	}        	
	        }
        }
		//
		//if (roiShape == items[4]) {
			//print(currImageNameForROIs+" udROIbase="+udROIbase+ " nNuclei="+nNuclei+" nROIs="+nROIs);
		//}
		
		run("Select None");
		close("Mask of*");
		close("Dup*");
	    roiManager("Show None");
	    numberOfPart = roiManager("count");

			// ========= MEASURE ROIS FOR CURR CHANNEL ===========================================================================================
		    // ===================================================================================================================================
		//if (nROIs>0) { - //note - if we gloss over analyses with no ROIs, this will mess-up the gUniqueCellIndex unless incremented by 1 in an else statement
		
		    // Extract channel to be analyzed, find best focus of multiple Z, run Gauss Blur and Rolling Ball subtraction

		    selectWindow(currImageName);
		    run("Select None");
		    dupImageName = substring(currImageName,0,lastIndexOf(currImageName,".")) + "_C"+measuredChannel;
		    run("Duplicate...", "title=[" + dupImageName + "] duplicate channels=" + measuredChannel);
		    selectWindow(dupImageName);
		    Stack.getDimensions(width, height, channels, slices, frames) ;
		    if (mGauss!=-1 ) run("Gaussian Blur...", "sigma="+mGauss+" stack");
		    if (slices == 1) {
				getStatistics(nPixels, mean, min, max, std, histogram);                             //v1.1  
	 			run("Subtract...", "value="+min);                                                   //v1.1
		    }
		    if (slices>1) {	
			    for (subtractingMin=1; subtractingMin<=slices;  subtractingMin++) {
					Stack.setSlice(subtractingMin);   	
					getStatistics(nPixels, mean, min, max, std, histogram);                             //v1.1  
			 		) run("Subtract...", "value="+min);                                                   //v1.1
			    }
		    }
		    if (mBallSize!=-1) run("Subtract Background...", "rolling=" + mBallSize + " stack");             //v1.1   
		    if (threshold32b!=-1) {
			    run("32-bit");
				setThreshold(threshold32b, 65555);
				run("NaN Background");
		    }

		    IJ.deleteRows(currLabelStart, nResults);  // refreshes at start of function, remove any measure made in this loop so far. Possibly vestigial 160505
		    currLabelStart = nResults;				// next empty results row
		    
		    if (slices>1) {
			    for (iCounter = 0; iCounter < numberOfPart; iCounter++) {
			        roiManager("Select", iCounter);
			        bestFocusSlice(dupImageName);
			        roiManager("Measure");
			    }
		    }
		    if (slices == 1) {
			 	roiManager("Measure");
		    }
   
		    run("Select None");
	    	
		    if ( (measuredChannel == gNuclearChannel) || (gPreviousImgName != currImageName) )  {
		    	// if starting on the nuclear channel, or if advancing to the first analysis stop of a new image
		    	gExpCellNumberStart = gUniqueCellIndex + 1;  // begins at 0 
				print("\\Update5: plan B");
		    } else {
				gUniqueCellIndex = gExpCellNumberStart-1;		    	
		    }
			gPreviousImgName = currImageName;

		    // check that channel is nuclear channel 
			if (currAnalysisIndex==0) {
				firstChannel = measuredChannel;
				
				if (roiShape!=items[4]) firstRoiShape = roiShape;
				if (roiShape==items[4]) firstRoiShape = userShapes[currAnalysisIndex];
				startCellsAnalysis1 = nResults-roiManager("count");
				endCellsAnalysis1 = nResults;
			}

			// dump measurements to the results table. If it appears that a given cell has already been measured, then dump measures to same row as that cell

			//first analysis for a given image
			if (currAnalysisIndex==0) {    

				//insert NN analysis algorithm

			tNN0 = getTime();
				
				if (nNN > 0) {
'
					nrPreNN = nResults;
					nROIs4NN = roiManager("Count");
					img0 = getTitle();
					t0 = getTime();
					roiManager("deselect");
					roiManager("Measure");
					xList = newArray(nROIs4NN);
					yList = newArray(nROIs4NN);
					means = newArray(nROIs4NN);
					distances = newArray(nROIs4NN);
					angles = newArray(nROIs4NN);
					ranks = newArray(nROIs4NN);
					nnArray = newArray(nNN);

					for (i=0;i<nROIs4NN;i++){
						xList[i] = getResult("X",currLabelStart+i);
						yList[i] = getResult("Y",currLabelStart+i);
						means[i] = getResult("Mean",currLabelStart+i);
					}
 					IJ.deleteRows(nrPreNN, nResults);

							//Need to re-arrange to allow for use of kNN.R script as an option for fast NN search . 
							//So calculation of NN distaces can be optional with a break point of X ROIs
							// Will need to move calculation of distance between perimeters to a second j loop since main j-loop would only be used of kNN script is not
							// Need to work out a function to call kNN with number of NN and returning an array of NN indicies and distances. 
							// NB: currently have an excessive # of calculations of angles. Only need to calc for NNs, not all pairs. 
							// this will be a bit tricky to reference, but do able. 
				
					for (j = 0;j<xList.length;j++) {
						if (dokNNR == false) {
							print("\\Update6: doing brute force NN approach for " +xList.length +" ROIs. j: " + j);
							distances = newArray(nROIs);
							// for each ROI (j loop), loop through all of the ROIs (k list) to find NNs
							for (k = 0;k<xList.length;k++) {
								//calculate distances between all pairs
								distances[k] = sqrt( pow(xList[j] - xList[k],2) + pow(yList[j] - yList[k],2));
								angles[k] = -1*(180/PI)*atan2(yList[k] - yList[j],xList[k] - xList[j]);
								// find nNN closest k (=ROI number)
							}
							rankPosArr = Array.rankPositions(distances);
							ranks = Array.rankPositions(rankPosArr);
							// sort again to give a sorted list of the ROI number ranked wrt distance to reference ROI
						
						}
						if (dokNNR == true) {
							//call to a new function that needs to know nNN, then will do the rest
						}
					
						sortedNNIndex = Array.rankPositions(ranks);
						
						for (i=1;i<=nNN;i++){
							setResult("NN"+i,currLabelStart+j,sortedNNIndex[i]+1);
							setResult("NN"+i+" dist",currLabelStart+j,distances[sortedNNIndex[i]]);
							residual = means[j]-means[sortedNNIndex[i]];
							setResult("NN"+i+" residual",currLabelStart+j,residual);
							setResult("angle"+i+"angle2NN",currLabelStart+j,angles[sortedNNIndex[i]]);
						}
					}
					updateResults();
					//optionally - estimate distance between perimeters of cells
					// note that we initially used an explicit calculate along the perimeter of each ROI and its NN. This got really slow. 
					// so we now find the voronoi distances between ROIs and measure that within a box bound by the centroids of a pair of NNs.
					// this has the potential for the box to contain measures of other neighbours, so should not be considered absolute
					if (dMethod == dMethChoices[1]) {

						//step one, make the voronoi distance mask.
						roiMask = "roiMask";
						imgVoronoi = "voronoi";
						imgUDM = "UDM";

						d2pT0 = getTime();
		
						newImage(roiMask, "8-bit black", width, height, 1);
						//create a binary image with filled ROIs. 
						roiManager("deselect");
						roiManager("select",Array.getSequence(roiManager("count")));
						roiManager("OR");
						roiManager("add");
						run("Fill");
						roiManager("select", roiManager("count")-1);
						roiManager("delete");
						//assume that the ref ROIs have been meausured in the previous portion of the analysis
						//roiManager("measure"); // get ROI stats
					 	roiManager("Deselect");
						run("Select None");
						run("Duplicate...", "title="+imgVoronoi); //create an image for voronoi outlines
						run("Options...", "iterations=1 count=1 edm=32-bit do=Nothing"); // ensure that binary options output 32b images
						selectWindow(imgVoronoi);
						setThreshold(1,65555);
						run("Convert to Mask");
						run("Voronoi");
						setThreshold(1,65555);
						run("Convert to Mask");
						run("Divide...", "value=255");
						run("32-bit");
						setAutoThreshold("Default");
						run("NaN Background");
						voronoi32bMask = "voronoi32bMask";
						rename(voronoi32bMask); 
					
						selectWindow(roiMask);
						run("Duplicate...", "title="+imgUDM); // create an image for the 32 bit distance map
						setAutoThreshold("Default");
						run("Distance Map");
						imageCalculator("Multiply create 32-bit", "EDM of UDM",voronoi32bMask);
						voronoiLines = "voronoiLines";
						rename(voronoiLines);
						selectWindow(voronoiLines);
			
						//tidy up
						close("EDM of "+imgUDM);
						close(imgUDM);
						close(roiMask);
						close(imgVoronoi);
						close(voronoi32bMask);

						//step 2: estimate distances between each ROI and it's NNs. Not that this method will likely underestimate these values for higher numbers of NNs
													
						for (i=1;i<=nNN;i++){
							for (j=0;j<xList.length;j++) {
								//reference the results table to find the ith NN index, then get its X&Y values		
								x2 = getResult("X", getResult("NN"+i,currLabelStart+j)-1);
								y2 = getResult("Y", getResult("NN"+i,currLabelStart+j)-1); 
								makeRectangle(minOf(xList[j],x2),minOf(yList[j],y2),abs(xList[j]-x2),abs(yList[j]-y2));
								getStatistics(areap, meanp, minp, maxp);
								setResult("NN"+i+" distBwPerimeters",currLabelStart+j,2*minp);	
								//print("i: "+i+" j: "+j+" x2: " + x2 + " y2 "+y2+ " 2*minp " + 2*minp);
							}
						}	
						run("Select None");
						close(voronoiLines);
						d2pT1 = getTime();
						//print("time to calc d2p for " + roiManager("count") + " ROIs: " + (d2pT1-d2pT0)/1000 + "");
					}
				}
				tNN1 = getTime();
				nnText = "\\Update3: time to find NNs: " +(tNN1-tNN0)/1000+ " s";
				if  ( (dMethod == dMethChoices[1]) && (nNN>0)) nnText = nnText + ", including d2p Time: " + (d2pT1-d2pT0)/1000 + " s";
				if (nNN >0) print(nnText);
  				
			    for (iCounter = currLabelStart; iCounter < nResults; iCounter++) {
			    	cellIndex = (iCounter - currLabelStart);						//currLabelStart should be the first results row of the current measures
					//v2.8 - add marker if ROIs touch edges of image. 
					//assumes that ROIs were measured with 'bound' measurements options
					onEdge = 0;
					if ( (getResult("BX", iCounter)==0) || (getResult("BY", iCounter)==0)	|| ( ( getResult("BX", iCounter) + getResult("Width", iCounter)) >= imgWidth ) || ( ( getResult("BY", iCounter) + getResult("Height", iCounter)) >= imgHeight ) ) {
						onEdge = 1;		
					}

					//v3.6 - add inclusion of ROIs size in "ROI shape if != 0
					setResult("onEdge", iCounter, onEdge);
			    	
			        setResult("Channel", iCounter, measuredChannel);
			        setResult("Cell", iCounter, "" + IJ.pad(gUniqueCellIndex,5));
			        if (roiShape != items[4]) setResult("ROI shape", iCounter, roiShape);
			        if (roiShape == items[4]) {
			        	setResult("ROI shape", iCounter, userShapes[currAnalysisIndex]); // if ROIs shapes are used defined, use that shape description
						//Added v3.8
			        	tempLabel = getResultString("Label", iCounter);
			        	splitLabel = split(tempLabel,":");			        	
			        	setResult("roiName", iCounter, splitLabel[1]); // if ROIs shapes are used defined, use that shape description
			        }
			        setResult("Label", iCounter, dupImageName + "_CELL_" + IJ.pad(cellIndex,5));
			        gUniqueCellIndex++;
			    }
			} else {  //subsequent analyses, where we need to try to match measures to the cells measured in the first analysis

				//loop through current results for this measurement of this image
				
			    for (iCounter = currLabelStart; iCounter < nResults; iCounter++) {

			    	cellIndex = (iCounter - currLabelStart);   //should be row (base 0) of current results. nResults - currLabelStart should normally = nNuclei
					
					//if analyzed ROIs were numbered or there are fewer current ROIs than nuclear ROIs
					if ( (udROIbase>-1) && (nROIs!=nNuclei) )  { 
						//check if each ROI number from ROI names matches the current cellIndex. 
						//If not, replace cellIndex with roiNumbers[cellIndex], which should direct results to match appropriate cell in the table in the oCounter matching loop
						if (cellIndex != roiNumbers[cellIndex]) cellIndex = roiNumbers[cellIndex];
						print("\\Update: using alternate aasignment of cellIndex for cell " + cellIndex);
					}
	    	
			    	currLabel = dupImageName + "_CELL_" + IJ.pad(cellIndex,5); //assumed name for current cell and current analysis channel
			    	matchIndex = -1;  //denotes that we have found the cell ID from the first run that this current cell's measure matches
			    	
			    	for (oCounter = startCellsAnalysis1; oCounter < endCellsAnalysis1; oCounter++) {   //recall, start(end)CellsAnalysis1 are the indicies of the results table for this images nuclei or first analysis set
			    		oLabel = getResultLabel(oCounter);
			    		oLabel = replace(oLabel,"_C"+firstChannel+"_","_C"+measuredChannel+"_"); //modify the image label for the current channel
			    		if (currLabel == oLabel) {
			    			matchIndex = oCounter;  //row of results table to add data to
			    			oCounter = endCellsAnalysis1;
			    		}
			    	}
			    	if (matchIndex != -1) {

						//check if (cellIndex != (iCounter - currLabelStart)). Indicates that iCounter(th) loop was for a current result that was not sequential with respect to nuclear ROIs
						// If not equal, need to assign incremental gUniqueCellIndex to iCounter(th) row and grab gUniqueCellIndex from the cell column

			    		
				    	//if matchIndex == -1, the iCounter(th) row filled with zeros. For that images, gUniqueIndex values will be incorrect - known issue
				        setResult("Area_"+currAnalysisIndex, matchIndex, getResult("Area",iCounter));
				        setResult("Mean_"+currAnalysisIndex, matchIndex, getResult("Mean",iCounter));
				        setResult("StdDev_"+currAnalysisIndex, matchIndex, getResult("StdDev",iCounter));
				        setResult("X_"+currAnalysisIndex, matchIndex, getResult("X",iCounter));
				        setResult("Y_"+currAnalysisIndex, matchIndex, getResult("Y",iCounter));
				        setResult("IntDen_"+currAnalysisIndex, matchIndex, getResult("IntDen",iCounter));

						//assumes that ROIs were measured with 'bound' measurements options
						onEdge = 0;
						if ( (getResult("BX",  iCounter)==0) || (getResult("BY",  iCounter)==0)	|| ( ( getResult("BX",  iCounter) + getResult("Width", iCounter)) >= imgWidth ) || ( ( getResult("BY", iCounter) + getResult("Height", iCounter)) >= imgHeight ) ) {
							onEdge = 1;		
						}
						setResult("onEdge_"+currAnalysisIndex, matchIndex, onEdge);
				    	setResult("Label_"+currAnalysisIndex, matchIndex, dupImageName + "_CELL_" + IJ.pad(cellIndex,5));
				        setResult("Channel_"+currAnalysisIndex, matchIndex, measuredChannel);
				        setResult("Cell_"+currAnalysisIndex, matchIndex, "" + IJ.pad(gUniqueCellIndex,5));
				        rs2 = roiShape;
				        thr32txt = "";
				        if (threshold32b!=-1) {
				        	 thr32txt = "_thr-"+threshold32b;
				        }
				        if (roiShape == items[1]) rs2 = roiLabels[1]+"-"+roiSize + thr32txt;
				        if (roiShape == items[2]) rs2 = roiLabels[2]+"-"+roiSize + thr32txt;
				        if (roiShape == items[3]) rs2 = roiLabels[3]+"-"+roiSize + thr32txt;
				        if (roiShape == items[4]) rs2 = userShapes[currAnalysisIndex];
				        setResult("ROI shape_"+currAnalysisIndex, matchIndex, rs2); // if ROIs shapes are used defined, use that shape description
				        gUniqueCellIndex++;

			    	} else {
			    		print("no matching result row found for "+currLabel);
			    		gUniqueCellIndex++; //still need to incremement the unique cell index of a row of data is missed
			    	}
			    }				
			    if (nROIs<nNuclei) gUniqueCellIndex = gUniqueCellIndex + (nNuclei-nROIs);
/*
 * *The problem with qUniqueCellIndex is that it we are not accounting for when a row of data is skipped and the current result essentially "skips" a row relative to the nuclear ROIs 
 *
 */
		
				IJ.deleteRows(currLabelStart, nResults);
			}

		//} //close if (nROIs > 0)
			
    } else { // close if roiManager("Count")==0
	print("\\Update6: no ROI found for img " +currImageName);

    }
    updateDisplay();
    close("Mask of*");
    close("Dup*");
    if (isOpen(dupImageName)) {
	    selectWindow(dupImageName);
    	close();
    }
    roiManager("reset");
}


//----------------------------------------------------------------------
function doSetImageFolder() {
    gImageFolder = getDirectory("Select folder with images & ROIs to analyze");
    gOutputImageFolder = gImageFolder + "_ROI" + File.separator();
    gNuclearImageFolder = gImageFolder + "_NUCLEAR_ROI" + File.separator();
    gFftImageFolder = gImageFolder + "_FFT" + File.separator();
    gImageList = getFileList(gImageFolder);
    Array.sort(gImageList);
    //Array.print(gImageList);
	tempImgList = newArray(gImageList.length);
	nImgs=0;

	for (i=0; i<gImageList.length; i++) {
	    if (!(endsWith(gImageList[i], File.separator()) || endsWith(gImageList[i], "/"))) {
	        if (endsWith(gImageList[i], ".tif") || endsWith(gImageList[i], ".TIF") || endsWith(gImageList[i], ".nd2"))
	            isAnImageFile_result = true;
	            tempImgList[nImgs] = gImageList[i];
	            nImgs++;
	            //print(gImageList[i]);
	    }
	}
    gImageList = Array.slice(tempImgList, 0, nImgs);  
    gImageNumber = 0;
    gCurrentImageName = "";
}
/*------------------------------------------------------------------*/

function bestFocusSlice(img0) {

        Stack.getDimensions(width, height, channels, slices, frames) ;
        maxSD = 0;
        bestSlice = 1;
            for (sl = 0; sl<slices; sl++) {
                //run("Select None");
                Stack.setSlice( sl+1);
                getStatistics(nPixels, mean, min, max, std, histogram);
                //std = std*std/mean;
                //showMessage(std + ", " + maxSD + ", " +sl+1);
                if (std > maxSD) {
                    maxSD = std;
                    bestSlice = sl+1;
                }
            }
         Stack.setSlice(bestSlice);
}

//----------------------------------------------------------------------
function isCompositeImage() {
    _imageInformation = getImageInfo();
    _isComposite = false;
    if (indexOf(_imageInformation, "\"composite\"") >= 0)
           _isComposite = true;
    return _isComposite;
}

function isAnImageFile(fileName) {
    //check for mac and pc based path separator....
    isAnImageFile_result = false;
    if (!(endsWith(fileName, File.separator()) || endsWith(fileName, "/"))) {
        if (endsWith(fileName, ".tif") || endsWith(fileName, ".TIF") || endsWith(fileName, ".nd2"))
            isAnImageFile_result = true;
    }
    //showMessage(isAnImageFile_result + " = " + fileName);
    return isAnImageFile_result;
}

//----------------------------------------------------------------------
function getNextImage() {
	if (gImageFolder == "") {
        doSetImageFolder();
	} 
    gCurrentImageName = "";
    roi_Number = 0;
	while (gImageNumber < gImageList.length && gCurrentImageName == "") {
		gCurrentImageName = gImageList[gImageNumber];
		gImageNumber++;
        if (!isAnImageFile(gCurrentImageName))
            gCurrentImageName = "";
	} 
    return gCurrentImageName;
	//showMessage(gImageFolder + ", " +gCurrentImageName+", "+gImageList.length +","+gImageNumber);
}

function dilateROIs(roiSize, imgW, imgH) {

	//getDimensions(width, height, channels, slices, frames);
	roiMask = "roiMask";
	imgVoronoi = "voronoi";
	imgDilated = "dilated";
	dilated2 = "dilated2";
	voronoi2 = "voronoi2";

	newImage(roiMask, "8-bit black", imgW, imgH, 1);
	run("Divide...", "value=255.000");
	run("16-bit");
	run("Add...", "value=1.000");
	for (j=0; j<nROIs;j++) { 
		roiManager("Select",j); //fixed in v1.4.6
		run("Multiply...", "value="+(j+1));
		run("Add...", "value=1.000");
	}
	roiManager("Deselect");
	run("Select None");
	run("Subtract...", "value=1.000");
	run("Duplicate...", "title="+imgVoronoi);
	run("Duplicate...", "title="+imgDilated);
	selectWindow(imgVoronoi);
	setThreshold(1,65555);
	run("Convert to Mask");
	run("Voronoi");
	setThreshold(1,65555);
	rename(voronoi2);
	run("Convert to Mask");
	selectWindow(imgDilated);
	setThreshold(1,65555);
	run("Convert to Mask");
	run("Invert LUT");
	run("Options...", "iterations=1 count=1 edm=16-bit");
	run("Distance Map");
	rename(dilated2);
	run("Options...", "iterations=1 count=1 edm=Overwrite");
	setThreshold(0, roiSize);
	run("Convert to Mask");
	imageCalculator("Subtract", dilated2,voronoi2);
	roiManager("reset");
	//selectWindow(dilated2);
	setThreshold(1, 255);
	run("Analyze Particles...", "  show=Nothing display add");
	run("Divide...", "value=255.000");
	selectWindow(roiMask);
	for (j=0; j<roiManager("count");j++) { 
		roiManager("Select",j); //fixed in v1.4.6
		getStatistics(area, mean, min, max);
		roiManager("Rename", ""+IJ.pad(max,5)+"");
	}
	roiManager("Deselect");
	roiManager("Sort");
	run("Select None");
	//selectWindow(imgVoronoi);
	//close();
	selectWindow(imgDilated);
	close();
	selectWindow(roiMask);
	close();
	//selectWindow(dilated2);
	close("*dilated2");
	selectWindow(voronoi2);
	close();
	//selectWindow(imgVoronoi);
	//close();
	roiManager("Deselect");
}

function showImageList() {

    imgNow = getTitle();
	openImages = newArray();
	for (i=1;i<=nImages;i++) {
		selectImage(i);
		Array.concat(openImages, getTitle());
		print(getTitle());
	}
	selectImage(imgNow);
	Array.print(openImages);
}

function timeStamp () {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	stamp = ""+ year +""+IJ.pad(month+1,2)+""+ IJ.pad(dayOfMonth,2)+"-"+IJ.pad(hour,2)+""+IJ.pad(minute,2)+"."+IJ.pad(second,2) ;
	return stamp;
}

function getParameterFiles() {

	//Find newest file.
	nParamFiles = 0;
	fList = getFileList(gImageFolder);
	pList = newArray(fList.length);
	pLastMod = newArray(fList.length);
	pLastMod[0] = "";
	pList[0] = "";
	for (g=0;g<fList.length;g++) {

		if (indexOf(fList[g],"0parameters")!=-1) {
			pList[nParamFiles] = fList[g];
			pLastMod[nParamFiles] = File.lastModified(gImageFolder+ File.separator+fList[g]);
			nParamFiles++;
		} else {
			pLastMod[g] = "";
			pList[g] = "";
		}
	}
	print("\\Update0: nParamFiles = " + nParamFiles);
	if (nParamFiles==0){
		pList = Array.slice(pList,0,2);
	}
	if (nParamFiles==1){
		pFile = pList[1];
		pList = Array.slice(pList,0,1);
	}
	
	if (nParamFiles>1) {	
	//Array.print(pList);
		pList = Array.slice(pList, 0, nParamFiles);
	//Array.print(pList);
		pLastMod = Array.slice(pLastMod, 0, nParamFiles);
		ranks = Array.rankPositions(pLastMod);
		Array.getStatistics(ranks, min, max, mean, stdDev);
		for (i = 0; i < ranks.length; i++) {
			if (ranks[i] == max) newest = i;
		}
		pFile = pList[newest];
	} 
	//print("parameters files list");
	//Array.print(pList);
	return pList;
}



function getParameters() {

	gDoBatchMode = false;
	doSendEmail = false;
	clearFlags = false;
	slices2channels = false;

	for(i=0;i<nResults;i++) {
		
		parameter = getResultString("Parameter",i);
		value =  getResultString("Values00",i);
		//print("parameter: " +parameter+ " Value: "+value);
		if (parameter == "gNuclearChannel") gNuclearChannel = value; 
		if (parameter == "gNumAnalyses") gNumAnalyses = value; 
		if (parameter == "gDefineNucROIs") gDefineNucROIs = value; 
		if (parameter == "gDoBatchMode")gDoBatchMode = value; 
		if (parameter == "nNN")nNN = value; 
		if (parameter == "dMethod")dMethod = value; 
		if (parameter == "dokNNR")dokNNR = value; 
		if (parameter == "doSendEmail") doSendEmail = value; 
		if (parameter == "clearFlags") clearFlags = value; 
		if (parameter == "slices2channels") slices2channels = value; 
		if (parameter == "roiShapes") prevRoiShapes = split(replace(value," ",""),","); 
		if (parameter == "channels") prevChannels = split(replace(value," ",""),","); 
		if (parameter == "ballSizes") prevBallSizes = split(replace(value," ",""),","); 
		if (parameter == "gaussRadii") prevGaussRadii = split(replace(value," ",""),","); 
		if (parameter == "roiSizes") prevRoiSizes = split(replace(value," ",""),","); 
		if (parameter == "threshold32s") prevThreshold32s = split(replace(value," ",""),","); 

		//defining ROI parameters
		if (parameter == "define_Nuc_ROIs") define_Nuc_ROIs = value; 
		if (parameter == "simpleThreshold") simpleThreshold = value; 
		if (parameter == "gBallSize") gBallSize = value; 
		if (parameter == "gNuclearMinArea") gNuclearMinArea = value; 
		if (parameter == "gBallSize") gBallSize = value; 
		if (parameter == "nucThreshold") nucThreshold = value; 
		if (parameter == "usRadius") usRadius = value; 
		if (parameter == "usMask") usMask = value; 
		if (parameter == "gDoWaterShed") gDoWaterShed = value; 
		if (parameter == "circThreshold") circThreshold = value; 
		if (parameter == "minSolid") minSolid = value; 
		if (parameter == "gaussRad") gaussRad = value; 
		if (parameter == "overwriteROIs") overwriteROIs = value; 
		if ((parameter == "clearFlags")&& (value==1)) clearFlags = true; 
		if ((parameter == "gDoBatchMode")&& (value==1)) gDoBatchMode = true; 
		if ((parameter == "doSendEmail")&& (value==1)) doSendEmail = true; 
		
		//need to add values for when ROIs are defined by multiple thresholds

		
	}
	
 	call("ij.Prefs.set", "dialogDefaults.gNuclearChannel",gNuclearChannel);
 	call("ij.Prefs.set", "dialogDefaults.gNumAnalyses",gNumAnalyses);
 	call("ij.Prefs.set", "dialogDefaults.gDefineNucROIs",gDefineNucROIs);
 	call("ij.Prefs.set", "dialogDefaults.gDoBatchMode",gDoBatchMode);
 	call("ij.Prefs.set", "dialogDefaults.doSendEmail",doSendEmail);
 	call("ij.Prefs.set", "dialogDefaults.clearFlags",clearFlags);
 	call("ij.Prefs.set", "dialogDefaults.slices2channels",slices2channels);

 	//call("ij.Prefs.set", "dialogDefaults.define_Nuc_ROIs",define_Nuc_ROIs);
 	call("ij.Prefs.set", "dialogDefaults.gBallSize",gBallSize);
 	call("ij.Prefs.set", "dialogDefaults.gNuclearMinArea",gNuclearMinArea);
 	call("ij.Prefs.set", "dialogDefaults.gBallSize",gBallSize);
 	call("ij.Prefs.set", "dialogDefaults.nucThreshold",nucThreshold);
 	call("ij.Prefs.set", "dialogDefaults.gaussRad",gaussRad);
 	call("ij.Prefs.set", "dialogDefaults.usRadius",usRadius);
 	call("ij.Prefs.set", "dialogDefaults.usMask",usMask);
 	call("ij.Prefs.set", "dialogDefaults.gDoWaterShed",gDoWaterShed);
 	call("ij.Prefs.set", "dialogDefaults.circThreshold",circThreshold);
 	call("ij.Prefs.set", "dialogDefaults.minSolid",minSolid);
 	call("ij.Prefs.set", "dialogDefaults.overwriteROIs",overwriteROIs);

	for(i=0;i<prevRoiShapes.length-1;i++) {
 			
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"shape",prevRoiShapes[i]);
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"channel",prevChannels[i]);
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"ballSize",prevBallSizes[i]);
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"gausRadii",prevGaussRadii[i]);
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"roiSize",prevRoiSizes[i]);
 		call("ij.Prefs.set", "dialogDefaults.c"+(i+1)+"threshold32",prevThreshold32s[i]);
	}
}

function arrayFind(arrayIn,querry) {
	foundQuerry = false;
   for (i=0; i<arrayIn.length;i++) {
   	 if (arrayIn[i]==querry) foundQuerry = true;
   }
   return foundQuerry;
	
}	

function getNumberAtRight(n) {

//modified in v3.5 to use regex to remove any letters from ROI names and take only numbers left of a hyhen
	cellID ="";
	for (i=0;i<lengthOf(n);i++) {
		ith = substring(n,i,i+1);	//get ith letter in "n"
		if ( matches(ith,"[0-9]")== true) cellID = cellID + ith; //add numbers to a growing string
		if ( matches(ith,"-")== true) i= lengthOf(n);   //if an - in encountered, stop
	} 
	cellID = parseInt(cellID);
/*
	isNotANumber = true;
	i= 0;
	end = lengthOf(n);
	cellID = -1; 
	while ( (isNotANumber == true) && (i<(end)) ) {
	 	isNotANumber = isNaN(parseInt(substring(n,i,end)));
	 	if (!isNotANumber) {
	 		cellID = parseInt(substring(n,i,end)); 
	 		//print(substring(n,i,end) + " contains a number");
	 	}
		i++;
	}
*/
	return cellID;
}

function callknnr(nNN) {

	ts0 = getTime();
	
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv use_file copy_column copy_row save_column"); //set Results saving settings to not use  row #s or col headers for R compatability
	//run("Input/Output...", "jpeg=85 gif=-1 file=.csv use_file copy_column copy_row"); //set Results saving settings to not use  row #s or col headers for R compatability
	
	refXout = xRefCOM; refYout = yRefCOM; //first pass at NN calculations will be based on COM

	someNAN = false;
	for (i=0;i<refXout.length;i++) {
		// print NN X&Y pairs to Results and save as csv for Rscript nn2
		if (isNaN(refXout[i]) || isNaN(refYout[i])) someNAN = true;
		setResult("X",nResults,refXout[i]);
		setResult("Y",nResults-1,refYout[i]);
	}

	if (someNAN == true) exit("some of your reference ROIS have NaN (not a number) values of their \n XM or YM (centres of mass) check your ROIs in: \n" + refROIFile);

	nn2Dir = 	getDirectory("home") +  "Fiji2nn2" + File.separator;  // to prevent multiple computers saving nn2 files to a shared and potentially conflicted folder
   		 															// nn2 files are saved to the users 'home' directory				
	if (!File.exists(nn2Dir)) File.makeDirectory(nn2Dir);

	path4Rref = nn2Dir+"ref.csv";
	path4Rnn1 = nn2Dir+"nn1.csv"; //save to csv in Fiji folder
	path4Rnn2 = nn2Dir+"nn2.csv"; //save to csv in Fiji folder
	path4Rnn3 = nn2Dir+"nn3.csv"; //save to csv in Fiji folder
	path4Rnn4 = nn2Dir+"nn4.csv"; //save to csv in Fiji folder
	if (File.exists(path4Rref) ) fd = File.delete(path4Rref);
	if (File.exists(path4Rnn1) ) fd = File.delete(path4Rnn1);
	if (File.exists(path4Rnn2) ) fd = File.delete(path4Rnn2);
	
	saveAs("Results", path4Rref); //save csv for R to read
	if (File.exists(path4Rref)) {
		print("\\Update6: path4Rref saved");
		wait(200);
	} else {
		exit("Failure in saving refence csv files for nn2 in R");
	}

	run("Clear Results");
	for (i=0;i<querry1X.length;i++) {
		// print NN X&Y pairs to Results and save as csv for Rscript nn2
		setResult("X",nResults,querry1X[i]);
		setResult("Y",nResults-1,querry1Y[i]);
	}
	saveAs("Results", path4Rnn1);
	run("Clear Results");
	if (File.exists(path4Rnn1)) {
		print("\\Update6: path4nn1 saved");
		wait(200);
	} else {
		exit("Failure in saving NN1 csv files for nn2 in R");
	}
	
	if (nSlicesToAnalyze>1) {
		run("Clear Results");
		// save NNc2 XYs to csv
		for (i=0;i<querry2X.length;i++) {
			setResult("X",nResults,querry2X[i]);
			setResult("Y",nResults-1,querry2Y[i]);
		}
		saveAs("Results", path4Rnn2);
		run("Clear Results");
		if (File.exists(path4Rnn2)) {
			print("\\Update6: path4nn2 saved");
			wait(200);
		} else {
			exit("Failure in saving NN2 csv files for nn2 in R");
		}
	}
	
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv use_file copy_column copy_row save_column");   // resest Results table saving options. 
	// do not use the "save_row" options here, or the RScript will see row numbers as X and X values as Y
	print("\\Update0: time to save ROIs to csv..." + getTime()-ts0);
	
	// =====  call to Rscript for nn2   ==========================================================================
	
	//Input sets: Find nearest neighbours to setA in setB (ie. what are the nearest POLG to each dsDNA)
	//results file will have equal # of rows to setA
	setB = path4Rnn1;     // the MINER nn ROIs are the training set in R
	setC = path4Rnn2;     // the MINER nn ROIs are the training set in R
	setA =  path4Rref;  // the MINER ref ROIs are the test set in R
	
	scriptName = getDirectory("plugins")+ "Macros" + File.separator + "kNNScript.R";
	if (File.exists(scriptName)==false) exit("Could not find KNNScript.R in the Plugins>Macros directory. /NThis file is required for nearest neighbour calculations");
	if (verbose == true) print("scriptName = "+ getDirectory("plugins")+ "Macros" + File.separator + "kNNScript.R");

	outputName1 = nn2Dir+"nn2Results1";
	outputName2 = nn2Dir+"nn2Results2";
	//outputName3 = getDirectory("imagej")+"nn2Results3";
	//outputName4 = getDirectory("imagej")+"nn2Results4";
	
	//How many nearest neighbours do you want to find?
	kNN= maxOf(5,numNNstats);
	tr0= getTime();
	print("\\Update9: Starting RScript");
	//Command line script --> note 2>&1 redirects stdout to the log file, allows for debugging of command line arguments
	logText = getInfo("log");
	
	//exec("Rscript",scriptName,setA,setB,kNN,outputName1,"plot","2>&1");   // credit Anita dos Santos
	exec("Rscript",scriptName,setA,setB,kNN,outputName1,"2>&1");   // credit Anita dos Santos, should run slightly faster without making and saving plots

	if (nSlicesToAnalyze>1) {
		//exec("Rscript",scriptName,setA,setC,kNN,outputName2,"plot","2>&1");
		exec("Rscript",scriptName,setA,setC,kNN,outputName2,"2>&1");
	}
	print("\\Clear");
	if (verbose == true) print(logText);
	print("\\Update10: Rscript took " + getTime()-tr0 + " ms for "+nSlicesToAnalyze+" channel(s)");
	
	run("Clear Results");
	for (w=0;w<3;w++) {
		if (!File.exists(outputName1+".csv")) {
			wait(300);
		}
	}	
	if (!File.exists(outputName1+".csv")) {
		exit("no output file found from call to kNNScript.R");
	} else {
		open(outputName1+".csv");
	}
	if (nSlicesToAnalyze>1) {
		if (!File.exists(outputName2+".csv")) wait(500);
		open(outputName2+".csv");
	}
	// now 
	
	//need to decide if we want to reference table values on the fly or store in arrays. 
	
	//===============================================================================================================================
	// ADAPTING TO USING Rscript nn2 - should simply have to create an array of the ROIs indices of the kNN and compare those wrt dFromP
	//v2.3m(nn2)

tProfiler = getTime(); //1000 ms

selectWindow("nn2Results1.csv"); //this imposes a good 1000 ms cost. Need to reduce to one call, which means a kNN x nRefs array. 

print("\\Update5: Table.size " + Table.size() + " nROIs: " +nROIs);


bigNn2IndicesNNC1 = newArray(kNN*Table.size());
bigNn2DistancesNNC1 = newArray(kNN*Table.size());

for (currROI=0; currROI<nROIs; currROI++) { 		
	for (k=0;k<kNN;k++) {
		//print("id"+k+ " currROI " + currROI);
		bigNn2IndicesNNC1[currROI*kNN+k] = Table.get("id"+(k+1), currROI); 
		bigNn2DistancesNNC1[currROI*kNN+k] = Table.get("dist"+(k+1), currROI);
		//stopped here
	}
}



if (nSlicesToAnalyze>1) {
	bigNn2IndicesNNC2 = newArray(kNN*Table.size());
	bigNn2DistancesNNC2 = newArray(kNN*Table.size());

	selectWindow("nn2Results2.csv");
	bigNn2IndicesNNC2 = newArray(kNN*Table.size());
	bigNn2DistancesNNC2 = newArray(kNN*Table.size());
	for (currROI=0; currROI<nROIs; currROI++) { 		
		for (k=0;k<kNN;k++) {
			bigNn2IndicesNNC2[currROI*kNN+k] = Table.get("id"+(k+1), currROI); 
			bigNn2DistancesNNC2[currROI*kNN+k] = Table.get("dist"+(k+1), currROI);
		}
	}
}


print("\\Update9: pull indices from csv table : "+ (getTime()- tProfiler) + " ms");



	
}


	
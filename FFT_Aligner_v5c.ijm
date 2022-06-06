/* 
Created by Damon Poburko, March 2011, Stanford University. dpoburko@stanford.edu
This macro is meant to take in stacks of grey scale or composite images (2-3 channels) and align them using a Fourier-transform theorem. 
Handles 8-bit, 16-bit & composite
130404: DP - tweaked to align a stack with a moving reference
                should at some point could set up to handle composite multi-Z stks
v3.4 131028 
	- incorporate aligning of multicolour/channel images
	- output saved to a new subfolder
	- just need to work out saving of files
v3.7 140709
	- handles larger CMOS images
v4.0 - aligns multi-channel images
v4d - should handle both multi-frame and multi-slice Image stacks
v4e&f - skipped due to bugs I lost track of
v4g - 
	1. For serial registration, make sure that subsequent frames are aligned to the best alignment of the frame before them, rather than its original and likely misalign position. - Rookie mistake!
	2. Go back to version 4d
		a. If in coming stack has 1 frame and n slices, simply prompt to convert slices to frames
		b. If multiple frames and slices, if aligning by slices, swap frames and slices at start of aligning by frames loop, then swap back
	3. Align by re-sampled image, 
		a. Should be able to do a quick align by 10x down sample - should be really fast, then go back to desired level with a smaller ROI
		b. Work out image references such that when down sampling, the full image is returned
    4.Figure out why align by color/channel check box isn't being remembered.
*/


//=== 1A. iNITIAL DIALOG & SETUP======================================================================================
//================================================================================================================

//macro "DTP_FFT_Aligner_batch_v4c" { 

requires("1.46c");
 version = "5b";

w0 = 0;
h0 = 0;
channels = 0;
slices = 0;
frames = 0;
var xBest = 0;
var yBest = 0;

referenceImg = getTitle();
imgDir = getDirectory("image");//this needs to be here to not to mistake the imageJ directory as the save directory


if (nImages>0) {
	Stack.getDimensions(w0, h0, channels, slices, frames);
}
maxDim = maxOf(h0,w0);
minDim = minOf(h0,w0);
originalBitDepth = bitDepth();
if (bitDepth() == 8) run("16-bit");

doDimSwap = false; 

var	refSlice = 1;
var	refChannel = 1;
var	refFrame = 1;
var  maxTranslation = 1;
dimsLabels = newArray("channels","slices","frames");
nDims = 3;
dimsDone = newArray(1,1,1);  // an array of 0=no, 1=yes to align by channel, slice or frame as indec 0,1,2
if (channels==1) dimsDone[0] =0;
if ((frames>1)||(slices>1)) dimsDone[0] =0;
if (slices==1) dimsDone[1] =0;
if (frames==1) dimsDone[2] =0;
if ((slices>1)&&(frames==1)) dimsDone[1] = 1;
if ((slices==1)&&(frames>1)) dimsDone[2] = 1;

subRgnPref = call("ij.Prefs.get", "dialogDefaults.doSubRgn", "full image");
subRgnArray = newArray(subRgnPref,"full image","32","64","128","256","512","1024","2048");
	
//----- Throw warning if active image is not 8-bit or 16-bit --------

if (channels>1) {
	rcText =  "[rc] Set reference channel (base 1)";
	rcDefault = parseInt (call("ij.Prefs.get", "dialogDefaults.refChannel", 1));
} else {
	rcText =  "[rc] Single channel image. Reference channel is 1";
	rcDefault = 1;
}
if (frames>1) {
	rfText = "[rf] Set reference frame (base 1, -1 = serial)";
	rfDefault = parseInt (call("ij.Prefs.get", "dialogDefaults.refFrame", -1));
} else {
	rfText = "[rf] Single Frame image. Reference frame is 1";
	rfDefault = 1;
}
if (slices>1) {
	rsText = "[rs] Set reference slice (base 1, -1 = serial)";
	rsDefault = parseInt (call("ij.Prefs.get", "dialogDefaults.refSlice", -1));
} else {
	rsText = "[rs] Single slice image. Reference slice is 1";
	rsDefault = 1;
}
 
Dialog.create("FFT Aligner v"+version);
if ((frames>1) && (slices>1)) {
	Dialog.addMessage("~~~ ALIGN SLICES AND FRAMES IN SEQUENTIAL RUNS OF THE MACRO!! ~~~");
	Dialog.addMessage(" ");
}
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Current image has "+channels+" channels, "+slices+" slices & "+frames+" frames.");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Select dimensions to be aligned:");
Dialog.setInsets(0, 20, 10);
Dialog.addCheckboxGroup(1, 3, dimsLabels, dimsDone);
Dialog.addNumber(rcText, rcDefault);
Dialog.addNumber(rsText, rsDefault);
Dialog.addNumber(rfText, rfDefault);
Dialog.addChoice("[subRgn] align by subregion (smaller = faster)", subRgnArray);
Dialog.addCheckbox("[place] the subregion used for alignment",  call("ij.Prefs.get", "dialogDefaults.placeBox", false));
Dialog.addNumber("[resample] image:  smaller is faster, but less accurate: ", parseFloat(call("ij.Prefs.get", "dialogDefaults.dsFactor", 1.0)), 2, 6, "");
//Dialog.addCheckbox("label aligned RGB image with offsets", call("ij.Prefs.get", "dialogDefaults.labelAligned", false));
Dialog.addNumber("[ftsz] font size of offset labels", parseInt (call("ij.Prefs.get", "dialogDefaults.fontSize", 18)));
Dialog.addNumber("[mxmv] maximum translation is", parseInt (call("ij.Prefs.get", "dialogDefaults.maxTranslation", 20)),0,6,"pixels");
Dialog.addCheckbox("[save] aligned output images", call("ij.Prefs.get", "dialogDefaults.autoSave", false));
Dialog.addCheckbox("[bpfft] bandpass FFT image. Slower but more precise.", call("ij.Prefs.get", "dialogDefaults.useBP", false));
Dialog.addCheckbox("[crop] aligned image to remove blank borders", call("ij.Prefs.get", "dialogDefaults.doCrop", true));
Dialog.addCheckbox("[called] from another macro.", false);
//Dialog.addCheckbox("[closeall] close all images on completion", parseInt (call("ij.Prefs.get", "dialogDefaults.closeAll", true)));
//Dialog.addCheckbox("[dobatchp] disable Batchmode for debugging.", false);
//Dialog.addCheckbox("[suppressdlg] suppress dialogs for batch processing.", call("ij.Prefs.get", "dialogDefaults.suppressDialogs", false));
Dialog.show();
//----------------------------------------------------------------------------------------

for (i=0;i<nDims;i++) {
	dimsDone[i] = Dialog.getCheckbox();
}
refChannel = Dialog.getNumber;	
	call("ij.Prefs.set", "dialogDefaults.refChannel",refChannel);
refSlice = Dialog.getNumber;	
if (slices>1) {
	call("ij.Prefs.set", "dialogDefaults.refSlice",refSlice);
} else {
	refSlice =1;
	call("ij.Prefs.set", "dialogDefaults.refSlice",refSlice);
}
refFrame = Dialog.getNumber;	
	call("ij.Prefs.set", "dialogDefaults.refFrame",refFrame);
doSubRgn = Dialog.getChoice();
	call("ij.Prefs.set", "dialogDefaults.doSubRgn", doSubRgn);
placeBox = Dialog.getCheckbox();
  	call("ij.Prefs.set", "dialogDefaults.placeBox", placeBox);
dsFactor = Dialog.getNumber();
if (dsFactor<0) {
		exit("The resamping factor ("+dsFactor+") must be positive \nPlease choose a new value in the dialog box.");
}
	call("ij.Prefs.set", "dialogDefaults.dsFactor", dsFactor);
  //labelAligned = Dialog.getCheckbox();
	//call("ij.Prefs.set", "dialogDefaults.labelAligned", labelAligned);
fontSize = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.fontSize", fontSize);
	setFont("SansSerif", fontSize, " antialiased");
	setForegroundColor(255, 255, 255);
maxTranslation = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.maxTranslation", maxTranslation);
autoSave = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.autoSave", autoSave);
useBP = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.useBP", useBP);
//closeAll = Dialog.getCheckbox();
closeAll = false;
	call("ij.Prefs.set", "dialogDefaults.closeAll", closeAll);
doCrop = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.doCrop", doCrop);

calledFromAotherMacro = Dialog.getCheckbox();
//batchOff = Dialog.getCheckbox();
batchOff = false;
//suppressDialogs = Dialog.getCheckbox();
suppressDialogs = false;
//call("ij.Prefs.set", "dialogDefaults.suppressDialogs", suppressDialogs);

run("Clear Results");	
if (calledFromAotherMacro==false){
	print("\\Clear");
}

tStart = getTime();
/*
 * moved to ~287 to accomodate moving the cropping box / rgeion  used for alignment
if (batchOff == false) {
	setBatchMode(true);
}
*/

//remove the original image suffix	
im2OriginalName = referenceImg;
suffix = "";
if (indexOf(referenceImg,".")!=-1) {
	suffix = substring(referenceImg, lastIndexOf(referenceImg, "."), lengthOf(referenceImg));
	referenceImg = replace(referenceImg,suffix,"");
	referenceImg = replace(referenceImg," ","_");
	rename(referenceImg);
}
im2Renamed = referenceImg;

//check or select directory to save output to.
if (autoSave==true) {
	if ((imgDir=="")&&(calledFromAotherMacro==false)) {
	  imgDir = getDirectory("Please select destination folder");
	}
	if ((imgDir=="")&&(calledFromAotherMacro==true)) {
	  imgDir = getDirectory("temp");
	}

	destFolder = "fftAligner"+version;
	savePath = imgDir + destFolder;	
	if (File.isDirectory(savePath)!=1) {
		File.makeDirectory(savePath); 
		print("\\Update1: createed folder "+savePath);
	}
} else {
	print("\\Update1: autoSave == false");
}

//Make a copy of the original image
//img0 = getTitle();
dup0 = referenceImg+"_dup0";
img2Align = "img2Align";
run("Duplicate...", "title="+dup0+" duplicate");

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// SCALING - if scaleFactor != 1.0m then scale the duplicated image
if (dsFactor!=1.0) {
	run("Scale...", "x="+dsFactor+" y="+dsFactor+" z=1.0 width="+floor(dsFactor*w0)+" height="+floor(dsFactor*h0)+" depth="+frames+" interpolation=Bilinear average process create");
	rename("temp");
	selectWindow(dup0);
	close();
	selectWindow("temp");
	rename(dup0);
}	
Stack.getDimensions(w1, h1, c1, s1, f1);
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//v4g - SWAP SLICES & FRAMES - If aligning by slices, swap the slices for frames. This allows for coding only frame alignment. 
if ((dimsDone[2]==0) && (dimsDone[1]==1)) {
	selectWindow(dup0);
	Stack.getDimensions(w0, h0, channels, oSlices, oFrames);
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	Stack.getDimensions(w0, h0, channels, slices, frames);
	//swap reference channel and slice values, then swap them back at the end of the macro
	oRefFrame = refFrame;
	oRefSlice = refSlice;
	refFrame = oRefSlice;
	refSlice = oRefFrame;
	doDimSwap = true; 
	print("\\Update6: Swapped frames ("+oFrames+"->"+frames+") and slices ("+oSlices+"->"+slices+") for " +getTitle());
	//swap frames and slices and swap back at end of the macro
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// SELECT A SUB-REGION of the image to align to speed up the alignment

	if  (doSubRgn == "full image") {
		power = floor(log(minOf(w1,h1))/log(2));	
		subRgnSize = pow(2,power);
	}
	if  (doSubRgn != "full image")  subRgnSize = parseInt(doSubRgn);
	while (minDim < subRgnSize) {
		subRgnSize = subRgnSize /2;
	}
	//Even if aligning by "full image", the region used for alignment must have dimensions that are a power of 2 
	//So it likely still needs to be cropped
	if (placeBox==false) { 
		//use a cropping box centered on the image
		selectWindow(dup0);
		makeRectangle( ( floor(w1-subRgnSize)/2) , floor(( h1-subRgnSize)/2) , subRgnSize, subRgnSize);
		getSelectionBounds(selX, selY, wSub, hSub);
	
	} else  {     
		//Allow the user to place the cropping box - Note that this isn't feasible in batch processing many files
		//selectWindow(referenceImg);
		selectWindow(dup0);
		makeRectangle( ( floor(w1-subRgnSize)/2) , floor(( h1-subRgnSize)/2) , subRgnSize, subRgnSize);
		waitForUser("Move the box to the region that will be used for alignment.");
		getSelectionBounds(selX, selY, wSub, hSub);
		//run("Select None");
		//selectWindow(dup0);
		//makeRectangle(selX, selY, wSub, hSub);
	}

	//activation of batch mode was moved from line ~180 to hear to side-step an issue of not being able to draw/move cropping boxes
	// when pausing batchmode
	if (batchOff == false) {
		setBatchMode(true);
		selectWindow(dup0);
		setBatchMode("hide");
	}

	run("Crop");
	Stack.getDimensions(w1, h1, c1, s1, f1);

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	//framework of moving through the alignment
	slicesDone = slices;
	channelsDone = channels;
	framesDone = frames;
	dupCmdList = newArray(frames*slices*channels);
	
	//if (dimsDone[0]==0) channelsDone=
	dx = newArray(frames*slices*channels);
	dy = newArray(frames*slices*channels);
	dxf = newArray(frames);
	dyf = newArray(frames);
	dxs = newArray(slices);
	dys = newArray(slices);
	dxc = newArray(channels*frames);
	dyc = newArray(channels*frames);
	Array.fill(dxf, 0);
	Array.fill(dyf, 0);
	Array.fill(dxs, 0);
	Array.fill(dys, 0);
	Array.fill(dxc, 0);
	Array.fill(dyc, 0);

	// Generate the initial reference image for alignment. This will be overridden if using serial registration
	imgRef = "imgRef";
	dupCmd = "";
	if (channels>1) dupCmd = dupCmd + " channels="+refChannel;
	if (slices>1) {
		if (channels>1) {
			dupCmd = dupCmd + " slices="+refSlice;
		}else{
			dupCmd = dupCmd + " range="+refSlice;
		}
	}
	if (frames>1) {
		if (channels>1) {
			dupCmd = dupCmd + " frames="+refFrame;
		}else{
			if (doDimSwap==true) { //this seems to be a quirk, where an original stack of frames uses "range" to dup a single image, but a stack of slices>frames uses "frames
				dupCmd = dupCmd + " frames="+refFrame;
			} else {
			 	dupCmd = dupCmd + " range="+refFrame;
			}
		}
	}
	selectWindow(dup0);
	run("Duplicate...", "title="+imgRef+" duplicate "+dupCmd);

s=1;

tf0 = getTime();		
		//step through all the frames in the stack to align frame (or slices re-ordered as frames) and channels
	for (f=1;f<=frames;f++) {

td1 = getTime();
		if ((dimsDone[2] == 1)||(dimsDone[1] == 1)) {	//if aligning by frame, align frames on ref channel		
			dupCmd = "";
			//Generate the text/string for the command to duplicate the reference image. Multiple hyperstack possibilities and syntaxes need to be accounted for
			if (channels>1) dupCmd = dupCmd + " channels="+refChannel;
			if (slices>1) {
				if (channels>1) {
					dupCmd = dupCmd + " slices="+refSlice;
				}else{
					dupCmd = dupCmd + " range="+refSlice;
				}
			}
			if (frames>1) {
				if (channels>1) {
					dupCmd = dupCmd + " frames="+f;
				}else{
					if (doDimSwap==true) { //this seems to be a quirk, where an original stack of frames uses "range" to dup a single image, but a stack of slices>frames uses "frames
						dupCmd = dupCmd + " frames="+f;
					} else {
					 	dupCmd = dupCmd + " range="+f;
					}
				}
			}
			
			//create the copy of the image to be aligned
			if (isOpen(img2Align))  close(img2Align);
			selectWindow(dup0);
			run("Duplicate...", "duplicate title="+img2Align+dupCmd);
			print("\\Update2: calcualting offset: f"+f+" of "+frames);			

			// v4g Updated SERIAL REGISTRATION: generate a rolling reference image of the previously aligned image
			if (refFrame == -1) {
				imgRef = "imgRef";
				dupCmd = "";
				//Generate the text/string for the command to duplicate the reference image. Multiple hyperstack possibilities and syntaxes need to be accounted for
				if (channels>1) dupCmd = dupCmd + " channels="+refChannel;
				if (slices>1) {
					if (channels>1) {
						dupCmd = dupCmd + " slices="+refSlice;
					}else{
						dupCmd = dupCmd + " range="+refSlice;
					}
				}
				if (frames>1) {
					if (channels>1) {
						dupCmd = dupCmd + " frames="+(f-1);
					}else{
						if (doDimSwap==true) { //this seems to be a quirk, where an original stack of frames uses "range" to dup a single image, but a stack of slices>frames uses "frames
							dupCmd = dupCmd + " frames="+(f-1);
						} else {
						 	dupCmd = dupCmd + " range="+(f-1);
						}
					}
				}
				if (isOpen(imgRef))  close(imgRef);
				selectWindow(dup0);
				run("Duplicate...", "title="+imgRef+" duplicate "+dupCmd);
				selectWindow(imgRef);
				//translate the previous image based on the previous lap's results. Of course when f=1, then frame 0 translation will be 0
				if (f>1) {
					translate(dxf[f-2],dyf[f-2]);	
				}
				dupCmdList[f-1]=dupCmd; 
				//print("\\Update5: dupCmd" + dupCmd);
			}
		
td2 = getTime();
			//Call the fftAlinger
			deltas = fftAligner(imgRef, img2Align);
td3 = getTime();
			selectWindow(img2Align);
			close();
			deltaSplit = split(deltas, ".");
			dxf[f-1] = parseInt(deltaSplit[0]) / dsFactor;
				//if (dxf[f-1]>maxTranslation) dxf[f-1] = 0;
			dyf[f-1] = parseInt(deltaSplit[1]) / dsFactor;
				//if (dyf[f-1]>maxTranslation) dyf[f-1] = 0;
			print("\\Update2: calcualting offset: f"+f+" of "+frames + "dx,dy: "+dxf[f-1]+","+dyf[f-1]);
			//print("\\Update3: time to duplicate image: "+ d2s( (td2-td1)/1000, 4)+ " s");
			print("\\Update3: time to calc FFT: "+ d2s( (td3-td2)/1000, 4)+ " s");
			
		} else {
			f=frames;    //v4d
		}
tf1 = getTime();		

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//v4g - Align frame and slice in sequential runs of the macros. 
//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//v4g - Align channels below - not quite working just write. 
//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

		//CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
		//ALIGN CHANNELS. Will adapt to align only reference. 
		//Otherwise, all channels will be translated for alignment of frame/slice on reference channel
		if (dimsDone[0] == 1) {	//if aligning by frame, align frames on ref channel		

			for (c=1;c<=channels;c++) {				
				print("\\Update0: aligning c"+c+" of "+channels);
				
				//No need to align refChannel against itself. dxc & dyc are already 0 in the array
				
				if (c!=refChannel) {
					//Generate the text/string for the command to duplicate the reference image. Multiple hyperstack possibilities and syntaxes need to be accounted for
					// For a single reference frame....
					dupCmd = " channels="+c;
					if (slices>1) {
						if (channels>1) {
							dupCmd = dupCmd + " slices="+refSlice;
						}else{
							dupCmd = dupCmd + " range="+refSlice;
						}
					}
					if (frames>1) {
						if (channels>1) {
							dupCmd = dupCmd + " frames="+f;
						}else{
							dupCmd = dupCmd + " range="+f;
						}
					}
					if (isOpen(img2Align))  close(img2Align);
					selectWindow(dup0);
					run("Duplicate...", "title="+img2Align+" duplicate "+dupCmd);
					dupCmdList[(f-1)*c1+(c-1)] = "img2Align: "+img2Align+dupCmd;
					//v4g SERIAL REGISTRATION: Generate a rolling reference image of the previously aligned image
					if (refFrame == -1) {
					
						dupCmd = " channels="+refChannel;
						if (slices>1) {
							if (channels>1) {
								dupCmd = dupCmd + " slices="+refSlice;
							}else{
								dupCmd = dupCmd + " range="+refSlice;
							}
						}
						if (frames>1) {
							if (channels>1) {
								dupCmd = dupCmd + " frames="+(f);
							}else{
								dupCmd = dupCmd + " range="+(f);
							}
						}
						if (isOpen(imgRef))  close(imgRef);
						selectWindow(dup0);
						run("Duplicate...", "title="+imgRef+" duplicate "+dupCmd);
						//print("\\Update5: dupCmd" + dupCmd);
						selectWindow(imgRef);
						dupCmdList[(f-1)*c1+(refChannel-1)]= "serial ref: "+dupCmd; 
					}
					
					deltas = fftAligner(imgRef, img2Align);
					deltaSplit = split(deltas, ".");
					selectWindow(img2Align);
					close();
					dxc[(f-1)*channels+c-1] = parseInt(deltaSplit[0]);
					dyc[(f-1)*channels+c-1] = parseInt(deltaSplit[1]);	
				}//if (c!=refChannel) {
			}//for (c=1;c<=channels;c++) {	
		}//if (dimsDone[0] == 1) {
		//CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
	}//for (f=1;f<=frames;f++) {


//make a copy of the original image
aligned = referenceImg+"_aligned";
selectWindow(referenceImg);
run("Duplicate...", "title="+aligned+" duplicate");

//If the first duplicate hyperstack was swapped (Frames→←Slices), then the original images needs to be temporarily swapped to be translated.
if (doDimSwap == true ) {
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
}

minDx = 0;
maxDx = 0;
minDy = 0;
maxDy = 0;

// IMAGE TRANSLATION STEP: - For each frame, slice, channel, translate by appropriate Frame & Channel offset.
//  Note that slices are not simultaneously aligned currently
if  ((dimsDone[2]==1)||(dimsDone[1]==1)) {
	print("\\Update5: entered labelling loop for "+slices+" slices, "+frames+" frames, and "+channels+" channels");
	selectWindow(aligned);
	for (f=1;f<=frames;f++) {
		for (s=1;s<=slices;s++) {
			for (c=1;c<=channels;c++) {	
				
				Stack.setPosition(c, s, f);		
				translate(dsFactor*dxf[f-1] + dsFactor*dxc[(f-1)*channels+c-1] , dsFactor*dyf[f-1] + dsFactor*dyc[(f-1)*channels+c-1]);
				ovrTxt = "C:"+c+" dx " + (dsFactor*dxf[f-1] + dsFactor*dxc[(f-1)*channels+c-1]) + " dy "+ (dsFactor*dyf[f-1] + dsFactor*dyc[(f-1)*channels+c-1] );
				print("\\Update4: translating f:"+f+" c:"+c +" "+ ovrTxt);
		    	makeText(ovrTxt, floor(w0*0.03), floor(h0*0.03)+(c-1)*fontSize);
				run("Add Selection...", "stroke=#f2efae  set"); //fill=#660000ff
				Overlay.setPosition(c,s,f);
				if (minDx > (dsFactor*dxf[f-1])) minDx = dsFactor*dxf[f-1];
				if (maxDx < (dsFactor*dxf[f-1])) maxDx = dsFactor*dxf[f-1];
				if (minDy > (dsFactor*dyf[f-1])) minDy = dsFactor*dyf[f-1];
				if (maxDy < (dsFactor*dyf[f-1])) maxDy = dsFactor*dyf[f-1];
			}	
		}
	}
}
//Crop the aligned image to exlude the empty border areas that mess up ROI selection
if (doCrop==true) {
	makeRectangle(maxDx, maxDy, w0+minDx-maxDx, h0+minDy-maxDy);
	run("Crop");
}


//If the first duplicate hyperstack was swapped (Frames→←Slices), the offset labels will be lost and need to be redone. 
if ((doDimSwap == true ) || (dimsDone[1]==1)) {
	
	//swap frames and slices and swap back to their original state
	print("\\Update5: Swapping "+frames+" frames back to " + slices + " slices");
	selectWindow(aligned);
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	Stack.getDimensions(w0, h0, channels, slices, frames);
	print("\\Update5: relabelling "+slices+" slices, "+frames+" frames, and "+channels+" channels");
	
	for (s=1;s<=slices;s++) {
		for (f=1;f<=frames;f++) {
			for (c=1;c<=channels;c++) {	
				print("\\Update4: relabelling "+IJ.pad(slices-s, 3)+" slices.");
				
				Stack.setPosition(c, s, f);		
				ovrTxt = "C:"+c+" dx " + (dsFactor*dxf[s-1] + dsFactor*dxc[(s-1)*channels+c-1]) + " dy "+ (dsFactor*dyf[s-1] + dsFactor*dyc[(s-1)*channels+c-1] );
				//print("\\Update4: translating f c "+f+" "+c + ovrTxt);
				// pixelsHigh = 0.71*FontSize + 0.29
		    	makeText(ovrTxt, floor(w0*0.03), floor(h0*0.03)+(c-1)*fontSize);
				run("Add Selection...", "stroke=#f2efae  set"); //fill=#660000ff
				Overlay.setPosition(c,s,f);
			}	
		}
	}
	//In order to avoid having the labels appear as overlapping, the image needs to be in color rather than composite mode.
	Property.set("CompositeProjection", "null");
	Stack.setDisplayMode("color");
}

//Tidy Up!
run("Select None");
if (isOpen(imgRef))  close(imgRef);
if (isOpen(dup0)) close(dup0);

//add maximal offets to aligned image metadata
md = getMetadata("Info");
md = md + "\n"+"Offsets:";
md = md + "\n"+"minDx: "+minDx;
md = md + "\n"+"maxDx: "+maxDx;
md = md + "\n"+"minDy: "+minDy;
md = md + "\n"+"maxDy: "+maxDy;
md = md + "\n";
setMetadata("Info", md);

setBatchMode("exit and display");

if (autoSave==true) {
	selectWindow(aligned);
	print("\\Update5: saving "+savePath+File.separator+aligned+".tif");
	saveAs("Tiff", savePath+File.separator+aligned+".tif");

}
print("\\Update5: Image alignment complete");


//=== THE END =====================================================================================================


//=================================================================================================================
//===================================== LIST OF FUNCTIONS ==========================================================
//=================================================================================================================

//Part 4. ===========================================================================================================
function fftAligner(refImg, targetImg) {
//=================================================================================================================

//"refSlice" is now a global variable
// re-writing to make the function simply align the images and report the X/y offset
 
// Part 4a. Set up the basics============================================================================================
	selectWindow(refImg);
	xBest = 0;
	yBest = 0;
	h2 = getHeight();
	w2 = getWidth();
	padImg1 = "padImg1"; 
	padImg2 = "padImg2";

// Part 4c. FFT alignment of Image Pair and calculation of offset ===================================================================================
	newImage(padImg1, "16-bit Black", 2*w2, 2*h2, 1);
	//run("Add Specified Noise...", "standard=5.50");
	selectWindow(targetImg);
	run("Duplicate...", "title=[tempTarget]");
	//run("Subtract Background...", "rolling=20");
	run("Copy");
	close();
	selectWindow(padImg1);
	run("Paste");

	newImage(padImg2, "16-bit Black", 2*w2, 2*h2, 1);
	//run("Add Specified Noise...", "standard=5.50");
	selectWindow(refImg);
	run("Duplicate...", "title=[temp]");
	//run("Subtract Background...", "rolling=20");
	run("Copy");
	close();
	selectWindow(padImg2);
	run("Paste");

	run("FD Math...", "image1="+padImg1+" operation=Correlate image2="+padImg2+" result=Result do");
	corrWidth = getWidth();
	run("Divide...", "value="+(corrWidth*corrWidth)); //FD Math gives sum over all pixels; convert to mean
	if (useBP==true) run("Bandpass Filter...", "filter_large=4 filter_small=0 suppress=None tolerance=5");
	getStatistics(fftArea, fftMean, fftMin, fftMax);
	//run("Subtract Background...", "rolling=3");
	//run("Find Maxima...", "noise=1000 output=List");
	run("Find Maxima...", "noise="+fftMax/2+" output=List");

	//v4.0 - set as global variable and assigned to storage array in alignment loop
/*
	bestXs =newArray();
	bestys =newArray();
	minOffset = sqrt( pow(h2,2)+pow(w2,2));
	minOffsetIndex=0;
	for (n=0;n<nResults;n++) {
		bestXs = Array.concat(bestXs, (getResult("X",n) - corrWidth/2)*-1);
		bestYs = Array.concat(bestYs, (getResult("Y",n) - corrWidth/2)*-1);
		if (minOffset > sqrt( pow(bestXs[n],2)+pow(bestYs[n],2))) {
			minOffset = sqrt( pow(bestXs[n],2)+pow(bestYs[n],2));
			minOffsetIndex = n;
		}
	}
	xBest = bestXs[minOffsetIndex];  
	yBest = bestYs[minOffsetIndex];
*/
	xBest = (getResult("X",0) - corrWidth/2)*-1;
	yBest = (getResult("Y",0) - corrWidth/2)*-1;
	center = corrWidth/2;
			
	selectWindow(padImg2);			close();
	selectWindow(padImg1);			close();
	selectWindow("Result");			close();
	if ( sqrt( pow(xBest,2)+pow(yBest,2))>maxTranslation){
		xBest=0;
		yBest=0;
	}
	if (abs(xBest)>maxTranslation) xBest = 0;
	if (abs(yBest)>maxTranslation) yBest = 0;
	
	deltasOut = ""+xBest+"."+yBest+"";
	//print("\\Update3: deltasOut: "+deltasOut);
	return deltasOut;

//===============================================================================================================
} //close fftAligner() //-------------------------------------------------------------------------------------------------------------------------------------------------------
//===============================================================================================================

// Part 5. =========================================================================================================
function imgLister(imgList) {  //---------------------------------------------------------------------------------------------------------------------------------------------
// ===============================================================================================================

	list = getList("window.titles");
		if (nImages==0) {
			showMessage("You need at least 2 images \N or a  stack to run this macro");
		} else {
			setBatchMode(true);
			for (i=1; i<=nImages; i++) {
				selectImage(i);
				imgList[i+1] = getTitle();
			}
			//imgList[nImages+1] = "none";
		setBatchMode(false);
		}

return imgList;
//===============================================================================================================
} // close imgLister // --------------------------------------------------------------------------------------------------------------------------------------------------------
//===============================================================================================================

function findInArray(array,query) {
	position=-1;
	for(i=0;i<array.length;i++) {
		if (array[i]==query) position = i;
	}
	return position;
}

function translate(x, y) {
  run("Select All");
  run("Cut");
  makeRectangle(x, y, getWidth(), getHeight());
  run("Paste");
  run("Select None");
}


//} // close macro



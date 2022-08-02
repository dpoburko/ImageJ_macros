/*
This batch shell pairs with the accompanying FFT_Aligner macro


*/

print("\\Clear");

refSlice = 1;
refChannel = 1;
refFrame = 1;
slicesOrFrames = newArray("Frames","Slices");
dimsLabels = newArray("channels","slices","frames");
nDims = 3;
dimsDone = newArray(0,0,1);  // an array of 0=no, 1=yes to align by channel, slice or frame as indec 0,1,2
subRgnPref = call("ij.Prefs.get", "dialogDefaults.doSubRgn", "full image");
subRgnArray = newArray(subRgnPref,"full image","32","64","128","256","512","1024","2048");
version = "5c";	
//----- Throw warning if active image is not 8-bit or 16-bit --------
imgTypes = newArray(".tif", ".jpg",".nd2",".stk");
swapChoices = newArray("swap", "don't swap");
doSwap = false;
 
Dialog.create("FFT Aligner v"+version+" batch converter");
Dialog.addMessage("Note: ",14,"#474646");
Dialog.setInsets(0, 30, 0);
Dialog.addMessage("1. ALL images in the folder to be analyzed will be aligned",14,"#474646");
Dialog.setInsets(0, 30, 0);
Dialog.addMessage("2. If both Slices (Z) and Frame (t) must be aligned,",14,"#474646");
Dialog.setInsets(0, 45, 0);
Dialog.addMessage( "do this with 2 sequential runs of the macro.",14,"#474646");
Dialog.setInsets(0, 30, 0);
Dialog.addMessage("3. All dimensions will be offset by the aligned dimension,",14,"#474646");
Dialog.setInsets(10, 0, 0);
Dialog.addChoice("Re-order Hypestack... swap Slices & Frames in output", swapChoices,call("ij.Prefs.get", "dialogDefaults.swapChoice",swapChoices[0]));
Dialog.setInsets(0, 40, 0);
Dialog.addMessage("If swapping Slices and Frames, align by final dimensions",12,"#b82421");
Dialog.addMessage("Align by :");
Dialog.setInsets(0, 0, 0);
Dialog.setInsets(0, 20, 10);

Dialog.addCheckboxGroup(1,3,dimsLabels, dimsDone);
//Dialog.addChoice("Slices or Frames", slicesOrFrames, "Frames");
Dialog.addNumber("[rc] set reference channel (base 1)", parseInt (call("ij.Prefs.get", "dialogDefaults.refChannel", 1)));
Dialog.addNumber("[rs] set reference slice (base 1, -1 = serial)", parseInt (call("ij.Prefs.get", "dialogDefaults.refSlice", 1)));
Dialog.addNumber("[rf] set reference frame (base 1, -1 = serial)", parseInt (call("ij.Prefs.get", "dialogDefaults.refFrame", 1)));
Dialog.addChoice("[subRgn] align by subregion (smaller = faster)", subRgnArray,call("ij.Prefs.get", "dialogDefaults.doSubRgn", subRgnArray[0]));

Dialog.addCheckbox("[place] the subregion used for alignment",  call("ij.Prefs.get", "dialogDefaults.placeBox", false));
Dialog.addNumber("[resample] image: smaller is faster, but less accurate: ", parseFloat(call("ij.Prefs.get", "dialogDefaults.dsFactor", 1.0)), 2, 6, "");
Dialog.addNumber("[ftsz] font size of offset labels", parseInt (call("ij.Prefs.get", "dialogDefaults.fontSize", 18)));
Dialog.addNumber("[mxmv] maximum translation is", parseInt (call("ij.Prefs.get", "dialogDefaults.maxTranslation", 20)),0,6,"pixels");
Dialog.addCheckbox("[save] aligned output images", call("ij.Prefs.get", "dialogDefaults.autoSave", false));
Dialog.addCheckbox("[bpfft] bandpass FFT image. Slower but more precise.", call("ij.Prefs.get", "dialogDefaults.useBP", false));
Dialog.addCheckbox("[crop] aligned image to remove blank borders", call("ij.Prefs.get", "dialogDefaults.doCrop", true));
Dialog.addChoice("File type to align", imgTypes, imgTypes[0]);
Dialog.addNumber("Rolling background subtraction before align. Radius (-1=off)", parseInt (call("ij.Prefs.get", "dialogDefaults.ballSize", 50)),0,6,"pixels");
Dialog.addNumber("Remove the first n timepoints from the stacks",parseInt (call("ij.Prefs.get", "dialogDefaults.nFramesRemoved", 0)),0,6,"");
Dialog.addCheckbox("Temporarily copy network-stored images to local hard drive for faster processing",false);
Dialog.show();
//----------------------------------------------------------------------------------------

swapChoice = Dialog.getChoice();
	call("ij.Prefs.set", "dialogDefaults.swapChoice",swapChoice);
	if (swapChoice == swapChoices[0] ) doSwap = true; 
for (i=0;i<nDims;i++) {
	dimsDone[i] = Dialog.getCheckbox();
}
refChannel = Dialog.getNumber;	
	call("ij.Prefs.set", "dialogDefaults.refChannel",refChannel);
refSlice = Dialog.getNumber;	
	call("ij.Prefs.set", "dialogDefaults.refSlice",refSlice);
refFrame = Dialog.getNumber;	
	call("ij.Prefs.set", "dialogDefaults.refFrame",refFrame);
doSubRgn = Dialog.getChoice();
	call("ij.Prefs.set", "dialogDefaults.doSubRgn", doSubRgn);
placeBox = Dialog.getCheckbox();
  	call("ij.Prefs.set", "dialogDefaults.placeBox", placeBox);
dsFactor = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.dsFactor", dsFactor);
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
doCrop = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.doCrop", doCrop);

closeAll = false;
fType = Dialog.getChoice();
ballSize = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.ballSize", ballSize);
nFramesRemoved = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.nFramesRemoved", nFramesRemoved);
copyToLocal = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.copyToLocal", copyToLocal);

//Choose directory to align
dir = getDirectory("choose folder to align");
fList = getFileList(dir);
nFiles = fList.length;
destFolder = "fftAligner"+version;
savePath = dir + destFolder;	
if (File.isDirectory(savePath)!=1) {
	File.makeDirectory(savePath); 
	print("\\Update1: created folder "+savePath);
}
//remove files from the file list in dir that are not of the image type to be aligned.
for (i=0;i<nFiles;i++) {
	if (!endsWith(toLowerCase(fList[nFiles-1-i]),fType)) fList = Array.deleteIndex(fList, nFiles-1-i);
}

setBatchMode(false);


dialogPlaceKey = "";
if (placeBox == true) dialogPlaceKey = " [place]";

dialogSaveKey = "";
if (autoSave == true) dialogSaveKey = " [save]";
imgSkippedList = newArray();

dialogCropKey = "";
if (doCrop==true) dialogCropKey = " [crop]";

t0=getTime();

nFiles = fList.length; //updated to thinned list
for (i=0;i<nFiles;i++) {
	print("\\Update0: opening image "+(i+1)+" of "+nFiles+ ": "+fList[i]);

	//run("TIFF Virtual Stack...", "open="+dir+fList[i]);
	if (copyToLocal==true){
		workingDir = getDirectory("home");
		print("\\Update1:1. moving image to local drive.");
		tm0= getTime();
		ic = File.copy(dir+fList[i], workingDir+fList[i]);
		
		print("\\Update1:1. Copy of image moved in "+ d2s( (getTime()-tm0)/1000,2)+" s");
		open(workingDir+fList[i]);
		run("Out [-]");
		run("Out [-]");
	} else {
		//opening virtual images doesn't seem to work work
		//run("TIFF Virtual Stack...", "open="+workingDir+fList[i]);
		tm0= getTime();
		open(dir+fList[i]);
		print("\\Update1:1. Opened image from source in "+ d2s( (getTime()-tm0)/1000,2)+" s");
		run("Out [-]");
		run("Out [-]");
	}
		
	img0 = getTitle();
	pctMemory = d2s(100*parseInt(IJ.currentMemory())/parseInt(IJ.maxMemory()),1);
	print("\\Update8:8. Using "+ pctMemory + "% of available "+d2s(parseInt(IJ.maxMemory())/1E9,1)+ "GB of RAM.");
	Stack.getDimensions(width, height, channels, slices, frames);
	if (nFramesRemoved>0) {
		didSwap = false;
		if ( (slices==1)&(frames>1)) {
			run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			didSwap = true;
		} 
		for (n=1;n<=nFramesRemoved;n++) {
			Stack.setSlice(1);
			run("Delete Slice", "delete=slice");
		}
		if (didSwap==true) {
			run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		} 
	}
	
	if (doSwap==true) run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	
	Stack.getDimensions(width, height, channels, slices, frames);
	print("\\Update7:7. Stack.getDimensions("+width+", "+height+", "+channels+", "+slices+", "+frames+") refFrame:"+refFrame+" refSlice:"+refSlice);
	dimensionsOK = true;
	pctMemory = d2s(100*parseInt(IJ.currentMemory())/parseInt(IJ.maxMemory()),1);
	print("\\Update8:8. Using "+ pctMemory + "% of available "+d2s(parseInt(IJ.maxMemory())/1E9,1)+ "GB of RAM.");

	rc = refChannel;

	//Check that the image opened actually meets the dimensions to be aligned
	if ( ((dimsDone[1] ==1) && (slices==1) )|| ((dimsDone[2] ==1) && (frames==1) ) ) {
		dimensionsOK == false;
		imgSkippedList = Array.concat(imgSkippedList,fList[i]);
		print("\\Update9:9. Dimensions issue for "+fList[i]);
		close("*");
	} else {
		if (refChannel>channels) rc = 1;
		if (ballSize>0) {
			print("\\Update9:9. Running background subtraction");
			run("Subtract Background...", "rolling="+ballSize+"");  
		}
		ni1 = nImages;

		if (dimsDone[1] == 1) {
			print("\\Update9:9. Running fft on slices");
			run("FFT Aligner v5c", "slices [rc]="+rc+" [rs]="+refSlice+" [rf]="+refFrame+" [subrgn]="+doSubRgn + dialogPlaceKey+" [resample]="+dsFactor+" [ftsz]="+fontSize+" [mxmv]="+maxTranslation + dialogSaveKey + dialogCropKey + " [called]");
			print("\\Update9: fft done");
		}
		if (dimsDone[2] == 1){
			print("\\Update9:9. Running fft on frames");
			run("FFT Aligner v5c", "frames [rc]="+rc+" [rs]="+refSlice+" [rf]="+refFrame+" [subrgn]="+doSubRgn + dialogPlaceKey+" [resample]="+dsFactor+" [ftsz]="+fontSize+" [mxmv]="+maxTranslation + dialogSaveKey + dialogCropKey + " [called]");
			print("\\Update9:9. fft done");
		}
		ni2 = nImages;
		if (autoSave == true){
				if (copyToLocal==true){
					print("\\Update10:10. Saving to local drive.");
					tm0= getTime();
					img1 = getTitle();
					print("\\Update10:10. Img1 is "+ img1+ " after fft. "+ni1+" images open before fft,"+ni2+" after");
					if (indexOf(img1,".tif")!=-1) {
						savePathFull =savePath+File.separator+img1;
					} else {
						savePathFull =savePath+File.separator+img1+".tif";

					}	
					saveAs("Tiff", savePathFull);
					print("\\Update10:10. Saved image in "+ d2s( (getTime()-tm0)/1000,2)+" s. Save to as "+savePathFull);
					//ic = File.copy(savePath+File.separator+img1+".tif", savePath+File.separator+img1+".tif");
				} else {
					tm0= getTime();
					img1 = getTitle();
					print("\\Update10:10. Img1 is "+ img1+ " after fft. "+ni1+" images open before fft,"+ni2+" after");
					if (indexOf(img1,".tif")!=-1) {
						savePathFull =savePath+File.separator+img1;
					} else {
						savePathFull =savePath+File.separator+img1+".tif";
					}
					saveAs("Tiff", savePathFull);
					print("\\Update10:10. Saved image in "+ d2s( (getTime()-tm0)/1000,2)+" s. Save to as "+savePathFull);

				}
		}
	}

	t1 = getTime();
	tLeft = (nFiles-1-i)*(t1-t0)/((i+1)*60000);
	print("\\Update11:11. Batch processing time left: " +d2s(tLeft, 2) + " min for "+(nFiles-1-i)+ " image stacks");
	pctMemory = d2s(100*parseInt(IJ.currentMemory())/parseInt(IJ.maxMemory()),1);
	
	print("\\Update8:8. Using "+ pctMemory + "% of available "+d2s(parseInt(IJ.maxMemory())/1E9,1)+ "GB of RAM.");
	close("*");
	if (copyToLocal==true){
		fd = File.delete(workingDir+fList[i]);
	}
}

setBatchMode("exit and display");
print("\\Update11: batch alignment complete");

/*
Created by Damon Poburko at Simon Fraser University, April 2022.

Future updates to do:
save settings used to .csv file

This macro assumes that you have installed StarDist on your Fiji/ImageJ installation
see https://stardist.net/ & https://github.com/stardist/stardist/

It is simply a batch processing wrapper/interface to peform Stardist segmentation on a folder of image stacks and save the rois metrics and ROI files.
*/

print("\\Clear");
dir = getDirectory("Choose folder with images to analyze");
print(dir);
fList = getFileList(dir);

// Need to add help button with URLs to Stardist installation instructions

outputTypes = newArray("ROI Manager","Label Image","Both");
roiPositions = newArray("Automatic","Stack","Hyperstack");
logOptions = newArray("Verbose","Show CNN Progress","Show CNN Output");
logOptionsDef = newArray(false, true,false);
Dialog.create("Stardist batch options");
Dialog.addMessage("This macro assumes that you have Stardist installed. See help", 12, "blue");
Dialog.addSlider("Channel to analyze by Stardist", 1, 5, parseInt(call("ij.Prefs.get", "dialogDefaults.channel", 1)));
Dialog.addCheckbox("Swap timepoints in Slices to Frames", call("ij.Prefs.get", "dialogDefaults.doSwap", true));
Dialog.addCheckbox("Normalize Input", call("ij.Prefs.get", "dialogDefaults.doNormalize", false));
Dialog.addNumber("percentile low",  parseFloat(call("ij.Prefs.get", "dialogDefaults.pctLow", 0.10)),2,6,"");
Dialog.addToSameRow();
Dialog.addNumber("percentile high",  parseFloat(call("ij.Prefs.get", "dialogDefaults.pctHi", 100.0)),2,6,"");
Dialog.addNumber("Prob/Score Threshold", parseFloat(call("ij.Prefs.get", "dialogDefaults.psThreshold", 0.10)),2,6,"");
Dialog.addToSameRow();
Dialog.addNumber("Overlap Threshold", parseFloat(call("ij.Prefs.get", "dialogDefaults.overlapThreshold", 0.20)),2,6,"");
Dialog.addChoice("Output type", outputTypes, outputTypes[0]);
Dialog.addNumber("Number of Tiles", parseInt(call("ij.Prefs.get", "dialogDefaults.nTiles", 1)));
Dialog.addToSameRow();
Dialog.addNumber("Boundary Exclusion", parseInt(call("ij.Prefs.get", "dialogDefaults.boundEx", 5)));
Dialog.setInsets(0, 15, 0);
Dialog.addChoice("ROI position", roiPositions, roiPositions[0]);
Dialog.setInsets(0, 15, 0);
Dialog.addCheckboxGroup(3, 1, logOptions, logOptionsDef);
Dialog.addMessage("To analyze a subset of images, provide unique strings in file names to analyze");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Leave blank for no filtering or provide a comma, space, or tab-separated list of strings");
Dialog.addString("Filter String", "", 40);
Dialog.addString("Suffix for .csv & .zip output files", "", 40);
Dialog.addCheckbox("Measure and save ROIs for current channel", true);
Dialog.addCheckbox("Re-analyze images with [imgName]_Stardist.zip ROI files & overwrite ROIs",  call("ij.Prefs.get", "dialogDefaults.reanalyze", true));
Dialog.show();

channel = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.channel", channel);
doSwap = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.doSwap", doSwap);
doNormalize = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.doNormalize",doNormalize);
	if(doNormalize) {
		normTF = "true";
	} else {
		normTF = "false";
	}
pctLow = Dialog.getNumber()*1.0;
	call("ij.Prefs.set", "dialogDefaults.pctLow",pctLow);
pctHi = Dialog.getNumber()*1.0;
	call("ij.Prefs.set", "dialogDefaults.pctHi",pctHi);
psThreshold = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.psThreshold", psThreshold);
overlapThreshold = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.overlapThreshold", overlapThreshold);
outType = Dialog.getChoice();
nTiles = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.nTiles", nTiles);
boundEx = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.boundEx", boundEx);
roiPosition = Dialog.getChoice();
doVerbose = Dialog.getCheckbox();
	if(doVerbose==true) {
		verboseTF = "true";
	} else {
		verboseTF = "false";
	}
cnnProgress = Dialog.getCheckbox();
	if(cnnProgress==true) {
		cnnProgTF = "true";
	} else {
		cnnProgTF = "false";
	}
cnnOut = Dialog.getCheckbox();
	if(cnnOut==true) {
		cnOutTF = "true";
	} else {
		cnnOutTF = "false";
	}
filterByString = Dialog.getString();
suffix = Dialog.getString();
saveROIMeasures = Dialog.getCheckbox();
reanalyze =  Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.reanalyze", reanalyze);

if (filterByString!="") {
	
	filterByString = replace(filterByString, " ", "\t");
	filterByString = replace(filterByString, ",", "\t");
	filterStrings = split(filterByString,"\t");
	print("filter " + fList.length + " files by:");
	Array.print(filterStrings);
	
	fList2 = newArray();
	
	for (i = 0; i < fList.length; i++) {
		for (j = 0; j < filterStrings.length; j++) {
			//print("fList["+i+"]:"+fList[i]+" has filter string @ char " +indexOf(fList[i],filterStrings[j]));
			if ( (fTypeCheck(fList[i])==true) && (indexOf(fList[i],filterStrings[j])!=-1 ) ) {
					fList2 = Array.concat(fList2,fList[i]);
			}
		}				
	}
	if (fList2.length>0) {
		fList=fList2;
		//Array.print(fList2);
	} else {
		exit("Did not find any images matching your filters");
	}
}

lowPercentiles = newArray(0,10,20,30,40,50,60,70,80,90);
t0 = getTime();
/*
for (i = 0; i <lowPercentiles.length; i++) {
		roiManager("reset");
		run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'forStardist-0001.tif', 'modelChoice':'Versatile (fluorescent nuclei)','normalizeInput':'true', 'percentileBottom':'"+lowPercentiles[i]+"', 'percentileTop':'100.0', 'probThresh':'0.479071', 'nmsThresh':'0.3', 'outputType':'ROI Manager', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Stack', 'verbose':'false', 'showCsbdeepProgress':'true', 'showProbAndDist':'false'], process=[false]");
		roiManager("Deselect");
		roiManager("count");
		setResult("lowPercentile", i, lowPercentiles[i]);	
		setResult("nROIs", i, roiManager("count"));	
		t1 = getTime();
		print("\\Update0: Analysis time was "+d2s((t1-t0)/1000,1)  +" s");
}
*/
framesDone = 0;
totalSDTime = 0;

//Set measurements to make sure that everything is recorded as expected
run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated display redirect=None decimal=3");


for (i = 0; i < fList.length; i++) {
	if (fTypeCheck(fList[i])==true) {
		img0 = fList[i];
		imgBase = replace(img0, substring(img0, lastIndexOf(img0, "."), lengthOf(img0) ) , "");
		pathOutZip = dir+ imgBase +"_StardistROIs-c"+channel+suffix+".zip";
		pathOutCSV = dir+ imgBase +"_StardistROIs-c"+channel+suffix+".csv";

//*** WOrk on how to best name output files with Channel used for Stardist
// try not to duplicate naming.
			
		if ( (File.exists(pathOutZip)==true) && (reanalyze==false) ) {
			print("\\Update5: "+ fList[i] + " is already analyzed." );
		} else {
		
			to0 = getTime();
			open(fList[i]);
			to1 =getTime();

			print("\\Update1:Time to open image: " +d2s((to1-to0)/60000,2)+ " min");
			img0 = getTitle();
			imgBase = replace(img0, substring(img0, lastIndexOf(img0, "."), lengthOf(img0) ) , "");
			roiManager("reset");
			
			Stack.getDimensions(width, height, channels, slices, frames);
			
			if ( (doSwap==true)|| ((slices>1)&&(frames==1)) ) run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			if (channels>1) {
				imgBase2 = imgBase+"-c"+channel;
				run("Duplicate...", "title="+imgBase2+" duplicate channels="+channel);	
				selectWindow(imgBase2);
			}
			
			str1 = "command=[de.csbdresden.stardist.StarDist2D], args=['input':'"+imgBase2+"', 'modelChoice':'Versatile (fluorescent nuclei)','normalizeInput':'"+normTF+"', 'percentileBottom':'"+pctLow+"', 'percentileTop':'"+pctHi;
			str2 = "', 'probThresh':'"+psThreshold+"', 'nmsThresh':'"+overlapThreshold+"', 'outputType':'"+outType+"', 'nTiles':'"+nTiles+"', 'excludeBoundary':'"+boundEx+"', 'roiPosition':'"+roiPosition+"', 'verbose':'"+verboseTF;
			str3 = "', 'showCsbdeepProgress':'"+cnnProgTF+"', 'showProbAndDist':'"+cnnOutTF+"'], process=[false]";
			
			sdCmd = str1+str2+str3;
			print("\\Update6: "+sdCmd);
			run("Command From Macro", sdCmd);
			
			tsd = getTime();
			print("\\Update2:Time to run Stardist: "+ d2s((tsd-to1)/60000,2)+"min, " +d2s((tsd-to1)/(1000*frames),2)+" s/frame");
			totalSDTime = totalSDTime+(tsd-to1)/60000;
			framesDone = framesDone+frames;
			roiManager("Deselect");			
			roiManager("Save", pathOutZip);
			
			if (saveROIMeasures ==true) {
				run("Clear Results");
				if (roiManager("count")>0){
					roiManager("Deselect");
					roiManager("measure");
					saveAs("Results", pathOutCSV);
				}
			}
			
			close("*");
			trs = getTime();
			print("\\Update3:Time to save ROIs: " +d2s((trs-tsd)/60000,2));
			tLeft = (fList.length-1-i)*(trs-t0)/60000;
			unitsLeft = "min";
			if (tLeft>60) {
				tLeft = tLeft / 60;
				unitsLeft = "hr";
			}
			print("\\Update4: Time left to analyze " +(fList.length-1-i) +" images estimated at ~" + d2s(tLeft,2)+" "+unitsLeft);
		}																				
	} else {
		print("print(\\Update5: ignored " + fList[i] );
	}
}

tpf = totalSDTime/framesDone;
print("\\Update4: StarDist analysis complete at ~ " +d2s(tpf,3) +" min/frame");


function fTypeCheck (file) {
	fTypeOK = false;
	fTypes = newArray(".tif",".tiff",".jpg",".png",".bmp");
	for (j=0;j<fTypes.length;j++) {
		if (endsWith(file,fTypes[j])==true) {
			fTypeOK = true;
			j=fTypes.length;
		}
	}
	return fTypeOK;
}

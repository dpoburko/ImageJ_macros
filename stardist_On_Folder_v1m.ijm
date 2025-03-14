/*
Created by Damon Poburko at Simon Fraser University, April 2022.

Future updates to do:
save settings used to .csv file

This macro assumes that you have installed StarDist on your Fiji/ImageJ installation
see https://stardist.net/ & https://github.com/stardist/stardist/

It is simply a batch processing wrapper/interface to peform Stardist segmentation on a folder of image stacks and save the rois metrics and ROI files.
Version history:
v1d - add option to perform rolling background subtraction before Stardist
v1e - add some file handling updates
v1f - added parsing and reuse of parameters from file
v1g - fixed error that prevented channels other than segmented channel from being saved to output files.    
v1h - add parsing of image ranges. e.g. A1:B3
v1i - add file picker to select a custom model for segmentation
v1j - tried saving ROIS as overlays and it got ugly
vlk - started to think that ROI saving was slow. Noted this to Wayne Rasband. He correctly identified that there most be duplicate ROI names
    - all ROIs now named as "SD"+roiManagerIndex to ensure no repeat naming 
v1m - option to log performance metrics. i.e. to compare different machines.
*/

version = "1l";

//set most analysis parameters as global to enable retreival from paramters file
var outputTypes = newArray("ROI Manager","Label Image","Both");
var roiPositions = newArray("Automatic","Stack","Hyperstack");
var logOptions = newArray("Verbose","Show CNN Progress","Show CNN Output");
var logOptionsDef = newArray(false, false,false);
var channel = 1;
var doSwap = 0;
var doNormalize = 1;
var ballSize = -1;
var pctLow =1.0;
var pctHi = 99.8;
var psThreshold = 0.5;
var overlapThreshold = 0.4;
var outType = outputTypes[0];
var nTiles = 1;
var boundEx = 1;
var roiPosition = roiPositions[0];
var doVerbose = 0;
var cnnProgress = 0;
var cnnOut = 0;
var filterByString ="";
var suffix ="";
var saveROIMeasures = 1;
var reanalyze = 0;

print("\\Clear");
var  dir="";

 dir1 = getDirectory("Choose folder with images to analyze");
 dir=dir1;
//print(dir);

var fList = getFileList(dir);

html = "<html>"
     +"<h3>For instructions on installing StarDist in Fiji go to:</h3>"
     +"<font color=blue>https://imagej.net/plugins/stardist</font>";
//     +"can have a <b>Help</b> button that displays<br>"
//     +"<font color=red>HTML</font> formatted text.<br>";

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
	    open(dir+pFile);
	    Table.rename(pFile,"Results");
		getParameters();
	}
}

// Need to add help button with URLs to Stardist installation instructions
modelChoice = call("ij.Prefs.get", "dialogDefaults.modelChoice", "Versatile (fluorescent nuclei)");
modelList = newArray("Versatile (fluorescent nuclei)","Model (.zip) from File");
SDpath = call("ij.Prefs.get", "dialogDefaults.SDpath", getDirectory("imagej"));

//check if model 

Dialog.create("Stardist batch options");
Dialog.addMessage("This macro assumes that you have Stardist installed. See help", 12, "blue");
Dialog.addSlider("Channel to analyze by Stardist", 1, 5, parseInt(call("ij.Prefs.get", "dialogDefaults.channel", channel)));
Dialog.addCheckbox("Swap timepoints in Slices to Frames", parseInt(call("ij.Prefs.get", "dialogDefaults.doSwap", doSwap)));
Dialog.addCheckbox("Normalize Input", parseInt(call("ij.Prefs.get", "dialogDefaults.doNormalize", doNormalize)));
Dialog.addNumber("Subtract background before Stardist if radius > 0", parseInt(call("ij.Prefs.get", "dialogDefaults.ballSize", ballSize)));
Dialog.addChoice("Select segmentation model",modelList, modelChoice);
Dialog.addNumber("percentile low",  parseFloat(call("ij.Prefs.get", "dialogDefaults.pctLow", pctLow)),2,6,"");
Dialog.addToSameRow();
Dialog.addNumber("percentile high",  parseFloat(call("ij.Prefs.get", "dialogDefaults.pctHi", pctHi)),2,6,"");
Dialog.addNumber("Prob/Score Threshold", parseFloat(call("ij.Prefs.get", "dialogDefaults.psThreshold", psThreshold)),2,6,"");
Dialog.addToSameRow();
Dialog.addNumber("Overlap Threshold", parseFloat(call("ij.Prefs.get", "dialogDefaults.overlapThreshold", overlapThreshold)),2,6,"");
Dialog.addChoice("Output type", outputTypes, outType);
Dialog.addNumber("Number of Tiles", parseInt(call("ij.Prefs.get", "dialogDefaults.nTiles", nTiles)));
Dialog.addToSameRow();
Dialog.addNumber("Boundary Exclusion", parseInt(call("ij.Prefs.get", "dialogDefaults.boundEx", boundEx)));
Dialog.setInsets(0, 15, 0);
Dialog.addChoice("ROI position", roiPositions, roiPosition);
Dialog.setInsets(0, 15, 0);
Dialog.addCheckboxGroup(3, 1, logOptions, logOptionsDef);
Dialog.addMessage("To analyze a subset of images, provide unique strings in file names to analyze");
Dialog.setInsets(0, 20, 0);
Dialog.addMessage("SYNTAX: (1) Blank -> no filter, (2) Lists-> comma, space, or tab-separated (Ch1_, Ch2_)");
Dialog.setInsets(0, 65, 0);
Dialog.addMessage("(3) Alphanumeric Ranges (e.g A4:C2 ) or lists of ranges (A2:B2, C3:D7) are parsed to a list.");
Dialog.addString("Filter String", call("ij.Prefs.get", "dialogDefaults.filterByString", filterByString), 40);
Dialog.addString("Suffix for .csv & .zip output files", call("ij.Prefs.get", "dialogDefaults.suffix", suffix), 40);
Dialog.addCheckbox("Measure and save ROIs for current channel", saveROIMeasures);
Dialog.addCheckbox("Re-analyze images with [imgName]_Stardist.zip ROI files & overwrite ROIs",  parseInt(call("ij.Prefs.get", "dialogDefaults.reanalyze", reanalyze)));
Dialog.addFile("Model (.Zip) from File",SDpath);
Dialog.addCheckbox("Log performance metrics",  call("ij.Prefs.get", "dialogDefaults.showMetrics", false));
Dialog.addCheckbox("Delete overlapping ROIs",  call("ij.Prefs.get", "dialogDefaults.removeOverlaps", false));

Dialog.addHelp(html);

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
ballSize = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.ballSize",ballSize);
modelChoice = Dialog.getChoice();
	call("ij.Prefs.set", "dialogDefaults.modelChoice",modelChoice);
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
	call("ij.Prefs.set", "dialogDefaults.filterByString", filterByString);
suffix = Dialog.getString();
	call("ij.Prefs.set", "dialogDefaults.suffix", suffix);
saveROIMeasures = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.saveROIMeasures", saveROIMeasures);
reanalyze =  Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.reanalyze", reanalyze);
SDpath = Dialog.getString();
	call("ij.Prefs.set", "dialogDefaults.SDpath", SDpath);
	print(SDpath);
showMetrics = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.showMetrics", showMetrics);
removeOverlaps = Dialog.getCheckbox();
	call("ij.Prefs.get", "dialogDefaults.removeOverlaps", removeOverlaps);
	
nROIs = roiManager("count");


//shorten fList to images
fList2 = newArray();
for (i = 0; i < fList.length; i++) {
	if ( fTypeCheck(fList[i])==true ) {
			fList2 = Array.concat(fList2,fList[i]);
	}			
}
fList=fList2;

minCol = 1;
maxCol = 24;
rcPad = 1;

if (filterByString!="") {
	
	filterByString = replace(filterByString, " ", "\t");
	filterByString = replace(filterByString, ",", "\t");
	filterStrings = split(filterByString,"\t");
	print("filter " + fList.length + " files by:");
	Array.print(filterStrings);

	filterStringsTemp = newArray();

	for(i=0;i<filterStrings.length;i++) {
		if (indexOf(filterStrings[i],":")>-1) {
			//parse for range
			rangeParts = split(filterStrings[i],":");
			rc1Letter = substring(rangeParts[0],0,1);
			rc1LetIndex = alphaNumber(rc1Letter);
			rc1Number = parseInt(substring(rangeParts[0],1));
			rc2Letter = substring(rangeParts[1],0,1);
			rc2LetIndex = alphaNumber(rc2Letter);
			rc2Number = parseInt(substring(rangeParts[1],1));
			
			//check if range is meant to have padded numbers
			//e.g. if range parts equals "A03", test for "0"
			rp1Zeros = lengthOf(replace(rangeParts[0],"\[^0\]" ,""));
			rp2Zeroes = lengthOf(replace(rangeParts[1],"\[^0\]" ,""));
			if (( rp1Zeros > 0) | (rp2Zeroes > 0) ) {
				//one of the range parts had some zeroes, the number of which will indicate the padding
				rcPad = maxOf(rp1Zeros,rp2Zeroes)+1;
			} else {
				//if either numeric portion is <10, and has no zeroes, we can assume no padding. 
				//Otherwise, we have double digit numbers and need to ask for user input on padding
				if (minOf(rc1Number,rc2Number)>9) {
					Dialog.create("Are range column numbers padded?");
					Dialog.addMessage("How many leading zeroes are used in the columnn numbers of ranges");
					Dialog.addNumber("e.g. A3:C11 has 0 leading zeros. A03:C11 has 1.", 0);
					Dialog.show();
					rcPad = Dialog.getNumber()+1;
					
				}
			}
			
			for (j=rc1LetIndex;j<=rc2LetIndex;j++) {
				
				if (j==rc1LetIndex) {
					firstK = rc1Number;
				}else {
					firstK = minCol;
				}
				if (j==rc2LetIndex) {
					lastK = rc2Number;
				} else {
					lastK = maxCol;
				}
				
				for (k=firstK;k<=lastK;k++) {
					currLetter = alphaNumber(j-1);//get current letter from number of alphabet
					filterStringsTemp = Array.concat(filterStringsTemp,currLetter+IJ.pad(k,rcPad));
				}
			}
		}
	}
	
	
	filterStrings = Array.concat(filterStrings,filterStringsTemp);
	fList2 = newArray();

	for (i = 0; i < fList.length; i++) {
		for (j = 0; j < filterStrings.length; j++) {
			//now filter by file name
			if  (indexOf(fList[i],filterStrings[j])!=-1  ) {
					fList2 = Array.concat(fList2,fList[i]);
			}
		}				
	}
	if (fList2.length>0) {
		fList=fList2;
		fList2 = Array.sort(fList2);
	} else {
		exit("Did not find any images matching your filters");
	}
}


t0 = getTime();

framesDone = 0;
totalSDTime = 0;

//Set measurements to make sure that everything is recorded as expected
run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated display redirect=None decimal=3");

//Save settings to a .csv file
run("Clear Results");
setResult("Parameter", 0, "channel");
setResult("Value", 0, channel);
setResult("Parameter", nResults, "doSwap");
setResult("Value", nResults-1, doSwap);
setResult("Parameter", nResults, "doNormalize");
setResult("Value", nResults-1, doNormalize);
setResult("Parameter", nResults, "ballSize");
setResult("Value", nResults-1, ballSize);
setResult("Parameter", nResults, "pctLow");
setResult("Value", nResults-1, pctLow);
setResult("Parameter", nResults, "pctHi");
setResult("Value", nResults-1, pctHi);
setResult("Parameter", nResults, "psThreshold");
setResult("Value", nResults-1, psThreshold);
setResult("Parameter", nResults, "overlapThreshold");
setResult("Value", nResults-1, overlapThreshold);
setResult("Parameter", nResults, "outType");
setResult("Value", nResults-1, outType);
setResult("Parameter", nResults, "nTiles");
setResult("Value", nResults-1, nTiles);
setResult("Parameter", nResults, "boundEx");
setResult("Value", nResults-1, boundEx);
setResult("Parameter", nResults, "roiPosition");
setResult("Value", nResults-1, roiPosition);
setResult("Parameter", nResults, "doVerbose");
setResult("Value", nResults-1, doVerbose);
setResult("Parameter", nResults, "cnnProgress");
setResult("Value", nResults-1, cnnProgress);
setResult("Parameter", nResults, "cnnOut");
setResult("Value", nResults-1, cnnOut);
setResult("Parameter", nResults, "filterByString");
setResult("Value", nResults-1, filterByString);
setResult("Parameter", nResults, "suffix");
setResult("Value", nResults-1, suffix);
setResult("Parameter", nResults, "saveROIMeasures");
setResult("Value", nResults-1, saveROIMeasures);
setResult("Parameter", nResults, "reanalyze");
setResult("Value", nResults-1, reanalyze);

startTime = timeStamp();
saveAs("Results", dir  + "0-analysisParameters_starDistOnFolder_v" + version + "_" + startTime + ".csv");//save to folder with timestamp
run("Clear Results");

//Process the list of files to be analyzed

for (i = 0; i < fList.length; i++) {
	
	if (fTypeCheck(fList[i])==true) {
		img0 = fList[i];
		imgBase = replace(img0, substring(img0, lastIndexOf(img0, "."), lengthOf(img0) ) , "");
		pathOutZip = dir+ imgBase +"_StardistROIs-c"+channel+suffix+".zip";
		pathOutCSV = dir+ imgBase +"_StardistROIs-c"+channel+suffix+".csv";

		if ( (File.exists(pathOutZip)==true) && (reanalyze==false) ) {

			print("\\Update5: "+ fList[i] + " is already analyzed." );
			
		} else {
		
			to0 = getTime();
			open(dir+fList[i]);
			to1 =getTime();

			if(ballSize>0){
				ticRbs = getTime();
				run("Subtract Background...", "rolling="+ballSize+" stack");
				tocRbs = getTime();
			}

			print("\\Update1:Time to open image: " +d2s((to1-to0)/60000,2)+ " min");
			img0 = getTitle();
			imgBase = replace(img0, substring(img0, lastIndexOf(img0, "."), lengthOf(img0) ) , "");
			roiManager("reset");
			
			Stack.getDimensions(width, height, channels, slices, frames);
			areaMP = (width*height/1E6); 
			print("\\Update6: The current image has " + channels + " channels");
			 
			
			if ( (doSwap==true)|| ((slices>1)&&(frames==1)) ) run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			if (channels>1) {
				imgBase2 = imgBase+"-c"+channel;
				run("Select None");
				if (frames>1) run("Duplicate...", "title="+imgBase2+" duplicate channels="+channel);	
				if (frames==1) {
					Stack.setChannel(channel);
					run("Duplicate...", "title="+imgBase2);	
				}
				if (getTitle()!=imgBase2) rename(imgBase2);
				selectWindow(imgBase2);
			}else{
				selectWindow(img0);
				rename(imgBase);
				imgBase2 = imgBase;
			}
			
			if (modelChoice == modelList[1]) {
				mFileString =  ", 'modelFile':'" + SDpath+"'";
				mFileString = replace(mFileString,File.separator,"/");
			} else {
				mFileString ="";
			}
			
			str1 = "command=[de.csbdresden.stardist.StarDist2D], args=['input':'"+imgBase2+"', 'modelChoice':'" + modelChoice + "', 'normalizeInput':'"+normTF+"', 'percentileBottom':'"+pctLow+"', 'percentileTop':'"+pctHi;
			str2 = "', 'probThresh':'"+psThreshold+"', 'nmsThresh':'"+overlapThreshold+"', 'outputType':'"+outType +"'" + mFileString +", 'nTiles':'"+ nTiles + "', 'excludeBoundary':'"+boundEx+"', 'roiPosition':'"+roiPosition+"', 'verbose':'"+verboseTF;
			str3 = "', 'showCsbdeepProgress':'"+cnnProgTF+"', 'showProbAndDist':'"+cnnOutTF+"'], process=[false]";
			
			sdCmd = str1+str2+str3;
			print("\\Update6: "+sdCmd);
			
			ticSD = getTime();
			run("Command From Macro", sdCmd);
			
			tsd = getTime();
			print("\\Update2:Time to run Stardist: "+ d2s((tsd-ticSD)/60000,2)+"min, " +d2s((tsd-ticSD)/(1000*frames),2)+" s/frame");
			totalSDTime = totalSDTime+(tsd-ticSD)/60000;
			sdSeconds = (tsd-ticSD)/1000;
			sPerFrame = (tsd-ticSD)/(frames*1000);
			sPerMP = sPerFrame/areaMP;
			framesDone = framesDone+frames;
			
			
			nROIs = roiManager("count");
			print("\\Update5: saving "+ nROIs +" ROIs");
			//nROIs =roiManager("count");
			
			if (nROIs>0){
				print("\\Update5: renaming ROIs to avoid same name performance loss");
				for (r = 0; r <nROIs;r++)  { 
				  	roiManager("Select",r);
					roiManager("Rename","SD"+IJ.pad(r,5));
				}
				roiManager("deselect");
				
				ticROIsave = getTime();
				roiManager("Save", pathOutZip);
				
				tsd1 = getTime();
				sToSaveROIs = (tsd1-ticROIsave)/1000;
				print("\\Update5: Saved "+nROIs+" ROIs in "+d2s(sToSaveROIs,3)+" s");
				chMeasured = "";
				
				if (removeOverlaps){

					img1 = replace(img0+"_copy";
					getDimensions(width, height, channels, slices, frames);
					newImage(img1, "16-bit black", width, height, 1);
					nROIs = roiManager("count");
					for (i = 1; i <= nROIs; i++) {
					    roiManager("select", nROIs-i);
						getStatistics(area, mean, min, max);
						if (max>0) {
							roiManager("delete");
						} else {
							run("Add...", "value=1");    	
						}
						showProgress(i, nROIs);
					}
					nROIs = roiManager("count");
				}
				
				
				
				if (saveROIMeasures ==true) {
					run("Clear Results");
					if (nROIs>0){
						chMeasured = channel;
						print("\\Update5: measuring ROIs on channel "+channel);
						roiManager("Deselect");
						roiManager("measure");
									// Measure other channels (mean & StdDev for now) using ROIs and add to new columns in data table. 
						if (channels>1) {
							selectWindow(img0);
							rTable = "Results";
							rTableTemp = "Temp"; //move current results table to a temporary name
							
							for (n=1;n<=channels;n++) {
								
								if (n!=channel) {    //skip the stardist channel
									Table.rename(rTable, rTableTemp);
									Stack.setChannel(n);
									run("Clear Results");
									chMeasured = chMeasured + ", " + n;
									print("\\Update5: measuring ROIs on channel "+n);
									roiManager("measure");
									//collect measured values from table in arrays
									means = Table.getColumn("Mean");
									SDs = Table.getColumn("StdDev");
									close("Results");
									//restore the main results table and add new columns
									Table.rename(rTableTemp, rTable);
									Table.setColumn("Mean_"+n, means);
									Table.setColumn("StdDev_"+n, SDs);
									
								}
							}
							
						}
						saveAs("Results", pathOutCSV);
					} else {
						sToSaveROIs = 0;
					}
				}
			}

			close("*");	//close all open images
			run("Collect Garbage");
			trs = getTime();
			line3 = "Time to save "+ nROIs + " ROIs: ";
			if (saveROIMeasures ==true) line3 = "Time to save ROIs & measurements: ";
			print("\\Update3:"+line3 + d2s((trs-tsd)/60000,2) + " min");
			tLeft = (fList.length-1-i)*(trs-t0)/(60000*(i+1));
			unitsLeft = "min";
			if (tLeft>60) {
				tLeft = tLeft / 60;
				unitsLeft = "hr";
			}
			print("\\Update4:Time left to analyze " +(fList.length-1-i) +" images is ~" + d2s(tLeft,2)+" "+unitsLeft);
			if (showMetrics) {
				if (i==0) {
					print("\\Update7:");
					print("\\Update8:");
					print("StarDist 2D Performance metrics:");
					print("Image:\t# Frames:\trun time(s):\ts/frame:\ts/MP\timage size(MP):\t#ROIs:\tROI save time(s):\ts/ROI");
				}
				//print(img0+"\t"+frames+"\t"+d2s(sdSeconds,2)+"\t"+d2s(sPerFrame,2)+"\t"+d2s(sPerMP,2)+"\t"+d2s(areaMP,2)+"\t"+nROIs+"\t"+d2s((tsd1-ticROIsave)/1000,3));
				print(img0+"\t "+frames+"\t "+d2s(sdSeconds,2)+"\t "+d2s(sPerFrame,2)+"\t "+d2s(sPerMP,2)+"\t "+d2s(areaMP,2)+"\t "+nROIs+"\t "+sToSaveROIs+"\t "+d2s(sdSeconds/nROIs,3));
				
				
				
				
			}			


		}																				
	} else {
		print("\\Update5: ignored " + fList[i] );
	}

}

tpf = totalSDTime/framesDone;
print("\\Update6: StarDist analysis complete at ~ " +d2s(tpf,3) +" min/frame");


function fTypeCheck (file) {
	fTypeOK = false;
	fTypes = newArray(".tif",".tiff",".jpg",".png",".bmp",".nd2");
	for (j=0;j<fTypes.length;j++) {
		if (endsWith(file,fTypes[j])==true) {
			fTypeOK = true;
			j=fTypes.length;
		}
	}
	return fTypeOK;
}


function timeStamp () {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	stamp = ""+ year +""+IJ.pad(month+1,2)+""+ IJ.pad(dayOfMonth,2)+"-"+IJ.pad(hour,2)+""+IJ.pad(minute,2)+"."+IJ.pad(second,2) ;
	return stamp;
}

function getParameterFiles() {

	//Find newest file.
	nParamFiles = 0;
	//fList = getFileList(dir); - now using global variable from first creation of fList
	pList = newArray(fList.length);
	pLastMod = newArray(fList.length);
	pLastMod[0] = "";
	pList[0] = "";
	for (g=0;g<fList.length;g++) {

		if (indexOf(fList[g],"0-analysisParameters")!=-1) {
			pList[nParamFiles] = fList[g];
			pLastMod[nParamFiles] = File.lastModified(dir+ File.separator+fList[g]);
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

	for(i=0;i<nResults;i++) {
		parameter = getResultString("Parameter",i);
		value =  getResultString("Value",i);
		//print("parameter: " +parameter+ " Value: "+value);
		if (parameter == "channel") 		channel = value; 
		if (parameter == "doSwap") 			doSwap = value; 
		if (parameter == "doNormalize") 	doNormalize = value; 
		if (parameter == "ballSize")		ballSize = value; 
		if (parameter == "pctLow") 			pctLow = value; 
		if (parameter == "pctHi")			pctHi = value; 
		if (parameter == "psThreshold")		psThreshold = value; 
		if (parameter == "overlapThreshold") 	overlapThreshold = value; 
		if (parameter == "outType") 		outType = value; 
		if (parameter == "nTiles") 			nTiles = value; 
		if (parameter == "boundEx") 		boundEx = value; 
		if (parameter == "roiPosition") 	roiPosition = value; 
		if (parameter == "doVerbose")		 doVerbose = value; 
		if (parameter == "cnnProgress") cnnProgress = value; 
		if (parameter == "cnnOut") cnnOut = value; 
		if (parameter == "filterByString") {
			if (value==NaN) {
				filterByString = ""; 
			}else {
				filterByString = value;
			}
		}
			//print("\\Update9: if (parameter == 'filterByString') filterByString = "+value+"; ");
		if (parameter == "suffix") {
			if (value ==NaN) {
				suffix = "";
			} else {
				suffix = value;	
			}		 
		}
		if (parameter == "saveROIMeasures") saveROIMeasures = value; 
		if (parameter == "reanalyze") reanalyze = value; 
	}
	
 	call("ij.Prefs.set", "dialogDefaults.channel",channel);
 	call("ij.Prefs.set", "dialogDefaults.doSwap",doSwap);
 	call("ij.Prefs.set", "dialogDefaults.doNormalize",doNormalize);
 	call("ij.Prefs.set", "dialogDefaults.ballSize",ballSize);
 	call("ij.Prefs.set", "dialogDefaults.pctLow",pctLow);
 	call("ij.Prefs.set", "dialogDefaults.pctHi",pctHi);
 	call("ij.Prefs.set", "dialogDefaults.psThreshold",psThreshold);
 	call("ij.Prefs.set", "dialogDefaults.overlapThreshold",overlapThreshold);
 	call("ij.Prefs.set", "dialogDefaults.outType",outType);
 	call("ij.Prefs.set", "dialogDefaults.nTiles",nTiles);
 	call("ij.Prefs.set", "dialogDefaults.boundEx",boundEx);
 	call("ij.Prefs.set", "dialogDefaults.roiPosition",roiPosition);
 	call("ij.Prefs.set", "dialogDefaults.doVerbose",doVerbose);
 	call("ij.Prefs.set", "dialogDefaults.cnnProgress",cnnProgress);
 	call("ij.Prefs.set", "dialogDefaults.cnnOut",cnnOut);
 	call("ij.Prefs.set", "dialogDefaults.filterByString",filterByString);
 	call("ij.Prefs.set", "dialogDefaults.suffix",suffix);
 	call("ij.Prefs.set", "dialogDefaults.saveROIMeasures",saveROIMeasures);
 	call("ij.Prefs.set", "dialogDefaults.reanalyze",reanalyze);

}
function alphaNumber(x) {
	alphabet = newArray("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z");
	aLetter = replace(x,"\[0-9\]" ,"");
	aNumber = replace(x,"\[A-Z\]" ,"");
	//if x is a letter, return number place in alphabet, where A=1
	if ( lengthOf(aLetter) > 0) {
		alphaIndex =0;	
		for (a=0;a<26;a++) {
			if (x==alphabet[a]){
				alphaIndex = a+1;
			}
		}
		return alphaIndex;
	}
	//if x is a number from 1-26, return number place in alphabet, where A=1
	if ( lengthOf(aNumber)>0) {
		x = parseInt(x); 	
		if ((x>=0)&&(x<27)){
			return alphabet[x];	
		} else {
			return ".";
		}
	}
}

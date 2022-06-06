
	var gVersion = "2.3";
	var gRefChannel = 1;
	var gMeasChannel = 1;
	var gNuclearMinArea = 300;
	var gmeasChannelGauss = 2;
	var gROIFileNamePattern = "";
	//var	gDoProjection = "";
	var gBatchResultFileName = "ROI_Metrics.xls";
	var gImgNamePattern;
	skipRoiString = "dummy";

	channelLabels = newArray("C1","C2","C3","C4","C5","C6");
	channelsToDo = newArray(call("ij.Prefs.get", "dialogDefaults.doC0", true),call("ij.Prefs.get", "dialogDefaults.doC1", false),call("ij.Prefs.get", "dialogDefaults.doC2", false),call("ij.Prefs.get", "dialogDefaults.doC3", false),call("ij.Prefs.get", "dialogDefaults.doC4", false),call("ij.Prefs.get", "dialogDefaults.doC5", false));
	roiLabel = call("ij.Prefs.get", "dialogDefaults.roiLabel", "cell");
	namePattern = call("ij.Prefs.get", "dialogDefaults.gImgNamePattern", "yymmdd_DPCxx_Tx_100x_HOE_DNA_MTO_Ki67_EDF_C2_");
	zStackOptions = newArray("best focus","maximal intensity projection [not ready]");
	patternLength = maxOf(lengthOf(namePattern),40);
	//ballSize = parseInt(call("ij.Prefs.get", "dialogDefaults.ballSize", "-1"));

	Dialog.create("Measure all channels by ROIs " + gVersion);
    Dialog.addMessage("For each file in the selected folder, matching ROIs \n sets will be opened, and specified channels will be measured");
   Dialog.addMessage("Channels to analyze");
   	Dialog.setInsets(5, 25, 0) ;
    Dialog.addCheckboxGroup(1, 6, channelLabels, channelsToDo);
    Dialog.addChoice("Z-stacks will be measured using", zStackOptions, zStackOptions[0]);
    Dialog.addSlider("If using best focus, use channel", 1, 6, parseInt(call("ij.Prefs.get", "dialogDefaults.focusOnChannel", "1")));
 Dialog.addMessage("ROI naming");
    Dialog.setInsets(15, 0, 0) ;

    Dialog.addString("Unique part of ROI file names",call("ij.Prefs.get", "dialogDefaults.gROIFileNamePattern", gROIFileNamePattern),30);
    Dialog.addString("label for ROIs in output file",call("ij.Prefs.get", "dialogDefaults.roiLabel", "cell"),30);
   	
    Dialog.addString("Label for output file (.xls)",call("ij.Prefs.get", "dialogDefaults.outPutLabel", ""),40);
    Dialog.addNumber("Ignore ROIs smaller than: ",parseInt(call("ij.Prefs.get", "dialogDefaults.minROIsize", "200000")),0,8,"px^2");
    Dialog.addString("Skip ROIs containing this text", call("ij.Prefs.get", "dialogDefaults.skipRoiString", skipRoiString));
    Dialog.addNumber("Run rolling ball subtraction on all slices (-1 = off)",parseInt(call("ij.Prefs.get", "dialogDefaults.ballSize", "-1")));
    Dialog.addCheckbox("Run in Batch Mode.",call("ij.Prefs.get", "dialogDefaults.doBatch", false));
    Dialog.addToSameRow();
    Dialog.addCheckbox("Confirm set measurements.",call("ij.Prefs.get", "dialogDefaults.checkMsts", false));
    Dialog.addCheckbox("Use advanced pattern matching.",call("ij.Prefs.get", "dialogDefaults.doAdvanced", false));
    Dialog.show();

	channelsToDo[0] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC0", channelsToDo[0]); 
	channelsToDo[1] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC1", channelsToDo[1]); 
	channelsToDo[2] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC2", channelsToDo[2]); 
	channelsToDo[3] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC3", channelsToDo[3]); 
	channelsToDo[4] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC4", channelsToDo[4]); 
	channelsToDo[5] = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doC5", channelsToDo[5]); 

	zStkChoice = Dialog.getChoice();

    focusOnChannel = Dialog.getNumber();	    	call("ij.Prefs.set", "dialogDefaults.focusOnChannel", focusOnChannel); 
 gROIFileNamePattern = Dialog.getString();	    	call("ij.Prefs.set", "dialogDefaults.gROIFileNamePattern", gROIFileNamePattern); 
	roiLabel = Dialog.getString();						call("ij.Prefs.set", "dialogDefaults.roiLabel", roiLabel); 
	outPutLabel = Dialog.getString();					call("ij.Prefs.set", "dialogDefaults.outPutLabel", outPutLabel); 
	minROIsize = Dialog.getNumber();					call("ij.Prefs.set", "dialogDefaults.minROIsize", minROIsize); 
	skipRoiString = Dialog.getString();					call("ij.Prefs.set", "dialogDefaults.skipRoiString", skipRoiString); 
	ballSize = Dialog.getNumber();					    call("ij.Prefs.set", "dialogDefaults.ballSize", ballSize); 
	doBatch = Dialog.getCheckbox();						call("ij.Prefs.set", "dialogDefaults.doBatch", doBatch); 
	checkMsts = Dialog.getCheckbox();					call("ij.Prefs.set", "dialogDefaults.checkMsts", checkMsts); 
	doAdvanced = Dialog.getCheckbox();					call("ij.Prefs.set", "dialogDefaults.doAdvanced", doAdvanced); 
	
		
	if (checkMsts== true) {
		waitForUser("Click Analyze>Set Measurments and confirm \n the measurements you want to be analyzed");
	}

	if (doAdvanced == true) {
		Dialog.create("Measure all channels by ROIs " + gVersion);
	    Dialog.addString("Image name template: ",call("ij.Prefs.get", "dialogDefaults.gImgNamePattern", gImgNamePattern),patternLength);
	    Dialog.setInsets(0, 15, 0) ;
	    Dialog.addMessage("Use * as wilcard for parts of image name that vary but must match \n e.g. 141021_DPC21_100x_*_HOE_DNA_MTO_Ki67_*_C3_EDF \n where *1 = treatmentA, treatmentB, *2 = S001,S002");
	    Dialog.show();
		gImgNamePattern = Dialog.getString();	        	call("ij.Prefs.set", "dialogDefaults.gImgNamePattern", gImgNamePattern); 
	}

		
	print("\\Clear");
	run("Clear Results");
	dir = getDirectory("Choose a Directory ");
	mainList = getFileList(dir);
	Array.sort(mainList);
	imgList = newArray(mainList.length);
	roiSetList = newArray(mainList.length);
	nImgs = 0;
	nRoisSets = 0;
	fTypesAllowed = newArray(".tif",".TIF",".tiff",".TIFF",".lsm",".nd2");
	
	//parse mainlist of files to create sets of images and ROI files
	//create list of images of specified type that match template
	imgList = newArray();
	for (i=0; i<mainList.length; i++) {
		if ( (endsWith(mainList[i], "/")==false) && (endsWith(mainList[i], File.separator() )==false ) ) { 
			fType = substring(mainList[i], lastIndexOf(mainList[i], "."), lengthOf(mainList[i]));
			fTypeOK = false;
			for (k = 0; k<fTypesAllowed.length; k++) {
				if (fType ==  fTypesAllowed[k]) 	fTypeOK = true;
			}
			if (fTypeOK == true) {
				imgList = Array.concat(imgList, mainList[i]);
				nImgs++;
			}
		}
    }
    Array.show("imgList0",imgList);
    //check that images in main list and of correct image type also match the specific file name patter
	//imgList = Array.trim(imgList,nImgs);  

	// generate sublist from imgList of files that mmatch the specified pattern from the dialog	
	if (doAdvanced == true) {
		imgListUniquePatterns = uniqueStringMatchingTemplate(gImgNamePattern,imgList);
	} else {
		imgListUniquePatterns = Array.copy(imgList);
		for (i=0; i< imgListUniquePatterns.length;i++) {
			imgListUniquePatterns[i] = substring(imgListUniquePatterns[i],0, lastIndexOf(imgListUniquePatterns[i],"."));
		}
	}
		
	Array.show("unique patterns",imgListUniquePatterns);
	

	//print("# of images to check: " + imgList.length);
	//print("# of unique name patterns: " + imgListUniquePatterns.length);
	
	
	imgListOK = newArray();
	nImgsOK = 0;
	//print("Images to analyze");

	// DP 190917 - it isn't clear anymore to me why this step is needed
	for (i=0; i<imgList.length; i++) { 		
		//print(imgList[i]);
		for (j=0; j<imgListUniquePatterns.length; j++) { 		
			if (indexOf(imgList[i],	imgListUniquePatterns[j]) != -1) {
				imgListOK = Array.concat(imgListOK,imgList[i]);
				nImgsOK++;
				j = imgListUniquePatterns.length;
			}
		}
	}
	Array.show("imgListOK",imgListOK);
	Array.show("imgList1",imgList);
	waitForUser;
	// *************************************************************************************************
	// *** Images that will be opened for analysis. There should only be one image per unqiue template
	// *************************************************************************************************
	//Array.show("OKed images",imgListOK);	

	//scan files for ROI sets that match on of the unique filename patterns contained in imgListUniquePatterns
	nROIsets = 0;
	roiSetList = newArray();
	matchImgList = newArray();

	//DP 190917 - rebuilt to allow multiple ROI sets per image. 
	for ( i =0; i< mainList.length; i++) {
		if ( endsWith(mainList[i], ".zip") == true)  {
			for (j=0;j<imgListOK.length; j++) {
				imgOKLessType = substring(imgListOK[j],0,lastIndexOf(imgListOK[j],"."));
				if (indexOf(mainList[i], imgOKLessType )!= -1) {
					roiSetList = Array.concat(roiSetList,mainList[i]);
					//matchImgList = Array.concat(matchImgList,imgListOK[j]);
					nROIsets++;
				}
			}
		} 
	}
	roiSetList = Array.trim(roiSetList,nROIsets);
	roiSetListOK = newArray(roiSetList.length);
	//Array.show("roiSetList",roiSetList);
	//Array.show("matchImgList",matchImgList);
	
	nROIsetsOK = 0;
	//print("OKd ROI sets: " );
	for ( i =0; i< roiSetList.length; i++) { 		
		//print(roiSetList[i]);
		for ( j =0; j< imgListUniquePatterns.length; j++) { 		
			//print(imgListUniquePatterns[j]);
			if (indexOf(roiSetList[i],	imgListUniquePatterns[j]) != -1) {
				roiSetListOK[nROIsetsOK] = roiSetList[i];
				//print(roiSetListOK[nROIsetsOK]);
				nROIsetsOK++;
				j = imgListUniquePatterns.length;
			}
		}
	}	


	// *************************************************************************************************
	// Final set of ROIs that will be used
	// *************************************************************************************************
	// v2.1 roiSetListOK = Array.trim(roiSetListOK,nROIsetsOK);

	//print(imgListOK.length + " files to be analyzed:");
	nEmptyRoiSets = 0;
	emptyRoiHolder = newArray();

    roiManager("reset");
    IJ.deleteRows(0, nResults);
	run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated display redirect=None decimal=3");
	firstResult = 0;
	lastResult =0;

	loopTime = 0;

if (doBatch==true) setBatchMode(true);
		tStart = getTime();
   for (imgIndex=0; imgIndex<imgListOK.length; imgIndex++) {
		firstResult = nResults;
		t0 = getTime();


			roiSetsForThisImage = newArray();
			//print("ROIs that image " + imgListOK[imgIndex] + " and ");
			//print("unique pattern " + imgListUniquePatterns[imgIndex] + " =");
			nRoiSetsForThisImage = 0;
			for(j=0;j<roiSetListOK.length;j++) {
				if (indexOf(roiSetListOK[j], imgListUniquePatterns[imgIndex])!= -1 ) {
					roiSetsForThisImage = Array.concat(roiSetsForThisImage,roiSetListOK[j]);
					nRoiSetsForThisImage++;
				}
			}
			//print(nRoiSetsForThisImage);

			if (roiSetsForThisImage.length>0) {

				resultsFirst = 0;
				resultsLast = 0;
	
				if (imgIndex==0) print("\\Update1:Working on image 1");	
				if (imgIndex>0) print("\\Update1:Working on image " + (imgIndex+1) + " of " +imgListOK.length+ " " +loopTime*(imgListOK.length-imgIndex+1)/60 + " min remaining");	
				
				open(dir + imgListOK[imgIndex]);
				run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
				if (ballSize>-1) run("Subtract Background...", "rolling="+ballSize+" stack");
				
				img0 = getTitle();
				img0 = substring(img0, 0, lastIndexOf(img0, "."));
				rename(img0);
				Stack.getDimensions(width, height, channels, slices, frames) ;
				Stack.getPosition(channel, slice, frame);
				//print("Dimensions:" + width +" "+ height+" "+ channels+" "+ slices+" "+ frames);
				
				//v2.4 copy image to MIP or best focus
				if (slices>1) {
					currSlice = slice;
					if (zStkChoice == zStackOptions[0]) {
						maxSD = -9999999999;
						bestSlice = 1;
						
						//print(width, height, channels, slices, frames);
						for (i = 0; i<slices; i++) {
							Stack.setSlice(i+1);
							getRawStatistics(nPixels, mean, min, max, std, histogram);
							SD = std/mean;
							//print(SD);
							if (SD > maxSD) {
								maxSD = SD;
								bestSlice = i+1;
							}
							Stack.getPosition(channel, slice, frame);
						}
						print("bestSlice = "+bestSlice);
						Stack.setPosition(channel,bestSlice, frame) ;
					}
					if (zStkChoice == zStackOptions[1]) {
						run("Z Project...", "projection=[Max Intensity]");
//!!!!!!!!!! Still need to do! !!!!!!!!!!!!!!!!!!!!!!!!!!!!

						
					}
				}



				
				//build loop for list of ROIs that contain patterns
				for (j=0; j<roiSetsForThisImage.length; j++) {
	
						resultsFirst = nResults;	
				
						if (roiManager ("count") > 0)  roiManager ("reset");
						print("\\Update2: ROIs opened: " + roiSetsForThisImage[j]);
						roiManager("Open", dir + roiSetsForThisImage[j]);
						Stack.setPosition(1, slice, frame);
						nROIs = roiManager("count");
						
						if (nROIs == 0) {
							emptyRoiHolder = Array.concat(emptyRoiHolder,roiSetsForThisImage[j]);
							nEmptyRoiSets++;
							newROIname = replace(roiSetsForThisImage[j]),".zip","_noROIs.roi");
							File.rename(dir + roiSetsForThisImage[j], dir + newROIname);
							
						} else {
							
						}
						
						print("\\Update3: nROIs " + nROIs);
	
						// DP - 190917 - There must be a faster / easier way to do this and getting all channels onto same line. 
						// ==== Assess and handle different pixel sizes
					    selectWindow(img0);
						roiManager("remove slice info");
					    roiManager("measure");
					    resultsLast = nResults;		
	
						okROIs = newArray();
						
						for (m = resultsFirst; m < resultsLast; m++ ) {
							mArea = getResult("Area",m);
							if (mArea >=minROIsize) {
								okROIs = Array.concat(okROIs,m-resultsFirst);
							}
						}
						IJ.deleteRows(resultsFirst, resultsLast); // clear intermediate measure results

					    Stack.setPosition(1, slice, frame);
					    //Array.show("okROIs",okROIs);
						roiManager("select",okROIs); // select ROIs with area > minROIsize

						channelsMeasured = 0;
												
						for (c=1; c<=channels; c++) { //loop through channels to be imaged and store results in one table
							//print("passed c="+c);
							if (channelsToDo[c-1]==true) {
								//print("passed channelsToDo");
								channelsMeasured++;
								Stack.setPosition(c, slice, frame);
								resultsFirst = nResults;
								roiManager("Measure");
								resultsLast = nResults;
								// add column to results for name of ROI file(s) analyzed
								if (channelsMeasured==1) {
									for (m = resultsFirst; m < resultsLast; m++ ) {
										setResult("ROIfile",m, roiSetsForThisImage[j]);
										roiManager("select",m-resultsFirst);
										
										setResult("ROIname",m, Roi.getName);
									}
								}
								
								if (channelsMeasured>1) {
									//print("passed channelsMeasured>1");
									for (m = resultsFirst; m < resultsLast; m++ ) {
										mArea = getResult("Area",m);
										// shuttle values to new columns
										if (mArea >=minROIsize) {
											//print("m="+m+" resultsFirst="+resultsFirst+" resultsLast="+resultsLast);
											toRow = m-okROIs.length;
											setResult("Mean_C"+c,toRow, getResult("Mean",m));
											setResult("StdDev_C"+c,toRow, getResult("StdDev",m));
											setResult("IntDen_C"+c,toRow, getResult("IntDen",m));
										}
									}
									IJ.deleteRows(resultsFirst, resultsLast);
								}
							}
							
						}
							
				}		// close j loop

				selectWindow(img0);
				close();
				lastResult = nResults;
				    
			} //close if image has ROIs

		loopTime = (getTime() - t0)/1000;
   }  // close for (imgIndex=0.... loop
	
	chnlsString = "";
	for (c=1; c<=channelsToDo.length; c++) {
		if (channelsToDo[c-1]==true) chnlsString = chnlsString + "_C"+c;			
	}
	gBatchResultFileName = outPutLabel + chnlsString + "_" + roiLabel + "_ROI_Metrics"+".xls";
   
    print("Savings as: " + dir + gBatchResultFileName);
    saveAs("Results", dir + gBatchResultFileName);
    print("Time to completion: " + ((getTime() - tStart)/60000) + " min" );
	print("Analysis Complete");
	Array.trim(emptyRoiHolder,nEmptyRoiSets);
	for (i=0;i<nEmptyRoiSets;i++) {
		print(emptyRoiHolder[i]);
	}
	if (doBatch==true) setBatchMode("exit and display");

function uniqueStringMatchingTemplate(template,list) {
	
// function will compare input list against a string patter, where "*" indicates parts of the pattern that can vary
// a sublist will be returned containing a set of unique parts of names from the input list that match the pattern

	arrayToMatch = Array.copy(list);
	pattern = template;	
	nMatches = 0;
	patternMatches = newArray(arrayToMatch.length);
	uniquePatterns = newArray(arrayToMatch.length);
	nPatterns = 0;
	patternSplitByWildCards = split(pattern,"*"); 
	//Array.print(patternSplitByWildCards);

	 
		for (i=0;i<arrayToMatch.length;i++) {
			 remainder = "";
			 tempPattern = "";
			 match = 0;
			 for (j=0;j<patternSplitByWildCards.length;j++) {
			 	if (indexOf(arrayToMatch[i], patternSplitByWildCards[j]) != -1) {
			 		arrayToMatch[i] = replace(arrayToMatch[i],patternSplitByWildCards[j],fromCharCode(167));
			 		match = 1;
			 	} else {
			 		match = 0;
			 	}
				if (match == 0) {
					// cancel loop of any part of pattern is not found in comparator
					j = patternSplitByWildCards.length;
				} 
			 }
			if (match == 1) {
				//reassemble patter
				wildCardParts = split(arrayToMatch[i],fromCharCode(167));
				for (l=0;l<patternSplitByWildCards.length-1;l++) {
					tempPattern = tempPattern + patternSplitByWildCards[l];
					tempPattern = tempPattern + wildCardParts[l];
				}
				tempPattern = tempPattern + patternSplitByWildCards[l];
				uniquePatterns[nPatterns] = tempPattern;
				nPatterns++;
					patternMatches[nMatches] = arrayToMatch[i];
					nMatches++;
			}
		}

		patternMatches = Array.trim(patternMatches,nMatches);
		for (i=0;i<patternMatches.length;i++) {
			//print(patternMatches[i]);
		}
		uniquePatterns = Array.trim(uniquePatterns,nPatterns);
		for (i=0;i<uniquePatterns.length;i++) {
			//print(uniquePatterns[i]);
		}
		return uniquePatterns;
}

function timeStamp() {

	//grab time stamp for analysis
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	day = dayOfMonth; if (day < 10) day = "0"+ dayOfMonth;
	mo = month; if (mo < 10) mo = "0"+ month;
	hr = hour; if (hr < 10) hr = "0"+ hour;
	min = minute; if (min < 10) min = "0"+ min;
	timeStampValue = year + "" + mo + "" +day+"-"+hr+"" +min;
	return timeStampValue;

}

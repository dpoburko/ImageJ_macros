/*
Written by Damon Poburko, Biomedical Physiology & Kinesiology, Simon Fraser University, Feb 2020
Use: Parses a folder for 2 sets of ROIs with unique string in each and tries to match them.
First set of ROIs is opened, and then the second set is opened, and ROIs in the first set are assigned new subsets of ROIs that fall within each of the larger ROIs in the 2nd set.
*/


dir = getDirectory("Choose a directory with images and ROIs");
dirArray = newArray(dir);
outPutDir = "subdividedROIs";
namingOptions = newArray("serial ID #s","ROI names in set B");

imgRange = "";
	//outPutLabel = "_test";
	//skipRoiString = "dummy";
	analyzeROIs = "false";
	roiAChannel = parseInt(call("ij.Prefs.get", "dialogDefaults.roiAChannel", 1));
	pxSize = 60;
	//roiFileString = "nucleus";
	roiFileString = "nucSurround-599";
	Dialog.create("Assign ROIs in set A to larger ROIs in Set B ");
    Dialog.addMessage("For each image in the selected folder, matching ROI sets for \n small objects (set A, e.g. organelles) will be assigned to \n new ROI sets defined by larger ROIs (set B, e.g. cell boundaries). \n \n File name patterns must be: \n    [image_name].[extension] \n    [setAprefix][image_name].zip\n    [setBprefix][image_name].zip");
    //Dialog.addString("Label for output file",call("ij.Prefs.get", "dialogDefaults.outPutLabel", outPutLabel));
    //Dialog.addNumber("Ignore ROIs in set B smaller than: ",parseInt(call("ij.Prefs.get", "dialogDefaults.minROIsize", 1)),0,8,"px^2");
    //Dialog.addString("Skip ROIs containing this text", call("ij.Prefs.get", "dialogDefaults.skipRoiString", skipRoiString));
    Dialog.addString("ROI set A unique prefix [e.g. 'MTO', 'puncta']", call("ij.Prefs.get", "dialogDefaults.roisAString", ""));
    Dialog.addString("ROI set B file unique prefix [e.g. 'nucleus', 'cell']", call("ij.Prefs.get", "dialogDefaults.roisBString", ""));
    //Dialog.addNumber("Range of numbers to analyze (x-y or blank for all)", 1,0,8,"");
    
    Dialog.addNumber("channel to measure ROI set A", parseInt(call("ij.Prefs.get", "dialogDefaults.roiAChannel", 1)),0,8,""); 
    Dialog.addString("Images analyzed (blank = all, or e.g. 3-8)", call("ij.Prefs.get", "dialogDefaults.imgRange", imgRange));
    Dialog.addChoice("Name surrounding ROIs as: ", namingOptions, call("ij.Prefs.get", "dialogDefaults.namingOptionsChoice", namingOptions[0]));
    Dialog.addCheckbox("Confirm set measurements.",call("ij.Prefs.get", "dialogDefaults.checkMsts", false));
    Dialog.addCheckbox("Run in batch mode.",call("ij.Prefs.get", "dialogDefaults.doBatchMode", false));
    Dialog.addCheckbox("time stamp output folder", call("ij.Prefs.get", "dialogDefaults.timeStampOutputFolder", false));
   // Dialog.addCheckbox("Notify by email when done", false);
    Dialog.setLocation(20,20);
    Dialog.show();

	//outPutLabel = Dialog.getString();			call("ij.Prefs.set", "dialogDefaults.outPutLabel", outPutLabel); 
	//minROIsize = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.minROIsize", minROIsize); 
	//skipRoiString = Dialog.getString();			call("ij.Prefs.set", "dialogDefaults.skipRoiString", skipRoiString); 
	roisAString = Dialog.getString();			call("ij.Prefs.set", "dialogDefaults.roisAString", roisAString); 
	roisBString = Dialog.getString();			call("ij.Prefs.set", "dialogDefaults.roisBString", roisBString); 
	roiAChannel = Dialog.getNumber();			call("ij.Prefs.set", "dialogDefaults.roiAChannel", roiAChannel); 
	imgRange = Dialog.getString();				call("ij.Prefs.set", "dialogDefaults.imgRange", imgRange); 
namingOptionsChoice = Dialog.getChoice();				call("ij.Prefs.set", "dialogDefaults.namingOptionsChoice", namingOptionsChoice);
nameByRoiNames = false;
if (namingOptionsChoice == namingOptions[1])  nameByRoiNames = true;
 
	//nameByRoiNames = Dialog.getCheckbox();		call("ij.Prefs.set", "dialogDefaults.nameByRoiNames", nameByRoiNames); 
	checkMsts = Dialog.getCheckbox();			call("ij.Prefs.set", "dialogDefaults.checkMsts", checkMsts); 
	doBatchMode = Dialog.getCheckbox();			call("ij.Prefs.set", "dialogDefaults.doBatchMode", doBatchMode); 
	timeStampOutputFolder= Dialog.getCheckbox();  call("ij.Prefs.set", "dialogDefaults.timeStampOutputFolder", timeStampOutputFolder); 
	//doSendEmail = Dialog.getCheckbox();  
	doSendEmail = false;
	
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

if (doBatchMode==true) setBatchMode(true);

t0 = getTime();


for (dd=0;dd<dirArray.length;dd++) {

	if (dirArray[dd]=="") {
		dd++;
	} else {
			dir = dirArray[dd]; 
			mainList = getFileList(dir);
			mainList = Array.sort(mainList);
			imgList = newArray(mainList.length);
			roiASetList = newArray(mainList.length);
			roiBSetList = newArray(mainList.length);
			nImgs = 0;
			nRoisSets = 0;
			fTypesAllowed = newArray(".tif",".TIF",".tiff",".TIFF",".lsm",".nd2");
			oBackGroundColor = getValue("color.background");
			oForeGroundColor = getValue("color.foreground");
			run("Colors...", "foreground=white background=black selection=cyan");
			run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated stack display decimal=3");
			if (checkMsts== true) {
				waitForUser("Click Analyze>Set Measurments and confirm \n the measurements you want to be analyzed");
			}
			
			tStart =getTime();
			print("\\Clear");

			// ========== Generate sets of matched images and small and large ROIs ================================================
			imgList = newArray();
			for ( i =0; i< mainList.length; i++) {
				for (k = 0; k<fTypesAllowed.length; k++) {
					if (endsWith(toLowerCase(mainList[i]),fTypesAllowed[k])) {
						imgList = Array.concat(imgList,mainList[i]);
					}
				}
			}
			roiASetList = newArray();
			for ( i =0; i< mainList.length; i++) {
				if (( endsWith(mainList[i], ".zip") == true) && ( indexOf(mainList[i], roisAString ) !=-1 )) {
					roiASetList = Array.concat(roiASetList,mainList[i]);
				}
			}
			roiBSetList = newArray();
			for ( i =0; i< mainList.length; i++) {
				if (( endsWith(mainList[i], ".zip") == true) && ( indexOf(mainList[i], roisBString ) !=-1 )) {
					roiBSetList = Array.concat(roiBSetList,mainList[i]);
				}
			}
			Array.sort(imgList);
			Array.sort(roiASetList);
			Array.sort(roiBSetList);
			//Array.show("Files found", imgList, roiASetList, roiBSetList);
			//waitForUser("exit?");
			
			imgListOK = newArray();
 			roiASetListOK = newArray();
 			roiBSetListOK = newArray();
 			t1 = getTime();
			for ( i =0; i< imgList.length; i++) {

				baseName = substring(imgList[i],0,indexOf(imgList[i],"."));
				matchForA = false;
				matchForB = false;
				for ( j =0; j< roiASetList.length; j++) {
					if (indexOf(roiASetList[j],baseName)!=-1) {
						roiASetListOK = Array.concat(roiASetListOK,roiASetList[j]);
						matchForA = true;
						j = roiASetList.length;
					}
				}
				for ( j =0; j< roiBSetList.length; j++) {
					if (indexOf(roiBSetList[j],baseName)!=-1) {
						roiBSetListOK = Array.concat(roiBSetListOK,roiBSetList[j]);
						matchForB = true;
						j = roiASetList.length;
					}
				}
				if ((matchForA==true) && (matchForB==true)){
					imgListOK = Array.concat(imgListOK,imgList[i]);
				}
			}

			//Array.show("matched Files", imgListOK, roiASetListOK, roiBSetListOK);
			//waitForUser("files matched?");

			// ================= Select specific range of images to be analyzed. ==========================
			if (imgRange=="") {
				imgSubSetStart = 0;
				imgSubSetEnd = imgListOK.length;
			}
			if (imgRange!="") {
			rangeArray = split(imgRange,"-");
				imgSubSetStart = parseInt(rangeArray[0]);
				if (rangeArray[1] != "") {
					imgSubSetEnd = parseInt(rangeArray[1]);	
				} else {
					imgSubSetEnd = imgListOK.length;
				}
			}
			nImgs = imgSubSetEnd - imgSubSetStart ;
			print("\\Update7: " + nImgs + " images to be analyzed");
			imgListOK = Array.slice(imgListOK,imgSubSetStart,imgSubSetEnd+1);
			roiASetListOK = Array.slice(roiASetListOK,imgSubSetStart,imgSubSetEnd+1);
			roiBSetListOK = Array.slice(roiBSetListOK,imgSubSetStart,imgSubSetEnd+1);
			//print("images to be analyzed. Analyzing ROIs within each image: " + analyzeROIs);

			//Array.show("matched Files", imgListOK, roiASetListOK, roiBSetListOK);
			//waitForUser("files matched?");

			//================= Generate time stamp =======================================================================
			getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
			dom = IJ.pad(dayOfMonth,2);
			mo = IJ.pad(month+1,2);
			yr = substring(year,2,4);
			hr = IJ.pad(hour,2);
			min = IJ.pad(minute,2);
			timeStamp = "_" + yr+"" +mo+"" +dom+"-"+hr+"" +min;
			if (timeStampOutputFolder==false) {
				timeStamp = "";
			} else {
				outPutDir = outPutDir + "_" + timeStamp;
			}
			print("\\Update0: ananlyzing " + imgListOK.length+ " images");

			// ================ Loop through images ========================================================================
			for (i=0; i<imgListOK.length; i++) {
		
				open(dir + imgListOK[i]);
				img0 = getTitle();
				print("\\Update1: opened " + img0);
				getDimensions(width, height, channels, slices, frames);
				baseName = substring(img0,0,indexOf(img0,"."));
				tempImg = baseName+"_C"+roiAChannel;
				if (channels >1) { 
					run("Duplicate...", "title="+tempImg+" duplicate channels="+roiAChannel);
					rename(tempImg); //
					selectWindow(tempImg);
				}	

				roiManager("reset");
				roiManager("Open",dir + roiASetListOK[i]);
				print("\\Update2: opened " + roiASetListOK[i]);
				roisSmallStart = 0;
				roisSmallEnd = roiManager("count")-1;
				roisBigStart = roiManager("count");
  				roiManager("Open", dir + roiBSetListOK[i]);		// open cell ROIs file if using subcell ROIs  
  				print("\\Update3: opened " + roiBSetListOK[i]);
				roisBigEnd = roiManager("count")-1;
				nCells = roisBigEnd - roisBigStart;
				run("Clear Results");
				roiManager("deselect");
				
				//to get centroid of each ROI, particularly the small ones
				roiManager("measure");   
				rsXs = newArray(1+roisSmallEnd - roisSmallStart);
				rsYs = newArray(1+roisSmallEnd - roisSmallStart);
				
				for (rs = roisSmallStart; rs <= roisSmallEnd; rs++) {
					rsXs[rs] = getResult("X",rs);		
					rsYs[rs] = getResult("Y",rs);		
				}
				
				rsIndexPerCell = newArray(0); //holder for index of sub-cellular ROIs that are contained within the current cell
				tStartCells = getTime;

				if (!File.exists( dir + File.separator+outPutDir)) {
					File.makeDirectory(dir + File.separator+outPutDir);	
				}
				// ===================================================================================================================
				// ======= loop through each cell ROI in currImage ==================================================================							
				for (rb = roisBigStart; rb <= roisBigEnd; rb++) {
						showProgress(rb/roisBigEnd);
						tPerCell0 = getTime;
					
						cellID = rb-roisBigStart;
						rsIndex = newArray(0); // holder of indicies of small ROIs (rs) within big ROI (rb)
						
						roiManager("select", rb);  // any modification of the "cell" ROI would need to be done in a function that resets the boundaries of the current cell ROI
						Roi.getBounds(xrb, yrb, wrb, hrb);
						roiName = Roi.getName;
						if (roiName=="") roiName= "ROI"+IJ.pad(rb,5); 
						// collect indicies of small ROIs (rs) whose centroids are inside large ROI (rb)
						for (rs = roisSmallStart; rs <= roisSmallEnd; rs++) {
								//check if each small ROIs is within
								if (Roi.contains(rsXs[rs],rsYs[rs])==1) {
									//add to array of indicies to select as a subgroup to measure and save to txt for for that cell
									rsIndex = Array.concat(rsIndex,rs);	
								}
								if (rsYs[rs] > (yrb+hrb) ) rs = roisSmallEnd; //jump to end of list when Y of rs passes Y bounds of rb
						}

						run("Set Measurements...", "area mean standard min centroid center perimeter fit shape integrated stack display redirect=None decimal=3");
	
						fileName = dir + File.separator+outPutDir + File.separator+ baseName+"_" + cellID;

						// some cell ROIs may not have any small ROIs within them. They will be overlooked from this point 
						if (rsIndex.length>1) {
							roiManager("deselect");	
							roiManager("select",rsIndex);
							run("Clear Results");
							roiManager("measure");
							if (nameByRoiNames==true) rbName = "_"+ roiName;
							if (nameByRoiNames==false) rbName = "_CELL"+ IJ.pad(cellID,5);
							print("\\Update6: savine ROIs details to .txt");
							saveAs("Measurements", "" + fileName  + rbName + "_ROIs.txt");   // need to generate path name
							print("\\Update6: savine ROIs to .zip: "+  rbName + "_ROIs.zip");
							roiManager("save selected", "" + fileName + rbName + "_ROIs.zip");
							roiManager("combine");
							roiManager("add");
							newIndex = roiManager("count")-1;
							roiManager("select", newIndex);
							roiManager("rename", rbName);
						}
						tPerCell1 = getTime;
						bLapTime = (tPerCell1-tPerCell0)/1000;
						tbLeft = (  (  (tPerCell1 - tStartCells) / (cellID+1) ) * ( nCells-cellID ) ) / 1000 ;
						bProgress = ( cellID )/nCells ;
						bPctDoneLength = 40;
						bPctDone = bProgress*bPctDoneLength;
						bPctDoneString = "";
						bPctLeftString = "";
						
						for(cc = 0; cc<bPctDoneLength;cc++) {
							bPctDoneString = bPctDoneString + "|";
							bPctLeftString = bPctLeftString + ".";
						}
						bPctDoneString = substring(bPctDoneString ,0,bPctDone);
						bPctLeftString = substring(bPctLeftString ,0,bPctDoneLength - bPctDone);
						print ("\\Update7: Assigning ROIs to cells " + bPctDoneString + bPctLeftString + " cell " +  (cellID+1) + " of " + nCells + ". Loop time: " + d2s(bLapTime,3) + " s, " + d2s(tbLeft,2) + " s left"   );
						
				} // close rb loop
				if (isOpen(tempImg)) {
					close(tempImg);
				}

				close("*");
						
				//Create progress bar in log
				lapTime = (getTime() - t1)/1000;
				t1 = getTime();
				
				//if (batchParamsArray[1]=="") paramLoopsLeft = 0;
				tLeft = (  (  (t1-t0) / (i+1) ) * ( imgListOK.length - i) )  / 1000 ;
				tLeftjLoop = (  (  (t1-t0) / (i+1) ) * (imgListOK.length-i) )  / 1000 ;
				progress = ( i + 1)/imgListOK.length ;
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
				if (tLeftjLoop/60 <= 60 ) tLeftStr1 = d2s(tLeftjLoop/60,1) + " min for img set" ;
				if (tLeftjLoop/60 > 60 ) tLeftStr1 = d2s(tLeftjLoop/3600,1) + " hr for img set" ;
				if (tLeft/60 <=60 ) tLeftStr2 = d2s(tLeft/60,1) + " min";
				if (tLeft/60 >60 ) tLeftStr2 = d2s(tLeft/3600,1) + " hr";
				print ("\\Update1: image set: " + pctDoneString + pctLeftString + " " +  (i+1) + " of " + imgListOK.length + " loop time: " + d2s(lapTime/60,3) + " min. " + tLeftStr1);

		}	// close i loop		

		
} // close if procParamsArray !=""
		

		
			//if (isOpen(pBar)==true) close(pBar+"*");
			if (doBatchMode==true) setBatchMode("exit and display");
			run("Colors...", "foreground="+oForeGroundColor+" background="+oBackGroundColor+" selection=cyan");
			
print("\\Update8: batch processing complete");
			print("\\Update9: processing time: " + ( getTime() - tStart)/60000 + " min" );
			
	//}	//close If dirArray[dd] == ""
//} //close dirArray loop

//if (doBatchMode==true) setBatchMode("exit and display"); //RIPA



if (doSendEmail == true) {
		// Send Email Module 2: Place at end of code once all other operations are complete
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
		File.saveString(pShellString, path);
		exec("cmd", "/c", "start", "powershell.exe", path);
		hide1 = File.delete(path);
	}



// ========================================================================================================================
// ================ FUNCTIONS ============================================================================================
// ========================================================================================================================

function swAutoFocus(imgName) {
	img0 = getTitle;
	img1 = img0+"ROI";
	Stack.getDimensions(width, height, channels, slices, frames) ;
	Stack.getPosition(channel, slice, frame) ;
	currSlice = slice;
	maxSD = 0;
	bestSlice = 1;

	for (i = 0; i<slices; i++) {
		setSlice( i+1);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		if (std > maxSD) {
			maxSD = std;
			bestSlice = i+1;
		}
	}
	setSlice(bestSlice);
	return(bestSlice);
}

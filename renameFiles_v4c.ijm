requires("1.42l");
print("\\Clear"); 

fileTypes =  newArray("All Files","All but folders", "/",".tif",".tiff", ".txt", ".zip", ".csv",".nd2",".jpg", ".doc", ".docx");
defaultDir = getDirectory("imagej");
mainDir = call("ij.Prefs.get", "dialogDefaults.mainDir", defaultDir);


Dialog.create("Filtered File Renaming");
Dialog.setInsets(0, 0,0) ;
Dialog.addString("Old string (+ ~'s)", call("ij.Prefs.get", "dialogDefaults.oString", "some text"),30);
Dialog.addString("New string (+ #'s)", call("ij.Prefs.get", "dialogDefaults.nString", "new text"),30);

Dialog.setInsets(0, 0,0) ;
Dialog.addMessage("Optional features") ;
Dialog.addMessage("  Add leading or lagging ~'s to old string to replace flanking wildcards") ;
Dialog.addMessage("  Add leading ^ to only replace at start of old string (e.g. ggt > old ^g > new c > cgt)") ;
Dialog.addMessage("  Add lagging $ to only replace at end of old string (e.g. bumble bee > old e$ > new g > bumble beg)") ;

//Dialog.addMessage("New string. Lagging #'s add a padded number sequence ") ;

//Dialog.setInsets(0, 30,0) ;
Dialog.addNumber("Lagging #'s add a padded number sequence starting at...", parseInt(call("ij.Prefs.get", "dialogDefaults.seqStart", "0"),10));
Dialog.addChoice("choose the file type to be renamed",fileTypes, call("ij.Prefs.get", "dialogDefaults.fileType", fileTypes[0]));
Dialog.addCheckbox("Change file extension", false);
Dialog.addDirectory("Folder to process", mainDir);
Dialog.addCheckbox("Process subdolders recursively", false);
Dialog.show();
  
// ====== retrieve values ============================
	
tag1 = Dialog.getString(); //old string

	 	call("ij.Prefs.set", "dialogDefaults.oString", tag1);
tag2 = Dialog.getString(); // new string

		call("ij.Prefs.set", "dialogDefaults.nString", tag2);
seqStart = Dialog.getNumber();
		call("ij.Prefs.set", "dialogDefaults.seqStart", seqStart);
fileType =  Dialog.getChoice(); 
		
call("ij.Prefs.set", "dialogDefaults.fileType", fileType);
doExtension = Dialog.getCheckbox();
mainDir = Dialog.getString();
		call("ij.Prefs.set", "dialogDefaults.mainDir", mainDir);
recursive = Dialog.getCheckbox();

atStart = false;
atEnd = false;
if (startsWith(tag1,"^"))  {
	atStart = true;
	tag1 = replace(tag1,"^","");
}
if (endsWith(tag1,"$")) {
	atEnd = true;
	tag1 = replace(tag1,"$","");
}

mainList = getFileList(mainDir);

if (!recursive) {
	
	dList = newArray(mainList.length);
	for (j=0;j<mainList.length;j++) {
		dList[j] = mainDir;
	}
	fList = mainList;
	
	
} else {

	print("\\Clear"); //clear the log
	listFiles(mainDir); 				//get a list of all files and sub-directories to the log
	logString = getInfo("Log");			//save to a string
	mainList2 = split(logString,"\n");	//break lines to an array
	//Array.show(mainList,mainList2);
	//separate filenames to one list and directories to another
	dList = newArray();
	fList = newArray();	

	for (j=0;j<mainList2.length;j++) {
		thisLine = mainList2[j];
		if (endsWith(thisLine,"/")){
			thisDir = substring(thisLine,0,lastIndexOf(substring(thisLine,0,lengthOf(thisLine)-1), "/")+1);
		}else{
			thisDir = substring(thisLine,0,lastIndexOf(thisLine, "/")+1);
		}
		//thisFile = replace(thisLine, thisDir, "");
		thisFile = substring(thisLine, lengthOf(thisDir), lengthOf(thisLine));
		fList = Array.concat(fList, thisFile);
		dList = Array.concat(dList, thisDir);

	}

	function listFiles(dir) {
	 list = getFileList(dir);
	 for (i=0; i<list.length; i++) {
	    if (endsWith(list[i], "/")) {
	       print( dir + list[i]);
	       listFiles(""+dir+list[i]);
	    } else {
	       print( dir + list[i]);
	    }
	 }
	}
}
//Array.show(dList,fList);
print("\\Clear");
tStart = getTime();
print("\\Update0: got file list. Might have taken a while for large folders");

// Parse tag1 for *, number and location
//tag1 = "~~test~~~";
tag1prefix = indexOf(tag1,"~");
tag1Base = replace(tag1,"~","");
tag1Length = lengthOf(tag1Base);
nPreTag1 = indexOf(tag1,tag1Base);
nsufxTag1 = lengthOf(tag1) - tag1Length - nPreTag1;

print("\\Update3: tag1Base " + tag1Base +" nPreTag1 " + nPreTag1+" nsufxTag1 " + nsufxTag1+" tag1prefix: "+tag1prefix);

//tag2 = "out-#####";
tag2Base = replace(tag2,"#","");
padLength = 0;
if (indexOf(tag2, "#")!=-1) { padLength = lengthOf(tag2)- indexOf(tag2, "#");  }
print("\\Update3: tag2Base " + tag2Base + " padLength " + padLength);

setBatchMode(true);

	
serialNum = seqStart;
nReplaced =0;

for (j=0; j<fList.length; j++) {                                                                                                       // for loop to parse through names in main folder
	showProgress(j/fList.length);
	if ( endsWith(fList[j], "/") ) {                                      // reset this to use the function filter with various conditions
		//need to sort out how to rename folders
		baseName = fList[j];
		fType = "/";
	} 
else {
		print("\\Update5: fList["+j+"] is "+fList[j]);
	    baseName = replace(fList[j],"/","");
	    fType = substring(fList[j], lastIndexOf(fList[j], "."), lengthOf(fList[j]));
	    
	}
	print("\\Update6: fType is "+fType+" fileType is: "+fileType);
	
    loopStart = getTime();
	print("\\Update10: filter("+fList[j]+", "+tag1Base+", "+fileType+")");
	//wait(300);
	if ( filter(fList[j], tag1Base, fileType)==true ) {

		tag1Full = tag1Base;
		newName = replace(fList[j], fType, "");

		if (nPreTag1>0) {
			prefix = substring(newName, indexOf(newName,tag1Base)-nPreTag1,indexOf(newName,tag1Base));
			tag1Full = prefix + tag1Full;
			print("\\Update7: tag1 + prefix " + j);
		}
		if (nsufxTag1>0) {
			suffix = toLowerCase(substring(newName, indexOf(newName,tag1Full) + lengthOf(tag1Full),indexOf(newName,tag1Full)+ lengthOf(tag1Full)+nsufxTag1));
			tag1Full = tag1Full + suffix;
			print("\\Update7: tag1 + suffix " + j);
		}
		if ( (atStart==false) & (atEnd==false) ) {				

			seqSuffix = "";
			if(padLength > 0) seqSuffix = IJ.pad(serialNum,padLength);
			newName = replace(newName, tag1Full, tag2Base+seqSuffix);
			path1 = dList[j] + fList[j];
			path2 = dList[j] + newName + fType;
			hideLog1 = File.rename(path1, path2);
			print("\\Update8: path1: " + path1);
			print("\\Update9: path2: " + path2);

			nReplaced = nReplaced + 1;	
			serialNum++;
		}
		if (atStart==true) {
			//only change file name if current file starts with Tag
			if (startsWith(newName,tag1)) {
				remainder = newName; 
				if (tag1!="") remainder = substring(newName,lengthOf(tag1),lengthOf(newName));
				newName = tag2+remainder;
				path1 = dList[j] + fList[j];
				path2 = dList[j] + newName + fType;
				hideLog1 = File.rename(path1, path2);
				print("\\Update8: path1: " + path1);
				print("\\Update9: path2: " + path2);

				nReplaced = nReplaced + 1;	
				serialNum++;
			}
		}
		if (atEnd==true) {
			
			doEnd = true; //if adding a global suffix to end of file names
			//if only acting on files that end with a specific string specified in tag1, flag doEnd = false to skip if 
			//the filename doesn't end in tag1 (less the $).
			if (endsWith(newName,tag1)==false) doEnd = false;

			remainder = substring(newName,0,lengthOf(newName)-lengthOf(tag1));
			
			if (doEnd==true) {
				newName = remainder+tag2;
				path1 = dList[j] + fList[j];
				path2 = dList[j] + newName + fType;

				hideLog1 = File.rename(path1, path2);
				print("\\Update8: path1: " + path1);
				print("\\Update9: path2: " + path2);
				nReplaced = nReplaced + 1;	
				serialNum++;
			}
		}

	}
	
	if (doExtension==true) {
		if (endsWith(fList[j],fileType)==true) {
			
			newName = replace(fList[j],fileType,tag2);
			
			path1 = dList[j] + fList[j];
			path2 = dList[j] + newName;
			print("\\Update8: path1: " + path1);
			print("\\Update9: path2: " + path2);
			hideLog1 = File.rename(path1, path2);
		}
	}
}                                        // close j loop through main list

setBatchMode(false); 


// ============================================================================================
// ============== FUNCTIONS ===================================================================
// ============================================================================================

// *****************************************************************************************************************************************************************************************
function filter(name, t1, type) {    // selection criteria to only use certain images  ***************************************************************************************************************************
// *****************************************************************************************************************************************************************************************
	// positive selection filter. If any image meets these requirements, it will pass the filter.
		if (indexOf(name,t1)==-1)  return false;            
		if (type == "All Files") {
			return true;
		} else if (type == "All but folders") {
				if (endsWith(name,File.separator)) {
					return false;              
				} else {
					return true;	
				}
		} else {
			if (endsWith(name,type)==false) {
				return false;              
			} else {
				return true;
			}
		}
 }    

tEnd = getTime();
timeElapsed = (tEnd - tStart)/1000;
setBatchMode(false); 
print("macro took " + (timeElapsed/60) + " (min), " + nReplaced + " files renamed."); 

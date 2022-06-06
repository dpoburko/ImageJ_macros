requires("1.42l");
print("\\Clear"); 

fileTypes =  newArray("All Files", "/",".tif", ".txt", ".zip", ".csv",".nd2",".jpg", ".doc", ".docx");

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
Dialog.show();
  
// ====== retrieve values ============================
	
	tag1 = Dialog.getString(); //old string
		 	call("ij.Prefs.set", "dialogDefaults.oString", tag1);
	tag2 = Dialog.getString(); // new string
			call("ij.Prefs.set", "dialogDefaults.nString", tag2);
	seqStart = Dialog.getNumber(); call("ij.Prefs.set", "dialogDefaults.seqStart", seqStart);
	fileType =  Dialog.getChoice(); call("ij.Prefs.set", "dialogDefaults.fileType", fileType);

atStart = false;
atEnd = false;
if (startsWith(tag1,"^")) {
	atStart = true;
	tag1 = replace(tag1,"^","");
}
if (endsWith(tag1,"$")) {
	atEnd = true;
	tag1 = replace(tag1,"$","");
}


tStart = getTime();

	mainDir = getDirectory("Choose a Directory ");
	print("\\Update0: getting file list. Might take a while for large folders");
	mainList = getFileList(mainDir);

// Parse tag1 for *, number and location
//tag1 = "~~test~~~";

tag1prefix = indexOf(tag1,"~");
tag1Base = replace(tag1,"~","");
tag1Length = lengthOf(tag1Base);
nPreTag1 = indexOf(tag1,tag1Base);
nsufxTag1 = lengthOf(tag1) - tag1Length - nPreTag1;

print("tag1Base " + tag1Base);
print("nPreTag1 " + nPreTag1);
print("nsufxTag1 " + nsufxTag1);
print(tag1prefix);

//tag2 = "out-#####";
tag2Base = replace(tag2,"#","");
print("tag2Base " + tag2Base);
padLength = 0;
if (indexOf(tag2, "#")!=-1) { padLength = lengthOf(tag2)- indexOf(tag2, "#");  }
print("padLength " + padLength);

setBatchMode(true);
	
	serialNum = seqStart;
	nReplaced =0;

	for (j=0; j<mainList.length; j++) {                                                                                                       // for loop to parse through names in main folder
   		showProgress(j/mainList.length);
   		if ( endsWith(mainList[j], "/") ) {                                      // reset this to use the function filter with various conditions
			//need to sort out how to rename folders
			baseName = mainList[j];
			fType = "/";
		} else {
		    baseName = replace(mainList[j],"/","");
		    fType = substring(mainList[j], lastIndexOf(mainList[j], "."), lengthOf(mainList[j]));
		}
		          
        loopStart = getTime();
		          
		if ( filter(mainDir, mainList[j], tag1Base, fileType) ) {
	
			tag1Full = tag1Base;
			newName = replace(mainList[j], fType, "");
	
			if (nPreTag1>0) {
				prefix = substring(newName, indexOf(newName,tag1Base)-nPreTag1,indexOf(newName,tag1Base));
				tag1Full = prefix + tag1Full;
				print("\\Update0: tag1 + prefix " + j);
			}
			if (nsufxTag1>0) {
				suffix = toLowerCase(substring(newName, indexOf(newName,tag1Full) + lengthOf(tag1Full),indexOf(newName,tag1Full)+ lengthOf(tag1Full)+nsufxTag1));
				tag1Full = tag1Full + suffix;
				print("\\Update0: tag1 + suffix " + j);
			}
			if ( (atStart==false) & (atEnd==false) ) {				
	
				seqSuffix = "";
				if(padLength > 0) seqSuffix = IJ.pad(serialNum,padLength);
				newName = replace(newName, tag1Full, tag2Base+seqSuffix);
				
				path1 = mainDir + mainList[j];
				path2 = mainDir + newName + fType;
				hideLog1 = File.rename(path1, path2);
				nReplaced = nReplaced + 1;	
				serialNum++;
			}
			if (atStart==true) {
				remainder = newName; 
				if (tag1!="") remainder = substring(newName,lengthOf(tag1),lengthOf(newName));
				newName = tag2+remainder;
				path1 = mainDir + mainList[j];
				path2 = mainDir + newName + fType;
				hideLog1 = File.rename(path1, path2);
				nReplaced = nReplaced + 1;	
				serialNum++;
			}
			if (atEnd==true) {
				
				doEnd = true; //if adding a global suffix to end of file names
				//if only acting on files that end with a specific string specified in tag1, flag doEnd = false to skip if 
				//the filename doesn't end in tag1 (less the $).
				if (endsWith(newName,tag1)==false) doEnd = false;

				remainder = substring(newName,0,lengthOf(newName)-lengthOf(tag1));
				
				if (doEnd==true) {
					newName = remainder+tag2;
					path1 = mainDir + mainList[j];
					path2 = mainDir + newName + fType;
					hideLog1 = File.rename(path1, path2);
					nReplaced = nReplaced + 1;	
					serialNum++;
				}
			}
	
		}
   
	}                                        // close j loop through main list



setBatchMode(false); 

// ============================================================================================
// ============== FUNCTIONS ===================================================================
// ============================================================================================

// *****************************************************************************************************************************************************************************************
function filter(subDir, name, t1, type) {    // selection criteria to only use certain images  ***************************************************************************************************************************
// *****************************************************************************************************************************************************************************************
	// positive selection filter. If any image meets these requirements, it will pass the filter.
		if (indexOf(name,t1)==-1)  return false;            
		if (type != "All Files") {  
			if (indexOf(name,type)==-1) return false;              
		}
		return true;
 }    

tEnd = getTime();
timeElapsed = (tEnd - tStart)/1000;
setBatchMode(false); 
print("macro took " + (timeElapsed/60) + " (min), " + nReplaced + " files renamed."); 

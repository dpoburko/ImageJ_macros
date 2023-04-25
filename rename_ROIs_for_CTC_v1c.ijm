/*
 * Created by Damon Poburko. Tis is a helper macro to label ROIs to create groundtruth tracks for TrackMate helper
 * April 17, 2023
 */


rc = roiManager("count");
rNames = newArray(rc);
thisIndex = roiManager("index");
prevIndex = -1;
end = false;
lastNumber = -1;
thisNumber = -1;
title = "update ROI name + integer";
msgString = "";
doDialog = true;
updateName = false;

print("\\Clear");
print("\\Update0: # ROIs = " + rc );
print("\\Update1: thisIndex = " + thisIndex);
wait(500);

if ((thisIndex==-1)||(thisIndex==(rc-1))) {
	
	while ((thisIndex==-1)||(thisIndex==(rc-1))) {
		thisIndex = roiManager("index");
		showStatus("Choose a first ROI!");
		
		print("\\Update4:Choose a first ROI! thisIndex ="+thisIndex);
		print("\\Update2: doDialog: " + doDialog);
		print("\\Update3: updateName: " + updateName);
		wait(50);
	}
		showStatus("next ROI!");
		print("\\Update4: next ROI!");
}

for (i=0;i<rc;i++) {
	print("\\Update1: parsing ROI " + i);
	roiManager("select", i);
	nameParts = split(Roi.getName,"-");
	if (isNaN(parseInt(nameParts[0]))==false) rNames = Array.concat(rNames,IJ.pad(parseInt(nameParts[0]),4));
}
roiManager("select",thisIndex);

rNames = unique(rNames);
usedNumbers = rNames;
Array.getStatistics(rNames , min, maxIndexAtStart, mean, stdDev);
thisNumber = maxOf(call("ij.Prefs.get", "dialogDefaults.thisNumber", "1"),maxIndexAtStart+1);		


while (end==false) {
	
	thisIndex = roiManager("index");
	
	//stall the macro until the user selects a new ROI
	if ( (thisIndex!=prevIndex)&&(thisIndex!=-1)) {

		//load the dialog to get a new cell number
//		thisNumber = maxOf(call("ij.Prefs.get", "dialogDefaults.thisNumber", "1"),maxIndexAtStart+1);		
 
		
		if (doDialog == true) {
			//Dialog.createNonBlocking(title);
			
			nameParts = split(Roi.getName,"-");
			if ( (isNaN(nameParts[0]) == false) & (nameParts.length>3) ) {
				if (nameParts[0] != lastNumber)  thisNumber = ""+(parseInt(nameParts[0])+1)+"";	
			}
			//if (isNaN(nameParts[0]) == true) {
			//	 thisNumber = ""+(parseInt(lastNumber)+1)+"";	
			//}
			doDialog = false;
			updateName = true;
			print("\\Update2: doDialog: " + doDialog);
			print("\\Update3: updateName: " + updateName);			
			
			Dialog.create(title);
			Dialog.addMessage(msgString);
			Dialog.addString("Number of current cell", thisNumber, 6);
			Dialog.addCheckbox("re-used number", false);
			Dialog.addCheckbox("Done", false);
			Dialog.show();
			thisNumber = Dialog.getString();
				call("ij.Prefs.set", "dialogDefaults.thisNumber", thisNumber);
			useOldNumber = Dialog.getCheckbox();
			end = Dialog.getCheckbox();	
			print("\\Update4: thisNumber = " + thisNumber);
				
		}
		//print("\\Update2: Dialog is open: " + isOpen(title));
	
		if ( (updateName == true) && (end == false) ) {

			//check if suggested cell number is alredy used
			if (usedNumbers.length == 0) {
				usedNumbers[0] = thisNumber;
			} else {
				//check if thisNumber already used
				alreadyUsed = false;
				for (j=0;j<usedNumbers.length;j++) {
					if (usedNumbers[j]== thisNumber) alreadyUsed = true;
				}
				if (alreadyUsed==false) {
					usedNumbers = Array.concat(usedNumbers,thisNumber);
					//carry on with another ROI for this cell
					roiManager("rename", parseInt(thisNumber)+"-"+Roi.getName);
					msgString = "";
					run("Select None");		
					roiManager("deselect");
					
				}
				if (alreadyUsed==true) {
					//current cell number had been used before. 
					if ( (lastNumber == thisNumber) || ((lastNumber != thisNumber) && (useOldNumber==true))  ) {
						//carry on with another ROI for this cell
						roiManager("rename", parseInt(thisNumber)+"-"+Roi.getName);
						msgString = "";
						
						roiManager("deselect");
						run("Select None");
					} else {
						//prompt to check if user really wants to recycle number
						//msgString = "That number is already used. Try" + usedNumbers[usedNumbers.length-1];
						 ""+(parseInt(checkName)+1)+""
					}
				}
			}
			doDialog = true;
			updateName = false;			
			
		}
				
	
		if (lastNumber != thisNumber) {
			print("\\Update0: lastNumber: " + lastNumber + " thisNumber: "+thisNumber);
			lastNumber = thisNumber;
		}
		if (prevIndex != thisIndex) {
			print("\\Update1: prevIndex: " + prevIndex + " thisIndex: "+thisIndex);	
			prevIndex = thisIndex;
		}
		
		print("\\Update2: doDialog: " + doDialog);
		print("\\Update3: updateName: " + updateName);
		wait(200);
	}
}

print("\\Update4: Exited macro");



//Described by https://forum.image.sc/t/get-unique-strings-from-an-array/2427/3
function unique(InputArray) {
    
    separator = "\\n";
    InputArrayAsString = InputArray[0];
    for(i = 1; i < InputArray.length; i++){
        InputArrayAsString += separator + InputArray[i];
    }
    
    script = "result = r'" + 
             separator +
             "'.join(set('" +
             InputArrayAsString +
             "'.split('" + 
             separator +
             "')))";
    
    result = eval("python", script);
    OutputArray = split(result, separator);
    OutputArray = Array.sort(OutputArray);
    Array.getStatistics(OutputArray , min, max, mean, stdDev);
    //Array.show(max + " unique ROIs",OutputArray);
    return OutputArray;
}

function nextNumber (list, number) {
	
	
	for (i=0;i<list.length;i++) {
		
	}
	
	
}

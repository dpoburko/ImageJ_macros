/*
Written by Damon Poburko at Simon Fraser University, April 2022
This macro aims to scan a list of images exported from a Sartorius Incucyte
and generate a list of well_position image base names in preparation 
for generating image stacks
*/

//USER DEFINED VARIABLES
chNames = newArray("Ch1","Ch2","Ch3");
nPrefixParts = 4;
chPart = 1; //base 0 index of part of file name containing Channel descriptor 
outName = "0_autoPrefixList_";


print("\\Clear");
run("Clear Results");
dir = getDirectory("Choose folder to parse for images");
dirParts = split(dir,File.separator);
print(dir);
Array.print(dirParts);
dirName = dirParts[dirParts.length-1];

imgType = ".tif";
print("\\Update0: Grabbing large file lists might take a while");
fList = getFileList(dir);
print("\\Update0: File list acquired");

nChannels = chNames.length;

nFiles = fList.length;
//remove non-image files from fList
for (i=0;i<nFiles;i++) {
	j = nFiles-i-1;
	if (endsWith(fList[j],".tif")==false) {
		fList = Array.deleteIndex(fList, j);
	}
	
}

uPrefixes = newArray(); //list of unique image prefixes, including varied channel numbers

nFiles = fList.length;
//remove non-image files from fList
for (i=0;i<nFiles;i++) {
	
	fNameParts = split(fList[i], "_");
	prefix = "";
	for (p=0;p<nPrefixParts;p++) {
		prefix = prefix + fNameParts[p];
		if (p<(nPrefixParts-1) ) prefix = prefix + "_";
	}

	pCaught = false;
	for (j=0;j<uPrefixes.length;j++) {
		if (prefix == uPrefixes[j]) pCaught=true;
	}
	if (pCaught==false) uPrefixes = Array.concat(uPrefixes,prefix);
}

print("\\Update0: Array of unique prefixes made. Contains " + uPrefixes.length+ " values");
Array.print(uPrefixes);

//if nChannels = 1, done, show list as table
uPrefixes = Array.sort(uPrefixes);

if (nChannels>1) {
// need to sort arrays ignoring Channel portion of name
//Simple approach is to make lists containing names of other channels list of names only containing Ch1 descriptor
//Then sample remaining names 

	ch1List = newArray();
	ch2List = newArray();
	ch3List = newArray();
	for (i=0;i<uPrefixes.length;i++) {
		for (j=0;j<nChannels;j++) {
			if ((j==0)&&(indexOf(uPrefixes[i], chNames[0])!=-1)) ch1List = Array.concat(ch1List,uPrefixes[i]);
			if ((j==1)&&(indexOf(uPrefixes[i], chNames[1])!=-1)) ch2List = Array.concat(ch2List,uPrefixes[i]);
			if ((j==2)&&(indexOf(uPrefixes[i], chNames[2])!=-1)) ch3List = Array.concat(ch3List,uPrefixes[i]);
		}
	}

	//Array.show("unique Prefixes by channel", ch1List, ch2List, ch3List);
	//waitForUser;

	//loop through list of ch1 images, check if other channels images match when ch x part is replaced with ch 1 part and add to results table to bbe saved a csv
	
	unmatched2 = newArray();
	unmatched3 = newArray();
	
	for (i=0;i<ch1List.length;i++) {
	
		setResult("Channel 1", nResults, ch1List[i]);	
	
		if (nChannels>1) {
			for (j=1;j<=ch2List.length;j++) {
				k =ch2List.length-j;
				if (replace(ch2List[k],chNames[1],chNames[0]) == ch1List[i]) {
					setResult("Channel 2", nResults-1, ch2List[k]);	
					ch2List = Array.deleteIndex(ch2List, k);
				}
				
			}
	
		}
		if (nChannels==3) {
			for (j=1;j<=ch3List.length;j++) {
				k =ch3List.length-j;
				if (replace(ch3List[k],chNames[2],chNames[0]) == ch1List[i]) {
					setResult("Channel 3", nResults-1, ch3List[k]);	
					ch3List = Array.deleteIndex(ch3List, k);
				}
				
			}
		}
	//updateResults();
	//wait(300);
	}
	
	if (nChannels>1) {
		for (j=0;j<ch2List.length;j++) {
				setResult("Channel 2", nResults, ch2List[j]);	
			
		}
	}
	if (nChannels==3) {
		for (j=0;j<ch3List.length;j++) {
				setResult("Channel 3", nResults, ch3List[j]);	
			
		}
	}

} //if nCHannels >1

nr = nResults;

//moveMismatches
loners = newArray();
for (i=1;i<=nr;i++) {
	j = nr-i;
	c1 = getResult("Channel 1", j);
	c2 = getResult("Channel 2", j);
	if (nChannels==3) c3 = getResult("Channel 3", j);
	remove = false;
	if ( (nChannels==2) && ( (c1==0) || (c2==0) )) remove == true;
	if ( (nChannels==3) && ( (c1==0) || (c2==0) || (c3==0) )) remove == true;
		
	if (remove==true) {
		loners = Array.concat(loners,c1);
		loners = Array.concat(loners,c2);
		if (nChannels==3) loners = Array.concat(loners,c1);
		Table.deleteRows(j, j);
	}

}

outPath = dir+outName+"_"+dirName+".csv";
saveAs("Results", outPath);
print("Generation of base names of image stacks complete");
print("Image prefixes saved in "+outPath);

if (loners.length>0) {
	run("Clear Results");
	for (i = 0; i<loners.length/nChannels;i++ {
		row = floor(i/nChannels);
		col = i%nChannels;
		colName = "Channel "+(col+1);
		setResult("Column", row, loners[i]);
		
	}
	lonerPath = dir+"0_unmatchedImages_"+dirName+".csv";
	saveAs("Results", lonerPath);
	print("Unmatched images listed in "+lonerPath);
}




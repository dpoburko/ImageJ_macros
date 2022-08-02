/*
Written by Damon Poburko at Simon Fraser University, April 2022
This macro aims to scan a list of images exported from a Sartorius Incucyte
and generate a list of well_position image base names in preparation 
for generating image stacks

v2c - fix issues for single channel
*/

//USER DEFINED VARIABLES
//chNames = newArray("Ch1","Ch2","Ch3");
nPrefixParts = 4;
chPart = 1; //base 0 index of part of file name containing Channel descriptor 
outName = "0_autoPrefixList_";
imgType = ".tif";

print("\\Clear");
run("Clear Results");
dir = getDirectory("Choose folder to parse for images");
dirParts = split(dir,File.separator);
print(dir);
Array.print(dirParts);
dirName = dirParts[dirParts.length-1];
beep();

print("\\Update0: Grabbing large file lists might take a while");
fList = getFileList(dir);
print("\\Update0: File list acquired");
if (fList.length>5000) beep();
nFiles = fList.length;

//remove non-image files from fList
for (i=0;i<nFiles;i++) {
	j = nFiles-i-1;
	if (endsWith(fList[j],imgType)==false) {
		fList = Array.deleteIndex(fList, j);
	}	
}
nFiles = fList.length;
exImgName = "";
checkType = false;
for (i=0;i<100;i++) {
	if (endsWith(fList[i], imgType)) {
		i = 100;
		exImgName =fList[i];
		print(exImgName);
	}
}

if (indexOf(exImgName,"_")>-1) {
	exParts = split(exImgName,"_");	
}	else {
	waitForUser("Warning!", "A "+imgType+" file was found with no underscores. /n This macro parses images assume that image name parts are separated by underscores.");	
}

nPrefixParts = exParts.length -3;
string0 = "[Well]_[Point]_[Time]";
for (i=0;i<nPrefixParts;i++){
	j= nPrefixParts-i-1;
	string0="[Part"+j+"]_"+string0;
}

//make an educated guess about different prefixes by collecting unique strings found prior to the Well ID of image names
uChannels = newArray();
for (n = 0; n < nFiles; n++) {
	imgParts = split(fList[n],"_");
	prefix = "";
	for (i=0;i<nPrefixParts;i++){
		if (i==0) {
			prefix = prefix+imgParts[i];
		}else{
			prefix = prefix+"_"+imgParts[i];
		}
	}
	if (uChannels.length==0) {
		uChannels=Array.concat(uChannels,prefix);	
	}else{
		chMatch = false;
		for(u=0;u<uChannels.length;u++){
			if (prefix==uChannels[u]){
				chMatch=true;
				u=uChannels.length;
			}
		}
		if (chMatch==false) {
			uChannels=Array.concat(uChannels,prefix);	
		}
	}
}

//Array.show("Likely channel names in fList", uChannels);
//waitForUser;

if (uChannels.length>1) { 
	ch2Default = uChannels[1];
}

if (uChannels.length>2) { 
	ch3Default = uChannels[2];
}

Dialog.create("List Incucyte Wells & Positions");
Dialog.addMessage("Images in this folder look like " + exImgName);
Dialog.addMessage("This should take the form " + string0);
//Dialog.addNumber("How many parts separated by an underscore do images names have before Well IDs?", nPrefixParts);
Dialog.addNumber("Number of image channels in the current folder",uChannels.length);
//Dialog.addNumber("Channels are described by the nth part of the file name, base 0",chPart);
Dialog.addChoice("Channel 1 name in filenames",uChannels,uChannels[0]);
if (uChannels.length>1) Dialog.addChoice("Channel 2 name in filenames (ignored if nChannels = 1) ",uChannels,ch2Default);
if (uChannels.length>2) Dialog.addChoice("Channel 3 name in filenames (ignored if nChannels = 1 or2)",uChannels,ch3Default);
Dialog.addString("list of images prefixes saved as [string]_[folder].csv",outName,20);
//Dialog.addString("Append Prefix to stacked images", "", 20);

Dialog.show();
//nPrefixParts = Dialog.getNumber();
nChannels = Dialog.getNumber();
//chPart = Dialog.getNumber();
chNames = newArray();
ch1Name = Dialog.getChoice();
if (uChannels.length>1) ch2Name = Dialog.getChoice();
if ((uChannels.length>2))ch3Name = Dialog.getChoice();

chNames = Array.concat(chNames,ch1Name);
if (nChannels>1) chNames = Array.concat(chNames,ch2Name);
if (nChannels==3) chNames = Array.concat(chNames,ch3Name);
outName = Dialog.getString();

//nChannels = chNames.length;


uPrefixes = newArray(); //list of unique image prefixes, including varied channel numbers

nFiles = fList.length; //updated with non-images removed

for (i=0;i<nFiles;i++) {
	
	fNameParts = split(fList[i], "_");
	prefix = "";
	for (p=0;p<fNameParts.length-1;p++) {
		if (p==0) prefix = prefix + fNameParts[p];
		if (p>0 ) prefix = prefix + "_"+ fNameParts[p];
	}

	pCaught = false;
	for (j=0;j<uPrefixes.length;j++) {
		if (prefix == uPrefixes[j]) pCaught=true;
	}
	if (pCaught==false) uPrefixes = Array.concat(uPrefixes,prefix);
}

print("\\Update0: Array of unique prefixes made. Contains " + uPrefixes.length+ " values");
//Array.print(uPrefixes);
//Array.show("uPrefixes",uPrefixes);


//if nChannels = 1, done, show list as table
uPrefixes = Array.sort(uPrefixes);

//new approach - given that name parts are just before time stamp, this name parts can be isolated to list imaging location
//add these to a table and add prefixes that contain the channel name where found
//loop through uPrefixes, grab last two parts add to table then add to channels column
points = newArray();
//temporary holder to be trimmed to final length of points
ch1Names = newArray(uPrefixes.length);
ch2Names = newArray(uPrefixes.length);
ch3Names = newArray(uPrefixes.length);


for(i=0;i<uPrefixes.length;i++){
	prefixParts = split(uPrefixes[i],"_");
	imgPoint = prefixParts[prefixParts.length-2]+"_"+prefixParts[prefixParts.length-1];
	pointMatch = false;
	matchIndex =points.length;
	currCh = -1;
	for(c=0;c<nChannels;c++) {
		if (indexOf(uPrefixes[i],chNames[c])!=-1) currCh =c;
	}
	
	if (points.length==0) {
		points[0]= imgPoint;
	} else {
		
		for (j=0;j<points.length;j++) {
			if (imgPoint==points[j]){
				pointMatch=true;
				matchIndex=j;
				j =points.length;
				
			}
		}
		if (pointMatch==false) {
			points = Array.concat(points,imgPoint);
		}
	}
	//assign current prefix to a list for each channel
	if (currCh == 0) ch1Names[matchIndex] = uPrefixes[i];
	if (currCh == 1) ch2Names[matchIndex] = uPrefixes[i];
	if (currCh == 2) ch3Names[matchIndex] = uPrefixes[i];
	
}
ch1Names = Array.trim(ch1Names,points.length);
ch2Names = Array.trim(ch2Names,points.length);
ch3Names = Array.trim(ch3Names,points.length);
//Array.show("List of imaged points",points, ch1Names, ch2Names, ch3Names);
//waitForUser("check list");

/*
So we now have rows of prefixes by imaging site (well_point)
Walk through list
if all channels match, add to row of results table.
if no match, add unmatched to a list of unmatch
*/

if (nChannels==1) {
	for(i=0;i<points.length;i++){
		//add points and prefixes to results table
		setResult("Point", i, points[i]);	
		setResult("Channel 1", i, ch1Names[i]);	
	}
}

unmatched = newArray();

if (nChannels>1) {

	for (i=0;i<points.length;i++) {
		channelsMatch = false;
		if ( (ch1Names[i]!="0")&&(ch2Names[i]!="0")) {
			if (nChannels==3) {
				if(ch3Names[i]!="0"){
					channelsMatch=true;
				} 
			}else {
				channelsMatch=true;
			}
		}
		if (channelsMatch==true) {
			setResult("Point", i, points[i]);	
			setResult("Channel 1",i, ch1Names[i]);	
			setResult("Channel 2",i, ch2Names[i]);	
			if (nChannels==3) 	setResult("Channel 3",i, ch3Names[i]);
		} else {
			if (ch1Names[i]!=0) unmatched = Array.concat(unmatched,ch1Names[i]);
			if (ch2Names[i]!=0) unmatched = Array.concat(unmatched,ch2Names[i]);
			if ((nChannels==3)&(ch3Names[i]!=0)) unmatched = Array.concat(unmatched,ch3Names[i]);
					
		}
	}

} //if nCHannels >1

nr = nResults;


outPath = dir+outName+"_"+dirName+".csv";
saveAs("Results", outPath);
print("Generation of base names of image stacks complete");
print("Image prefixes saved in "+outPath);

//save Mismatches

if (unmatched.length>0) {
	run("Clear Results");
	for (i = 0; i<unmatched.length;i++) {
		setResult("unMatchedPrefixes",i, unmatched[i]);
	}
	lonerPath = dir+"0_unmatchedImages_"+dirName+".csv";
	saveAs("Results", lonerPath);
	print("Unmatched images listed in "+lonerPath);
}




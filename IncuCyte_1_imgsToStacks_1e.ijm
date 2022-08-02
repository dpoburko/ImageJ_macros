/*
Written by Damon Poburko at Simon Fraser University, April 2022
This macro aims to generate multi-color, time-lapse image stacks from single images
exported from a Sartorius Incucyte

This macro assumes that you have created a .csv file that at the bare minimum has a column 
for each image channel in your dataset. 
Each row should show image name prefixes a given channel (e.g. plate001_ch1_wellA1_position02)

Version history:
v1d -
- save frames as frames rather than slices
*/
print("\\Clear");

version = "1e";

dir = getDirectory("Choose directory of Incucyte images");
dirOut = dir+"stacks"+File.separator;
if (!File.isDirectory(dirOut)) {
	dm = File.makeDirectory(dirOut);
}
print("\\Update0: getting file list");
fList = getFileList(dir);

fList2 = fList;
fLL = fList.length;
print("\\Update0: parsing file list for .csv index of image basenames");
for (f=0;f<fLL;f++) {
	showProgress(f/fLL);
	if (indexOf(fList[fLL-f-1],".csv")==-1) fList = Array.deleteIndex(fList, fLL-f-1);
}

Dialog.create("Select the file containing the prefixes to be merged");
Dialog.addChoice("select the .csv file", fList, fList[0]);
Dialog.addSlider("Number of channels to merge", 1, 3, 2);
Dialog.show();
csvFName = Dialog.getChoice();
nChannels = Dialog.getNumber();

colorChoices = newArray("Green","Red","Magenta","Grays");
colorsOut = newArray("Grays","Green","Red");

tp = dir+csvFName;
Table.open(tp);
th = Table.headings;
thList = split(th,"\t");
Array.print(thList);
th1 = "";
th2 = "";
th3 = "";

Dialog.createNonBlocking("Select Columns with paired image prefixes");
Dialog.addChoice("Channel 1 prefixes", thList, thList[thList.length-2]);
if (nChannels>1) Dialog.addChoice("Channel 2 prefixes", thList, thList[thList.length-1]);
if (nChannels>2) Dialog.addChoice("Channel 3 prefixes", thList, thList[thList.length-1]);
Dialog.addChoice("Channel 1 output color", colorChoices, colorChoices[0]);
if (nChannels>1) Dialog.addChoice("Channel 2 output color", colorChoices, colorChoices[1]);
if (nChannels>2) Dialog.addChoice("Channel 3 output color", colorChoices, colorChoices[2]);
Dialog.addCheckbox("Overwrite existing stacks", false);
Dialog.show();

th1 = Dialog.getChoice();
if (nChannels>1) th2 = Dialog.getChoice();
if (nChannels>2) th3 = Dialog.getChoice();
colorsOut[0] = Dialog.getChoice();
if (nChannels>1) colorsOut[1] = Dialog.getChoice();
if (nChannels>2) colorsOut[2] = Dialog.getChoice();
doOverwrite = Dialog.getCheckbox();


setBatchMode(true);

ch1Names = Table.getColumn(th1);
if (nChannels>1) ch2Names = Table.getColumn(th2);
if (nChannels>2) ch3Names = Table.getColumn(th3);

ch1FilesExist = newArray(ch1Names.length);
ch1FilesExist = Array.fill(ch1FilesExist, 0);
ch2FilesExist = ch1FilesExist;
ch3FilesExist = ch1FilesExist;

prefixesMatchFiles = false;
for (i=0;i<ch1Names.length;i++) {
	for (f=0;f<fList2.length;f++) {
		if ((indexOf(fList2[f],".tif")!=-1) && (indexOf(fList2[f],ch1Names[i])!=-1)) {
			ch1FilesExist[i] = 1;
			f=fList2.length;
		}
	}
	if (nChannels>1) {
		for (f=0;f<fList2.length;f++) {
			if ((indexOf(fList2[f],".tif")!=-1) && (indexOf(fList2[f],ch2Names[i])!=-1)) {
				ch2FilesExist[i] = 1;
				f=fList2.length;
			}
		}
	}
	if (nChannels>2) {
		for (f=0;f<fList2.length;f++) {
			if ((indexOf(fList2[f],".tif")!=-1) && (indexOf(fList2[f],ch3Names[i])!=-1)) {
				ch3FilesExist[i] = 1;
				f=fList2.length;
			}
		}
	}
}

Array.getStatistics(ch1FilesExist, min1, max1);
Array.getStatistics(ch2FilesExist, min2, max2);
Array.getStatistics(ch3FilesExist, min3, max3);

if (nChannels==1) {prefixesMatchFiles = true;}
if (nChannels==2) {
	if ( (min1==1) && (min2==1) ) {
		prefixesMatchFiles = true;
	}
}
if (nChannels==3) {
	if ( (min1==1) && (min2==1) && (min3==1) ) {
		prefixesMatchFiles = true;
	}
}

if (prefixesMatchFiles == false) {
	badPrefixes = newArray();
	for(i=0;i<ch1FilesExist.length;i++) {
		if 	(ch1FilesExist[i]==0) badPrefixes = Array.concat(badPrefixes,ch1Names[i]);	
		if 	((nChannels>1) && (ch2FilesExist[i]==0))  badPrefixes = Array.concat(badPrefixes,ch2Names[i]);	
		if 	((nChannels>2) && (ch3FilesExist[i]==0))  badPrefixes = Array.concat(badPrefixes,ch3Names[i]);	
	}
	Array.show("Prefixes don't match images",badPrefixes);
	exit("At least one of your prefixes did not have matched images \n See the array list");	
}

if (nChannels == 1 ) Array.show("Image prefixe",ch1Names);
if (nChannels == 2 ) Array.show("Image pairs prefixed",ch1Names,ch2Names);
if (nChannels == 3 ) Array.show("Image trios prefixed",ch1Names,ch2Names,ch3Names);

tStart = getTime();

for (i=0;i<ch1Names.length; i++) {

	if (i==0) print("\\Update1: time to open "+ch1Names[i]+": ");
	if (nChannels == 1  ) {
		print("\\Update0: working on "+ch1Names[i]);
		prefixOut = replace(ch1Names[i], "Ch1_", "");
	}
	if (nChannels >1  ) {
		if (i==0) print("\\Update2: time to open "+ch2Names[i]+": ");
		print("\\Update0: working on "+ch1Names[i]+" and "+ch2Names[i]);
		prefixOut = replace(ch1Names[i], "Ch1_", th1+"-"+th2+"_");
	}
	if (nChannels >2  ) {
		if (i==0) print("\\Update3: time to open "+ch3Names[i]+": ");
		print("\\Update0: working on "+ch1Names[i]+" and "+ch2Names[i]+" and "+ch3Names[i]);
		prefixOut = replace(ch1Names[i], "Ch1_", th1+"-"+th2+"-"+th3+"_");
	}

	pathOut = dirOut+prefixOut+".tif";
	
	//%%%% check if file already exists and check option to over-write or skip
	
	
	if ( (File.exists(pathOut)==1) && (doOverwrite==false)  ) {
		//skip current image stack
		print("\\Update4: "+prefixOut+".tif exists. Moving to next stack.");
	} else {	

		t0 = getTime();
	
		//print("Image Sequence... dir="+dir+" filter="+ch1Names[i]+" sort");	
		//run("Image Sequence...", "dir="+dir+" filter="+ch1Names[i]+" sort");
		File.openSequence(dir, " filter="+ch1Names[i]);
	
		i1Bytes = getValue("image.size");
		rename(ch1Names[i]);
	
		run(colorsOut[0]);
		Stack.getDimensions(width1, height1, channels1, slices1, frames1);
		t1 = getTime();
		MBps1 = (i1Bytes/1000000)/((t1-t0)/1000);
		print("\\Update1: time to open "+ch1Names[i]+": "+d2s(((t1-t0)/60000),1)+" min at " +MBps1+ " MB/s");
		if (bitDepth() == 8) {
			setMinAndMax(0, 255);
			run("16-bit");
		}
		if (bitDepth() == 32) {
			setMinAndMax(0, 16383);
			run("16-bit");
		}
		if (nChannels>1) {
			//run("Image Sequence...", "dir="+dir+" filter="+ch2Names[i]+" sort");
			File.openSequence(dir, " filter="+ch2Names[i]);
			i2Bytes = getValue("image.size");
			rename(ch2Names[i]);
			run(colorsOut[1]);
			Stack.getDimensions(width2, height2, channels2, slices2, frames2);
			//this is a temp fix and a lazy way to not have to re-write the match checks below for 2 vs 3 channels
			Stack.getDimensions(width3, height3, channels3, slices3, frames3); 
			t2 = getTime();
			MBps2 = (i2Bytes/1000000)/((t2-t1)/1000);
			print("\\Update2: time to open "+ch2Names[i]+": "+d2s(((t2-t1)/60000),1)+" min at " +MBps2+ " MB/s");
			if (bitDepth() == 8) {
				setMinAndMax(0, 255);
				run("16-bit");
			}
			if (bitDepth() == 32) {
				setMinAndMax(0, 16383);
				run("16-bit");
			}
		}
		if (nChannels > 2) {
			//run("Image Sequence...", "dir="+dir+" filter="+ch3Names[i]+" sort");
			File.openSequence(dir, " filter="+ch3Names[i]);
			i3Bytes = getValue("image.size");
			rename(ch3Names[i]);
			run(colorsOut[2]);
			Stack.getDimensions(width3, height3, channels3, slices3, frames3);
			t2b = getTime();
			MBps3 = (i3Bytes/1000000)/((t2b-t2)/1000);
			print("\\Update3: time to open "+ch3Names[i]+": "+d2s(((t2b-t2)/60000),1)+" min at " +MBps3+ " MB/s");
			if (bitDepth() == 8) {
				setMinAndMax(0, 255);
				run("16-bit");
			}
			if (bitDepth() == 32) {
				setMinAndMax(0, 16383);
				run("16-bit");
			}
		}
		
		failmsg ="Dimension mismatch:";
		dimsMatch = true;
	
		if (nChannels>1) {
			if ( (width1!=width2) || (width2!=width3) || (width1!=width3))  {
					failmsg = failmsg+ " width";
					dimsMatch = false;
			} 
			if ( (height1!=height2) || (height2!=height3) || (height1!=height3)) {
					failmsg = failmsg+ " height";
					dimsMatch = false;
			} 
			if( (channels1!=channels2) || (channels2!=channels3) || (channels1!=channels3)){
					failmsg = failmsg+ " channels";
					dimsMatch = false;
			} 
			if ( (slices1!=slices2) || (slices2!=slices3) || (slices1!=slices3)) {
					failmsg = failmsg+ " slices";
					dimsMatch = false;
			} 
			if ( (frames1!=frames2) || (frames2!=frames3) || (frames1!=frames3)) {
					failmsg = failmsg+ " frames";
					dimsMatch = false;
			} 
		}
		if (dimsMatch == false) {
			close(ch1Names[i]);	
			close(ch2Names[i]);	
			if (nChannels==3) close(ch3Names[i]);	
			print("Pairing "+i+" failed. "+failmsg);
		} else {
			if (nChannels==2) run("Merge Channels...", "c1="+ch1Names[i]+" c2="+ch2Names[i]+" create");
			if (nChannels==3) run("Merge Channels...", "c1="+ch1Names[i]+" c2="+ch2Names[i]+" c3="+ch3Names[i]+" create");
			rename(prefixOut);
			
			i4Bytes = getValue("image.size");
	
			t3a = getTime(); 
			
			//*** Need to add step to swap frames and slices ***
	
			//getFinal dimensions, swap slices and frames if needed
			Stack.getDimensions(width, height, channels, slicesFinal, framesFinal);
			if ((framesFinal == 1)&(slicesFinal>1)) {
				run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			}
			
			saveAs("Tiff", pathOut);
			close();
			
			t3b = getTime();
			MBps4 = (i4Bytes/1000000)/((t3b-t3a)/1000);
			print("\\Update4: time to save "+pathOut+": "+d2s(((t3b-t3a)/60000),1)+" min at " +MBps4+ " MB/s");
			tRemaining = ((ch1Names.length-1-i)*(t3b-t0)/60000);
			print("\\Update5: time left for remaining "+(ch1Names.length-1-i)+" stacks estimated at: "+d2s(tRemaining,1)+" minutes");
		}
	}
	//%%%% check if file already exists and check option to over-write or skip
	
}

tEnd = getTime();
tTotal = (tEnd - tStart)/60000;
print("\\Update4: Done making  "+ch1Names.length+" stacks in "+d2s(tTotal,0)+" minutes");

run("Close All");

setBatchMode("exit and display");

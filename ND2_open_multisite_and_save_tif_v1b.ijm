msg = "1. Remember to set Bioformats configuration for ND2 files to Windowless \n2. If some ND2 files are not opening all dimensions try \n    Bioformats importer : set 'Open all series' to ON and 'Concatenate series when compatible' to ON ";


//waitForUser("Usage tip", msg);
// ND acquisition multi-point images need ImageJ with Bioformts set to windowless
// Well plate "Jobs" get read as multiple series with Bioformats opening as hyperstack, all series in Fiji




version = 1.0;
Dialog.create("Open multisite ND2 and save as tiffsv" + version);

Dialog.addMessage(msg);
Dialog.addMessage("WARNING: Run this macro in Fiji with Bioformats set to 'Open all series', windowless");
Dialog.addCheckbox("batch Process a folder?", true); 
//Dialog.addNumber("scale image dimensions by... [-1=off]",-1);
Dialog.show();
doBatch = Dialog.getCheckbox;
//scaleFactor = Dialog.getNumber;
scaleFactor = -1;

if (doBatch == false) {
	selectWindow(img0);
	splitND2(img0);
}

if (doBatch == true) {
	dir = getDirectory("Choose a Directory ");
	mainList = getFileList(dir);

	imgList = newArray(mainList.length);
	nImgs = 0;
	close("*");

	for ( i =0; i< mainList.length; i++) {
		if ( endsWith(toLowerCase(mainList[i]), ".nd2") == true) {
			imgList[nImgs] = mainList[i];
					nImgs++;
		}
	}

	imgList = Array.trim(imgList,nImgs);
	//Array.print(imgList);
	print("\\Update0: splitting "+nImgs+" ND2 files from array len: " + imgList.length);	
	//new new output folder
	saveDir = dir + File.separator + "multi-well_Tiffs";
	if (File.exists(saveDir)==false) {
		md = File.makeDirectory(saveDir);
	}

	time0 = getTime();
	
	for (a=0; a<imgList.length; a++) {
		print("\\Update1: " + dir + imgList[a]);
		print("\\Update2: opening image " + (a + 1 ) + " of " + imgList.length);
		open(dir + imgList[a]);
		nImgsOpen = nImages;
		print("\\Update3: " + nImgsOpen + " found");
		oImgName = getTitle();
		imgBaseName = substring(oImgName, 0, indexOf(oImgName,"(series ") + 8 );
		openImgList = newArray(nImages);
		for (c=1; c<=nImages; c++) {
			selectImage(c);
			openImgList[c-1] = getTitle();
			print("\\Update4: "+ openImgList[c-1]);
		}
		Array.sort(openImgList);
		
		for (b=0; b<openImgList.length; b++) {
			selectImage(openImgList[b]);
			currImgName = imgBaseName + b + ")";
			currImgIndex = substring(openImgList[b], lastIndexOf(openImgList[b]," ")+1,lastIndexOf(openImgList[b],")"));
			print("\\Update6: looking for - b: " + b + " " + openImgList[b]);
			imgTitle = getTitle();
			oName = substring(imgTitle,0,indexOf(imgTitle,".nd2"));
			newName = oName + "_S" + IJ.pad(parseInt(currImgIndex),3);
			print("\\Update5: saving image " + newName);
			saveAs("Tiff", saveDir + File.separator + newName );
		}
		close("*");
		time1 = getTime();
		timeLeft =  60000*(imgList.length - a)*(time1 - time0) / (a+1);
		print("\\Update7: time remaining" + timeLeft + " minutes");

	}
}

function pad(value,places) {
	if (value == 0) valuePlaces = 1;
	if (value != 0) valuePlaces = 1 + floor(log(value)/log(10));
	paddingZeros = "";
	for (p=0; p<(places-valuePlaces);p++) {
		paddingZeros = paddingZeros + "0";
	}
	return paddingZeros + value;
}
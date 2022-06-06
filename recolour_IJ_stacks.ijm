if (nImages!=0) {
	Stack.getDimensions(width, height, channels, slices, frames);
	Stack.getPosition(channel, slice, frame);
}
if (nImages==0) {
	channels =4;
	channel = 1;
	slice = 1;
	frame = 1;
}
colorArray = newArray("Blue","Red","Green","Magenta","Cyan","Grays");


        version = 1.01;
        Dialog.create("Recolour Images v"+version);
		Dialog.setInsets(10, 15, 0);
    	
    	Dialog.addChoice("select colour for channel 1" , colorArray, call("ij.Prefs.get", "dialogDefaults.ch1Color", "Blue"));
    	if (channels>1) Dialog.addChoice("select colour for channel 2", colorArray, call("ij.Prefs.get", "dialogDefaults.ch2Color", "Green"));
    	if (channels>2) Dialog.addChoice("select colour for channel 3", colorArray, call("ij.Prefs.get", "dialogDefaults.ch3Color", "Red"));
    	if (channels>3) Dialog.addChoice("select colour for channel 4", colorArray, call("ij.Prefs.get", "dialogDefaults.ch4Color", "Magenta"));
    	Dialog.addCheckbox("overwrite existing file",call("ij.Prefs.get", "dialogDefaults.doOverwrite", true));
    	Dialog.addCheckbox("process all images in folder",false);
  
	// ====== retrieve values ============================
		Dialog.show();
		ch1Color = Dialog.getChoice;
			call("ij.Prefs.set", "dialogDefaults.ch1Color", ch1Color);
		if (channels>1) { 
			ch2Color = Dialog.getChoice; 			call("ij.Prefs.set", "dialogDefaults.ch2Color", ch2Color);
		}
		if (channels>2) { 
			ch3Color = Dialog.getChoice; 			call("ij.Prefs.set", "dialogDefaults.ch3Color", ch3Color);
		}
		if (channels>3) { 
			ch4Color = Dialog.getChoice; 			call("ij.Prefs.set", "dialogDefaults.ch4Color", ch4Color);
		}
		doOverwrite = Dialog.getCheckbox();				call("ij.Prefs.set", "dialogDefaults.doOverwrite", doOverwrite);
		doBatch = Dialog.getCheckbox();

if (doBatch == true) {
	
	dir = getDirectory("Choose a Directory ");
	setBatchMode(true);
	mainList = getFileList(dir);
	mainList = Array.sort(mainList);
	imgList = newArray(mainList.length);
	nImgs = 0;
	searchTerm = "decon";
	// create a list of images to analyze from current folder
	nTotal = 0;
	print("\\Clear");
	for (i=0; i<mainList.length;i++) {
		print("Update0: working on file " + i + " of " + mainList.length + " " +mainList[i]);
		if ( (endsWith(toUpperCase(mainList[i]),".TIF")==true) || (endsWith(toUpperCase(mainList[i]),".TIFF")==true)|| (endsWith(toUpperCase(mainList[i]),".ND2")==true) ) {
			open(dir+mainList[i]);
			if (channels>=2) {
				Stack.setPosition(1, slice, frame);
				run(ch1Color);
				run("Enhance Contrast", "saturated=0.35");
				Stack.setPosition(2, slice, frame);
				run(ch2Color);
				run("Enhance Contrast", "saturated=0.35");
				if (channels==4) {
					Stack.setPosition(3, slice, frame);
					run(ch3Color);
					run("Enhance Contrast", "saturated=0.35");
				}
				if (channels==4) {
					Stack.setPosition(4, slice, frame);
					run(ch4Color);
					run("Enhance Contrast", "saturated=0.35");
				}
			}
			Stack.setPosition(1, slice, frame);
			Stack.setDisplayMode("composite");
			run("Save");
			close();
		}
	
	}
	print(nTotal + " ROIs total");
	setBatchMode("exit and display");
}
if (doBatch == false) {
	Stack.setPosition(1, slice, frame);
		run("Blue");
		run("Enhance Contrast", "saturated=0.35");
	if (channels>=3) {
		Stack.setPosition(1, slice, frame);
		run(ch1Color);
		run("Enhance Contrast", "saturated=0.35");
		Stack.setPosition(2, slice, frame);
		run(ch2Color);
		run("Enhance Contrast", "saturated=0.35");
		Stack.setPosition(3, slice, frame);
		run(ch3Color);
		run("Enhance Contrast", "saturated=0.35");
		if (channels==4) {
			Stack.setPosition(4, slice, frame);
			run(ch4Color);
			run("Enhance Contrast", "saturated=0.35");
		}
	}
	Stack.setPosition(channel, slice, frame);
	Stack.setDisplayMode("composite");
	if (doOverwrite == true) run("Save");
}
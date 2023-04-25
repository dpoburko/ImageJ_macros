/*
 * Written by Damon Poburko, August 2022.
 * A simple macro to break an image to m x n subregions
 */


m = 2;
n = 2;
padSize = maxOf(lengthOf(""+m+""),lengthOf(""+n+""));
imgTypes = newArray(".tif", ".jpg",".nd2",".stk");
filterByString ="";

m2 = parseInt( call("ij.Prefs.get", "dialogDefaults.m",m));
print(m2+1);

Dialog.create("Segment images");
Dialog.addMessage("Break images in folder into subregions on a grid of m columns x n rows. ");

Dialog.addNumber("Number of columns (m)",  parseInt( call("ij.Prefs.get", "dialogDefaults.m", ""+m+"")));
Dialog.addNumber("Number of rows (n)",  parseInt( call("ij.Prefs.get", "dialogDefaults.n", ""+n+"")));
Dialog.addChoice("File type to align", imgTypes, call("ij.Prefs.get", "dialogDefaults.fType", imgTypes[0]));
Dialog.addMessage("To analyze a subset of images, provide unique strings in file names to analyze");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Leave blank for no filtering or provide a comma, space, or tab-separated list of strings");
Dialog.addString("Filter String", call("ij.Prefs.get", "dialogDefaults.filterByString", filterByString), 40);
Dialog.addMessage("After this dialog, select the fold of images to analyze");
Dialog.addString("Name of output with in the image folder","subdivided");
Dialog.show();

m = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.m", m);
n = Dialog.getNumber();
	call("ij.Prefs.set", "dialogDefaults.n", n);
fType = Dialog.getChoice();
	call("ij.Prefs.set", "dialogDefaults.fType", fType);
filterByString = Dialog.getString();
	call("ij.Prefs.set", "dialogDefaults.filterByString", filterByString);
outFolder = Dialog.getString();

setBatchMode(true);
print("\\Clear");

//Select image directory
dir = getDirectory("Choose folder with images");
fList = getFileList(dir);
fList2 = newArray();

outPath = dir+outFolder+File.separator;

if (File.exists(outPath)) {
	print("\\Update0: Output folder exists");
} else {
	File.makeDirectory(outPath);
	print("\\Update0: Created output folder "+ outPath);
}

//shorten fList to images
fList2 = newArray();
for (i = 0; i < fList.length; i++) {
	if ( fTypeCheck(fList[i])==true ) {
			fList2 = Array.concat(fList2,fList[i]);
	}			
}
print("\\Update1: "+fList2.length+ " " +fType+ " images found");
fList=fList2;
wait(1500);

if (filterByString!="") {
	
	print("\\Update1: filtering image list for files containing filter strong");
	wait(200);
	filterByString = replace(filterByString, " ", "\t");
	filterByString = replace(filterByString, ",", "\t");
	filterStrings = split(filterByString,"\t");
	//print("filter " + fList.length + " files by:");
	Array.print(filterStrings);
	
	fList2 = newArray();

	for (i = 0; i < fList.length; i++) {
		for (j = 0; j < filterStrings.length; j++) {
			//now filter by file name
			if  (indexOf(fList[i],filterStrings[j])!=-1  ) {
					fList2 = Array.concat(fList2,fList[i]);
			}
		}				
	}
	if (fList2.length>0) {
		fList=fList2;
		//Array.print(fList2);
		print("\\Update1: Found "+fList.length+ " images meeting filter criteria");
		wait(1000);
		
	} else {
		exit("Did not find any images matching your filters");
	}
}

tf0 = getTime();
nImgs = fList.length;
imagesDone=0;

for(f=0;f<nImgs;f++){
	
	
	pathIn = dir+File.separator+ fList[f];
	print("\\Update0: opening "+ fList[f]);
	open(pathIn);
	getDimensions(width, height, channels, slices, frames);
	img0  = getTitle();
	imgBase = substring(img0, 0, lastIndexOf(img0, "."));
	
	ti0 = getTime();
	nTiles = m*n;
	tilesDone = 0;
	for(i=0;i<n;i++) {
		y = i*Math.floor(height/n);
		
		for(j=0;j<m;j++) {
			
			x = j*Math.floor(width/m);	
			selectWindow(img0);
			img1 = imgBase+"_SR("+IJ.pad(j,padSize)+"-"+IJ.pad(i,padSize)+")";
			print("\\Update1: saving "+ img1);
			makeRectangle(x, y, Math.floor(width/m), Math.floor(height/n));
			run("Duplicate...", "title="+img1+" duplicate");
			saveAs(".tif", outPath+ File.separator + img1 );
			close();
			selectWindow(img0);
			run("Select None");
			tilesDone++;
			ti1 = getTime();
			print("\\Update2: time to finish curr image: "+ d2s( (nTiles-tilesDone)*(ti1-ti0)/(tilesDone*60000)      ,2)+" min");
		}
	}
	
	close("*");
	imagesDone++;
	tf1= getTime();
	print("\\Update3: time to finish remaining images: "+ d2s( (nImgs-imagesDone)*(tf1-tf0)/(imagesDone*60000)      ,2)+" min");
}
print("\\Update4: Done subdividing images");
setBatchMode("exit and display");

function fTypeCheck (file) {
	fTypeOK = false;
	fTypes = newArray(".tif",".tiff",".jpg",".png",".bmp");
	for (j=0;j<fTypes.length;j++) {
		if (endsWith(file,fTypes[j])==true) {
			fTypeOK = true;
			j=fTypes.length;
		}
	}
	return fTypeOK;
}
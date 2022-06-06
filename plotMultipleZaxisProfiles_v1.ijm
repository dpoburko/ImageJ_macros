img0 = getTitle();
img1 = replace(img0,"Result of ", "") +"2";
nr = roiManager("count");
Stack.getDimensions(width, height, channels, slices, frames);

//Brewer 2.0 pallets https://colorbrewer2.org/#type=sequential&scheme=Reds&n=9

YlOrRd = newArray("#ffffcc","#ffeda0","#fed976","#feb24c","#fd8d3c","#fc4e2a","#e31a1c","#bd0026","#800026");
YlGnBu = newArray("#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58");
RdPu = newArray("#fff7f3","#fde0dd","#fcc5c0","#fa9fb5","#f768a1","#dd3497","#ae017e","#7a0177","#49006a");
PuRd = newArray("#f7f4f9","#e7e1ef","#d4b9da","#c994c7","#df65b0","#e7298a","#ce1256","#980043","#67001f");
BuGn = newArray("#f7fcfd","#e5f5f9","#ccece6","#99d8c9","#66c2a4","#41ae76","#238b45","#006d2c","#00441b");
BuPu = newArray("#f7fcfd","#e0ecf4","#bfd3e6","#9ebcda","#8c96c6","#8c6bb1","#88419d","#810f7c","#4d004b");
GnBu = newArray("#f7fcf0","#e0f3db","#ccebc5","#a8ddb5","#7bccc4","#4eb3d3","#2b8cbe","#0868ac","#084081");
Blues = newArray("#f7fbff","#deebf7","#c6dbef","#9ecae1","#6baed6","#4292c6","#2171b5","#08519c","#08306b");
Greens = newArray("#f7fcf5","#e5f5e0","#c7e9c0","#a1d99b","#74c476","#41ab5d","#238b45","#006d2c","#00441b");
Greys = newArray("#ffffff","#f0f0f0","#d9d9d9","#bdbdbd","#969696","#737373","#525252","#252525","#000000");
Oranges = newArray("#fff5eb","#fee6ce","#fdd0a2","#fdae6b","#fd8d3c","#f16913","#d94801","#a63603","#7f2704");
Purples = newArray("#fcfbfd","#efedf5","#dadaeb","#bcbddc","#9e9ac8","#807dba","#6a51a3","#54278f","#3f007d");
Reds = newArray("#fff5f0","#fee0d2","#fcbba1","#fc9272","#fb6a4a","#ef3b2c","#cb181d","#a50f15","#67000d");

//diverging
BrBG = newArray("#8c510a","#bf812d","#dfc27d","#f6e8c3","#f5f5f5","#c7eae5","#80cdc1","#35978f","#01665e");

allBrewer = Array.concat(YlOrRd,YlGnBu,RdPu,PuRd,BuGn,BuPu,GnBu,Blues,Greens,Greys,Oranges, Purples,Reds);

pallets = newArray("YlOrRd","YlGnBu","RdPu","PuRd","BuGn","BuPu","GnBu","Blues","Greens","Greys","Oranges", "Purples","Reds","All");

//collect pallets preferences from past run
palletsPrefs = call("ij.Prefs.get", "dialogDefaults.palletPrefs","none");
bgDefault = call("ij.Prefs.get", "dialogDefaults.bkgdClr","white");

if (palletsPrefs!="none") {
	palletsDefaults	= newArray();
	for (i=0;i<lengthOf(palletsPrefs);i++) {
	palletsDefaults	= Array.concat(palletsDefaults,parseInt(substring(palletsPrefs, i, i+1)));
	}
} else {
	palletsDefaults = newArray(pallets.length);
}


// from https://www.google.com/search?q=hex+color+picker&rlz=1C1ONGR_enCA932CA932&oq=hex+color+picker&aqs=chrome.0.69i59j0j0i395l8.2134j1j9&sourceid=chrome&ie=UTF-8
//palletsDefaults = newArray(pallets.length);
bkgd = newArray("white","lightGray","gray","darkGray","black");
palletsChoice = newArray(pallets.length);
c = 0;
palletsPrefs = "";

Dialog.create("multiPlotZaxisProfiles");
//Dialog.addChoice("select line colors from Brewer pallets", pallets, "RdPu");
Dialog.addCheckboxGroup(5, 3, pallets, palletsDefaults);
Dialog.addChoice("background color", bkgd, call("ij.Prefs.get", "dialogDefaults.clrBkgd","white"));
Dialog.addNumber("line thickness", parseInt(call("ij.Prefs.get", "dialogDefaults.lineWidth","2")) );
Dialog.addCheckbox("normalize each line from min <> max", call("ij.Prefs.get", "dialogDefaults.normalize",false));
Dialog.show();
//Collect Dialog selections
for (i=0;i<pallets.length;i++) {
	tf = Dialog.getCheckbox();
	palletsChoice[i] = tf;
	palletsPrefs = palletsPrefs+tf;
}
clrBkgd = Dialog.getChoice();
lineWidth = Dialog.getNumber();
normalize = Dialog.getCheckbox();
	call("ij.Prefs.set", "dialogDefaults.palletPrefs",palletsPrefs);
	call("ij.Prefs.set", "dialogDefaults.clrBkgd",clrBkgd);
	call("ij.Prefs.set", "dialogDefaults.lineWidth",lineWidth);
	call("ij.Prefs.set", "dialogDefaults.normalize",normalize);

//parse pallet choices
pChoice = 0;
colors = newArray();
//Array.show("palletsChoice", palletsChoice);
for (i=0;i<pallets.length;i++) {
	if (palletsChoice[i] == true) {
		pChoice = i;
		theseColors = Array.slice(allBrewer,i*9,(i*9)+8);
		colors = Array.concat(colors,theseColors);
	}
}
if (palletsChoice[palletsChoice.length-1] == true) colors = allBrewer;
//to select an array of colors, it looks like I would need to concat all color palettes and select a subset of values based on an aray of palette nams
//Array.show("colors",colors);

selectWindow(img0);
run("Duplicate...", "title="+img1+" duplicate");
setBatchMode("hide");
ymax = 0;

legendTxt = "";
for (i=0; i<nr; i++) {
	roiManager("select", i);
	legendTxt = legendTxt + Roi.getName +"\n";
}

// collect data from ROI manager and create plots
for (i=0; i<nr; i++) {
	selectWindow(img1);
	if (c==colors.length) c=0;
	roiManager("select", i);
	Roi.setStrokeColor(colors[c]);
	run("Plot Z-axis Profile");
	Plot.getValues(xpoints, ypoints);
	Array.getStatistics(ypoints, min, max, mean, stdDev);
	if (normalize==true) {
		for (j=0;j<ypoints.length;j++) {
			ypoints[j] = (ypoints[j]-min)/(max-min);
		}
	}
	if (i == 0) ymin = min;
	if (max > ymax) ymax = max;
	if (min < ymin) ymin = min;
	close();
	
	if (i==0) {
		if (normalize==true) {
			pnsuffix = ".normalized";
			yAxLbl = "(Y-Ymin)/(Ymax-Ymin)";
		} else {
			pnsuffix = ".raw";
			yAxLbl = "RFU";
		}
		 
		Plot.create(""+img1+pnsuffix, "frame", yAxLbl, xpoints, ypoints); 	
		Plot.setLineWidth(lineWidth);
		Plot.setBackgroundColor(clrBkgd);
		Plot.setColor(colors[c]);

	}
	if (i>0) {
		
		Plot.setColor(colors[c]);
		Plot.add("line", xpoints, ypoints); 	
		c = c+1;
		
	}
	Plot.getLimits(xMin, xMax, yMin, yMaxOld);
	if (normalize==false) Plot.setLimits(xMin, xMax, ymin, ymax);
	if (normalize==true) Plot.setLimits(xMin, xMax, -0.05, 1.05);
}
Plot.setStyle(0, ""+colors[0]+",none,"+lineWidth+",Line");
Plot.setLegend(legendTxt, "Auto Transparent");	
//Plot.setLegend(legendTxt, "Auto");	
Plot.show();

close(img1);
setBatchMode("exit and display");

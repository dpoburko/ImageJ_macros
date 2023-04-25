/*
*  Created by Damon Poburko, ca. 2015 Department of Biomedical Physiology & Kinesiology, Simon Fraser University, Burnaby, Canada
*  Feel free to use and distribute this macro as suits your needs. Please acknowledge Damon Poburko, Simon Fraser University in any published works that use this macro
*  
*  This macro was written to plot line profiles on ImageJ plots
*  It will send intensity metrics of a line to a results table.
*  As a bonus, the correlation coefficient (r^2) of all pairs of plotted channel profiles are written to the results table. 
*/


requires("1.42l");
print("\\Clear");                     //clear log
version = "1a";


//================================================================================================================

if (selectionType==-1)
	exit("Area selection required");
run("Set Measurements...", "area mean min centroid shape redirect=None decimal=3");

imageName = getTitle();
baseName = imageName;            
selectWindow(baseName);
roiName = "";
if (isOpen("ROI Manager")) {
	if (roiManager("index")!= -1) {
		roiName = ":"+Roi.getName;
	}
}
	outName = imageName+roiName+"_lineProfile";


Stack.getDimensions(width, height, channels, slices, frames);
nChannels = channels;
getLine(x1, y1, x2, y2, lineWidth);
print("\\Clear");
print("channels: " +channels + "");
 

Stack.setChannel(1);
profile1=getProfile();
Array.getStatistics(profile1, min1, max1, mean1, stdDev);
Array.print(profile1);
LUT1 = guessLUT();

selectWindow(baseName);
Stack.setChannel(2);
profile2=getProfile();
Array.getStatistics(profile2, min2, max2, mean2, stdDev);
Array.print(profile1);
LUT2 = guessLUT();
profilesMax = maxOf(max1,max2);

selectWindow(baseName);
if (nChannels >= 3) {
	selectWindow(baseName);
	Stack.setChannel(3);
	profile3=getProfile();
	Array.getStatistics(profile3, min3, max3, mean3, stdDev);
	LUT3 = guessLUT();
	profilesMax = maxOf(max3,profilesMax);
}
if (nChannels >= 4) {
	selectWindow(baseName);
	Stack.setChannel(4);
	profile4=getProfile();
	Array.getStatistics(profile4, min4, max4, mean4, stdDev);
	LUT4 = guessLUT();
	profilesMax = maxOf(max4,profilesMax);
}
if (nChannels >= 5) {
	selectWindow(baseName);
	Stack.setChannel(5);
	profile5=getProfile();
	Array.getStatistics(profile5, min5, max5, mean5, stdDev);
	LUT5 = guessLUT();
	profilesMax = maxOf(max5,profilesMax);
}


 
colorArray = newArray("red","green","blue","magenta","black","yellow","cyan","none");

Dialog.create("RGB profiles");

	Dialog.addNumber("rolling ball size (pixels, -1 = none)", parseInt(call("ij.Prefs.get", "dialogDefaults.ballSize", "-1")));
	Dialog.addNumber("set Y Max (0 = autoscale,-1 = normalize)", parseInt(call("ij.Prefs.get", "dialogDefaults.yMax", "-1")));
	Dialog.addNumber("plot width (pixels))", parseInt(call("ij.Prefs.get", "dialogDefaults.plotWidth", "720")));
	Dialog.addNumber("plot height (pixels))", parseInt(call("ij.Prefs.get", "dialogDefaults.plotHeight", "256")));
	Dialog.addChoice("C1 color (cannot be 'None')",colorArray,LUT1);
	Dialog.addChoice("C2 color (cannot be 'None')",colorArray,LUT2);
	if (nChannels>=3) Dialog.addChoice("C3 color",colorArray,LUT3);
	if (nChannels>=4) Dialog.addChoice("C4 color",colorArray,LUT4);
	if (nChannels>=5) Dialog.addChoice("C5 color",colorArray,LUT5);
	Dialog.addCheckbox("hide plot window",call("ij.Prefs.get", "dialogDefaults.hidePlot", false) );
	Dialog.show();
  	//----------------------------------------------------------------------------------------

	ballSize = Dialog.getNumber();
		call("ij.Prefs.set", "dialogDefaults.ballSize", ballSize);
	yMax = Dialog.getNumber();
		call("ij.Prefs.set", "dialogDefaults.yMax", yMax);
	plotWidth = Dialog.getNumber();
		call("ij.Prefs.set", "dialogDefaults.plotWidth", plotWidth);
	plotHeight = Dialog.getNumber();
		call("ij.Prefs.set", "dialogDefaults.plotHeight", plotHeight);
	c1color = Dialog.getChoice();
	c2color = Dialog.getChoice();
	c3color = "none";
	c4color = "none";
	c5color = "none";
	if (nChannels>=3) c3color = Dialog.getChoice();
	if (nChannels>=4) c4color = Dialog.getChoice();
	if (nChannels==5) c5color = Dialog.getChoice();
	hidePlot = Dialog.getCheckbox();
		call("ij.Prefs.set", "dialogDefaults.hidePlot", hidePlot);
	print("hidePlot " + hidePlot);

//setBatchMode(true);

	if (ballSize >0) run("Subtract Background...", "rolling="+ballSize+"");
	print(yMax);
	plotMax = profilesMax;
	setMax = "maximum="+ plotMax + " fixed";
	if (yMax == 0 ) {
		setMax = "maximum="+ 0;
	}
	if (yMax == -1 ) {
		setMax = "maximum="+ 100 + " fixed";
		plotMax = 100;
	}
	selectWindow(baseName);

	if (yMax == -1 ) {
		print("data normalized");
		for (i=0; i<profile1.length; i++) {
			profile1[i] = 100*profile1[i]/max1;
		}
		for (i=0; i<profile1.length; i++) {
			profile2[i] = 100*profile2[i]/max2;
		}
		if (c3color != "none") {
			for (i=0; i<profile1.length; i++) {
				profile3[i] = 100*profile3[i]/max3;
			}
		}
		if (c4color != "none") {
			for (i=0; i<profile1.length; i++) {
				profile4[i] = 100*profile4[i]/max4;
			}
		}
		if (c5color != "none") {
			for (i=0; i<profile1.length; i++) {
				profile5[i] = 100*profile5[i]/max5;
			}
		}		
	}

	xValues = newArray(profile1.length);
	for (j=0; j<xValues.length; j++) {
		xValues[j] = j+1;
	}

	plotColors = newArray("red","green","blue");
	if (yMax>-1) Plot.create(outName,"pixels", "RFU", xValues, profile1);
	if (yMax==-1) Plot.create(outName,"pixels", "% max", xValues, profile1);

	print("yMax: " + yMax); 
	Plot.setLimits(0, xValues[j-1], 0, plotMax);
	chNumber = 1;
	
	if (c1color != "none") {
		Stack.setChannel(1);
		Plot.setColor(c1color);
		Plot.add("line",xValues, profile1);
		chNumber++;
	}	
	if (c2color != "none") {
		Stack.setChannel(chNumber);
		Plot.setColor(c2color);
		Plot.add("line",xValues, profile2);
		chNumber++;
	}

	if ( (nChannels >= 3) && (c3color != "none"))  {
		Stack.setChannel(chNumber);
		Plot.setColor(c3color);
		Plot.add("line",xValues, profile3);
		chNumber++;
	}
	if ( (nChannels >= 4) && (c4color != "none"))  {
		Stack.setChannel(chNumber);
		Plot.setColor(c4color);
		Plot.add("line",xValues, profile4);
	}
	if ( (nChannels >= 5) && (c5color != "none"))  {
		Stack.setChannel(chNumber);
		Plot.setColor(c5color);
		Plot.add("line",xValues, profile5);
	}

//legend = "C1\tC2";
//if ( (nChannels >= 3) && (c3color != "none"))  legend = "C1\tC2\tC3";
//if ( (nChannels >= 4) && (c3color != "none"))  legend = "C1\tC2\tC3\tC4";
//Plot.setLegend(legend);

Plot.setColor(c1color);

 run("Profile Plot Options...", "width="+plotWidth+" height="+plotHeight+" minimum=0 " + yMax + " draw");
Plot.show;
if (hidePlot == true) run("Close");

// Calculate Correlation Coefficients and send to results table.
nr = nResults();
Fit.doFit("Straight Line", profile1, profile2);
print("C1-C2: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);

setResult("Label",nr,outName);
setResult("length",nr,profile1.length);
setResult("lineWidth",nr,lineWidth);
setResult("meanC1",nr,mean1);
setResult("minC1",nr,min1);
setResult("mean-minC1",nr,mean1-min1);
setResult("meanC2",nr,mean2);
setResult("minC2",nr,min2);
setResult("mean-minC2",nr,mean2-min2);

if ( (nChannels >= 3) && (c3color != "none"))  {
	setResult("meanC3",nr,mean3);
	setResult("minC3",nr,min3);
	setResult("mean-minC3",nr,mean3-min3);
}
if ( (nChannels >= 4) && (c4color != "none"))  {
	setResult("meanC4",nr,mean4);
	setResult("minC4",nr,min4);
	setResult("mean-minC4",nr,mean4-min4);
}
if ( (nChannels >= 5) && (c5color != "none"))  {
	setResult("meanC5",nr,mean4);
	setResult("minC5",nr,min4);
	setResult("mean-minC5",nr,mean5-min5);
}

setResult("x1",nr,x1); 
setResult("x2",nr,x2);
setResult("y1",nr,y1);
setResult("y2",nr,y2);

setResult("C1-C2_r^2",nr,Fit.rSquared);
setResult("C1-C2_slope",nr,Fit.p(1));

resultsRow = nResults()-1;

if ( (nChannels >= 3) && (c3color != "none"))  {
	Fit.doFit("Straight Line", profile1, profile3);
	print("C1-C3: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C1-C3_r^2",resultsRow,Fit.rSquared);
	setResult("C1-C3_slope",resultsRow,Fit.p(1));

	Fit.doFit("Straight Line", profile2, profile3);
	print("C2-C3: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C2-C3_r^2",resultsRow,Fit.rSquared);
	setResult("C2-C3_slope",resultsRow,Fit.p(1));
}

if ( (nChannels >= 4) && (c4color != "none"))  {
	Fit.doFit("Straight Line", profile1, profile4);
	print("C1-C4: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C1-C4_r^2",resultsRow,Fit.rSquared);
	setResult("C1-C4_slope",resultsRow,Fit.p(1));

	Fit.doFit("Straight Line", profile2, profile4);
	print("C2-C4: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C2-C4_r^2",resultsRow,Fit.rSquared);
	setResult("C2-C4_slope",resultsRow,Fit.p(1));

	Fit.doFit("Straight Line", profile3, profile4);
	print("C3-C4: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C3-C4_r^2",resultsRow,Fit.rSquared);
	setResult("C3-C4_slope",resultsRow,Fit.p(1));
}
if ( (nChannels >= 5) && (c4color != "none"))  {
	Fit.doFit("Straight Line", profile1, profile5);
	print("C1-C5: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C1-C5_r^2",resultsRow,Fit.rSquared);
	setResult("C1-C5_slope",resultsRow,Fit.p(1));

	Fit.doFit("Straight Line", profile2, profile5);
	print("C2-C5: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C2-C5_r^2",resultsRow,Fit.rSquared);
	setResult("C2-C5_slope",resultsRow,Fit.p(1));

	Fit.doFit("Straight Line", profile3, profile5);
	print("C3-C5: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C3-C5_r^2",resultsRow,Fit.rSquared);
	setResult("C3-C5_slope",resultsRow,Fit.p(1));
	Fit.doFit("Straight Line", profile3, profile5);

	print("C4-C5: a="+d2s(Fit.p(0),6)+", b="+d2s(Fit.p(1),6)+ ", rSquared="+Fit.rSquared);
	setResult("C4-C5_r^2",resultsRow,Fit.rSquared);
	setResult("C4-C5_slope",resultsRow,Fit.p(1));

}

function guessLUT() {

	getLut(reds, greens, blues);
	Array.getStatistics(reds, min, redsMax, mean, stdDev);
	Array.getStatistics(greens, min, greensMax, mean, stdDev);
	Array.getStatistics(blues, min, bluesMax, mean, stdDev);
	lutColor = "red";
	if ( (redsMax == 255) & (greensMax == 0) & (bluesMax == 0) ) lutColor = "red";
	if ( (redsMax == 0) & (greensMax == 255) & (bluesMax == 0) ) lutColor = "green";
	if ( (redsMax == 0) & (greensMax == 0) & (bluesMax == 255) ) lutColor = "blue";
	if ( (redsMax == 0) & (greensMax == 150) & (bluesMax == 255) ) lutColor = "blue";
	if ( (redsMax == 255) & (greensMax == 0) & (bluesMax == 255) ) lutColor = "magenta";
	if ( (redsMax == 255) & (greensMax == 255) & (bluesMax == 255) ) lutColor = "black";
	if ( (redsMax == 0) & (greensMax == 255) & (bluesMax == 255) ) lutColor = "cyan";
	if ( (redsMax == 255) & (greensMax == 255) & (bluesMax == 0) ) lutColor = "yellow";
	return lutColor;
}

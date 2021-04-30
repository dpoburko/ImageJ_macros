/*
 * Created by Damon Poburko at Simon Fraser University ca. 2019
 * Note: This macro uses a brute force approach to determine the distance between ImageJ ROIs
 * For upto ~1000 ROIs, this is pretty quick, comparable to using the R nn2 k-tree based nearest neighbour search.
 * Feel free to use this macro freely, but please acknowledge use of this script directly or as inspiration
 */

nNN = 6;
dMethChoices = newArray("COMs","perimeters");
Dialog.create("Find Nearest Neighbour ROIs");
Dialog.addNumber("number of nearest neighbours to find for each ROI", parseInt(call("ij.Prefs.get", "dialogDefaults.nNN", "1")));
Dialog.addMessage("NN distance is always measured by X&Y values (geometric centers).");
Dialog.addMessage("But the distance to a neighbour can optionaly be reported as the distance between ROI edges");
Dialog.addChoice("distance reported between",dMethChoices,call("ij.Prefs.get", "dialogDefaults.dMethod",  dMethChoices[0]) );
Dialog.show();
nNN = Dialog.getNumber(); 	call("ij.Prefs.set", "dialogDefaults.nNN", nNN);
dMethod = Dialog.getChoice(); call("ij.Prefs.set", "dialogDefaults.dMethod", dMethod);

nROIs = roiManager("Count");
img0 = getTitle();
t0 = getTime();
run("Clear Results");
run("Set Measurements...", "mean centroid redirect=None decimal=3");
roiManager("deselect");
roiManager("Measure");
xList = newArray(nROIs);
yList = newArray(nROIs);
means = newArray(nROIs);
distances = newArray(nROIs);
angles = newArray(nROIs);
ranks = newArray(nROIs);
nnArray = newArray(nNN);

for (i=0;i<nROIs;i++){
	xList[i] = getResult("X",i);
	yList[i] = getResult("Y",i);
	means[i] = getResult("Mean",i);
}

print("\\Update0: Analyzing "+ xList.length+" ROIs by " + dMethod);

run("Clear Results");

for (j = 0;j<xList.length;j++) {
	distances = newArray(nROIs);
	// for each ROI (j loop), loop through all of the ROIs (k list) to find NNs
	for (k = 0;k<xList.length;k++) {
		//calculate distances between all pairs
		distances[k] = sqrt( pow(xList[j] - xList[k],2) + pow(yList[j] - yList[k],2));
		angles[k] = -1*(180/PI)*atan2(yList[k] - yList[j],xList[k] - xList[j]);
		// find nNN closest k (=ROI number)
	}
		rankPosArr = Array.rankPositions(distances);
		ranks = Array.rankPositions(rankPosArr);
		// sort again to give a sorted list of the ROI number ranked wrt distance to reference ROI
		sortedNNIndex = Array.rankPositions(ranks);
		setResult("Label",j,img0);
		setResult("ROI",j,j+1);
		setResult("mean",j,means[j]);
		setResult("X",j,xList[j]);
		setResult("Y",j,yList[j]);
		for (i=1;i<=nNN;i++){
			setResult("NN"+i,j,sortedNNIndex[i]+1);
		}

		if (dMethod == dMethChoices[1]) {
			roiManager("select", j);
			Roi.getCoordinates(xref, yref);
		}
		
		for (i=1;i<=nNN;i++){

			if (dMethod == dMethChoices[1]) {
				//get points of roi J, move ref selection out of i-loop in future to reduce redundant calls
				roiManager("select", sortedNNIndex[i]);
				Roi.getCoordinates(xnn, ynn);
				d2p = 5000;
				for (m=0;m<xref.length;m++) {
					for (n=0;n<xnn.length;n++) {
						dTest = sqrt( pow(xref[m] - xnn[n],2) + pow(yref[m] - ynn[n],2));
						if (dTest < d2p) d2p = dTest;
					}
				}
				roiManager("deselect");
			}
			setResult("NN"+i+" dist",j,distances[sortedNNIndex[i]]);
			if (dMethod == dMethChoices[1]) setResult("NN"+i+" distBwPerimeters",j,d2p);
		}
		for (i=1;i<=nNN;i++){
			residual = means[j]-means[sortedNNIndex[i]];
			setResult("NN"+i+" residual",j,residual);
		}
		for (i=1;i<=nNN;i++){
			setResult("angle"+i+"angle2NN",j,angles[sortedNNIndex[i]]);
		}

}
print("nROIs: " + nROIs + " time2CalcDists(ms): "+d2s((getTime()-t0),1));
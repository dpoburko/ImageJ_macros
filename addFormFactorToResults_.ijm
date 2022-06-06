//calculate ROI form factor
// Check that results table contains columns for perimeter and area
// Formula: Perimeter^ 2 / (4 * Pi() * Area)

resultsOpen = isOpen("Results");

//selectWindow("Results");
//th = split(Table.headings,"\t");
//Array.show("Results Headings",th);
// hasPerimeter = arrayContains(th, "Perim.") ;
// hasArea = arrayContains(th, "Area") ;

run("Set Measurements...", "area standard min centroid center perimeter fit shape display redirect=None decimal=3");
roiManager("deselect");
nROIs = roiManager("count");
run("Clear Results");
nROIs = roiManager("measure");
nres = nResults;

for (j=0;j<nres;j++) {
	ff = pow( getResult("Perim.", j),2) / ( 4*PI*getResult("Area", j)  );
	setResult("FF", j, ff);		
	a = getResult("Area", j);
	setResult("log(Area)", j, log(a)/log(10));		
	setResult("sqrt(Area)", j, pow(a,0.5));		

}

function arrayContains(array, test) {

	testFound = false;
    for (i=0;i<array.length;i++) {
    	if (array[i]==test) {
    		testsFound = true;
    		i = array.length;
    	}
    }
    return testFound;

}

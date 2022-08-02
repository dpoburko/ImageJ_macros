/*
 * This macro was written by Damon Poburko, Biomedical Physiology & kinesiology, 
 * July 14th, 2022
 * It is written to label frames in a hyperstack with IncuCyte formatted time stamps
 * It assumes that timepoints are encoded as frames, not slices
 */

//User Option:: adjust the time in minutes between frames 
frameInterval = 20; //minutes

//swap frames and slices to use Property.setSliceLabel(string)
run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
Stack.getDimensions(width, height, channels, slices, frames);

//quickly hide the image for faster processing 
setBatchMode(true);
setBatchMode("hide");

for (s=1;s<=slices;s++) {
	ts = min2Text(s*frameInterval);
	print("\\Update0: Property.setSliceLabel("+ts+","+s+")");
	Stack.setSlice(s);
	Property.setSliceLabel(ts);
}

setBatchMode("exit and display");

run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");

function min2Text(m) {
// take a value m in minutes and convert it to an IncuCyte formatted time stamp
 	
 	//get # days
 	d = Math.floor(m/1440);
 	//get #hours
 	h = Math.floor( (m%1400)/60);
 	//get#minutes
 	m = Math.floor( (m%1400)%60);
 	timeString = IJ.pad(d, 2)+"d"+IJ.pad(h, 2)+"h"+IJ.pad(m, 2)+"m";
 	return timeString;
}

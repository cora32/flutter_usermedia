window.state = {
    hasFace: false,
    initialized: false,
    facefinder_classify_region: null,
    update_memory: null,
}

function rgba_to_grayscale(rgba, nrows, ncols) {
	var gray = new Uint8Array(nrows*ncols);
	for(var r=0; r<nrows; ++r)
		for(var c=0; c<ncols; ++c)
			gray[r*ncols + c] = (2*rgba[r*4*ncols+4*c+0]+7*rgba[r*4*ncols+4*c+1]+1*rgba[r*4*ncols+4*c+2])/10;
	return gray;
}

window.detectFace = (rgba, width, height) => {
    image = {
        "pixels": rgba_to_grayscale(rgba, height, width),
        "nrows": height,
        "ncols": width,
        "ldim": width
    }
    params = {
        "shiftfactor": 0.1, // move the detection window by 10% of its size
        "minsize": 100,     // minimum size of a face
        "maxsize": 1000,    // maximum size of a face
        "scalefactor": 1.1  // for multiscale processing: resize the detection window by 10% when moving to the higher scale
    }

    dets = pico.run_cascade(image, window.state.facefinder_classify_region, params);
    dets = window.state.update_memory(dets);
    dets = pico.cluster_detections(dets, 0.2); // set IoU threshold to 0.2

    window.state.hasFace = false;

    for(i=0; i<dets.length; ++i) {
        if(dets[i][3] > 50.0) {
            window.state.hasFace = true;
        }
    }
}

window.loadPico = () => {
   console.log('* loading pico');

   if(window.state.initialized) return;

   window.state.update_memory = pico.instantiate_detection_memory(5); // we will use the detecions of the last 5 frames
   window.state.facefinder_classify_region = function(r, c, s, pixels, ldim) {return -1.0;};
   var cascadeurl = './js/facefinder';
   fetch(cascadeurl).then(function(response) {
   	response.arrayBuffer().then(function(buffer) {
   		var bytes = new Int8Array(buffer);
   		window.state.facefinder_classify_region = pico.unpack_cascade(bytes);
   		console.log('* facefinder loaded');

		window.state.initialized = true;
   	})
   })
}
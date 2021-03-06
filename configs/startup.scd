include("SuperDirt");
s.options.numBuffers = 1024 * 32; // increase this if you need to load more samples
s.options.memSize = 8192 * 16; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 2; // set this to your hardware output channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot {
        ~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
        s.sync;
        ~dirt.start(57120, [0, 0]);   // start listening on port 57120, create two busses each sending audio to channel 0
        s.sync;
	// optional, needed for the sclang tests only:
        (

                ~d1 = ~dirt.orbits[0]; // one orbit
                ~d2 = ~dirt.orbits[1];

        );
	s.sync;
	SynthDef(\plucklead, {
		|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
		var line = Line.ar(begin, end, sustain, doneAction:2);
		var env = Env([0, 1, 0.333, 0],[5, 70, 1000]);
		var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
		var speedFreq = freq*abs(speed);
		var pulseLfo = SinOsc.ar(Rand(-1,1));
		var sound = RLPF.ar(Pulse.ar([speedFreq*Rand(0.99,1.01)*2,speedFreq*Rand(0.99,1.01)*2],pulseLfo)*0.5+Saw.ar(speedFreq), (20000*(envGen**2.8))+DC.ar(10), 0.5);
		Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
	}).add;
	s.sync;
	~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
        // for example: ~dirt.loadSoundFiles("/Users/myUserName/Dirt/samples/*");
        s.sync; // wait for samples to be read
	"SuperDirt has loaded!".postln;
};

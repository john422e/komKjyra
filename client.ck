// synths
//SinOsc synth => Envelope sinEnv => Gain sGain => dac.chan(0);
SndBuf buf1 => Envelope bufEnv1 => Gain sGain1 => dac.chan(0);
SndBuf buf2 => Envelope bufEnv2 => Gain sGain2 => dac.chan(1);


0.0 => sGain1.gain;
0.09 => sGain2.gain;

// globals
1 => int running;
float attackTime; // this doesn't do anything right now (done in samples in bufPlay func)
int tempo;
float beatTime;
0.1 => float attackRatio;
0.05 => float gapRatio;
float gapTime;
float noteLength;
int sequenceLength;
float sequenceTime;

float audioLevel;

// sound files to read in
"komKjyra_LOC.wav" => string fn1;
"recordNoise.wav" => string fn2;


// need to sort this out...
16 => sequenceLength; // needs to match size of sequence in python
int sequence[sequenceLength]; // sequence of 1s and 0s
0 => int offset;
(sequenceLength * beatTime) => sequenceTime;










// OSC
OscIn in;
OscMsg msg;

10000 => int IN_PORT;
IN_PORT => in.port;
in.listenAll();

// functions

fun void setTempo(int newTempo) {
    newTempo => tempo;
    60.0/tempo => beatTime; // length of one beat in seconds
    beatTime * attackRatio => attackTime; // attack length in seconds
    beatTime * gapRatio => gapTime; // silence between notes
    beatTime - gapTime => noteLength; // length of one note
};

fun void readInFile(SndBuf buf, string fileName) {
    // read in sound file from current directory and assign to buffer
    (me.dir() + fileName => buf.read);
}

fun bufPlayLoop(SndBuf buf, Envelope env) {
    // play sound file in a loop (this does NOT turn on envelope)
    // make sure buf loops and starts at the beginning of file
    0 => buf.pos;
    1 => buf.loop;
    // track sample count
    0 => int sampleCount;
    // set envelope attack duration in samples
    48 => int envDur;
    
    while (buf.loop()) {
        // start buf
        //env.keyOn();
        while( (sampleCount < buf.samples()) && buf.loop() ) {
            // turn off when we reach the end of the buffer
            if(sampleCount >= buf.samples() - envDur) env.keyOff();
            sampleCount++; // increment sample count
            1::samp => now; // wait for one sample
            //<<< "SAMPLE: " + sampleCount >>>;
        }
        0 => sampleCount; // reset sample count
    }
    // turn off when loop killed
    env.keyOff();
}

fun void playNote(Envelope e) {
    // play a single note (noteLength + gapTime = beatTime)
    // note on
    e.keyOn();
    //<<< "ON" >>>;
    // wait noteLength seconds
    noteLength::second => now;
    // note off
    e.keyOff();
    //<<< "OFF" >>>;
    // wait gapTime seconds
    gapTime::second => now;
}

fun void playSequence(int seq[], Envelope e1, Envelope e2) {
    // iterate through sequence and look for 1s or 0s
    // wait offset (0 by default)
    <<< "OFFSETTING", offset >>>;
    offset::ms => now;
    for( 0 => int i; i < seq.size(); i++ ) {
        <<< seq[i] >>>;
        if( seq[i] == 0 ) {
            //<<< "SILENCE" >>>;
            // wait in silence
            beatTime::second => now;
        }
        if( seq[i] == 1 ) {
            <<< "SOUND" >>>;
            //pulseTime::second => now;
            // run function which will pulse and wait
            spork ~ playNote(e1);
            playNote(e2);
            
        }
    }
}

int test;

fun void oscListener() {
    <<< "LISTENING ON PORT:", IN_PORT >>>;
    
    while(running) {
        //<<< "HEY" >>>;
        //1::second => now;
        in => now; // wait for a message
        while(in.recv(msg)) {
            <<< "RECEIVING..." >>>;
            if( msg.address == "/sequence" ) {
                // get the sequence from the message
                <<< msg.address >>>;
                // iterate through the message arguments
                for( 0 => int i; i < msg.numArgs(); i++ ) {
                    msg.getInt(i) => sequence[i];
                }
                for( 0 => int i; i < sequence.size(); i++ ) {
                    <<< "SEQUENCE[" + i + "] = " + sequence[i] >>>;
                }
            }
            if( msg.address == "/tempo" ) {
                setTempo(msg.getInt(0));
                <<< "RECEIVING TEMPO", tempo >>>;
            }   
            if( msg.address == "/offset" ) {
                msg.getInt(0) => offset;
                <<< "RECEIVING OFFSET", offset >>>;
                // wait one full sequence to hear offset applied
                (sequenceTime + (offset/1000))::second => now;
                // reset offset to 0
                0 => offset;
            }
            if( msg.address == "/audioLevel1" ) {
                msg.getFloat(0) => audioLevel;
                <<< "RECEIVING AUDIO LEVEL 1", audioLevel >>>;
                // set the audio level
                audioLevel => sGain1.gain;
            }
            if( msg.address == "/audioLevel2" ) {
                msg.getFloat(0) => audioLevel;
                <<< "RECEIVING AUDIO LEVEL 2", audioLevel >>>;
                // set the audio level
                audioLevel => sGain2.gain;
            }
            if( msg.address == "/quit" ) {
                <<< "RECEIVING QUIT MESSAGE" >>>;
                0 => running; // stop the loop
                0 => buf1.loop;
                0 => buf2.loop;
            }
            //1::second => now;
        }
    }
}

// initialize tempo
setTempo(120);

// start the listener
spork ~ oscListener();

// read in sound file
readInFile(buf1, fn1);
readInFile(buf2, fn2);

// play the sound files in a loop
bufEnv1.keyOff();
bufEnv2.keyOff();
spork ~ bufPlayLoop(buf1, bufEnv1);
spork ~ bufPlayLoop(buf2, bufEnv2);

// make a sequence
//[0, 1, 0, 1, 1, 0, 1, 1, 1] @=> int mySequence[];
// play the sequence
//playSequence(mySequence, sinEnv);

while( running ) playSequence(sequence, bufEnv1, bufEnv2 );

//120::second => now; // wait a second before starting


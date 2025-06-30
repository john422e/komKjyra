OscIn oin;
OscMsg msg;

10010 => oin.port;
oin.listenAll();

<<< "Listening on port 10000..." >>>;

while (true) {
    oin => now;
    while (oin.recv(msg)) {
        <<< "Received OSC:", msg.address >>>;
    }
}
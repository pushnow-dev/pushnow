#!/bin/sh
set -eu
cd "$(dirname "$0")"
npm --prefix runtime ci --ignore-scripts
curl -fL --max-time 60 https://repo.maven.apache.org/maven2/org/json/json/20250517/json-20250517.jar -o json-20250517.jar
printf '%s\n' '3ea61b2a06e31edf1c91134fe9106b0ebb16628be169f3db75bc7a2b06b45796  json-20250517.jar' | shasum -a 256 -c -
javac --release 11 -cp json-20250517.jar -d target/test-classes src/main/java/dev/pushnow/Client.java tests/Probe.java tests/ClientTest.java examples/Example.java

#!/bin/sh
set -eu
cd "$(dirname "$0")"
java -cp target/test-classes:json-20250517.jar ClientTest
npm --prefix runtime test

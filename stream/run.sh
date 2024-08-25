#!/bin/bash

set -e

if [ ! -d mediamtx ]; then
	./setup.sh
fi

cp mediamtx.yml mediamtx/
cd mediamtx
./mediamtx
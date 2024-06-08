#!/bin/bash

if [ ! -d mediamtx ]; then
	./setup.sh
fi

cd mediamtx
./mediamtx

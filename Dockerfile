
FROM ubuntu:24.04

# from https://github.com/mitchallen/pi-cross-compile/blob/master/Dockerfile
RUN apt-get update && apt-get install -y git && apt-get install -y build-essential

# from https://www.raspberrypi.com/documentation/computers/linux_kernel.html#cross-compiling-the-kernel
RUN yes Y | apt-get install git bc bison flex libssl-dev make libc6-dev libncurses5-dev
RUN yes Y | apt-get install crossbuild-essential-arm64

# from https://github.com/raspberrypi/tools/blob/master/README.md
RUN yes Y | apt-get install gcc-aarch64-linux-gnu

# and the rest from https://github.com/mitchallen/pi-cross-compile/blob/master/Dockerfile
ENV BUILD_FOLDER /build

WORKDIR ${BUILD_FOLDER}

CMD ["/bin/bash", "-c", "make", "-f", "${BUILD_FOLDER}/Makefile"]
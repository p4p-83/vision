# `vision`

> [!NOTE]
> Refer to [`p4p.jamesnzl.xyz/learn`](https://p4p.jamesnzl.xyz/learn) for full details.

This repository contains the camera, keying, and compositing scripts to produce the [MediaMTX](https://github.com/bluenviron/mediamtx) real-time media server used to stream real-time video from the Raspberry Pi's camera(s).

The video is read from the sensor by `rpicam-vid`, before being piped to `ffmpeg`, which streams it to MediaMTX using RTSP.

The stream can then be accessed on a client using RTSP through a player such as VLC or IINA with
```sh
vlc rtsp://<raspberry.pi.ip.address>:8554/hq
# or
vlc rtsp://<raspberry.pi.ip.address>:8554/cm3
# or
iina rtsp://<raspberry.pi.ip.address>:8554/hq
# or
iina rtsp://<raspberry.pi.ip.address>:8554/cm3
```
or through WebRTC directly in a web browser at
```
http://<raspberry-pi-ip-address>:8889/hq
http://<raspberry-pi-ip-address>:8889/cm3
```

> [!warning]
> The RTSP latency is _bad_.  
> The WebRTC latency is 👌.

This repository is included as a submodule in [`p4p-83/controller`](https://github.com/p4p-83/controller) to be run on the Raspberry Pi.

## Usage

Firstly, clone this repository. Set up [SSH Agent Forwarding](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/using-ssh-agent-forwarding) on the Raspberry Pi if needed.

```sh
cd stream
julia -i run.jl
> start()
# before shut down
> stop()
> exit()
```

## Interfaces

### WebRTC

- WebRTC is used for the real-time low-latency video streaming from MediaMTX on the Raspberry Pi to the web interface.

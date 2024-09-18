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

The next step depends on whether you wish to run `vision` in a standalone manner for experimentation, or have it included as a submodule in a wider Julia project.

For standalone testing and experimentation, use `vision-run-standalone.jl` to call vision for you and print some baseline information as it holds the session open for you. Do this at the shell using the following command.

```sh
julia vision-run-standalone.jl
```

Alternatively, if you're using this as a submodule in a wider project (e.g. as is done by `controller`), you can do this in the usual Julia way by bringing `vision.jl` itself in as a submodule. This is done by `vision-run-standalone.jl`, so you can use that as a minimal example.

## Interfaces

### WebRTC

- WebRTC is used for the real-time low-latency video streaming from MediaMTX on the Raspberry Pi to the web interface.

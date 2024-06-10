# `interface`

This repository contains the user interface for our pick-and-place machine.

At present, it also contains the setup scripts to produce the [MediaMTX](https://github.com/bluenviron/mediamtx) real-time media server used to stream real-time video from the Raspberry Pi's camera(s).

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

## Usage

Firstly, clone this repository. Set up [SSH Agent Forwarding](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/using-ssh-agent-forwarding) on the Raspberry Pi if needed.

### Video Real-Time Streaming

```sh
cd interface/streaming
bash setup.sh
bash run.sh

# note that run.sh will call setup.sh first if needed
```

### Client Interface

```sh
cd interface/client-prototype
npm ci
npm run build
# Open index.html in a browser
```

```sh
cd interface/client
npm ci
npm run dev
```

## Interfaces

### WebRTC

- WebRTC is used for the real-time low-latency video streaming from MediaMTX on the Raspberry Pi to the web interface.
- [`WebRtcVideo`](./client/src/components/WebRtcVideo.tsx) is a React component created using the [`Eyevinn/webrtc-player`](https://github.com/Eyevinn/webrtc-player) package to receive the WHEP stream and display it in a `<video>` tag.

### WebSocket

- A WebSocket is used for the real-time low-latency full-duplex data channel between the Raspberry Pi and the web interface.
- [`socket.ts`](./client/src/lib/socket.ts) implements the API for this data channel.

A message looks like:
- A `Uint8` byte stream
- The first byte is the 'tag' that describes the message type
- The subsequent bytes are an arbitrary payload defined by the message type

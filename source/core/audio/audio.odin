package audio

import saudio "../../libs/sokol/audio"
import slog "../../libs/sokol/log"

import "core:slice"
import "core:sync"

SoundHandle :: distinct u64

Sound :: struct {
	samples:    []f32,
	channels:   int,
	sampleRate: int,
}

Voice :: struct {
	id:     SoundHandle,
	cursor: int,
	active: bool,
	volume: f32,
	loop:   bool,
}

Mixer :: struct {
	lock:   sync.Mutex,
	voices: [64]Voice,
	sounds: map[SoundHandle]Sound,
	next:   SoundHandle,
}

@(private)
_mixer: Mixer

init :: proc() {
	_mixer.next = 1
	_mixer.sounds = make(map[SoundHandle]Sound)
	description := saudio.Desc {
		num_channels = 2,
		sample_rate = 44100,
		buffer_frames = 2048,
		stream_cb = _audioCallback,
		logger = {func = slog.func},
	}
	saudio.setup(description)
}

shutdown :: proc() {
	saudio.shutdown()
	for _, sound in _mixer.sounds {
		delete(sound.samples)
	}
	delete(_mixer.sounds)
}

play :: proc(id: SoundHandle, volume: f32 = 1.0, loop: bool = false) {
	sync.lock(&_mixer.lock)
	defer sync.unlock(&_mixer.lock)

	for &voice in _mixer.voices {
		if !voice.active {
			voice.active = true
			voice.id = id
			voice.cursor = 0
			voice.volume = volume
			voice.loop = loop
			return
		}
	}
}

@(private)
_audioCallback :: proc "c" (buffer: ^f32, numFrames: i32, numChannels: i32) {
	context = {}
	sync.lock(&_mixer.lock)
	defer sync.unlock(&_mixer.lock)

	totalSamples := int(numFrames * numChannels)
	output := slice.from_ptr(buffer, totalSamples)

	slice.fill(output, 0.0)

	for &voice in _mixer.voices {
		if !voice.active do continue
		sound, ok := _mixer.sounds[voice.id]
		if !ok {
			voice.active = false
			continue
		}
		for frameIndex := 0; frameIndex < int(numFrames); frameIndex += 1 {
			if voice.cursor >= len(sound.samples) {
				if voice.loop {
					voice.cursor = 0
				} else {
					voice.active = false
					break
				}
			}

			leftSample: f32 = 0.0
			rightSample: f32 = 0.0

			if sound.channels == 1 {
				val := sound.samples[voice.cursor]
				leftSample = val
				rightSample = val
				voice.cursor += 1
			} else {
				if voice.cursor + 1 >= len(sound.samples) do break
				leftSample = sound.samples[voice.cursor]
				rightSample = sound.samples[voice.cursor + 1]
				voice.cursor += 2
			}

			output[frameIndex * 2 + 0] += leftSample * voice.volume
			output[frameIndex * 2 + 1] += rightSample * voice.volume
		}
	}
}

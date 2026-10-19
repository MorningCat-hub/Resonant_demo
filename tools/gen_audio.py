#!/usr/bin/env python3
"""Procedural audio for 《弦刃 Resonant》.

Everything is synthesized from scratch with numpy so the project has no
third-party audio dependencies.  All music stems share one 120 BPM, 32-bar
(64 second) timeline and therefore stay sample-locked when layered in Godot.

Run:
    python tools/gen_audio.py
"""
from __future__ import annotations

import math
import os
import wave
from pathlib import Path

import numpy as np

SR = 32_000
BPM = 120.0
SPB = 60.0 / BPM               # seconds per beat
BAR = SPB * 4.0                # seconds per bar (2.0)
BARS = 32
DURATION = BAR * BARS          # 64.0 s
N = int(round(DURATION * SR))
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(0x5EED)


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR), dtype=np.float64) / SR


def add_wrap(buf: np.ndarray, start: int, seg: np.ndarray, gain: float = 1.0) -> None:
    """Add a signal at a sample position, wrapping its tail around the loop."""
    if seg.size == 0:
        return
    idx = (start + np.arange(seg.size)) % buf.size
    np.add.at(buf, idx, seg * gain)


def fade(sig: np.ndarray, attack: float = 0.002, release: float = 0.005) -> np.ndarray:
    n = sig.size
    a = max(1, min(n, int(attack * SR)))
    r = max(1, min(n, int(release * SR)))
    sig[:a] *= np.linspace(0.0, 1.0, a)
    sig[-r:] *= np.linspace(1.0, 0.0, r)
    return sig


def onepole_lp(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
    """FFT one-pole response.  Fast enough for full 64 s stems without scipy."""
    n = x.size
    if n < 8:
        return x.copy()
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    response = 1.0 / (1.0 + 1j * freqs / max(cutoff, 1.0))
    return np.fft.irfft(spec * response, n=n)


def hp_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lp_fast(x, cutoff)


def mix(*parts: np.ndarray) -> np.ndarray:
    """Sum signals with different lengths, zero-padding to the longest."""
    n = max(p.size for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:p.size] += p
    return out


def noise(dur: float) -> np.ndarray:
    return rng.standard_normal(int(dur * SR))


def normalise(sig: np.ndarray, peak: float = 0.88) -> np.ndarray:
    m = float(np.max(np.abs(sig))) if sig.size else 0.0
    if m > 1e-9:
        sig *= peak / m
    return sig


def write(name: str, sig: np.ndarray, peak: float = 0.88) -> None:
    sig = np.asarray(sig, dtype=np.float64)
    sig = np.nan_to_num(sig)
    sig = normalise(sig, peak)
    pcm = np.clip(sig * 32767.0, -32768, 32767).astype("<i2")
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name:24s} {path.stat().st_size / 1024 / 1024:6.2f} MB")


# --------------------------------------------------------------------------- #
# instruments
# --------------------------------------------------------------------------- #
def kick(dur: float = 0.38, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = 43.0 + 95.0 * np.exp(-t * 34.0)
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 9.0)
    click = hp_fast(noise(dur), 1800.0) * np.exp(-t * 90.0) * 0.18
    return (body + click) * gain


def snare(dur: float = 0.22, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    n = hp_fast(noise(dur), 900.0) * np.exp(-t * 22.0)
    tone = np.sin(2.0 * np.pi * 185.0 * t) * np.exp(-t * 30.0) * 0.5
    return (n * 0.8 + tone) * gain


def hat(dur: float = 0.055, gain: float = 1.0, open_hat: bool = False) -> np.ndarray:
    if open_hat:
        dur = 0.18
    t = t_axis(dur)
    n = hp_fast(noise(dur), 6500.0)
    return n * np.exp(-t * (26.0 if open_hat else 75.0)) * gain


def rim(dur: float = 0.08, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    n = hp_fast(noise(dur), 2400.0) * np.exp(-t * 55.0)
    tone = np.sin(2.0 * np.pi * 1260.0 * t) * np.exp(-t * 60.0) * 0.5
    return (n + tone) * gain


def bass(midi: float, dur: float, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = hz(midi)
    ph = 2.0 * np.pi * f * t
    saw = 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    sub = np.sin(ph) * 0.7
    raw = lp_fast(saw * 0.45 + sub, 520.0)
    env = np.minimum(1.0, t / 0.006) * np.exp(-t * 2.5)
    env *= np.clip((dur - t) / 0.04, 0.0, 1.0)
    return raw * env * gain


def pluck(midi: float, dur: float, gain: float = 1.0, bright: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = hz(midi)
    out = np.zeros_like(t)
    for k, amp in ((1, 1.0), (2, 0.42 * bright), (3, 0.24 * bright),
                   (4, 0.12 * bright), (6, 0.06 * bright)):
        out += amp * np.sin(2.0 * np.pi * f * k * t) * np.exp(-t * (2.6 + k * 1.5))
    # tiny pluck transient
    out += hp_fast(noise(dur), 2500.0) * np.exp(-t * 95.0) * 0.1
    return out * np.minimum(1.0, t / 0.003) * gain


def pad(midis: list[float], dur: float, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in midis:
        for det in (-0.11, 0.0, 0.13):
            f = hz(m + det)
            ph = 2.0 * np.pi * f * t
            out += (2.0 * ((ph / (2 * np.pi) + 0.5) % 1.0) - 1.0)
    out /= max(1, len(midis) * 3)
    out = lp_fast(out, 1400.0)
    env = np.minimum(1.0, t / 0.35) * np.clip((dur - t) / 0.35, 0.0, 1.0)
    return out * env * gain


def bell(midi: float, dur: float = 1.2, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = hz(midi)
    mod = np.sin(2.0 * np.pi * f * 2.01 * t) * 1.8 * np.exp(-t * 2.2)
    car = np.sin(2.0 * np.pi * f * t + mod)
    return car * np.exp(-t * 2.0) * gain


def string(midi: float, dur: float, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = hz(midi)
    vib = 0.0035 * np.sin(2.0 * np.pi * 5.1 * t)
    ph = 2.0 * np.pi * f * (t + vib * t)
    raw = 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    raw += 0.5 * (2.0 * (((ph * 1.005) / (2 * np.pi)) % 1.0) - 1.0)
    raw = lp_fast(raw, 2800.0)
    env = np.minimum(1.0, t / 0.08) * np.clip((dur - t) / 0.25, 0.0, 1.0)
    return raw * env * gain


def choir(midis: list[float], dur: float, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in midis:
        f = hz(m)
        for k, a in ((1, 1.0), (2, 0.3), (3, 0.17), (4, 0.09), (5, 0.05)):
            out += a * np.sin(2.0 * np.pi * f * k * t +
                                0.22 * np.sin(2.0 * np.pi * 5.3 * t))
    out /= max(1, len(midis))
    env = np.minimum(1.0, t / 0.6) * np.clip((dur - t) / 0.8, 0.0, 1.0)
    return out * env * gain


def timpani(midi: float, dur: float = 0.8, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    f = hz(midi)
    body = np.sin(2.0 * np.pi * f * t) * np.exp(-t * 5.0)
    body += np.sin(2.0 * np.pi * f * 1.5 * t) * np.exp(-t * 8.0) * 0.2
    return body * gain


# --------------------------------------------------------------------------- #
# musical data
# --------------------------------------------------------------------------- #
CHORDS = [
    ("Am", 57, [57, 60, 64]),   # A3 C4 E4
    ("Am", 57, [57, 60, 64]),
    ("F", 53, [53, 57, 60]),
    ("F", 53, [53, 57, 60]),
    ("C", 48, [48, 52, 55]),
    ("C", 48, [48, 52, 55]),
    ("G", 55, [55, 59, 62]),
    ("G", 55, [55, 59, 62]),
]
ROOTS = {"Am": 45, "F": 41, "C": 36, "G": 43}

# 8-bar melody.  (bar, beat, midi, beats, gain)
MELODY = [
    (0, 0.0, 69, 1.5, 0.9), (0, 1.5, 72, 0.5, 0.7), (0, 2.0, 76, 1.0, 0.85),
    (0, 3.0, 74, 1.0, 0.7),
    (1, 0.0, 72, 1.0, 0.8), (1, 1.0, 69, 1.5, 0.7), (1, 2.5, 67, 1.5, 0.65),
    (2, 0.0, 65, 1.5, 0.85), (2, 1.5, 69, 0.5, 0.7), (2, 2.0, 72, 1.5, 0.8),
    (2, 3.5, 69, 0.5, 0.55),
    (3, 0.0, 67, 1.0, 0.8), (3, 1.0, 65, 1.0, 0.7), (3, 2.0, 64, 2.0, 0.75),
    (4, 0.0, 64, 1.0, 0.85), (4, 1.0, 67, 0.5, 0.65), (4, 2.0, 72, 1.5, 0.85),
    (4, 3.5, 74, 0.5, 0.65),
    (5, 0.0, 76, 1.0, 0.9), (5, 1.0, 74, 0.5, 0.7), (5, 1.5, 72, 1.5, 0.8),
    (5, 3.0, 69, 1.0, 0.6),
    (6, 0.0, 71, 1.0, 0.8), (6, 1.0, 74, 1.0, 0.8), (6, 2.0, 79, 1.0, 0.75),
    (6, 3.0, 74, 1.0, 0.65),
    (7, 0.0, 72, 1.5, 0.85), (7, 1.5, 71, 0.5, 0.65), (7, 2.0, 69, 2.0, 0.8),
]


def build_pulse() -> np.ndarray:
    buf = np.zeros(N)
    for bar in range(BARS):
        base = int(bar * BAR * SR)
        for beat in range(4):
            at = base + int(beat * SPB * SR)
            if beat in (0, 2):
                add_wrap(buf, at, rim(0.07, 0.5), 0.34)
            else:
                add_wrap(buf, at, rim(0.06, 0.65), 0.22)
            # soft shaker on the offbeat
            add_wrap(buf, at + int(SPB * 0.5 * SR),
                     hat(0.035, 0.6), 0.16)
        # pulse heart on each bar
        add_wrap(buf, base, kick(0.3, 0.55), 0.32)
        add_wrap(buf, base + int(2 * SPB * SR), kick(0.25, 0.35), 0.17)
    # airy loop tone
    t = t_axis(DURATION)
    air = np.sin(2 * np.pi * hz(81) * t) * 0.018
    air *= 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * t / DURATION))
    buf += air
    return buf


def build_bass() -> np.ndarray:
    buf = np.zeros(N)
    for bar in range(BARS):
        name, root_midi, tones = CHORDS[bar % 8]
        root = ROOTS[name]
        base = int(bar * BAR * SR)
        # drum kit
        for beat in (0, 2):
            add_wrap(buf, base + int(beat * SPB * SR), kick(0.42, 0.95), 0.82)
        add_wrap(buf, base + int(1.5 * SPB * SR), kick(0.3, 0.45), 0.3)
        for beat in (1, 3):
            add_wrap(buf, base + int(beat * SPB * SR), snare(0.22, 0.9), 0.5)
        for eighth in range(8):
            g = 0.09 if eighth % 2 else 0.14
            add_wrap(buf, base + int(eighth * 0.5 * SPB * SR),
                     hat(0.05, 0.8), g)
        add_wrap(buf, base + int(3.5 * SPB * SR), hat(0.15, 0.4, True), 0.2)
        # driving bass: root, root, fifth, octave, root, fifth, seventh, root
        pattern = [0, 0, 7, 12, 0, 7, 10, 12]
        for eighth, interval in enumerate(pattern):
            at = base + int(eighth * 0.5 * SPB * SR)
            dur = 0.24 if eighth % 2 else 0.3
            add_wrap(buf, at, bass(root + interval, dur, 0.62),
                     0.55 if eighth == 0 else 0.42)
        # chord stabs on the and-of-2
        if bar % 4 == 3:
            for m in tones:
                add_wrap(buf, base + int(2.5 * SPB * SR),
                         pluck(m + 12, 0.35, 0.35), 0.22)
    return buf


def build_melody() -> np.ndarray:
    buf = np.zeros(N)
    for cycle in range(4):
        bar_off = cycle * 8
        for bar, beat, midi, beats, gain in MELODY:
            # cycle variation: up an octave on the last pass, small ornaments
            transpose = 12 if cycle == 3 and bar >= 4 else 0
            at = int((bar_off + bar) * BAR * SR + beat * SPB * SR)
            dur = beats * SPB + 0.5
            g = gain * (0.9 if cycle else 0.72)
            add_wrap(buf, at, pluck(midi + transpose, dur, g, 1.0), 0.55)
            if cycle >= 1 and (bar, beat) in ((2, 0.0), (5, 0.0), (7, 0.0)):
                add_wrap(buf, at + int(0.25 * SPB * SR),
                         bell(midi + transpose + 12, 0.8, 0.25), 0.16)
    # dotted-eighth echo, wrapped
    delayed = np.roll(buf, int(0.375 * SPB * SR)) * 0.23
    delayed = np.roll(delayed, int(0.75 * SPB * SR)) * 0.10
    return buf + delayed


def build_harmony() -> np.ndarray:
    buf = np.zeros(N)
    for bar in range(BARS):
        name, root_midi, tones = CHORDS[bar % 8]
        base = int(bar * BAR * SR)
        add_wrap(buf, base, pad([m - 12 for m in tones], BAR * 1.15, 0.5), 0.6)
        # slow arpeggio on 16ths, very soft
        arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12,
               tones[1] + 12, tones[2] + 24, tones[1] + 12,
               tones[0] + 24, tones[2] + 12]
        for i in range(8):
            at = base + int(i * 0.5 * SPB * SR)
            add_wrap(buf, at, bell(arp[i], 1.0, 0.28),
                     0.18 if i % 2 else 0.24)
        if bar % 4 == 0:
            add_wrap(buf, base, bell(tones[2] + 24, 2.0, 0.4), 0.18)
    # wide string swell every 8 bars
    for bar in range(0, BARS, 8):
        name, root_midi, tones = CHORDS[bar % 8]
        for m in tones:
            add_wrap(buf, int(bar * BAR * SR), string(m, BAR * 3.5, 0.22), 0.24)
    # gentle reverb taps
    wet = np.roll(buf, int(0.043 * SR)) * 0.24
    wet += np.roll(buf, int(0.079 * SR)) * 0.16
    wet += np.roll(buf, int(0.131 * SR)) * 0.11
    return buf + wet


# Boss: a more aggressive pass over the same grid.
BOSS_RIFF = [45, 45, 48, 45, 43, 45, 50, 48]
BOSS_CHORDS = [
    ("Am", 45, [57, 60, 64]),
    ("Am", 45, [57, 60, 64]),
    ("F", 41, [53, 57, 60]),
    ("E", 40, [52, 56, 59]),
]


def build_boss_pulse() -> np.ndarray:
    buf = np.zeros(N)
    t = t_axis(DURATION)
    drone = (np.sin(2 * np.pi * hz(33) * t) * 0.6 +
             np.sin(2 * np.pi * hz(45) * t) * 0.3)
    drone *= 0.6 + 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * t / (BAR * 8)))
    buf += drone * 0.11
    for bar in range(BARS):
        base = int(bar * BAR * SR)
        for beat in range(4):
            at = base + int(beat * SPB * SR)
            if beat in (0, 2):
                add_wrap(buf, at, timpani(33, 0.6, 0.9), 0.62)
                add_wrap(buf, at, kick(0.5, 1.0), 0.55)
            else:
                add_wrap(buf, at, snare(0.18, 0.65), 0.28)
            for sub in (0, 2):
                add_wrap(buf, at + int(sub * 0.25 * SPB * SR),
                         hat(0.03, 0.6), 0.11)
        # industrial tick on the last sixteenth of the bar
        add_wrap(buf, base + int(3.75 * SPB * SR), rim(0.05, 0.8), 0.22)
        # cymbal every 8 bars
        if bar % 8 == 0:
            add_wrap(buf, base, hat(0.7, 0.55, True), 0.25)
    return buf


def build_boss_lead() -> np.ndarray:
    buf = np.zeros(N)
    for bar in range(BARS):
        name, root, tones = BOSS_CHORDS[bar % 4]
        base = int(bar * BAR * SR)
        # ostinato
        for eighth in range(8):
            at = base + int(eighth * 0.5 * SPB * SR)
            note = BOSS_RIFF[eighth] + (12 if bar % 8 >= 4 and eighth in (2, 6) else 0)
            add_wrap(buf, at, bass(note, 0.28, 0.8), 0.42)
            if eighth in (3, 7):
                add_wrap(buf, at, string(note + 24, 0.22, 0.3), 0.22)
        # brass stabs
        for beat in (0.0, 1.5, 2.5):
            at = base + int(beat * SPB * SR)
            for m in tones:
                add_wrap(buf, at, string(m, 0.5, 0.4), 0.18)
        # ominous melody every 4 bars
        if bar % 4 == 0:
            for i, (bt, midi, ln) in enumerate([(0.0, 81, 1.0), (1.0, 79, 0.5),
                                                (1.5, 76, 1.5), (3.0, 74, 1.0)]):
                add_wrap(buf, base + int(bt * SPB * SR),
                         string(midi, ln * SPB, 0.55), 0.28)
    # rhythmic delay + reverb
    out = buf + np.roll(buf, int(0.5 * SPB * SR)) * 0.13
    out += np.roll(out, int(0.067 * SR)) * 0.12
    return out


def build_boss_coda() -> np.ndarray:
    buf = np.zeros(N)
    for bar in range(0, BARS, 4):
        base = int(bar * BAR * SR)
        if bar % 8 == 0:
            chord = [57, 60, 64, 69, 72]      # A minor add 9
            root = 45
        else:
            chord = [53, 57, 60, 65, 69]      # F major add 9
            root = 41
        add_wrap(buf, base, choir(chord, BAR * 4.2, 0.6), 0.55)
        add_wrap(buf, base, timpani(root, 1.4, 0.5), 0.30)
        add_wrap(buf, base + int(2 * SPB * SR), timpani(root + 7, 1.0, 0.4), 0.18)
        for i, m in enumerate((chord[0] + 12, chord[2] + 12, chord[3] + 12)):
            add_wrap(buf, base + int(i * 0.5 * SPB * SR),
                     bell(m, 2.4, 0.5), 0.15)
        # heroic horn call in the second half
        if bar % 8 == 4:
            for bt, m in ((0.0, 69), (0.5, 72), (1.0, 76), (2.0, 79)):
                add_wrap(buf, base + int(bt * SPB * SR),
                         string(m, 1.0, 0.7), 0.28)
    wet = np.roll(buf, int(0.053 * SR)) * 0.2 + np.roll(buf, int(0.099 * SR)) * 0.13
    return buf + wet


# --------------------------------------------------------------------------- #
# sound effects
# --------------------------------------------------------------------------- #
def sfx_envelope(n: int, a: float = 0.003, d: float = 0.2) -> np.ndarray:
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / max(d, 1e-4))


def whoosh(dur: float, f0: float, f1: float, gain: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    n = noise(dur)
    # crude moving band: crossfade low and high passed noise
    lo = lp_fast(n, f0)
    hi = hp_fast(n, f1)
    mix = np.linspace(0, 1, t.size) ** 1.6
    sig = (lo * (1 - mix) + hi * mix) * np.exp(-t * 9.0)
    sig *= np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.6
    return sig * gain


def impact(dur: float, base: float, noise_amt: float, gain: float) -> np.ndarray:
    t = t_axis(dur)
    body = np.sin(2 * np.pi * base * t * (1.0 + 0.5 * np.exp(-t * 40))) * np.exp(-t * 14)
    crack = hp_fast(noise(dur), 1800) * np.exp(-t * 55) * noise_amt
    return (body + crack) * gain


def generate_sfx() -> None:
    write("ui_move.wav", fade(rim(0.04, 0.7), 0.001, 0.005), 0.55)
    write("ui_confirm.wav", fade(bell(84, 0.35, 0.7), 0.001, 0.01), 0.7)
    write("ui_back.wav", fade(bell(69, 0.3, 0.55), 0.001, 0.01), 0.6)
    write("click.wav", fade(rim(0.06, 0.9), 0.001, 0.005), 0.75)
    write("metronome_hi.wav", fade(bell(88, 0.18, 0.5), 0.001, 0.01), 0.55)

    write("swing_light.wav", fade(whoosh(0.18, 900, 5200, 0.7), 0.004, 0.02), 0.55)
    write("swing_heavy.wav", fade(whoosh(0.38, 220, 2100, 0.85), 0.01, 0.04), 0.65)
    write("swing_thrust.wav", fade(whoosh(0.22, 1400, 7200, 0.7), 0.004, 0.03), 0.55)
    write("swing_launch.wav", fade(whoosh(0.26, 700, 4200, 0.7), 0.003, 0.04), 0.55)

    write("hit_light.wav", fade(impact(0.18, 540, 0.8, 0.9), 0.001, 0.02), 0.8)
    write("hit_heavy.wav", fade(impact(0.5, 64, 1.3, 1.2), 0.001, 0.04), 0.95)
    write("hit_thrust.wav", fade(impact(0.22, 760, 0.7, 0.8), 0.001, 0.02), 0.8)
    write("hit_launch.wav", fade(mix(impact(0.26, 320, 0.8, 0.7),
                                     bell(81, 0.26, 0.45)), 0.001, 0.02), 0.8)
    # armor clang
    t = t_axis(0.36)
    clang = sum(np.sin(2 * np.pi * f * t) * a for f, a in
                ((880, 0.4), (1320, 0.25), (1870, 0.18), (2610, 0.1)))
    clang *= np.exp(-t * 12)
    write("hit_armor.wav", fade(clang, 0.001, 0.03), 0.7)

    write("perfect.wav", fade(bell(84, 0.8, 0.6) + bell(88, 0.8, 0.45) +
                              bell(91, 0.8, 0.35), 0.001, 0.05), 0.75)
    write("great.wav", fade(bell(79, 0.5, 0.5) + bell(84, 0.5, 0.3), 0.001, 0.03), 0.65)
    write("good.wav", fade(bell(72, 0.38, 0.45), 0.001, 0.03), 0.55)

    write("dodge.wav", fade(whoosh(0.24, 500, 6000, 0.75), 0.003, 0.03), 0.6)
    write("hurt.wav", fade(impact(0.36, 110, 1.2, 1.0), 0.001, 0.04), 0.85)
    write("death_note.wav", fade(pluck(76, 0.5, 0.7) + bell(88, 0.5, 0.4), 0.001, 0.05), 0.65)
    write("death_guard.wav", fade(impact(0.7, 70, 1.2, 1.0), 0.001, 0.08), 0.85)
    write("death_sprite.wav", fade(bell(93, 0.7, 0.6) + bell(96, 0.7, 0.35), 0.001, 0.06), 0.65)
    t = t_axis(0.5)
    glitch = np.sign(np.sin(2 * np.pi * 90 * t)) * hp_fast(noise(0.5), 2000) * np.exp(-t * 9)
    write("death_dissonant.wav", fade(glitch, 0.002, 0.04), 0.6)
    write("note_pickup.wav", fade(bell(88, 0.45, 0.55) + bell(93, 0.45, 0.3), 0.001, 0.04), 0.65)
    write("checkpoint.wav", fade(pad([57, 60, 64, 69], 0.8, 0.6), 0.02, 0.08), 0.6)

    write("seal_hit.wav", fade(impact(0.35, 240, 0.9, 0.8), 0.001, 0.03), 0.75)
    write("seal_complete.wav", fade(bell(81, 1.6, 0.55) + bell(84, 1.6, 0.4) +
                                    bell(88, 1.6, 0.3) + pad([57, 64, 69], 1.6, 0.5),
                                    0.001, 0.15), 0.75)
    write("unlock.wav", fade(pad([57, 60, 64, 69, 72], 2.2, 0.55) +
                             bell(76, 2.2, 0.2), 0.08, 0.4), 0.65)
    write("boss_telegraph.wav", fade(string(45, 0.55, 0.8) + string(52, 0.55, 0.5),
                                     0.01, 0.08), 0.7)
    write("boss_slam.wav", fade(impact(0.75, 48, 1.5, 1.3), 0.001, 0.08), 0.95)
    write("boss_shot.wav", fade(impact(0.3, 330, 0.6, 0.7) +
                                bell(79, 0.3, 0.35), 0.001, 0.04), 0.7)
    write("boss_hurt.wav", fade(impact(0.22, 210, 0.7, 0.8), 0.001, 0.03), 0.7)
    write("finale_hit.wav", fade(impact(0.9, 44, 1.4, 1.3) +
                                 bell(88, 0.9, 0.5), 0.001, 0.1), 0.95)
    write("finale_success.wav", fade(pad([57, 60, 64, 69, 72, 76], 3.2, 0.6) +
                                     bell(84, 3.2, 0.35) + bell(88, 3.2, 0.25),
                                     0.03, 0.8), 0.75)
    write("finale_fail.wav", fade(string(45, 1.8, 0.6) + string(44, 1.8, 0.4) +
                                  string(42, 1.8, 0.3), 0.02, 0.3), 0.55)
    write("telegraph.wav", fade(string(76, 0.25, 0.5), 0.005, 0.03), 0.5)
    write("resonance.wav", fade(bell(93, 0.6, 0.4), 0.001, 0.05), 0.5)


def main() -> None:
    print(f"Resonant audio: {SR} Hz mono, {BPM:.0f} BPM, {BARS} bars, {DURATION:.1f}s")
    print("music stems")
    write("level_pulse.wav", build_pulse(), 0.78)
    write("level_bass.wav", build_bass(), 0.82)
    write("level_melody.wav", build_melody(), 0.78)
    write("level_harmony.wav", build_harmony(), 0.76)
    write("boss_pulse.wav", build_boss_pulse(), 0.82)
    write("boss_lead.wav", build_boss_lead(), 0.82)
    write("boss_coda.wav", build_boss_coda(), 0.76)
    print("sfx")
    generate_sfx()
    print("done ->", OUT)


if __name__ == "__main__":
    main()

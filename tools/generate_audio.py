#!/usr/bin/env python3
"""Generate all placeholder audio (SFX + music loops) as WAV files.

Pure-python synthesis — no dependencies. Deterministic (fixed seeds).
Run from the project root:  python3 tools/generate_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
TAU = math.tau
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def write_wav(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            s = max(-0.98, min(0.98, s))
            frames += struct.pack("<h", int(s * 32000))
        w.writeframes(bytes(frames))
    print(f"  {name}  {len(samples)/SR:.2f}s")


def buf(seconds):
    return [0.0] * int(seconds * SR)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def sine(f, t):
    return math.sin(TAU * f * t)


def tri(f, t):
    return 2 / math.pi * math.asin(math.sin(TAU * f * t))


def soft_square(f, t):
    return math.tanh(3.0 * math.sin(TAU * f * t))


def add_tone(b, start, dur, freq, wave_fn=sine, vol=0.3, attack=0.01, release=0.08, vib=0.0):
    n0 = int(start * SR)
    n = int(dur * SR)
    for i in range(n):
        idx = n0 + i
        if idx >= len(b):
            break
        t = i / SR
        f = freq * (1.0 + vib * math.sin(TAU * 5.5 * t))
        e = min(1.0, t / max(attack, 1e-4)) * min(1.0, (dur - t) / max(release, 1e-4))
        b[idx] += wave_fn(f, t) * vol * max(0.0, e)


def add_noise(b, start, dur, vol=0.3, attack=0.002, release=0.05, lp=0.5, rng=None):
    rng = rng or random
    n0 = int(start * SR)
    n = int(dur * SR)
    prev = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(b):
            break
        t = i / SR
        e = min(1.0, t / max(attack, 1e-4)) * min(1.0, (dur - t) / max(release, 1e-4))
        prev = prev * lp + rng.uniform(-1, 1) * (1 - lp)
        b[idx] += prev * vol * max(0.0, e)


def sweep(b, start, dur, f0, f1, wave_fn=sine, vol=0.3, attack=0.01, release=0.05):
    n0 = int(start * SR)
    n = int(dur * SR)
    phase = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(b):
            break
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        phase += TAU * f / SR
        e = min(1.0, t / max(attack, 1e-4)) * min(1.0, (dur - t) / max(release, 1e-4))
        b[idx] += math.sin(phase) * vol * max(0.0, e)


# ---------------------------------------------------------------- SFX --------

def gen_sfx():
    b = buf(0.14)
    sweep(b, 0, 0.14, 320, 660, vol=0.4)
    write_wav("sfx_jump.wav", b)

    b = buf(0.16)
    sweep(b, 0, 0.16, 500, 180, vol=0.35)
    add_noise(b, 0, 0.1, vol=0.12, lp=0.3)
    write_wav("sfx_whoosh.wav", b)

    b = buf(0.1)
    add_noise(b, 0, 0.04, vol=0.5, lp=0.2)
    add_tone(b, 0.02, 0.08, 140, sine, vol=0.5, release=0.06)
    write_wav("sfx_bite.wav", b)

    b = buf(0.09)
    add_tone(b, 0, 0.09, 780, sine, vol=0.4, release=0.07)
    add_tone(b, 0, 0.05, 1560, sine, vol=0.15, release=0.04)
    write_wav("sfx_crumb.wav", b)

    b = buf(0.3)
    add_tone(b, 0, 0.12, midi(76), sine, vol=0.35, release=0.08)
    add_tone(b, 0.11, 0.19, midi(81), sine, vol=0.35, release=0.14)
    write_wav("sfx_fruit.wav", b)

    b = buf(0.25)
    sweep(b, 0, 0.25, 220, 70, soft_square, vol=0.35)
    write_wav("sfx_hurt.wav", b)

    b = buf(0.7)
    sweep(b, 0, 0.7, 620, 130, vol=0.4, release=0.25)
    for i in range(6):
        add_tone(b, i * 0.1, 0.06, 620 - i * 80, tri, vol=0.12)
    write_wav("sfx_death.wav", b)

    b = buf(0.14)
    add_noise(b, 0, 0.12, vol=0.4, lp=0.75)
    add_tone(b, 0, 0.08, 90, sine, vol=0.3)
    write_wav("sfx_splat.wav", b)

    b = buf(0.04)
    add_noise(b, 0, 0.03, vol=0.22, lp=0.35)
    write_wav("sfx_step.wav", b)

    # Wing buzz loop: low buzz with flutter AM.
    b = buf(0.5)
    for i in range(len(b)):
        t = i / SR
        am = 0.6 + 0.4 * math.sin(TAU * 26 * t)
        b[i] = (math.sin(TAU * 95 * t) * 0.5 + math.sin(TAU * 190 * t) * 0.25
                + math.sin(TAU * 287 * t) * 0.12) * 0.3 * am
    write_wav("sfx_wings.wav", b)

    b = buf(0.9)
    for i, n in enumerate([72, 76, 79, 84]):
        add_tone(b, i * 0.14, 0.3, midi(n), tri, vol=0.3, release=0.2)
        add_tone(b, i * 0.14, 0.3, midi(n) * 2, sine, vol=0.1, release=0.2)
    write_wav("sfx_complete.wav", b)

    # Rat squeak: two sharp descending chirps.
    b = buf(0.45)
    sweep(b, 0, 0.16, 2400, 1400, vol=0.3, attack=0.005, release=0.06)
    sweep(b, 0.22, 0.18, 2100, 1100, vol=0.3, attack=0.005, release=0.08)
    write_wav("sfx_squeak.wav", b)

    # Heavy thud for boss charges/slams.
    b = buf(0.3)
    add_tone(b, 0, 0.25, 55, sine, vol=0.6, attack=0.004, release=0.2)
    add_noise(b, 0, 0.1, vol=0.25, lp=0.85)
    write_wav("sfx_thud.wav", b)

    # Acid sizzle for burning puddles.
    b = buf(0.5)
    add_noise(b, 0, 0.5, vol=0.3, lp=0.15, release=0.4)
    add_tone(b, 0, 0.3, 3200, sine, vol=0.04, release=0.25)
    write_wav("sfx_sizzle.wav", b)


# ---------------------------------------------------------------- music ------

def track(name, bpm, bars, chords, bass_fn, extras_fn, lead, lead_vol=0.16, lead_wave=tri):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    b = buf(total)
    for bar in range(bars):
        root, third, fifth = chords[bar % len(chords)]
        t0 = bar * 4 * beat
        bass_fn(b, t0, beat, root, third, fifth)
        extras_fn(b, t0, beat, root, third, fifth, bar)
    for bar, on_beat, note, length in lead:
        add_tone(b, bar * 4 * beat + on_beat * beat, length * beat, midi(note),
                 lead_wave, vol=lead_vol, attack=0.02, release=0.12, vib=0.006)
    # gentle master soften
    b = [math.tanh(1.4 * s) * 0.75 for s in b]
    write_wav(name, b)


def chord(root_midi, minor=False):
    return (root_midi, root_midi + (3 if minor else 4), root_midi + 7)


def gen_music():
    rng = random.Random(7)

    # DRAIN — slow, murky, dripping. A minor.
    def drain_bass(b, t0, beat, root, third, fifth):
        for k in range(4):
            add_tone(b, t0 + k * beat, beat * 0.9, midi(root - 24), sine, vol=0.3,
                     attack=0.02, release=0.3)

    def drain_extras(b, t0, beat, root, third, fifth, bar):
        for n in (root, third, fifth):
            add_tone(b, t0, beat * 3.8, midi(n - 12), tri, vol=0.05, attack=0.6, release=1.0)
        if bar % 2 == 1:  # echoing drip plinks
            tt = t0 + rng.uniform(0.5, 2.5) * beat
            n = rng.choice([root + 12, fifth + 12, root + 19])
            add_tone(b, tt, 0.1, midi(n), sine, vol=0.14, release=0.09)
            add_tone(b, tt + 0.22, 0.1, midi(n), sine, vol=0.07, release=0.09)

    drain_lead = [
        (1, 0, 76, 1.5), (1, 2, 74, 1.0), (2, 0, 72, 2.0),
        (3, 2, 71, 1.5), (5, 0, 74, 1.5), (5, 2, 76, 1.0),
        (6, 0, 72, 2.5), (7, 2, 69, 1.5),
    ]
    track("music_drain.wav", 84, 8,
          [chord(57, True), chord(53), chord(60), chord(52),
           chord(57, True), chord(53), chord(50, True), chord(52)],
          drain_bass, drain_extras, drain_lead, lead_vol=0.12, lead_wave=sine)

    # STREET — mellow night walk. D minor.
    def street_bass(b, t0, beat, root, third, fifth):
        walk = [root - 24, third - 24, fifth - 24, third - 24]
        for k in range(4):
            add_tone(b, t0 + k * beat, beat * 0.8, midi(walk[k]), tri, vol=0.26,
                     attack=0.01, release=0.15)

    def street_extras(b, t0, beat, root, third, fifth, bar):
        for k in (1, 3):  # offbeat chord stabs
            for n in (root, third, fifth):
                add_tone(b, t0 + k * beat + beat * 0.5, beat * 0.35, midi(n), soft_square,
                         vol=0.045, attack=0.01, release=0.1)

    street_lead = [
        (0, 2, 69, 1.0), (1, 0, 72, 1.5), (1, 3, 74, 0.75),
        (2, 0, 77, 2.0), (3, 0, 74, 1.0), (3, 2, 72, 1.5),
        (4, 2, 69, 1.0), (5, 0, 72, 1.5), (6, 0, 76, 2.0), (7, 0, 74, 2.5),
    ]
    track("music_street.wav", 96, 8,
          [chord(50, True), chord(55, True), chord(58), chord(57),
           chord(50, True), chord(55, True), chord(58), chord(57)],
          street_bass, street_extras, street_lead, lead_vol=0.14, lead_wave=sine)

    # KITCHEN — bouncy and bright. C major.
    def kitchen_bass(b, t0, beat, root, third, fifth):
        seq = [root - 24, fifth - 24, root - 12, fifth - 24,
               root - 24, fifth - 24, root - 12, fifth - 24]
        for k in range(8):
            add_tone(b, t0 + k * beat * 0.5, beat * 0.4, midi(seq[k]), tri, vol=0.24,
                     attack=0.005, release=0.08)

    def kitchen_extras(b, t0, beat, root, third, fifth, bar):
        arp = [root, third, fifth, third + 12, fifth, third, root + 12, fifth]
        for k in range(8):
            add_tone(b, t0 + k * beat * 0.5, beat * 0.3, midi(arp[k % len(arp)]), sine,
                     vol=0.06, attack=0.005, release=0.08)

    kitchen_lead = [
        (0, 0, 76, 0.75), (0, 1, 79, 0.75), (0, 2, 84, 1.5),
        (1, 0, 83, 0.75), (1, 2, 79, 1.0), (2, 0, 81, 1.5), (2, 2, 76, 1.0),
        (3, 0, 77, 1.0), (3, 2, 79, 1.5),
        (4, 0, 76, 0.75), (4, 1, 79, 0.75), (4, 2, 84, 1.5),
        (5, 0, 86, 1.0), (5, 2, 83, 1.0), (6, 0, 81, 1.5), (6, 2, 77, 1.0),
        (7, 0, 79, 2.0), (7, 2, 72, 2.0),
    ]
    track("music_kitchen.wav", 116, 8,
          [chord(60), chord(55), chord(57, True), chord(53),
           chord(60), chord(55), chord(57, True), chord(53)],
          kitchen_bass, kitchen_extras, kitchen_lead, lead_vol=0.13, lead_wave=soft_square)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("Generating SFX...")
    gen_sfx()
    print("Generating music...")
    gen_music()
    print("Done ->", OUT)

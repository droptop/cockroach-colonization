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

    # Acid sizzle for burning puddles.
    b = buf(0.5)
    add_noise(b, 0, 0.5, vol=0.3, lp=0.15, release=0.4)
    add_tone(b, 0, 0.3, 3200, sine, vol=0.04, release=0.25)
    write_wav("sfx_sizzle.wav", b)

    # --- Granny's kit -------------------------------------------------------
    # Still placeholders, but each one its OWN placeholder: granny_stomp and
    # granny_swat used to share sfx_thud, so two different attacks landed with
    # an identical sound and the player had no way to tell them apart.

    # "Eek!" — a startled yelp. Two formant-ish tones sliding up then clipped
    # short, which is about as close to a voice as pure synthesis gets.
    b = buf(0.42)
    sweep(b, 0.0, 0.13, 700, 1150, vol=0.30, attack=0.012, release=0.05)
    sweep(b, 0.0, 0.13, 1400, 2100, vol=0.12, attack=0.012, release=0.05)
    sweep(b, 0.15, 0.20, 1050, 820, vol=0.26, attack=0.010, release=0.12)
    sweep(b, 0.15, 0.20, 2050, 1700, vol=0.09, attack=0.010, release=0.12)
    add_noise(b, 0.0, 0.05, vol=0.05, lp=0.4)
    write_wav("sfx_granny_eek.wav", b)

    # Swatter: light, flat, plastic. A quick air-whip into a slap — high and
    # papery where the stomp is low and heavy.
    b = buf(0.3)
    sweep(b, 0.0, 0.07, 900, 260, vol=0.16, attack=0.004, release=0.03)
    add_noise(b, 0.06, 0.05, vol=0.42, lp=0.25, attack=0.001, release=0.04)
    add_tone(b, 0.065, 0.12, 320, tri, vol=0.30, attack=0.002, release=0.10)
    add_tone(b, 0.065, 0.07, 640, sine, vol=0.10, attack=0.002, release=0.06)
    write_wav("sfx_granny_swat.wav", b)

    # Stomp: a slipper, and the whole floor. Deep body, long tail, and a rattle
    # of everything on the shelves.
    b = buf(0.55)
    add_tone(b, 0.0, 0.42, 42, sine, vol=0.70, attack=0.004, release=0.34)
    add_tone(b, 0.0, 0.22, 78, sine, vol=0.28, attack=0.004, release=0.18)
    add_noise(b, 0.0, 0.14, vol=0.30, lp=0.88, release=0.11)
    add_noise(b, 0.10, 0.30, vol=0.05, lp=0.55, release=0.26)
    write_wav("sfx_granny_stomp.wav", b)

    # Aerosol hiss. Loops, so it is deliberately flat and seamless — no attack
    # or release shaping, or the seam would tick every time round.
    b = buf(0.6)
    add_noise(b, 0, 0.6, vol=0.30, lp=0.05, attack=0.0001, release=0.0001)
    add_noise(b, 0, 0.6, vol=0.10, lp=0.62, attack=0.0001, release=0.0001)
    add_tone(b, 0, 0.6, 5200, sine, vol=0.015, attack=0.0001, release=0.0001)
    write_wav("sfx_granny_spray.wav", b)

    # Water: a slap of liquid, then it running away across the floor.
    b = buf(0.7)
    add_noise(b, 0.0, 0.09, vol=0.45, lp=0.35, attack=0.001, release=0.07)
    sweep(b, 0.0, 0.18, 520, 130, vol=0.22, attack=0.003, release=0.14)
    add_noise(b, 0.08, 0.55, vol=0.13, lp=0.20, attack=0.02, release=0.45)
    write_wav("sfx_water_splash.wav", b)

    gen_split_sfx()


# ------------------------------------------------------- the split names -----

def gen_split_sfx():
    """The 19 names carved out of `thud` and `squeak`.

    These are STILL placeholders — synthesis, not recordings. The point is only
    that each one is its OWN placeholder. `thud` was being played from sixteen
    different places and `squeak` from thirteen, so every boss shared one hurt
    sound and one death sound, and a blocked shield was indistinguishable from
    a rat landing. Distinct-but-synthetic beats identical-and-synthetic, and it
    means a real recording drops in over one file without touching any code.

    See docs/audio-brief.md for what each should eventually become.
    """
    rng = random.Random(4242)

    # --- impacts, from `thud` -----------------------------------------------
    # Big soft body on a hard floor: low, slow, a little wet.
    b = buf(0.42)
    add_tone(b, 0, 0.36, 42, sine, vol=0.65, attack=0.004, release=0.3)
    add_tone(b, 0, 0.14, 88, sine, vol=0.2, attack=0.003, release=0.12)
    add_noise(b, 0, 0.13, vol=0.22, lp=0.88, rng=rng)
    write_wav("sfx_impact_heavy.wav", b)

    # Pebble on tile: tiny, sharp, dry, gone.
    b = buf(0.14)
    add_tone(b, 0, 0.05, 1500, tri, vol=0.3, attack=0.001, release=0.04)
    add_noise(b, 0, 0.04, vol=0.28, lp=0.3, attack=0.0005, release=0.03, rng=rng)
    write_wav("sfx_impact_light.wav", b)

    # Bottle-cap shield: cheap tin, rattly, faintly comic.
    b = buf(0.4)
    for f, v in ((1180, 0.26), (1790, 0.18), (2630, 0.12), (3410, 0.07)):
        add_tone(b, 0, 0.3, f, sine, vol=v, attack=0.001, release=0.26, vib=0.02)
    add_noise(b, 0, 0.05, vol=0.3, lp=0.2, attack=0.0005, release=0.04, rng=rng)
    write_wav("sfx_block.wav", b)

    # A refusal, not a hit: dead, damped, no ring at all.
    b = buf(0.34)
    add_tone(b, 0, 0.15, 96, sine, vol=0.4, attack=0.006, release=0.13)
    add_tone(b, 0, 0.1, 143, tri, vol=0.12, attack=0.006, release=0.09)
    add_noise(b, 0, 0.07, vol=0.12, lp=0.9, rng=rng)
    write_wav("sfx_locked.wav", b)

    # Concrete letting go, then grit falling after it.
    b = buf(0.46)
    add_noise(b, 0, 0.05, vol=0.5, lp=0.25, attack=0.0005, release=0.04, rng=rng)
    sweep(b, 0, 0.1, 420, 150, vol=0.3, attack=0.002, release=0.08)
    for i in range(7):
        at = 0.06 + rng.uniform(0.0, 0.3)
        add_noise(b, at, 0.03, vol=rng.uniform(0.05, 0.13), lp=0.2,
                  attack=0.001, release=0.025, rng=rng)
    write_wav("sfx_crack.wav", b)

    # Chitin turning a blade: hard, dismissive, no follow-through.
    b = buf(0.26)
    add_tone(b, 0, 0.09, 780, soft_square, vol=0.3, attack=0.001, release=0.07)
    add_tone(b, 0, 0.06, 1560, tri, vol=0.14, attack=0.001, release=0.05)
    add_noise(b, 0, 0.035, vol=0.22, lp=0.45, attack=0.0005, release=0.03, rng=rng)
    write_wav("sfx_guard.wav", b)

    # --- boss voices, from `squeak` -----------------------------------------
    # Each boss gets a pitch range and a texture of its own, so that even as
    # placeholders you can tell which animal is making the noise.

    def chirp(dur, f0, f1, vol=0.3, wave=None, at=0.0, buffer=None):
        sweep(buffer, at, dur, f0, f1, vol=vol, attack=0.005,
              release=max(0.03, dur * 0.4))

    # Rat: high, rodent, two-part. Closest to the old squeak, which was
    # always really a rat sound doing five other jobs.
    b = buf(0.5)
    chirp(0.14, 2500, 1500, 0.3, at=0.0, buffer=b)
    chirp(0.2, 2800, 1250, 0.28, at=0.18, buffer=b)
    write_wav("sfx_rat_cry.wav", b)

    b = buf(0.3)
    chirp(0.16, 2200, 1350, 0.32, at=0.0, buffer=b)
    write_wav("sfx_rat_hurt.wav", b)

    b = buf(0.85)
    chirp(0.3, 2300, 700, 0.32, at=0.0, buffer=b)
    add_noise(b, 0.3, 0.35, vol=0.1, lp=0.55, attack=0.02, release=0.3, rng=rng)
    write_wav("sfx_rat_death.wav", b)

    # Cat: much lower and vowel-like, with vibrato. Nothing else in the game
    # sounds like a big animal.
    b = buf(0.55)
    add_tone(b, 0, 0.45, 620, tri, vol=0.3, attack=0.02, release=0.3, vib=0.06)
    add_tone(b, 0, 0.45, 930, sine, vol=0.1, attack=0.03, release=0.3, vib=0.06)
    write_wav("sfx_cat_hurt.wav", b)

    b = buf(1.2)
    sweep(b, 0, 0.95, 700, 300, vol=0.3, attack=0.03, release=0.6)
    add_tone(b, 0, 0.8, 1050, tri, vol=0.08, attack=0.05, release=0.5, vib=0.08)
    write_wav("sfx_cat_death.wav", b)

    # Mantis: no pitch to speak of, just dry clicking. Insect, not animal.
    def clicks(buffer, start, count, spread, vol, rng_):
        for i in range(count):
            at = start + i * spread * rng_.uniform(0.7, 1.3)
            add_noise(buffer, at, 0.012, vol=vol * rng_.uniform(0.7, 1.1),
                      lp=0.12, attack=0.0004, release=0.01, rng=rng_)

    b = buf(0.6)
    clicks(b, 0.0, 9, 0.045, 0.3, rng)
    add_noise(b, 0.0, 0.4, vol=0.06, lp=0.1, attack=0.03, release=0.3, rng=rng)
    write_wav("sfx_mantis_cry.wav", b)

    b = buf(0.34)
    add_noise(b, 0, 0.04, vol=0.34, lp=0.2, attack=0.0005, release=0.03, rng=rng)
    clicks(b, 0.03, 4, 0.04, 0.2, rng)
    write_wav("sfx_mantis_hurt.wav", b)

    b = buf(0.95)
    clicks(b, 0.0, 14, 0.055, 0.24, rng)
    sweep(b, 0.0, 0.5, 300, 120, vol=0.1, attack=0.02, release=0.4)
    write_wav("sfx_mantis_death.wav", b)

    # Wasp: buzz, which means amplitude modulation rather than a tone.
    def buzz(buffer, start, dur, f0, f1, vol, rng_):
        n0 = int(start * SR)
        n = int(dur * SR)
        phase = 0.0
        for i in range(n):
            idx = n0 + i
            if idx >= len(buffer):
                break
            t = i / SR
            f = f0 + (f1 - f0) * (t / dur)
            phase += TAU * f / SR
            am = 0.55 + 0.45 * math.sin(TAU * 62.0 * t)
            e = min(1.0, t / 0.01) * min(1.0, (dur - t) / (dur * 0.35))
            buffer[idx] += math.tanh(2.0 * math.sin(phase)) * am * vol * max(0.0, e)

    b = buf(0.4)
    buzz(b, 0, 0.3, 220, 420, 0.26, rng)
    write_wav("sfx_wasp_hurt.wav", b)

    b = buf(1.0)
    buzz(b, 0, 0.85, 260, 70, 0.26, rng)
    write_wav("sfx_wasp_death.wav", b)

    # Spider Queen: layered chittering, the nastiest of the five.
    b = buf(0.6)
    clicks(b, 0.0, 12, 0.038, 0.2, rng)
    add_noise(b, 0.0, 0.45, vol=0.13, lp=0.35, attack=0.01, release=0.35, rng=rng)
    sweep(b, 0.0, 0.4, 1500, 900, vol=0.07, attack=0.01, release=0.3)
    write_wav("sfx_queen_drop.wav", b)

    b = buf(0.45)
    clicks(b, 0.0, 7, 0.03, 0.22, rng)
    add_tone(b, 0, 0.22, 1750, tri, vol=0.15, attack=0.004, release=0.18, vib=0.1)
    write_wav("sfx_queen_hurt.wav", b)

    b = buf(1.35)
    clicks(b, 0.0, 18, 0.05, 0.22, rng)
    sweep(b, 0.0, 0.7, 1800, 420, vol=0.18, attack=0.01, release=0.5)
    # Strands letting go as she falls.
    for i in range(5):
        sweep(b, 0.25 + i * 0.16, 0.09, 2600, 1500, vol=0.09,
              attack=0.001, release=0.07)
    write_wav("sfx_queen_death.wav", b)


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

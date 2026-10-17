import numpy as np
import wave
import math
import os

SR = 44100
BPM = 128.0
BEAT_DUR = 60.0 / BPM          # ~0.46875s
SIXTEENTH_DUR = BEAT_DUR / 4.0  # ~0.1171875s
TOTAL_BARS = 32
TOTAL_BEATS = TOTAL_BARS * 4
TOTAL_SECONDS = TOTAL_BEATS * BEAT_DUR  # Exactly 60.0 seconds!
TOTAL_SAMPLES = int(round(TOTAL_SECONDS * SR))

print(f"Generating Soundtrack: {TOTAL_BARS} bars, {BPM} BPM, {TOTAL_SECONDS:.2f}s, {TOTAL_SAMPLES} samples")

# Audio buffers: Stereo (2, TOTAL_SAMPLES)
mix_left = np.zeros(TOTAL_SAMPLES, dtype=np.float32)
mix_right = np.zeros(TOTAL_SAMPLES, dtype=np.float32)

def note_freq(name):
    notes = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4,
             'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9,
             'A#': 10, 'Bb': 10, 'B': 11}
    letter = name[:-1]
    octave = int(name[-1])
    semitone = notes[letter] + (octave + 1) * 12
    return 440.0 * (2.0 ** ((semitone - 69) / 12.0))

def add_audio(buf_l, buf_r, start_sec, pan, vol, left_chan, right_chan=None):
    if right_chan is None:
        right_chan = left_chan
    start_idx = int(round(start_sec * SR))
    n = len(left_chan)
    if start_idx >= TOTAL_SAMPLES:
        return
    end_idx = min(start_idx + n, TOTAL_SAMPLES)
    valid_len = end_idx - start_idx
    
    # Pan: -1 (left) to +1 (right)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    
    buf_l[start_idx:end_idx] += left_chan[:valid_len] * (vol * pan_l)
    buf_r[start_idx:end_idx] += right_chan[:valid_len] * (vol * pan_r)

# ==============================================================================
# 1. DRUMS SYNTHESIS
# ==============================================================================

def synth_taiko(dur=0.45, start_pitch=145.0, end_pitch=46.0):
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    # Exponential pitch decay
    freq = end_pitch + (start_pitch - end_pitch) * np.exp(-t * 22.0)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    
    # Body + resonance
    body = np.sin(phase) + 0.35 * np.sin(phase * 1.85) + 0.15 * np.sin(phase * 2.7)
    # Attack click
    noise = np.random.uniform(-1.0, 1.0, n) * np.exp(-t * 70.0)
    
    env = np.exp(-t * 8.0)
    taiko = (body * 0.85 + noise * 0.15) * env
    # Soft saturation
    return np.tanh(taiko * 1.4)

def synth_snare(dur=0.28):
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    # Tone
    tone = np.sin(2.0 * np.pi * 185.0 * t) * np.exp(-t * 28.0)
    # Crisp noise
    noise = np.random.uniform(-1.0, 1.0, n) * np.exp(-t * 16.0)
    # Mid-pass resonance
    filtered_noise = np.convolve(noise, [0.3, -0.1, 0.4, 0.2, -0.2], mode='same')
    snare = (tone * 0.45 + filtered_noise * 0.55)
    return np.tanh(snare * 1.5)

def synth_hihat(dur=0.06, open_hat=False):
    if open_hat:
        dur = 0.22
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    # Metallic frequencies
    metallic = (np.sin(2*np.pi*3200*t) + np.sin(2*np.pi*4800*t) + 
                np.sin(2*np.pi*6700*t) + np.sin(2*np.pi*8900*t)) * 0.2
    noise = np.random.uniform(-1.0, 1.0, n)
    decay_rate = 14.0 if open_hat else 75.0
    env = np.exp(-t * decay_rate)
    return (noise * 0.7 + metallic * 0.3) * env

# Pre-render drum sounds
taiko_strong = synth_taiko(dur=0.55, start_pitch=150, end_pitch=45)
taiko_accent = synth_taiko(dur=0.35, start_pitch=190, end_pitch=65)
snare_hit = synth_snare()
hihat_closed = synth_hihat(open_hat=False)
hihat_open = synth_hihat(open_hat=True)

# ==============================================================================
# 2. STRING (KOTO / SHAMISEN) SYNTHESIS - Karplus-Strong
# ==============================================================================

def synth_koto_note(freq, dur=0.6, pluck_bright=0.85):
    n = int(dur * SR)
    buffer_len = int(round(SR / freq))
    if buffer_len < 2:
        buffer_len = 2
    
    # Excitation noise with high-frequency emphasis
    noise = np.random.uniform(-1.0, 1.0, buffer_len).astype(np.float32)
    # Karplus-Strong loop
    out = np.zeros(n, dtype=np.float32)
    out[:buffer_len] = noise
    
    decay_factor = 0.988 - (freq / 4000.0) * 0.02
    decay_factor = max(0.95, min(0.995, decay_factor))
    
    ptr = 0
    prev_sample = 0.0
    for i in range(buffer_len, n):
        idx = i % buffer_len
        prev_idx = (idx - 1) % buffer_len
        # Low-pass filtering in feedback loop creates realistic string dampening
        new_val = (out[idx] + out[prev_idx]) * 0.5 * decay_factor
        out[i] = new_val
    
    # Envelope smoothing
    t = np.linspace(0, dur, n, endpoint=False)
    env = np.exp(-t * 2.5)
    return out * env

# ==============================================================================
# 3. SHAKUHACHI / BAMBOO FLUTE SYNTHESIS
# ==============================================================================

def synth_flute_note(freq, dur=1.2, vibrato_depth=0.025, vibrato_speed=5.2):
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    
    # Vibrato starts after 0.2 seconds
    vib_env = np.clip((t - 0.2) / 0.3, 0.0, 1.0)
    pitch_mod = 1.0 + vibrato_depth * vib_env * np.sin(2.0 * np.pi * vibrato_speed * t)
    
    inst_freq = freq * pitch_mod
    phase = 2.0 * np.pi * np.cumsum(inst_freq) / SR
    
    # Bamboo tone: strong odd harmonics + warm even harmonics + breath noise
    sine1 = np.sin(phase)
    sine2 = 0.28 * np.sin(phase * 2.0)
    sine3 = 0.18 * np.sin(phase * 3.0)
    sine4 = 0.08 * np.sin(phase * 4.0)
    
    tone = sine1 + sine2 + sine3 + sine4
    # Breathy whisper
    breath = np.random.uniform(-0.15, 0.15, n) * (0.8 + 0.2 * np.sin(phase))
    
    # ADSR Envelope
    attack_samples = int(0.08 * SR)
    release_samples = int(0.18 * SR)
    env = np.ones(n, dtype=np.float32)
    env[:attack_samples] = np.linspace(0.0, 1.0, attack_samples)
    env[-release_samples:] = np.linspace(1.0, 0.0, release_samples)
    
    return (tone * 0.85 + breath * 0.15) * env

# ==============================================================================
# 4. CYBER-SAMURAI BASS SYNTHESIS
# ==============================================================================

def synth_bass_note(freq, dur=SIXTEENTH_DUR * 1.8):
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    
    # Sub sine + warm sawtooth
    sub = np.sin(2.0 * np.pi * freq * t)
    saw = 0.0
    for h in range(1, 6):
        saw += (1.0 / h) * np.sin(2.0 * np.pi * freq * h * t)
    saw *= 0.4
    
    raw_bass = sub * 0.7 + saw * 0.3
    # Punchy envelope with fast decay
    env = np.exp(-t * 9.5)
    
    # Soft overdrive
    return np.tanh(raw_bass * env * 2.2) * 0.75

# ==============================================================================
# 5. METALLIC BLADE CLASH / RING SYNTHESIS
# ==============================================================================

def synth_blade_ring(dur=2.4):
    n = int(dur * SR)
    t = np.linspace(0, dur, n, endpoint=False)
    # High blade ring resonance
    ring_freqs = [1760.0, 2480.0, 3120.0, 4250.0, 5820.0]
    weights = [0.4, 0.3, 0.2, 0.15, 0.08]
    
    sound = np.zeros(n, dtype=np.float32)
    for f, w in zip(ring_freqs, weights):
        sound += w * np.sin(2.0 * np.pi * f * t)
        
    # Strike whoosh transient
    strike = np.random.uniform(-1.0, 1.0, n) * np.exp(-t * 80.0) * 0.3
    
    env = np.exp(-t * 2.2)
    blade = (sound * env + strike)
    return blade * 0.6

blade_ring_sample = synth_blade_ring()

# ==============================================================================
# 6. SONG COMPOSITION: 32 BARS OF MARTIAL ARTS BATTLE ENERGY
# ==============================================================================

print("Composing 32-Bar martial arts theme...")

# Bar time helper
def bar_time(bar_idx, beat_offset=0.0):
    return (bar_idx * 4.0 + beat_offset) * BEAT_DUR

# Katana Blade Rings on key structural points
for bar in [0, 8, 16, 24, 30]:
    add_audio(mix_left, mix_right, bar_time(bar, 0.0), 0.3, 0.75, blade_ring_sample)
    add_audio(mix_left, mix_right, bar_time(bar, 0.05), -0.3, 0.65, blade_ring_sample)

# --- DRUM PATTERNS ---
for bar in range(TOTAL_BARS):
    # Bars 0-7: Intro (Sparse heavy taiko + hi-hat buildup)
    if bar < 8:
        # Taiko on 1 and 3
        add_audio(mix_left, mix_right, bar_time(bar, 0.0), 0.0, 0.85, taiko_strong)
        if bar >= 4:
            add_audio(mix_left, mix_right, bar_time(bar, 2.0), -0.15, 0.75, taiko_accent)
            add_audio(mix_left, mix_right, bar_time(bar, 3.5), 0.15, 0.60, taiko_accent)
            # Snare on 2 and 4 from bar 4
            add_audio(mix_left, mix_right, bar_time(bar, 1.0), -0.1, 0.65, snare_hit)
            add_audio(mix_left, mix_right, bar_time(bar, 3.0), -0.1, 0.70, snare_hit)
            
        # Closed hats
        if bar >= 2:
            for sixteenth in range(16):
                t_sec = bar_time(bar, sixteenth * 0.25)
                vol = 0.45 if (sixteenth % 4 == 2) else 0.25
                add_audio(mix_left, mix_right, t_sec, 0.25, vol, hihat_closed)
                
    # Bars 8-31: FULL BATTLE DRUM BEAT
    else:
        # Driving Taiko kicks on 1, 2.5, 3
        add_audio(mix_left, mix_right, bar_time(bar, 0.0), 0.0, 0.95, taiko_strong)
        add_audio(mix_left, mix_right, bar_time(bar, 1.5), -0.1, 0.70, taiko_accent)
        add_audio(mix_left, mix_right, bar_time(bar, 2.0), 0.0, 0.85, taiko_strong)
        add_audio(mix_left, mix_right, bar_time(bar, 2.75), 0.15, 0.65, taiko_accent)
        
        # Snappy War Snare on 2 and 4
        add_audio(mix_left, mix_right, bar_time(bar, 1.0), -0.1, 0.85, snare_hit)
        add_audio(mix_left, mix_right, bar_time(bar, 3.0), -0.1, 0.90, snare_hit)
        
        # Ghost snare roll at end of every 2nd bar
        if bar % 2 == 1:
            add_audio(mix_left, mix_right, bar_time(bar, 3.5), -0.1, 0.45, snare_hit)
            add_audio(mix_left, mix_right, bar_time(bar, 3.75), -0.1, 0.65, snare_hit)
            
        # 16th-note Hi-hat groove with accents
        for sixteenth in range(16):
            t_sec = bar_time(bar, sixteenth * 0.25)
            if sixteenth in [2, 6, 10, 14]: # Offbeats
                add_audio(mix_left, mix_right, t_sec, 0.25, 0.65, hihat_open)
            else:
                vol = 0.40 if (sixteenth % 2 == 0) else 0.25
                add_audio(mix_left, mix_right, t_sec, 0.25, vol, hihat_closed)
                
    # Climax frenzy drum rolls in bars 28-31
    if bar >= 28:
        add_audio(mix_left, mix_right, bar_time(bar, 0.5), -0.3, 0.55, taiko_accent)
        add_audio(mix_left, mix_right, bar_time(bar, 1.75), 0.3, 0.60, taiko_accent)
        add_audio(mix_left, mix_right, bar_time(bar, 3.25), -0.2, 0.65, taiko_accent)

# --- CYBER BASSLINE (Bars 4 - 31) ---
# Japanese D minor / Insen root movement: D -> C -> Bb -> A
chord_roots = [
    note_freq("D2"), note_freq("D2"), note_freq("C2"), note_freq("C2"),
    note_freq("Bb1"), note_freq("Bb1"), note_freq("A1"), note_freq("A1")
]

for bar in range(4, TOTAL_BARS):
    root = chord_roots[(bar - 4) % 8]
    # Rhythmic syncopated 16th bassline: [X . X .  X . . X  . X . X  X . X .]
    bass_steps = [0, 2, 4, 7, 9, 11, 12, 14]
    for step in bass_steps:
        pitch = root
        if step in [7, 14]:
            pitch = root * 1.5 # 5th harmonic punch
        b_sample = synth_bass_note(pitch, dur=SIXTEENTH_DUR * 1.7)
        t_sec = bar_time(bar, step * 0.25)
        add_audio(mix_left, mix_right, t_sec, 0.0, 0.85, b_sample)

# --- KOTO / SHAMISEN MELODIC MOTIF ---
# Authentic D Insen pentatonic melody: D4, Eb4, G4, A4, C5, D5
motif_1 = [
    ("D4", 0.0, 0.7), ("Eb4", 0.5, 0.65), ("G4", 1.0, 0.75), ("A4", 1.5, 0.85),
    ("G4", 2.0, 0.7), ("Eb4", 2.5, 0.65), ("D4", 3.0, 0.9),
    ("D4", 4.0, 0.7), ("F4", 4.5, 0.7), ("G4", 5.0, 0.8), ("A4", 5.5, 0.9),
    ("C5", 6.0, 0.85), ("A4", 6.5, 0.75), ("G4", 7.0, 0.8)
]

# Play motif across intro (bars 0-7) and battle beat (bars 8-15) and outro (bars 24-31)
for start_bar in [0, 8, 24]:
    for note, beat_offset, vol in motif_1:
        if start_bar + int(beat_offset // 4) < TOTAL_BARS:
            f = note_freq(note)
            k_sample = synth_koto_note(f, dur=0.85)
            t_sec = bar_time(start_bar, beat_offset)
            # Dual-panned stereo koto
            add_audio(mix_left, mix_right, t_sec, -0.35, vol * 0.8, k_sample)
            # Soft delay echo on right
            add_audio(mix_left, mix_right, t_sec + SIXTEENTH_DUR * 1.5, 0.40, vol * 0.35, k_sample)

# Counterpoint rapid arpeggio in Section B (bars 8-15)
koto_arp = ["D4", "G4", "A4", "D5", "Eb5", "D5", "A4", "G4"]
for bar in range(8, 16):
    for i, n_name in enumerate(koto_arp):
        f = note_freq(n_name)
        k_note = synth_koto_note(f, dur=0.35)
        t_sec = bar_time(bar, i * 0.5)
        add_audio(mix_left, mix_right, t_sec, 0.35, 0.50, k_note)

# --- SHAKUHACHI / BAMBOO FLUTE (Bars 16 - 27) ---
# Soaring emotional ninja duel melody
flute_melody = [
    # Bar 16-17: D5 -> A4 -> G4
    ("D5", 0.0, 1.8), ("A4", 2.0, 1.4), ("G4", 4.0, 1.8), ("Eb4", 6.0, 1.5),
    # Bar 18-19: D4 -> G4 -> A4 -> C5 -> D5
    ("D4", 8.0, 1.2), ("G4", 9.5, 1.0), ("A4", 11.0, 1.4), ("C5", 13.0, 1.5), ("D5", 14.5, 2.2),
    # Bar 20-21: Eb5 -> D5 -> C5 -> A4
    ("Eb5", 16.0, 1.8), ("D5", 18.0, 1.4), ("C5", 20.0, 1.6), ("A4", 22.0, 1.5),
    # Bar 22-23: G4 -> A4 -> D5 -> (climax sustain)
    ("G4", 24.0, 1.2), ("A4", 25.5, 1.4), ("C5", 27.0, 1.4), ("D5", 28.5, 3.2)
]

for note, beat_offset, dur_beats in flute_melody:
    bar_num = 16 + int(beat_offset // 4)
    if bar_num < TOTAL_BARS:
        f = note_freq(note)
        fl_sample = synth_flute_note(f, dur=dur_beats * BEAT_DUR)
        t_sec = bar_time(16, beat_offset)
        # Center-stage flute with lush stereo space
        add_audio(mix_left, mix_right, t_sec, -0.05, 0.95, fl_sample)
        # Reverb / stereo echo
        add_audio(mix_left, mix_right, t_sec + 0.12, 0.25, 0.35, fl_sample)
        add_audio(mix_left, mix_right, t_sec + 0.24, -0.25, 0.20, fl_sample)

# ==============================================================================
# 7. MASTERING & SEAMLESS LOOP NORMALIZATION
# ==============================================================================

print("Mastering & normalizing soundtrack...")

# Crossfade loop endpoints: smooth 50ms at start and end to guarantee ZERO clicks
crossfade_len = int(0.06 * SR)
fade_in = np.linspace(0.0, 1.0, crossfade_len)
fade_out = np.linspace(1.0, 0.0, crossfade_len)

# Apply gentle wrap-around loop overlap
mix_left[:crossfade_len] += mix_left[-crossfade_len:] * fade_out
mix_right[:crossfade_len] += mix_right[-crossfade_len:] * fade_out
mix_left[-crossfade_len:] = mix_left[:crossfade_len] * fade_in + mix_left[-crossfade_len:] * fade_out
mix_right[-crossfade_len:] = mix_right[:crossfade_len] * fade_in + mix_right[-crossfade_len:] * fade_out

# Peak limiter / soft clipper
max_peak = max(np.max(np.abs(mix_left)), np.max(np.abs(mix_right)))
print(f"Pre-master Peak: {max_peak:.2f}")

if max_peak > 0:
    # Normalize to 0.88 (-1.1 dB)
    target_scale = 0.88 / max_peak
    mix_left = np.tanh(mix_left * target_scale * 1.1)
    mix_right = np.tanh(mix_right * target_scale * 1.1)

# Convert to 16-bit PCM
pcm_left = (mix_left * 32767.0).clip(-32768, 32767).astype(np.int16)
pcm_right = (mix_right * 32767.0).clip(-32768, 32767).astype(np.int16)

# Interleave stereo
stereo_data = np.empty((TOTAL_SAMPLES * 2,), dtype=np.int16)
stereo_data[0::2] = pcm_left
stereo_data[1::2] = pcm_right

output_path = "audio/menu_bgm.wav"
with wave.open(output_path, "wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    wf.writeframes(stereo_data.tobytes())

print(f"SUCCESS! Exported {output_path} ({os.path.getsize(output_path)} bytes, {TOTAL_SECONDS:.1f}s)")

# Pre-render blade UI sound effects
def export_sfx(filename, samples):
    pcm = (samples * 32767.0).clip(-32768, 32767).astype(np.int16)
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())

# UI Hover: Swift katana whoosh + high harmonic chime (0.09s)
t_hov = np.linspace(0, 0.09, int(0.09 * SR), endpoint=False)
whoosh = np.random.uniform(-0.5, 0.5, len(t_hov)) * np.exp(-t_hov * 45.0)
chime = (0.3 * np.sin(2*np.pi*2400*t_hov) + 0.2 * np.sin(2*np.pi*3600*t_hov)) * np.exp(-t_hov * 30.0)
hover_sfx = np.tanh((whoosh + chime) * 2.0) * 0.7
export_sfx("audio/ui_hover.wav", hover_sfx)
print("SUCCESS! Exported audio/ui_hover.wav")

# UI Click: Katana blade clash / guard impact with ringing resonance (0.16s)
t_clk = np.linspace(0, 0.16, int(0.16 * SR), endpoint=False)
impact = np.sin(2*np.pi*280*t_clk) * np.exp(-t_clk * 55.0)
blade_clash = (0.5 * np.sin(2*np.pi*1850*t_clk) + 0.35 * np.sin(2*np.pi*3100*t_clk) + 0.2 * np.sin(2*np.pi*4800*t_clk)) * np.exp(-t_clk * 20.0)
click_noise = np.random.uniform(-0.6, 0.6, len(t_clk)) * np.exp(-t_clk * 85.0)
click_sfx = np.tanh((impact * 0.4 + blade_clash * 0.5 + click_noise * 0.3) * 2.2) * 0.85
export_sfx("audio/ui_click.wav", click_sfx)
print("SUCCESS! Exported audio/ui_click.wav")

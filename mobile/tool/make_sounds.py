"""Pravi zvučne efekte igre (sintetizovani, bez tuđih snimaka).

Pokretanje:  python3 tool/make_sounds.py   → assets/sounds/*.wav
"""
import math, os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(25)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.2, curve=4.0):
    """Brz napad, eksponencijalno opadanje."""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dec = np.exp(-curve * x / max(d, 1e-4))
    return att * dec


def tone(f, d, harm=((1, 1.0),), a=0.004, decay=0.25, curve=4.0, bend=0.0):
    x = t(d)
    freq = f * (1 + bend * x / d)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    s = sum(amp * np.sin(k * ph) for k, amp in harm)
    return s * env(len(x), a, decay, curve)


def bell(f, d=0.6, decay=0.35):
    return tone(f, d, harm=((1, 1), (2.76, 0.35), (5.4, 0.12), (8.9, 0.05)), decay=decay, curve=3.2)


def marimba(f, d=0.35, decay=0.18):
    return tone(f, d, harm=((1, 1), (4, 0.25), (9.2, 0.06)), a=0.002, decay=decay, curve=4.5)


def noise(d, decay=0.03, lp=0.3):
    n = rng.standard_normal(int(SR * d))
    # jednostavan niskopropusni filter
    y = np.zeros_like(n)
    for i in range(1, len(n)):
        y[i] = y[i - 1] + lp * (n[i] - y[i - 1])
    return y * env(len(n), 0.0005, decay, 5)


def seq(parts):
    """parts: [(start_sec, signal, gain)]"""
    end = max(s + len(sig) / SR for s, sig, _ in parts)
    out = np.zeros(int(SR * end) + 1)
    for s, sig, g in parts:
        i = int(SR * s)
        out[i:i + len(sig)] += g * sig
    return out


def save(name, sig, gain=0.9):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * gain
    fade = min(len(sig), int(SR * 0.01))
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)


N = lambda m: 440 * 2 ** ((m - 69) / 12)  # MIDI → Hz
C5, D5, E5, G5, A5, C6, E6, G6 = (N(m) for m in (72, 74, 76, 79, 81, 84, 88, 91))

os.makedirs(OUT, exist_ok=True)
# Dodir slova / polja: kratak drveni „tik“
save('tap', seq([(0, marimba(N(83), 0.09, 0.03), 1.0), (0, noise(0.02, 0.006, 0.6), 0.25)]), 0.55)
# Postavljanje pločice na tablu: tup „klak“ drveta
save('place', seq([(0, marimba(N(64), 0.16, 0.05), 1.0), (0, marimba(N(76), 0.12, 0.03), 0.35), (0, noise(0.04, 0.01, 0.35), 0.6)]), 0.8)
# Protivnik je odigrao / ti si na potezu: dva mekana tona naviše
save('turn', seq([(0, bell(G5, 0.35, 0.18), 1.0), (0.11, bell(C6, 0.55, 0.28), 1.0)]), 0.7)
# Otkucaj poslednjih sekundi
save('tick', seq([(0, tone(N(93), 0.06, harm=((1, 1), (3, 0.2)), decay=0.02), 1.0)]), 0.5)
# Izgubljen život: silazni ton + tup udarac
save('life_lost', seq([(0, tone(330, 0.45, harm=((1, 1), (2, 0.5), (3, 0.3)), decay=0.35, curve=2.5, bend=-0.45), 1.0),
                       (0, marimba(90, 0.3, 0.12), 0.8)]), 0.85)
# Pronađen protivnik / početak partije: brzi akord naviše
save('start', seq([(0.00, marimba(C5, 0.3), 1), (0.07, marimba(E5, 0.3), 1), (0.14, marimba(G5, 0.3), 1),
                   (0.21, bell(C6, 0.7, 0.4), 1.1)]), 0.8)
# Pobeda: fanfara
save('win', seq([(0.00, bell(C5, 0.5), 1), (0.12, bell(E5, 0.5), 1), (0.24, bell(G5, 0.5), 1),
                 (0.40, bell(C6, 1.3, 0.8), 1.2), (0.40, bell(E6, 1.3, 0.8), 0.6), (0.40, bell(G6, 1.3, 0.8), 0.35)]), 0.85)
# Poraz: tri tona naniže
save('lose', seq([(0.00, tone(G5 / 2, 0.45, harm=((1, 1), (2, 0.4)), decay=0.3), 1),
                  (0.22, tone(E5 / 2, 0.45, harm=((1, 1), (2, 0.4)), decay=0.3), 1),
                  (0.44, tone(C5 / 2, 0.9, harm=((1, 1), (2, 0.4)), decay=0.6, bend=-0.03), 1.1)]), 0.75)
# Nerešeno
save('draw', seq([(0, bell(E5, 0.5, 0.3), 1), (0.18, bell(E5, 0.7, 0.4), 0.9)]), 0.7)
# Novčić (dnevna nagrada)
save('coin', seq([(0, bell(N(83), 0.25, 0.1), 1), (0.08, bell(N(88), 0.7, 0.35), 1.1)]), 0.75)
# Medalja: svečani akord sa svetlucanjem
spark = [(0.5 + i * 0.06, bell(N(96 + (i % 3) * 3), 0.25, 0.08), 0.35) for i in range(6)]
save('medal', seq([(0.00, bell(G5, 0.6), 1), (0.10, bell(C6, 0.6), 1), (0.20, bell(E6, 1.4, 0.9), 1.1),
                   (0.20, bell(G6, 1.4, 0.9), 0.5)] + spark), 0.85)
print('ok', sorted(os.listdir(OUT)))

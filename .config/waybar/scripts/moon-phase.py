#!/usr/bin/env python3
import json
import math
from datetime import datetime


def get_moon_phase():
    # Known new moon date
    known_new_moon = datetime(2000, 1, 6, 18, 14, 0)
    now = datetime.now()

    # Calculate phase (0 = new moon, 0.5 = full moon, 1 = new moon again)
    seconds_since_new = (now - known_new_moon).total_seconds()
    synodic_month = 29.530588853  # days
    phase = (seconds_since_new / (synodic_month * 86400)) % 1

    # Icons with exact phase boundaries
    phases = [
        (0.0625, "🌑", "New Moon"),
        (0.1875, "🌒", "Waxing Crescent"),
        (0.3125, "🌓", "First Quarter"),
        (0.4375, "🌔", "Waxing Gibbous"),
        (0.5625, "🌕", "Full Moon"),
        (0.6875, "🌖", "Waning Gibbous"),
        (0.8125, "🌗", "Last Quarter"),
        (0.9375, "🌘", "Waning Crescent"),
        (1.0000, "🌑", "New Moon"),
    ]

    for threshold, icon, name in phases:
        if phase < threshold:
            illumination = int(50 * (1 - math.cos(2 * math.pi * phase)))
            tooltip = f"{name} ({illumination}% illuminated)"
            print(json.dumps({"text": icon, "tooltip": tooltip}))
            break


get_moon_phase()

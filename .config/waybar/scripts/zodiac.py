#!/usr/bin/env python3
import json
from datetime import datetime


def get_zodiac():
    now = datetime.now()
    month = now.month
    day = now.day

    # Zodiac signs with dates and symbols
    zodiacs = [
        ((3, 21), (4, 19), "♈", "Aries"),
        ((4, 20), (5, 20), "♉", "Taurus"),
        ((5, 21), (6, 20), "♊", "Gemini"),
        ((6, 21), (7, 22), "♋", "Cancer"),
        ((7, 23), (8, 22), "♌", "Leo"),
        ((8, 23), (9, 22), "♍", "Virgo"),
        ((9, 23), (10, 22), "♎", "Libra"),
        ((10, 23), (11, 21), "♏", "Scorpio"),
        ((11, 22), (12, 21), "♐", "Sagittarius"),
        ((12, 22), (1, 19), "♑", "Capricorn"),
        ((1, 20), (2, 18), "♒", "Aquarius"),
        ((2, 19), (3, 20), "♓", "Pisces"),
    ]

    for start, end, symbol, name in zodiacs:
        start_month, start_day = start
        end_month, end_day = end

        # Handle zodiac signs that span across year boundary
        if start_month > end_month:  # Capricorn case
            if month == start_month and day >= start_day:
                return json.dumps({"text": symbol, "tooltip": name})
            elif month == end_month and day <= end_day:
                return json.dumps({"text": symbol, "tooltip": name})
        elif (
            (month == start_month and day >= start_day)
            or (month == end_month and day <= end_day)
            or (start_month < month < end_month)
        ):
            return json.dumps({"text": symbol, "tooltip": name})

    # Default (shouldn't reach here)
    return json.dumps({"text": "♓", "tooltip": "Pisces"})


print(get_zodiac())

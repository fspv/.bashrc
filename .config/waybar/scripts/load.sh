#!/bin/sh

awk '{printf "{\"text\": \"LA: %.0f\", \"tooltip\": \"Load average: %s %s %s\"}\n", $1, $1, $2, $3}' /proc/loadavg

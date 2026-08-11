#!/bin/sh

free -b | awk '
/^Mem:/ {total = $2; used = $3; buff_cache = $6; available = $7}
/^Swap:/ {swap_total = $2; swap_used = $3}
END {
    printf "{\"text\": \"MEM: %.0f%%\", \"tooltip\": \"Used: %.1fG / %.1fG\\nSwap: %.1fG / %.1fG\\nBuff/cache: %.1fG\"}\n",
        (total - available) / total * 100,
        used / 2^30, total / 2^30,
        swap_used / 2^30, swap_total / 2^30,
        buff_cache / 2^30
}'

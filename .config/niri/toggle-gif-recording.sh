#!/usr/bin/env bash

set -euo pipefail

state_dir="/tmp/niri-gif-recorder"
pid_file="$state_dir/wf-recorder.pid"
temp_file="$state_dir/current.mp4"

mkdir -p "$state_dir"

notify_done() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "GIF 录制" "$1"
    fi
}

next_output() {
    local index=1
    local candidate

    while :; do
        printf -v candidate "/tmp/demo-%03d.gif" "$index"
        if [[ ! -e "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
        ((index++))
    done
}

cleanup() {
    rm -f "$pid_file" "$temp_file"
}

if [[ -f "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    if kill -0 "$pid" >/dev/null 2>&1; then
        output="$(next_output)"

        kill -INT "$pid"
        for _ in {1..100}; do
            if ! kill -0 "$pid" >/dev/null 2>&1; then
                break
            fi
            sleep 0.1
        done

        ffmpeg -y -i "$temp_file" \
            -vf "fps=12,scale=iw:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse" \
            "$output"

        rm -f "$temp_file" "$pid_file"
        notify_done "已保存到 $output"
        exit 0
    fi

    cleanup
fi

geometry="$(slurp)"
if [[ -z "$geometry" ]]; then
    exit 0
fi

rm -f "$temp_file"

wf-recorder -g "$geometry" -f "$temp_file" >/dev/null 2>&1 &
echo "$!" > "$pid_file"

#!/usr/bin/env bash

set -euo pipefail

state_dir="/tmp/niri-gif-recorder"
pid_file="$state_dir/wf-recorder.pid"
log_file="$state_dir/recorder.log"
temp_file="$state_dir/current.mp4"

mkdir -p "$state_dir"

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send "GIF 录制" "$1" || true
}

next_output() {
    local index=1
    local candidate
    while :; do
        printf -v candidate "/tmp/demo-%03d.gif" "$index"
        [[ ! -e "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
        ((index++))
    done
}

cleanup() {
    rm -f "$pid_file" "$temp_file"
}

get_niri_hints() {
    command -v niri >/dev/null 2>&1 || return 0
    niri msg --json windows 2>/dev/null \
        | jq -r '.[] | select(.geometry != null)
                  | "\(.geometry.x),\(.geometry.y) \(.geometry.width)x\(.geometry.height)"' \
        2>/dev/null \
        || true
}

# 等待 pid 进程退出，超时返回 1
wait_for_exit() {
    local pid="$1"
    local i
    for ((i = 0; i < 100; i++)); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    return 1   # 10 秒仍未退出
}

stop_and_convert() {
    local pid="$1"
    local output
    output="$(next_output)"

    kill -INT "$pid"

    if ! wait_for_exit "$pid"; then
        kill -9 "$pid" 2>/dev/null || true
        notify "wf-recorder 未响应，已强制终止"
        sleep 0.3
    fi

    sync

    if [[ ! -s "$temp_file" ]]; then
        notify "录制文件为空，跳过转换"
        cleanup
        return
    fi

    if ffmpeg -y -i "$temp_file" \
        -vf "fps=12,scale=iw:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse" \
        "$output" 2>>"$log_file"; then
        rm -f "$temp_file" "$pid_file"
        notify "已保存到 $output"
    else
        notify "GIF 转换失败，日志：$log_file"
        rm -f "$pid_file"
    fi
}

if [[ -f "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
        stop_and_convert "$pid"
        exit 0
    fi
    cleanup
fi

hints="$(get_niri_hints)"
if [[ -n "$hints" ]]; then
    geometry="$(printf '%s\n' "$hints" | slurp)"
else
    geometry="$(slurp)"
fi

[[ -z "$geometry" ]] && exit 0

rm -f "$temp_file"
wf-recorder -g "$geometry" -f "$temp_file" 2>>"$log_file" &
echo "$!" > "$pid_file"
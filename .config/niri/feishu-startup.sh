#!/bin/bash
feishu &
sleep 1
niri msg windows | grep -B1 'Title: ""' | grep -v focused | grep 'Window ID' | awk '{print $3}' | tr -d ':' | xargs -I{} niri msg action close-window --id {}
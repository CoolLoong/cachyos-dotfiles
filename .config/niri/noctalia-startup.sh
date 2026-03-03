#!/bin/bash

niri msg event-stream | while IFS= read -r line; do
    if echo "$line" | grep -q '"OutputsChanged"'; then
        qs -c noctalia-shell
        break
    fi
done
# Source - https://stackoverflow.com/a/78735454
# Posted by Atajanoviic, modified by community. See post 'Timeline' for change history
# Retrieved 2026-02-13, License - CC BY-SA 4.0

#!/bin/bash

if [ "$1" == "on" ]; then
    echo "Turning persistence mode ON and setting performance state..."
    sudo nvidia-smi -pm 1
    sudo nvidia-smi -lgc 1000,2100  # you can adjust clock speed here
    sudo modprobe -r nvidia_uvm && sudo modprobe nvidia_uvm
    echo "Persistence mode is ON."
elif [ "$1" == "off" ]; then
    echo "Turning persistence mode OFF and resetting performance state..."
    sudo nvidia-smi -pm 0
    sudo nvidia-smi -rgc
    sudo modprobe -r nvidia_uvm && sudo modprobe nvidia_uvm
    echo "Persistence mode is OFF."
else
    echo "Usage: $0 {on|off}"
    exit 1
fi

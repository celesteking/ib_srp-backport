#!/bin/bash

echo "Available disk space:"
df -k /
echo "Number of CPU cores: $(grep -c '^processor[[:blank:]]*:' /proc/cpuinfo)"

rm -rf linux-kernel
if [ -e /home/bart/software/linux-kernel ]; then
    repo=/home/bart/software/linux-kernel
else
    repo=https://github.com/bvanassche/linux.git
fi
git clone -n "$repo" linux-kernel || exit $?

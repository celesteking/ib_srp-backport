#!/bin/bash

for v in $(<"$(dirname "$0")/kernel_versions.txt"); do
    "$(dirname "$0")/build_v.sh" "$v" || exit $?
done

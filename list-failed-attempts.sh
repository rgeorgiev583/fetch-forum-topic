#!/bin/bash

[[ $# -lt 2 ]] && exit 1
hostname=$1
max_page_number=$2

comm <(find -type d -name ${hostname} | cut -d/ -f2 | sort) <(seq 1 ${max_page_number} | sort) | grep -v $'\t\t' | xargs echo
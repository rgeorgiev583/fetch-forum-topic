#!/bin/bash

max_job_count=$(grep -c ^processor /proc/cpuinfo)
spam_topic_page_url_template='http://forum.animes-bg.com/viewtopic.php?f=18&t=75541&start='
spam_step=15
spam_target_directory=.

while getopts :Hj:p:s:t: option
do
    case $option in
        H)
            span_hosts=-H
            ;;

        j)
            max_job_count=$OPTARG
            ;;

        p)
            spam_topic_page_url_template=$OPTARG
            ;;

        s)
            spam_step=$OPTARG
            ;;

        t)
            spam_target_directory=$OPTARG
            ;;
    esac
done

shift $((OPTIND - 1))

spam_max_page_number=$1
[[ -z $spam_max_page_number ]] && exit 1
shift

job_count=0
trap job_count=$((job_count - 1)) SIGUSR1

for spam_page_number in $(seq 1 $spam_max_page_number)
do
    while [[ $job_count -ge $max_job_count ]]
    do
        wait -n
    done

    spam_page_target_directory="${spam_target_directory}/${spam_page_number}"
    mkdir -p "${spam_page_target_directory}"
    [[ $? -ne 0 ]] && continue
    spam_offset=$(( spam_step * (spam_page_number - 1) ))
    job_count=$((job_count + 1))
    {
        wget -EkKp ${span_hosts} -o "${spam_page_target_directory}/wget-log" -P "${spam_page_target_directory}" "${spam_topic_page_url_template}${spam_offset}"
        kill -USR1 $$
    } &
done

while ! wait
do
    :
done
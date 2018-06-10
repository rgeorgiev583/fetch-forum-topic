#!/bin/bash

script_name=$0

max_job_count=$(grep -c ^processor /proc/cpuinfo)
spam_topic_page_url_template='http://forum.animes-bg.com/viewtopic.php?f=18&t=75541&start='
spam_topic_posts_step=15
target_directory=.

while getopts :Hj:p:s:t:v option
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
            spam_topic_posts_step=$OPTARG
            ;;

        t)
            target_directory=$OPTARG
            ;;

        v)
            is_verbose_mode=yes
            ;;
    esac
done

shift $((OPTIND - 1))

spam_topic_max_page_number=$1
if [[ -z $spam_topic_max_page_number ]]
then
    echo "${script_name}: no maximum page number specified"
    exit 1
fi
shift

function decrement_job_count
{
    job_count=$((job_count - 1))
    [[ -n $is_verbose_mode ]] && echo "Job with pid $! has just finished its execution (${job_count} more jobs remaining)." >&2
}

function wget_spam_topic_page_and_notify
{
    spam_topic_page_url=${spam_topic_page_url_template}${spam_topic_posts_offset}
    if [[ -n $is_verbose_mode ]]
    then
        echo "Starting the fetching of page ${spam_topic_page_number} into directory ${spam_topic_page_target_directory}..." >&2
        echo "URL: ${spam_topic_page_url}" >&2
    fi
    wget -EkKp ${span_hosts} -o "${spam_topic_page_target_directory}/wget-log" -P "${spam_topic_page_target_directory}" "${spam_topic_page_url}"
    [[ -n $is_verbose_mode ]] && echo "Finished the fetching of page ${spam_topic_page_number}." >&2
    kill -USR1 $$
}

job_count=0
trap decrement_job_count SIGUSR1

for spam_topic_page_number in $(seq 1 $spam_topic_max_page_number)
do
    while [[ $job_count -ge $max_job_count ]]
    do
        wait -n
    done

    spam_topic_page_target_directory="${target_directory}/${spam_topic_page_number}"
    mkdir -p "${spam_topic_page_target_directory}"
    [[ $? -ne 0 ]] && continue
    spam_topic_posts_offset=$(( spam_topic_posts_step * (spam_topic_page_number - 1) ))
    job_count=$((job_count + 1))
    [[ -n $is_verbose_mode ]] && echo "Starting a new background job (${job_count} jobs total)." >&2
    wget_spam_topic_page_and_notify &
done

while ! wait
do
    :
done
#!/bin/bash

script_name=$0

max_job_count=$(grep -c ^processor /proc/cpuinfo)
forum_topic_posts_step=15
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
            forum_topic_max_page_number=$OPTARG
            ;;

        s)
            forum_topic_posts_step=$OPTARG
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

forum_topic_page_url_template=$1
if [[ -z $forum_topic_page_url_template ]]
then
    echo "${script_name}: no base URL for forum topic pages specified"
    exit 1
fi
shift

if [[ -n $forum_topic_max_page_number ]]
then
    forum_topic_page_numbers=$(seq 1 $forum_topic_max_page_number)
else
    forum_topic_page_numbers=$@
fi

if [[ -z $forum_topic_page_numbers ]]
then
    echo "${script_name}: no range specified of forum topic pages to download"
    exit 2
fi

function decrement_job_count
{
    job_count=$((job_count - 1))
    [[ -n $is_verbose_mode ]] && echo "Job with pid $! has just finished its execution (${job_count} more jobs remaining)." >&2
}

function wget_forum_topic_page_and_notify
{
    forum_topic_page_url=${forum_topic_page_url_template}${forum_topic_posts_offset}
    if [[ -n $is_verbose_mode ]]
    then
        echo "Starting the fetching of page ${forum_topic_page_number} into directory ${forum_topic_page_target_directory}..." >&2
        echo "URL: ${forum_topic_page_url}" >&2
    fi
    wget -EkKp ${span_hosts} -o "${forum_topic_page_target_directory}/wget-log" -P "${forum_topic_page_target_directory}" "${forum_topic_page_url}"
    [[ -n $is_verbose_mode ]] && echo "Finished the fetching of page ${forum_topic_page_number}." >&2
    kill -USR1 $$
}

job_count=0
trap decrement_job_count SIGUSR1

for forum_topic_page_number in $forum_topic_page_numbers
do
    while [[ $job_count -ge $max_job_count ]]
    do
        wait -n
    done

    forum_topic_page_target_directory="${target_directory}/${forum_topic_page_number}"
    mkdir -p "${forum_topic_page_target_directory}"
    [[ $? -ne 0 ]] && continue
    forum_topic_posts_offset=$(( forum_topic_posts_step * (forum_topic_page_number - 1) ))
    job_count=$((job_count + 1))
    [[ -n $is_verbose_mode ]] && echo "Starting a new background job (${job_count} jobs total)." >&2
    wget_forum_topic_page_and_notify &
done

while ! wait
do
    :
done
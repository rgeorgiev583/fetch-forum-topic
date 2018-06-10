#!/bin/bash

spam_topic_page_url_template='http://forum.animes-bg.com/viewtopic.php?f=18&t=75541&start='
spam_step=15
spam_target_directory=.

while getopts :p:s:t: option
do
    case $option in
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

for spam_page_number in $(seq 1 $spam_max_page_number)
do
    spam_page_target_directory="${spam_target_directory}/${spam_page_number}"
    mkdir -p "${spam_page_target_directory}"
    [[ $? -ne 0 ]] && continue
    spam_offset=$(( spam_step * (spam_page_number - 1) ))
    wget -bEHkKp -o "${spam_page_target_directory}/wget-log" -P "${spam_page_target_directory}" "${spam_topic_page_url_template}${spam_offset}" > /dev/null
done
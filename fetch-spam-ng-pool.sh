#!/bin/bash

source /opt/scriptpool/queue/NamedPipeQueue.sh
source /opt/scriptpool/worker/BashWorker.sh
source /opt/scriptpool/pool/NamedPipePool.sh

scriptpool_input_pipe_name=~/.scriptpool/poolpipe

spam_topic_page_url_template='http://forum.animes-bg.com/viewtopic.php?f=18&t=75541&start='
spam_step=15
spam_target_directory=.
worker_count=$(grep -c ^processor /proc/cpuinfo)

while getopts :p:s:t:w: option
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

        w)
            worker_count=$OPTARG
            ;;
    esac
done

shift $(( OPTIND - 1 ))

spam_max_page_number=$1
[[ -z $spam_max_page_number ]] && exit 1
shift

Pool --workers=$worker_count &
sleep 1

for spam_page_number in $(seq 1 $spam_max_page_number)
do
    spam_page_target_directory="${spam_target_directory}/${spam_page_number}"
    mkdir -p "${spam_page_target_directory}"
    [[ $? -ne 0 ]] && continue
    spam_offset=$(( $spam_step * ($spam_page_number - 1) ))
    echo "wget -bEHkKp -o \"${spam_page_target_directory}/wget-log\" -P \"${spam_page_target_directory}\" \"${spam_topic_page_url_template}${spam_offset}\" > /dev/null" > $scriptpool_input_pipe_name
done

echo terminate_pool > $scriptpool_input_pipe_name
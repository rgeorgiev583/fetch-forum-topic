#!/bin/bash

script_name=$0
failure_list_filename=failures.lst

max_job_count=$(($(nproc) + 1))
forum_topic_min_page_number=1
forum_topic_posts_step=15
target_directory=.

while getopts :fHj:p:P:s:t:v option; do
	case $option in
	f)
		force=true
		;;

	H)
		span_hosts=-H
		;;

	j)
		max_job_count=$OPTARG
		;;

	p)
		forum_topic_page_range=$OPTARG
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

	*)
		echo "${script_name}: invalid options detected" >&2
		;;
	esac
done

shift $((OPTIND - 1))

forum_topic_page_url_template=$1
if [[ -z $forum_topic_page_url_template ]]; then
	echo "${script_name}: no base URL for forum topic pages specified" >&2
	exit 1
fi
shift

if [[ -f "${target_directory}/${failure_list_filename}" ]]; then
	echo "Found a list of failed downloads; will reattempt them..."
	failed_page_numbers=$(<"${target_directory}/${failure_list_filename}")
	echo "Pages for which download will be reattempted: ${failed_page_numbers}"
	forum_topic_page_numbers="${forum_topic_page_numbers} ${failed_page_numbers}"

	i=1
	while [[ -f "${target_directory}/${failure_list_filename}.${i}" ]]; do
		i=$((i + 1))
	done
	mv "${target_directory}/${failure_list_filename}" "${target_directory}/${failure_list_filename}.${i}"
fi

numeric_range_pattern='(([[:digit:]]+)\.\.)?([[:digit:]]+)'
if [[ -n $forum_topic_page_range && $forum_topic_page_range =~ $numeric_range_pattern ]]; then
	[[ -n ${BASH_REMATCH[2]} ]] && forum_topic_min_page_number=${BASH_REMATCH[2]}
	[[ -n ${BASH_REMATCH[3]} ]] && forum_topic_max_page_number=${BASH_REMATCH[3]}
fi

if [[ -n $forum_topic_min_page_number && -n $forum_topic_max_page_number ]]; then
	forum_topic_page_numbers="${forum_topic_page_numbers} $(seq "${forum_topic_min_page_number}" "${forum_topic_max_page_number}")"
else
	forum_topic_page_numbers="${forum_topic_page_numbers} $*"
fi

if [[ -z $forum_topic_page_numbers ]]; then
	echo "${script_name}: no range specified of forum topic pages to download" >&2
	exit 2
fi

function decrement_job_count() {
	job_count=$((job_count - 1))
	[[ -n $is_verbose_mode ]] && echo "Job with pid $! has just finished its execution (${job_count} more jobs remaining)."
}

function wget_forum_topic_page_and_notify() {
	forum_topic_page_url=${forum_topic_page_url_template}${forum_topic_posts_offset}
	if [[ -n $is_verbose_mode ]]; then
		echo "Starting the fetching of page ${forum_topic_page_number} into directory ${forum_topic_page_target_directory}..."
		echo "URL: ${forum_topic_page_url}"
	fi
	wget -EkKp ${span_hosts} -a "${forum_topic_page_target_directory}/wget-log" -P "${forum_topic_page_target_directory}" "${forum_topic_page_url}"
	forum_topic_page_host=$(echo "${forum_topic_page_url}" | cut -d/ -f3)
	if [[ ! -d "${forum_topic_page_target_directory}/${forum_topic_page_host}" ]]; then
		echo "${forum_topic_page_number}" >>"${target_directory}/${failure_list_filename}"
		echo "${script_name}: failed to fetch page ${forum_topic_page_number}" >&2
	else
		[[ -n $is_verbose_mode ]] && echo "Finished the fetching of page ${forum_topic_page_number}."
	fi
	kill -USR1 $$
}

job_count=0
trap decrement_job_count SIGUSR1

for forum_topic_page_number in $forum_topic_page_numbers; do
	while [[ $job_count -ge $max_job_count ]]; do
		wait -n
	done

	forum_topic_page_target_directory="${target_directory}/${forum_topic_page_number}"

	if [[ -z ${force} && -d ${forum_topic_page_target_directory} ]]; then
		continue
	fi

	if ! mkdir -p "${forum_topic_page_target_directory}"; then
		echo "${script_name}: could not create target directory for page ${forum_topic_page_number}" >&2
		continue
	fi

	forum_topic_posts_offset=$((forum_topic_posts_step * (forum_topic_page_number - 1)))
	job_count=$((job_count + 1))
	[[ -n $is_verbose_mode ]] && echo "Starting a new background job (${job_count} jobs total)."
	wget_forum_topic_page_and_notify &
done

while ! wait; do
	:
done

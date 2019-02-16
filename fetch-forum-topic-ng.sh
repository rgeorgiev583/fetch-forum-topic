#!/bin/bash

failure_list_file_basename=failures.lst
numeric_range_pattern='(([[:digit:]]+)\.\.)?([[:digit:]]+)'
forum_topic_min_page_number=1

max_job_count=$(($(nproc) + 1))
forum_topic_post_step=15
target_directory=.

while getopts :fHj:p:P:s:t:v option; do
	case ${option} in
	f)
		force=true
		;;

	H)
		span_hosts=-H
		;;

	j)
		max_job_count=${OPTARG}
		;;

	s)
		forum_topic_post_step=${OPTARG}
		;;

	t)
		target_directory=${OPTARG}
		;;

	v)
		is_verbose_mode=yes
		;;

	*)
		echo "error: invalid option: ${option}" >&2
		exit 2
		;;
	esac
done

shift $((OPTIND - 1))

forum_topic_page_url_template=$1
if [[ -z ${forum_topic_page_url_template} ]]; then
	echo "error: no base URL specified for forum topic pages" >&2
	exit 1
fi
shift

failure_list_filename=${target_directory}/${failure_list_file_basename}
if [[ -f ${failure_list_filename} ]]; then
	echo "Found a list of failed downloads; will reattempt them..."
	failed_page_numbers=$(<"${failure_list_filename}")

	echo "Pages for which download will be reattempted: ${failed_page_numbers//$'\n'/, }"
	forum_topic_page_numbers="${forum_topic_page_numbers} ${failed_page_numbers}"

	i=1
	while [[ -e ${failure_list_filename}.${i} ]]; do
		((i++))
	done
	if ! mv "${failure_list_filename}" "${failure_list_filename}.${i}"; then
		echo "error: failed to rename list of failed downloads from ${failure_list_filename} to ${failure_list_filename}.${i}" >&2
	fi
fi

for forum_topic_page_range; do
	if [[ ${forum_topic_page_range} =~ ${numeric_range_pattern} ]]; then
		if [[ -n ${BASH_REMATCH[2]} ]]; then
			forum_topic_page_range_from=${BASH_REMATCH[2]}
		else
			forum_topic_page_range_from=${forum_topic_min_page_number}
		fi
		forum_topic_page_range_to=${BASH_REMATCH[3]}
	else
		echo "error: invalid page range specification: ${forum_topic_page_range}" >&2
		exit 1
	fi

	forum_topic_page_numbers="${forum_topic_page_numbers} $(seq "${forum_topic_page_range_from}" "${forum_topic_page_range_to}")"
done

function decrement_job_count() {
	((job_count--))
	[[ -n ${is_verbose_mode} ]] && echo "Job with pid $! has just finished its execution (${job_count} more jobs remaining)."
}

function fetch_forum_topic_page_and_notify() {
	local forum_topic_page_number=$1
	local forum_topic_post_offset=$((forum_topic_post_step * (forum_topic_page_number - 1)))
	local forum_topic_page_url=${forum_topic_page_url_template}${forum_topic_post_offset}
	local forum_topic_page_target_directory="${target_directory}/${forum_topic_page_number}"

	if [[ -n ${is_verbose_mode} ]]; then
		echo "Starting the fetching of page ${forum_topic_page_number} into directory ${forum_topic_page_target_directory}..."
		echo "URL: ${forum_topic_page_url}"
	fi

	wget -EkKp ${span_hosts} -a "${forum_topic_page_target_directory}/wget-log" -P "${forum_topic_page_target_directory}" "${forum_topic_page_url}"

	local forum_topic_page_host=$(echo "${forum_topic_page_url}" | cut -d/ -f3)
	if [[ ! -d "${forum_topic_page_target_directory}/${forum_topic_page_host}" ]]; then
		echo "${forum_topic_page_number}" >>"${target_directory}/${failure_list_file_basename}"
		echo "error: failed to fetch page ${forum_topic_page_number}" >&2
	else
		[[ -n ${is_verbose_mode} ]] && echo "Finished the fetching of page ${forum_topic_page_number}."
	fi

	kill -USR1 $$
}

job_count=0
trap decrement_job_count SIGUSR1

for forum_topic_page_number in ${forum_topic_page_numbers}; do
	while [[ ${job_count} -ge ${max_job_count} ]]; do
		wait -n
	done

	forum_topic_page_target_directory="${target_directory}/${forum_topic_page_number}"

	if [[ -z ${force} && -d ${forum_topic_page_target_directory} ]]; then
		for failed_page_number in ${failed_page_numbers}; do
			if [[ ${forum_topic_page_number} -eq ${failed_page_number} ]]; then
				is_failed_page_number=true
			fi
		done
		if [[ -z ${is_failed_page_number} ]]; then
			continue
		fi
	fi

	if ! mkdir -p "${forum_topic_page_target_directory}"; then
		echo "error: failed to create target directory for page ${forum_topic_page_number}" >&2
		continue
	fi

	((job_count++))
	[[ -n ${is_verbose_mode} ]] && echo "Starting a new background job (${job_count} jobs total)."

	fetch_forum_topic_page_and_notify "${forum_topic_page_number}" &
done

while ! wait; do
	:
done

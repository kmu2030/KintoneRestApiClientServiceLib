#!/bin/sh

prev=$(date +%s)
clear_threshold=300
ok_sign='\u2714'
ignores=('print')

inotifywait -q -m \
	-e modify \
	-r 'C:\OMRON\Data\SimulatorData\CARD\Memory001' \
	--format "%w %f" |
while read -r dir file; do
	file=${file//[$'\r']};
	if [ ! -s "$dir\\$file" ]; then continue; fi

	now=$(date +%s);
	if [ $((now - prev)) -gt $clear_threshold ]; then
		clear;
	fi
	prev=$now;

	is_ignore=false
	for ignore in "${ignores[@]}"; do
		if [[ "$ignore" == "$file" ]]; then
			is_ignore=true
			break
		fi
	done
	if "$is_ignore"; then
		continue
	fi

	echo -e "$(date -d "@${now}" '+%H:%M:%S') $file";
	if [ -z "$(tail -1 "$dir\\$file" | grep 'Test suite has no failures.$')" ]; then
		cat "$dir\\$file" 2>/dev/null;
	fi
done

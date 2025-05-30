#!/bin/sh
# Mount kernel debug fs so debug tools can work.
# memdebug=4 and memdebug=5 requires debug fs to be mounted.
# And there is no need to umount it.

command -v getargnum > /dev/null || . /lib/dracut-lib.sh

# "sys/kernel/tracing" has the priority if exists.
get_trace_base() {
    # trace access through debugfs would be obsolete if "/sys/kernel/tracing" is available.
    if [ -d "/sys/kernel/tracing" ]; then
        echo "/sys/kernel"
    else
        echo "/sys/kernel/debug"
    fi
}

is_debugfs_ready() {
    [ -f "$(get_trace_base)/tracing/trace" ]
}

prepare_debugfs() {
    trace_base=$(get_trace_base)
    # old debugfs interface case.
    if ! [ -d "$trace_base/tracing" ]; then
        mount none -t debugfs "$trace_base"
    # new tracefs interface case.
    elif ! [ -f "$trace_base/tracing/trace" ]; then
        mount none -t tracefs "$trace_base/tracing"
    fi

    if ! [ -f "$trace_base/tracing/trace" ]; then
        echo "WARN: failed to mount debugfs"
        return 1
    fi
}

if ! is_debugfs_ready; then
    prepare_debugfs
fi

if [ -n "$DEBUG_MEM_LEVEL" ]; then
    if [ "$DEBUG_MEM_LEVEL" -ge 5 ]; then
        echo "memstrack - will report kernel module memory usage summary and top allocation stack"
        nohup memstrack --report module_summary,module_top --notui --throttle 80 -o /.memstrack > /dev/null &
    elif [ "$DEBUG_MEM_LEVEL" -ge 4 ]; then
        echo "memstrack - will report memory usage summary"
        nohup memstrack --report module_summary --notui --throttle 80 -o /.memstrack > /dev/null &
    else
        exit 0
    fi
fi

PID=$!
RET=$?

if [ $RET -ne 0 ]; then
    echo "Failed to start memstrack, exit status: $RET"
    exit $RET
fi

echo $PID > /run/memstrack.pid

# Wait a second for memstrack to setup everything, avoid missing any event
sleep 1

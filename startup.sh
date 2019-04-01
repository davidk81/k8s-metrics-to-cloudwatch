#!/bin/sh

BASEPATH=`dirname $0`
METRIC_INTERVAL=${METRIC_INTERVAL:=150}

kops export kubecfg ${K8S_CLUSTER_NAME}

# https://unix.stackexchange.com/questions/10646/repeat-a-unix-command-every-x-seconds-forever
repeat () {
    local repeat_times=$1 repeat_delay=$2 repeat_foo repeat_sleep
    read -t .0001 repeat_foo
    if [ $? = 1 ] ;then
        repeat_sleep() { sleep $1 ;}
    else
        repeat_sleep() { read -t $1 repeat_foo; }
    fi
    shift 2
    while ((repeat_times)); do
        ((repeat_times=repeat_times>0?repeat_times-1:repeat_times))
        start=`date +%s`
        "${@}"
        end=`date +%s`
        runtime=$((end-start))
        sleeptime=$((repeat_delay-runtime))
        echo "(execution time: $runtime secs)"
        ((repeat_times)) && ((10#${sleeptime//.})) &&
            echo "(sleeping for  : $sleeptime secs)" &&
            repeat_sleep $sleeptime
    done
}

repeat -1 $METRIC_INTERVAL $BASEPATH/write-metrics.sh

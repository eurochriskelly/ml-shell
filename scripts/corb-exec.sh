#!/bin/bash

runCorb() {
  initialize
  local start=$(date +%s)
  local type="validate"
  local task=$1
  local job=$2
  local threads=$3
  local batchSize=$4
  local dataReport=tasks/$task/corb-report-${job}.txt
  local javaReport=tasks/$task/corb-javaout-${job}.log
  echo "" > $dataReport
  echo "" > $javaReport

  II "Storing corb log in [$javaReport]"
  II "Storing corb report in [$dataReport]"

  #set -o xtrace
  corbOpts=(
    -server -cp .:$CORB_JAR:$XCC_JAR
    -DXCC-CONNECTION-URI="xcc://${ML_USER}:${ML_PASS}@${ML_HOST}:${CORB_PORT}"
    -DOPTIONS-FILE="tasks/${task}/jobs/${job}.properties"
    -DEXPORT-FILE-NAME="$dataReport"
  )

  if [ -n "$threads" ];then
    corbOpts+=( -DTHREAD-COUNT="$threads")
  fi

  if [ -n "$batchSize" ];then
    corbOpts+=( -DBATCH-SIZE="$batchSize")
  fi

  set -o xtrace
  java "${corbOpts[@]}" com.marklogic.developer.corb.Manager > $javaReport 2>&1
  set +o xtrace

  echo " ----------------- " >>$javaReport
  II "-> Corb step [$step] took [$(($(date +%s) - $start))] seconds"
  II "-> Report [$dataReport]"
}

II() { echo "$(date +%Y-%m-%dT%H:%M:%S%z): $@" ; }

initialize() {
    if [ -z "$ML_HOST" ];then
        echo "ERROR: Expected environment variable [ML_HOST] not defined! Please source your environment."
        exit 1
    fi

    # Dump configuration settings used
    local c=$runDir/config.txt
    touch $c
    echo "HOST: $ML_HOST" >> $c
    echo "USER: $ML_USER" >> $c
}

while [ "$#" -gt "0" ]; do
  case $1 in
  --task)
    shift
    task=$1
    shift
    ;;

  --job)
    shift
    job=$1
    shift
    ;;

  --threads)
    shift
    threads=$1
    shift
    ;;

  --batchSize)
    shift
    batchSize=$1
    shift
    ;;

  *)
    echo "Unknown option [$1]"
    shift
    exit
    ;;
  esac
done

startedAt="$(date +%s)"
timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
runDir=./results/run-${startedAt}
mkdir -p $runDir
log=./results/run-${startedAt}/log

if [ -n "$job" ]; then
  runCorb $task $job $threads $batchSize
else
  echo "You must provide a job!"
  echo "e.g. startjob --job getcounts"
  echo "Available jobs:"
  cd scripts/corb/
  jobs="$(find . -type d -mindepth 1)"
  cd - 2 /dev/null &>1
  echo "$jobs" | while read line; do
    echo "  $line"
  done
fi

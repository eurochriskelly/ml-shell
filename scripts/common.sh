#!/bin/bash

II() { echo "II $(date) $@"; }
EE() { echo "EE $(date) $@"; }

fetch() {
  local endpoint=$1
  shift
  local rest=($@)
  local URL="${ML_PROTOCOL}://${ML_HOST}:${ML_PORT}${endpoint}"
  local curlOpts=(
    --insecure
    -u "$ML_USER:$ML_PASS"
    -k --digest -s
    "${rest[@]}"
  )
  curl "${curlOpts[@]}" "$URL"
}

doEval() {
  prepScript() {
    local tmp=/tmp/$1
    local db=$2
    local vars=$3
    echo "xquery=" >$tmp
    local txt=$(cat scripts/eval/${1}.xqy)
    local path="scripting/eval/${1}.xqy"
    echo $txt >>$tmp
    if [ -n "$vars" ]; then
      echo "&" >>$tmp
      echo "vars=${vars}" >>$tmp
    fi
    if [ -n "$db" ]; then
      echo "&" >>$tmp
      echo "database=${db}" >>$tmp
    fi
    echo $tmp
  }
  local script=$(prepScript $@)
  local opts=(-X POST -d @$script)
  fetch "/v1/eval" "${opts[@]}" | grep stories
}

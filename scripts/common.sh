#!/bin/bash

II() { echo "II $(date) $@"; }
# script that only echos if $MULSH_DEBUG is set
DD() { if [ -n "$MULSH_DEBUG" ]; then echo "DD $(date) $@"; fi; }
EE() { echo "EE $(date) $@"; }
WW() { echo "WW $(date) $@"; }
LL() { echo "$(date) $@" >> /tmp/mulsh.log; }

fetch() {
  local endpoint=$1
  shift
  local rest=($@)
  local URL="${ML_PROTOCOL}://${ML_HOST}:${ML_PORT}${endpoint}"
  # TODO generate based on environment
  local curlOpts=(
    --insecure
    -u "$ML_USER:$ML_PASS"
    -k --digest -s
    "${rest[@]}"
  )
  LL "curl ${curlOpts[@]} $URL"
  curl "${curlOpts[@]}" "$URL"
}

doEval() {
  prepScript() {
    local ts=$(date +%s)
    local script=$1
    find /tmp -name "mle-*" -exec rm {} \; 2>&1 > /dev/null
    local tmp=/tmp/mle-$ts
    test -f $tmp && rm $tmp
    local db=$3
    local vars=$4
    local extension="${script##*.}"
    if [ "$extension" == "xqy" ];then
      echo "xquery=" > $tmp
    else
      echo "javascript=" > $tmp
    fi
    local txt=$(cat ${script})
    echo "$txt" >> $tmp
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

  DD "Evaluating script [$1] against database [$2] with vars [$3]"
  local script=
  local base=$MULSH_TOP_DIR/scripts/eval/${1}

  # Check if it exists in the scripts/eval directory
  if [[ -f "${base}.xqy" || -f "${base}.sjs" || -f "${base}.js" ]]; then
    if [ -f "${base}.xqy" ]; then
      script=$MULSH_TOP_DIR/scripts/eval/${1}.xqy
    else
      if [ -f "${base}.sjs" ]; then
        script=$MULSH_TOP_DIR/scripts/eval/${1}.sjs
      else
        script=$MULSH_TOP_DIR/scripts/eval/${1}.js
      fi
    fi
  fi

  # Check if it exists locally
  if [ -z "$script" ]; then
    # check if $1 with either xqy OR js extension exists in current directory
    if [[ -f "${1}.xqy" || -f "${1}.sjs" ||  -f "${1}.js" ]]; then
      if [ -f "${1}.xqy" ]; then
        script=${1}.xqy
      else
        if [ -f "${1}.sjs" ]; then
          script=${1}.sjs
        else
          script=${1}.js
        fi
      fi
    fi
  fi

  if [ -z "$script" ]; then
    DD "Script [$1] not found in $MULSH_TOP_DIR/scripts/eval or current directory."
    ls $MULSH_TOP_DIR/scripts/eval
    return 1
  else
    DD "Found matching script [$script]"
  fi

  local useScript=$(prepScript $script $@)
  if [ "$useScript" == "1" ]; then
    DD "No script [$1] found in $MULSH_TOP_DIR/scripts/eval or ."
    return 1
  fi
  local opts=(-X POST -d @$useScript)
  local response=$(fetch "/v1/eval" "${opts[@]}")
  # Cleanup the response
  while read -r line; do
    local c2=$(echo $line|cut -c1-2|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    case "$c2" in
      # Ignore log messages
      "II") ;;
      "EE") ;;
      "WW") ;;
      "DD") ;;
      "--") ;;
      "") ;;
      *)
        # Ignore lines starting with "Content-Type" or "X-Primitive"
        if [[ "$line" != "Content-Type"* && "$line" != "X-Primitive"* ]]; then
          echo $line
        fi
    esac
  done <<< "$response"
}

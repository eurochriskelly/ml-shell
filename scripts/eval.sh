#!/bin/bash

source $MULSH_TOP_DIR/scripts/common.sh

echo $(pwd)
run() {
  while [[ $# -gt 0 ]];do
    case $1 in
      --script|-s) shift;script=$1;shift
        ;;
      --params|-p) shift;params=$1;shift
        ;;
      --database|-d) shift;database=$1;shift
        ;;
      *)
        echo "Unknown argument [$1]"
        shift
        ;;
    esac
  done
  doEval $script $database $params
}

run $@
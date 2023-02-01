#!/bin/bash

mlsh() {
  local cmd=$1
  shift
  local args=($@)
  case $cmd in
    "qc")
      cd $MLSH_TOP_DIR
      bash scripts/qc.sh "${args[@]}"
      ;;
    "eval")
      doEval "${args[@]}"
      ;;
    "fetch")
      fetch "${args[@]}"
      ;;
    "corb")
      runCorb "${args[@]}"
      ;;
    "init")
      source $MLSH_TOP_DIR/init.sh
      ;;
    *)
      echo "Unknown command [$cmd]"
      showHelp
      ;;
  esac
}

showHelp() {
  echo ""
  echo "mlsh init                                       # source this file"
  echo "mlsh qc [pull|push]                             # pull/push from/to query console"
  echo "mlsh corb <task> <job> <threads> <batchSize>    # run corb task"
  echo "mlsh eval <script> <db> <vars>                  # run eval script"
  echo "mlsh fetch <endpoint> <rest>                    # fetch from ml"
  echo ""
}

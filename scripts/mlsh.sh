#!/bin/bash

mlsh() {
  local cmd=$1
  shift
  local args=($@)
  case $cmd in
    "qc")
      cd $MSH_TOP_DIR
      bash scripts/qc.sh "${args[@]}"
      ;;
    "eval")
      doEval "${args[@]}"
      ;;
    "fetch")
      fetch "${args[@]}"
      ;;
    "run")
      runCorb "${args[@]}"
      ;;
    *)
      echo "Unknown command [$cmd]"
      showHelp
      ;;
  esac
}

showHelp() {
  echo ""
  echo "mlsh eval <script> <db> <vars>"
  echo "mlsh fetch <endpoint> <rest>"
  echo "mlsh run <task> <job> <threads> <batchSize>"
  echo "mlsh qc [pull|push]"
  echo ""
}

mlsh $@
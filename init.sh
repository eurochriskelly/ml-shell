#!/bin/bash

echo "Initializing ml-shell..."
getScriptDir() {
  local scriptDir=$(dirname $0)
  if [ "$scriptDir" = "." ]; then
    scriptDir=$(pwd)
  fi
  echo $scriptDir
}

export MSH_TOP_DIR=$(getScriptDir)
alias qc="cd $MSH_TOP_DIR; bash scripts/qc.sh"
alias mlsh="cd $MSH_TOP_DIR; bash scripts/mlsh.sh"
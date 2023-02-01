#!/bin/bash

echo "Initializing ml-shell..."
getScriptDir() {
  local scriptDir=$(dirname $0)
  if [ "$scriptDir" = "." ]; then
    scriptDir=$(pwd)
  fi
  echo $scriptDir
}

export MLSH_TOP_DIR=$(getScriptDir)
alias qc="cd $MLSH_TOP_DIR; bash scripts/qc.sh"
alias mlsh="cd $MLSH_TOP_DIR; bash scripts/mlsh.sh"


if [ ! -f "$MLSH_TOP_DIR/env.sh" ]; then
  echo "Creating a default .mlshrc file in your home directory."
  echo "Please modify as needed."
  cp $MLSH_TOP_DIR/.mlshrc.example ~/.mlshrc
  exit
fi

source ~/.mlshrc
#!/bin/bash

echo "Initializing ml-shell..."
getScriptDir() {
  local scriptPath=$(readlink -f $1)
  local scriptDir=$(dirname $1)
  if [ "$scriptDir" = "." ]; then
    scriptDir=$(pwd)
  fi
  echo $scriptDir
}

export MLSH_TOP_DIR=$(getScriptDir $0)
alias qc="bash $MLSH_TOP_DIR/scripts/qc.sh"
alias mlsh="bash $MLSH_TOP_DIR/scripts/mlsh.sh"
alias mlsh:go="cd $MLSH_TOP_DIR"

if [ ! -f "$HOME/.mlshrc" ]; then
  echo "No ~/.mlshrc file found."
  echo "Creating a default .mlshrc file in your home directory."
  echo "Please modify as needed."
  cp $MLSH_TOP_DIR/mlshrc.template ~/.mlshrc
fi

echo "Sourcing ~/.mlshrc"
source ~/.mlshrc
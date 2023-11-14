#!/bin/bash

# Log analysis tasks
source $MLSH_TOP_DIR/scripts/common.sh > /dev/null 2>&1

main() {
  #
  #
  if [ -z "$1" ]; then
    showHelp
  fi

  local env=$1
  export ML_ENV=$env

  echo ML_ENV $ML_ENV
  echo ML_HOST $ML_HOST
  echo ML_USER $ML_USER
}

showHelp() {
  local envs=$(cat ~/.mlshrc | grep ")$" | grep -v "*" | awk '{print $1}' | awk -F\) '{print $1}')
  echo "Available environments:"
  echo "$envs" | sed 's/^/  /'
}

main "$@"

#!/bin/bash

source $MULSH_TOP_DIR/scripts/common.sh

showHelp() {
  echo "Usage: mulsh eval [options] <script> <database> <params>"
  echo "Options:"
  echo "  -s|--script <script>   The script to run"
  echo "  -d|--database <database>   The database to run the script against"
  echo "  -p|--params <params>   The parameters to pass to the script"
  echo "  -h|--help              Show this help"
}

run() {
  local database=$ML_CONTENT_DB
  while [[ $# -gt 0 ]];do
    case $1 in
      --script|-s)
        shift;script=$1;shift
        # Check if file has extension. If yes then remove it.
        # It will be found and added by the script
        if [[ $script == *.* ]]; then
          script=${script%.*}
        fi
        ;;

      --params|-p)
        shift;params=$1;shift
        ;;

      # Better to pass vars as A:B,C:D
      --vars|-v)
        shift;params=$(toJson $1);shift
        ;;

      --database|-d)
        shift;database=$1;shift
        ;;

      *)
        echo "Unknown argument [$1]"
        showHelp
        shift
        ;;
    esac
  done
  doEval $script $database $params
}

run $@

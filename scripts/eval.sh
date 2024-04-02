#!/bin/bash

source $MLSH_TOP_DIR/node_modules/mlsh-core/scripts/common.sh
LAST_SCRIPT=

showHelp() {
  echo "Usage: mlsh eval [options] <script> <database> <params>"
  echo "Options:"
  echo "  -s|--script <script>   The script to run"
  echo "  -d|--database <database>   The database to run the script against"
  echo "  -p|--params <params>   The parameters to pass to the script"
  echo "  -h|--help              Show this help"
}

run() {
  if [ "$#" -eq 0 ]; then
    echo -n "Select a database or press ENTER for default [$ML_CONTENT_DB]: "
    read dbChoice
    local database=$ML_CONTENT_DB
    if [ -n "$dbChoice" ]; then
      database=$dbChoice
    fi
    while true; do
      echo "MLSH EVAL: DB [$database]"
      interactivelyRunScriptsInDir $database
    done
    exit 0
  else
    while [[ $# -gt 0 ]]; do
      case $1 in
      --script | -s)
        shift
        script=$1
        shift
        # Check if file has extension. If yes then remove it.
        # It will be found and added by the script
        if [[ $script == *.* ]]; then
          script=${script%.*}
        fi
        ;;

      --params | -p)
        shift
        params=$1
        shift
        ;;

      # Better to pass vars as A:B,C:D
      --vars | -v)
        shift
        params=$(toJson $1)
        shift
        ;;

      --database | -d)
        shift
        database=$1
        shift
        ;;

      --help | -h)
        showHelp
        exit 0
        ;;

      *)
        echo "Unknown option [$1]"
        shift
        ;;
      esac
    done
    doEval $script $database $params
  fi

}

# Interactively allow user to select a script to run
# from the list of scripts in the current directory.
# Number each script and let the user select one
# by typing the number and pressing ENTER.
interactivelyRunScriptsInDir() {
  # get xqy, js, and sjs files
  local database=$1
  local scripts=$(ls -1 *.xqy *.js *.sjs 2>/dev/null | sort)
  echo "Scripts in current directory:"
  i=1
  for s in $scripts; do
    echo "  ${i}. $s"
    i=$((i + 1))
  done
  local extra=
  if [ -n "$LAST_SCRIPT" ]; then extra="press ENTER to re-run ($LAST_SCRIPT),"; fi
  echo -n "Select a script, ${extra} or choose an option [Database/Params/eXit]: "
  read choice
  if [ "$choice" == "x" ]; then
    exit 0
  fi

  if [ -z "$choice" ]; then
    # if user pressed enter, re-run last script
    script=${LAST_SCRIPT}
    if [ -z "$script" ]; then
      echo "Nothing selected and no previous script ran. Exiting"
      exit 0
    fi
  else
    # split choice into 2 parts
    local scriptNum=$(echo $choice | cut -d' ' -f1)
    local params=$(echo $choice | cut -d' ' -f2)
    if [ -n "$params" ]; then
      params=$(toJson $params)
    fi
    local script=$(echo $scripts | cut -d' ' -f$scriptNum)
  fi

  if [ -z $script ]; then
    echo "No script selected"
    exit 1
  fi
  # remove extension from variable $script
  # FIXME: this should be done inside doEval
  extension=$LAST_EXTENSION
  if [ "$script" != "${script%.*}" ]; then
    extension=${script##*.}
  fi
  script=${script%.*}
  database="$(checkForDatabaseOverride $script $extension $database)"
  clear
  echo "ML EVAL DB [$database]."
  echo RUNNING: doEval $script $database $params
  LAST_SCRIPT=$script
  LAST_EXTENSION=$extension
  # calculate elapsed time
  start=$(date +%s)
  # Echo in green
  echo -e "\033[32m--------------------------------------------\033[0m"
  result="$(doEval $script $database $params)"
  echo "$result" > /tmp/mlsh-eval.out
  local numLines=$(echo "$result" | wc -l)
  LL "Output temporarily stored in /tmp/mlsh-eval.out"
  # in the terminal we want to truncate the response to 50 lines
  # The full response should be view with a better tool (e.g. vim, emacs)
  if [ $numLines -gt 50 ]; then
    result="$(echo "$result" | head -n 50)n\\nSee /tmp/mlsh-eval.out for full response"
  fi
  echo "$result" | while read -r line; do
    # echo the line but truncate to 200 characters if it's more than that
    # Add ... at the end if the line has been truncated
    if [ ${#line} -gt 200 ]; then
      echo "  ${line:0:200} ... (long line truncated)"
    else
      echo "  $line"
    fi
  done
  echo -e "\033[32m--------------------------------------------\033[0m"
  echo -e "\033[32mFull response @ /tmp/mlsh-eval.out\033[0m"

  end=$(date +%s)
  elapsed=$((end - start))
  echo "Elapsed time: $elapsed seconds"
  echo ""
}

checkForDatabaseOverride() {
  local script=$1
  local extension=$2
  local database=$3
  local predb=$database
  if [ ! -f $script ]; then
    script=${script}.${extension}
  fi
  # if the script contains "@DEFAULTS" in the first 10 lines, parse it for the database name
  # the string should look like this: @DEFAULTS:database=Documents where Documents in the value of the database override
  if [ -n "$(head -n 10 $script | grep "@DEFAULTS:database=")" ]; then
    database=$(head -n 10 $script | grep "@DEFAULTS:database=" | cut -d'=' -f2 | cut -d' ' -f1)
    if [ "$database" != "" ]; then
      LL "Found database override [$database] in script [$script]. Using that instead of [$predb]."
    fi
  fi
  echo "$database"
}

run $@

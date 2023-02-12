#!/bin/bash

# Log analysis tasks
source $MULSH_TOP_DIR/scripts/common.sh

main() {
  local option=$1
  if [ -z "$option" ]; then
    # Ask user to select from known options
    echo "Please select from the following options:"
    echo "1. show-errors "
    echo "2. search"
    echo "3. follow"
    echo -n "Enter your choice: "
    read choice
    case $choice in
      1) option="show-errors" ;;
      2) option="search" ;;
      3) option="follow" ;;
      *)
        echo "Unknown option [$option]"
        echo "Please select an option [show-errors/search/follow]"
        echo "e.g."
        echo "mulsh log show-errors"
        cd $MULSH_TOP_DIR
        return
        ;;

    esac
    echo "User selected option [$option]"
  fi

  case $option in
    show-errors)
      showErrors
      ;;

    search)
      shift
      search "$@"
      ;;

    follow)
      follow
      ;;

    *)
      # Let user select one of the known options
      echo "Unknown option [$option]"
      echo "Please select an option [show-errors/search/follow]"
      echo "e.g."
      echo "log show-errors"
      cd $MULSH_TOP_DIR
      return
      ;;
  esac
}

# Show errors in the log in the past X minutes
showErrors() {
  local minutes=$1
  if [ -z "$minutes" ]; then
    echo -n "Please enter the number of minutes to search: "
    read minutes
  fi
  echo "Searching for errors in the past [$minutes] minutes"
  local results=$(doEval showErrors "${ML_MODULES_DB}" '{"MINUTES": "'$minutes'"}')
  echo $results
}

search() {
  local pattern=$1
  if [ -z "$pattern" ]; then
    echo -n "Please enter a pattern to match (e.g. *foo.xqy): "
    read $pattern
  fi
  shift
  local minutes=$1
  if [ -z "$minutes" ]; then
    echo -n "How many minutes: "
    read $minutes
  fi
  echo "Searching for logs matching [$pattern]"
  local results=$(doEval recentErrors "${ML_MODULES_DB}" '{"PATTERN":"'$pattern'","MINUTES":"'$minutes'"}')
  echo "$results"|tail -n 1|awk '{print $1 " " $2}'
  echo "==="
  echo "$results"
}

follow() {
  echo "Following logs..."
  local results=$(doEval recentErrors "App-Services" '{"INITIALIZE":"1"}')
  local day=
  local time=
  local minutes=1
  while true;do
    local results=$(doEval recentErrors "${ML_MODULES_DB}" '{"DAY":"'$day'","TIME":"'$time'","MINUTES":"'$minutes'"}')
    if [ -n "$results" ]; then
      echo "$results"
    fi
    sleep 3
    if [ -n "$results" ]; then
      day=$(echo "$results"|grep "^20"|tail -n 1|awk '{print $1}')
      time=$(echo "$results"|grep "^20"|tail -n 1|awk '{print $2}')
    fi
    minutes=
  done

}

main "$@"

#!/bin/bash

# Log analysis tasks
source $MLSH_TOP_DIR/scripts/common.sh

main() {
  local option=$1
  local logtype=${2:-error}
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
      3)
        shift
        option="follow"
        if [ -n "$1" ]; then
          case $1 in
            -e) logtype="error" ;;
            -a) logtype="access" ;;
            *) echo "Unknown log type [$1]. Must be one of [-e|-a]"; return ;;
          esac
        fi
        ;;
      *)
        echo "Unknown option [$option]"
        echo "Please select an option [show-errors/search/follow]"
        echo "e.g."
        echo "mlsh log show-errors"
        cd $MLSH_TOP_DIR
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
      follow $logtype
      ;;

    *)
      # Let user select one of the known options
      echo "Unknown option [$option]"
      echo "Please select an option [show-errors/search/follow]"
      echo "e.g."
      echo "log show-errors"
      cd $MLSH_TOP_DIR
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
  local results=$(doEval showErrors "${ML_MODULES_DB}" '{"MINUTES":"$minutes"}')
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
  local logtype=$1
  local results=$(doEval recentErrors "App-Services" '{"INITIALIZE":"1"}')
  local day=
  local time=
  local minutes=1
  local params=$(toJson DAY:$day,TIME:$time,MINUTES:$minutes)
  # TODO: make log fall asleep if there is not activity for a while
  case $logtype in
    error)
      while true;do
        local results=$(doEval recentErrors "${ML_MODULES_DB}" '{"DAY":"'$day'","TIME":"'$time'","MINUTES":"'$minutes'","TYPE":"'$logtype'"}')
        if [ -n "$results" ]; then
          echo "$results"
        fi
        sleep 5
        if [ -n "$results" ]; then
          day=$(echo "$results"|grep "^20"|tail -n 1|awk '{print $1}')
          time=$(echo "$results"|grep "^20"|tail -n 1|awk '{print $2}')
        fi
        minutes=
      done
      ;;
    access)
      # TODO: Run also Error log tailing using server varable to track last time
      while true;do
        local results=$(doEval recentAccess "${ML_MODULES_DB}" '{"FLAGS":"no-eval+no-moz"}')
        if [ -n "$results" ]; then  echo "$results"|column -s, -t;fi
        sleep 5
      done
      ;;
    *)
      echo "Unknown log type [$logtype]. Must be one of [ErrorLog|AccessLog]"
      return
      ;;
  esac


}

main "$@"

#!/bin/bash

source $MLSH_TOP_DIR/scripts/common.sh
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

    "update")
      mlshUpdate "${args[@]}"
      ;;

    "fetch")
      fetch "${args[@]}"
      ;;

    "corb")
      if [ ! -f "$CORB_JAR" ]; then
        echo "Please set CORB_JAR in your ~/.mlshrc file."
        return
      fi
      if [ ! -f "$XCC_JAR" ]; then
        echo "Please set XCC_JAR in your ~/.mlshrc file."
        return
      fi
      runCorb "${args[@]}"
      ;;
    "init")
      source $MLSH_TOP_DIR/init.sh
      ;;
    "help")
      showHelp ${args[@]}
      ;;
    *)
      echo "Unknown command [$cmd]"
      showHelp
      ;;
  esac
}

showHelp() {
  local cmd=$1
  case $cmd in
    "qc")
      echo "Usage: mlsh qc [pull|push]"
      echo ""
      echo "Pulls or pushes the query console from/to the database."
      echo ""
      echo "Examples:"
      echo " mlsh qc pull"
      echo " mlsh qc push"
      ;;
    "eval")
      echo "Usage: mlsh eval <script> <db> <vars>"
      echo ""
      echo "Runs an eval script against the database."
      echo ""
      echo "Examples:"
      echo " mlsh eval /path/to/script.xqy App-Services"
      echo " mlsh eval /path/to/script.xqy App-Services \"var1=value1&var2=value2\""
      ;;
    "fetch")
      echo "Usage: mlsh fetch <endpoint> <rest>"
      echo ""
      echo "Fetches a resource from the database."
      echo ""
      echo "Examples:"
      echo " mlsh fetch /manage/v2/databases"
      echo " mlsh fetch /manage/v2/databases App-Services"
      ;;
    "corb")
      echo "Usage: mlsh corb <task> <job> <threads> <batchSize>"
      echo ""
      echo "Runs a corb task."
      echo ""
      echo "Examples:"
      echo " mlsh corb /path/to/task.xqy /path/to/job.xml 4 100"
      ;;
    "help")
      echo "Usage: mlsh help <command>"
      echo ""
      echo "Shows help for a command."
      echo ""
      echo "Examples:"
      echo " mlsh help qc"
      echo " mlsh help eval"
      echo " mlsh help fetch"
      echo " mlsh help corb"
      ;;
    *)
      echo ""
      echo "mlsh <command> <args>                           # run a command"
      echo ""
      echo "Commands:"
      echo " mlsh init                                       # source this file"
      echo " mlsh update                                     # update ml-shell from github (zip)"
      echo " mlsh qc [pull|push]                             # pull/push from/to query console"
      echo " mlsh corb <task> <job> <threads> <batchSize>    # run corb task"
      echo " mlsh eval <script> <db> <vars>                  # run eval script"
      echo " mlsh fetch <endpoint> <rest>                    # fetch from ml"
      echo " mlsh help <command> .                           # for more info on a command"
      echo ""
      ;;
  esac
}

mlshUpdate() {
  echo "Updating ml-shell..."
  local timestamp=$(date +%s)
  local updir=/tmp/ml-shell/$timestamp
  local force=$1
  if [ -z "$force" ]; then
    echo "Please use 'mlsh update -f' to replace files."
  else
    force=true
  fi
  cd $MLSH_TOP_DIR
  test -d /tmp/ml-shell && rm -rf /tmp/ml-shell
  mkdir -p $updir
  local releaseInfo=$(curl -s https://api.github.com/repos/eurochriskelly/ml-shell/releases/latest)
  local tag=$(
    echo "$releaseInfo" \
    | grep tag_name \
    | awk -F": " '{print $2}' \
    | awk -F\" '{print $2}'
  )
  ## Download zip for current version
  echo "$releaseInfo" \
    | grep zipball \
    | awk -F": " '{print $2}' \
    | awk -F\" '{print $2}' \
    | wget -qi -

  mv "$tag" $updir/latest.zip
  cd $updir
  unzip -q latest.zip
  rm latest.zip
  local dir=$(ls -d *)
  if "$force";then
    echo "Replacing current version. Backing up previous version to './versions/$timestamp'"
    mkdir -p $MLSH_TOP_DIR/versions/$timestamp
    mv $MLSH_TOP_DIR/* $MLSH_TOP_DIR/versions/$timestamp
    mv $dir/* $MLSH_TOP_DIR/
  else
    echo "Update will be stored in './update' folder."
    mv $dir/* .
  fi
  echo "rm -rf $dir"
}

mlsh $@
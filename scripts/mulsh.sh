#!/bin/bash

source $MULSH_TOP_DIR/scripts/common.sh

mulsh() {
  local cmd=$1
  shift
  local args=($@)
  case $cmd in
    # Core commands
    "update")
      mulshUpdate "${args[@]}"
      ;;

    "init")
      source $MULSH_TOP_DIR/init.sh
      ;;

    "help")
      showHelp ${args[@]}
      ;;

    # Wrappers
    "eval")
      bash $MULSH_TOP_DIR/scripts/eval.sh "${args[@]}"
      ;;

    "rest")
      fetch "${args[@]}"
      ;;

    "qc|qconsole")
      bash $MULSH_TOP_DIR/scripts/qconsole.sh "${args[@]}"
      ;;
    "mod|modules")
      bash $MULSH_TOP_DIR/scripts/modules.sh "${args[@]}"
      ;;

    "mlcp")
      bash $MULSH_TOP_DIR/scripts/mlcp-wrapper.sh "${args[@]}"
      ;;

    "corb")
      if [ ! -f "$CORB_JAR" ]; then
        echo "Please set CORB_JAR in your ~/.mulshrc file."
        return
      fi
      if [ ! -f "$XCC_JAR" ]; then
        echo "Please set XCC_JAR in your ~/.mulshrc file."
        return
      fi
      runCorb "${args[@]}"
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
      echo "Usage: mulsh qc [pull|push]"
      echo ""
      echo "Pulls or pushes the query console from/to the database."
      echo ""
      echo "Examples:"
      echo " mulsh qc pull"
      echo " mulsh qc push"
      ;;

    "eval")
      echo "Usage: mulsh eval <script> <db> <vars>"
      echo ""
      echo "Runs an eval script against the database."
      echo ""
      echo "Examples:"
      echo " mulsh eval /path/to/script.xqy Documents"
      echo " mulsh eval /path/to/script.xqy App-Services \"var1=value1&var2=value2\""
      ;;

    "rest")
      echo "Usage: mulsh rest <endpoint> <rest>"
      echo ""
      echo "Fetches a resource from the database."
      echo ""
      echo "Examples:"
      echo " mulsh rest /manage/v2/databases"
      echo " mulsh rest /manage/v2/databases App-Services"
      ;;

    "mlcp")
      echo "Usage: mulsh mlcp <args>"
      echo ""
      echo "Runs mlcp."
      echo ""
      echo "Examples:"
      echo " mulsh mlcp import --type xml --collections foo,bar -prefix /base"
      ;;

    "corb")
      echo "Usage: mulsh corb <task> <job> <threads> <batchSize>"
      echo ""
      echo " Runs a corb task as specifeid in the task folder."
      echo " - if omitted, the job name will be the current folder"
      echo ""
      echo " Job name must be specified and match basename of properties"
      echo " file in the <task>/job folder."
      echo " - e.g. if job name is 'foo', then the jobs/foo.properties "
      echo "        file must"
      echo ""
      echo "Examples:"
      echo " mulsh corb --job jobName"
      echo " mulsh corb --job jobName --taskDir path/taskDir --threads 6"
      echo " mulsh corb --job jobName --taskDir path/taskDir [--threads 4] [--batchs 100]"
      ;;

    "help")
      echo "Usage: mulsh help <command>"
      echo ""
      echo "Shows help for a command."
      echo ""
      echo "Examples:"
      echo " mulsh help qc"
      echo " mulsh help eval"
      echo " mulsh help fetch"
      echo " mulsh help corb"
      ;;

    "modules")
      echo "Usage: mulsh modules <command>"
      echo ""
      echo "Manage modules."
      echo ""
      echo "Examples:"
      echo " mulsh modules find"
      echo " mulsh modules deploy <module>"
      echo " mulsh modules undeploy <module>"
      echo " mulsh modules reset <id>"
      ;;

    *)
      echo ""
      echo "mulsh <command> <args>                           # run a command"
      echo ""
      echo "Commands:"
      echo " mulsh init                                       # source this file"
      echo " mulsh config                                     # configure current state (e.g. environment, database)"
      echo " mulsh update                                     # update mulsh from github (zip)"
      echo " mulsh qc [pull|push]                             # pull/push from/to query console"
      echo " mulsh corb <task> <job> <threads> <batchSize>    # run corb task"
      echo " mulsh eval <script> <db> <vars>                  # run eval script"
      echo " mulsh rest <endpoint> <rest>                     # call ml rest endpoint"
      echo " mulsh mlcp <args>                                # run mlcp"
      echo " mulsh modules <command>                          # manage modules"
      echo " mulsh help <command> .                           # for more info on a command"
      echo ""
      ;;
  esac
}

mulshUpdate() {
  echo "Updating mulsh from github..."
  local timestamp=$(date +%s)
  local OLD_DIR=$(pwd)
  local updir=/tmp/mulsh/$timestamp
  local force=$1
  if [ -z "$force" ]; then
    echo "Please use 'mulsh update -f' to replace files."
    force=false
  else
    force=true
  fi
  cd $MULSH_TOP_DIR
  test -d /tmp/mulsh && rm -rf /tmp/mulsh
  mkdir -p $updir
  local releaseInfo=$(curl -s https://api.github.com/repos/eurochriskelly/mulsh/releases/latest)
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
    mkdir -p $MULSH_TOP_DIR/versions/$timestamp
    mv $MULSH_TOP_DIR/* $MULSH_TOP_DIR/versions/$timestamp
    mv $dir/* $MULSH_TOP_DIR/
  else
    mv $dir/* .
    echo "Update was copied to $(pwd). Please review and copy to $MULSH_TOP_DIR"
  fi
  rm -rf $dir
  cd $OLD_DIR 2>&1 > /dev/null
}

mulsh $@
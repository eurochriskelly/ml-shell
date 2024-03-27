#!/bin/bash

source $MLSH_TOP_DIR/scripts/common.sh
test -f $HOME/.mlshrc-gen && source $HOME/.mlshrc-gen
mlsh() {
  local cmd=$1
  shift
  local args=($@)
  if [ -z "$ML_ENV" ];then
    echo "No environment selected. Please run 'mlsh env'"
    exit 0
  fi
  clear
  # Define color codes
  fM='\033[35m' # Foreground Magenta
  bM='\033[45m' # Background Magenta
  white='\033[97m' # White
  end='\033[0m' # End of color string
  echo -e "${bM}${white} MLSH$ ${end}${fM} - Current env [${end}${white}$ML_ENV${end}${fM}]${end}"
  case $cmd in
    # Core commands
    update)
      mlshUpdate "${args[@]}"
      ;;

    init)
      source $MLSH_TOP_DIR/init.sh
      ;;

    env|mlenv|showenv)
      bash $MLSH_TOP_DIR/scripts/config.sh "$@"
      ;;

    helpme|help)
      showHelp ${args[@]}
      ;;

    # Wrappers
    ev|eval)
      bash $MLSH_TOP_DIR/scripts/eval.sh "${args[@]}"
      ;;

    qc|qconsole)
      bash $MLSH_TOP_DIR/scripts/qconsole.sh "${args[@]}"
      ;;

    mod|module|modules)
      bash $MLSH_TOP_DIR/scripts/modules.sh "${args[@]}"
      ;;

    log|logs)
      bash $MLSH_TOP_DIR/scripts/logs.sh "${args[@]}"
      ;;

    mlcp)
      bash $MLSH_TOP_DIR/scripts/mlcp-wrapper.sh "${args[@]}"
      ;;

    corb)
      bash $MLSH_TOP_DIR/node_modules/mlsh-corb/src/corb-wrapper.sh "${args[@]}"
      ;;

    *)
      dropToShell
      ;;
  esac

  echo -e "${bM}+${end}"
}

dropToShell() {
  CUSTOM_BASHRC="$HOME/.mlsh.d/mlsh/shell/bashrc"
  # Starting bash with the custom bashrc
  if [ -f "$CUSTOM_BASHRC" ];then
    exec /bin/bash --rcfile "$CUSTOM_BASHRC" --noprofile
  else
    echo "No custom bashrc found [$CUSTOM_BASHRC]. Starting default shell."
  fi
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
      echo " mlsh qc list             # list available workspaces"
      echo " mlsh qc pull             # download queries"
      echo " mlsh qc push             # upload queries"
      ;;

    "eval")
      echo "Usage: mlsh eval <script> <db> <vars>"
      echo ""
      echo "Runs an eval script against the database."
      echo ""
      echo "Examples:"
      echo " mlsh eval /path/to/script.xqy Documents"
      echo " mlsh eval /path/to/script.xqy App-Services \"var1=value1&var2=value2\""
      ;;

    "log")
      echo "Usage: mlsh log <db> <log>"
      echo ""
      echo "Shows the log for the database."
      echo ""
      echo "Examples:"
      echo " - Show errors occurring in the last 10 minutes"
      echo " mlsh log show-errors --time 10m"
      echo ""
      echo " - Search across the cluster for logs containing 'XDMP-AS'"
      echo " mlsh log search --pattern 'XDMP-AS' --ports 8000,8001"
      echo ""
      echo " - Follow the logs on the cluster for"
      echo " mlsh log follow --ports 8000,8001,Error,TaskServer"
      echo ""
      ;;

    "mlcp")
      echo "Usage: mlsh mlcp <args>"
      echo ""
      echo "Runs mlcp."
      echo ""
      echo "Examples:"
      echo " mlsh mlcp import --type xml --collections foo,bar -prefix /base"
      ;;

    "corb")
      echo "Usage: mlsh corb <task> <job> <threads> <batchSize>"
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
      echo " mlsh corb --job jobName"
      echo " mlsh corb --job jobName --taskDir path/taskDir --threads 6"
      echo " mlsh corb --job jobName --taskDir path/taskDir [--threads 4] [--batchs 100]"
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

    "modules")
      echo "Usage: mlsh modules <command>"
      echo ""
      echo "Manage modules."
      echo ""
      echo "Examples:"
      echo " mlsh modules find"
      echo " mlsh modules deploy <module>"
      echo " mlsh modules undeploy <module>"
      ;;

    *)
      echo ""
      echo "mlsh <command> <args>                           # run a command"
      echo ""
      echo "Commands:"
      echo " mlsh init                                       # source this file"
      echo " mlsh env                                        # show the current environment"
      echo " mlsh update                                     # update mlsh from github (zip)"
      echo " mlsh qc [list|pull|push]                        # list workspaces/pull/push from/to query console"
      echo " mlsh log [OPTIONS]                              # show log for database"
      echo " mlsh corb <task> <job> <threads> <batchSize>    # run corb task"
      echo " mlsh eval <script> <db> <vars>                  # run eval script"
      echo " mlsh mlcp <args>                                # run mlcp"
      echo " mlsh modules <command>                          # manage modules"
      echo " mlsh help <command> .                           # for more info on a command"
      echo ""
      ;;
  esac
}

mlshUpdate() {
  echo "Updating mlsh from github..."
  local timestamp=$(date +%s)
  local OLD_DIR=$(pwd)
  local updir=/tmp/mlsh/$timestamp
  local force=$1
  if [ -z "$force" ]; then
    echo "Please use 'mlsh update -f' to replace files."
    force=false
  else
    force=true
  fi
  cd $MLSH_TOP_DIR
  test -d /tmp/mlsh && rm -rf /tmp/mlsh
  mkdir -p $updir
  local releaseInfo=$(curl -s https://api.github.com/repos/eurochriskelly/mlsh/releases/latest)
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
    mv $dir/* .
    echo "Update was copied to $(pwd). Please review and copy to $MLSH_TOP_DIR"
  fi
  rm -rf $dir
  cd $OLD_DIR 2>&1 > /dev/null
}

mlsh $@

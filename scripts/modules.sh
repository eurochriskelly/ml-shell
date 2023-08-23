#!/bin/bash
#
# Partial or single module
#
# - find matching modules in the database and download a list
# -

TS=$(date +%s)
TODAY=$(date +%Y%m%d)
QC_WORKDIR=$(pwd)
source $MLSH_TOP_DIR/scripts/common.sh

main() {
  #
  # show banner with name and version of tool
  #
  echo "--------------------------------------------------"
  echo "MLSH module loader"
  echo "Version: $MLSH_VERSION"
  echo "--------------------------------------------------"
  echo ""

  initialize
  local option=$1
  # doEval cleanupArtefacts "App-Services" 2>&1 > /dev/null
  # TODO: prep by backing up modules database
  if [ -z "$option" ]; then
    # Ask user to select from known options
    echo "Please select from the following options:"
    echo "1. find"
    echo "2. load"
    echo "3. reset"
    echo -n "Enter your choice: "
    read choice
    case $choice in
      1) option="find" ;;
      2) option="load" ;;
      3) option="reset" ;;
      *)
        echo "Unknown option [$option]"
        echo "Please select an option [find/load/reset]"
        echo "e.g."
        echo "mlsh modules find"
        cd $MLSH_TOP_DIR
        return
        ;;
    esac
    echo "User selected option [$option]"
  fi
  case $option in
    # Find matching modules in the database and download if required
    find|retrieve|match|search)
      shift
      local pattern=$1
      if [ -z "$pattern" ]; then
        echo -n "Please enter a pattern to match (e.g. *foo.xqy): "
        read $pattern
      fi
      echo "Searching for modules matching [$pattern]"
      findModules "$pattern"
      ;;

    # Load one or more locally edit modules into the database
    load|update)
      loadModules
      ;;

    # Reset the modules database
    reset)
      loadModules "reset"
      ;;

    *)
      echo "Unknown option [$option]"
      echo "Please select an option [match/load]"
      echo "e.g."
      echo "mlsh modules match"
      return
      ;;
  esac
}

# Find matching modules in the database and download if required
findModules() {
    local ddir=modules_${TODAY} # one directory for a given day is plenty
    II "Finding modules in database [$ML_MODULES_DB]"
    local pattern=$1
    local results=$(doEval moduleLister "${ML_MODULES_DB}" '{"pattern":"'${pattern}'"}')
    local i=1
    echo "Showing (max 50) results:"
    while read -r line; do
        local uri=$(echo $line | awk -F~ '{print $1}' )
        echo "  $i: $uri"
        i=$((i+1))
    done <<< "$results"
    echo "Enter a csv list of modules to download."
    echo -n "e.g. 2,5,6 or ALL for everything: "
    read choices
    if [ "$choices" == "ALL" ]; then
        choices=$(seq 1 $i)
    fi
    if [ -z "$choices" ]; then
        echo "No choices made, exiting."
        return
    fi

    mkdir -p $ddir/originals 2>&1 > /dev/null
    mkdir -p $ddir/edited 2>&1 > /dev/null

    # split choices by comma into array
    choices=(${choices//,/ })
    i=1
    while read -r line; do
        # loop through choices and download if required
        for c in "${choices[@]}"; do
            if [ "$c" == "$i" ]; then
                local uri=$(echo $line | awk -F~ '{print $1}' )
                local localName=$(echo $line | awk -F~ '{print $2}' )
                downloadModule "$uri" "$ddir/originals/$localName"
                echo ${line//#AMP#/&} >> $ddir/module-info.txt
            fi
        done
        i=$((i+1))
    done <<< "$results"
    for f in $(find $ddir/originals -type f);do
        cp $f $ddir/edited
    done
    # re-order the list in a deteministic way
    {
      cat $ddir/module-info.txt | sort | uniq > $ddir/module-info.txt.tmp
      mv $ddir/module-info.txt.tmp $ddir/module-info.txt
    }
    if [ -n "$(which tree)" ]; then
        tree $ddir
    fi
    echo "Modified module in $ddir/edited and update using 'mlsh modules load'"
}

##
 # Load one or more locally edit modules into the database
 #
loadModules() {
    local reset=
    if [ "$1" == "reset" ]; then
        reset="true"
    else
        reset="false"
    fi
    local ddir=modules_$(date +%Y%m%d) # one directory for a given day is plenty
    # if the current path contains $ddir then proceed
    if [[ $(pwd) != *"$ddir"* && ! -d "$ddir" ]]; then
        echo "Please run this command from the directory containing the modules to load"
        return
    fi

    # extract the path to the $ddir directory
    ddir=$(echo $(pwd) | awk -F$ddir '{print $1}' )/$ddir

    # read in each line in the module-info.txt file
    # and deploy the module
    while read -r line; do
        local uri=$(echo $line | awk -F~ '{print $1}' )
        local localName=$(echo $line | awk -F~ '{print $2}' )
        local perms=$(echo $line | awk -F~ '{print $3}' )
        local cols=$(echo $line | awk -F~ '{print $4}' )
        local localFile=
        if [ "$reset" == "true" ]; then
            localFile=$ddir/originals/$localName
        else
            localFile=$ddir/edited/$localName
        fi
        deployModule \
            "$localFile" "$uri" \
            "$perms" "$cols" "$reset"
    done < $ddir/module-info.txt
}


initialize() {
    if [ -z "$ML_ENV" ]; then
        echo "Please add 'source ~/.mlshrc' to your .bashrc or equivalent"
        exit 1
    fi
}

II() { echo "$(date +%Y-%m-%dT%H:%M:%S%z): $@"; }

deployModule() {
    local t=$1
    local dest=$2
    local perms=$3
    local cols=$4
    local reset=$5
    DD "$ML_PROTOCOL"
    local URL=
    BASE_URL="${ML_PROTOCOL}://${ML_HOST}:8000/v1/documents?"
    URL="${BASE_URL}uri=${dest}&"
    URL="${URL}format=json&"
    URL="${URL}database=${ML_MODULES_DB}&"
    local curlOpts=(
        --insecure
        -u "$ML_USER:$ML_PASS"
        -k --digest
        --silent
        -T "$t"
    )
    if [ -n "$CERT_PATH" ]; then
        # In environments having CERT_PATH defined
        curlOpts=(
            --cert-type p12
            --cert "${CERT_PATH}:${CERT_PASS}"
            "${curlOpts[@]}"
        )
    fi
    local getOpts=("${curlOpts[@]}" -X GET)

    ## PUT MODULE
    local putOpts=("${curlOpts[@]}" -X PUT)
    # TODO: insert modules in own modules-root
    URL="${BASE_URL}"
    URL="${URL}uri=${dest}&"
    URL="${URL}database=${ML_MODULES_DB}&"
    URL="${URL}${perms}"
    URL="${URL}&${cols}"
    if $reset;then
        URL="${URL}" # no extra collections
    else
        URL="${URL}collection=/mod/devel&"
        URL="${URL}collection=/mod/devel/${TODAY}&"
        URL="${URL}collection=/mod/update&"
    fi
    set -o xtrace
    curl "${putOpts[@]}" "$URL"
    set +o xtrace
    if $reset;then
      II "  Reset module [$dest]"
    else
      II "  Deployed module [$dest]"
    fi
}

downloadModule() {
    local uri=$1
    local fname=$2
    local db=${ML_MODULES_DB}
    local opts=(-X GET)
    echo "  Downloading module [$uri] to [$fname]"
    fetch "/v1/documents?uri=${uri}&database=${db}" "${opts[@]}" > "$fname"
  }

main $@

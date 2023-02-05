#!/bin/bash
#
# Partial or single module
#
# - find matching modules in the database and download a list
# -

TS=$(date +%s)
TODAY=$(date +%Y%m%d)
QC_WORKDIR=$(pwd)
source $MULSH_TOP_DIR/scripts/common.sh

main() {
  #
  # show banner with name and version of tool
  #
  echo "--------------------------------------------------"
  echo "MULSH module loader"
  echo "Version: $MULSH_VERSION"
  echo "--------------------------------------------------"
  echo ""

  initialize
  local option=$1
  # doEval cleanupArtefacts "App-Services" 2>&1 > /dev/null
  # TODO: prep by backing up modules database
  case $option in
    # Find matching modules in the database and download if required
    find|retrieve|match|search)
      shift
      findModules "$@"
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
      echo "mulsh modules match"
      return
      ;;
  esac
}

# Find matching modules in the database and download if required
findModules() {
    local ddir=modules_${TODAY} # one directory for a given day is plenty
    II "Finding modules in database [$ML_MODULES_DB]"
    local pattern=$1
    local results=$(doEval moduleLister "${ML_MODULES_DB}" "{\"pattern\":\"${pattern}\"}")
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
    echo "Modified module in $ddir/edited and update using 'mulsh modules load'"
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
        echo "Please add 'source ~/.mulshrc' to your .bashrc or equivalent"
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
    URL="${URL}${perms}&"
    URL="${URL}${cols}&"
    if $reset;then
        URL="${URL}" # no extra collections
    else
        URL="${URL}collection=/mod/devel&"
        URL="${URL}collection=/mod/devel/${TODAY}&"
        URL="${URL}collection=/mod/update&"
    fi
    curl "${putOpts[@]}" "$URL"
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

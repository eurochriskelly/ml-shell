#!/bin/bash
#
# Partial or single module
#
# - find matching modules in the database and download a list
# -

TS=$(date +%s)
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
  doEval cleanupArtefacts "App-Services" 2>&1 > /dev/null
  case $option in
    # Find matching modules in the database and download if required
    find)
      shift
      findModules "$@"
      ;;

    # Load one or more locally edit modules into the database
    load)
      loadModules
      ;;

    # Reset the modules database
    reset)
      resetModules
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

findModules() {
    local ddir=modules_$(date +%Y%m%d) # one directory for a given day is plenty
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
                downloadModule $uri $ddir/originals/$localName
                echo $line >> $ddir/module-info.txt
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

loadModules() {
    local ddir=modules_$(date +%Y%m%d) # one directory for a given day is plenty
    # if the current path contains $ddir then proceed
    if [[ $(pwd) != *"$ddir"* ]]; then
        echo "Please run this command from the directory containing the modules to load"
        return
    fi

    # extract the path to the $ddir directory
    echo "Ddir was $ddir"
    ddir=$(echo $(pwd) | awk -F$ddir '{print $1}' )$ddir

    echo "The right path is $ddir"
    return

    if [ ! -d "$ddir" ]; then
        echo "No modules found todays data"
        return
    fi
    d() { deploy-module "$1" "$2"; }
    II "Deploying modules ... "
    d api-1.xqy /contexts/cds/components/frbr/lib/api.xqy
}


initialize() {
    if [ -z "$ML_ENV" ]; then
        echo "Please add 'source ~/.mulshrc' to your .bashrc or equivalent"
        exit 1
    fi
}

II() { echo "$(date +%Y-%m-%dT%H:%M:%S%z): $@"; }

deploy-module() {
    local t=$1
    local dest=$2
    local URL=
    BASE_URL="${PROTOCOL}://${HOST}:8000/v1/documents?"
    URL="${BASE_URL}uri=${dest}&"
    URL="${URL}format=json&"
    URL="${URL}database=${ML_MODULES_DB}&"
    local curlOpts=(
        --insecure
        -u "$USER:$PASS"
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

    ## GET PERMISSIONS
    local response=$(curl "${getOpts[@]}" "${URL}category=permissions&")
    local len=$(echo $response | jq '.permissions | length')
    local PERMS=
    for i in $(seq 0 $(($len - 1))); do
        local perm=$(echo $response | jq -c ".permissions[$i]")
        for p in $perm; do
            local role=$(echo $p | jq -r '."role-name"')
            local caps=$(echo $p | jq -cr '.capabilities[]')
            for c in $caps; do
                PERMS="${PERMS}perm:${role}=${c}&"
            done
        done
    done

    ## GET COLLECTIONS
    local response=$(curl "${getOpts[@]}" "${URL}category=collections&")
    local cols=$(echo "$response" | jq -cr '.collections[]')
    local COLS=
    while read -r col; do
        COLS="${COLS}collection=${col}&"
    done <<<"$cols"
    local putOpts=("${curlOpts[@]}" -X PUT)
    # TODO: insert modules in own modules-root
    URL="${BASE_URL}"
    URL="${URL}uri=${dest}&"
    URL="${URL}database=${ML_MODULES_DB}&"
    URL="${URL}${PERMS}"
    URL="${URL}collection=/mod/devel&"
    URL="${URL}collection=/mod/devel/${TEST_SESSION}&"
    URL="${URL}${COLS}"
    URL="${URL}collection=/mod/update&"
    curl "${putOpts[@]}" "$URL"
    II "Deployed [$t] to [$dest]"
}

downloadModule() {
    local uri=$1
    local fname=$2
    local opts=(-X GET)
    echo "  Downloading module [$uri] to [$fname]"
    fetch "/v1/documents?uri=${uri}&database=${db}" "${opts[@]}" > "$fname"
  }

main $@

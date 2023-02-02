#!/bin/bash
#
#
#

# Import the contents of the current directory into the specified collection.
#
mlcpImport() {
  local path="$(pwd)"
  local collections=""
  local extension=

  echo "$@"
  echo '--'

  while [[ $# -gt 0 ]];do
    case $1 in
      --type)
        shift
        type=$1
        shift
        ;;

      --collections)
        shift
        collections=$1
        shift
        ;;

      --prefix)
        shift
        prefix=$1
        shift
        ;;

      *)
        echo "Unknown option [$1]"
        shift
        exit
        ;;
      esac
  done

  set -o xtrace
  "$MLCP_PATH" import \
    -mode local \
    -host $ML_HOST \
    -port $ML_PORT \
    -username $ML_USER \
    -password $ML_PASS \
    -input_file_path "$path" \
    -input_file_type "$type" \
    -output_uri_prefix "$prefix" \
    -output_collections "$collections" \
    -output_permissions "admin,read,admin,update"
    # -output_uri_replace "$3,''" \
    # -output_uri_suffix ".json" \
    # -output_uri_replace "$4,''"
  set +o xtrace
}

interactive() {
  # Get the user to choose import or export
  echo "Choose an option:"
  echo "  1. Import"
  echo "  2. Export"
  read -p "Option: " option

  case $option in
    "1")
      # Get user to choose the type of import
      echo "Import format?:"
      echo "  1. JSON"
      echo "  2. XML"
      echo "  3. TTL"

      read -p "Option: " format
      case $format in
        "1")
          type="json"
          ;;
        "2")
          type="xml"
          ;;
        "3")
          type="rdf"
          ;;
        *)
          type=$format
          return
          ;;
      esac

      # Get user to choose the collection to import into
      echo "Enter a csv list of collections?:"
      read -p "Collections: " collection

      # get user to choose prefix
      echo "Path Prefix? (e.g. /foo/bar/ => /foo/bar/abc.xml):"
      read -p "Prefix: " prefix

      # Show user selected options and ask for confirmation
      echo "Will run command: " mulsh mlcp import --collections $collection --type $type --prefix $prefix
      read -p "Continue? (y/n): " confirm
      if [ "$confirm" != "y" ]; then
        echo "Aborting"
        return
      fi
      mlcpImport --collections $collection --type $type --prefix $prefix
      ;;
    "2")
      mlcpExport
      ;;
    *)
      echo "Unknown option [$option]"
      return
      ;;
  esac
}

case $1 in
  "import")
    mlcpImport "${@:2}"
    ;;
  "export")
    mlcpExport "${@:2}"
    ;;
  *)
    echo "Unknown command [$1]"
    interactive "${@:2}"
    ;;
esac

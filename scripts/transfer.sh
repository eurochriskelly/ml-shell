#!/bin/bash
#
# This script is used to transfer data from one MarkLogic instance to another.
# Example usage:
#
# mlsh transfer --source local --target tst --collector collect.xqy
#
# Features:
# - Uses mlcp to transfer data from one MarkLogic instance to another
# - Use a local file collector or a named collector
# - Interactive interface if only top level command is provided

main() {
  ;;
}


main $@

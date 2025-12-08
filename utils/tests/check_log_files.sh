#!/usr/bin/env bash

# Usage: utils/tests/check_log_files.sh --gecko-path .
# Depends on a test_subfolders.txt file expected in a CONFIG directory next to the script

set -euo pipefail

# to-do:
# make a smk to create all possible ref indexes for the READ_MAPPING and run it before launching the tests 

# ------- CONFIG ------- #

configPath=$(dirname "$0")"/CONFIG"
dirsFile=${configPath}/test_subfolders.txt


# -------- ARGUMENTS -------- #

while [[ $# -gt 0 ]]
    do
    key="$1"
    case $key in
        --gecko-path)
        geckoPath=$(realpath "$2")
        shift
        shift
        ;;
        -*|*)
        echo -e "\nWARNING: "$1" option is unknown and will be ignored.\n"
        shift
        ;;
    esac
done


# -------- FUNCTIONS -------- #

sourceDependencies(){
    local geckoPath="$1"
    source "${geckoPath}/utils/utils.sh"
}


printLogInfo(){
    local testDir="$1"
    for log in "${testDir}"/slurm*out ; do
        echo "$log:"
        grep -i "error" "$log" || true
        grep 'of.*steps.*(.*%)' "$log" | tail -1 || true
        echo -e "\n"
    done
}

printAllTestsLogInfo(){
    echo -e "\n"
    for testDir in "${testDirs[@]}" ; do
        printLogInfo "${testDir}"
    done
}


# ---------- MAIN --------- #

sourceDependencies "$geckoPath"

setErrorExitMsg

importTestDirs "$dirsFile"

printAllTestsLogInfo




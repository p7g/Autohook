#!/usr/bin/env bash

# Autohook
# A very, very small Git hook manager with focus on automation
# Author:   Nik Kantar <http://nkantar.com>
# Version:  2.1.1
# Website:  https://github.com/nkantar/Autohook


echo() {
    builtin echo "[Autohook] $@";
}

printf() {
    builtin printf "[Autohook] $@"
}

debug-print() {
    if [ "$DEBUG" != '' ]; then
        >&2 echo "[DEBUG] $@"
    fi
}


install() {
    hook_types=(
        "applypatch-msg"
        "commit-msg"
        "post-applypatch"
        "post-checkout"
        "post-commit"
        "post-merge"
        "post-receive"
        "post-rewrite"
        "post-update"
        "pre-applypatch"
        "pre-auto-gc"
        "pre-commit"
        "pre-push"
        "pre-rebase"
        "pre-receive"
        "prepare-commit-msg"
        "update"
    )

    repo_root=$(git rev-parse --show-toplevel)
    debug-print "[install] found repo_root '$repo_root'"
    hooks_dir="$repo_root/.git/hooks"
    debug-print "[install] found hooks_dir '$hooks_dir'"
    autohook_linktarget="../../hooks/autohook.sh"
    for hook_type in "${hook_types[@]}"
    do
        hook_symlink="$hooks_dir/$hook_type"
        ln -s $autohook_linktarget $hook_symlink
        debug-print "[install] linked '$autohook_linktarget' to '$hook_symlink'"
    done
    debug-print '[install] done'
}


main() {
    calling_file=$(basename $0)
    debug-print "called by '$calling_file'"

    if [[ $calling_file == "autohook.sh" ]]
    then
        command=$1
        debug-print "called by autohook.sh, command is '$command'"
        if [[ $command == "install" ]]
        then
            debug-print "installing..."
            install
        fi
    else
        repo_root=$(git rev-parse --show-toplevel)
        hook_type=$calling_file
        symlinks_dir="$repo_root/hooks/$hook_type"
        files=("$symlinks_dir"/*)
        number_of_symlinks="${#files[@]}"
        if [[ $number_of_symlinks == 1 ]]
        then
            if [[ "$(basename ${files[0]})" == "*" ]]
            then
                number_of_symlinks=0
            fi
        fi
        echo "Looking for $hook_type scripts to run...found $number_of_symlinks!"
        if [[ $number_of_symlinks -gt 0 ]]
        then
            hook_exit_code=0
            for file in "${files[@]}"
            do
                scriptname=$(basename $file)
                echo "BEGIN $scriptname"
                eval $file &> /dev/null
                script_exit_code=$?
                if [[ $script_exit_code != 0 ]]
                then
                  hook_exit_code=$script_exit_code
                fi
                echo "FINISH $scriptname"
            done
            if [[ $hook_exit_code != 0 ]]
            then
              echo "A $hook_type script yielded negative exit code $hook_exit_code"
              exit $hook_exit_code
            fi
        fi
    fi
}


main "$@"

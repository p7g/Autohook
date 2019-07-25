#!/usr/bin/env bash

# Autohook
# A very, very small Git hook manager with focus on automation
# Author:   Nik Kantar <http://nkantar.com>
# Version:  2.1.1
# Website:  https://github.com/nkantar/Autohook


echo() {
    builtin echo "[Autohook] $@"
}

echo-verbose() {
    if [ "$VERBOSE" != '' ]; then
        echo "$@"
    fi
}

echo-error() {
    >&2 echo "[ERROR] $@"
}

printf() {
    builtin printf "[Autohook] $@"
}

printf-error() {
    fmt=$1
    shift
    >&2 printf "[ERROR] $fmt" "$@"
}

echo-debug() {
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
    echo-debug "[install] found repo_root '$repo_root'"
    hooks_dir="$repo_root/.git/hooks"
    echo-debug "[install] found hooks_dir '$hooks_dir'"
    autohook_linktarget="../../hooks/autohook.sh"
    for hook_type in "${hook_types[@]}"; do
        hook_symlink="$hooks_dir/$hook_type"
        ln -s $autohook_linktarget $hook_symlink
        echo-debug "[install] linked '$autohook_linktarget' to '$hook_symlink'"
    done
    echo-debug '[install] done'
}


link-script() {
    script_name=$1
    hook_type=$2
    extension=$3

    if [ "$script_name" == '' ] || [ "$hook_type" == '' ] || [ "$extension" == '' ]; then
        echo-error 'Expected script name, hook type, and extension args to link'
        return 1
    fi

    repo_dir=$(git rev-parse --show-toplevel) # git gives us an absolute path
    script_dir="$repo_dir/hooks/scripts"
    source_path="$script_dir/$script_name"
    target_path="$repo_dir/hooks/$hook_type/$extension/$script_name"

    mkdir -p "$(dirname $target_path)"

    ln -s $source_path $target_path
    return $?
}


main() {
    calling_file=$(basename $0)
    echo-debug "called by '$calling_file'"

    if [ $calling_file == "autohook.sh" ]; then
        command=$1
        echo-debug "called by autohook.sh, command is '$command'"
        if [ $command == "install" ]; then
            echo-debug "installing..."
            install
        elif [ "$command" == "link-script" ]; then
            echo-debug 'linking script'
            shift
            link-script "$@"
            exit $?
        fi
    else
        repo_root=$(git rev-parse --show-toplevel)
        hook_type=$calling_file
        symlinks_dir="$repo_root/hooks/$hook_type"

        echo-debug "[main] found repo root '$repo_root'"
        echo-debug "[main] hook type is '$hook_type'"
        echo-debug "[main] found symlinks dir '$symlinks_dir'"

        staged_files=$(git diff --cached --name-only | rev | sort | rev)
        echo-debug "[main] staged files: '$staged_files'"
        accumulator=
        last_extension=

        for staged_file in $staged_files ''; do # empty string allows us to run scripts for the last extension too
            echo-debug "[main] staged file: '$staged_file'"
            current_extension=${staged_file##*.}
            echo-debug "[main] previous extension '$last_extension' -> current extension '$current_extension'"
            if [ "$current_extension" != "$last_extension" ]; then
                echo-debug '[main] current extension is different from last extension'
                if [ "$last_extension" != '' ]; then # don't trigger on the first loop
                    echo-debug '[main] last extension is not empty, running scripts'
                    script_files=("$symlinks_dir/$last_extension"/*)
                    number_of_symlinks="${#script_files[@]}"
                    echo-debug "[main] found $number_of_symlinks symlinks: '$script_files'"
                    if [ $number_of_symlinks == 1 ]; then
                        if [ "$(basename ${script_files[0]})" == "*" ]; then
                            echo-debug '[main] only script file was "*", setting number_of_symlinks to 0'
                            number_of_symlinks=0
                        fi
                    fi
                    echo-verbose "Looking for $hook_type scripts to run...found $number_of_symlinks!"
                    if [ "$number_of_symlinks" -gt 0 ]; then
                        echo-debug '[main] had symlinks, running scripts'
                        hook_exit_code=0
                        for file in "${script_files[@]}"
                        do
                            scriptname=$(basename $file)
                            echo-verbose "BEGIN $scriptname for '$last_extension' extension"
                            echo-debug "[main] running '$file' with staged files '$accumulator'"
                            result=$(2>&1 AUTOHOOK_HOOK_TYPE="$hook_type" AUTOHOOK_STAGED_FILES=$accumulator AUTOHOOK_REPO_ROOT="$repo_root" $file)
                            script_exit_code=$?
                            if [ "$script_exit_code" != 0 ]; then
                                echo-debug "[main] script exited with $script_exit_code"
                                hook_exit_code=$script_exit_code
                            fi
                            echo-verbose "FINISH $scriptname for '$last_extension' extension"
                        done
                        if [ "$hook_exit_code" != 0 ]; then
                            echo-error "A $hook_type script yielded negative exit code $hook_exit_code"
                            printf-error "Result:\n%s\n" "$result"
                            exit $hook_exit_code
                        fi
                    fi
                fi
                if [ "$staged_file" == '' ]; then # end of staged files, break
                    echo-debug '[main] reached end of staged files'
                    break
                fi
                last_extension=$current_extension
                accumulator=
                echo-debug "[main] updating last extension to '$current_extension'"
            fi
            echo-debug "[main] appending '$staged_file' to accumulator"
            accumulator="$accumulator '$staged_file'"
        done
        echo-debug '[main] finished'
    fi
}


main "$@"

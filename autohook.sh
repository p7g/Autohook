#!/usr/bin/env bash

# Autohook
# A very, very small Git hook manager with focus on automation
# Author:   Nik Kantar <http://nkantar.com>
# Version:  2.1.1
# Website:  https://github.com/nkantar/Autohook


echo() {
    builtin echo "[Autohook] $*"
}

echo_verbose() {
    if [ "$AUTOHOOK_VERBOSE" != '' ]; then
        echo "$@"
    fi
}

echo_error() {
    >&2 echo "[ERROR] $*"
}

printf() {
    fmt=$1
    shift
    # shellcheck disable=SC2059
    builtin printf "[Autohook] $fmt" "$@"
}

printf_error() {
    fmt=$1
    shift
    # shellcheck disable=SC2059
    >&2 printf "[ERROR] $fmt" "$@"
}

echo_debug() {
    if [ "$AUTOHOOK_DEBUG" != '' ]; then
        >&2 echo "[DEBUG] $*"
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
    echo_debug "[install] found repo_root '$repo_root'"
    hooks_dir="$repo_root/.git/hooks"
    echo_debug "[install] found hooks_dir '$hooks_dir'"
    autohook_linktarget="../../hooks/autohook.sh"
    for hook_type in "${hook_types[@]}"; do
        hook_symlink="$hooks_dir/$hook_type"
        ln -s "$autohook_linktarget" "$hook_symlink"
        echo_debug "[install] linked '$autohook_linktarget' to '$hook_symlink'"
    done
    echo_debug '[install] done'
}


link_script() {
    script_name=$1
    hook_type=$2
    extension=$3

    if [ "$script_name" == '' ] || [ "$hook_type" == '' ]; then
        echo_error 'Expected script name, hook type, and extension args to link'
        return 1
    fi

    repo_dir=$(git rev-parse --show-toplevel) # git gives us an absolute path
    script_dir="$repo_dir/hooks/scripts"
    source_path="$script_dir/$script_name"
    target_path="$repo_dir/hooks/$hook_type"
    if [ "$extension" != '' ]; then
        target_path="$target_path/$extension"
    fi
    target_path="$target_path/$script_name"

    mkdir -p "$(dirname "$target_path")"

    ln -s "$source_path" "$target_path"
    return $?
}


run_symlinks() {
    if ! [ -d "$1" ]; then
        return
    fi

    script_files=()
    while IFS='' read -r script_file; do
        script_files+=("$script_file")
    done < <(find "$1" \( -type f -o -type l \) -maxdepth 1)

    hook_type=$2
    accumulator=$3
    number_of_symlinks="${#script_files[@]}"
    echo_debug "[main] found $number_of_symlinks symlinks: '${script_files[*]}'"
    if [ "$number_of_symlinks" -eq 1 ]; then
        if [ "$(basename "${script_files[0]}")" == "*" ]; then
            echo_debug '[main] only script file was "*", setting number_of_symlinks to 0'
            number_of_symlinks=0
        fi
    fi
    echo_verbose "Found $number_of_symlinks scripts"
    if [ "$number_of_symlinks" -gt 0 ]; then
        echo_debug '[main] had symlinks, running scripts'
        hook_exit_code=0
        for file in "${script_files[@]}"
        do
            scriptname=$(basename "$file")
            echo_verbose "BEGIN $scriptname"
            echo_debug "[main] running '$file' with staged files '$accumulator'"
            result=$(2>&1 AUTOHOOK_HOOK_TYPE="$hook_type" AUTOHOOK_STAGED_FILES=$accumulator AUTOHOOK_REPO_ROOT="$repo_root" $file)
            script_exit_code=$?
            if [ "$script_exit_code" != 0 ]; then
                echo_debug "[main] script exited with $script_exit_code"
                hook_exit_code=$script_exit_code
            fi
            echo_verbose "FINISH $scriptname"
        done
        if [ "$hook_exit_code" != 0 ]; then
            echo_error "A $hook_type script yielded negative exit code $hook_exit_code"
            printf_error "Result:\n%s\n" "$result"
            exit $hook_exit_code
        fi
    fi
}


main() {
    calling_file=$(basename "$0")
    echo_debug "called by '$calling_file'"

    if [ "$calling_file" == "autohook.sh" ]; then
        command=$1
        echo_debug "called by autohook.sh, command is '$command'"
        if [ "$command" == "install" ]; then
            echo_debug "installing..."
            install
        elif [ "$command" == "link-script" ]; then
            echo_debug 'linking script'
            shift
            link_script "$@"
            exit $?
        fi
    else
        repo_root=$(git rev-parse --show-toplevel)
        hook_type=$calling_file
        symlinks_dir="$repo_root/hooks/$hook_type"

        echo_debug "[main] found repo root '$repo_root'"
        echo_debug "[main] hook type is '$hook_type'"
        echo_debug "[main] found symlinks dir '$symlinks_dir'"

        echo_verbose "Running global $hook_type scripts"
        run_symlinks "$symlinks_dir" "$hook_type"
        echo_verbose "Finished running global $hook_type scripts"

        staged_files=$(git diff --cached --name-only | rev | sort | rev)
        echo_debug "[main] staged files: '$staged_files'"
        accumulator=()
        last_extension=

        if [ "$staged_files" != '' ]; then
            for staged_file in $staged_files ''; do # empty string allows us to run scripts for the last extension too
                echo_debug "[main] staged file: '$staged_file'"
                current_extension=${staged_file##*.}
                echo_debug "[main] previous extension '$last_extension' -> current extension '$current_extension'"
                if [ "$current_extension" != "$last_extension" ]; then
                    echo_debug '[main] current extension is different from last extension'
                    if [ "$last_extension" != '' ]; then # don't trigger on the first loop
                        echo_debug '[main] last extension is not empty, running scripts'
                        script_file_dir=$symlinks_dir/$last_extension
                        echo_verbose "Running scripts for $hook_type with extension $last_extension"
                        run_symlinks "$script_file_dir" "$hook_type" "$(IFS=$'\n'; builtin echo "${accumulator[*]}")"
                        echo_verbose "Finished running scripts for $hook_type with extension $last_extension"
                    fi
                    if [ "$staged_file" == '' ]; then # end of staged files, break
                        echo_debug '[main] reached end of staged files'
                        break
                    fi
                    last_extension=$current_extension
                    accumulator=()
                    echo_debug "[main] updating last extension to '$current_extension'"
                fi
                echo_debug "[main] appending '$staged_file' to accumulator"
                accumulator+=("$staged_file")
            done
        fi
        echo_debug '[main] finished'
    fi
}


main "$@"

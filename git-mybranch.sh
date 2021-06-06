#!/usr/bin/env bash

set -eu

readonly self_path="$0"
readonly VERSION="0.0.1"

function print_usage {
cat <<EOL
git-mybranch - Operate my draft branch

Usage:
    git mybranch [COMMAND] [ARGS...]
    git mybranch [ALIAS_FOR_LOG] [ARGS...]

Commands:
    rebase      Rebase my branch
    fixup       Create a fixup commit
    log         Show commits
    diff        Show file changes
    help        Print help
    version     Show version information
EOL
}

function print_version {
    echo "git-mybranch ${VERSION}"
}

function main {
    local subcommand="${1:-}"
    shift 1

    case "${subcommand}" in
        'rebase')
            rebase "$@"
            ;;
        'fixup')
            fixup
            ;;
        'log')
            log "$@"
            ;;
        'diff')
            diff "$@"
            ;;
        'help' | '-h')
            print_usage
            ;;
        'version')
            print_version
            ;;
        *)
            fallback_alias "${subcommand}" "$@"
            ;;
    esac
}

function mybranch/othrer_remote_refs {
    local current_remote ref_format='%(refname:short)'
    current_remote="$(git_silent branch --format='%(upstream:short)' --points-at HEAD)"
    if [ -z "${current_remote}" ]
    then
        git for-each-ref --format="${ref_format}" refs/remotes
    else
        git for-each-ref --format="${ref_format}" --no-contains="${current_remote}" refs/remotes
    fi
}

function mybranch/ancestor_commit {
    local refs
    refs="$(mybranch/othrer_remote_refs)"

    until [ "$(wc -l <<<"${refs}")" -le 1 ]
    do
        refs="$(mybranch/initial_commit <<<"${refs}" | sed -E 's/$/~/')"

    done
    echo "${refs}"
}

function mybranch/initial_commit {
    export -f oldest_commit
    # use xargs to avoid "Argument list too long"
    xargs -P 4 -r bash -c 'oldest_commit --not "$@"' _
}

# export
function oldest_commit {
    git log --oneline --pretty=format:"%h" --reverse HEAD "$@" | head -n 1
}

function fixup {
    if git diff --cached --quiet
    then
        print_error 'No staged changes. Use git add -p to add them.'
        exit 1
    fi

    local selected
    selected=$(fixup/select_commit)

    read -r commit _ <<<"${selected}"

    if [ -n "${commit}" ]
    then
        git commit --fixup "${commit}"
    fi
}

function fixup/select_commit {
    local ancestor_commit log_range log_format='%h - %s %C(green)(%cr) %C(cyan)<%an> %C(yellow)%d%C(reset)'
    ancestor_commit=$(mybranch/ancestor_commit)

    if [ -n "${ancestor_commit}" ]
    then
        log_range="${ancestor_commit}..HEAD"
    else
        log_range='HEAD'
    fi
    if which fzf &> /dev/null
    then
        export -f "fixup_preview"
        fixup/log "${log_range}" \
            | fzf --ansi --reverse --preview-window 'down:70%:+1' --preview "bash -c 'fixup_preview {}'"
    else
        local IFS=$'\n' PS3='fixup: '
        select item in $(fixup/log "${log_range}")
        do
            echo "${item}"
            break
        done
    fi
}

function fixup/log {
    local log_range="$1" log_range log_format='%h - %s %C(green)(%cr) %C(cyan)<%an> %C(yellow)%d%C(reset)'

    git log --oneline --first-parent \
            --grep='^fixup!' --invert-grep \
            --color --pretty=format:"${log_format}" \
            --abbrev-commit \
            --date=relative \
            "${log_range}"
}

# export
function fixup_preview {
    local commit="$1"

    printf '\e[0;90mStaged Changes:\e[0m\n'
    git diff --staged --stat --compact-summary

    fixup/preview/print_horizontal_line_full_width

    local show_format='%C(brightblack)Date: %ad%C(reset)%n%n    %s%n%n    %b%n'
    git show --color --stat --compact-summary --pretty=format:"${show_format}" "${commit}"
}

function fixup/preview/print_horizontal_line_full_width {
    printf '\e[0;90m──%.0s' "$(seq "$(tput cols)")"
    printf '\e[0m\n'
}

function rebase {
    local ancestor_commit
    ancestor_commit=$(mybranch/ancestor_commit)

    if [ -n "${ancestor_commit}" ]
    then
        git rebase "$@" "${ancestor_commit}"
    else
        git rebase "$@" --root
    fi
}

function log {
    local ancestor_commit
    ancestor_commit=$(mybranch/ancestor_commit)

    if [ -n "${ancestor_commit}" ]
    then
        git log "$@" "${ancestor_commit}..HEAD"
    else
        git log "$@" HEAD
    fi
}

function diff {
    local ancestor_commit
    ancestor_commit=$(mybranch/ancestor_commit)

    if [ -n "${ancestor_commit}" ]
    then
        git diff "$@" "${ancestor_commit}"
    else
        git diff "$@" HEAD
    fi
}

function fallback_alias {
    local alias_command="$1" alias_raw
    shift 1

    if alias_raw=$(git config --get "alias.${alias_command}")
    then
        read -r cmd _ <<<"${alias_raw}"
        case "${cmd}" in
            'log')
                bash -c "'${self_path}' ${alias_raw} "'"$@"' _ "$@"
                ;;
            *)
                print_error "alias '${alias_command}' is not an alias for 'log': ${alias_raw}"
                print_usage
                exit 1
                ;;
        esac
    else
        print_error "alias not found: '$1'"
        print_usage
        exit 1
    fi
}

function print_error {
    {
        echo -e "\e[31m$*\e[m"
    } >&2
}

function git_silent {
    git "$@" 2>/dev/null
}

main "$@"

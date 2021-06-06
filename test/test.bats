#!/usr/bin/env bats

function setup {
    load '../node_modules/bats-support/load'
    load '../node_modules/bats-assert/load'

    base_path="$(dirname "${BATS_TEST_DIRNAME}")"
    temp_path=$(mktemp -d)
    bin_path="${temp_path}/bin"
    repo_path="${temp_path}/git.git"
    work_path="${temp_path}/work"

    install -d "${bin_path}" "${repo_path}" "${work_path}"
    install -m 0744 "${base_path}/git-mybranch.sh" "${bin_path}/git-mybranch"

    PATH="${bin_path}:${PATH}"
    cd "${work_path}"

    setup_git_repository
}

function teardown {
    rm -rf "${temp_path}"
}

function setup_git_repository {
    git init --bare --shared "${repo_path}"

    git init
    git remote add origin "${repo_path}"

    touch a b c d e
    git add .

    git commit -m 'commit_a' a
    git push -u origin

    git checkout -b test
    git commit -m 'commit_b' b
    git commit -m 'commit_c' c
    git commit -m 'commit_d' d
    git commit -m 'commit_e' e
}

function fzf_stub {
    local stdout="$@"
cat <<EOF > "${bin_path}/fzf"
#!/usr/bin/env bash

echo '${stdout}'
EOF
    chmod +x "${bin_path}/fzf"
}

@test "log" {
    run git mybranch log --oneline
    assert_success
    assert_line --index 3 --partial 'commit_b'
    refute_line --index 4 --partial 'commit_a'
}

@test "diff" {
    run git mybranch diff --name-only
    assert_success
    assert_output --partial 'b' 'c' 'd' 'e'
    refute_output --partial 'a'
}

@test "fixup" {

    touch f
    git add .

    fzf_stub "$(git log --oneline -n 3 | tail -n1)"

    run git mybranch fixup
    assert_success
    assert_output --partial 'fixup! commit_c'
}

@test "rebase" {
    git checkout main
    touch g
    git add .
    git commit -m 'commit_g'
    git push -u origin
    git checkout test

    run git mybranch rebase --onto main
    assert_success

    run git log --oneline --first-parent
    assert_output --partial 'commit_g'
}

@test "print version" {
    run git mybranch version
    assert_success
    assert_line --regexp 'git-mybranch [0-9]+\.[0-9]+\.[0-9]+'
}

@test "print help" {
    run git mybranch help
    assert_success
    assert [ -n "${output}" ]
}

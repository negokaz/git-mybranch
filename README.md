# git-mybranch

A Git subcommand for operates your draft branch

## Usages

Show your commits like *Commits* in GitHub Pull Request

```
git mybranch log
```

Create a fixup commit to your created commits in current branch

You can choose a commit interactively if `fzf` is installed
```
git mybranch fixup
```

Rebase your branch onto the specified branch

```
git mybranch rebase --onto origin/main
```

Edit (rebase) your branch interactively

```
git mybranch rebase -i
```

Show your commits like *Files changed* in GitHub Pull Request

```
git mybranch diff
```

## Install

```
curl -L https://raw.githubusercontent.com/negokaz/git-mybranch/main/git-mybranch.sh \
    -o /usr/local/bin/git-mybranch \
&& chmod +x /usr/local/bin/git-mybranch
```

## LICENSE

Copyright (c) 2021 Kazuki Negoro

git-mybranch is released under the [MIT License](LICENSE)

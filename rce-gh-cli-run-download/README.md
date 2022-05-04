# [UNPATCHED] Cli: gh run download implementation allows overwriting git repository configuration upon artifacts downloading

Hi there!

## TL;DR

**Asset**: [GitHub’s official command line tool](https://github.com/cli/cli)

**Screencast:** [HERE](https://keybase.pub/metnew/gh_cli_run_download_rce.mov) 

**Impact:** Running `gh run download` on untrusted repository may lead to arbitrary code execution.

**Fix: Github decided not to patch this issue.**

**PoC**

```bash
# Clone malicious repo
$ git clone https://github.com/Metnew/gh_run_download_git_artifacts
# Download the maliicous artifact **interactively**
$ gh run download
# OR download the specific version directly
# However, in this case the artifact may require some slight modifications (untested)
# $ gh run download 216442041
# Boom!
$ git fetch
# OR just navigate to the dir with zsh
```

Bounty: **$500** (donated to https://www.comebackalive.in.ua/)

**my 2cents**

I disagree with the decision of Github team.
This bug fits into [the definition of in-scope bugs for CLI](https://bounty.github.com/targets/github-cli.html)
> Code execution that requires minimal, expected user interaction, such as performing actions on a repository that a user would not expect to lead to code execution

IMO, the report should have been triaged and rewarded at least at "Medium" severity.
Real CVSS is high, though.


## Writing to `<root>/.git/` with `gh run download`

```
USAGE
  gh run download [<run-id>] [flags]

FLAGS
  -D, --dir string         The directory to download artifacts into (default ".")
```

By default, `gh run download` command puts artifacts in the current dir. It can't overwrite files though, only create new ones. There are also no restrictions on the name/path of the files to be written (only path traversal check).

It means, it's possible to craft an artifact that creates new files in `<root>/.git/*` upon `gh run download`. 

## Achieving code execution with `.git/commondir`

[What's `.git/commondir`?](https://git-scm.com/docs/gitrepository-layout#Documentation/gitrepository-layout.txt-commondir)
> **commondir**
> If this file exists, $GIT_COMMON_DIR (see git[1]) will be set to the path specified in this file if it is not explicitly set. If the specified path is relative, it is relative to $GIT_DIR. The repository with commondir is incomplete without the repository pointed by "commondir".

With `.git/commondir` it's possible to re-define `$GIT_COMMON_DIR` for the current repository and therefore supply an attacker-crafted `.gitconfig` for the repo.
This effectively allows the attacker to run arbitrary commands once user (or any of user's devtools) run any git command (e.g., git fetch or similar).

**Step-by-step**

1. `gh run download`
2. the downloaded artifact has fileee `.git/commondir` pointing to `./poc` and `.git/poc` git repository with malicious `.gitconfig`
3. gh cli writes artifact files to `.git`
3. now the actual gitconfig in effect isn't `/.git/config`, but `.git/poc/config`
3. user tooling interacts with the repository (regular `git diff` in github desktop) OR user runs some git command (e.g., `git fetch`)
4. code execution!

> A malicious payload can be achieved through gitconfig properties (core.gitproxy, core.sshCommand, credential.helper), git hooks (see below), git filters.

## Achieving code execution with git hooks

> it's possible to leverage `commondir` scenario to re-define `core.hooksPath` and make executable hooks a part of the repository. In this case, they'll have `+x` flag, and rce via git hooks will be accomplishable. 

There is a well-known issue of `actions/upload` [reseting file permissions](https://github.com/actions/upload-artifact/issues/38) of artifacts.
> Funny enough, adding `+x` to all artifacts initially was a (default behaviour)[https://github.com/actions/upload-artifact/issues/20].

Thus, at this moment the malicious hooks written into `.git/hooks` are not executable :( 
But this scenario will be actual as soon as the above-mentioned issue is fixed.

> I can't imagine someone managing to have all of possible client-side git hooks (even non-standard!) configured, so there always be a place for a malicious one (+ git-p4* hooks). 
```
applypatch-msg pre-commit commit-msg    pre-merge fsmonitor-watchman    pre-merge-commit post-applypatch       pre-push
post-checkout  pre-rebase post-index-change  pre-receive post-merge prepare-commit-msg
post-rewrite  push-to-checkout post-update  reference-transaction pre-applypatch sendemail-validate pre-auto-gc update
```
In this scenario malicious code will be executed upon running any porcelain git command:  `git fetch`, `pull`, `push`, `checkout`, `commit`, `merge`, `rebase`, `am`, `add`, `rm`.

## Impact

Manipulation of repository configuration leading to code execution.

The attack can be **carried out unnoticeable**  for the victim running `git status` or similar, because it's possible to drop the payload directly into the `.git` folder. 

The attack can be effectively used by an insider against other contributors to the same repository (it's very unlikely someone checks .git folder everytime they pull new artifacts).

## Similar bugs in git

Here's a quote from [git/git release notes](https://github.com/git/git/commit/f1b50ec6f85883c483b344442c69cd3d88b38380) about [CVE-2022-24765](https://nvd.nist.gov/vuln/detail/CVE-2022-24765), which is pretty similar:

> Merely having a Git-aware prompt that runs `git status` (or `git diff`) and navigating to a directory which is supposedly not a Git worktree, or opening such a directory in an editor or IDE such as VS Code or Atom, will potentially run commands defined by that other user.

[CVE-2022-24765](https://nvd.nist.gov/vuln/detail/CVE-2022-24765) description:
>  Git Bash users who set `GIT_PS1_SHOWDIRTYSTATE` are vulnerable as well. Users who installed posh-gitare vulnerable simply by starting a PowerShell. Users of IDEs such as Visual Studio are vulnerable: simply creating a new project would already read and respect the config specified in ..... Users of the Microsoft fork of Git are vulnerable simply by starting a Git Bash.

## Response from Github

Hi @metnew, 

Thanks again for this submission and for your patience while we investigated it! We thoroughly analyzed this finding and determined that this behavior is working as expected. [As stated in the CLI documentation for the `gh run download` command](https://cli.github.com/manual/gh_run_download), this command is intended to:
> Download artifacts generated by a GitHub Actions workflow run.
> The contents of each artifact will be extracted under separate directories based on the artifact name. If only a single artifact is specified, it will be extracted into the current directory.

Furthermore, expoiting this finding requires social engineering and user interaction, which is considered out of scope for the CLI, [as noted in our bounty site](https://bounty.github.com/targets/github-cli.html):
> Code execution requiring social-engineering or unlikely user interaction is typically not eligible for rewards.

Even though your report is ineligible for a full bounty reward, we appreciate you bringing this issue to our attention. As thanks for your submission, we would like to offer you a small award. If you would like to donate your reward and have it matched by GitHub, [please follow the instructions for submitting a donation request to HackerOne](https://bounty.github.com/#receiving_your_award).

Best regards and happy hacking!
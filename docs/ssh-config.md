# Hosts and tags in ~/.ssh/config

[← Back](../README.md)

`~/.ssh/config` gives each server a short name, so `ssh web1` is enough instead of `ssh admin@192.0.2.10`.
homelab uses the same names, and finds the servers for a menu by a comment line with tags.

## Example

```
# Defaults for every host (optional); a block without tags is never listed
Host *
    User admin
    IdentityFile ~/.ssh/id_ed25519

Host web1
    HostName 192.0.2.10
    # TAGS: Debian, Docker, OS

Host db1
    HostName 192.0.2.11
    # TAGS: Debian, OS

Host pve1
    HostName 192.0.2.20
    User root
    # TAGS: Cluster
```

The main menu then shows `Cluster`, `Debian`, `Docker`, `OS`; `Debian` lists web1 and db1.

A tag can be anything that helps you pick: the system (`Debian`, `Ubuntu`), a role (`Docker`), or a group
for one job, like `OS` on every host whose packages you update together.

## Rules

- `Host` starts at the beginning of the line, with one name. homelab takes only the first name after `Host`.
- `# TAGS:` goes inside its host's block: after its `Host` line, before the next one. Write `TAGS` in capitals,
  with the colon.
- Separate tags with commas or spaces. Capitals count: `Debian` and `debian` are two tags.
- A tag matches as a whole word: the tag `web` doesn't pick a host tagged `webserver`.
- A host without a `# TAGS:` line isn't in any menu, but `ssh` still knows it.
- Hosts are listed in the order they have in the file.

## Log in with a key

homelab checks every host first, without asking anything (`BatchMode`, 5 seconds), so a host that wants a
password counts as unreachable. Set up a key once per host:

```bash
ssh-keygen -t ed25519          # once, if you have no key yet (~/.ssh/id_ed25519)
ssh-copy-id web1               # asks the password one last time
ssh web1                       # must log in without a password now
```

`sudo` on the host may still ask for its password; homelab shows that prompt.

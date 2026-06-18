# SSHLog for Termux (Android)

This is a customized fork of [sshlog/agent](https://github.com/sshlog/agent) patched specifically to compile and run natively on Android within the **Termux** environment.

SSHLog is a daemon that passively monitors OpenSSH servers via eBPF to record terminal sessions, watch command executions, and trigger plugins (e.g. posting Slack messages on active SSH logins).

---

## 🚀 One-Click Termux Installer

To install all dependencies, compile the native C++ library, patch the necessary eBPF compile tools (`bpftool`), configure the Python daemon, and install system CLI wrappers, run the following commands:

```bash
git clone --recurse-submodules https://github.com/ibidathoillah/sshlog-termux.git
cd sshlog-termux
./install.sh
```

---

## ⚡ How to Run

> [!IMPORTANT]
> Because `sshlog` uses eBPF kernel triggers to passively monitor processes, **root permissions** (`tsu` or `su`) are required to run the daemon.

### 1. Start the Daemon (as root)
```bash
tsu
sshlogd --logfile /data/data/com.termux/files/usr/var/log/sshlog/sshlogd.log
```

### 2. Monitor SSH Sessions (as root)
Using the `sshlog` client utility:
* **List active sessions**:
  ```bash
  sshlog sessions
  ```
* **Watch events in real-time**:
  ```bash
  sshlog watch
  ```
* **Attach to active session TTY (read-only or interactive)**:
  ```bash
  sshlog attach [TTY_ID]
  ```

---

## ⚙️ Configuration & Customization
- **Config Folder**: `/data/data/com.termux/files/usr/etc/sshlog/`
  - Active plugins and event rules are configured under `/data/data/com.termux/files/usr/etc/sshlog/conf.d/`.
- **Log Files**: Logs are written to `/data/data/com.termux/files/usr/var/log/sshlog/`.

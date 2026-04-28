# Gaze - Kali Repository Wrapper 👁️

Gaze is a powerful, isolated CLI utility that allows you to securely turn any Debian-based Linux distribution (like Parrot OS, Ubuntu, Debian, or Zorin) into a full-fledged Penetration Testing distribution by safely accessing the Kali Linux repositories.

## ❓ Why use Gaze?
Adding Kali repositories directly to your host system's `sources.list` is extremely dangerous and can break your OS during normal updates (creating what is known as a "FrankenDebian"). 

Gaze solves this by creating a **100% isolated** `apt` configuration environment. It temporarily points package manager searches and installations to the official Kali repositories *without ever modifying your system's actual sources*. 

* 🛡️ **Totally Safe:** Never breaks your system updates. Your normal `sudo apt upgrade` remains completely safe.
* 📦 **Native Installation:** Tools install natively to your system and are accessible globally.
* 🚀 **Self-Installing:** Run it once and it intelligently installs itself to your system paths.

## 📥 Installation

You can download, make executable, and launch Gaze in a single command using `wget`:

```bash
wget -qO gaze https://raw.githubusercontent.com/ASWIN-S-OO6/gaze/main/gaze.sh && chmod +x gaze && sudo ./gaze
```

*Note: Gaze requires root (`sudo`) privileges because it handles package management.*

### Launching

Once run for the first time, Gaze automatically installs itself globally. For all future uses, simply open your terminal from anywhere and type:

```bash
sudo gaze
```

## 🛠️ Features
- **Search:** Quickly search the massive Kali Linux repository for specific tools (e.g., `nmap`, `gobuster`, `metasploit-framework`).
- **Install & Uninstall:** Install pentesting tools seamlessly. Dependencies are automatically resolved and fetched.
- **List Installed Tools:** Keep track of exactly what packages you have installed through Gaze.
- **Isolated Upgrades:** Safely upgrade *only* the tools you installed via Gaze without accidentally upgrading your core OS packages.

## 💻 Compatibility
Gaze is designed to work on any Debian-based Linux distribution that utilizes the APT package manager, including:
- Parrot OS
- Ubuntu
- Linux Mint
- Zorin OS
- Debian based distros


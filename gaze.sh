#!/bin/bash

# ==============================================================================
# Gaze - Kali Repository Wrapper
# A tool to turn any distro into a pentest distro using Kali repos safely.
# ==============================================================================

export NEWT_COLORS="root=white,blue:window=white,blue:border=white,blue:shadow=black,black:button=black,white:actbutton=white,cyan:title=white,blue:roottext=white,blue:textbox=white,blue:actlistbox=white,cyan:sellistbox=white,blue:listbox=white,blue"

GAZE_DIR="/etc/gaze"
GAZE_LIB="/var/lib/gaze"
GAZE_CACHE="/var/cache/gaze"

setup_env() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\e[31m[-] Gaze requires root privileges. Please run with sudo.\e[0m"
        exit 1
    fi

    # Self-install mechanism
    if [[ "$(realpath "$0")" != "/usr/local/bin/gaze" && "$(realpath "$0")" != "/usr/bin/gaze" ]]; then
        echo -e "\e[34m[+]\e[0m Installing gaze to /usr/local/bin/gaze..."
        cp "$0" /usr/local/bin/gaze
        chmod +x /usr/local/bin/gaze
        echo -e "\e[34m[+]\e[0m Installation complete. You can now use the 'gaze' command anywhere."
        echo -e "\e[34m[+]\e[0m Launching Gaze..."
        exec /usr/local/bin/gaze "$@"
    fi

    # Check dependencies silently, install if missing
    for cmd in whiptail wget gpg; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "\e[33m[*]\e[0m Installing missing dependency: $cmd"
            apt-get update -qq && apt-get install -y "$cmd" -qq
        fi
    done

    # Create isolated directory structure
    mkdir -p "$GAZE_DIR"
    mkdir -p "$GAZE_LIB/lists/partial"
    mkdir -p "$GAZE_CACHE/archives/partial"
    touch "$GAZE_DIR/installed_tools.log"

    # Fetch Kali Keyring if missing
    if [ ! -f "$GAZE_DIR/kali-archive-keyring.gpg" ]; then
        echo -e "\e[34m[*]\e[0m Fetching Kali Linux Archive Key..."
        wget -q -O "$GAZE_DIR/archive-key.asc" https://archive.kali.org/archive-key.asc
        if [ -s "$GAZE_DIR/archive-key.asc" ]; then
            gpg --yes --dearmor < "$GAZE_DIR/archive-key.asc" > "$GAZE_DIR/kali-archive-keyring.gpg"
            rm -f "$GAZE_DIR/archive-key.asc"
        else
            echo -e "\e[31m[-]\e[0m Failed to download Kali key. Check your internet connection."
            exit 1
        fi
    fi

    # Create isolated sources.list
    cat > "$GAZE_DIR/sources.list" <<EOF
deb [signed-by=$GAZE_DIR/kali-archive-keyring.gpg] http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
EOF

    # Create isolated apt config
    cat > "$GAZE_DIR/apt.conf" <<EOF
Dir::State::Lists "$GAZE_LIB/lists";
Dir::Etc::SourceList "$GAZE_DIR/sources.list";
Dir::Etc::SourceParts "/dev/null";
Dir::Cache::Archives "$GAZE_CACHE/archives";
Dir::Cache::pkgcache "$GAZE_CACHE/pkgcache.bin";
Dir::Cache::srcpkgcache "$GAZE_CACHE/srcpkgcache.bin";
EOF
}

run_apt() {
    APT_CONFIG="$GAZE_DIR/apt.conf" apt-get "$@"
}

run_apt_cache() {
    APT_CONFIG="$GAZE_DIR/apt.conf" apt-cache "$@"
}

update_lists() {
    TMP_OUT=$(mktemp)
    run_apt update -o APT::Status-Fd=3 > "$TMP_OUT" 2>&1 3> >( \
        awk -F: '/^dlstatus:/ || /^pmstatus:/ { print $3; fflush() }' | \
        whiptail --title "Updating Repositories" --gauge "Downloading lists..." 10 60 0 \
    )
    if [ $? -eq 0 ]; then
        whiptail --title "Success" --msgbox "Kali repository lists updated successfully." 10 60
    else
        whiptail --title "Update Failed" --scrolltext --textbox "$TMP_OUT" 20 80
    fi
    rm -f "$TMP_OUT"
}

search_tool() {
    QUERY=$(whiptail --title "Search Kali Repositories" --inputbox "Enter search term (e.g., nmap, gobuster):" 10 60 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ] && [ -n "$QUERY" ]; then
        TMP_OUT=$(mktemp)
        run_apt_cache search "$QUERY" > "$TMP_OUT" 2>&1
        if [ -s "$TMP_OUT" ]; then
            whiptail --title "Search Results for '$QUERY'" --scrolltext --textbox "$TMP_OUT" 20 80
        else
            whiptail --title "Search Results" --msgbox "No packages found for '$QUERY'." 10 60
        fi
        rm -f "$TMP_OUT"
    fi
}

install_tool() {
    TOOL=$(whiptail --title "Install Kali Tool" --inputbox "Enter the exact package name to install:" 10 60 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ] && [ -n "$TOOL" ]; then
        TMP_OUT=$(mktemp)
        export DEBIAN_FRONTEND=noninteractive
        run_apt -y install "$TOOL" -o APT::Status-Fd=3 > "$TMP_OUT" 2>&1 3> >( \
            awk -F: '/^pmstatus:/ || /^dlstatus:/ { print $3; fflush() }' | \
            whiptail --title "Installing $TOOL" --gauge "Installing package..." 10 60 0 \
        )
        if [ $? -eq 0 ]; then
            echo "$TOOL" >> "$GAZE_DIR/installed_tools.log"
            sort -u "$GAZE_DIR/installed_tools.log" -o "$GAZE_DIR/installed_tools.log"
            whiptail --title "Success" --msgbox "$TOOL has been successfully installed." 10 60
        else
            whiptail --title "Installation Failed" --scrolltext --textbox "$TMP_OUT" 20 80
        fi
        rm -f "$TMP_OUT"
    fi
}

uninstall_tool() {
    TOOL=$(whiptail --title "Uninstall Tool" --inputbox "Enter the package name to uninstall:" 10 60 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ] && [ -n "$TOOL" ]; then
        TMP_OUT=$(mktemp)
        export DEBIAN_FRONTEND=noninteractive
        run_apt -y remove "$TOOL" -o APT::Status-Fd=3 > "$TMP_OUT" 2>&1 3> >( \
            awk -F: '/^pmstatus:/ || /^dlstatus:/ { print $3; fflush() }' | \
            whiptail --title "Uninstalling $TOOL" --gauge "Removing package..." 10 60 0 \
        )
        if [ $? -eq 0 ]; then
            if [ -f "$GAZE_DIR/installed_tools.log" ]; then
                sed -i "/^$TOOL\$/d" "$GAZE_DIR/installed_tools.log"
            fi
            whiptail --title "Success" --msgbox "$TOOL has been successfully uninstalled." 10 60
        else
            whiptail --title "Uninstallation Failed" --scrolltext --textbox "$TMP_OUT" 20 80
        fi
        rm -f "$TMP_OUT"
    fi
}

list_tools() {
    if [ -f "$GAZE_DIR/installed_tools.log" ] && [ -s "$GAZE_DIR/installed_tools.log" ]; then
        whiptail --title "Tools installed via Gaze" --scrolltext --textbox "$GAZE_DIR/installed_tools.log" 20 60
    else
        whiptail --title "Installed Tools" --msgbox "No tools installed via Gaze yet." 10 60
    fi
}

upgrade_tools() {
    if [ -f "$GAZE_DIR/installed_tools.log" ] && [ -s "$GAZE_DIR/installed_tools.log" ]; then
        PACKAGES=$(tr '\n' ' ' < "$GAZE_DIR/installed_tools.log")
        TMP_OUT=$(mktemp)
        export DEBIAN_FRONTEND=noninteractive
        run_apt -y install --only-upgrade $PACKAGES -o APT::Status-Fd=3 > "$TMP_OUT" 2>&1 3> >( \
            awk -F: '/^pmstatus:/ || /^dlstatus:/ { print $3; fflush() }' | \
            whiptail --title "Upgrading Tools" --gauge "Upgrading packages..." 10 60 0 \
        )
        if [ $? -eq 0 ]; then
            whiptail --title "Success" --msgbox "Tools upgraded successfully." 10 60
        else
            whiptail --title "Upgrade Failed" --scrolltext --textbox "$TMP_OUT" 20 80
        fi
        rm -f "$TMP_OUT"
    else
        whiptail --title "Upgrade" --msgbox "No tools installed via Gaze to upgrade." 10 60
    fi
}

browse_categories() {
    while true; do
        CAT_CHOICE=$(whiptail --title "Browse Categories" --menu "Select a Category:" 20 70 12 \
            "kali-tools-information-gathering" "Information Gathering" \
            "kali-tools-vulnerability" "Vulnerability Analysis" \
            "kali-tools-web" "Web Application Analysis" \
            "kali-tools-database" "Database Assessment" \
            "kali-tools-passwords" "Password Attacks" \
            "kali-tools-wireless" "Wireless Attacks" \
            "kali-tools-reverse-engineering" "Reverse Engineering" \
            "kali-tools-exploitation" "Exploitation Tools" \
            "kali-tools-social-engineering" "Social Engineering" \
            "kali-tools-sniffing-spoofing" "Sniffing & Spoofing" \
            "kali-tools-post-exploitation" "Post Exploitation" \
            "kali-tools-forensics" "Forensics" \
            "kali-tools-reporting" "Reporting Tools" \
            "Back" "Return to Main Menu" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ] || [ "$CAT_CHOICE" = "Back" ]; then
            break
        fi

        CATEGORY="$CAT_CHOICE"

        while true; do
            ACTION=$(whiptail --title "Category: $CATEGORY" --menu "Choose an action:" 14 60 3 \
                "1" "View Tools in Category" \
                "2" "Install Entire Category" \
                "3" "Back" 3>&1 1>&2 2>&3)

            if [ $? -ne 0 ] || [ "$ACTION" = "3" ]; then
                break
            fi

            if [ "$ACTION" = "1" ]; then
                TMP_OUT=$(mktemp)
                run_apt_cache depends "$CATEGORY" 2>/dev/null | grep -E "  Depends:|  Recommends:" | cut -d':' -f2 | tr -d ' ' | sort -u | column -c 70 > "$TMP_OUT"
                if [ -s "$TMP_OUT" ]; then
                    whiptail --title "Tools in $CATEGORY" --scrolltext --textbox "$TMP_OUT" 22 80
                else
                    whiptail --title "Error" --msgbox "Could not fetch tools. Make sure you updated the Kali Repo Lists." 10 60
                fi
                rm -f "$TMP_OUT"
            elif [ "$ACTION" = "2" ]; then
                TMP_OUT=$(mktemp)
                export DEBIAN_FRONTEND=noninteractive
                run_apt -y install "$CATEGORY" -o APT::Status-Fd=3 > "$TMP_OUT" 2>&1 3> >( \
                    awk -F: '/^pmstatus:/ || /^dlstatus:/ { print $3; fflush() }' | \
                    whiptail --title "Installing $CATEGORY" --gauge "Installing tools..." 10 60 0 \
                )
                if [ $? -eq 0 ]; then
                    echo "$CATEGORY" >> "$GAZE_DIR/installed_tools.log"
                    sort -u "$GAZE_DIR/installed_tools.log" -o "$GAZE_DIR/installed_tools.log"
                    whiptail --title "Success" --msgbox "$CATEGORY has been successfully installed." 10 60
                else
                    whiptail --title "Installation Failed" --scrolltext --textbox "$TMP_OUT" 20 80
                fi
                rm -f "$TMP_OUT"
            fi
        done
    done
}

main_menu() {
    # Initial repository sync if empty
    if [ -z "$(ls -A "$GAZE_LIB/lists" 2>/dev/null | grep -v 'partial')" ]; then
        whiptail --title "Initial Setup" --msgbox "Kali repository lists are empty. Gaze will now download them for the first time." 10 60
        update_lists
    fi

    # Detect OS Name
    OS_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    if [ -z "$OS_NAME" ]; then
        OS_NAME=$(uname -s)
    fi

    while true; do
        CHOICE=$(whiptail --title "Gaze - Pentest Toolkit Manager ($OS_NAME)" --menu "Choose an action:" 18 70 8 \
            "1" "Search for a Tool" \
            "2" "Install a Tool" \
            "3" "Browse Categories" \
            "4" "Uninstall a Tool" \
            "5" "List Installed Tools" \
            "6" "Update Kali Repo Lists" \
            "7" "Upgrade Gaze Tools" \
            "8" "Exit" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            break
        fi

        case $CHOICE in
            1) search_tool ;;
            2) install_tool ;;
            3) browse_categories ;;
            4) uninstall_tool ;;
            5) list_tools ;;
            6) update_lists ;;
            7) upgrade_tools ;;
            8) break ;;
        esac
    done
    
    # Reset terminal colors to fix background issues
    tput sgr0 2>/dev/null || echo -ne "\e[0m"
    clear
}

setup_env "$@"
main_menu

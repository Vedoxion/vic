#!/usr/bin/env bash
# VPS Toolkit: Certbot Auto-SSL + User Management + Port Forwarding (TUI)
# Tested on: Ubuntu/Debian, RHEL/CentOS/Alma/Rocky
set -euo pipefail

# ---------- Helpers ----------
RED=$(tput setaf 1 || true); GRN=$(tput setaf 2 || true); YLW=$(tput setaf 3 || true); BLU=$(tput setaf 4 || true); CLR=$(tput sgr0 || true)

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "${RED}Please run as root (sudo).${CLR}"; exit 1
  fi
}

PAK=""
PKG_INSTALL=""
detect_os() {
  if command -v apt >/dev/null 2>&1; then
    PAK="apt"; PKG_INSTALL="apt-get update -y && apt-get install -y"
  elif command -v dnf >/dev/null 2>&1; then
    PAK="dnf"; PKG_INSTALL="dnf install -y"
  elif command -v yum >/dev/null 2>&1; then
    PAK="yum"; PKG_INSTALL="yum install -y"
  else
    echo "${RED}Unsupported distro (needs apt/dnf/yum).${CLR}"; exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_whiptail() {
  if ! have_cmd whiptail; then
    if [[ "$PAK" == "apt" ]]; then
      eval "$PKG_INSTALL" whiptail
    else
      eval "$PKG_INSTALL" newt
      ln -sf /usr/bin/whiptail /usr/bin/whiptail || true
    fi
  fi
}

msg() {
  whiptail --title "$1" --msgbox "$2" 12 72
}

ask_text() { # $1=title $2=prompt $3=default -> stdout
  whiptail --title "$1" --inputbox "$2" 10 72 "$3" 3>&1 1>&2 2>&3
}

ask_yesno() { # returns 0 for Yes
  whiptail --title "$1" --yesno "$2" 10 72
}

ask_menu() { # $1=title $2=prompt $3... items (tag desc pairs)
  whiptail --title "$1" --menu "$2" 20 78 10 "${@:3}" 3>&1 1>&2 2>&3
}

log() { echo "$@"; }

# ---------- Common packages ----------
ensure_base_tools() {
  if [[ "$PAK" == "apt" ]]; then
    apt-get update -y
    apt-get install -y curl ca-certificates software-properties-common iproute2 iptables
  else
    eval "$PKG_INSTALL" curl ca-certificates iproute iptables
  fi
}

persist_iptables() {
  if [[ "$PAK" == "apt" ]]; then
    if ! have_cmd netfilter-persistent; then
      apt-get install -y iptables-persistent
    fi
    netfilter-persistent save
  else
    if have_cmd service && service iptables status >/dev/null 2>&1; then
      service iptables save || true
    elif have_cmd iptables-save; then
      iptables-save > /etc/iptables.rules
      grep -q iptables-restore /etc/rc.local 2>/dev/null || {
        echo -e "#!/bin/sh -e\niptables-restore < /etc/iptables.rules\nexit 0" > /etc/rc.local
        chmod +x /etc/rc.local
      }
    fi
  fi
}

enable_ip_forward() {
  sed -i 's/^#\?net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p >/dev/null
}

# ---------- Certbot / Auto SSL ----------
install_certbot() {
  # Prefer snap on Ubuntu/Debian; fallback to package manager
  if [[ "$PAK" == "apt" ]]; then
    if ! have_cmd snap; then
      apt-get install -y snapd
      systemctl enable --now snapd || true
      ln -sf /var/lib/snapd/snap /snap || true
      sleep 2
    fi
    snap install core || true
    snap refresh core || true
    snap install --classic certbot || true
    ln -sf /snap/bin/certbot /usr/bin/certbot
  else
    # RHEL/CentOS/Alma/Rocky
    if have_cmd dnf; then
      dnf install -y certbot python3-certbot-nginx python3-certbot-apache || true
    else
      yum install -y epel-release || true
      yum install -y certbot python3-certbot-nginx python3-certbot-apache || true
    fi
    # If still no certbot, try snap on RHEL-like
    if ! have_cmd certbot && have_cmd snap; then
      snap install --classic certbot
      ln -sf /snap/bin/certbot /usr/bin/certbot
    fi
    if ! have_cmd certbot; then
      msg "Certbot" "Failed to install Certbot automatically. Install manually and retry."
      return 1
    fi
  fi
}

certbot_issue() {
  install_certbot || return 1

  local mode
  mode=$(ask_menu "Auto SSL" "Choose mode" \
    nginx "For Nginx (auto configure & redirect)" \
    apache "For Apache (auto configure & redirect)" \
    standalone "Temporary standalone server (no webserver)") || return 0

  local domain email agree_redirect
  domain=$(ask_text "Domain" "Enter your domain (DNS must point here):" "")
  [[ -z "$domain" ]] && { msg "Error" "Domain cannot be empty."; return 1; }
  email=$(ask_text "Email" "Enter email for renewal notices (Let's Encrypt):" "")

  case "$mode" in
    nginx)
      have_cmd nginx || { msg "Nginx missing" "Install Nginx first, then retry."; return 1; }
      if ask_yesno "Redirect" "Force HTTP → HTTPS redirection?"; then
        certbot --nginx -d "$domain" -m "$email" --agree-tos --redirect -n || { msg "Certbot" "Failed to obtain certificate."; return 1; }
      else
        certbot --nginx -d "$domain" -m "$email" --agree-tos -n || { msg "Certbot" "Failed to obtain certificate."; return 1; }
      fi
      systemctl reload nginx || true
      ;;
    apache)
      have_cmd apache2 || have_cmd httpd || { msg "Apache missing" "Install Apache first, then retry."; return 1; }
      if ask_yesno "Redirect" "Force HTTP → HTTPS redirection?"; then
        certbot --apache -d "$domain" -m "$email" --agree-tos --redirect -n || { msg "Certbot" "Failed to obtain certificate."; return 1; }
      else
        certbot --apache -d "$domain" -m "$email" --agree-tos -n || { msg "Certbot" "Failed to obtain certificate."; return 1; }
      fi
      systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null || true
      ;;
    standalone)
      # Requires ports 80/443 free
      certbot certonly --standalone -d "$domain" -m "$email" --agree-tos -n || { msg "Certbot" "Failed to obtain certificate. Ensure ports 80/443 are free."; return 1; }
      ;;
  esac

  msg "Success" "Certificate installed for ${domain}.\nAuto-renewal is handled by Certbot timer."
}

# ---------- User Management ----------
add_user_flow() {
  local u ssk sudoer
  u=$(ask_text "Add User" "New username:" "")
  [[ -z "$u" ]] && { msg "Error" "Username cannot be empty."; return; }
  if id "$u" >/dev/null 2>&1; then
    msg "User Exists" "User '$u' already exists."; return
  fi
  useradd -m -s /bin/bash "$u"
  if ask_yesno "Password" "Set a password for '$u'?"; then
    passwd "$u"
  fi
  if ask_yesno "SSH Key" "Add an SSH public key for '$u'?"; then
    ssk=$(ask_text "SSH Key" "Paste the user's SSH public key:" "")
    if [[ -n "$ssk" ]]; then
      install -d -m 700 -o "$u" -g "$u" "/home/$u/.ssh"
      echo "$ssk" >> "/home/$u/.ssh/authorized_keys"
      chown "$u:$u" "/home/$u/.ssh/authorized_keys"
      chmod 600 "/home/$u/.ssh/authorized_keys"
    fi
  fi
  if ask_yesno "Sudo" "Grant sudo to '$u'?"; then
    if [[ "$PAK" == "apt" ]]; then
      usermod -aG sudo "$u"
    else
      usermod -aG wheel "$u"
    fi
  fi
  msg "Done" "User '$u' created."
}

remove_user_flow() {
  local u
  u=$(ask_text "Remove User" "Username to remove:" "")
  [[ -z "$u" ]] && { msg "Error" "Username cannot be empty."; return; }
  id "$u" >/dev/null 2>&1 || { msg "Not Found" "User '$u' does not exist."; return; }
  if ask_yesno "Confirm" "Delete home directory too?"; then
    userdel -r "$u"
  else
    userdel "$u"
  fi
  msg "Done" "User '$u' removed."
}

toggle_sudo_flow() {
  local u has
  u=$(ask_text "Toggle Sudo" "Username:" "")
  [[ -z "$u" ]] && { msg "Error" "Username cannot be empty."; return; }
  id "$u" >/dev/null 2>&1 || { msg "Not Found" "User '$u' does not exist."; return; }
  if [[ "$PAK" == "apt" ]]; then
    if id -nG "$u" | grep -qw sudo; then
      deluser "$u" sudo || gpasswd -d "$u" sudo || true
      has=0
    else
      usermod -aG sudo "$u"; has=1
    fi
  else
    if id -nG "$u" | grep -qw wheel; then
      gpasswd -d "$u" wheel || true; has=0
    else
      usermod -aG wheel "$u"; has=1
    fi
  fi
  msg "Done" "Sudo for '$u' is now $( [[ $has -eq 1 ]] && echo ENABLED || echo DISABLED )."
}

user_management_menu() {
  while true; do
    local choice
    choice=$(ask_menu "User Management" "Choose an action" \
      add "Add user (SSH key, sudo optional)" \
      remove "Remove user" \
      togglesudo "Toggle sudo for user" \
      back "Back") || return
    case "$choice" in
      add) add_user_flow ;;
      remove) remove_user_flow ;;
      togglesudo) toggle_sudo_flow ;;
      back) break ;;
    esac
  done
}

# ---------- Port Forwarding ----------
# Option A: Local port → Local port (REDIRECT)
forward_local_redirect() {
  local from to proto
  proto=$(ask_menu "Protocol" "Choose protocol" tcp "TCP" udp "UDP") || return
  from=$(ask_text "From Port" "Public/listen port on THIS server:" "80")
  to=$(ask_text "To Port" "Destination port on THIS server:" "8080")
  [[ -z "$from" || -z "$to" ]] && { msg "Error" "Ports cannot be empty."; return; }

  if [[ "$proto" == "tcp" ]]; then
    iptables -t nat -A PREROUTING -p tcp --dport "$from" -j REDIRECT --to-ports "$to"
  else
    iptables -t nat -A PREROUTING -p udp --dport "$from" -j REDIRECT --to-ports "$to"
  fi
  persist_iptables
  msg "Success" "Forwarded $proto $from → local:$to"
}

# Option B: Public port → Remote host:port (DNAT)
forward_remote_dnat() {
  local proto from rip rport ifc
  proto=$(ask_menu "Protocol" "Choose protocol" tcp "TCP" udp "UDP") || return
  from=$(ask_text "From Port" "Public/listen port on THIS server:" "80")
  rip=$(ask_text "Remote Host" "Destination private/remote IP:" "10.0.0.2")
  rport=$(ask_text "Remote Port" "Destination port:" "8080")
  [[ -z "$from" || -z "$rip" || -z "$rport" ]] && { msg "Error" "All fields required."; return; }

  enable_ip_forward

  ifc=$(ip route show default | awk '/default/ {print $5; exit}')
  [[ -z "$ifc" ]] && ifc="eth0"

  if [[ "$proto" == "tcp" ]]; then
    iptables -t nat -A PREROUTING -i "$ifc" -p tcp --dport "$from" -j DNAT --to-destination "${rip}:${rport}"
    iptables -A FORWARD -p tcp -d "$rip" --dport "$rport" -j ACCEPT
  else
    iptables -t nat -A PREROUTING -i "$ifc" -p udp --dport "$from" -j DNAT --to-destination "${rip}:${rport}"
    iptables -A FORWARD -p udp -d "$rip" --dport "$rport" -j ACCEPT
  fi
  # Masquerade outbound so replies return correctly
  iptables -t nat -C POSTROUTING -o "$ifc" -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o "$ifc" -j MASQUERADE

  persist_iptables
  msg "Success" "Forwarded $proto $from → ${rip}:${rport} (DNAT + MASQUERADE)."
}

list_nat_rules() {
  local rules
  rules="$(iptables -t nat -S; echo; iptables -S FORWARD 2>/dev/null || true)"
  whiptail --title "iptables rules" --scrolltext --msgbox "$rules" 25 96
}

clear_nat_rules() {
  if ask_yesno "Confirm" "This will FLUSH all NAT rules and FORWARD chain ACCEPT rules added here.\nProceed?"; then
    iptables -t nat -F
    iptables -F FORWARD || true
    persist_iptables
    msg "Cleared" "NAT & FORWARD rules flushed."
  fi
}

port_forwarding_menu() {
  ensure_base_tools
  while true; do
    local choice
    choice=$(ask_menu "Port Forwarding" "Choose an action" \
      localredir "Forward local port → local port (REDIRECT)" \
      dnat "Forward public port → remote host:port (DNAT)" \
      list "View NAT/FORWARD rules" \
      clear "Clear NAT & FORWARD rules" \
      back "Back") || return
    case "$choice" in
      localredir) forward_local_redirect ;;
      dnat) forward_remote_dnat ;;
      list) list_nat_rules ;;
      clear) clear_nat_rules ;;
      back) break ;;
    esac
  done
}

# ---------- Main Menu ----------
main_menu() {
  while true; do
    local choice
    choice=$(ask_menu "VPS Toolkit" "Select a tool" \
      ssl "Auto SSL (Certbot) – Nginx/Apache/Standalone" \
      users "User Management – add/remove/ssh/sudo" \
      port "Port Forwarding – REDIRECT/DNAT + persist" \
      quit "Quit") || exit 0
    case "$choice" in
      ssl) certbot_issue ;;
      users) user_management_menu ;;
      port) port_forwarding_menu ;;
      quit) exit 0 ;;
    esac
  done
}

# ---------- Bootstrap ----------
require_root
detect_os
ensure_whiptail
ensure_base_tools
main_menu

#!/usr/bin/env bash
set -euo pipefail

# Run as normal user. The script uses sudo for system units and systemctl --user
# for per-user GNOME services.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Run this script as your normal user, not as root." >&2
  exit 1
fi

SCRIPT_NAME="$(basename "$0")"
APP_DIR="${HOME}/.local/share/applications"
PRINTER_DESKTOP_SRC="/usr/share/applications/gnome-printers-panel.desktop"
COLOR_DESKTOP_SRC="/usr/share/applications/gnome-color-panel.desktop"
BLUETOOTH_DESKTOP_SRC="/usr/share/applications/gnome-bluetooth-panel.desktop"
PRINTER_DESKTOP_DST="${APP_DIR}/gnome-printers-panel.desktop"
COLOR_DESKTOP_DST="${APP_DIR}/gnome-color-panel.desktop"
BLUETOOTH_DESKTOP_DST="${APP_DIR}/gnome-bluetooth-panel.desktop"

info()  { printf '[INFO] %s
' "$*"; }
ok()    { printf '[OK]   %s
' "$*"; }
skip()  { printf '[SKIP] %s
' "$*"; }
warn()  { printf '[WARN] %s
' "$*" >&2; }

run_root() {
  sudo "$@"
}

run_user() {
  systemctl --user "$@"
}

system_unit_load_state() {
  systemctl show -p LoadState --value "$1" 2>/dev/null || true
}

user_unit_load_state() {
  run_user show -p LoadState --value "$1" 2>/dev/null || true
}

system_unit_exists() {
  local state
  state="$(system_unit_load_state "$1")"
  [[ -n "$state" && "$state" != "not-found" ]]
}

user_unit_exists() {
  local state
  state="$(user_unit_load_state "$1")"
  [[ -n "$state" && "$state" != "not-found" ]]
}

ensure_app_dir() {
  mkdir -p "$APP_DIR"
}

hide_desktop_panel() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    skip "menu source missing: $src"
    return 0
  fi

  ensure_app_dir
  cp -f "$src" "$dst"
  sed -i '/^Hidden=/d' "$dst"
  sed -i '/^NoDisplay=/d' "$dst"
  {
    echo 'Hidden=true'
    echo 'NoDisplay=true'
  } >> "$dst"
  ok "menu hidden: $(basename "$dst")"
}

restore_desktop_panel() {
  local dst="$1"

  if [[ -f "$dst" ]]; then
    rm -f "$dst"
    ok "menu restored: $(basename "$dst")"
  else
    skip "menu override not present: $(basename "$dst")"
  fi
}

mask_disable_system_unit() {
  local unit="$1"

  if system_unit_exists "$unit"; then
    run_root systemctl stop "$unit" >/dev/null 2>&1 || true
    run_root systemctl disable "$unit" >/dev/null 2>&1 || true
    run_root systemctl mask "$unit" >/dev/null 2>&1 || true
    ok "$unit disabled and masked"
  else
    skip "$unit not found"
  fi
}

unmask_enable_start_system_unit() {
  local unit="$1"

  if system_unit_exists "$unit"; then
    run_root systemctl unmask "$unit" >/dev/null 2>&1 || true
    run_root systemctl enable "$unit" >/dev/null 2>&1 || true
    run_root systemctl start "$unit" >/dev/null 2>&1 || true
    ok "$unit restored"
  else
    skip "$unit not found"
  fi
}

unmask_only_system_unit() {
  local unit="$1"

  if system_unit_exists "$unit"; then
    run_root systemctl unmask "$unit" >/dev/null 2>&1 || true
    ok "$unit unmasked"
  else
    skip "$unit not found"
  fi
}

mask_disable_user_unit() {
  local unit="$1"

  if user_unit_exists "$unit"; then
    run_user stop "$unit" >/dev/null 2>&1 || true
    run_user disable "$unit" >/dev/null 2>&1 || true
    run_user mask "$unit" >/dev/null 2>&1 || true
    ok "$unit disabled and masked"
  else
    skip "$unit not found"
  fi
}

unmask_enable_start_user_unit() {
  local unit="$1"

  if user_unit_exists "$unit"; then
    run_user unmask "$unit" >/dev/null 2>&1 || true
    run_user enable "$unit" >/dev/null 2>&1 || true
    run_user start "$unit" >/dev/null 2>&1 || true
    ok "$unit restored"
  else
    skip "$unit not found"
  fi
}

unmask_only_user_unit() {
  local unit="$1"

  if user_unit_exists "$unit"; then
    run_user unmask "$unit" >/dev/null 2>&1 || true
    ok "$unit unmasked"
  else
    skip "$unit not found"
  fi
}

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} help
  ${SCRIPT_NAME} status
  ${SCRIPT_NAME} all
  ${SCRIPT_NAME} restore
  ${SCRIPT_NAME} privacy
  ${SCRIPT_NAME} desktop
  ${SCRIPT_NAME} modem on|off
  ${SCRIPT_NAME} avahi on|off
  ${SCRIPT_NAME} bluetooth on|off
  ${SCRIPT_NAME} whoopsie on|off
  ${SCRIPT_NAME} updates on|off
  ${SCRIPT_NAME} logging on|off
  ${SCRIPT_NAME} printers on|off
  ${SCRIPT_NAME} color on|off
  ${SCRIPT_NAME} indexing on|off
  ${SCRIPT_NAME} toggle <modem|avahi|bluetooth|whoopsie|updates|logging|printers|color|indexing> on|off

Modes:
  all
    Disables:
      - ModemManager.service
      - avahi-daemon.service
      - avahi-daemon.socket
      - bluetooth.service
      - whoopsie.service
      - whoopsie.path
      - apt-daily.timer
      - apt-daily-upgrade.timer
      - apt-daily.service
      - apt-daily-upgrade.service
      - unattended-upgrades.service
      - rsyslog.service
      - cups.socket
      - cups.service
      - legacy-printer-app.service
      - colord.service
      - org.gnome.SettingsDaemon.Color.service
      - tracker-miner-fs-3.service
      - tracker-extract-3.service
      - tracker-miner-fs-3.timer
      - tracker-writeback-3.service
    Also hides the GNOME Printers, Color, and Bluetooth panels.

  privacy
    Disables:
      - ModemManager.service
      - avahi-daemon.service
      - avahi-daemon.socket
      - bluetooth.service
      - whoopsie.service
      - whoopsie.path
    Also hides the GNOME Bluetooth panel.

  desktop
    Disables:
      - cups.socket
      - cups.service
      - legacy-printer-app.service
      - colord.service
      - org.gnome.SettingsDaemon.Color.service
      - tracker-miner-fs-3.service
      - tracker-extract-3.service
      - tracker-miner-fs-3.timer
      - tracker-writeback-3.service
    Also hides the GNOME Printers, Color, and Bluetooth panels, and disables GNOME file indexing/search background services.

  restore
    Re-enables everything managed by this script and removes any local menu overrides.

  status
    Shows the current load/enabled/active state for every managed unit and the menu override files.

Feature commands:
  modem
    Disables or enables:
      - ModemManager.service

  avahi
    Disables or enables:
      - avahi-daemon.service
      - avahi-daemon.socket

  bluetooth
    Disables or enables:
      - bluetooth.service
    Also hides or restores the GNOME Bluetooth panel.
    The Bluetooth quick settings tile usually disappears after shell reload or re-login.

  whoopsie
    Disables or enables:
      - whoopsie.service
      - whoopsie.path

  updates
    Disables or enables:
      - apt-daily.timer
      - apt-daily-upgrade.timer
      - apt-daily.service
      - apt-daily-upgrade.service
      - unattended-upgrades.service

  logging
    Disables or enables:
      - rsyslog.service

  printers
    Disables or enables:
      - cups.socket
      - cups.service
      - legacy-printer-app.service
    Also hides or restores the GNOME Printers panel.

  color
    Disables or enables:
      - colord.service
      - org.gnome.SettingsDaemon.Color.service
    Also hides or restores the GNOME Color panel.

  indexing
    Disables or enables:
      - tracker-miner-fs-3.service
      - tracker-extract-3.service
      - tracker-miner-fs-3.timer
      - tracker-writeback-3.service
    Disables or enables GNOME file indexing/search background services.

Notes:
  - Printers are restored using socket activation, so CUPS starts only when needed.
  - Color management is restored without forcing a manual start of the user service.
  - This script does not touch touchscreen, touchpad, or stylus settings.

Examples:
  ${SCRIPT_NAME} privacy
  ${SCRIPT_NAME} bluetooth off
  ${SCRIPT_NAME} printers off
  ${SCRIPT_NAME} indexing off
  ${SCRIPT_NAME} updates off
  ${SCRIPT_NAME} restore
  ${SCRIPT_NAME} status
EOF
}

# Feature actions

disable_modem() {
  mask_disable_system_unit "ModemManager.service"
}

restore_modem() {
  unmask_enable_start_system_unit "ModemManager.service"
}

disable_avahi() {
  mask_disable_system_unit "avahi-daemon.service"
  mask_disable_system_unit "avahi-daemon.socket"
}

restore_avahi() {
  unmask_enable_start_system_unit "avahi-daemon.socket"
  unmask_enable_start_system_unit "avahi-daemon.service"
}

disable_bluetooth() {
  mask_disable_system_unit "bluetooth.service"
  hide_desktop_panel "$BLUETOOTH_DESKTOP_SRC" "$BLUETOOTH_DESKTOP_DST"
}

restore_bluetooth() {
  unmask_enable_start_system_unit "bluetooth.service"
  restore_desktop_panel "$BLUETOOTH_DESKTOP_DST"
}

disable_whoopsie() {
  mask_disable_system_unit "whoopsie.service"
  mask_disable_system_unit "whoopsie.path"
}

restore_whoopsie() {
  unmask_enable_start_system_unit "whoopsie.path"
  unmask_enable_start_system_unit "whoopsie.service"
}

disable_updates() {
  mask_disable_system_unit "apt-daily.timer"
  mask_disable_system_unit "apt-daily-upgrade.timer"
  mask_disable_system_unit "apt-daily.service"
  mask_disable_system_unit "apt-daily-upgrade.service"
  mask_disable_system_unit "unattended-upgrades.service"
}

restore_updates() {
  unmask_enable_start_system_unit "apt-daily.timer"
  unmask_enable_start_system_unit "apt-daily-upgrade.timer"
  unmask_enable_start_system_unit "apt-daily.service"
  unmask_enable_start_system_unit "apt-daily-upgrade.service"
  unmask_enable_start_system_unit "unattended-upgrades.service"
}

disable_logging() {
  mask_disable_system_unit "rsyslog.service"
}

restore_logging() {
  unmask_enable_start_system_unit "rsyslog.service"
}

disable_printers() {
  mask_disable_system_unit "cups.socket"
  mask_disable_system_unit "cups.service"
  mask_disable_system_unit "legacy-printer-app.service"
  hide_desktop_panel "$PRINTER_DESKTOP_SRC" "$PRINTER_DESKTOP_DST"
}

restore_printers() {
  unmask_only_system_unit "cups.service"
  unmask_enable_start_system_unit "cups.socket"
  unmask_enable_start_system_unit "legacy-printer-app.service"
  restore_desktop_panel "$PRINTER_DESKTOP_DST"
}

disable_color() {
  mask_disable_system_unit "colord.service"
  mask_disable_user_unit "org.gnome.SettingsDaemon.Color.service"
  hide_desktop_panel "$COLOR_DESKTOP_SRC" "$COLOR_DESKTOP_DST"
}

restore_color() {
  unmask_only_system_unit "colord.service"
  unmask_only_user_unit "org.gnome.SettingsDaemon.Color.service"
  restore_desktop_panel "$COLOR_DESKTOP_DST"
}

disable_indexing() {
  mask_disable_user_unit "tracker-miner-fs-3.service"
  mask_disable_user_unit "tracker-extract-3.service"
  mask_disable_user_unit "tracker-miner-fs-3.timer"
  mask_disable_user_unit "tracker-writeback-3.service"
}

restore_indexing() {
  unmask_enable_start_user_unit "tracker-miner-fs-3.service"
  unmask_enable_start_user_unit "tracker-extract-3.service"
  unmask_enable_start_user_unit "tracker-miner-fs-3.timer"
  unmask_enable_start_user_unit "tracker-writeback-3.service"
}

# Group modes

disable_all() {
  info "Applying: all"
  disable_modem
  disable_avahi
  disable_bluetooth
  disable_whoopsie
  disable_updates
  disable_logging
  disable_printers
  disable_color
  disable_indexing
}

restore_all() {
  info "Applying: restore"
  restore_modem
  restore_avahi
  restore_bluetooth
  restore_whoopsie
  restore_updates
  restore_logging
  restore_printers
  restore_color
  restore_indexing
}

disable_privacy() {
  info "Applying: privacy"
  disable_modem
  disable_avahi
  disable_bluetooth
  disable_whoopsie
}

restore_privacy() {
  info "Applying: restore privacy"
  restore_modem
  restore_avahi
  restore_bluetooth
  restore_whoopsie
}

disable_desktop() {
  info "Applying: desktop"
  disable_printers
  disable_color
  disable_bluetooth
  disable_indexing
}

restore_desktop() {
  info "Applying: restore desktop"
  restore_printers
  restore_color
  restore_bluetooth
  restore_indexing
}

print_status_system_unit() {
  local label="$1"
  local unit="$2"
  local load_state enabled_state active_state

  load_state="$(system_unit_load_state "$unit")"
  if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
    printf '[%s] not found
' "$label"
    return
  fi

  enabled_state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  active_state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  printf '[%s] load=%s enabled=%s active=%s
' "$label" "$load_state" "${enabled_state:-unknown}" "${active_state:-unknown}"
}

print_status_user_unit() {
  local label="$1"
  local unit="$2"
  local load_state enabled_state active_state

  load_state="$(user_unit_load_state "$unit")"
  if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
    printf '[%s] not found
' "$label"
    return
  fi

  enabled_state="$(run_user is-enabled "$unit" 2>/dev/null || true)"
  active_state="$(run_user is-active "$unit" 2>/dev/null || true)"
  printf '[%s] load=%s enabled=%s active=%s
' "$label" "$load_state" "${enabled_state:-unknown}" "${active_state:-unknown}"
}

status() {
  echo "System services:"
  print_status_system_unit "ModemManager" "ModemManager.service"
  print_status_system_unit "avahi-daemon" "avahi-daemon.service"
  print_status_system_unit "avahi-daemon.socket" "avahi-daemon.socket"
  print_status_system_unit "bluetooth" "bluetooth.service"
  print_status_system_unit "whoopsie" "whoopsie.service"
  print_status_system_unit "whoopsie.path" "whoopsie.path"
  print_status_system_unit "apt-daily.timer" "apt-daily.timer"
  print_status_system_unit "apt-daily-upgrade.timer" "apt-daily-upgrade.timer"
  print_status_system_unit "apt-daily.service" "apt-daily.service"
  print_status_system_unit "apt-daily-upgrade.service" "apt-daily-upgrade.service"
  print_status_system_unit "unattended-upgrades" "unattended-upgrades.service"
  print_status_system_unit "rsyslog" "rsyslog.service"
  print_status_system_unit "cups.socket" "cups.socket"
  print_status_system_unit "cups.service" "cups.service"
  print_status_system_unit "legacy-printer-app" "legacy-printer-app.service"
  print_status_system_unit "colord" "colord.service"

  echo
  echo "User services:"
  print_status_user_unit "gnome-color" "org.gnome.SettingsDaemon.Color.service"
  print_status_user_unit "tracker-miner-fs-3" "tracker-miner-fs-3.service"
  print_status_user_unit "tracker-extract-3" "tracker-extract-3.service"
  print_status_user_unit "tracker-miner-fs-3.timer" "tracker-miner-fs-3.timer"
  print_status_user_unit "tracker-writeback-3" "tracker-writeback-3.service"

  echo
  echo "Desktop menu overrides:"
  [[ -f "$PRINTER_DESKTOP_DST" ]] && echo "[Printers] hidden override present" || echo "[Printers] default visible"
  [[ -f "$COLOR_DESKTOP_DST" ]] && echo "[Color] hidden override present" || echo "[Color] default visible"
  [[ -f "$BLUETOOTH_DESKTOP_DST" ]] && echo "[Bluetooth] hidden override present" || echo "[Bluetooth] default visible"
}

toggle_one() {
  local name="$1"
  local state="$2"

  case "${name}:${state}" in
    modem:off) disable_modem ;;
    modem:on) restore_modem ;;

    avahi:off) disable_avahi ;;
    avahi:on) restore_avahi ;;

    bluetooth:off) disable_bluetooth ;;
    bluetooth:on) restore_bluetooth ;;

    whoopsie:off) disable_whoopsie ;;
    whoopsie:on) restore_whoopsie ;;

    updates:off) disable_updates ;;
    updates:on) restore_updates ;;

    logging:off) disable_logging ;;
    logging:on) restore_logging ;;

    printers:off) disable_printers ;;
    printers:on) restore_printers ;;

    color:off) disable_color ;;
    color:on) restore_color ;;

    indexing:off) disable_indexing ;;
    indexing:on) restore_indexing ;;

    *)
      warn "Unknown toggle: ${name} ${state}"
      exit 1
      ;;
  esac
}

main() {
  local cmd="${1:-help}"

  case "$cmd" in
    help|-h|--help)
      usage
      ;;

    status)
      status
      ;;

    all)
      disable_all
      ;;

    restore)
      restore_all
      ;;

    privacy)
      disable_privacy
      ;;

    desktop)
      disable_desktop
      ;;

    modem|avahi|bluetooth|whoopsie|updates|logging|printers|color|indexing)
      if [[ $# -lt 2 ]]; then
        warn "Usage: ${SCRIPT_NAME} ${cmd} on|off"
        exit 1
      fi
      toggle_one "$cmd" "$2"
      ;;

    toggle)
      if [[ $# -lt 3 ]]; then
        warn "Usage: ${SCRIPT_NAME} toggle <modem|avahi|bluetooth|whoopsie|updates|logging|printers|color|indexing> on|off"
        exit 1
      fi
      toggle_one "$2" "$3"
      ;;

    *)
      warn "Unknown command: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"

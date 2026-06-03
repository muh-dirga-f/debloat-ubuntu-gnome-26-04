#!/usr/bin/env bash
set -euo pipefail

# Run as normal user. The script uses sudo for system units and systemctl --user
# for per-user GNOME services.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Run this script as your normal user, not as root." >&2
  exit 1
fi

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="2026.06.02"
APP_DIR="${HOME}/.local/share/applications"

PRINTER_DESKTOP_SRC="/usr/share/applications/gnome-printers-panel.desktop"
COLOR_DESKTOP_SRC="/usr/share/applications/gnome-color-panel.desktop"
BLUETOOTH_DESKTOP_SRC="/usr/share/applications/gnome-bluetooth-panel.desktop"

PRINTER_DESKTOP_DST="${APP_DIR}/gnome-printers-panel.desktop"
COLOR_DESKTOP_DST="${APP_DIR}/gnome-color-panel.desktop"
BLUETOOTH_DESKTOP_DST="${APP_DIR}/gnome-bluetooth-panel.desktop"

info()  { printf '[INFO] %s\n' "$*"; }
ok()    { printf '[OK]   %s\n' "$*"; }
skip()  { printf '[SKIP] %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }

USE_COLOR=0
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  USE_COLOR=1
fi

colorize() {
  local code="$1"
  shift
  local text="$*"

  if (( USE_COLOR )); then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

state_color_code() {
  local value="${1,,}"

  case "$value" in
    running|active|enabled|enabled-runtime|linked|linked-runtime|loaded)
      printf '%s' '1;32'
      ;;
    inactive|disabled|masked|masked-runtime|failed|dead|not-found|error|bad)
      printf '%s' '1;31'
      ;;
    static|indirect|generated|transient|alias|unknown)
      printf '%s' '1;33'
      ;;
    activating|deactivating|reloading|listening|plugged)
      printf '%s' '1;34'
      ;;
    *)
      printf '%s' '0;90'
      ;;
  esac
}

status_state() {
  local value="${1:-unknown}"
  local padded color

  color="$(state_color_code "$value")"
  printf -v padded '%-12s' "$value"
  colorize "$color" "$padded"
}

status_not_found() {
  colorize '0;90' 'not found'
}

status_heading() {
  colorize '1;36' "$*"
}


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
  ${SCRIPT_NAME} boot
  ${SCRIPT_NAME} modem on|off
  ${SCRIPT_NAME} avahi on|off
  ${SCRIPT_NAME} bluetooth on|off
  ${SCRIPT_NAME} whoopsie on|off
  ${SCRIPT_NAME} cloud-init on|off
  ${SCRIPT_NAME} boot on|off
  ${SCRIPT_NAME} updates on|off
  ${SCRIPT_NAME} logging on|off
  ${SCRIPT_NAME} printers on|off
  ${SCRIPT_NAME} color on|off
  ${SCRIPT_NAME} indexing on|off
  ${SCRIPT_NAME} toggle <modem|avahi|bluetooth|whoopsie|cloud-init|boot|updates|logging|printers|color|indexing> on|off

Modes:
  all
    Conservative combined mode:
      - ModemManager.service
      - avahi-daemon.service
      - avahi-daemon.socket
      - bluetooth.service
      - whoopsie.service
      - whoopsie.path
      - cloud-init-local.service
      - cloud-init.service
      - cloud-config.service
      - cloud-final.service
      - cloud-init-main.service
      - cloud-init-network.service
      - cloud-init-hotplugd.socket
      - NetworkManager-wait-online.service
      - motd-news.timer
      - update-notifier-download.timer
      - update-notifier-motd.timer
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
      - localsearch-3.service
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
      - localsearch-3.service
      - tracker-miner-fs-3.service
      - tracker-extract-3.service
      - tracker-miner-fs-3.timer
      - tracker-writeback-3.service
    Also hides the GNOME Printers, Color, and Bluetooth panels, and disables GNOME file indexing/search background services.

  boot
    Disables:
      - cloud-init-local.service
      - cloud-init.service
      - cloud-config.service
      - cloud-final.service
      - cloud-init-main.service
      - cloud-init-network.service
      - cloud-init-hotplugd.socket
      - NetworkManager-wait-online.service
      - motd-news.timer
      - update-notifier-download.timer
      - update-notifier-motd.timer
    This is intended for a normal desktop/laptop install, not cloud images.

  restore
    Re-enables everything managed by this script and removes any local menu overrides.

  status
    Shows the current load/enabled/active state for every managed unit and the menu override files.
    Output is colorized automatically in a real terminal.

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

  cloud-init
    Disables or enables:
      - cloud-init-local.service
      - cloud-init.service
      - cloud-config.service
      - cloud-final.service
      - cloud-init-main.service
      - cloud-init-network.service
      - cloud-init-hotplugd.socket

  boot
    Disables or enables:
      - cloud-init-local.service
      - cloud-init.service
      - cloud-config.service
      - cloud-final.service
      - cloud-init-main.service
      - cloud-init-network.service
      - cloud-init-hotplugd.socket
      - NetworkManager-wait-online.service
      - motd-news.timer
      - update-notifier-download.timer
      - update-notifier-motd.timer

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
      - localsearch-3.service
      - tracker-miner-fs-3.service
      - tracker-extract-3.service
      - tracker-miner-fs-3.timer
      - tracker-writeback-3.service
    Disables or enables GNOME file indexing/search background services.
    On Ubuntu 26.04, localsearch-3.service is the main target.

Notes:
  - Printers are restored using socket activation, so CUPS starts only when needed.
  - Color management is restored without forcing a manual start of the user service.
  - Cloud-init is normally unnecessary on a desktop install; this script only disables it when you ask for it.
  - On Ubuntu 26.04, localsearch-3.service may be the active file indexer.
  - The `all` mode also disables update timers and rsyslog, but these remain available as separate toggles.
  - This script does not touch touchscreen, touchpad, or stylus settings.

Examples:
  ${SCRIPT_NAME} boot
  ${SCRIPT_NAME} privacy
  ${SCRIPT_NAME} bluetooth off
  ${SCRIPT_NAME} printers off
  ${SCRIPT_NAME} indexing off
  ${SCRIPT_NAME} updates off
  ${SCRIPT_NAME} restore
  ${SCRIPT_NAME} status
EOF
}

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

disable_cloud_init() {
  mask_disable_system_unit "cloud-init-local.service"
  mask_disable_system_unit "cloud-init.service"
  mask_disable_system_unit "cloud-config.service"
  mask_disable_system_unit "cloud-final.service"
  mask_disable_system_unit "cloud-init-main.service"
  mask_disable_system_unit "cloud-init-network.service"
  mask_disable_system_unit "cloud-init-hotplugd.socket"
}

restore_cloud_init() {
  unmask_enable_start_system_unit "cloud-init-hotplugd.socket"
  unmask_enable_start_system_unit "cloud-init-network.service"
  unmask_enable_start_system_unit "cloud-init-main.service"
  unmask_enable_start_system_unit "cloud-final.service"
  unmask_enable_start_system_unit "cloud-config.service"
  unmask_enable_start_system_unit "cloud-init.service"
  unmask_enable_start_system_unit "cloud-init-local.service"
}

disable_boot() {
  disable_cloud_init
  mask_disable_system_unit "NetworkManager-wait-online.service"
  mask_disable_system_unit "motd-news.timer"
  mask_disable_system_unit "update-notifier-download.timer"
  mask_disable_system_unit "update-notifier-motd.timer"
}

restore_boot() {
  unmask_enable_start_system_unit "NetworkManager-wait-online.service"
  unmask_enable_start_system_unit "motd-news.timer"
  unmask_enable_start_system_unit "update-notifier-download.timer"
  unmask_enable_start_system_unit "update-notifier-motd.timer"
  restore_cloud_init
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
  mask_disable_user_unit "localsearch-3.service"
  mask_disable_user_unit "tracker-miner-fs-3.service"
  mask_disable_user_unit "tracker-extract-3.service"
  mask_disable_user_unit "tracker-miner-fs-3.timer"
  mask_disable_user_unit "tracker-writeback-3.service"
}

restore_indexing() {
  unmask_enable_start_user_unit "localsearch-3.service"
  unmask_enable_start_user_unit "tracker-miner-fs-3.service"
  unmask_enable_start_user_unit "tracker-extract-3.service"
  unmask_enable_start_user_unit "tracker-miner-fs-3.timer"
  unmask_enable_start_user_unit "tracker-writeback-3.service"
}

disable_all() {
  info "Applying: all"
  disable_modem
  disable_avahi
  disable_bluetooth
  disable_whoopsie
  disable_boot
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
  restore_boot
  restore_printers
  restore_color
  restore_indexing
  restore_updates
  restore_logging
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
    printf '  %-30s %s\n' "[$label]" "$(status_not_found)"
    return
  fi

  enabled_state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  active_state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  printf '  %-30s load=%s enabled=%s active=%s\n' \
    "[$label]" \
    "$(status_state "$load_state")" \
    "$(status_state "$enabled_state")" \
    "$(status_state "$active_state")"
}

print_status_user_unit() {
  local label="$1"
  local unit="$2"
  local load_state enabled_state active_state

  load_state="$(user_unit_load_state "$unit")"
  if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
    printf '  %-30s %s\n' "[$label]" "$(status_not_found)"
    return
  fi

  enabled_state="$(run_user is-enabled "$unit" 2>/dev/null || true)"
  active_state="$(run_user is-active "$unit" 2>/dev/null || true)"
  printf '  %-30s load=%s enabled=%s active=%s\n' \
    "[$label]" \
    "$(status_state "$load_state")" \
    "$(status_state "$enabled_state")" \
    "$(status_state "$active_state")"
}

print_status_override() {
  local label="$1"
  local file="$2"

  if [[ -f "$file" ]]; then
    printf '  %-30s %s\n' "[$label]" "$(status_state 'override')"
  else
    printf '  %-30s %s\n' "[$label]" "$(status_state 'default')"
  fi
}

status() {
  printf '%s\n' "$(status_heading "${SCRIPT_NAME} v${SCRIPT_VERSION}")"
  printf '%s\n' "$(status_heading 'System services:')"
  printf '  %s\n' "$(colorize '1;32' 'green=active/enabled/running')"
  printf '  %s\n' "$(colorize '1;31' 'red=inactive/disabled/masked/not-found')"
  printf '  %s\n' "$(colorize '1;33' 'yellow=static/indirect/unknown/override/default')"
  print_status_system_unit "ModemManager" "ModemManager.service"
  print_status_system_unit "avahi-daemon" "avahi-daemon.service"
  print_status_system_unit "avahi-daemon.socket" "avahi-daemon.socket"
  print_status_system_unit "bluetooth" "bluetooth.service"
  print_status_system_unit "whoopsie" "whoopsie.service"
  print_status_system_unit "whoopsie.path" "whoopsie.path"
  print_status_system_unit "cloud-init-local" "cloud-init-local.service"
  print_status_system_unit "cloud-init" "cloud-init.service"
  print_status_system_unit "cloud-config" "cloud-config.service"
  print_status_system_unit "cloud-final" "cloud-final.service"
  print_status_system_unit "cloud-init-main" "cloud-init-main.service"
  print_status_system_unit "cloud-init-network" "cloud-init-network.service"
  print_status_system_unit "cloud-init-hotplugd.socket" "cloud-init-hotplugd.socket"
  print_status_system_unit "NetworkManager-wait-online" "NetworkManager-wait-online.service"
  print_status_system_unit "motd-news.timer" "motd-news.timer"
  print_status_system_unit "update-notifier-download.timer" "update-notifier-download.timer"
  print_status_system_unit "update-notifier-motd.timer" "update-notifier-motd.timer"
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

  printf '\n%s\n' "$(status_heading 'User services:')"
  print_status_user_unit "gnome-color" "org.gnome.SettingsDaemon.Color.service"
  print_status_user_unit "localsearch-3" "localsearch-3.service"
  print_status_user_unit "tracker-miner-fs-3" "tracker-miner-fs-3.service"
  print_status_user_unit "tracker-extract-3" "tracker-extract-3.service"
  print_status_user_unit "tracker-miner-fs-3.timer" "tracker-miner-fs-3.timer"
  print_status_user_unit "tracker-writeback-3" "tracker-writeback-3.service"

  printf '\n%s\n' "$(status_heading 'Desktop menu overrides:')"
  print_status_override "Printers" "$PRINTER_DESKTOP_DST"
  print_status_override "Color" "$COLOR_DESKTOP_DST"
  print_status_override "Bluetooth" "$BLUETOOTH_DESKTOP_DST"
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

    cloud-init:off) disable_cloud_init ;;
    cloud-init:on) restore_cloud_init ;;

    boot:off) disable_boot ;;
    boot:on) restore_boot ;;

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

    boot)
      disable_boot
      ;;

    modem|avahi|bluetooth|whoopsie|cloud-init|boot|updates|logging|printers|color|indexing)
      if [[ $# -lt 2 ]]; then
        warn "Usage: ${SCRIPT_NAME} ${cmd} on|off"
        exit 1
      fi
      toggle_one "$cmd" "$2"
      ;;

    toggle)
      if [[ $# -lt 3 ]]; then
        warn "Usage: ${SCRIPT_NAME} toggle <modem|avahi|bluetooth|whoopsie|cloud-init|boot|updates|logging|printers|color|indexing> on|off"
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

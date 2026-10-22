#!/bin/bash
options="Shutdown\nReboot\nLogout\nSuspend\nHibernate\nLock\nExit"
chosen=$(printf '%b\n' "$options" | noctalia-patched dmenu --prompt "Power Menu")

case $chosen in
  "Shutdown") systemctl poweroff ;;
  "Reboot")   systemctl reboot ;;
  "Logout")   niri msg action quit --skip-confirmation ;;
  "Suspend")  systemctl suspend ;;
  "Hibernate") systemctl hibernate ;;
  "Lock")     swaylock ;;
  "Exit")     exit 0 ;;
  *)          exit 1 ;;
esac
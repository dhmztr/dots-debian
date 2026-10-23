#!/bin/sh
# startx -> bspwm. Without a systemd user session there is no D-Bus session
# bus (tray, notifications, portals need it), so start one here.
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
export PATH="$HOME/.local/bin:$PATH"
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null; then
    exec dbus-run-session bspwm
fi
exec bspwm

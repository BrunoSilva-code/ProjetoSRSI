#!/bin/bash
set -e

mkdir -p /home/kali/.vnc
if [ ! -f /home/kali/.vnc/xstartup ]; then
  cp /opt/xstartup /home/kali/.vnc/xstartup
fi
chown -R kali:kali /home/kali/.vnc

su - kali -c "tigervncserver :1 \
  -localhost yes \
  -SecurityTypes None \
  -geometry 1440x900 \
  -depth 24"

exec websockify --web=/usr/share/novnc \
  6080 localhost:5901

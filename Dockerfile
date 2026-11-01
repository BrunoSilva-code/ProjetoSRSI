FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    dbus-x11 \
    xterm \
    firefox-esr \
    ettercap-graphical \
    wireshark \
    mariadb-client \
    libcap2-bin \
    sudo \
    && apt clean

RUN useradd -m -s /bin/bash kali

RUN printf 'kali ALL=(root) NOPASSWD: /usr/bin/ettercap\n' > /etc/sudoers.d/ettercap-kali \
    && chmod 0440 /etc/sudoers.d/ettercap-kali \
    && visudo -cf /etc/sudoers.d/ettercap-kali

RUN groupadd -f wireshark \
    && usermod -aG wireshark kali \
    && chgrp wireshark /usr/bin/dumpcap \
    && chmod 0750 /usr/bin/dumpcap \
    && setcap cap_net_raw,cap_net_admin+ep /usr/bin/dumpcap

RUN mkdir -p /home/kali/.vnc \
    && chown -R kali:kali /home/kali

COPY xstartup /opt/xstartup
COPY start.sh /start.sh

RUN chmod +x /opt/xstartup /start.sh \
    && chown -R kali:kali /home/kali/.vnc

EXPOSE 6080

CMD ["/start.sh"]

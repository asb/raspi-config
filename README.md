raspi-config
============

Configuration tool for the Raspberry Pi
Ensure sudo is installed.
Write a shell script which updates your package manager's repositories and upgrades all programs installed by it. place it in /var/cache/raspi-config-update
Then type cp ./raspi-config/raspi-config /usr/bin/raspi-config and then sudo chmod +x /usr/bin/raspi-config
To start type sudo raspi-config

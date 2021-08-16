#!/bin/sh
if grep -q okay /proc/device-tree/soc/v3d@7ec00000/status 2> /dev/null || grep -q okay /proc/device-tree/v3dbus/v3d@7ec04000/status 2> /dev/null || grep -q okay /proc/device-tree/soc/firmwarekms@7e600000/status 2> /dev/null ; then
    if ps ax | grep -v grep | grep -q openbox ; then
        exec xcompmgr -a
    fi
fi

#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Enable video for streaming in Firefox
dnf swap -y noopenh264 openh264
dnf install -y gstreamer1-plugin-openh264

# Install fonts since nix fonts are broken af
dnf install -y \
    ansible \
    apcupsd-gui \
    bcc-tools \
    containernetworking-plugins \
    distrobox \
    fira-code-fonts \
    mock \
    nmap \
    openscap-containers \
    podman-docker \
    qemu \
    rpmdevtools \
    rpmlint \
    tailscale \
    virt-manager

# This is needed to allow nix to be installed/used
install -d -m 0755 /nix

# TODO: not sure if best solution
# workaround bootc container lint warnings
# echo 'd /var/lib/tailscale 0600 root root - -' > /usr/lib/tmpfiles.d/tailscale.conf
# echo 'd /var/lib/mock 0775 root mock - -' > /usr/lib/tmpfiles.d/mock.conf
# echo 'd /var/lib/rpm-state 0755 root root - -'  > /usr/lib/tmpfiles.d/filesystem.conf
# echo 'd /var/lib/rpm-state/gconf 0755 root root - -'  > /usr/lib/tmpfiles.d/gconf.conf

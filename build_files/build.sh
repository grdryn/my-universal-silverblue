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
	lego \
	mock \
	nix \
	nmap \
	openscap-containers \
	podman-docker \
	qemu \
        restic \
	rpmdevtools \
	rpmlint \
	tailscale \
	virt-manager

# This is needed to allow nix to be installed/used
# /var is writable at runtime on Silverblue/bootc, while /nix on the root
# filesystem is read-only. Nix rejects symlinks for /nix, so we bind-mount
# /var/nix over /nix at boot via a systemd mount unit, giving Nix a real
# directory backed by persistent storage.
install -d -m 0755 /var/nix
install -d -m 0755 /nix

# Install systemd mount unit to bind-mount /var/nix over /nix at boot
# /usr/lib is replaced on bootc upgrade; /etc is preserved, so we write
# here to ensure the new unit takes effect after upgrade.
cat >/usr/lib/systemd/system/nix.mount <<'EOF'
[Unit]
Description=Bind-mount /var/nix on /nix
PropagatesStopTo=nix-daemon.service
After=systemd-tmpfiles-setup.service
Requires=systemd-tmpfiles-setup.service
ConditionPathIsDirectory=/nix
DefaultDependencies=no

[Mount]
What=/var/nix
Where=/nix
Type=none
DirectoryMode=0755
Options=bind

[Install]
RequiredBy=nix-daemon.service
EOF

# Create Nix store directories at boot via tmpfiles.d
# Paths use /var/nix (persistent /var partition), not /nix directly,
# because tmpfiles runs before the nix.mount bind-mount at boot.
cat >/usr/lib/tmpfiles.d/nix.conf <<'EOF'
d /var/nix 0755 root root -
d /var/nix/store 0755 root root -
d /var/nix/store/.links 0755 root root -
d /var/nix/var 0755 root root -
d /var/nix/var/nix 0755 root root -
d /var/nix/var/nix/db 0755 root root -
d /var/nix/var/nix/daemon-socket 0755 root root -
d /var/nix/var/nix/gcroots 0755 root root -
d /var/nix/var/nix/profiles 0755 root root -
d /var/nix/var/nix/userpool 0755 root root -
EOF

# Enable nix-daemon for multi-user Nix operation
# nix-daemon.service creates its own listening socket at
# /nix/var/nix/daemon-socket/socket, so we don't need nix-daemon.socket.
systemctl enable nix.mount nix-daemon.service

### Podman rootful --userns=auto
# Podman 6 resolves the subuid/subgid pool for the "containers" user via NSS,
# so the helper account must exist. Create it at boot with sysusers: users
# baked into /etc/passwd at build time do not reach already-installed systems
# because of the bootc three-way merge of /etc.
cat >/usr/lib/sysusers.d/containers.conf <<'EOF'
u containers - "Helper user to reserve subuids and subgids for rootful Podman" / /usr/sbin/nologin
EOF

# Subuid/subgid pool used by rootful --userns=auto containers (quadlets with
# UserNS=auto). Keep the range below Fedora's SUB_UID_MIN (524288) so it
# cannot collide with ranges assigned to real users. Existing systems keep
# their locally-merged /etc/subuid, so only fresh installs pick these up.
for f in /etc/subuid /etc/subgid; do
	grep -q '^containers:' "$f" || printf 'containers:100000:400000\n' >>"$f"
done

# TODO: not sure if best solution
# workaround bootc container lint warnings
# echo 'd /var/lib/tailscale 0600 root root - -' > /usr/lib/tmpfiles.d/tailscale.conf
# echo 'd /var/lib/mock 0775 root mock - -' > /usr/lib/tmpfiles.d/mock.conf
# echo 'd /var/lib/rpm-state 0755 root root - -'  > /usr/lib/tmpfiles.d/filesystem.conf
# echo 'd /var/lib/rpm-state/gconf 0755 root root - -'  > /usr/lib/tmpfiles.d/gconf.conf

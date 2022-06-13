#!/usr/bin/env bash

# Made by Fernando "maroto"
# Run anything in the filesystem right before being "mksquashed"
# ISO-NEXT specific cleanup removals and additions (08-2021 + 10-2021) @killajoe and @manuel
# refining and changes november 2021 @killajoe and @manuel

script_path=$(readlink -f "${0%/*}")
work_dir="work"

# Adapted from AIS. An excellent bit of code!
# all pathes must be in quotation marks "path/to/file/or/folder" for now.

arch_chroot() {
    arch-chroot "${script_path}/${work_dir}/x86_64/airootfs" /bin/bash -c "${1}"
}

do_merge() {

arch_chroot "$(cat << EOF

echo "##############################"
echo "# start chrooted commandlist #"
echo "##############################"

cd "/root"

# Init & Populate keys
pacman-key --init
pacman-key --populate archlinux endeavouros

# Prepare livesession settings and user
sed -i 's/#\(en_US\.UTF-8\)/\1/' "/etc/locale.gen"
locale-gen
ln -sf "/usr/share/zoneinfo/UTC" "/etc/localtime"

# Set root permission and shell
usermod -s /usr/bin/bash root

# Create liveuser
useradd -m -p "" -g 'liveuser' -G 'sys,rfkill,wheel,uucp,nopasswdlogin,adm,tty' -s /bin/bash liveuser

# Root qt style for Calamares
mkdir "/root/.config"
cp -Rf "/home/liveuser/.config/"{"Kvantum","qt5ct"} "/root/.config/"

# Add builddate to motd:
cat "/usr/lib/endeavouros-release" >> "/etc/motd"
echo "------------------" >> "/etc/motd"

# Enable systemd services
systemctl enable NetworkManager.service systemd-timesyncd.service bluetooth.service firewalld.service
systemctl enable vboxservice.service vmtoolsd.service vmware-vmblock-fuse.service
systemctl set-default multi-user.target

# Revert from arch-iso preset to default preset
cp -rf "/usr/share/mkinitcpio/hook.preset" "/etc/mkinitcpio.d/linux-zen.preset"
sed -i 's?%PKGBASE%?linux?' "/etc/mkinitcpio.d/linux-zen.preset"

# Patching EndeavourOS specific grub config
patch -u "/etc/default/grub" -i "/root/grub.patch"
rm "/root/grub.patch"

# Patching mkinitcpio.conf
patch -u "mkinitcpio.conf" -i "/root/mkinitcpio.patch"
cp "mkinitcpio.conf" "/etc/"
rm "mkinitcpio.conf" "/root/mkinitcpio.patch"

# Remove unneeded grub stuff from /boot
rm -R "/boot/syslinux"
rm -R "/boot/memtest86+"
rm "/boot/amd-ucode.img"
rm "/boot/initramfs-linux-zen.img"
rm "/boot/intel-ucode.img"
rm "/boot/vmlinuz-linux-zen"

# Install locally builded packages on ISO (place packages under airootfs/root/packages)
pacman -U --noconfirm -- "/root/packages/"*".pkg.tar.zst"
rm -rf "/root/packages/"

# Autologin i3
echo "#!/bin/sh
[ -f ~/.xprofile ] && . ~/.xprofile && dbus-launch i3" >> "/home/liveuser/.xinitrc"

echo "#!/bin/sh
xset s off -dpms &" >> "/home/liveuser/.xprofile"

chmod +x /home/liveuser/.xprofile /home/liveuser/.xinitrc

# Fix LightDM
pacman -Sy --noconfirm lightdm lightdm-webkit2-greeter lightdm-webkit-theme-litarvan
systemctl enable lightdm.service

sudo rm -rf /etc/lightdm/lightdm.conf
sudo curl -L https://raw.githubusercontent.com/Gorkido/GorOS-Installation-Configs-Testing/main/lightdm/lightdm.conf >> /etc/lightdm/lightdm.conf

# LightDM Theme
sudo sed -i 's/^#greeter-session=.*$/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf
sudo sed -i 's/^webkit_theme        = .*$/webkit_theme        = litarvan/' /etc/lightdm/lightdm-webkit2-greeter.conf

# TEMPORARY CUSTOM FIXES

# Fix for getting bash configs installed
cp -af "/home/liveuser/"{".bashrc",".bash_profile"} "/etc/skel/"

# Move blacklisting nouveau out of ISO (copy back to target for offline installs)
mv "/usr/lib/modprobe.d/nvidia-utils.conf" "/etc/calamares/files/nv-modprobe"
mv "/usr/lib/modules-load.d/nvidia-utils.conf" "/etc/calamares/files/nv-modules-load"

# Clean pacman log
rm "/var/log/pacman.log"

sudo pacman -Sc --noconfirm
sudo pacman -Scc --noconfirm
yay -Sc --noconfirm
yay -Scc --noconfirm

echo "############################"
echo "# end chrooted commandlist #"
echo "############################"

EOF
)"
}

#################################
########## STARTS HERE ##########
#################################

do_merge

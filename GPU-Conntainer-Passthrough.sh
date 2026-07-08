DRIVER=NVIDIA-Linux-x86_64-595.84.run
DRIVER_DOWNLOAD=https://download.nvidia.com/XFree86/Linux-x86_64/595.84/$DRIVER
CTID=$1
MAJOR_DEVICE_TYPE_GPU=$(stat -c '%Hr' /dev/nvidia0)
MAJOR_DEVICE_TYPE_UVM=$(stat -c '%Hr' /dev/nvidia-uvm)
echo -e "\e[0;96mDriver $DRIVER\e[0m"
echo -e "\e[0;96mChecking container for gpu\e[0m"
if grep -Fq "/dev/nvidia0" /etc/pve/lxc/$CTID.conf
then
    # code if found
    echo -e "\e[0;96mgpu already passed to container\e[0m"
else
    # code if not found
    echo -e "\e[0;96mshutting down container\e[0m"
    pct shutdown $CTID
    echo -e "\e[0;96mpassing gpu to container\e[0m"
    echo "lxc.cgroup2.devices.allow: c ${MAJOR_DEVICE_TYPE_GPU}:* rwm" >> /etc/pve/lxc/$CTID.conf
    echo "lxc.cgroup2.devices.allow: c ${MAJOR_DEVICE_TYPE_UVM}:* rwm" >> /etc/pve/lxc/$CTID.conf
    echo "lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file" >> /etc/pve/lxc/$CTID.conf
    echo "lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file" >> /etc/pve/lxc/$CTID.conf
    echo "lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file" >> /etc/pve/lxc/$CTID.conf
    echo "lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file" >> /etc/pve/lxc/$CTID.conf
    echo -e "\e[0;96mstarting container again\e[0m"
    pct start $CTID
fi
echo -e "\e[0;96mCopying driver to container\e[0m"
pct exec $CTID -- bash -c "mkdir /opt/nvidia"
pct push $CTID /opt/nvidia/$DRIVER /opt/nvidia/$DRIVER
echo -e "\e[0;96mInstalling driver in container\e[0m"
pct exec $CTID -- bash -c "chmod +x /opt/nvidia/$DRIVER && \
/opt/nvidia/$DRIVER --no-kernel-module --no-questions --ui=none"
echo -e "\e[0;96mDone! run nvidia-smi inside the container to test\e[0m"

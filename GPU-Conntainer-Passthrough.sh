source <(wget -qO- https://bash-tui-toolkit.timo-reymann.de/latest/bundle.bash)

DRIVER=NVIDIA-Linux-x86_64-595.84.run
DRIVER_DOWNLOAD=https://download.nvidia.com/XFree86/Linux-x86_64/595.84/$DRIVER
MAJOR_DEVICE_TYPE_GPU=$(stat -c '%Hr' /dev/nvidia0)
MAJOR_DEVICE_TYPE_UVM=$(stat -c '%Hr' /dev/nvidia-uvm)
TUI=1
IDs=$(pct list | sed '1d'| tr -s ' ' | cut -d " " -f 1)


display_help() {
    # taken from https://stackoverflow.com/users/4307337/vincent-stans
    echo "Usage: $0 [-id ctid]" >&2
    echo
    echo "   -h, --help                 Show this message"
    echo "   -id                        Container ID to passthrough to"
    echo "   -s, --shell                Disable the TUI. Use this when offline"
    echo
    # echo some stuff here for the -a or --add-options 
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) display_help; shift ;;
        -id) CTIDs=($2); shift ;;
        -s|--shell) TUI=0; shift;;
        # ... (same format for other required arguments)
        *) echo "Unknown parameter passed: $1" ;;
    esac
    shift
done

#### TUI select options ####

if [ $TUI == 1 ] ; then
  IFS=$'\n' read -r -d '' -a LIST_IDS <<< $IDs
  IFS=$'\n' read -r -d '' -a LIST_NAMES <<< $(pct list | sed '1d'| tr -s ' ' | cut -d " " -f 1,3)

  IFS=$' ' read -r -d '' -a checked <<< $(checkbox "Select one or more items" "${LIST_NAMES[@]}")

  for i in ${checked[@]}
  do
    echo "Selected: ${LIST_IDS[$i]}"
    CTIDs+=(${LIST_IDS[$i]})
  done

fi

for CTID in ${CTIDs[@]}
do

  if [ $(echo $IDs | grep -c $CTID) -gt 0 ]
  then
    echo "Container: ${CTID}"
  else
    echo "invalid container $CTID"
    exit
  fi

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
done

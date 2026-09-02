source <(wget -qO- https://bash-tui-toolkit.timo-reymann.de/latest/bundle.bash)

DRIVER=NVIDIA-Linux-x86_64-595.80.run
DRIVER_DOWNLOAD=https://download.nvidia.com/XFree86/Linux-x86_64/595.84/$DRIVER
MAJOR_DEVICE_TYPE_GPU=$(stat -c '%Hr' /dev/nvidia0)
MAJOR_DEVICE_TYPE_UVM=$(stat -c '%Hr' /dev/nvidia-uvm)
TUI=1
remove=0
IDs=$(pct list | sed '1d'| tr -s ' ' | cut -d " " -f 1)


display_help() {
    # taken from https://stackoverflow.com/users/4307337/vincent-stans
    echo "Usage: $0 [-id ctid]" >&2
    echo
    echo "   -h, --help                 Show this message"
    echo "   -id <ctid>                 Container ID to passthrough to"
    echo "   -s, --shell                Disable the TUI. Use this when offline"
    echo "   --patch-nvenc              Download and apply patches for nvenc from https://github.com/keylase/nvidia-patch"
    echo "   --patch-nvfbc              Download and apply patches for nvfbc from https://github.com/keylase/nvidia-patch"
    echo "   --patch-nvenc-nvfbc        Patch both nvenc and nvfbc"
    echo "   -r, --remove, --uninstall  Uninstall the Driver"
    echo
    # echo some stuff here for the -a or --add-options 
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) display_help; shift ;;
        -id) CTIDs=$2; shift 2;;
        -s|--shell) TUI=0; shift;;
        --patch-nvenc) selected_patches=1; shift;;
        --patch-nvfbc) selected_patches=2; shift;;
        --patch-nvenc-nvfbc) selected_patches=3; shift;;
        -r|--remove|--uninstall) remove=1;shift;;

        # ... (same format for other required arguments)
        *) echo "Unknown parameter passed: $1" ;;
    esac
    shift
done

#### TUI select options ####

if [ $TUI == 1 ] ; then
  IFS=$'\n' read -r -d '' -a LIST_IDS <<< $IDs
  IFS=$'\n' read -r -d '' -a LIST_NAMES <<< $(pct list | sed '1d'| tr -s ' ' | cut -d " " -f 1,3)
  patches=("None" "NVENC patch" "NVFBC patch" "Both")

  # Show currenty installed driver version for each container
  for i in ${LIST_NAMES[@]}
  do
    tmp_id="$(echo "$i" | cut -d " " -f 1)"
    driver_version=$(grep "GPU Passed through <br>Current Driver Version" /etc/pve/lxc/${tmp_id}.conf | cut -d " " -f 7)
    if [[ ${#driver_version} -gt 0 ]]
    then
    $i+="($driver_version)"
    fi
  done


    IFS=$' ' read -r -d '' -a checked <<< $(checkbox "Select one or more items" "${LIST_NAMES[@]}")


  for i in ${checked[@]}
  do
    echo "Selected: ${LIST_IDS[$i]}"
    CTIDs+=(${LIST_IDS[$i]})
  done

  if [[ $remove != 1 ]]
  then
  selected_patches=$(list "Install patches from https://github.com/keylase/nvidia-patch?" "${patches[@]}")
  fi
fi


#### Container ####

for CTID in ${CTIDs[@]}
do

  if [ $(echo $IDs | grep -c $CTID) -gt 0 ]
  then
    if [[ $remove == 1 ]]
    then
      echo "Uninstalling from Container: ${CTID}"
    else
      echo "Installing in Container: ${CTID}"
    fi
  else
    echo "invalid container $CTID"
    exit
  fi

  #### Uninstallation ###
  if [[ $remove == 1 ]]
  then
    echo -e "\e[0;96mUninstalling the driver\e[0m"
    pct start $CTID
    pct exec $CTID -- bash -c "nvidia-uninstall --no-questions --ui=none"
    echo -e "\e[0;96mRemoving Driver files\e[0m"
    pct exec $CTID -- bash -c "rm -r /opt/nvidia"
    echo -e "\e[0;96mRemoving configuration\e[0m"
    pct shutdown $CTID
    sed -i "/#GPU Passed through/d" "/etc/pve/lxc/$CTID.conf"
    sed -i "/rwm #GPU/d" "/etc/pve/lxc/$CTID.conf"
    sed -i "\|lxc.mount.entry: /dev/nvidia0|d" "/etc/pve/lxc/$CTID.conf"
    sed -i "\|lxc.mount.entry: /dev/nvidiact|d" "/etc/pve/lxc/$CTID.conf"
    sed -i "\|lxc.mount.entry: /dev/nvidia-uvm|d" "/etc/pve/lxc/$CTID.conf"
    sed -i "\|lxc.mount.entry: /dev/nvidia-uvm-tools|d" "/etc/pve/lxc/$CTID.conf"
    pct start $CTID
    echo -e "\e[0;96mDone\e[0m"
  else
  #### Installation ####
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
      echo "#GPU Passed through <br>Current Driver Version ${DRIVER}" >> /etc/pve/lxc/$CTID.conf
      echo "lxc.cgroup2.devices.allow: c ${MAJOR_DEVICE_TYPE_GPU}:* rwm #GPU" >> /etc/pve/lxc/$CTID.conf
      echo "lxc.cgroup2.devices.allow: c ${MAJOR_DEVICE_TYPE_UVM}:* rwm #GPU" >> /etc/pve/lxc/$CTID.conf
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
  #### Container Patches ####
  if [[ $selected_patches -gt 0 ]]
    then
    echo -e "\e[0;96mDownloading Patches\e[0m"
    pct exec $CTID -- bash -c "git clone https://github.com/keylase/nvidia-patch /opt/nvidia/nvidia-patch"
    if [[ $selected_patches == 1 ]] # NVENC patch
    then
      pct exec $CTID -- bash -c "bash /opt/nvidia/nvidia-patch/patch.sh"
    elif [[ $selected_patches == 2 ]] # NVFBC patch
    then
      pct exec $CTID -- bash -c "bash /opt/nvidia/nvidia-patch/patch-fbc.sh"
    else # Both
      pct exec $CTID -- bash -c "bash /opt/nvidia/nvidia-patch/patch.sh"
      pct exec $CTID -- bash -c "bash /opt/nvidia/nvidia-patch/patch-fbc.sh"
    fi
  fi
  echo -e "\e[0;96mRebooting the container\e[0m"
  pct reboot $CTID
  echo -e "\e[0;96mDone! run nvidia-smi inside the container to test\e[0m"
  fi #installation or uninstallation
done

#### Host Patches ####
if [[ $selected_patches -gt 0 ]]
  then
  echo -e "\e[0;96mDownloading Patches\e[0m"
  git clone https://github.com/keylase/nvidia-patch /opt/nvidia/nvidia-patch
  if [[ $selected_patches == 1 ]] # NVENC patch
  then
    bash /opt/nvidia/nvidia-patch/patch.sh
  elif [[ $selected_patches == 2 ]] # NVFBC patch
  then
    bash /opt/nvidia/nvidia-patch/patch-fbc.sh
  else # Both
    bash /opt/nvidia/nvidia-patch/patch.sh
    bash /opt/nvidia/nvidia-patch/patch-fbc.sh
  fi

fi

# Proxmox GPU-Conntainer-Passthrough script
This is a script to pass through a nvidia gpu to proxmox containers and install the nvidia driver
### usage
- download the official nvidia driver .run file
- move the driver file to /opt/nvidia (example: `/opt/nvidia/NVIDIA-Linux-x86_64-595.80.run`
)
- install the driver on the proxmox host
- edit "DRIVER" to the name of the driver file (example: `DRIVER=NVIDIA-Linux-x86_64-595.80.run`)

UI
```
bash ./GPU-Conntainer-Passthrough.sh
```
UI Uninstallation
```
bash ./GPU-Conntainer-Passthrough.sh -r
```
Automated (Currently broken)
```
bash ./GPU-Conntainer-Passthrough.sh -s -id <container id>
```

## Credits
Based on https://github.com/Mxlted/Proxmox-Nvidia-Drivers

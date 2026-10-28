
cat > /tmp/ubuntu-audit.sh <<'AUDIT'
#!/usr/bin/env bash

export LC_ALL=C
REPORT="/tmp/ubuntu-audit-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$REPORT") 2>&1

section() {
    printf '\n\n'
    printf '=%.0s' {1..90}
    printf '\n## %s\n' "$1"
    printf '=%.0s' {1..90}
    printf '\n'
}

run() {
    printf '\n$'
    printf ' %q' "$@"
    printf '\n'
    "$@" 2>&1 || true
}

section "1. OS AND KERNEL"
run cat /etc/os-release
run uname -a
run hostnamectl
run uptime
run whoami
run id
run timedatectl

section "2. FILESYSTEMS AND MOUNTS"
run df -hT
run df -ih
run findmnt
run lsblk -o NAME,SIZE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS
run cat /etc/fstab

section "3. TOP-LEVEL DISK USAGE"
run sudo du -xhd1 / 2>/dev/null
run sudo du -xhd1 /home 2>/dev/null
run du -xhd1 "$HOME" 2>/dev/null
run sudo du -xhd1 /var 2>/dev/null
run sudo du -xhd1 /usr 2>/dev/null
run sudo du -xhd1 /opt 2>/dev/null
run sudo du -xhd1 /tmp 2>/dev/null

section "4. LARGE FILES (FILESYSTEM /)"
run sudo find / -xdev -type f -size +500M \
    -printf '%s bytes | %TY-%Tm-%Td | %p\n' 2>/dev/null

section "5. HOME LARGE FILES"
run find "$HOME" -xdev -type f -size +200M \
    -printf '%s bytes | %TY-%Tm-%Td | %p\n' 2>/dev/null

section "6. APT CACHE AND PACKAGE STATE"
run apt list --installed
run apt-mark showmanual
run apt-mark showauto
run apt-get -s autoremove --purge
run apt-get -s clean
run du -sh /var/cache/apt/archives /var/lib/apt/lists 2>/dev/null
run dpkg --audit
run sudo apt-get check
run grep -hE '^(Start-Date|Commandline|Install:|Upgrade:|Remove:|End-Date)' \
    /var/log/apt/history.log 2>/dev/null
run zgrep -hE '^(Start-Date|Commandline|Install:|Upgrade:|Remove:|End-Date)' \
    /var/log/apt/history.log.*.gz 2>/dev/null

section "7. SYSTEM LOGS AND JOURNAL"
run journalctl --disk-usage
run journalctl --list-boots
run sudo du -sh /var/log
run sudo du -ah /var/log 2>/dev/null
run sudo logrotate --debug /etc/logrotate.conf
run systemctl --failed --no-pager

section "8. MEMORY AND SWAP"
run free -h
run swapon --show
run cat /proc/meminfo
run vmstat 1 3
run ps aux --sort=-%mem

section "9. RUNNING PROCESSES AND CPU"
run ps aux --sort=-%cpu
run top -b -n 1
run lscpu
run nproc

section "10. PYTHON EXECUTABLES AND VERSIONS"
run bash -lc 'type -a python python3 pip pip3 uv conda jupyter 2>/dev/null'
run bash -lc 'command -v python python3 pip pip3 uv conda jupyter'
run python3 --version
run python3 -m pip --version
run python3 -m pip list
run python3 -m pip cache dir
run python3 -m pip cache info
run python3 -m pip check
run uv --version
run uv python list
run conda info --envs
run conda list
run ls -lah /usr/bin/python*
run ls -lah /usr/local/bin/python*
run ls -lah "$HOME/.local/bin"

section "11. PYTHON ENVIRONMENT DIRECTORIES"
run du -sh "$HOME"/venv "$HOME"/jupyter-env "$HOME"/miniconda \
    "$HOME"/.venv "$HOME"/.virtualenvs "$HOME"/.cache/uv \
    "$HOME"/.cache/pip "$HOME"/.local/share/virtualenvs 2>/dev/null
run find "$HOME" -maxdepth 5 \
    \( -type d -name .venv -o -type d -name venv \
       -o -type d -name envs -o -type d -name site-packages \) \
    -prune -print 2>/dev/null

section "12. JUPYTER AND KERNELS"
run jupyter --version
run jupyter kernelspec list
run jupyter --paths
run jupyter server list
run python3 -m pip show jupyterlab notebook ipykernel jupyter-core
run pipx list
run du -sh "$HOME"/.local/share/jupyter "$HOME"/.jupyter \
    "$HOME"/.cache/jupyter "$HOME"/.ipython 2>/dev/null
run find "$HOME/.local/share/jupyter/kernels" -maxdepth 3 \
    -type f -name kernel.json -print 2>/dev/null
run find "$HOME/.local/share/jupyter/kernels" -maxdepth 3 \
    -type f -name kernel.json -exec sh -c \
    'echo "--- $1"; cat "$1"' _ {} \; 2>/dev/null

section "13. USER CACHE AND TRASH"
run du -xhd2 "$HOME/.cache" 2>/dev/null
run du -sh "$HOME/.local/share/Trash" 2>/dev/null
run du -xhd2 "$HOME/.local/share" 2>/dev/null
run du -xhd2 "$HOME/.config" 2>/dev/null
run du -xhd2 "$HOME/.npm" 2>/dev/null
run du -xhd2 "$HOME/.cargo" 2>/dev/null
run du -xhd2 "$HOME/.rustup" 2>/dev/null
run du -xhd2 "$HOME/.gradle" 2>/dev/null
run du -xhd2 "$HOME/.m2" 2>/dev/null
run du -xhd2 "$HOME/.conda" 2>/dev/null
run du -xhd2 "$HOME/.nv" 2>/dev/null

section "14. PROJECTS AND REPOSITORIES"
run du -xhd2 "$HOME/repos" 2>/dev/null
run find "$HOME/repos" -maxdepth 4 \
    \( -name .git -o -name .venv -o -name node_modules \
       -o -name __pycache__ -o -name .pytest_cache \
       -o -name .mypy_cache -o -name .ruff_cache \
       -o -name dist -o -name build \) -prune -print 2>/dev/null
run git --version
run git lfs version
run find "$HOME/repos" -type f -path '*/.git/objects/pack/*.pack' \
    -printf '%s bytes | %p\n' 2>/dev/null
run find "$HOME/repos" -type f -name '*.parquet' \
    -printf '%s bytes | %p\n' 2>/dev/null

section "15. NODE, NPM AND FRONTEND TOOLING"
run node --version
run npm --version
run npm cache verify
run npm config get cache
run corepack --version
run pnpm --version
run yarn --version
run du -sh "$HOME"/.npm "$HOME"/.cache/node "$HOME"/.cache/pnpm 2>/dev/null
run find "$HOME/repos" -maxdepth 5 -type d -name node_modules \
    -prune -exec du -sh {} + 2>/dev/null

section "16. DOCKER AND CONTAINERS"
run docker --version
run docker system df -v
run docker ps -a --size
run docker images
run docker volume ls
run docker network ls
run podman --version
run podman system df
run du -sh /var/lib/docker /var/lib/containers 2>/dev/null

section "17. GPU AND GRAPHICS"
run lspci
run lspci -nnk
run nvidia-smi
run nvidia-smi -q
run ubuntu-drivers devices
run lsmod
run glxinfo -B
run vulkaninfo --summary
run du -sh /var/cache/apt/archives 2>/dev/null

section "18. INSTALLED SNAP, FLATPAK AND APPIMAGES"
run snap list --all
run snap saved
run flatpak list --app --runtime
run flatpak --user list --app --runtime
run du -sh /var/lib/snapd/snaps "$HOME/.var/app" \
    /var/lib/flatpak "$HOME/.local/share/flatpak" 2>/dev/null
run find "$HOME" -maxdepth 4 -type f -iname '*.AppImage' \
    -printf '%s bytes | %p\n' 2>/dev/null

section "19. STARTUP SERVICES AND TIMERS"
run systemctl list-unit-files --state=enabled --no-pager
run systemctl list-timers --all --no-pager
run systemctl --user list-unit-files --state=enabled --no-pager
run systemctl --user --failed --no-pager
run systemd-analyze time
run systemd-analyze blame
run systemd-analyze critical-chain

section "20. NETWORK AND LISTENING PORTS"
run ip -brief address
run ip route
run ss -tulpn
run resolvectl status

section "21. KERNELS AND BOOT"
run dpkg -l 'linux-image*' 'linux-modules*' 'linux-headers*'
run ls -lh /boot
run du -sh /boot
run grub-editenv list
run cat /etc/default/grub

section "22. SECURITY AND SYSTEM HEALTH"
run sudo ufw status verbose
run sudo aa-status
run sudo smartctl --scan
run sudo systemctl status unattended-upgrades --no-pager
run sudo journalctl -p err -b --no-pager
run dmesg --level=err,warn

section "23. RECENTLY CHANGED LARGE FILES"
run find "$HOME" -xdev -type f -size +100M -mtime -30 \
    -printf '%s bytes | %TY-%Tm-%Td | %p\n' 2>/dev/null

section "24. END OF REPORT"
printf '\nReport saved to: %s\n' "$REPORT"
printf 'Report size: '
du -h "$REPORT" 2>/dev/null
AUDIT

bash /tmp/ubuntu-audit.sh

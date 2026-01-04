# Low-Power NAS with Alpine Linux (For Jellyfin)

A complete guide to building an energy-efficient NAS for Jellyfin using Alpine Linux with automatic suspend/wake functionality.

## Overview

This guide shows you how to repurpose old hardware into a low-power NAS that:
- Runs Alpine Linux (minimal RAM usage)
- Shares media via NFSv4 to your Jellyfin server
- Automatically suspends when idle to save power
- Wakes up instantly when Jellyfin needs access
- Supports JBOD storage with mergerfs

Perfect for reducing electricity costs while keeping your media accessible 24/7.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Wake-on-LAN Configuration](#wake-on-lan-configuration)
3. [Storage: Mergerfs JBOD (Optional)](#storage-mergerfs-jbod-optional)
4. [NFS Server Setup](#nfs-server-setup)
5. [Jellyfin Client Configuration](#jellyfin-client-configuration)
6. [Automatic Suspend on Idle](#automatic-suspend-on-idle)
7. [Automatic Wake on Access](#automatic-wake-on-access)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)

---

## Initial Setup

### Installing Alpine Linux

Download Alpine Linux Standard from [alpinelinux.org](https://alpinelinux.org/downloads/).

**Manual installation:**
1. Boot from USB/CD
2. Login as `root` (no password)
3. Run `setup-alpine`
4. Follow prompts for keyboard, network, timezone, disk

**Automated installation (advanced):**
Use [alpine-answers](https://github.com/bifferos/alpine-answers) to create unattended installation media.

### Post-Install: Enable Edge/Testing Repository

For mergerfs and newer packages, enable the testing repository:

```bash
# Edit repositories file
vi /etc/apk/repositories
```

Add this line:
```
http://dl-cdn.alpinelinux.org/alpine/edge/testing
```

Your final `/etc/apk/repositories` should look like:
```
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
```

Update package index:
```bash
apk update
```

---

## Wake-on-LAN Configuration

Enable your NAS to wake from suspend via network magic packets.

### Install ethtool

```bash
apk add ethtool
```

### Configure Network Interface

Edit `/etc/network/interfaces`:

```bash
vi /etc/network/interfaces
```

Add the `post-up` command:

```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    post-up /usr/sbin/ethtool -s eth0 wol g
```

**Note:** Consider using a static IP or DHCP reservation for reliability.

### Verify WOL is Enabled

Reboot and check:

```bash
reboot

# After reboot:
ethtool eth0 | grep Wake-on
```

Expected output:
```
Supports Wake-on: pumbg
Wake-on: g
```

The `g` indicates wake-on-magic-packet is enabled.

---

## Storage: Mergerfs JBOD (Optional)

Skip this section if you're using a single drive or hardware RAID.

### Why Mergerfs?

Mergerfs pools multiple drives into a single mount point (JBOD - Just a Bunch Of Disks) without RAID overhead, perfect for media storage where redundancy isn't critical.

### Enable FUSE Kernel Module

```bash
# Load module now
modprobe fuse

# Make permanent
echo "fuse" >> /etc/modules

# Verify
lsmod | grep fuse
```

### Install Mergerfs

```bash
apk add mergerfs
```

**Important:** You don't need to install the `fuse` package. Mergerfs includes its own mount helper.

### Configure fstab

Install util-linux to get the blkid command:
```bash
apk add util-linux
```

Get your disk UUIDs:
```bash
blkid
```

Edit `/etc/fstab`:

```bash
vi /etc/fstab
```

Add your individual disks and mergerfs pool:

```
# Individual disk mounts
/dev/disk/by-uuid/YOUR-UUID-1 /mnt/disk1 auto nosuid,nodev,nofail 0 0
/dev/disk/by-uuid/YOUR-UUID-2 /mnt/disk2 auto nosuid,nodev,nofail 0 0
/dev/disk/by-uuid/YOUR-UUID-3 /mnt/disk3 auto nosuid,nodev,nofail 0 0

# Mergerfs pool
/mnt/disk* /mnt/storage mergerfs defaults,nonempty,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs,dropcacheonclose=true,minfreespace=250G,fsname=mergerfs 0 0
```

Mount everything:
```bash
mount -a
```

### Verify Mergerfs

```bash
df -h /mnt/storage
ps ax | grep mergerfs
```

---

## NFS Server Setup

### Load NFS Kernel Module

```bash
# Load now
modprobe nfsd

# Make permanent
echo "nfsd" >> /etc/modules

# Verify
lsmod | grep nfsd
```

### Install NFS Utilities

```bash
apk add nfs-utils
```

### Configure Exports

Create your NFS export directory:
```bash
mkdir -p /mnt/storage/jellyfin
chown nobody:nogroup /mnt/storage/jellyfin
```

Edit `/etc/exports`:

```bash
vi /etc/exports
```

Add your exports. NFSv4, unlike v3, requires a root export, and any shares must be children of that location.
Just make the root /mnt/storage, and the exported share /mnt/storage/jellyfin.  Any clients will reference our
share as /jellyfin.  The star '*' makes this insecure, any host can write/edit media but that's fine for me.

```
/mnt/storage *(rw,sync,fsid=0,crossmnt,no_subtree_check)
/mnt/storage/jellyfin *(rw,sync,all_squash,anonuid=65534,anongid=65534,no_subtree_check,fsid=101)
```

**Export options explained:**
- `rw` - Read/write access
- `sync` - Synchronous writes
- `fsid=0` - NFSv4 root export
- `all_squash` - Map all users to anonymous
- `anonuid/anongid=65534` - Use nobody:nogroup
- `no_subtree_check` - Performance improvement

### Enable and Start NFS

```bash
rc-update add nfs default
rc-service nfs start
```

### Verify Exports

```bash
showmount -e localhost
```

Expected output:
```
Export list for localhost:
/mnt/storage/jellyfin *
/mnt/storage          *
```

Check detailed export options:
```bash
exportfs -v
```

Expected output:
```
/mnt/storage  	<world>(sync,wdelay,hide,crossmnt,no_subtree_check,fsid=0,sec=sys,rw,secure,root_squash,no_all_squash)
/mnt/storage/jellyfin
		<world>(sync,wdelay,hide,no_subtree_check,fsid=101,sec=sys,rw,secure,root_squash,all_squash)
```

---

## Jellyfin Client Configuration

Configure your Jellyfin server (or any Alpine Linux client) to mount the NFS share.

### Install NFS Client (Optional)

**Note:** For NFSv4, `nfs-utils` is optional on the client side. The Alpine kernel includes native NFSv4 support and can mount shares directly via `/etc/fstab`. However, `nfs-utils` provides useful tools like `showmount` and `nfsstat` for debugging.

**Downside:** Installing `nfs-utils` pulls in Python as a dependency (~50MB), which may not be desirable on minimal systems.

If you want the utilities:
```bash
apk add nfs-utils
```

Or skip it and rely on kernel-only NFS support.

### Mount the Share

Create mount point:
```bash
mkdir -p /mnt/thirstynas
```

Add to `/etc/fstab` on your Jellyfin server:

```
thirstynas:/jellyfin /mnt/thirstynas nfs4 rw,vers=4.2,rsize=1048576,wsize=1048576,proto=tcp,hard,timeo=10,retrans=15 0 0
```

**Mount options explained:**
- `hard` - Never give up retrying (critical for Jellyfin)
- `timeo=10` - Initial timeout 1 second (in deciseconds)
- `retrans=15` - Retry 15 times at 1s before exponential backoff begins
- `rsize/wsize` - Large buffer sizes for better performance

**Note:** These timeout values (timeo, retrans) are optimized for the automatic wake-on-access setup described later. See [Automatic Wake on Access](#automatic-wake-on-access) for details.  Nothing I'm describing here stops the NAS from sleeping during playback, it's dependent on the underlying
NFS requests.  To reduce any wake delays as much as possible you may need to experiment with these values, but I'm certain the defaults will not 
give a good experience.

Mount it:
```bash
mount -a
```

### Test Access

```bash
ls /mnt/thirstynas
touch /mnt/thirstynas/test.txt
rm /mnt/thirstynas/test.txt
```

**Configure Jellyfin:** In Jellyfin's dashboard, add `/mnt/thirstynas` as a media library location.

---

## Automatic Suspend on Idle

Install the NFS idle suspend daemon on your **NAS server**.

### Download and Install

```bash
# Transfer the installer to your NAS
# Then run:
sh nfs-idle-suspend-installer.sh

# Enable and start
rc-update add nfs-idle-suspend default
rc-service nfs-idle-suspend start
```

### How It Works

- Monitors `/proc/net/rpc/nfsd` for NFS activity
- Checks every 5 seconds
- Suspends after 30 seconds of inactivity
- Suspends to RAM: `echo mem > /sys/power/state`

### Configuration

Edit `/usr/local/bin/nfs-idle-suspend.sh` to adjust:
- `CHECK_INTERVAL=5` - Polling frequency
- `IDLE_THRESHOLD=30` - Seconds before suspend

### Manual Testing

Test suspend/wake manually first:

```bash
# Suspend (fans should stop)
echo mem > /sys/power/state

# Wake by pressing keyboard key or sending WOL from another machine:
# On Alpine client:
apk add net-tools
ether-wake AA:BB:CC:DD:EE:FF

# On macOS:
brew install wakeonlan
wakeonlan AA:BB:CC:DD:EE:FF
```

Replace `AA:BB:CC:DD:EE:FF` with your NAS MAC address (get it with `ip link` on the NAS).

---

## Automatic Wake on Access

Install the wakeup monitor on your **Jellyfin client**.

### Why This Is Needed

With a hard NFS mount and automatic suspend, you need a way to wake the NAS when Jellyfin tries to access it. Simply using autofs isn't enough due to edge cases where:
- ARP cache expires while NAS is asleep
- Mount exists but server is suspended
- No remount triggers = no wake-up

The solution: Monitor outgoing network traffic to the NAS and send WOL packets when activity is detected.

### Install Dependencies

```bash
apk add tcpdump net-tools
```

### Install Wakeup Monitor

```bash
# Transfer the installer to your Jellyfin server
sh nas-wake-installer.sh
```

### Configure

Edit `/usr/local/bin/nas-wake-monitor.sh`:

```bash
vi /usr/local/bin/nas-wake-monitor.sh
```

Set these values:
```bash
NAS_HOST="thirstynas"              # Your NAS hostname or IP
NAS_MAC="AA:BB:CC:DD:EE:FF"        # NAS MAC address
INTERFACE="eth0"                    # Network interface to monitor
ACTIVITY_FILE="/tmp/nas-activity"   # Timestamp file for NAS heartbeat
ACTIVITY_THRESHOLD=2                # Seconds - skip wake if NAS responded recently
```

**Note:** `LOCAL_MAC` is auto-detected from the network interface. No manual configuration needed.

Get NAS MAC address:
```bash
# On NAS:
ip link show eth0
```

### Enable and Start

```bash
rc-update add nas-wake-monitor default
rc-service nas-wake-monitor start
```

### How It Works

The monitor uses a two-process architecture for intelligent wake-on-LAN:

**Background Process (Incoming Traffic Monitor):**
- Continuously monitors NAS→client traffic using tcpdump
- Samples incoming packets every 0.1 seconds
- Updates `/tmp/nas-activity` timestamp file when packets detected
- Runs as background job managed by main process

**Main Process (Outgoing Traffic Monitor):**
- Watches for client→NAS traffic (ARP requests, NFS calls, etc.)
- Checks activity file timestamp before sending WOL
- **Sends WOL only if:** NAS hasn't responded in 2+ seconds (configurable)
- **Skips WOL if:** Recent incoming traffic indicates NAS is awake

**Benefits:**
- No unnecessary WOL packets when NAS is actively serving files
- No port polling or connection attempts (lower network/NAS load)
- Instant detection of NAS activity via passive monitoring
- Eliminates mount/unmount state issues

During active NFS streaming, the activity file stays fresh (milliseconds old), preventing unnecessary wake attempts. When the NAS suspends, incoming traffic stops, and the next outgoing request triggers a WOL.

---

## Testing

### Test Complete Workflow

1. **Verify NAS suspends:**
   ```bash
   # On NAS, watch logs:
   tail -f /var/log/messages | grep nfs-idle-suspend
   
   # Wait 30 seconds with no activity
   # NAS should suspend (fans stop)
   ```

2. **Test automatic wake:**
   ```bash
   # On Jellyfin client:
   ls /mnt/thirstynas
   
   # Should see wakeup logs:
   tail -f /var/log/messages | grep nas-wake
   
   # NAS should wake and respond within ~10-20 seconds
   ```

3. **Test Jellyfin playback:**
   - Start playing media in Jellyfin
   - NAS should wake and stay awake during playback
   - After playback ends, NAS should suspend after 30 seconds

### Check Service Status

On NAS:
```bash
rc-service nfs status
rc-service nfs-idle-suspend status
```

On Jellyfin client:
```bash
rc-service nas-wake-monitor status
mount | grep nfs
```

---

## Troubleshooting

### NAS Won't Suspend

**Check if service is running:**
```bash
rc-service nfs-idle-suspend status
tail /var/log/messages | grep nfs-idle-suspend
```

**Verify no active connections:**
```bash
netstat -tn | grep :2049
```

**Test manual suspend:**
```bash
echo mem > /sys/power/state
```

### NAS Won't Wake

**Verify WOL is enabled:**
```bash
ethtool eth0 | grep Wake-on
```

**Test WOL manually from client:**
```bash
ether-wake AA:BB:CC:DD:EE:FF
```

**Check wakeup monitor logs:**
```bash
tail -f /var/log/messages | grep nas-wake-monitor
```

**Verify packet filter is working:**
```bash
tcpdump -i eth0 -c 5 "dst host thirstynas"
# Try accessing NFS share from another terminal
```

### Mount Hangs on Client

**Hard mount behavior:** With `hard` mounts, the client will freeze indefinitely waiting for the server. This is intentional - Jellyfin cannot function without the NAS.

**Check wakeup monitor is running:**
```bash
rc-service nas-wake-monitor status
```

**Force unmount if needed:**
```bash
umount -f /mnt/thirstynas
```

### DHCP Lease Issues

If your NAS IP changes after suspend, use a static IP or DHCP reservation:

**Static IP configuration** in `/etc/network/interfaces`:
```
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    post-up /usr/sbin/ethtool -s eth0 wol g
```

**Or configure DHCP reservation** on your router based on the NAS MAC address.

### Mergerfs Not Working

**Check FUSE module:**
```bash
lsmod | grep fuse
```

**Check mount helper:**
```bash
ls -l /usr/sbin/mount.mergerfs
```

**Verify mounts:**
```bash
df -h
mount | grep mergerfs
```

---

## Power Savings

Typical power consumption:
- **Idle (awake):** 40-60W
- **Suspended:** 1-2W (R5 AM4 system, 5 HDDs)
- **Potential savings:** (~£100/year)

Suspend effectiveness depends on your usage pattern. Best results with occasional media access rather than continuous streaming.

---


### Building Installers

```bash
make
```

Generates:
- `nfs-idle-suspend-installer.sh` (for NAS)
- `nas-wake-installer.sh` (for Jellyfin client)

---

## License

MIT License - See LICENSE file

---

## Credits

Thanks to the Jellyfin community for this amazing bit of software.

---

## Additional Notes

- **Maintenance:** Power off Jellyfin when doing NAS maintenance to avoid issues with scheduled tasks
- **Dedicated use:** This setup assumes the NAS is dedicated to Jellyfin. For multi-purpose NAS, consider different suspend strategies
- **Network segment:** Both machines should be on the same subnet for optimal WOL reliability
- **Alpine simplicity:** No systemd, no heavy Python daemons - just efficient shell scripts using ~1-2MB RAM

Enjoy your low-power Jellyfin NAS!

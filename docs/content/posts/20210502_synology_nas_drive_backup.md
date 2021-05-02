---
author: "sc-ram"
date: 2021-05-02
title: "Backup data from single Synology NAS drive"
---
What happens if your Synology is gone but the drive is still there?

I recently upgraded my 2-bay Synology NAS with bigger drives by replacing one drive after the other with a bigger one
and running a repair step afterwards. That worked perfectly fine and did not take too long. However, afterwards I wanted
too see if I could retrieve data from the drives even though they had been setup using SHR (Synology Hybrid Raid).
This could come handy if the NAS dies but the drives are still intact. As I am working on my old drives there is no risk
of losing data. But playing with the raid configuration can of course lead to invalid raid configurations and data loss.

So let's see how far we can get...
 
## Connect drive (USB or SATA) and check device name
```
$ lsblk
...

sdc               8:32   0   1.8T  0 disk 
├─sdc1            8:33   0   2.4G  0 part 
├─sdc2            8:34   0     2G  0 part 
├─sdc3            8:35   0     1K  0 part 
└─sdc5            8:37   0   1.8T  0 part
```
I don't have too many drives attached to my machine so finding the correct block device is easy. In my case it is sdc.
Apparently it contains 4 partitions. Let's see what kind of raid SHR really is.

## Check Raid configuration
```
$ sudo mdadm --examine /dev/sdc5
/dev/sdc5:
          Magic : a92b4efc
        Version : 1.2
    Feature Map : 0x0
     Array UUID : b424cd2c:14d42b7d:b24e6e57:48e95d1b
           Name : DiskStation:2
  Creation Time : Fri Feb  3 10:09:23 2017
     Raid Level : raid1
   Raid Devices : 2

 Avail Dev Size : 3897366912 (1858.41 GiB 1995.45 GB)
     Array Size : 1948683456 (1858.41 GiB 1995.45 GB)
    Data Offset : 2048 sectors
   Super Offset : 8 sectors
   Unused Space : before=1968 sectors, after=0 sectors
          State : clean
    Device UUID : 3a6825ba:a1548281:c02a8604:47837a28

    Update Time : Wed Apr 21 19:54:13 2021
       Checksum : d1cd24ec - correct
         Events : 446


   Device Role : Active device 1
   Array State : AA ('A' == active, '.' == missing, 'R' == replacing)
```
Apparently we can work with raid 1 after all. Let's see if we can create a running raid configuration and mount it.

## Assemble raid from single disk
```
$ sudo mdadm -A -R /dev/md3 /dev/sdc5
mdadm: Merging with already-assembled /dev/md/DiskStation:2
mdadm: failed to add /dev/sdc5 to /dev/md/DiskStation:2: Device or resource busy
mdadm: /dev/md/DiskStation:2 has been started with 0 drives (out of 2).
```
Apparently mdadm already created a raid. As I want to set it up manually I will stop this raid for now. 
Especially as it will not work with 0 drives.
```
$ sudo mdadm --stop /dev/md/DiskStation\:2 
mdadm: stopped /dev/md/DiskStation:2
```
Let's try the assemble step once again
``` 
$ sudo mdadm -A -R /dev/md3 /dev/sdc5
mdadm: /dev/md3 has been started with 1 drive (out of 2).
```
That looks much better. This time one drive has been started which is enough for raid 1. Let's try to mount it.

## Let's try to mount it - part1

``` 
$ sudo mkdir /mnt/syno
```
First create a directory to mount the device.

``` 
$ sudo mount /dev/md3 /mnt/syno/
mount: /mnt/syno: unknown filesystem type 'LVM2_member'.
```
Not so fast! Synology seems to use LVM on top of the raid to slice the volumes. So more work is required.

## LVM setup required

``` 
$ sudo vgscan
WARNING: PV /dev/md3 in VG vg1000 is using an old PV header, modify the VG to update.
Found volume group "vg1000" using metadata type lvm2
```
OK so there is a volume group `vg1000` on the device we just set up using mdadm. 
Let's see what LVM can tell us about the volume.

``` 
$ sudo lvdisplay
  WARNING: PV /dev/md3 in VG vg1000 is using an old PV header, modify the VG to update.
  --- Logical volume ---
  LV Path                /dev/vg1000/lv
  LV Name                lv
  VG Name                vg1000
  LV UUID                2gf4Pt-Zn61-CMXW-fBBu-ybWH-gbCi-pqe3q3
  LV Write Access        read/write
  LV Creation host, time , 
  LV Status              available
  # open                 0
  LV Size                1.81 TiB
  Current LE             475752
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     131064
  Block device           253:3
```
This is interesting as it already tells us the LV Path as `/dev/vg1000/lv`. 
So let's try to mount it once again.

## Let's try to mount it - part2

``` 
$ sudo mount /dev/vg1000/lv /mnt/syno/
```
There is no error. Does that mean we managed to mount it finally?

``` 
$ cd /mnt/syno
``` 
```
$ ls
Backup   Data   Music
```

Well, I guess we managed to get to the data. 
The drive is mounted correctly and we can access the data on the drive. 
It contains just the same data like Volume1 on the Synology UI. 
After all it is just a LVM volume.

## Learnings

- Synology uses software raid based on mdadm for raid setup
- Volumes are sliced using LVM on top of the raid devices
- Now I really want to do that with a 4-bay NAS to see if there are any differences. Unfortunately I don't have one.
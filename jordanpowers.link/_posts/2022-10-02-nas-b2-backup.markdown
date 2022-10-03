---
layout: post
title:  "Backing up our NAS to B2"
date:   2022-10-02 06:30:00 -0800
categories:
---

## Rationale
Recently, I've been going through my family's old MiniDV tapes and transcribing them to modern mp4s.
I've been uploading the transcribed videos to our local NAS, which is where we have collected all
the photos and videos taken from more modern cameras and camcorders. However, this recent
transcription effort has forced me to consider the fragility of our current storage solution. While
the RAID-0 configuration of the NAS provides some protection from drive failures, it's still not a
good idea to keep all these irreplaceable photos and videos in a single place. And so, I decided it
was finally time to figure out an off-site backup for our NAS.

## Backblaze B2
After some preliminary investigation, I settled on Backblaze's B2 service to backup the data.
Mostly, the decision was motivated by Backblaze's cheapness and ease of use. At only
$0.005 / GB / month, the only cheaper solution I could find was AWS's S3 Glacier ($0.0036) and
Deep Archive ($0.00099). However, these two options both had significant restrictions on data
retrieval, and were way more complicated to set up and use. Since I'm only uploading
~600GB, the difference in cost was minimal, and B2's simple pricing structure and uncomplicated
api led me to choose that solution.

## The NAS
The NAS in question is a WD My Cloud EX2 Ultra. While this NAS does have some support for
plugin applications, I could not find a plugin or other drop-in solution for uploading to B2.
However, during my research I did find another guide for [Automating WD MyCloud Backups to Backblaze B2](https://www.cavella.com/2022/01/06/automate-mycloud-backups-to-backblaze.html),
which was a great starting point for my own solution. Unfortunately, the other guide does not account
for the fact that changes to the NAS's filesystem are not persisted across reboots, which creates a
few major problems preventing the method described from being used as a long-term solution. As such,
while I did use the ideas presented in that guide, I had to modify it into a viable long-term solution.

## Steps

### Step 1: Backblaze
I started by signing up for B2 and creating a couple of buckets to hold the soon-to-be-uploaded
data. I then generated a set of application keys to allow the NAS programmatic access. This was
relatively straightforward, so I'll omit the details.

### Step 2: RClone
RClone is the tool I used to copy the data from the NAS to B2.

First, I downloaded and unzipped the latest install.

```bash
cd /mnt/HD/HD_a2/NAS_Prog/
wget --no-check-certificate https://downloads.rclone.org/rclone-current-linux-arm-v7.zip
unzip rclone-current-linux-arm-v7.zip
rm rclone-current-linux-arm-v7.zip
cd rclone-v1.59.2-linux-arm-v7
```

Then I configured the Backblaze B2 remote, using the application key generated in step 1.

```bash
cd /mnt/HD/HD_a2/Nas_Prog/rclone-v1.59.2-linux-arm-v7/
./rclone --config ./rclone.conf config
```

### Step 3: Scripts
I created my backup script in the new 'sync' subfolder of the Public share.

```bash
cd /mnt/HD/HD_a2/Public
mkdir sync
cat << 'EOF' > sync/b2-sync.sh
#!/bin/bash
set -ex
date
/mnt/HD/HD_a2/Nas_Prog/rclone-v1.59.2-linux-arm-v7/rclone --config /mnt/HD/HD_a2/Nas_Prog/rclone-v1.59.2-linux-arm-v7/rclone.conf sync --transfers 4 --log-level INFO --log-file=/mnt/HD/HD_a2/Public/sync/pictures-sync.log '/mnt/HD/HD_a2/Public/Shared Pictures' b2:powersnet-pictures
/mnt/HD/HD_a2/Nas_Prog/rclone-v1.59.2-linux-arm-v7/rclone --config /mnt/HD/HD_a2/Nas_Prog/rclone-v1.59.2-linux-arm-v7/rclone.conf sync --transfers 4 --log-level INFO --log-file=/mnt/HD/HD_a2/Public/sync/videos-sync.log '/mnt/HD/HD_a2/Public/Shared Videos' b2:powersnet-videos --exclude '/Plex/**'
echo -en '\n\n'
EOF
chown nobody:share sync
chmod 777 -R sync
```

Note that I limit rclone to 4 parallel transfers. The NAS only has 1 GB of RAM, so any more
transfers would cause an out-of-memory condition.

### Step 4: Initial Upload
The initial upload took a few days, so I used nohup to ensure that it would not be interrupted
if the ssh session were to disconnect.

```bash
cd /mnt/HD/HD_a2/Public/sync
nohup ./b2-sync.sh > b2-sync.log
```

I used `tail` in a second console to monitor the upload progress.

```bash
cd /mnt/HD/HD_a2/Public/sync
tail -f b2-sync.log
tail -f pictures-sync.log
tail -f videos-sync.log
```

### Step 5: Automate the Backup
You'd think automating this would be easy---just set up a cron job to run the backup script
every night. Unfortunately, for some reason the NAS does not preserve modified crontab scripts
across reboots. So I had to find a way to create a periodic task that would persist.

Luckily, I found this [forum post](https://community.wd.com/t/crontab-on-mycloud-ex2/98653/6) that
described modifying the `/usr/local/config/config.xml` file to define a cron job. This job will then
be recreated every time the system reboots.

```xml
<crond>
    <list>
        <count>7</count>
        <!-- ... -->
        <name id="11">b2_backup</name>
    </list>
    <!-- ... -->
    <b2_backup>
        <item id="1">
            <count>1</count>
            <method>3</method>
            <1>0</1>
            <2>0</2>
            <3>*</3>
            <4>*</4>
            <5>*</5>
            <run>/mnt/HD/HD_a2/Public/sync/b2-sync.sh &gt; /mnt/HD/HD_a2/Public/sync/b2-sync.log 2&gt;&amp;1</run>
        </item>
    </b2_backup>
</crond>
```

So far, this seems to be working great!

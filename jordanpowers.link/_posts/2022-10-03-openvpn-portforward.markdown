---
layout: post
title:  "Port Forwarding using OpenVPN"
date:   2022-10-03 12:00:00 -0800
categories:
---
## Rationale
I frequently find myself needing to be able to host a temporary server accessible from outside
of my LAN. There are many reasons I find myself in this situation, including temporarily hosting
game servers for playing with my friends, hosting a webserver to easily share a large file over the
internet, or developing a web application that needs to be able to respond to webhooks and other
3rd-party requests.

However, with the ubiquitousness of NAT in modern ipv4 networks, port forwarding is required to host
any sort of public server from inside a LAN. This is infeasible on large public or corporate
networks, where you have no control over the router and UPnP is almost certainly disabled. While
there are commercial solutions like [ngrok](https://ngrok.com/), these are often expensive
or bandwidth-limited.

Personally, I developed this solution when I was living in university housing and I wanted to host
servers for games like Minecraft, Factorio, or Terraria to play with my friends. The network
on-campus was heavily locked down, and while I could access the internet, I was unable to enact
any form of port forwarding. While I could have rented a virtual server to run these games, I
preferred to forward the traffic to my local machine since it allowed me to rent the cheapest EC2
tier instead of having to pay for the resources required to run more complicated game servers.

## Solution
My solution is to use OpenVPN to create a tunnel from my computer to a remote server, so that
the VPN host becomes essentially my "router." Then, since I have complete control over the remote
server, I can just use port forwarding to send the traffic from the remote server to my local
computer through the OpenVPN tunnel.

### Step 1: Setup a remote host

The remote host should have a static ip or a dyndns setup.

I used an AWS EC2 t2.nano instance, with AWS Route53 as a dns provider.

First, I installed the AWS CLI and other dependencies.
```bash
sudo apt install unzip jq
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -r aws awscliv2.zip
```

Then I created an AWS IAM user with the following policy and saved it using `aws configure`.
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/<YOUR HOSTED ZONE ID HERE>"
        }
    ]
}
```

After that I created a folder for the dyndns script, downloaded it, and edited the configuration
variables at the top.

```bash
mkdir -p ~/dyndns
cd dyndns
curl -O http://jordanpowers.link/assets/ovpn-portforward/dyndns.sh
vim dyndns.sh
```

Finally, I created and enabled a systemd script to run the dyndns on boot.
```bash
curl -O http://jordanpowers.link/assets/ovpn-portforward/dyndns.service
sudo cp dyndns.service /usr/lib/systemd/system/dyndns.service
sudo systemctl daemon-reload
sudo systemctl start dyndns
sudo systemctl enable dyndns
```

### Step 2: Install OpenVPN and EasyRSA
Install OpenVPN.
```bash
sudo apt update
sudo apt install openvpn
```

Download and extract EasyRSA.
```bash
cd ~
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.0/EasyRSA-3.1.0.tgz
tar xvf EasyRSA-3.1.0.tgz
rm EasyRSA-3.1.0.tgz
mv EasyRSA-3.1.0 openvpn-ca
```

### Step 3: Generate the CA
Have easyrsa generate the pki folder.
```bash
./easyrsa init-pki
```
Then, edit the `pki/vars` file to uncomment the set_var instructions and fill in the requisite
values.
```
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "Los Angeles"
set_var EASYRSA_REQ_ORG        "Powers Co"
set_var EASYRSA_REQ_EMAIL      "admin@example.com"
set_var EASYRSA_REQ_OU         "Community"
```

Finally, generate the CA. When prompted for a 'Common Name', accept the default value.
```bash
./easyrsa build-ca nopass
```

### Step 4: Generate the Server Certificate, Key, and DH Files
First, generate and sign the server certificate. When prompted for a 'Common Name,' just hit enter
to accept the default values. When prompted to 'Confirm request details', type `yes` and hit enter.
```bash
./easyrsa gen-req server nopass
./easyrsa sign-req server server
```

Next, generate a strong Diffie-Hellman key and a HMAC signature. This will take a few minutes
to complete.
```bash
./easyrsa gen-dh
openvpn --genkey secret ta.key
```

Finally, copy all the newly generated files to `/etc/openvpn`.
```bash
sudo cp pki/private/server.key /etc/openvpn
sudo cp pki/issued/server.crt /etc/openvpn
sudo cp pki/ca.crt /etc/openvpn
sudo cp pki/dh.pem /etc/openvpn
sudo cp ta.key /etc/openvpn
```

### Step 5: Configure the OpenVPN Service
First, download the server configuration provided [here](/assets/ovpn-portforward/server.conf)
and install it.
```bash
cd ~
curl -O http://jordanpowers.link/assets/ovpn-portforward/server.conf
sudo chown root:root server.conf
sudo chmod 644 server.conf
sudo mv server.conf /etc/openvpn
```

Next, make the client configuration directory.
```bash
sudo mkdir /etc/openvpn/ccd
```

Decide on a name for your client and remember it. Create a file with that same name as described
below. Be sure to replace `<CLIENT NAME>` with the actual name you decided.
```bash
sudo tee /etc/openvpn/ccd/<CLIENT NAME> << 'EOF'
ifconfig-push 10.8.0.201 255.255.255.0
EOF
```

### Step 6: Enable network forwarding
First, enable ufw.
```bash
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status
```

Next, enable ip forwarding. Edit `/etc/sysctl.conf`:
```bash
sudo vim /etc/sysctl.conf
```

Set the following value:
```
net.ipv4.ip_forward=1
```

And reload the parameters from disk
```bash
sudo sysctl -p
```

Next, edit iptables to enable forwarding traffic from OpenVPN clients.
First, get the network interface of the server.
```bash
ip route | grep default
```

You're looking for the value that follows the word `dev`. It'll usually be something like `eth0`
or `enp2s0f0`.

Next, edit `/etc/ufw/before.rules`:
```bash
sudo vim /etc/ufw/before.rules
```

Near the top, add the following lines. Make sure to change `eth0` with the interface you just
found.
```
#
#
# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#

# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to eth0
-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
COMMIT
# END OPENVPN RULES

# Don't delete these required lines, otherwise there will be errors
...
```

Next, edit `/etc/default/ufw`:
```bash
sudo vim /etc/default/ufw
```

And set the default forward policy:
```
DEFAULT_FORWARD_POLICY="ACCEPT"
```

Finally, allow OpenVPN traffic on port 1194 and restart the firewall.
```bash
sudo ufw allow 1194/udp
sudo ufw disable
sudo ufw enable
```

### Step 7: Enable the OpenVPN Service
First, start the service and make sure there are no errors.
```bash
sudo systemctl start openvpn@server
sudo systemctl status openvpn@server
```

If all is well, enable the service so the server will start on boot.
```bash
sudo systemctl enable openvpn@server
```

### Step 8: Generate the Client Configuration
First, make a directory to hold the client configurations.
```bash
mkdir -p ~/client-configs/files
```

Then, download the client configuration base and the generation script.
```bash
cd ~/client-configs
curl -O http://jordanpowers.link/assets/ovpn-portforward/base.conf
curl -O http://jordanpowers.link/assets/ovpn-portforward/make_config.sh
chmod +x make_config.sh
```

Next, open base.conf and replace `<SERVER_IP>` with the server's static ip or dyndns address.
```
remote <SERVER_IP> 1194
```

Run the generation script with the name of your client. Be sure to use the same name as configured
in the `ccd` directory from step 5.
```bash
./make_config.sh <CLIENT_NAME>
```

Finally, copy the file at ~/client-configs/files/<CLIENT_NAME>.ovpn to the client and open it
with the OpenVPN client.

### Step 9: Forward Ports
First, download the forwarding script.
```bash
cd ~
curl -O http://jordanpowers.link/assets/ovpn-portforward/ports.py
chmod +x ports.py
```

Then run the script to forward the desired ports.
```bash
./ports.py forward 8000 tcp
```
Note that forwarded ports will be reset when the server is rebooted. The forwarding script will have
to be re-run every time the server is started.

## References
- <https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-18-04>

# Installation steps

## Setup for basic configuration

**Change directory**

```
cd ~/Downloads
```

**Hostname configuration**

```
sudo echo "gbadrive" > /etc/hostname
```

**Upgrade**

```
sudo apt update && sudo apt upgrade
```

**Dependencies**

```
sudo apt install build-essential libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev git avahi-daemon pulseaudio-module-bluetooth golang dnsmasq bridge-utils python3-dbus python-gi-dev pulseaudio-module-zeroconf python2.7 python2-dev oneko tshark sox tcpdump samba expect aircrack-ng lirc libbluetooth-dev i2c-tools
```

**Create python2.7 link for btnap**

```
sudo ln -s /usr/bin/python2.7 /usr/bin/python2
```

**Install python 3 and 2.7 dependencies**

```
wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
sudo python2 get-pip.py
sudo python2.7 -m pip install dbus-python
sudo python3 -m pip install wiringpi rpi-rf pybluez evdev dbus-python
```

**Clear dependencies**

```
sudo apt autoremove
```

**Configure wlan1 for hotspot in** \*/etc/dhcpcd.conf \*

```
interface wlan1
    static ip_address=192.168.10.1/24
    nohook wpa_supplicant
```

**WiFi hotspot**

Set hostapd conf in */etc/default/hostapd*

```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

In */etc/hostapd/hostapd.conf*

```
country_code=FR
interface=wlan1
ssid=GBA Drive
hw_mode=b
driver=nl80211
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=gbadrive
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

**Enable IPv4 routing in** */etc/sysctl.conf*

```
# Enable IPv4 routing
net.ipv4.ip_forward=1
```

**Set dnsmasq configuration in** */etc/dnsmasq.conf*  
wlan0 is for the WiFi, br0 for the bluetooth.

```
interface=wlan1
interface=br0
domain=wlan
dhcp-range=wlan1,192.168.10.100,192.168.10.150,12h
dhcp-range=br0,192.168.20.100,192.168.20.150,12h
```

**Unmask and disable hostapd for manual activation only**

```
sudo systemctl unmask hostapd
sudo systemctl disable hostapd
```

**Configure bluetooth hotspot and sniffer for LE devices**

Set the following line in */etc/systemd/system/bluetooth.target.wants/bluetooth.service*

```
ExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=sap --experimental
```

**Install btnap**

```
git clone https://github.com/bablokb/pi-btnap.git
sudo ./pi-btnap/tools/install-btnap server
```

Check */etc/btnap.conf*

```
MODE="server"
BR_DEV="br0"
BR_IP="192.168.20.99/24"
BR_GW="192.168.20.1"
ADD_IF="lo"
REMOTE_DEV=""
DEBUG=""
```

**Set bluetooth name**

```
echo "PRETTY_HOSTNAME=\"GBA Drive\"" > /etc/machine-info
```

**Test bluetooth services**

```
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
sudo systemctl restart dnsmasq
sudo systemctl restart btnap
```

**Bluetooth pairing**

```
bluetoothctl
> agent on
> scan on
... wait for your device to show up ...
...
... now pair with its address
> pair aa:bb:cc:dd:ee:ff
... and trust it permantently ...
> trust aa:bb:cc:dd:ee:ff
... wait ...
> quit
```

## Setup for WiFi hacking

**Update OUI database for aircrack-ng**

```
sudo airodump-ng-oui-update
```

**Setup GO and Bettercap**

**Change directory**

```
cd ~/Downloads
```

**Make this persistent in your .bashrc or .zshrc file (root and pi user)**

```
export GOPATH=/root/gocode
sudo mkdir -p $GOPATH
git clone https://github.com/bettercap/bettercap.git
```

**Let's install it**

```
cd bettercap
sudo make
sudo make install
```

**Let's download the caplets and fix it**

```
cd /usr/local/share/bettercap/caplets/
wget "https://raw.githubusercontent.com/bettercap/caplets/master/pita.cap"
sed -i "s/\!monstop/#\!monstop/g" /usr/local/share/bettercap/caplets/pita.cap
sed -i "s/\!monstart/#\!monstart/g" /usr/local/share/bettercap/caplets/pita.cap
sed -i "s/wpa\.pcap/\/home\/pi\/Share\/captures\/capture_wpa.pcap/g" /usr/local/share/bettercap/caplets/pita.cap
wget "https://raw.githubusercontent.com/bettercap/caplets/master/simple-passwords-sniffer.cap"
sed -i "s/passwords\.cap/\/home\/pi\/Share\/captures\/capture_passwords.cap/g" usr/local/share/bettercap/caplets/simple-passwords-sniffer.cap
```

## Setup for radio hijacking

**Download and build Pi FM RDS**

```
cd /opt
sudo git clone https://github.com/ChristopheJacquet/PiFmRds.git
sudo mv PiFmRds pi_fm_rds
cd pi_fm_rds/src
```

**Tweak the** *pi_fm_rds.c* **file to exploit full raspi capabilities**

**Change the line**

```
carrier_freq < 76e6 || carrier_freq > 108e6
```

**By**

```
carrier_freq < 1e6 || carrier_freq > 250e6
```

**Compile**

```
sudo make clean
sudo make
sudo mv pi_fm_rds /opt/pi_fm_rds/
```

## Setup Samba server

```
SMB_DIR="/home/pi/Share"
mkdir $SMB_DIR
sudo chown -R pi:pi $SMB_DIR
sudo chmod 0777 $SMB_DIR
```

**Edit the SMB configuration file in** */etc/samba/smb.conf*

```
# GBA Drive settings
[GBAShare]
comment = GBADrive
public = yes
writeable = yes
browsable = yes
path = /home/pi/Share
create mask = 0777
directory mask = 0777
```

**Restart SMB service and enable on boot**

```
sudo systemctl restart smbd
sudo systemctl enable smbd
```

## Setup for Lirc - Infrared module

**Install lirc and disable on boot**

```
sudo apt install lirc
sudo systemctl disable lircd
```

**Edit the file** */boot/config.txt* **and add the following lines**

```
dtoverlay=gpio-ir,gpio_pin=27
dtoverlay=gpio-ir-tx,gpio_pin=17
```

## Setup for GBA Drive

**Install GBA Drive**

```
cd /opt/
sudo git clone https://github.com/valou8709/gbadrive.git
echo "alias gbadrive='sudo xterm -fn fixed -fullscreen /opt/gbadrive/gbadrive.sh'" >> /home/pi/.bashrc
sudo chmod 744 /opt/gbadrive/gbadrive.sh /opt/gbadrive/assets/scripts/*
source /home/pi/.bashrc
cp -r /opt/gbadrive/share/* /home/pi/Share/
sudo chown -R 0777 /home/pi/Share
```

**Put dialog configuration file .dialogrc in** */opt/gbadrive*

**Run GBADrive at startup as a graphical program**

**Create the file** /etc/xdg/autostart/gbadrive.desktop **and add the following lines:**

```
[Desktop Entry]
Name=GBADrive
Exec=sudo xterm -fn fixed -fullscreen -e /opt/gbadrive/gbadrive.sh
```

**Create another file for QJoyPad in** /etc/xdg/autostart/qjoypad.desktop **and add the following lines:**

```
[Desktop Entry]
Name=QJoyPad
Exec=qjoypad gbadrive                                             
```

**Reboot**

```
sudo reboot
```

## Setup for GBA streaming and ROM loader

**Setup raspi stream on gba**

```
sudo apt install python-pigpio python3-pigpio qjoypad
```

**Edit and add the following lines in the file** */boot/config.txt*. **Remove other lines before which could caue conflicts (max_framebuffer, dtoverlay etc.)**

```
# Set Aspect Ratio (4:3)
hdmi_safe=0
disable_overscan=1
hdmi_group=2
hdmi_mode=6

# Set GBA Resolution
framebuffer_width=240
framebuffer_height=160
```

**Run raspi-config and enable SPI, Serial and I2C interfaces then reboot**

```
sudo raspi-config
```

**Download the gba-remote-play release**

```
cd /opt/
sudo mkdir gba_remote_play && cd gba_remote_play
sudo wget https://github.com/rodri042/gba-remote-play/releases/download/v1.1/gba-remote-play.zip
sudo unzip gba-remote-play.zip
sudo rm gba-remote-play.zip
sudo chmod +x gbarplay.sh multiboot.tool raspi.run
```

**Add the following line after running** `sudo crontab -e` **to run streaming at startup**

```
# Start GBA Streaming at boot
@reboot sleep 5 ; /opt/gba_remote_play/gbarplay.sh &
```

**Install and check WiringPi**

```
cd ~/Downloads/
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb
gpio -v
```

**Set the button mapping by editing the following file (and create the directory if needed)** */home/pi/.qjoypad3/gbadrive.lyt*

```
# QJoyPad 4.3 Layout File
# For GBA Drive

Joystick 1 {
        Button 1: key 65
        Button 2: key 36
        Button 5: key 37
        Button 6: key 54
        Button 9: key 23
        Button 10: key 36
        Button 11: Key 111
        Button 12: Key 116
        Button 13: Key 113
        Button 14: Key 114
}
```

**Setup GBA ROM loader**

```
cd /opt/
sudo git clone https://github.com/bartjakobs/GBA-Multiboot-Python.git
sudo mv GBA-Multiboot-Python gba_multiboot
```

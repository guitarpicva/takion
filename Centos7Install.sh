#!/bin/bash
# Centos7 install should be run as root or via sudo
################################################################
# See the TAKServerSetup.txt file for TAK server configuration
################################################################

# 1. Install epel-release and run an update to freshen package lists
yum install epel-release -y
yum update -y

# 2. If required, enable sshd so that the device may be reached
# via shell over ssh.  Then start the ssh server
systemctl enable sshd
systemctl start sshd
# for use with radio
sudo yum install telnet -y 
# 3. Install dependencies for the TAK server
yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y

###################################################################
# 4. Open various firewall ports
###################################################################
firewall-cmd --add-port=6969/udp --permanent
firewall-cmd --add-port=8089/tcp --permanent
firewall-cmd --add-port=8446/tcp --permanent
firewall-cmd --add-port=8443/tcp --permanent
firewall-cmd --add-port=8444/tcp --permanent
firewall-cmd --reload
# 13. Change the config to allow lots of open file descriptors
echo -e "* soft nofile 32768\n* hard nofile 32768" | sudo tee --append /etc/security/limits.conf > /dev/null

###################################################################
# 5. OPTIONAL - install remote desktop protocol for remote control
###################################################################
yum install xrdp -y
systemctl enable xrdp
systemctl start xrdp
firewall-cmd --add-port=3389/tcp --permanent
firewall-cmd --reload
################################################################

# 6. Install the TAK Server from the TAK server rpm file
yum install takserver-4.0-RELEASE130.noarch.rpm -y

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!!!! ANSWER THE FOLLOWING QUESTION TO COMPLETE THE SETUP.  HINT: 3 !!!!!"
echo "!!!!! You must choose the selection which enables openjdk 11 !!!!!!!!!!!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
# 7. Select the jdk11 as the default Java version by running:
alternatives --config java

# 8. Initialize the ATAK database with the setup script
/opt/tak/db-utils/takserver-setup-db.sh

# 9. Enable it at boot and start it
systemctl enable takserver
systemctl start takserver
# now check it
ps ax|grep tak
# that should show multiple processes running

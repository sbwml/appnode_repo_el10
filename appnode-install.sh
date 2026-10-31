#!/bin/bash
RED_COLOR='\E[1;31m'
GREEN_COLOR='\E[1;32m'
YELLOW_COLOR='\E[1;33m'
BLUE_COLOR='\E[1;34m'
PINK_COLOR='\E[1;35m'
RES='\E[0m'
defpassword=$(cat /proc/sys/kernel/random/uuid | md5sum | base64 | awk '{print substr($0, 20, 8)}')

NOTE='

              AppNode - www.appnode.com

---------------------------------------------------------

  _______                 _____   __     _________     
  ___    |__________________  | / /___________  /____ 
  __  /| |__  __ \__  __ \_   |/ /_  __ \  __  /_  _ \
  _  ___ |_  /_/ /_  /_/ /  /|  / / /_/ / /_/ / /  __/
  /_/   |_|  .___/_  .___//_/ |_/  \____/\__,_/  \___/ 
          /_/     /_/

---------------------------------------------------------
'
echo -e "\E[1;32m$NOTE\E[0m"

platform=$(arch)
if [ "$(id -u)" != "0" ]; then
  echo "ERROR: Root user is required to run the installer!"
  exit 1
fi

ip_info=$(curl -s https://ip.cooluc.com)
myip=$(echo "$ip_info" | grep -Po 'ip\":"\K[^"]+')

if [[ "$ONLY_AGENT" == "1" || "$AGENT_ONLY" == "1" ]]; then
  ONLY_AGENT_MODE=1
else
  ONLY_AGENT_MODE=0
fi

if [ "$ONLY_AGENT_MODE" != "1" ]; then
  rm -rf /opt/appnode
fi

echo -e "${GREEN_COLOR}>> Disabling SELinux${RES}"
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0 > /dev/null 2>&1
echo
echo

echo -e "\r\n${GREEN_COLOR}>> Stopping and disabling firewalld${RES}\r\n"
systemctl stop firewalld > /dev/null 2>&1
systemctl disable firewalld > /dev/null 2>&1

echo -e "\033[32m* Installing repository epel...\033[0m"
dnf install -y epel-release

if [[ "$INSTALL_AGENT" == "1" || "$ONLY_AGENT_MODE" == "1" ]]; then
  echo -e "${GREEN_COLOR}>> Updating repository for AppNode Agent${RES}\r\n"
  echo -e "\033[32m* Installing repository appnode-agent...\033[0m"
  dnf install -y https://hook.cooluc.com/release/appnode-agent-release-1.2-1.el10.x86_64.rpm
  echo -e "\r\n\033[32m* Installing repository appnode-extras...\033[0m"
  dnf install -y https://hook.cooluc.com/release/appnode-extras-release-1.1-1.el10.noarch.rpm
  echo -e "\r\n\033[32m* Installing repository appnode...\033[0m"
  dnf install -y https://hook.cooluc.com/release/appnode-release-1.1-1.el10.noarch.rpm

  echo -e "\r\n${GREEN_COLOR}>> Installing AppNode Agent${RES}\r\n"
  dnf install -y appnode-agent appnode-app-sshd sqlite3
  echo -e "\r\n${GREEN_COLOR}>> Starting AppNode Agent service${RES}\r\n"
  appnode agent start
  systemctl enable appnode-agent > /dev/null 2>&1

  if netstat -lnp 2>/dev/null | grep -q :9999 || ss -lntp 2>/dev/null | grep -q :9999; then
    echo -e "\r\n${GREEN_COLOR}>> AppNode Agent installed successfully!${RES}\r\n"
  fi
fi

if [ "$ONLY_AGENT_MODE" != "1" ]; then
  echo -e "${GREEN_COLOR}>> Updating repository for AppNode CCenter${RES}\r\n\r\n"
  echo -e "\033[32m* Installing repository appnode-ccenter...\033[0m"
  dnf install -y https://hook.cooluc.com/release/appnode-ccenter-release-1.2-1.el10.x86_64.rpm

  echo -e "\r\n${GREEN_COLOR}>> Installing AppNode CCenter${RES}\r\n"
  dnf install -y appnode-ccenter
  echo -e "\r\n${GREEN_COLOR}>> AppNode CCenter Configuration${RES}\r\n"

  echo -n "* Port [default: 8888]: "
  read port
  if [ -z "$port" ]; then
    port=8888
  fi
  echo -n "* Admin username [default: admin]: "
  read username
  if [ -z "$username" ]; then
    username=admin
  fi
  echo -n "* Admin password [default: $defpassword]: "
  read password
  if [ -z "$password" ]; then
    password=$defpassword
  fi

  echo -e "\r\n${GREEN_COLOR}>> Starting AppNode CCenter service${RES}\r\n"
  appnode ccenter config ccenter_port "$port" > /dev/null 2>&1
  appnode ccenter.user create "$username" "$password" > /dev/null 2>&1
  appnode ccenter start

  echo -e "\r\n${GREEN_COLOR}>> AppNode CCenter installed successfully!${RES}\r\n"

  echo -e "\r\n${GREEN_COLOR}--------------------------------------------------
- URL: http://$myip:$port/
- Admin username: $username
- Admin password: $password
--------------------------------------------------${RES}\r\n"
else
  echo -e "\r\n${GREEN_COLOR}--------------------------------------------------
- AppNode Agent Port: 9999
- Server IP: $myip
- Please add and connect this node in your AppNode CCenter panel.
--------------------------------------------------${RES}\r\n"
fi

echo -e "\r\n${GREEN_COLOR}       ENJOY YOUR NODE :-)${RES}\r\n"

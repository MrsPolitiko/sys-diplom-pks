#!/bin/bash

# Define some constants
SSH_CONNECT_TIMEOUT="-o ConnectTimeout=30"
SSH_IDENTITY_FILE=$(pwd)"/ssh-keys/vm-cloud-diplom"
SSH_COMMON_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONNECT_TIMEOUT"
SSH_KEYS="-i $SSH_IDENTITY_FILE $SSH_COMMON_ARGS"
SSH_CONFIG="$HOME/.ssh/config"

PLAYBOOKS=("webservers.yml" "zabbix-server.yml"  "zabbix-agents.yml")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function definitions
copy_playbooks() {
    # Копируем файлы на ресурс bastion
    echo -e "${GREEN}Copying config files...${NC}"
    # Обновляем hosts на bastion
    echo -e "${GREEN}... hosts${NC}"
    scp ${SSH_KEYS} ./hosts_for_bastion ${VM_USERNAME}@${BASTION_WAN_IP}:/tmp/hosts_for_bastion
    ssh ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} "sudo bash -c 'cat /tmp/hosts_for_bastion >> /etc/hosts'"

    # Закидываем ansible на bastion
    echo -e "${GREEN}... ansible${NC}"
    scp ${SSH_KEYS} -r ./ansible ${VM_USERNAME}@${BASTION_WAN_IP}:${RESOURCE_HOME}/
    # Ansible не будет запускаться из каталога с правами выше 755
    ssh ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} "sudo chmod 755 ${RESOURCE_HOME}/ansible"
}

copy_keys() {
    # Закидываем ключ на bastion
    echo -e "${GREEN}... key${NC}"
    scp ${SSH_KEYS} ./ssh-keys/vm-cloud-diplom ${VM_USERNAME}@${BASTION_WAN_IP}:${RESOURCE_HOME}/.ssh/vm-cloud-diplom
}

# Exit on error and show commands
set -e
set -x

PARAM=$1 # The first param of the script
case "$PARAM" in
  "clear"|"destroy")
    echo -e "${YELLOW}=== Destroy deployment ===${NC}"
    terraform -chdir=./terraform destroy -auto-approve
    [ "$PARAM" = "destroy" ] && exit 0
    ;;
  "copy")
    echo -e "${YELLOW}=== Copying files to bastion ===${NC}"
    # Получаем необходимые переменные
    cd terraform/ || exit
    VM_USERNAME=$(terraform output -raw vm_username)
    BASTION_WAN_IP=$(terraform output -raw bastion_ip)
    cd ..
    RESOURCE_HOME="/home/${VM_USERNAME}"
    
    copy_playbooks "${VM_USERNAME}" "${BASTION_WAN_IP}" "${RESOURCE_HOME}"
    copy_keys "${VM_USERNAME}" "${BASTION_WAN_IP}" "${RESOURCE_HOME}"
    exit 0
    ;;
esac

echo -e "${YELLOW}=== Starting deployment ===${NC}"

# Terraform Part
echo -e "${GREEN}Initializing Terraform...${NC}"

test ! -d ./scripts && cd ..
cd terraform/ || exit

terraform init -reconfigure

echo -e "${GREEN}Applying Terraform configuration...${NC}"
terraform apply -auto-approve

#******************  Prepare some files  *************************#
# Get outputs for Ansible
BASTION_NAME=$(terraform output -raw bastion_name)
ZABBIX_NAME=$(terraform output -raw zabbix_name)
WEB_A_NAME=$(terraform output -raw web_a_name)
WEB_B_NAME=$(terraform output -raw web_b_name)
ELASTIC_NAME=$(terraform output -raw elastic_name)
VM_USERNAME=$(terraform output -raw vm_username)
RESOURCE_HOME="/home/${VM_USERNAME}"

BASTION_FQDN="${BASTION_NAME}.ru-central1.internal"
ZABBIX_FQDN="${ZABBIX_NAME}.ru-central1.internal"
WEB_A_FQDN="${WEB_A_NAME}.ru-central1.internal"
WEB_B_FQDN="${WEB_B_NAME}.ru-central1.internal"
ELASTIC_FQDN="${ELASTIC_NAME}.ru-central.internal"

# Get outputs for bastion
BASTION_WAN_IP=$(terraform output -raw bastion_wan_ip)
BASTION_IP=$(terraform output -raw bastion_lan_ip)
ZABBIX_IP=$(terraform output -raw zabbix_lan_ip)
ZABBIX_WAN_IP=$(terraform output -raw zabbix_wan_ip)
WEB_A_IP=$(terraform output -raw web_a_lan_ip)
WEB_B_IP=$(terraform output -raw web_b_lan_ip)
ELASTIC_IP=$(terraform output -raw elastic_lan_ip)

cd ..  # В корне проекта

#******************* Собираем файлы конфигурации проекта *********************
#******************* Инвентори плейбука *********************
# ansible !!! Change to FQDN
echo -e "${GREEN}Updating Ansible inventory...${NC}"

# 😸 Генерируем inventory файл для Ansible
cat > ansible/inventory/hosts.ini <<EOF
[bastion]
${BASTION_FQDN}

[zabbix]
${ZABBIX_FQDN}

[webservers]
${WEB_A_FQDN}
${WEB_B_FQDN}

[elastic]
${ELASTIC_FQDN}

# !!! Для проксирования SSH обязательно нужно указывать в ProxyCommand= -i ../ssh-keys/vm-cloud-diplom  
[all:vars]
#ansible_ssh_private_key_file=../ssh-keys/vm-cloud-diplom
#ansible_ssh_common_args='${SSH_CONNECT_TIMEOUT} -o ProxyCommand="ssh -W %h:%p -q pks@${BASTION_WAN_IP} -i ../${SSH_IDENTITY_FILE}"'
ansible_ssh_private_key_file=${RESOURCE_HOME}/.ssh/vm-cloud-diplom
ansible_ssh_common_args='${SSH_CONNECT_TIMEOUT}'

[bastion:vars]
ansible_ssh_common_args=''
EOF

#******************* Общие переменные плэйбука *********************
# ansible !!! Change to FQDN
echo -e "${GREEN}Updating Ansible group_vars...${NC}"

# 😺 Генерируем переменные для Ansible
cat > ansible/group_vars/all/main.yml <<EOF

# Настройки Zabbix
zabbix_version: "7.0"
zabbix_db_name: "zabbix"
zabbix_db_user: "zabbix"
zabbix_db_password: "zabbix"  # TODO: Переделать на vault или другой secure storage
zabbix_server: "zabbix.example.com"

# Настройки PHP
php_fpm_socket: "/var/run/php/php8.1-fpm.sock"

# Адреса ресурсов
zabbix_server_ip: ${ZABBIX_FQDN}
bastion_ip: ${BASTION_FQDN}
weba_ip: ${WEB_A_FQDN}
webb_ip: ${WEB_B_FQDN}
elastic_ip: ${ELASTIC_FQDN}
EOF

# hosts
cat > hosts_for_bastion <<EOF
${BASTION_IP}   ${BASTION_FQDN}
${WEB_A_IP}   ${WEB_A_FQDN}
${WEB_B_IP}   ${WEB_B_FQDN}
${ZABBIX_IP}   ${ZABBIX_FQDN}
${ELASTIC_IP}   ${ELASTIC_FQDN}
EOF

#***  Подготовка к запуску плейбуков. Запуск осуществляется из хоста где запускается скрипт
# Чистим known_host
echo -e "${GREEN}Clean known_host...${NC}"
ssh-keygen -R ${BASTION_WAN_IP}
ssh-keygen -R ${WEB_A_IP}
ssh-keygen -R ${WEB_B_IP}
ssh-keygen -R ${ZABBIX_WAN_IP}
ssh-keygen -R ${ELASTIC_IP}


# Проверяем доступность bastion # Не всегда успевает подняться ssh на bastion
echo -e "${GREEN}Check bastion host...${NC}"
#echo -e "${YELLOW}BASTION_WAN_IP is ${BASTION_WAN_IP} ${NC}"
duration=15
while [ $duration -gt 0 ]; do
  if ssh -q ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} exit; then
    echo "SSH доступен!"
    break
  else
    echo "Осталось попыток: $duration \n"
    sleep 1
    ((duration--))
  fi
done

if [ $duration -eq 0 ]; then
  echo "Не удалось подключиться по SSH после 15 попыток"
  exit 1
fi

copy_playbooks
copy_keys


# Обновляем hosts на нашем хосте
#test ! -e /etc/hosts.bak && sudo cp /etc/hosts /etc/hosts.bak
#sudo cat /etc/hosts.bak > /etc/hosts
#sudo cat ./hosts_for_bastion >> /etc/hosts

# Обновляем .ssh/config на нашем хосте
awk -v new_ip="$BASTION_WAN_IP" '
    /^Host bastion/ {sub(/[0-9.]+$/, new_ip)}
    /^    HostName/ {sub(/[0-9.]+/, new_ip)}
    {print}
' "$SSH_CONFIG" > "${SSH_CONFIG}.tmp" && mv "${SSH_CONFIG}.tmp" "$SSH_CONFIG"

echo -e "${GREEN}Running Ansible playbooks...${NC}"

# Проверка доступности хостов
echo -e "${YELLOW}Testing SSH connections...${NC}"
sleep 20
ssh ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} "cd ansible && ansible all -m ping"

# 😺 Последовательное выполнение плейбуков
for playbook in "${PLAYBOOKS[@]}"; do
  echo -e "${GREEN}Executing ${playbook}...${NC}"
#  ansible-playbook playbooks/${playbook}
  #ssh -i ssh-keys/vm-cloud-diplom -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pks@158.160.109.121 "cd ansible && ansible-playbook playbooks/zabbix-server.yml"
  ssh ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} "cd ansible && ansible-playbook playbooks/${playbook}" 
done

echo -e "${GREEN}=== Deployment completed successfully! ===${NC}"

# Функция проверки доступности ресурсов
check_services() {
    local services=("nginx" "zabbix-server" "elasticsearch")
    for service in "${services[@]}"; do
        # ssh ssh-keys/vm-cloud-diplom pks@158.160.62.40  "systemctl is-active -q nginx
        if ! ssh ${SSH_KEYS} ${VM_USERNAME}@${BASTION_WAN_IP} "systemctl is-active -q $service"; then
            log "ERROR" "Сервис $service не запущен"
            return 1
        fi
    done
}

log() {
    # exec > >(tee "${0}".log) 2>&1  # Копируем вывод в файл
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" 
}

update_session_hosts() {
    # Обновляем hosts для текущей сессии
    #test ! -e /etc/hosts.bak && sudo cp /etc/hosts /etc/hosts.bak
    #sudo cat /etc/hosts.bak > /etc/hosts
    #sudo cat ./hosts_for_bastion >> /etc/hosts
    return
}

# Helpful links
# logging
# https://r4ven.me/it-razdel/komandnaya-stroka-linux/nastrojka-logirovaniya-vyvoda-skriptov-bash/


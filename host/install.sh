#!/bin/bash

# Základní nástroje
sudo apt-get update
sudo apt-get install -y net-tools uuid-runtime wget

# Stažení a instalace Zabbix repo pro Ubuntu 22.04 (Jammy)
sudo wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_7.0-1+ubuntu22.04_all.deb

# Aktualizace seznamu balíčků a instalace agenta
sudo apt-get update
sudo apt install -y zabbix-agent2

# Volitelné pluginy
sudo apt install -y zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

# Povolení a spuštění služby
sudo systemctl enable zabbix-agent2
sudo systemctl restart zabbix-agent2
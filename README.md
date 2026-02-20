Úvodem – omluva a vysvětlení
Z důvodu mé absence na hodině, kde byl tento projekt zadán, jsem se potýkal s některými nedokonalostmi a musel jsem hledat alternativní řešení.

Při prvním pokusu o spuštění pfSense přes doporučený box došlo k chybě (viz screenshot v příloze), protože box nepodporoval VirtualBox. Z tohoto důvodu jsem byl nucen použít jiný, funkční box – madinasoc2030/pfsense. Tento box je sice starší (verze 2.6.0 namísto očekávané 2.7.2), ale pro účely monitoringu pomocí SNMP a Zabbixu je plně dostačující a všechny úkoly projektu na něm byly úspěšně realizovány.












Projekt: Monitoring pfSense a Linux hostitele pomocí Zabbix 7.0 LTS
Tento repozitář obsahuje kompletní konfiguraci pro monitoring firewallu pfSense a linuxového hostitele pomocí Zabbix 7.0 LTS. Vše je postaveno na Vagrantu a VirtualBoxu.

Přehled
pfSense – firewall, monitorovaný přes SNMP (šablona PFSense by SNMP)

Zabbix server – Zabbix appliance 7.0 LTS (statická IP 192.168.1.100)

Linux host – Ubuntu 22.04 (jméno ubuntu-...) se Zabbix agentem 2, monitorovaný šablonou Linux by Zabbix agent

Vagrant – automatizace tvorby virtuálních strojů

Požadavky
Vagrant (testováno s verzí 2.4.1)

VirtualBox (testováno s verzí 7.0)

Git (pro správu zdrojových kódů)

Zabbix appliance 7.0 LTS (stažená a importovaná do VirtualBoxu)

1. Příprava prostředí
1.1 Zabbix appliance
Stáhni Zabbix appliance 7.0 LTS (např. OVA) z oficiálních stránek.

Importuj do VirtualBoxu.

Nastav dvě síťová rozhraní:

eth0 – NAT (pro přístup k internetu)

eth1 – Vnitřní síť (Internal network) s názvem intnet

Spusť appliance a přihlas se (uživatel root, heslo zabbix).

Nakonfiguruj statickou IP na eth1:

bash
vi /etc/sysconfig/network-scripts/ifcfg-eth1
Obsah:

text
DEVICE=eth1
TYPE=Ethernet
ONBOOT=yes
BOOTPROTO=none
IPADDR=192.168.1.100
NETMASK=255.255.255.0
Restartuj síť: systemctl restart network

Ověř spojení s pfSense (až bude vytvořena) – ping 192.168.1.1

2. Instalace pfSense pomocí Vagrantu
2.1 Vagrantfile pro pfSense
V adresáři pfSense vytvoř Vagrantfile:

ruby
IMAGE_NAME = "madinasoc2030/pfsense"

Vagrant.configure("2") do |config|
  config.vm.guest = :freebsd
  config.vm.box = IMAGE_NAME
  config.ssh.shell = "sh"
  config.ssh.insert_key = false
  config.vm.synced_folder '.', '/vagrant', disabled: true

  # přístup k webGUI na http://localhost:8888
  config.vm.network :forwarded_port, guest: 80, host: 8888, host_ip: "127.0.0.1"


  # LAN – vnitřní síť intnet
  config.vm.network "private_network",
    auto_config: false,
    virtualbox__intnet: "zabbix

  config.vm.provider "virtualbox" do |vb|
    vb.name = "pfsense-box"
  end
end
2.2 Spuštění a základní nastavení pfSense
bash
cd pfSense
vagrant up
Po naběhnutí se do pfSense dostaneš:

WebGUI: http://localhost:8888 (uživatel admin, heslo pfsense)

SSH: vagrant ssh nebo ssh admin@localhost -p 2222 (heslo vagrant)

Základní nastavení:

Změň heslo admina (doporučeno).

Nastav LAN IP na 192.168.1.1/24 (přes menu nebo web).

Povol SNMP službu: Services → SNMP → Enable → Contact: skolni.email@sposdk.cz (tvůj školní email) → Save.

Nastav pravidla firewallu pro LAN:

Povol ICMP (ping) – pro testování.

Povol UDP 161 (SNMP) – pro Zabbix.

2.3 Zjištění Netgate Device ID
V konzoli pfSense (při přihlášení) je hned v úvodu uvedeno Netgate Device ID: ....
Ulož ho do souboru NetgateID.txt v kořenu projektu:

text
57aedd694474c9c3a678
3. Konfigurace Zabbix serveru a propojení s pfSense
3.1 Ověření SNMP spojení
Na Zabbix appliance nainstaluj SNMP utility:

bash
yum install net-snmp-utils -y
Otestuj:

bash
snmpwalk -v2c -c public 192.168.1.1 system
Měl bys vidět systémové informace včetně sysContact.0 s tvým emailem.

3.2 Uložení výpisu SNMP do souboru
bash
snmpwalk -v2c -c public 192.168.1.1 system > /root/pfsense-box.txt
Tento soubor později zkopíruj do projektu (např. pomocí SCP nebo přes sdílenou složku).

3.3 Vytvoření hostitele v Zabbix
Přihlas se do Zabbix web GUI (http://192.168.1.100/zabbix).

Configuration → Hosts → Create host:

Host name: pfsense-box

Groups: FreeBSD servers (vytvoř)

Interfaces: přidej SNMP interface – IP 192.168.1.1, port 161, verze SNMPv2c, community {$SNMP_COMMUNITY}

Templates: vyber PFSense by SNMP

Macros: přidej {$SNMP_COMMUNITY} = public

Ulož a počkej na zelenou (může to trvat pár minut).

4. Klonování šablony a přidání tagů
4.1 Problém s klonováním – oprava preprocessing kroků
Při klonování šablony PFSense by SNMP může dojít k chybě:

text
Invalid parameter "/1/preprocessing/2/params": value must be empty.
Řešení:
V původní šabloně je třeba "vyčistit" problematické preprocessing kroky. Postup:

Otevři šablonu PFSense by SNMP.

Jdi na Discovery rules → klikni na Network interfaces discovery.

V záložce Item prototypes postupně otevři každý item (je jich 26) a ihned klikni na Update (bez změny). Tím se odstraní "špinavé" parametry.

Teprve poté zkus šablonu Clone (Configuration → Templates → PFSense by SNMP → Clone).

Pojmenuj ji např. PFSense by SNMP-clone.

4.2 Hromadné přidání tagu target: pf
V klonované šabloně:

Jdi na Items.

Vyfiltruj itemy patřící do BEGEMOT-PF-MIB (klíče začínající pfsense.packets, pfsense.state, pfsense.source, pfsense.rules, pfsense.pf atd.).

Označ je všechny (zaškrtni).

Klikni na Mass update.

V sekci Tags vyber Add → Tag: target, Value: pf.

Potvrď.

Stejný postup zopakuj pro Item prototypes v discovery rule (tam jsou itemy pro síťová rozhraní – ty také patří do BEGEMOT-PF-MIB).

4.3 Export klonované šablony
V detailu klonované šablony klikni na Export a ulož jako YAML do adresáře exports (např. exports/pfsense-template-clone.yaml).

5. Instalace Linux hostitele (Ubuntu 22.04) se Zabbix agentem 2
5.1 Vagrantfile pro Ubuntu
V adresáři host vytvoř Vagrantfile:

ruby
IMAGE_NAME = "ubuntu/jammy64"

Vagrant.configure("2") do |config|
  config.ssh.insert_key = false

  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 4
  end

  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = IMAGE_NAME
    ubuntu.vm.network "forwarded_port", guest: 22, host: 2205, host_ip: "127.0.0.1"
    ubuntu.vm.network "forwarded_port", guest: 80, host: 8805, host_ip: "127.0.0.1"
    ubuntu.vm.network "private_network", ip: "192.168.1.5", virtualbox__intnet: "zabbix
    ubuntu.vm.hostname = "hostzbx
  end

  config.vm.provision "shell", path: "install.sh"
  config.vm.provision "shell", path: "configure.sh"
end
5.2 Instalační skript install.sh
bash
#!/bin/bash

sudo apt-get update
sudo apt-get install -y net-tools uuid-runtime wget

# Zabbix repo pro Ubuntu 22.04
sudo wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_7.0-1+ubuntu22.04_all.deb

sudo apt-get update
sudo apt install -y zabbix-agent2

# volitelné pluginy
sudo apt install -y zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

sudo systemctl enable zabbix-agent2
sudo systemctl restart zabbix-agent2
5.3 Konfigurační skript configure.sh
bash
#!/bin/bash

# Vygenerujeme unikátní hostname (např. ubuntu-968c2770)
UNIQUE_HOSTNAME="ubuntu-$(uuidgen)"
SHORT_HOSTNAME=$(echo $UNIQUE_HOSTNAME | cut -d'-' -f1,2)

sudo cp -v /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf-orig

sudo sed -i "s/Hostname=Zabbix server/Hostname=$SHORT_HOSTNAME/g" /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/Server=127.0.0.1/Server=192.168.1.100/g' /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/ServerActive=127.0.0.1/ServerActive=192.168.1.100/g' /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/# Timeout=3/Timeout=30/g' /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/# HostMetadata=/HostMetadata=SPOS/g' /etc/zabbix/zabbix_agent2.conf

# Kontrola změn
sudo diff -u /etc/zabbix/zabbix_agent2.conf-orig /etc/zabbix/zabbix_agent2.conf

sudo systemctl restart zabbix-agent2
5.4 Spuštění a přidání do Zabbixu
bash
cd host
vagrant up
Po dokončení:

Přihlas se do Zabbix web GUI.

Configuration → Hosts → Create host:

Host name: podle výstupu (např. ubuntu-968c2770)

Groups: Linux servers

Agent interface: IP 192.168.1.5, port 10050

Templates: Linux by Zabbix agent

Ulož a ověř data v Monitoring → Latest data.

6. Finální úkoly (odevzdání)
6.1 Soubory k přiložení
pfsense-box.txt – výpis snmpwalk -v2c -c public 192.168.1.1 system

NetgateID.txt – Netgate Device ID (např. 57aedd694474c9c3a678)

Export šablony – exports/pfsense-template-clone.yaml

Screenshoty – do adresáře screenshots:

Grafy pfsense-box

Dashboard pfsense-box

Dashboard Web GUI pfSense

Grafy Linux VM (např. CPU, Memory)




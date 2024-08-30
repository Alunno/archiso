#!/bin/bash

##################################################
################## CONFIGURAÇÃO ##################
##### (Mais tarde no arquivo de configuração) ####
##################################################
RELEASE_VERSION="0.2.0 Private Alpha"

LOADKEY=br-abnt2
LOCAL_MIRROR_COUNTRY='Brazil'
NUMBER_OF_MIRRORS=200
HOSTNAME=myhost
KEYMAP=br-abnt2
FONT=lat9w-16
LANG=pt_BR.UTF-8
declare -a LOCALE=("pt_BR.UTF-8 UTF-8" "pt_BR ISO-8859-1" "pt_BR@real ISO-8859-15" "en_US.UTF-8")
TIMEZONE=/usr/share/zoneinfo/America/Sao_Paulo

logfile="archinstall.log"

##################################
##### Definição das funções ######
##################################

##########################
##### Script Parte 1 #####
##########################

func_prologue() {
	# Você esta pronto?

	read -p "Olá, seja bem vindo a instalação do arch-linux? (Pressione Enter) " ready
	echo "Perfeito!"
	sleep 1
	echo "Vamos começar"
	sleep 1
}

func_loadkeys() {
	# Definir conjunto de caracteres de entrada do teclado

	echo "LoadKeys \"$LOADKEY\" "
	loadkeys $LOADKEY
	#echo "[OK]"
}

func_connect_to_lan() {
	echo "Conexão com a LAN!"
}

func_connect_to_wifi() {
	# Ajuda para conectar ao WIFI Hotspot

	#echo ""
	#echo -n "Scaneando dispositivos de rede..."
	#iwctl
	#listOfDevices=device list	
	#echo " pronto"
	#echo " Seus dispositivos de rede:"
	#echo "$listOfDevices"
	#read -p "Digite o dispositivo de sua escolha: " device
	#iwctl
	echo "Diálogo interativo não foi implementado ainda"
	echo "Abrindo iwctl (Programa de acesso ao WIFI)..."
	echo "HINT: Pressione \"Ajuda\" para mais Instruções"
	iwctl
}

func_internet_connection() {
	# Pergunta se LAN ou WIFI e carrega o módulo específico

	connectWifi="-1"
	read -p "Deseja usar uma conexão LAN ou WIFI? (Digite a escolha) " connection
	case "$connection" in
		LAN|lan|Lan) connectWifi="0"
		;;
		WIFI|wifi|Wifi) connectWifi="1"
		;;
	esac

	if [ $connectWifi == "-1" ]
	then
		echo "Entrada incorreta, escolha LAN"
		func_connect_to_lan
		
	elif [ $connectWifi == "1" ]
	then
		# Conectar por WIFI
		echo "Conectando ao WIFI..."
		func_connect_to_wifi
	else
		func_connect_to_lan
	fi
}

func_check_internet_connection() {
	# Verifica a disponibilidade de uma conexão com a Internet

	echo -n "Verificando IPv4 "
	if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
	  	echo "[OK]"
	else
	  	echo "[ERRO]"
	  	echo "Saindo..."
	  	exit 1
	fi

	echo -n "Verificando Rede "
	if ping -q -c 1 -W 1 google.com >/dev/null; then
	  	echo "[OK]"
	else
	  	echo "[ERRO]"
	  	echo "Saindo..."
	  	exit 1
	fi

	echo -n "Verificando conectividade HTTP "
	case "$(curl -s --max-time 2 -I http://google.com | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in
		[23])	echo "[OK]";;
		5)    	echo "[Proxy esta causando problemas]";;
		*)    	echo "[A rede esta lenta ou sem acesso]"
		   	echo "Saindo..."
		   	exit 1
		   	;;
	esac

	echo "Conexão com a internet estabelecida"
	sleep 1
}

func_release_notes() {
	echo "Olá, seja bem vindo a instalação do arch-linux"
	echo "Versão: $RELEASE_VERSION"
	echo ""
	sleep 1
}

func_partitioning() {
	# Criando Partições, LVM, Formatação, Montagem

	# Variaveis
	deviceRoot=""
	separatehome=0  # 1 se criar o diretório inicial em um dispositivo separado
	separatehomedevice=""
	
	echo ""
	echo "##### PARTICIONANDO #####"
	echo ""
	lsblk
	echo ""
	
	# Definir dispositivo root na entrada
	read -p "Selecione o dispositivo ROOT na saída acima para instalar o sistema base archlinux em (e.g. sda): " deviceRoot
	echo ""

	# Partição home separada?
	#while true; do
    #		read -p "Gostaria de usar um dispositivo separado para o diretorio home? (Esta opção usará toda a memória do dispositivo para a partição inicial. Certifique-se de fazer backup dos seus dados neste dispositivo antes de digitar YES [Y/N] " yn
    #		case $yn in
	#		[Yy]* ) separatehome=1; break;;
	#		[Nn]* ) separatehome=0; break;;
	#		* ) echo "Por favor responda yes ou no.";;
    #		esac
	#done
	
	#if [ $separatehome == 1 ]
	#then
	#	# Defina o dispositivo rais na entrada
	#	lsblk
	#	read -p "Selecione o dispositivo para o diretório home: " separatehomedevice
	#fi
	
	#echo ""
	#echo "!!!CUIDADO!!!"
	#echo "O processo se iniciará em 10 segundos. Este processo criará uma nova tabela de partição GPT no dispositivo selecionado"
	#echo "Pressione Ctrl+C para encerrar"
	#sleep 10
	echo "Criando dispositivo root "
	sgdisk -o /dev/$deviceRoot   # Criando tabela GPT
	sgdisk -n 128:-200M: -t 128:ef00 /dev/$deviceRoot  # Criando EFI / Partição de Boot
	sgdisk -n 1:: -t 1:8e00 /dev/$deviceRoot  # Criando partição linux LVM
	#echo "[OK]"
	
	#if [ $separatehome == 1 ]
	#then
	#	echo -n "Criando dispositivo home..."
	#	sgdisk -o /dev/$separatehomedevice  # Criando tabela GPT
	#	sgdisk -n 1:: /dev/$separatehomedevice  # Criando partição Linux ext4
	#	echo " done"
	#	echo ""
	#fi
	
	### Criando dispositivo encriptado ###
	echo "Configure a criptografia da partição em \"/dev/${deviceRoot}1\""
	echo "Digite a senha para a partição root:"
	cryptsetup luksFormat /dev/${deviceRoot}1 
	
	echo "Digite a senha que você definiu para sua partição root:"
	cryptsetup open /dev/${deviceRoot}1 cryptlvm 

	echo "Configurar o volume do grupo"
	
	#echo -n "Criar um volume fisico"
	pvcreate /dev/mapper/cryptlvm 
	#echo " done"
	
	#echo -n "Criar um volume de grupo"
	vgcreate vg1 /dev/mapper/cryptlvm 
	#echo " feito"
	
	#echo "[OK]"

	# SWAP
	read -p "Quanto de memoria swap deseja usar? (em GB) " swapspace
	echo "Criando membro do crupo "
	lvcreate -L ${swapspace}G vg1 -n swap 
	lvcreate -l 100%FREE vg1 -n root 
	#echo "[OK]"
	
	### Formatando partições ###
	echo "Formatando partições "
	mkfs.fat -F32 /dev/sda128 
	mkfs.ext4 /dev/vg1/root 
	mkswap /dev/vg1/swap 
	
	#if [ $separatehome == 1 ]
	#then
	#	mkfs.ext4 /dev/${separatehomedevice}1
	#fi
	
	#echo "[OK]"
	
	### Montando partições ###
	echo "Montando partições "
	mount /dev/vg1/root /mnt 
	mkdir /mnt/home 
	#if [ $separatehome == 1 ]
	#then
	#	mount /dev/${separatehomedevice}1 /mnt/home
	#fi
	mkdir /mnt/boot 
	mount /dev/${deviceRoot}128 /mnt/boot 
	swapon /dev/vg1/swap 
	#echo "[OK]"
}

func_gen_mirror_list() {
	echo "Gerando $NUMBER_OF_MIRRORS Entrada de listas espelho:"
	#reflector --verbose --country $LOCAL_MIRROR_COUNTRY -l $NUMBER_OF_MIRRORS -p https --sort rate --save /etc/pacman.d/mirrorlist 
}

func_install_base() {
	echo "Instalando o sistema base "
	pacstrap /mnt base base-devel zsh linux linux-headers linux-firmware nano dhcpcd lvm2 reflector git
}

func_config_archlinux() {
	echo "Configurar ArchLinux "
	
	# Nome do dispositivo
	echo $HOSTNAME > /mnt/etc/hostname
	 
	# Layout do teclado
	echo KEYMAP=$KEYMAP > /mnt/etc/vconsole.conf  

	# Fonte (opcional)
	echo FONT=$FONT >> /mnt/etc/vconsole.conf  

	# Regis̃o
	echo LANG=$LANG > /mnt/etc/locale.conf  # Idioma
	
	# nano /etc/locale.gen
	# -> descomente isso:
	#pt_BR.UTF-8 UTF-8
	#pt_BR ISO-8859-1
	#pt_BR@euro ISO-8859-15
	#en_US.UTF-8
	for lang in ${LOCALE[@]}
	do
		match="#${lang}"
		insert="$lang"
		file="/mnt/etc/locale.gen"
		sed -i "s/$match/$insert/" $file
	done

	#echo "[OK]"

	echo "Gerando arquivo FSTAB "
	# Gerando fstab
	genfstab -U /mnt >> /mnt/etc/fstab  # (altere -U para -L para usar label em vez de UUID
	
	#echo "[OK]"
	
	cat /mnt/etc/fstab   # verificando

	#read -p "(Precione enter para continuar) " pronto.
	
	#while true; do
    #		read -p "Você deseja editar o arquivo fstab (y/n)? " yn
	#    	case $yn in
	#		[Yy]* ) nano /mnt/etc/fstab; break;;
	#		[Nn]* ) break;;
	#		* ) echo "Por favor responda yes ou no.";;
	#    	esac
	#done
	echo "Editar arquivo hosts "
	echo "127.0.0.1		localhost.localdomain	localhost" >> /mnt/etc/hosts
	echo "::1		localhost.localdomain	localhost" >> /mnt/etc/hosts
	echo "127.0.0.1		$hostname.localdomain	$hostname" >> /mnt/etc/hosts
	#echo "[OK]"
}

func_script_part1() {
	echo "Bem-vindo ao instalador do arch-linux"
	sleep 1

	### Prólogo ###
	#func_prologue

	### LoadKeys ###
	func_loadkeys

	### CONEXÃO COM INTERNET ###
	#func_internet_connection

	### verificar conexão com a internet ###
	func_check_internet_connection

	### Notas ###
	func_release_notes

	### Atualizando banco de dados ###
	pacman -Syyy 

	### Preconfig ###
	export EDITOR=nano

	### Particionando ###
	func_partitioning

	### Gerar lista de espelhos ###
	func_gen_mirror_list

	### Instalar pacotes base ###
	func_install_base
	
	### Config Arch Linux ###
	func_config_archlinux

	### Copie o script para o diretório raiz na instalação do ArchLinux
	cp -v $0 /mnt/install-archlinux.sh
	echo "${deviceRoot}" >> /mnt/device.info
	# Pendência -> Copie outros arquivos importantes/urgentes
	
	### ALterar diretório root (Arch-ChRoot) ### Pendência
	echo "Mudando para ArchLinux Root e continuando o script (em 3 Segundos)"
	sleep 3
	arch-chroot /mnt ./install-archlinux.sh continue

	echo $(pwd)
	if [ -f install-archlinux.sh ]
    then
        echo 'ERRO: Algo falhou dentro do chroot, desmontando os sistemas de arquivos para que você possa investigar.'
        echo 'Certifique-se de desmontar tudo antes de tentar executar este script novamente.'
    else
        echo 'Desmontando sistema de arquivos'
        func_reboot_arch
        echo 'Feito! Reinicie o sistema.'
    fi
	}

#########################
##### Script Part 2 #####
#########################

func_post_arch_chroot_config() {
	echo "Pós-configuração no Arch-Chroot "
	# Gerando Locale
	locale-gen 
	
	# Modificar localtime
	ln -sf $TIMEZONE /etc/localtime   # Alterar fuzo hórario
	hwclock --systohc --utc  # Sincronizar relógio do Hardware
	
	#echo "[OK]"

	# Definir senha do root
	echo "Defina sua senha de root"
	passwd root
	
	# Gerenciar lista de espelhos do sistema archlinux
	echo "Gerando $NUMBER_OF_MIRRORS Entrada de lista de espelho: "
	reflector --verbose --country $LOCAL_MIRROR_COUNTRY -l $NUMBER_OF_MIRRORS -p https --sort rate --save /etc/pacman.d/mirrorlist

	# Manipular MKINICPIO - Pendênte - Ponto crítico durante uma atualização ISO, fique de OLHO ao testar
	echo "Editar Mkinitcpio "
	match="bloquear sistema de arquivos"
	insert="bloquear sistema de arquivos lvm2 encriptado"
	file="/etc/mkinitcpio.conf"
	sed -i "s/$match/$insert/" $file
	#echo "[OK]"
	echo "Gerando Mkinitcpio "
	mkinitcpio -p linux
	
	### GRUB ###
	echo "Configurando GRUB Bootloader "
	pacman -Sy --noconfirm grub efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
	
	rootdevice=$(cat device.info)
	echo "${rootdevice}"

	echo "Editar arquivo padrão do grub "
	sed -i "s/loglevel=3 quiet/cryptdevice=\/dev\/${rootdevice}1:cryptlvm:allow-discards loglevel=3/" /etc/default/grub
	sed -i "s/#GRUB_ENABLE_CRYPTODISK=\"y\"/GRUB_ENABLE_CRYPTODISK=\"y\"/" /etc/default/grub
	
	#echo " feito"

	# (Pendência) O mesmo acontece com outras seções padrão do grub
	
	grub-mkconfig -o /boot/grub/grub.cfg  # Gerando arquivo de configuração do grub
	
	echo ""
	echo "SISTEMA BASE instalado e CONFIGURAÇÃO BASE concluida"
	echo ""
}

func_setup_arch_linux_root() {
	echo "func_setup_arch_linux_root (Pendência)" # Pendência
}

func_leave_arch_chroot() {
	exit
}

func_reboot_arch() {
	umount /mnt/boot 
	umount /mnt
	swapoff /dev/vg1/swap  
	vgchange -an
	cryptsetup luksClose cryptlvm

	reboot
}

func_script_part2() {
	echo "#####################################################"
	echo "#  Sistema base Arch Linux- Arch-ChRoot Pós-Script #"
	echo "#####################################################"
	echo ""
	# Gerar configuração de chroot pós-script arch-linux
	func_post_arch_chroot_config
	
	func_setup_arch_linux_root

	func_leave_arch_chroot
}

#set -ex

#########################
##### Metodo Main ######
#########################
script_part="$1"

if [ $script_part == "continuar" ]
then
	func_script_part2
else
	func_script_part1
fi
	
install_packer() {
    mkdir /foo
    cd /foo
    curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz | tar xzf -
    cd yay
    makepkg -si --noconfirm --asroot

    cd /
    rm -rf /foo
}
create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -s /bin/zsh -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power,adbusers,wireshark "$name"
    echo -en "$password\n$password" | passwd "$name"
}

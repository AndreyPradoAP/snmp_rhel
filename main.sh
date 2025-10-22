#!/bin/bash

# Precisa criar verificação de senhas na função create_user_snmpd()

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens coloridas
print_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
	echo -e "${RED}[ERRO]${NC} $1"
}

# Verificar se o script está sendo executado como root
check_root() {
	if [[ $EUID -ne 0 ]]; then # O valor do EUID do root é sempre 0
		print_error "Este script deve ser executado como root!"
		exit 1
	fi
}

update_system() {
	print_info "Iniciando atualização do sistema..."
	
	if dnf update -y; then
		print_success "Sistema atualizado com sucesso!"
	else
		print_error "Falha ao atualizar o sistema!"
		return 1
	fi
}

download_snmpd() {
	print_info "Iniciando instalação do net-snmp e dependências..."

	if dnf install net-snmp net-snmp-utils -y; then
		print_success "Pacotes instalados com sucesso!"
	else
		print_error "Falha ao instalar pacotes!"
		return 1
	fi
}

# Configuração do Usuário SNMP
create_user_snmpd() {
	# Verificar se snmpd está ativo
	if systemctl is-active --quiet snmpd; then
		print_info "Desativando snmpd..."
		systemctl stop snmpd
	fi

	# Input e validação do nome do usuário snmpd
	while true; do
		read -p "Digite o nome do usuário SNMPD (Deve ser o mesmo configurado no snmp-exporter): " user_snmp


		# Testa se a variável está vazia
		if ! [[ -z "$user_snmp" ]]; then
			break
		fi
	
		print_error "Usuário não pode ser vazio! Digite novamente!"
	done

	local password_auth
	read -sp "Digite a senha de autenticação do usuário snmpd: " password_auth
	echo ""
	local password_cript
	read -sp "Digite a senha de criptografia SNMPD: " password_cript

	if net-snmp-create-v3-user -ro -a SHA -A $password_auth -x AES -X $password_cript $user_snmp; then
		print_success "Usuário snmpd criado com sucesso!"
	else
		print_error "Falha criar o usuário"
		return 1
	fi
}

create_agent_snmp() {
	TARGET_FOLDER="/etc/snmp"
	TARGET_FILE="/etc/snmp/snmpd.conf"

	# Verifico se o arquivo existe
	# Se existe, crio um backup
	# Se não, crio o arquivo
	if [ -f "$TARGET_FILE" ]; then
		cp "$TARGET_FILE" "${TARGET_FILE}.bkp"
	else
		print_warning "Arquivo $TARGET_FILE não existe"
		echo ""
		print_info "Criando arquivo..."

		mkdir -p $TARGET_FOLDER && touch $TARGET_FILE
	fi

	# Adicionando configuração do agent snmp
	print_info "Alterando o arquivo "$TARGET_FILE"..."
	cat > "$TARGET_FILE" <<-EOF
		view   all         included   .1
		group  grupoV3      usm        $user_snmp
		access grupoV3 ""   usm        priv exact  all none none
	EOF

	print_info "Inciando o serviço snmpd..."
	systemctl start snmpd
	systemctl enable snmpd

	print_success "Snmpd configurado com sucesso!"
}


# Início do script
check_root
main_menu
update_system
download_snmpd
create_user_snmpd
create_agent_snmp

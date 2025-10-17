#!/bin/bash

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

    if dnf sudo dnf install net-snmp net-snmp-utils net-snmp-devel -y; then
        print_success "Pacotes instalados com sucesso!"
    else
        print_error "Falha ao instalar pacotes!"
        return 1
    fi
}

config_snmpd() {
    # Verificar se snmpd está ativo
    if systemctl is-active --quiet snmpd; then
        print_info "Desativando snmpd..."
        systemctl stop snmpd
    fi

    # Input e validação do nome do usuário snmpd
    while true; do
        read -p "Digite o nome do usuário SNMPD (Deve ser o mesmo configurado no snmp-exporter): " user_snmp

        if ! [[ -z "$user_snmp" ]]; then
            break
        fi

        print_error "Usuário não pode ser vazio! Digite novamente!"
    done
    

    read -sp "Digite a senha de autenticação do usuário snmpd: " password_auth

    read -sp "Digite a senha de criptografia SNMPD: " password_cript

    if net-snmp-create-v3-user -ro -a SHA -A $password_auth -x AES -X $password_cript $user_snmp; then
        print_success "Usuário snmpd criado com sucesso!"
    else
        print_error "Falha criar o usuário"
        return 1
    fi

    
}


# Início do script
check_root
main_menu
update_system

#!/bin/bash

# autor: Ricardo Ferreira
# Github - https://github.com/ricardoferreiracosta08/  
# Blog - http://ricardoferreira.site 
# data da criacao: 2021-01-04
#
# https://stato.bln.br/wordpress/backup-diferencial-e-incremental-com-tar/
# https://www.nanoshots.com.br/2015/11/criando-rotinas-de-backup-full-e.html
#
# TO DO:
# -------
# Retenção
# Envio de e-mails
# Monitorar arquivo .monitor
# Filtro de entrada na restauração do usuário
# Caso não seja íntegro o BACKUP é preciso agir
# --------

#### VARIAVEIS ###########################################################

remote_ssh="192.168.122.69"
port_ssh="22"
user_ssh="root"
dir_backup_ssh="/mnt/backups"
dir_restore_ssh="/home/ricardo"

PASTAS_BACKUP="pastasbackup.txt"	#diretorios para backup
LOCAL_BACKUP="backups"		# destino para backup
LOG="$LOCAL_BACKUP/log"

PRESERVAR_BACKUP_LOCAL=1       # garantir cópia local de backup (1|0) [recomendado]

#email=""         # email de destino do relatorio
#nb="7"                                    # numero maximo de arquivos de backup a serem mantidos
#_mail=/usr/bin/mail                     # caminho para comando mail

#### CONSTANTES ###########################################################
#### NÃO MUDAR ###############################

#DIA DA SEMANA 0 -7
DIA=`date +%w.%H-%M-%S` #NUMBER_DAY + HOUR + MINUTE + SECONDs

#Arquivo oculto de controle INCREMENTAL do TAR
CONTROLE_INCREMENTAL=".incremental"

#ARQUIVO OCULTO DE BASE PARA O FIND 
CONTROLE_DIFERENCIAL=".diferencial"

ARQUIVOS_DIFERENCIAL=".listadiferencial"

monitor_file=".monitor" #monitoramento
echo -e "FAIL" | tee $monitor_file 1>>/dev/null #monitoramento

#be="template0|template1|postgres"   # bancos que nao vao entrar no backup

nw=$(date +%d%m%Y.%H%M%S)               # variavel de hora
ln="$LOG/$1.$nw.eventos.log"            # formato do arquivo de ln
lb="$LOG/$1.$nw.backup.log"            # formato do arquivo de ln

###
########## PRÉ-EXECUÇÃO #######################################
###

### Verifica se é usuario root ###################################
#if [ $(id -u) != "0" ];then
#        echo -e "Erro: este script precisa ser executado com usuario root..." | tee -a $ln
#        exit 1
#fi

### verifica se o mailx esta instalado ####################################

#if [ ! -x $_mail ];then
#        echo "\nErro: Este script não conseguiu encontrar o comando mail"
#        exit 1
#fi

### verificando se existe o arquivo com os locais para backups #############################

        if [ ! -f $PASTAS_BACKUP ]; then
                echo -e "\nErro: o arquivo de locais do backup não existe!" | tee -a $ln
		exit 1
        fi

### verificando se existe o diretorio para armazenar os backups #############################

        if [ ! -d $LOCAL_BACKUP ]; then
                echo -e "\nErro: o diretorio de destino do backup não existe!" | tee -a $ln
		echo -e "\nAção: criar diretório!" | tee -a $ln
                mkdir $LOCAL_BACKUP
        fi

### verificando se existe o diretorio para armazenar os LOGs #############################

        if [ ! -d $LOG ]; then
                echo -e "\nErro: o diretorio de destino dos logs não existe!" | tee -a $ln
		echo -e "\nAção: criar diretório!" | tee -a $ln
		mkdir $LOG
        fi

### verificando se servidor remoto está ativo #############################

        nc -z $remote_ssh $port_ssh > /dev/null  # netcat

        if [ ! $? -eq 0 ]; then
                echo -e "\nErro: Servidor remoto está DOWN!" | tee -a $ln
                exit 1
        fi

### SCRIPT ##########################################################

completo()
{
 echo -e "\nBACKUP iniciado em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln
 echo -e "------------------------------------------------------------------------\n" | tee -a $ln

 if [ -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
    date_backup_old=$(stat --printf=%y $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{print $1}')
    #    mv $LOCAL_BACKUP/backupcompleto.tar.gz $LOCAL_BACKUP/backupcompleto.tar.gz.old.$date_backup_old | tee -a $ln

    rm -f $LOCAL_BACKUP/*
    ssh $user_ssh@$remote_ssh 'rm -f '$dir_backup_ssh'/*'

    echo -e "Backup COMPLETO $date_backup_old removido ........................ OK" | tee -a $ln
 fi

 echo -e "Tipo Backup .................................. COMPLETO" | tee -a $ln

 echo -e "\nLOG BACKUP COMPLETO $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $lb
 echo -e "------------------------------------------------------------------------\n" | tee -a $lb
 rm -f $CONTROLE_INCREMENTAL #sempre remover para manter o último incremental

 echo -e "Backup em execução .................................. " | tee -a $ln

 if tar -czvf $LOCAL_BACKUP/backupcompleto.tar.gz -T $PASTAS_BACKUP -g $CONTROLE_INCREMENTAL | tee -a $lb
 then
  echo -e "OK" | tee $monitor_file 
  touch -t `date +%Y%m%d%H%M` $CONTROLE_DIFERENCIAL
    
  echo -e "Backup COMPLETO .................................. OK" | tee -a $ln
  
  echo -e "Enviando backup .................................. " | tee -a $ln
  echo -e "------------------------------------------------- " | tee -a $lb
  rsync -avz -e ssh $LOCAL_BACKUP/backupcompleto.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh | tee -a $lb
  echo -e "Backup COMPLETO enviado .......................... OK" | tee -a $ln

  echo -e "Verificando INTEGRIDADE Backup ....................................... " | tee -a $ln
  checksum_integridade_local=$(sha256sum $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{ print $1 }')
  checksum_integridade_remoto=$(ssh $user_ssh@$remote_ssh 'sha256sum '$dir_backup_ssh'/backupcompleto.tar.gz')
  checksum_integridade_remoto=$(echo $checksum_integridade_remoto | awk '{ print $1 }')

  if [ $checksum_integridade_local == $checksum_integridade_remoto ]; then
   echo -e "INTEGRIDADE Backup ....................................... OK" | tee -a $ln
  else
   echo "q" 
  fi

  if [ ! $PRESERVAR_BACKUP_LOCAL -eq 1 ]; then
    rm -f $LOCAL_BACKUP/backupcompleto.tar.gz
  fi

  echo -e "\n------------------------------------------------------------------------" | tee -a $ln
  echo -e "BACKUP concluído em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln | tee -a $lb
 else
  echo -e "\nErro: durante compactação" | tee -a $ln
  echo -e "Backup COMPLETO .................................. FALHOU" | tee -a $ln
  echo -e "FAIL" | tee $monitor_file
  exit 1
 fi

}

diferencial()
{
 echo -e "\nBACKUP iniciado em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln
 echo -e "------------------------------------------------------------------------\n" | tee -a $ln

 if [ ! -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
   echo -e "[Erro] Não existe Backup COMPLETO .................................. " | tee -a $ln
   exit 1
 fi

 echo -e "Tipo Backup .................................. DIFERENCIAL" | tee -a $ln

 echo -e "\nLOG BACKUP DIFERENCIAL $(date +%d/%m/%Y.%H:%M:%S) " | tee -a $lb
 echo -e "------------------------------------------------------------------------\n\n" | tee -a $lb

 # procura os arquivos que mudaram do último backup completo e joga numa arquivo lista
 find `cat $PASTAS_BACKUP` \( -cnewer $CONTROLE_DIFERENCIAL -a  ! -type d \) > $ARQUIVOS_DIFERENCIAL
  
 if tar -czvf $LOCAL_BACKUP/backup.dif$DIA.tar.gz -T $ARQUIVOS_DIFERENCIAL | tee -a $lb
 then
  echo -e "OK" | tee $monitor_file 
  echo -e "Backup DIFERENCIAL .................................. OK" | tee -a $ln

#  checksum_integridade=$(sha256sum $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{ print $1 }')
  echo -e "Enviando backup .................................. " | tee -a $ln
  echo -e "------------------------------------------------- " | tee -a $lb
  rsync -avz -e ssh $LOCAL_BACKUP/backup.dif$DIA.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh | tee -a $lb
  echo -e "Backup DIFERENCIAL enviado .......................... OK" | tee -a $ln

  echo -e "Verificando INTEGRIDADE Backup ....................................... " | tee -a $ln
  checksum_integridade_local=$(sha256sum $LOCAL_BACKUP/backup.dif$DIA.tar.gz | awk '{ print $1 }')
  checksum_integridade_remoto=$(ssh $user_ssh@$remote_ssh 'sha256sum '$dir_backup_ssh'/backup.dif'$DIA'.tar.gz')
  checksum_integridade_remoto=$(echo $checksum_integridade_remoto | awk '{ print $1 }')

  if [ $checksum_integridade_local == $checksum_integridade_remoto ]; then
   echo -e "INTEGRIDADE Backup ....................................... OK" | tee -a $ln
  else
   echo "q" 
  fi

  if [ ! $PRESERVAR_BACKUP_LOCAL -eq 1 ]; then
    rm -f $LOCAL_BACKUP/backup.dif$DIA.tar.gz
  fi

  echo -e "\n------------------------------------------------------------------------" | tee -a $ln
  echo -e "BACKUP concluído em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln | tee -a $lb
 else
  echo -e "\nErro: durante compactação" | tee -a $ln
  echo -e "Backup DIFERENCIAL .................................. FALHOU" | tee -a $ln
  echo -e "FAIL" | tee $monitor_file
  exit 1
 fi

}

incremental()
{
 echo -e "\nBACKUP iniciado em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln
 echo -e "------------------------------------------------------------------------\n" | tee -a $ln

 if [ ! -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
   echo -e "[Erro] Não existe Backup COMPLETO .................................. " | tee -a $ln
   exit 1
 fi

 echo -e "Tipo Backup .................................. INCREMENTAL" | tee -a $ln

 echo -e "\nLOG BACKUP INCREMENTAL $(date +%d/%m/%Y.%H:%M:%S) " | tee -a $lb
 echo -e "------------------------------------------------------------------------\n\n" | tee -a $lb

 if tar -czvf $LOCAL_BACKUP/backup.inc$DIA.tar.gz -T $PASTAS_BACKUP -g $CONTROLE_INCREMENTAL | tee -a $lb
 then
  echo -e "OK" | tee $monitor_file 
  echo -e "Backup INCREMENTAL .................................. OK" | tee -a $ln

#  checksum_integridade=$(sha256sum $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{ print $1 }')
  echo -e "Enviando backup .................................. " | tee -a $ln
  echo -e "------------------------------------------------- " | tee -a $lb
  rsync -avz -e ssh $LOCAL_BACKUP/backup.inc$DIA.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh | tee -a $lb
  echo -e "Backup INCREMENTAL enviado .......................... OK" | tee -a $ln

  echo -e "Verificando INTEGRIDADE Backup ....................................... " | tee -a $ln
  checksum_integridade_local=$(sha256sum $LOCAL_BACKUP/backup.inc$DIA.tar.gz | awk '{ print $1 }')
  checksum_integridade_remoto=$(ssh $user_ssh@$remote_ssh 'sha256sum '$dir_backup_ssh'/backup.inc'$DIA'.tar.gz')
  checksum_integridade_remoto=$(echo $checksum_integridade_remoto | awk '{ print $1 }')

  if [ $checksum_integridade_local == $checksum_integridade_remoto ]; then
   echo -e "INTEGRIDADE Backup ....................................... OK" | tee -a $ln
  else
   echo "q" 
  fi

  if [ ! $PRESERVAR_BACKUP_LOCAL -eq 1 ]; then
    rm -f $LOCAL_BACKUP/backup.inc$DIA.tar.gz
  fi

  echo -e "\n------------------------------------------------------------------------" | tee -a $ln
  echo -e "BACKUP concluído em $(date +%d/%m/%Y.%H:%M:%S)" | tee -a $ln | tee -a $lb
 else
  echo -e "\nErro: durante compactação" | tee -a $ln
  echo -e "Backup INCREMENTAL .................................. FALHOU" | tee -a $ln
  echo -e "FAIL" | tee $monitor_file
  exit 1
 fi
}

recuperar()
{
  echo -e "Backups disponíveis:"
  echo -e "---------------------------------"
  array=($(ssh $user_ssh@$remote_ssh 'ls '$dir_backup_ssh'' ))
  for key in "${!array[@]}"
  do
    echo -e "$key) ${array[$key]}"
  done

  echo -e "----------------------------------"  
  echo -e "Escolha uma opção:"
  read opcao
  clear
  echo -e "----------------------------------"
  echo -e "Restauração: \n ${array[$opcao]} \n ${array[0]}"
  echo -e "----------------------------------"
  echo -e "Confirma? [s|N]"
  read confirma
  case $confirma in
   s) ssh $user_ssh@$remote_ssh 'cat '$dir_backup_ssh'/'${array[$opcao]}' '$dir_backup_ssh'/'${array[0]}' | tar --keep-newer-files -xvzf - -C '$dir_restore_ssh' -i' ;;
   S) ssh $user_ssh@$remote_ssh 'cat '$dir_backup_ssh'/'${array[$opcao]}' '$dir_backup_ssh'/'${array[0]}' | tar --keep-newer-files -xvzf - -C '$dir_restore_ssh' -i' ;;
   *) exit 0;;
  esac

#cat teste*.tar.gz | tar --keep-newer-files -xvf - -C /home/ricardo/backups -i
}

case $1 in
completo) completo ;;
diferencial) diferencial ;;
incremental) incremental ;;
recuperar) recuperar ;;
*) exit 1 ;;
esac

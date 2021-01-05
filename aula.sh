#!/bin/bash

remote_ssh="192.168.122.69"
port_ssh="22"
user_ssh="root"
dir_backup_ssh="/mnt/backups"
dir_restore_ssh="/home/ricardo"

PASTAS_BACKUP="pastasbackup.txt"	#diretorios para backup
LOCAL_BACKUP="backups"		# destino para backup
LOG="$LOCAL_BACKUP/log"

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

nw=$(date +%d%m%Y.%H%M%S)               # variavel de hora

### SCRIPT ##########################################################

completo()
{
 
 if [ -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
    date_backup_old=$(stat --printf=%y $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{print $1}')
  
    rm -f $LOCAL_BACKUP/*
    ssh $user_ssh@$remote_ssh 'rm -f '$dir_backup_ssh'/*'

 fi

 rm -f $CONTROLE_INCREMENTAL #sempre remover para manter o último incremental

 if tar -czvf $LOCAL_BACKUP/backupcompleto.tar.gz -T $PASTAS_BACKUP -g $CONTROLE_INCREMENTAL 
 then
  echo -e "OK" | tee $monitor_file 
  touch -t `date +%Y%m%d%H%M` $CONTROLE_DIFERENCIAL
   
  rsync -avz -e ssh $LOCAL_BACKUP/backupcompleto.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh 
  
  checksum_integridade_local=$(sha256sum $LOCAL_BACKUP/backupcompleto.tar.gz | awk '{ print $1 }')
  checksum_integridade_remoto=$(ssh $user_ssh@$remote_ssh 'sha256sum '$dir_backup_ssh'/backupcompleto.tar.gz')
  checksum_integridade_remoto=$(echo $checksum_integridade_remoto | awk '{ print $1 }')

  if [ $checksum_integridade_local == $checksum_integridade_remoto ]; then
   echo -e "INTEGRIDADE Backup ....................................... OK"
  else
   echo "TO DO" 
  fi

 else
  echo -e "FAIL" | tee $monitor_file
  exit 1
 fi

}

diferencial()
{
 
 if [ ! -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
   echo -e "[Erro] Não existe Backup COMPLETO .................................. " 
   exit 1
 fi

 # procura os arquivos que mudaram do último backup completo e joga numa arquivo lista
 find `cat $PASTAS_BACKUP` \( -cnewer $CONTROLE_DIFERENCIAL -a  ! -type d \) > $ARQUIVOS_DIFERENCIAL
  
 if tar -czvf $LOCAL_BACKUP/backup.dif$DIA.tar.gz -T $ARQUIVOS_DIFERENCIAL 
 then
  echo -e "OK" | tee $monitor_file 
  
  rsync -avz -e ssh $LOCAL_BACKUP/backup.dif$DIA.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh 
  
 else
  echo -e "\nErro: durante compactação" 
  echo -e "FAIL" | tee $monitor_file
  exit 1
 fi

}

incremental()
{
 
 if [ ! -f "$LOCAL_BACKUP/backupcompleto.tar.gz" ]; then
   echo -e "[Erro] Não existe Backup COMPLETO .................................. " 
   exit 1
 fi


 if tar -czvf $LOCAL_BACKUP/backup.inc$DIA.tar.gz -T $PASTAS_BACKUP -g $CONTROLE_INCREMENTAL 
 then
  echo -e "OK" | tee $monitor_file 
  rsync -avz -e ssh $LOCAL_BACKUP/backup.inc$DIA.tar.gz $user_ssh@$remote_ssh:$dir_backup_ssh 
 
 else
  echo -e "\nErro: durante compactação" 
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
}

case $1 in
completo) completo ;;
diferencial) diferencial ;;
incremental) incremental ;;
recuperar) recuperar ;;
*) exit 1 ;;
esac

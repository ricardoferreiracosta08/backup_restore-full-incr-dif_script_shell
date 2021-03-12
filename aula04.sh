#!/bin/bash


date=$(date +%d%m%Y-%H%M%S)

PASTAS_BACKUP="/root/pastasbackup"
LOCAL_BACKUP="/root/backups/"
LOCAL_RESTORE="/root/restore/"
NOME_ARQUIVO="backup-$date.tar.gz"
PATH_BACKUP=$LOCAL_BACKUP$NOME_ARQUIVO
MONITOR_FILE="/root/monitor"

if [ ! -d $LOCAL_BACKUP ]
then
   mkdir $LOCAL_BACKUP 
fi

if [ ! -d $LOCAL_RESTORE ]
then
   mkdir $LOCAL_RESTORE 
fi


completo()
{
   if tar -czvf $PATH_BACKUP -T $PASTAS_BACKUP 
   then
     echo "OK" | tee $MONITOR_FILE
   else
     echo "ERRO" | tee  $MONITOR_FILE
     exit 1
   fi
}

menu_recuperar()
{
   clear
   backup=$(ls $LOCAL_BACKUP)
   echo -e "----------------------"
   echo -e "Backup disponível: \n $backup \n\n"
   echo -e "----------------------"
   echo -e "Confirma? [s|N]"
   read confirma

   case $confirma in
      s|S) recuperar $LOCAL_BACKUP$backup $LOCAL_RESTORE ;;
      *) exit 0 ;;
   esac   
}

recuperar() 
{
   backup_recupera=$1
   destino=$2

   if ! tar -xzf $backup_recupera -C $destino  
   then
     exit 1
   fi
}

case $1 in
completo) completo ;;
recuperacao) menu_recuperar ;;
recuperar) recuperar $2 $3 ;;
*) echo "ERROOOOUUUUU" ;;
esac

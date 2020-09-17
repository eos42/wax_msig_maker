#!/bin/bash

source config.sh

unlocked_wallets=$( (cleos wallet list | grep \* | wc -l) 2>&1)
unlocked_wallets=$(( unlocked_wallets+0 ))

url=https://api.eos42.io:7884

proposal_name=$1
account_name=$2
description=$3

function send_telegram_message(){
  chat_id=$1
  users=$2
  curl -X POST -H 'Content-Type: application/json' -d "{\"chat_id\":\"$chat_id\",\"text\":\"MSIG requested: https://wax.bloks.io/msig/$account_name/$proposal_name with transaction ID $transaction_id\n\nThe purpose of the MSIG is: $description\n\n$users\",\"parse_mode\":\"HTML\"}" https://api.telegram.org/bot$url_msig_telegram_bot_api/sendMessage
}

if [[ $unlocked_wallets < 1 ]]
then
  echo "Please unlock your wallet first"
  exit 4
fi

if [[ $# -lt 1 ]]
then
  echo "Must specify at least one transaction json"
  exit 2
fi

telegram_users=""

for i in "$@"
do
  if [[ $i == "-h" || $i == "--help" ]]
  then
    echo "How to use the MSIG maker"
    echo "Type ./msig-maker PROPOSAL-NAME ACCOUNT-NAME MSIG-DESCRIPTION TRANSACTIONS..."
    echo
    echo "For example:"
    echo "./msig-maker mymsig phillhamnett \"This MSIG sends money to account X\" transaction1.json transaction2.json"
    echo 
    echo "To generate transactions, create them how you normally would with cleos, and append with \"-s -d -j > transactionX.json\""
    echo
    echo "Example:"
    echo "cleos -u https://api.eos42.io:7884 transfer eos42freedom phillhamnett \"0.0001 EOS\" \"my memo\" -p eos42freedom@active -s -d -j > transaction1.json"
    exit 3
  fi

  # Check to make sure that the authorizations of the MSIG are consistent
  if [[ $i == $1 || $i == $2 || $i == $3 ]]
  then 
    continue
  fi
  if [[ $i == $4 ]]
  then
    final_actor=$( (cat $i | jq -r .actions[0].authorization[0].actor) 2>&1)
    final_permission=$( (cat $i | jq -r .actions[0].authorization[0].permission) 2>&1)
    cat $i | jq . > msig_transaction.json
  else
    tmp_final_actor=$( (cat $i | jq -r .actions[0].authorization[0].actor) 2>&1)
    tmp_final_permission=$( (cat $i | jq -r .actions[0].authorization[0].permission) 2>&1)
    if [[ $tmp_final_actor != $final_actor || $tmp_final_permission != $final_permission ]]
    then
      echo "The permissions for the MSIG must be the same on all transactions involved in the MSIG. You can't push something that requires $tmp_final_actor@$tmp_final_permission and $final_actor@$final_permission in the same MSIG"
      exit 1
    fi

    action=$( (cat $i | jq .actions) 2>&1 )
    cat msig_transaction.json | jq ".actions += $action" | jq . > msig_transaction2.json
    cp msig_transaction2.json msig_transaction.json
  fi
done

expiration="$(date -d "+1 year" +%Y-%m-%dT12:00:00)"
cat msig_transaction.json | jq ".expiration = \"$expiration\"" | jq . > msig_transaction2.json
cp msig_transaction2.json msig_transaction.json

# Create the permissions json
cat msig_transaction.json
cleos -u $url get account $final_actor -j | jq '[.permissions[] | select(.perm_name == "'$final_permission'") | .required_auth.accounts[] | select(.permission.permission != "eosio.code") | .permission]' | jq . > permissions.json
cat permissions.json
all_actors=$( (cat permissions.json | grep actor | cut -d'"' -f 4) 2>& 1)
echo $all_actors
declare -a actors

if [[ $all_actors == "eosio.prods" ]]
then
  actors=($(cleos -u $url system listproducers -l 30 -j | jq -r .rows[].owner))
else
  actors=($all_actors)
fi

echo ${actors[@]}

echo Permissions are
cat permissions.json

result=$( (cleos -u $url multisig propose_trx $proposal_name permissions.json msig_transaction.json $account_name) 2>&1)

if [[ $? -ne 0 ]]
then
  echo $result
  exit 1
fi

transaction_id=$( (echo $result | grep "executed transaction" |  cut -s -d' ' -f 3) 2>&1)

declare -a users

for i in ${actors[@]}
do
  for j in ${!telegram_users[@]}
  do
    if [[ $i == $j ]]
    then
      users+="${telegram_users[${j}]} "
    fi
  done
done

echo ${users[@]}

send_telegram_message CHAT_ID_OF_WAX_GUILDS_TELEGRAM_GROUP_TO_BE_ADDED_HERE "${users[@]}"

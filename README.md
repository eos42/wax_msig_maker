# MSIG MAKER for WAX

This MSIG maker allows developers to quickly and efficiently create MSIGs with the correct permissions requests and without screwing up anything such as expiration times etc.
It can also be used by BPs for system upgrades to quickly allow for every BP to be informed when an upgrade is due.

How to use the MSIG maker
Type `./msig-maker PROPOSAL-NAME ACCOUNT-NAME MSIG-DESCRIPTION TRANSACTIONS...`

For example:
`./msig-maker mymsig phillhamnett "This MSIG sends money to account X" transaction1.json transaction2.json`

To generate transactions, create them how you normally would with cleos, and append with `-s -d -j > transactionX.json`

Example:
`cleos -u https://api.eos42.io:7884 transfer eos42freedom phillhamnett "0.0001 EOS" "my memo" -p eos42freedom@active -s -d -j > transaction1.json`

## Caveats
The Telegram bot is not currently intsalled in the WAX guilds group. As soon as this is done it should start informing BPs for upgrades

BP Upgrade MSIGs won't work until the `eosio` keys are handed over from `admin.wax` to `eosio.prods`

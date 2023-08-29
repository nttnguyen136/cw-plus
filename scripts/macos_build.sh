#!/bin/bash
BUILD="TRUE"
WORKSPACE=cosmwasm/workspace-optimizer:0.12.9
# CHAIN_ID=aura-testnet-2
# CHAIN_ID=serenity-testnet-001
CHAIN_ID=euphoria-2
WASM_PATH="./artifacts/"
WASM_FILE="cw20_base.wasm"
WASM_FILE_PATH=$WASM_PATH$WASM_FILE
WALLET=wallet
GITHUB="https://github.com/nttnguyen136/cw-plus"

CONTRACT_LABEL="CW20 Contract"

# CODE_ID=1077

INIT_MSG='{
"name": "New CW20 Token",
"symbol": "NEWTOKEN",
"decimals": 6,
"initial_balances": [],
"mint": { "minter": "aura1afuqcya9g59v0slx4e930gzytxvpx2c43xhvtx" },
"marketing": {"marketing":"aura1h6r78trkk2ewrry7s3lclrqu9a22ca3hpmyqfu", "description": "Coin gives
you the joint benefits of open blockchain technology and traditional currency by converting your cash into a stable digital currency equivalent.","logo": {"url": "https://nft-ipfs.s3.amazonaws.com/assets/imgs/icons/color/aura.svg"}}
}'

AURAD=$(which aurad)

echo "Build Tool: $AURAD"

case $CHAIN_ID in
aura-testnet-2)
  RPC="https://rpc.dev.aura.network:443"
  AURASCAN="http://explorer.dev.aura.network"
  NODE="--node $RPC"
  FEE="0.0025utaura"
  ;;

serenity-testnet-001)
  RPC="https://rpc.serenity.aura.network:443"
  AURASCAN="https://serenity.aurascan.io"
  NODE="--node $RPC"
  FEE="0.0025uaura"
  ;;

euphoria-2)
  RPC="https://rpc.euphoria.aura.network:443"
  AURASCAN="https://euphoria.aurascan.io"
  NODE="--node $RPC"
  FEE="0.0025ueaura"
  ;;
esac

TXFLAG="$NODE --chain-id $CHAIN_ID --gas-prices $FEE --gas auto --gas-adjustment 1.3 -y"

echo "=================== DEPLOY ENV INFO ==================="
echo "- RPC                 $RPC"
echo "- CHAIN_ID            $CHAIN_ID"
echo "- TXFLAG:             $TXFLAG"
echo "- WASM_FILE_PATH:     $WASM_FILE_PATH"
echo "======================================================="
echo " "

if [ "$BUILD" = "TRUE" ]; then
  docker run --rm -v "$(pwd)":/code \
    --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
    --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
    $WORKSPACE
  sleep 1
fi

if [ -z "$CODE_ID" ]; then

  TXHASH=$($AURAD tx wasm store $WASM_FILE_PATH --from $WALLET $TXFLAG --output json | jq -r ".txhash")

  echo "Store Hash: $AURASCAN/transaction/$TXHASH"

  sleep 10

  CODE_ID=$(curl "$RPC/tx?hash=0x$TXHASH" | jq -r ".result.tx_result.log" | jq -r ".[0].events[-1].attributes[-1].value")
fi

#uri: https://nft-ipfs.s3.amazonaws.com/assets/imgs/icons/color/aura.svg
if [ -n "$CODE_ID" ]; then
  INIT_MSG='{
  "name": "'$CODE_ID' New Token",
  "symbol": "NEWTOKEN",
  "decimals": 12,
  "initial_balances": [],
  "mint": { "minter": "aura1afuqcya9g59v0slx4e930gzytxvpx2c43xhvtx" },
  "marketing": {"marketing":"aura1h6r78trkk2ewrry7s3lclrqu9a22ca3hpmyqfu", "description": "Coin gives you the joint benefits of open blockchain technology and traditional currency by converting your cash into a stable digital currency equivalent.","logo": {"url": "https://nft-ipfs.s3.amazonaws.com/QmWobdZpeyhq8NnUEoqLBzpz9HDTrQ1VoEK52aoh7bMLXE.gif"}}
  }'
  INIT=$INIT_MSG

  LABEL="$CODE_ID $CONTRACT_LABEL"

  echo "=================== CONTRACT INFO ==================="
  echo "CODE_ID:       $CODE_ID"
  echo "INIT:          $INIT"
  echo "LABEL:         $LABEL"
  echo "====================================================="

  INSTANTIATE=$($AURAD tx wasm instantiate $CODE_ID "$INIT" --from $WALLET --label "$LABEL" $TXFLAG -y --no-admin --output json)

  HASH=$(echo $INSTANTIATE | jq -r ".txhash")

  sleep 10

  CONTRACT=$(curl "$RPC/tx?hash=0x$HASH" | jq -r ".result.tx_result.log" | jq -r ".[0].events[0].attributes[0].value")

  COMMIT_ID=$(git rev-parse --verify HEAD)

  echo "====================================================="
  echo $(date)
  echo "CW20 - Code ID: "$CODE_ID
  echo "Aurascan: $AURASCAN/transaction/$HASH"
  echo "Contract: $AURASCAN/contracts/$CONTRACT"
  echo "Github: $GITHUB/commit/$COMMIT_ID"
  echo "Cargo version: $WORKSPACE"
  echo "WASM FILE: $WASM_FILE"
  echo "====================================================="

  echo "=====================================================" >>CW20info.txt
  echo $(date) >>CW20info.txt
  echo "Code ID: "$CODE_ID >>CW20info.txt
  echo "Aurascan: $AURASCAN/transaction/$HASH" >>CW20info.txt
  echo "Contract: $AURASCAN/contracts/$CONTRACT" >>CW20info.txt
  echo "Github: $GITHUB/commit/$COMMIT_ID" >>CW20info.txt
  echo "Cargo version: $WORKSPACE" >>CW20info.txt
  echo "WASM FILE: $WASM_FILE" >>CW20info.txt

else
  echo "==================="
  echo "Can not get CODE_ID"
  echo "==================="
fi

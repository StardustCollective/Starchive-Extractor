parse_arguments "$@"

if [[ -n "${HASH_MODE:-}" ]]; then
  if [[ -z "$network_choice" ]]; then
    talk "[ERROR] --hash requires --cluster <network> (mainnet/integrationnet/testnet)" $LRED
    exit 1
  fi
  process_hash_mode
  exit 0
fi

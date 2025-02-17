#!/bin/sh

echo "$1" # ns
echo "$2" # res
echo "$3" # sa
echo "$4" # name
echo "$LIST" # list

wget -O /tmp/jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
chmod +x /tmp/jq

curl -k --cacert /tmp/certs/ca.crt --header "X-Vault-Token: $(cat /tmp/token)" --request GET https://vault.secrets.svc:8200/v1/auth/kubernetes/role/"$2" > /tmp/output
ns_tmp=$(/tmp/jq  --raw-output ".data.bound_service_account_namespaces += [\"$1\"] |.data.bound_service_account_namespaces |.= unique | tostring" /tmp/output)
ret=$?

# shellcheck disable=SC3014
if [ "$ret" != "0" ]; then
  ns_tmp=["$1"]
fi
sa_tmp=$(/tmp/jq  --raw-output ".data.bound_service_account_names += [\"$3\"] |.data.bound_service_account_names |.= unique | tostring" /tmp/output)
ret=$?

# shellcheck disable=SC3014
if [ "$ret" != "0" ]; then
  sa_tmp=["$3"]
fi
echo "$ns_tmp"
echo "$sa_tmp"
echo "{\"policy\":\"path \\\"$1/data/$2/*\\\" {capabilities = [\\\"read\\\"]}\"}"

echo "{\"policies\": [\"$2\"],\"bound_service_account_names\":$sa_tmp,\"bound_service_account_namespaces\":$ns_tmp}"

echo "{ \"data\": { $LIST } }"

curl -k --cacert /tmp/certs/ca.crt \
--header "X-Vault-Token: $(cat /tmp/token)" \
--request POST \
--data "{ \"type\":\"kv-v2\" }" \
https://vault.secrets.svc:8200/v1/sys/mounts/"$1";

curl -k --cacert /tmp/certs/ca.crt \
--header "X-Vault-Token: $(cat /tmp/token)" \
--request PUT \
--data "{\"policy\":\"path \\\"$1/data/$2/*\\\" {capabilities = [\\\"read\\\"]}\"}" \
https://vault.secrets.svc:8200/v1/sys/policies/acl/"$2";

curl -k --cacert /tmp/certs/ca.crt \
--header "X-Vault-Token: $(cat /tmp/token)" \
--request POST \
--data "{\"policies\": [\"$2\"],\"bound_service_account_names\":$sa_tmp,\"bound_service_account_namespaces\":$ns_tmp}" \
https://vault.secrets.svc:8200/v1/auth/kubernetes/role/"$2";

curl -k --cacert /tmp/certs/ca.crt \
--header "X-Vault-Token: $(cat /tmp/token)" \
--request POST \
--data "{ \"data\": { $LIST } }" \
https://vault.secrets.svc:8200/v1/"$1"/data/"$2"/"$4";
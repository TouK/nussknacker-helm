#!/usr/bin/env bats

: "${NUSSKNACKER_URL:?required environment value not set}"
: "${AUTHORIZATION:?required environment value not set}"
: "${SCENARIO_TYPE:?required environment value not set}"

function curl() {
  /usr/bin/curl -f -k -v -H "Content-type: application/json" -H "Authorization: ${AUTHORIZATION}" "$@"
}
export -f curl

# timeout command has different syntax in Ubuntu and BusyBox
if [[ $(realpath $(which timeout)) =~ "busybox" ]]; then
  function timeout() {
    $(which timeout) -t "$@"
  }
fi

function given_a_proxy_process() {
  local PROCESS_NAME="${1:?required}"
  local PROCESS_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_DEPLOY_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/deploy/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_CANCEL_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/cancel/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_IMPORT_URL=$( echo ${NUSSKNACKER_URL%/}/api/processes/import/${PROCESS_NAME} | sed -e 's/ /%20/g')

  curl ${PROCESS_URL} || curl -X POST ${PROCESS_URL%/}/Default
  export PROCESS_NAME GROUP INPUT_TOPIC OUTPUT_TOPIC
  cat ${BATS_TEST_DIRNAME}/rr-testprocess.json | envsubst  | /usr/bin/curl -f -k -v -H "Authorization: ${AUTHORIZATION}" ${PROCESS_IMPORT_URL} -F process=@- | (echo '{ "comment": "created by a bats test", "process": '; cat; echo '}') | curl -X PUT ${PROCESS_URL} -d @-

  [[ $(curl ${PROCESS_URL%/}/status | jq -r .status.name) = RUNNING ]] && curl -X POST ${PROCESS_CANCEL_URL}
  curl -X POST ${PROCESS_DEPLOY_URL}
  #on smaller ci envs deployment may last some time...
  timeout 60 /bin/sh -c "until [ `curl ${PROCESS_URL%/}/status | jq -r .status.name` = "RUNNING" ]; do sleep 1 && echo -n .; done;" || true
  echo "Checking after waiting for status..."
  curl ${PROCESS_URL%/}/status
}

function setup() {
  given_a_proxy_process "test proxy process for rr"
}

@test "message should pass through the rr proxy process" {
  INPUT_MESSAGE='{"productId":10}'
  EXPECTED_OUTPUT_MESSAGE='{"productId":20}'

  if [[ $(curl -XPOST $SCENARIO_URL -d $INPUT_MESSAGE) == $EXPECTED_OUTPUT_MESSAGE ]]; then echo ok; else exit 1; fi
}
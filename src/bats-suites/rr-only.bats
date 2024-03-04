#!/usr/bin/env bats

: "${NUSSKNACKER_URL:?required environment value not set}"
: "${AUTHORIZATION:?required environment value not set}"

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

function cancel_process() {
  local PROCESS_NAME="${1:?required}"
  local PROCESS_CANCEL_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/cancel/${PROCESS_NAME} | sed -e 's/ /%20/g')
  curl -X POST ${PROCESS_CANCEL_URL}
}

function wait_for_status() {
  local PROCESS_NAME="${1:?required}"
  local STATUS="${2:?required}"
  local PROCESS_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/${PROCESS_NAME} | sed -e 's/ /%20/g')
  timeout 60 /bin/sh -c "until [[ `curl ${PROCESS_URL%/}/status | jq -r .status.name` == \"$STATUS\" ]]; do sleep 1 && echo -n .; done;" || true
}

function given_a_proxy_process() {
  local PROCESS_NAME="${1:?required}"
  local PROCESSES_URL="${NUSSKNACKER_URL%/}/api/processes"
  local PROCESS_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_DEPLOY_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/deploy/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_IMPORT_URL=$( echo ${NUSSKNACKER_URL%/}/api/processes/import/${PROCESS_NAME} | sed -e 's/ /%20/g')

  curl ${PROCESS_URL} || echo "{ \"name\": \"$PROCESS_NAME\", \"processingMode\": \"Request-Response\", \"isFragment\": false }" | curl -X POST ${PROCESSES_URL} -d @-
  export PROCESS_NAME GROUP INPUT_TOPIC OUTPUT_TOPIC
  cat ${BATS_TEST_DIRNAME}/rr-testprocess.json | envsubst  | /usr/bin/curl -f -k -v -H "Authorization: ${AUTHORIZATION}" ${PROCESS_IMPORT_URL} -F process=@- | jq .scenarioGraph | (echo '{ "comment": "created by a bats test", "scenarioGraph": '; cat; echo '}') | curl -X PUT ${PROCESS_URL} -d @-

  [[ $(curl ${PROCESS_URL%/}/status | jq -r .status.name) = RUNNING ]] && cancel_process "$PROCESS_NAME"
  curl -X POST ${PROCESS_DEPLOY_URL}
  #on smaller ci envs deployment may last some time...
  wait_for_status "$PROCESS_NAME" "RUNNING"
  echo "Checking after waiting for status..."
  local STATUS_RESPONSE=$(curl ${PROCESS_URL%/}/status)
  echo "Status is: $STATUS_RESPONSE"
  [[ `echo $STATUS_RESPONSE | jq -r .status.name` == "RUNNING" ]]
}

function setup() {
  given_a_proxy_process "test proxy process for rr"
}

@test "message should pass through the rr proxy process" {
  local PROCESS_NAME="test proxy process for rr"
  INPUT_MESSAGE='{"productId":10}'
  EXPECTED_OUTPUT_MESSAGE='{"productId":20}'

  if [[ $(curl $RR_SCENARIO_INPUT_URL -d $INPUT_MESSAGE) == $EXPECTED_OUTPUT_MESSAGE ]]; then echo ok; else exit 1; fi

  cancel_process "$PROCESS_NAME"
  wait_for_status "$PROCESS_NAME" "CANCELED"
}

#!/usr/bin/env bats

: "${NUSSKNACKER_URL:?required environment value not set}"
: "${AUTHORIZATION:?required environment value not set}"
: "${KAFKA_BOOTSTRAP_SERVER:?required environment value not set}"
: "${SCHEMA_REGISTRY_URL:?required environment value not set}"
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

function given_a_topic() {
  local TOPIC_FULL_NAME="${1:?required}"
  local SCHEMA="${2:?required}"

  kafka-topics --bootstrap-server $KAFKA_BOOTSTRAP_SERVER --describe --topic "${TOPIC_FULL_NAME}" ||
    kafka-topics --bootstrap-server $KAFKA_BOOTSTRAP_SERVER --create --topic "${TOPIC_FULL_NAME}" \
      --partitions 10 --replication-factor 1

  kafka-consumer-groups --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} \
    --topic "${TOPIC_FULL_NAME}" \
    --group helm_test --reset-offsets --to-latest --execute

  cat << _END | curl -d @- "${SCHEMA_REGISTRY_URL%/}/subjects/${TOPIC_FULL_NAME}-value/versions"
{ "schema": "$(echo $SCHEMA | sed -e 's/"/\\"/g')" }
_END
}

function given_a_proxy_process() {
  local PROCESS_NAME="${1:?required}"
  local PROCESS_OBJECT="${2:?required}"
  local PROCESS_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_DEPLOY_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/deploy/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_CANCEL_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/cancel/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_IMPORT_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/import/${PROCESS_NAME} | sed -e 's/ /%20/g')

  curl ${PROCESS_URL} || curl -X POST ${PROCESS_URL%/}/Default
  echo ${PROCESS_OBJECT} | /usr/bin/curl -f -k -v -H "Authorization: ${AUTHORIZATION}" ${PROCESS_IMPORT_URL} -F process=@- | (echo '{ "comment": "created by a bats test", "process": '; cat; echo '}') | curl -X PUT ${PROCESS_URL} -d @-

  [[ $(curl ${PROCESS_URL%/}/status | jq -r .status.name) = RUNNING ]] && curl -X POST ${PROCESS_CANCEL_URL}
  curl -X POST ${PROCESS_DEPLOY_URL}
}

function when_a_message_has_been_posted_on_the_topic() {
  local TOPIC_FULL_NAME="${1:?required}"
  local ID=${2:?required}

  local SCHEMA_ID=$(curl "${SCHEMA_REGISTRY_URL%/}/subjects/${TOPIC_FULL_NAME}-value/versions/latest" | jq '.id')

  cat << _END | kafka-avro-console-producer \
    --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
    --topic "${TOPIC_FULL_NAME}" \
    --property "schema.registry.url=${SCHEMA_REGISTRY_URL}" \
    --property "value.schema.id=${SCHEMA_ID}"
{ "id": "$ID", "content": "a content", "tags": [] }
_END
}

function then_the_message_can_be_consumed_from_the_topic() {
  local TOPIC_FULL_NAME="${1:?required}"
  local ID=${2:?required}

  kafka-avro-console-consumer \
    --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
    --topic "${TOPIC_FULL_NAME}" \
    --group helm_test \
    --property "schema.registry.url=${SCHEMA_REGISTRY_URL}" \
    --timeout-ms 60000 \
    | (while : ; do
        read MSG;
        echo $MSG
        if [[ -z $MSG ]]; then exit 1; fi;
        if echo $MSG | jq -e ".id == \"${ID}\""; then break; fi;
      done)
}

function setup() {
  export GROUP=testgroup
  export INPUT_TOPIC=inputKafkaOnly
  export OUTPUT_TOPIC=outputKafkaOnly
  local SCHEMA=$(cat << _END
{
  "namespace": "\${GROUP}",
  "name": "\${TOPIC}",
  "type": "record",
  "doc": "This is a sample schema definition",
  "fields": [
    { "name": "id", "type": "string", "doc": "Message id" },
    { "name": "content", "type": "string", "doc": "Message content" },
    { "name": "tags", "type": { "type": "array", "items": "string" }, "doc": "Message tags" }
  ]
}
_END
)
  local -x PROCESS_NAME="test proxy process for kafka only"

  given_a_topic "${KAFKA_NAMESPACE}_${GROUP}.$INPUT_TOPIC" "$(echo $SCHEMA | TOPIC=${INPUT_TOPIC} envsubst)"
  given_a_topic "${KAFKA_NAMESPACE}_${GROUP}.$OUTPUT_TOPIC" "$(echo $SCHEMA | TOPIC=${OUTPUT_TOPIC} envsubst)"
  given_a_proxy_process "${PROCESS_NAME}" "$(cat ${BATS_TEST_DIRNAME%/}/testprocess.json | envsubst)"
}

@test "message should pass through the proxy process" {
  local ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  when_a_message_has_been_posted_on_the_topic "${KAFKA_NAMESPACE}_${GROUP}.$INPUT_TOPIC" ${ID}
  then_the_message_can_be_consumed_from_the_topic "${KAFKA_NAMESPACE}_${GROUP}.$OUTPUT_TOPIC" ${ID}
}

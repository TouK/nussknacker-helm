#!/usr/bin/env bats

: "${MANAGEMENT_URL:?required environment value not set}"
: "${FRONTEND_URL:?required environment value not set}"
: "${WIREMOCK_URL:?required environment value not set}"
: "${NUSSKNACKER_URL:?required environment value not set}"
: "${AUTHORIZATION:?required environment value not set}"

function curl() {
  /usr/bin/curl -f -k -v -H "Content-type: application/json" -H "Authorization: ${AUTHORIZATION}" "$@"
}
export -f curl

function given_a_group() {
  local GROUP="${1:?required}"

  curl ${MANAGEMENT_URL%/}/groups/${GROUP} ||
    curl -d "{\"groupName\": \"${GROUP}\"}" ${MANAGEMENT_URL%/}/groups
}

function given_a_topic() {
  local -x GROUP="${1:?required}"
  local -x TOPIC="${2:?required}"
  local SCHEMA="${3:?required}"

  curl ${MANAGEMENT_URL%/}/topics/${GROUP}.${TOPIC} ||
    cat  << _END | curl -d @- ${MANAGEMENT_URL%/}/topics/
{
    "name": "${GROUP}.${TOPIC}",
    "description": "This is a test topic",
    "contentType": "AVRO",
    "retentionTime": {
        "duration": 1
    },
    "owner": {
        "source": "Plaintext",
        "id": "Test"
    },
    "schema": "$(echo $SCHEMA | envsubst | sed -e 's/"/\\"/g')"
}
_END
}

function given_a_subscriber() {
  local GROUP="${1:?required}"
  local TOPIC="${2:?required}"
  local SUBSCRIBER_NAME="${3:?required}"

  local SUBSCRIBER_URL=${WIREMOCK_URL%/}/${SUBSCRIBER_NAME}

  # wait for wiremock
  timeout 10 /bin/sh -c "until curl --output /dev/null --silent --fail ${WIREMOCK_URL%/}/__admin/; do sleep 1 && echo -n .; done;"

  cat << _END | curl -d @- ${WIREMOCK_URL%/}/__admin/mappings
{
  "request": {
    "method": "POST",
    "url": "/${SUBSCRIBER_NAME}"
  },
  "response": {
    "status": 202
  }
}
_END
  cat << _END | curl -d @- ${MANAGEMENT_URL%/}/topics/${GROUP}.${TOPIC}/subscriptions
{
    "contentType": "JSON",
    "description": "test",
    "endpoint": "${SUBSCRIBER_URL%/}",
    "name": "${SUBSCRIBER_NAME}",
    "owner": { "id": "test", "source": "Plaintext" },
    "topicName": "${GROUP}.${TOPIC}"
}
_END
}

function given_a_proxy_process() {
  local PROCESS_NAME="${1:?required}"
  local PROCESS_URL=$(echo ${NUSSKNACKER_URL%/}/api/processes/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_DEPLOY_URL=$(echo ${NUSSKNACKER_URL%/}/api/processManagement/deploy/${PROCESS_NAME} | sed -e 's/ /%20/g')
  local PROCESS_IMPORT_URL=$( echo ${NUSSKNACKER_URL%/}/api/processes/import/${PROCESS_NAME} | sed -e 's/ /%20/g')

  curl ${PROCESS_URL} || (
    curl -X POST ${PROCESS_URL%/}/Default
    export PROCESS_NAME GROUP INPUT_TOPIC OUTPUT_TOPIC KAFKA_NAMESPACE
    cat ${BATS_TEST_DIRNAME}/testprocess.json | envsubst  | /usr/bin/curl -f -k -v -H "Authorization: ${AUTHORIZATION}" ${PROCESS_IMPORT_URL} -F process=@- | (echo '{ "comment": "created by a bats test", "process": '; cat; echo '}') | curl -X PUT ${PROCESS_URL} -d @-
  )

  [[ $(curl ${PROCESS_URL%/}/status | jq -r .status.name) = RUNNING ]] ||
    curl -X POST ${PROCESS_DEPLOY_URL}
}

function when_a_message_has_been_posted_on_the_topic() {
  GROUP=${1:?required}
  TOPIC=${2:?required}

  cat << _END | curl -d @- ${FRONTEND_URL%/}/topics/${GROUP}.${TOPIC}
{
  "id": "an id",
  "content": "a content",
  "tags": []
}
_END
}

function then_the_message_is_received_by_the_subscriber() {
  local SUBSCRIBER_NAME="${1:?required}"

  cat << _END | timeout 90 bash -c "until curl -d '$(cat)' ${WIREMOCK_URL%/}/__admin/requests/count | tee >(cat 1>&3) | grep '\"count\" : 1'; do sleep 10; done"
{
    "method": "POST",
    "url": "/${SUBSCRIBER_NAME}"
}
_END
}

function setup() {
  GROUP=testgroup
  given_a_group $GROUP

  SCHEMA=$(cat << _END
{
  "namespace": "\${GROUP}",
  "name": "\${TOPIC}",
  "type": "record",
  "doc": "This is a sample schema definition for some Hermes message",
  "fields": [
    { "name": "id", "type": "string", "doc": "Message id" },
    { "name": "content", "type": "string", "doc": "Message content" },
    { "name": "tags", "type": { "type": "array", "items": "string" }, "doc": "Message tags" },
    {
      "name": "__metadata",
      "type": [ "null", { "type": "map", "values": "string" } ],
      "default": null,
      "doc": "Field used in Hermes internals to propagate metadata like hermes-id"
    }
  ]
}
_END
)
  INPUT_TOPIC=input
  given_a_topic $GROUP $INPUT_TOPIC "$SCHEMA"
  OUTPUT_TOPIC=output
  given_a_topic $GROUP $OUTPUT_TOPIC "$SCHEMA"

  SUBSCRIBER_NAME=$(head /dev/urandom | tr -dc a-z | head -c 16)
  given_a_subscriber $GROUP $OUTPUT_TOPIC $SUBSCRIBER_NAME

  given_a_proxy_process "test proxy process"
}

@test "message should pass through the proxy process" {
  when_a_message_has_been_posted_on_the_topic ${GROUP} ${INPUT_TOPIC}
  then_the_message_is_received_by_the_subscriber ${SUBSCRIBER_NAME}
}

function teardown() {
  # afterwards remove the subscription
  curl -X DELETE "${MANAGEMENT_URL%/}/topics/${GROUP}.${OUTPUT_TOPIC}/subscriptions/${SUBSCRIBER_NAME}"
}


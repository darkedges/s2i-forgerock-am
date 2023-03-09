#!/bin/bash
#
# The 'run' performs a simple test that verifies that STI image.
# The main focus here is to excersise the STI scripts.
#
# IMAGE_NAME specifies a name of the candidate image used for testing.
# The image has to be available before this script is executed.
#
BUILDER=${BUILDER}
FORGEROCK_VERSION=${FORGEROCK_VERSION}

APP_IMAGE="$(echo ${BUILDER} | cut -f 1 -d':')-testapp"

test_dir=`dirname ${BASH_SOURCE[0]}`
image_dir="${test_dir}/.."
cid_file=`date +%s`$$.cid

# Since we built the candidate image locally, we don't want S2I attempt to pull
# it from Docker hub
s2i_args="--pull-policy never "

# TODO: This should be part of the image metadata
test_port=8080

image_exists() {
  docker inspect $1 &>/dev/null
}

prepare() {
  if ! image_exists ${BUILDER}; then
    echo "ERROR: The image ${BUILDER} must exist before this script is executed."
    exit 1
  fi
}

test_image_usage_label() {
  local expected="s2i build . darkedges/s2i-forgerock-am myapp"
  echo "Checking image usage label ..."
  out=$(docker inspect --format '{{ index .Config.Labels "usage" }}' $BUILDER)
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[docker inspect --format \"{{ index .Config.Labels \"usage\" }}\"] Expected '${expected}', got '${out}'"
    return 1
  fi
}

test_builder_forgerock_ig_version() {
  local run_cmd="node --version"
  local expected_version="v${FORGEROCK_VERSION}"

  echo "Checking nodejs runtime version ..."
  out=$(docker run ${BUILDER} /bin/bash -c "${run_cmd}")
  if ! echo "${out}" | grep -q "${expected_version}"; then
    echo "ERROR[/bin/bash -c "${run_cmd}"] Expected '${expected_version}', got '${out}'"
    return 1
  fi

  echo "Checking NPM_CONFIG_TARBALL environment variable"
  out=$(docker run ${BUILDER} /bin/bash -c 'echo $NPM_CONFIG_TARBALL')
  local expected_var="/usr/share/node/node-v${FORGEROCK_VERSION}-headers.tar.gz"
  if ! echo "${out}" | grep -q "${expected_var}"; then
    echo "ERROR[/bin/bash -c "${run_cmd}"] Expected '${expected_var}', got '${out}'"
    return 1
  fi
}

cleanup() {
  if [ -f $cid_file ]; then
    if container_exists; then
      cid=$(cat $cid_file)
      docker stop $cid
      exit_code=`docker inspect --format="{{ .State.ExitCode }}" $cid`
      echo "Container exit code = $exit_code"
      # Only check the exist status for non DEV_MODE
      if [ "$1" == "false" ] &&  [ "$exit_code" != "222" ] ; then
        echo "ERROR: The exist status should have been 222."
        exit 1
      fi
    fi
  fi
  cids=`ls -1 *.cid 2>/dev/null | wc -l`
  if [ $cids != 0 ]
  then
    rm *.cid
  fi
}

check_result() {
  local result="$1"
  if [[ "$result" != "0" ]]; then
    echo "STI image '${BUILDER}' test FAILED (exit code: ${result})"
    cleanup
    exit $result
  fi
}

prepare
test_image_usage_label
check_result $?

test_builder_forgerock_ig_version
check_result $?

test_nss_wrapper
check_result $?
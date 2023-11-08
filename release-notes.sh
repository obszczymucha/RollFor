#!/usr/bin/env bash

check_arguments() {
  if [[ $# != 2 ]]; then
    echo "Usage: $0 <start_tag> <end_tag>"
    exit 1
  fi
}

run() {
  local start_tag="$1"
  local end_tag="$2"

  commit_messages=$(git log --oneline --pretty=format:"%s" ${start_tag}..${end_tag})
  echo "Changes between ${start_tag} and ${end_tag}:"
  echo "${commit_messages}"
}

check_arguments "$@"
run "$@"


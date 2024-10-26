#!/bin/bash

case $1 in

  --force)
    ARGS='--force'
    shift
    ;;

  --help)
    ARGS='--help'
  ;;

esac

ansible-galaxy install -r requirements.yml $ARGS

ansible-playbook ark_asa_server.yml "$@" 

#!/bin/bash

SCP_OPTIONS=
SSH_USER=john-doe
SSH_SERVER=localhost
REMOTE_PATH=/packages

scp $SCP_OPTIONS "$@" $SSH_USER@$SSH_SERVER:$REMOTE_PATH

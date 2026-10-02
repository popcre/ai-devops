#!/usr/bin/env bash
# P3 live-proof candidate: deliberately invalid bash syntax.
# This file is expected to fail `bash -n` so fast-classifier validate stops
# every expensive job. Do not fix the syntax error in the first commit.
if [ true
then
  echo never
fi

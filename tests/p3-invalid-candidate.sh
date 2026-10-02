#!/usr/bin/env bash
# P3 live-proof candidate: deliberately invalid bash syntax.
# Unclosed quote is a parse error, so `bash -n` fails and fast-classifier
# validate stops every expensive job. Do not fix this in the first commit.
echo 'never closed

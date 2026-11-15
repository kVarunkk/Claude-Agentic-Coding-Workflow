#!/usr/bin/env bash
# patch-id.sh <plan-dir>
# Prints a stable id of the staged change, leaving out <plan-dir>/reports and decisions.tsv
# (those change after the review on purpose). Record it when the review starts; commit only if it
# is unchanged, else review again. Prints "empty" when nothing is staged.
set -u
plan="${1:?usage: patch-id.sh <plan-dir>}"
plan="${plan%/}"
id=$(git diff --cached --binary -- . ":(exclude)$plan/reports" ":(exclude)$plan/decisions.tsv" |
  git patch-id --stable | cut -d' ' -f1)
printf '%s\n' "${id:-empty}"

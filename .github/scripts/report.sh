#!/usr/bin/env bash
# Publie le rapport de vérification dans la branche "ci-report" (lisible sans connexion).
# Usage : report.sh <url-du-depot> <fichier-rapport>
set -u
URL="$1"; FILE="$2"
W="$(mktemp -d)"
cd "$W"
git init -q -b ci-report
git config user.name "ci-report"
git config user.email "ci-report@users.noreply.github.com"
git remote add origin "$URL"
git fetch -q origin ci-report 2>/dev/null && git reset -q --hard FETCH_HEAD || true
cp "$FILE" "$W/report.txt"
git add report.txt
git commit -q -m "rapport de vérification" || true
git push -q origin ci-report

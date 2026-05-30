#!/bin/bash

FILE="manifests/deployment.yaml"
URL="http://192.168.17.61:30080/"
CSV="results.csv"

ATTEMPTS=20
INTERVAL=0.01
TIMEOUT=120

echo "run,first_ok_ms,stable_ms" > "$CSV"

for i in $(seq 1 $ATTEMPTS); do

  cd . || exit 1

  # -----------------------------
  # SWITCH VERSIONE
  # -----------------------------
  if grep -q "image: .*:a" "$FILE"; then
    sed -i.bak 's|\(image: .*:\)a|\1b|' "$FILE"
    EXPECTED="VERSION B"
  else
    sed -i.bak 's|\(image: .*:\)b|\1a|' "$FILE"
    EXPECTED="VERSION A"
  fi

  # -----------------------------
  # GIT PUSH SILENZIOSO
  # -----------------------------
  git add "$FILE" >/dev/null 2>&1
  git commit -m "run $i -> $EXPECTED" >/dev/null 2>&1
  git push >/dev/null 2>&1

  # -----------------------------
  # MONITOR
  # -----------------------------
  START_TOTAL=$(date +%s%3N)

  FIRST_OK=""
  STABILIZED=""
  STABLE_REQUIRED=5000

  while true; do
    NOW=$(date +%s%3N)
    RESPONSE=$(curl -s "$URL")

    if [[ "$RESPONSE" == "$EXPECTED" ]]; then

      if [ -z "$FIRST_OK" ]; then
        FIRST_OK=$NOW
      fi

      if [ -z "$STABILIZED" ]; then
        STABILIZED=$NOW
      fi

      if [ $((NOW - STABILIZED)) -ge $STABLE_REQUIRED ]; then
        break
      fi

    else
      STABILIZED=""
    fi

    sleep $INTERVAL
  done

  # -----------------------------
  # SALVATAGGIO CSV
  # -----------------------------
  FIRST_OK_MS="NA"
  STABLE_MS="NA"

  if [[ "$FIRST_OK" != "timeout" ]]; then
    FIRST_OK_MS=$((FIRST_OK - START_TOTAL))
  fi

  if [[ "$STABILIZED" != "timeout" ]]; then
    STABLE_MS=$((STABILIZED - START_TOTAL))
  fi

  echo "$i,$FIRST_OK_MS,$STABLE_MS"
  echo "$i,$FIRST_OK_MS,$STABLE_MS" >> "$CSV"
  sleep $TIMEOUT
done

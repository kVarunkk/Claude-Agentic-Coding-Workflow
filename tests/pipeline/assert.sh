# Tiny assert helpers. Source it.
PASS=0; FAILED=0
eq() { # name expected actual
  if [ "$2" == "$3" ]; then PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"
  else FAILED=$((FAILED + 1)); printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fi
}
has() { # name needle haystack
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); printf 'ok   %s\n' "$1" ;;
    *) FAILED=$((FAILED + 1)); printf 'FAIL %s\n     missing: %s\n     in:      %s\n' "$1" "$2" "$3" ;;
  esac
}
done_tests() {
  printf '\n%d passed, %d failed\n' "$PASS" "$FAILED"
  [ "$FAILED" -eq 0 ]
}

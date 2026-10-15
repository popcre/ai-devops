#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'status=$?; if [ "$status" -ne 0 ]; then printf "FAIL: test-az-mail.sh exited %s at: %s\n" "$status" "${BASH_COMMAND:-unknown}" >&2; fi; rm -rf -- "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

for tool in jq openssl sha256sum; do command -v "$tool" >/dev/null || fail "test dependency unavailable: $tool"; done
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) actual_windows=1 ;; *) actual_windows=0; command -v flock >/dev/null || fail 'test dependency unavailable: flock' ;; esac

mkdir -p "$TMP/private/.git" "$TMP/stubs" "$TMP/config/ai-devops" "$TMP/windows-profile"
profile_root="$TMP/config"
if [ "$actual_windows" -eq 1 ]; then
  profile_root="$TMP/windows-profile/.config"
  test_user_profile="$(cygpath -aw "$TMP/windows-profile")"
else
  test_user_profile='C:\Users\fixture'
fi
mkdir -p "$profile_root/ai-devops"
chmod 700 "$profile_root/ai-devops"
# Keep the subject attached to its option so Git Bash leaves it alone while
# still converting the certificate output paths for Windows OpenSSL.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" -out "$TMP/certificate.pem" \
  -days 30 -subj=/CN=az-mail-fixture >/dev/null 2>&1
cat "$TMP/key.pem" >> "$TMP/certificate.pem"
fingerprint="$(openssl x509 -in "$TMP/certificate.pem" -noout -fingerprint -sha256 | sed 's/^[^=]*=//')"
test_application_id='11111111-1111-4111-8111-111111111111'
test_tenant_id='22222222-2222-4222-8222-222222222222'
if [ "$actual_windows" -eq 1 ]; then host="$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')"; else host="$(hostname -s | tr '[:upper:]' '[:lower:]')"; fi
jq -n --arg fingerprint "$fingerprint" --arg host "$host" --arg app "$test_application_id" --arg tenant "$test_tenant_id" \
  '{schema_version:1,repository:"u2giants/ai-devops-private-config",files:{},values:{azure_cli_mail_application_id:$app,azure_cli_mail_tenant_id:$tenant,azure_cli_mail_certificate_ref:"op://vibe_coding/fixture/Certificate",azure_cli_mail_certificate_sha256:$fingerprint,azure_cli_mail_linux_hosts:$host,azure_cli_mail_windows_hosts:$host}}' \
  > "$TMP/private/manifest.json"
printf 'fixture-token' > "$profile_root/ai-devops/op-service-account"
chmod 600 "$profile_root/ai-devops/op-service-account"

cat > "$TMP/stubs/op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == read ]] || exit 41
cat "$AZ_MAIL_TEST_CERT"
EOF
cat > "$TMP/stubs/az" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'AZURE_CONFIG_DIR=%s\n' "${AZURE_CONFIG_DIR:-}" >> "$AZ_MAIL_TEST_CALLS"
printf '%s\n' "$*" >> "$AZ_MAIL_TEST_CALLS"
EOF
chmod +x "$TMP/stubs/op" "$TMP/stubs/az"

env AI_PRIVATE_CONFIG_HOME="$TMP/private" AI_PRIVATE_CONFIG_ALLOW_FIXTURE=1 \
  XDG_CONFIG_HOME="$TMP/config" USERPROFILE="$test_user_profile" OP_SERVICE_ACCOUNT_TOKEN=fixture-token \
  AZ_MAIL_TEST_CERT="$TMP/certificate.pem" PATH="$TMP/stubs:$PATH" \
  bash "$ROOT/tools/setup-az-mail.sh" >/dev/null || fail 'supported host setup failed'
if [ "$actual_windows" -eq 0 ]; then
  [[ "$(stat -c '%a' "$profile_root/ai-devops/az-mail")" == 700 ]] || fail 'profile directory is not private'
  [[ "$(stat -c '%a' "$profile_root/ai-devops/az-mail/config.json")" == 600 ]] || fail 'profile config is not private'
  [[ "$(stat -c '%a' "$profile_root/ai-devops/az-mail/certificate.pem")" == 600 ]] || fail 'certificate is not private'
fi
pass 'setup installs a verified certificate and private profile files'

env XDG_CONFIG_HOME="$TMP/config" USERPROFILE="$test_user_profile" AZ_MAIL_TEST_CALLS="$TMP/calls" PATH="$TMP/stubs:$PATH" \
  bash "$ROOT/bin/az-mail" rest --method GET --url https://graph.microsoft.com/v1.0/users/fixture@example.test/messages >/dev/null || fail 'mail command failed'
grep -q -- "--service-principal --username $test_application_id --tenant $test_tenant_id" "$TMP/calls" || fail 'service-principal sign-in was not isolated through az-mail'
grep -q 'rest --method GET --url https://graph.microsoft.com/v1.0/users/fixture@example.test/messages' "$TMP/calls" || fail 'Azure CLI arguments were not forwarded'
pass 'command signs in with the scoped app and forwards Azure CLI arguments'

mkdir -p "$TMP/windows-stubs"
cat > "$TMP/windows-stubs/uname" <<'EOF'
#!/usr/bin/env bash
printf 'MINGW64_NT-10.0\n'
EOF
cat > "$TMP/windows-stubs/cygpath" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -aw) printf 'C:/fixture/%s\n' "$(basename "$2")" ;;
  -u) printf '%s\n' "$AZ_MAIL_WINDOWS_HOME" ;;
  *) exit 42 ;;
esac
EOF
chmod +x "$TMP/windows-stubs/uname" "$TMP/windows-stubs/cygpath"
env AI_PRIVATE_CONFIG_HOME="$TMP/private" AI_PRIVATE_CONFIG_ALLOW_FIXTURE=1 \
  XDG_CONFIG_HOME="$TMP/config" USERPROFILE='C:\\Users\\fixture' AZ_MAIL_WINDOWS_HOME="$TMP/windows-profile" OP_SERVICE_ACCOUNT_TOKEN=fixture-token \
  AZ_MAIL_TEST_CERT="$TMP/certificate.pem" PATH="$TMP/windows-stubs:$TMP/stubs:$PATH" \
  bash "$ROOT/tools/setup-az-mail.sh" >/dev/null || fail 'allowlisted Windows setup failed'
env XDG_CONFIG_HOME="$TMP/config" USERPROFILE='C:\\Users\\fixture' AZ_MAIL_WINDOWS_HOME="$TMP/windows-profile" AZ_MAIL_TEST_CALLS="$TMP/windows-calls" \
  PATH="$TMP/windows-stubs:$TMP/stubs:$PATH" bash "$ROOT/bin/az-mail" account show >/dev/null || fail 'Windows path handling failed'
grep -q '^AZURE_CONFIG_DIR=C:/fixture/azure$' "$TMP/windows-calls" || fail 'Windows Azure CLI config path was not converted'
grep -q -- '--certificate C:/fixture/certificate.pem' "$TMP/windows-calls" || fail 'Windows certificate path was not converted'
[[ ! -e "$TMP/windows-profile/.config/ai-devops/az-mail/op-refresh.lock.d" ]] || fail 'Windows setup left its 1Password lock behind'
pass 'Windows setup and Azure CLI paths use the Windows profile paths'

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *)
    chmod 644 "$profile_root/ai-devops/az-mail/config.json"
    if env XDG_CONFIG_HOME="$TMP/config" USERPROFILE="$test_user_profile" AZ_MAIL_TEST_CALLS="$TMP/denied-calls" PATH="$TMP/stubs:$PATH" \
      bash "$ROOT/bin/az-mail" account show >/dev/null 2>&1; then fail 'opened profile permissions were accepted'; fi
    [[ ! -e "$TMP/denied-calls" ]] || fail 'Azure CLI ran with opened profile permissions'
    pass 'command refuses a profile with permissive file access'
    chmod 600 "$profile_root/ai-devops/az-mail/config.json"
    ;;
esac

if [ "$actual_windows" -eq 1 ]; then
  jq '.values.azure_cli_mail_windows_hosts="not-this-host"' "$TMP/private/manifest.json" > "$TMP/private/manifest.next"
else
  jq '.values.azure_cli_mail_linux_hosts="not-this-host"' "$TMP/private/manifest.json" > "$TMP/private/manifest.next"
fi
mv "$TMP/private/manifest.next" "$TMP/private/manifest.json"
rm -rf "$profile_root/ai-devops/az-mail"
env AI_PRIVATE_CONFIG_HOME="$TMP/private" AI_PRIVATE_CONFIG_ALLOW_FIXTURE=1 \
  XDG_CONFIG_HOME="$TMP/config" USERPROFILE="$test_user_profile" OP_SERVICE_ACCOUNT_TOKEN=fixture-token \
  AZ_MAIL_TEST_CERT="$TMP/certificate.pem" PATH="$TMP/stubs:$PATH" \
  bash "$ROOT/tools/setup-az-mail.sh" >/dev/null || fail 'unsupported host was not skipped cleanly'
[[ ! -e "$profile_root/ai-devops/az-mail/certificate.pem" ]] || fail 'unsupported host received a certificate'
pass 'unsupported hosts receive no mailbox certificate'

grep -Fq "Protect-AiDevOpsPrivatePath -Path \$azMailDirectory -Directory" "$ROOT/bin/setup-machine.ps1" || fail 'Windows setup does not protect the mailbox profile directory'
grep -Fq "Protect-AiDevOpsPrivatePath -Path \$azMailAzureDirectory -Directory" "$ROOT/bin/setup-machine.ps1" || fail 'Windows setup does not protect the Azure CLI token directory'
grep -Fq "Set-AiDevOpsPrivateFileAtomic -Path \$azMailCertificate" "$ROOT/bin/setup-machine.ps1" || fail 'Windows setup does not protect the mailbox certificate file'
pass 'Windows machine setup protects both profile directories and credential files'

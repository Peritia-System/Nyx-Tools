#!/usr/bin/env bash
nyx-info() {
############################################
# CONFIG (injected by Nix)
############################################
local info_dir="@LOG_DIR@/info"
local topic_name="Homemanager-Support"
local msg_file="${info_dir}/${topic_name}-message.txt"
local inform_enable=true
local sleeptimer=3


# ⚠ IMPORTANT PROJECT UPDATE ⚠

local information="
⚠ IMPORTANT PROJECT UPDATE ⚠

Please note that I will soon switch Nyx from a Home Manager module to a NixOS module.
You can still use the Home Manager module, but I will only continue developing it for Nyx at a specific legacy commit/revision.

Please consider pinning Nyx to that commit:
https://github.com/Peritia-System/Nyx-Tools/blob/main/Documentation/How-to-Homemanager.md

Or even better switch to the nixosmodule. Checkout the ReadMe for that:
https://github.com/Peritia-System/Nyx-Tools

If you use this, you can keep the current version indefinitely but wont receive updates.
If you dont pin to that commit, I wont take any responsibility for breakage.
(Note: I dont take any responsibility regardless — this is a hobby project.)
If you want to ensure it works, help me develop it.

Thank you for your understanding <3

This is not supposed to discourage you from using Nyx!!! I am so, so glad you use Nyx :)
But it is very early in development so things move quick and big changes will be common.
Plus as I said, it is a hobby project and at the moment I develop alone.
"

############################################
# Helpers
############################################

usage() {
  cat <<'EOF'
Usage: nyx-info [--acknowledge] [--print-force] [--help]

  --acknowledge   Record acknowledgment for the current notice and print it.
  --print-force   Print the current notice without reading/writing state.
  --help          Show this help.

Notes:
  - You'll be prompted again if the notice text changes.
  - State is stored under @LOG_DIR@/info per topic, in this format:

    -----Acknowledged-----
    $ack
    -----BEGIN INFO-----
    $information
    -----END INFO-----
    -----BEGIN SHA-----
    $sha
    -----END SHA-----
EOF
}

ensure_storage() {
  mkdir -p "${info_dir}"
}

hash_text() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "ERROR: Need sha256sum or shasum on PATH." >&2
    exit 1
  fi
}

current_sha() {
  printf '%s' "${information}" | hash_text
}

save_state() {
  # $1 = ack (true/false), $2 = sha
  {
    echo "-----Acknowledged-----"
    echo "$1"
    echo "-----BEGIN INFO-----"
    printf '%s\n' "${information}"
    echo "-----END INFO-----"
    echo "-----BEGIN SHA-----"
    echo "$2"
    echo "-----END SHA-----"
  } > "${msg_file}"
}

load_state() {
  # Sets globals: stored_ack, stored_sha, stored_info (empty if no file).
  stored_ack=""
  stored_sha=""
  stored_info=""

  [[ -f "${msg_file}" ]] || return 0

  stored_ack="$(awk '/^-----Acknowledged-----$/{getline; print; exit}' "${msg_file}" || true)"

  stored_info="$(awk '
    BEGIN{p=0}
    /^-----BEGIN INFO-----$/ {p=1; next}
    /^-----END INFO-----$/   {p=0}
    p==1 {print}
  ' "${msg_file}" || true)"

  stored_sha="$(awk '
    BEGIN{p=0}
    /^-----BEGIN SHA-----$/ {p=1; next}
    /^-----END SHA-----$/   {p=0}
    p==1 {print}
  ' "${msg_file}" || true)"
}

print_notice() {
  cat <<EOF
-----BEGIN NYX INFO NOTICE-----

${information}

-----END NYX INFO NOTICE-----

To acknowledge this message run: nyx-info --acknowledge
EOF
}

should_skip_notice() {
  local now_sha="$1"
  [[ -n "${stored_sha:-}" && "${stored_sha}" == "${now_sha}" && "${stored_ack:-}" == "true" ]]
}

############################################
# Main
############################################
  local acknowledge=false print_force=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --acknowledge) acknowledge=true ;;
      --print-force) print_force=true ;;
      --help|-h) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
  done

  [[ "${inform_enable}" == true ]] || exit 0
  ensure_storage

  local now_sha
  now_sha="$(current_sha)"

  if [[ "${print_force}" == true ]]; then
    print_notice
    exit 0
  fi

  load_state

  if [[ "${acknowledge}" == true ]]; then
    save_state "true" "${now_sha}"
    print_notice
    exit 0
  fi

  if should_skip_notice "${now_sha}"; then
    echo "Notice already acknowledged. To reread: ${info_dir} -> ${msg_file}"
    exit 0
  fi

  save_state "false" "${now_sha}"
  print_notice
}

nyx-info "$@"

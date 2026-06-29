#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <recipe-file> [report-dir]"
  exit 1
fi

RECIPE_FILE="$1"
if [[ ! -f "$RECIPE_FILE" ]]; then
  echo "Recipe file not found: $RECIPE_FILE"
  exit 1
fi

REPO_ROOT="$(pwd)"
WORK_DIR="$REPO_ROOT/projects/.gha"
REPORT_DIR="${2:-$REPO_ROOT/tmp/reports/$(basename "$RECIPE_FILE" .yaml)}"
PATCH_FILE="$REPO_ROOT/build/reports/rewrite/rewrite.patch"

mkdir -p "$WORK_DIR"
mkdir -p "$REPORT_DIR"

log() {
  local message="$1"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $message"
}

extract_recipe_name() {
  awk '/^name: / { print $2; exit }' "$RECIPE_FILE"
}

extract_change_module_version_field() {
  local field_name="$1"
  awk -v field="$field_name" '
    $0 ~ /io\.oczadly\.openrewrite\.hcl\.ChangeModuleVersion:/ { in_block = 1; next }
    in_block && $0 ~ /^  - / { in_block = 0 }
    in_block && $0 ~ "^[[:space:]]*" field ":[[:space:]]" {
      val = $0
      sub("^[[:space:]]*" field ":[[:space:]]*", "", val)
      gsub(/"/, "", val)
      print val
      exit
    }
  ' "$RECIPE_FILE"
}

normalize_version() {
  local raw="$1"
  raw="${raw#~>}"
  raw="${raw# }"
  raw="${raw% }"
  echo "$raw"
}

sanitize_id() {
  local value="$1"
  echo "$value" | tr '/:' '_' | tr -cd '[:alnum:]_.-'
}

try_repo() {
  local url="$1"
  if git ls-remote --exit-code "$url" HEAD >/dev/null 2>&1; then
    echo "$url"
    return 0
  fi
  return 1
}

resolve_module_repo_url() {
  local source_path="$1"
  local owner="${source_path%%/*}"
  local module_path="${source_path#*/}"
  local direct_repo="https://github.com/${owner}/${module_path}.git"
  local prefixed_repo="https://github.com/${owner}/terraform-azurerm-${module_path}.git"

  if resolved="$(try_repo "$direct_repo")"; then
    echo "$resolved"
    return
  fi

  if resolved="$(try_repo "$prefixed_repo")"; then
    echo "$resolved"
    return
  fi

  echo "Could not resolve AVM repository for source ${source_path}" >&2
  exit 1
}

resolve_tag() {
  local repo_dir="$1"
  local wanted="$2"

  if git -C "$repo_dir" rev-parse --verify --quiet "refs/tags/v${wanted}" >/dev/null; then
    echo "v${wanted}"
    return
  fi

  if git -C "$repo_dir" rev-parse --verify --quiet "refs/tags/${wanted}" >/dev/null; then
    echo "$wanted"
    return
  fi

  echo "Could not resolve tag for version ${wanted} in ${repo_dir}" >&2
  exit 1
}

generate_property_value() {
  local key="$1"

  case "$key" in
    *.subscription_id)
      echo "00000000-0000-0000-0000-000000000000"
      ;;
    *.role_assignment_id)
      echo "00000000-0000-0000-0000-000000000001"
      ;;
    *.module_name)
      echo "main"
      ;;
    *.resource_group_name)
      echo "rg-avm-ci"
      ;;
    *.parent_id)
      echo "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-avm-ci"
      ;;
    *_name|*_name_*)
      echo "ci-${key##*.}"
      ;;
    *)
      echo "ci-value"
      ;;
  esac
}

collect_gradle_props() {
  mapfile -t placeholders < <(
    grep -oE '\$\{[a-zA-Z0-9_.:-]+\}' "$RECIPE_FILE" \
      | sed -E 's/^\$\{//; s/\}$//' \
      | awk -F: '{print $1":"$2}' \
      | awk '!seen[$0]++' || true
  )

  local item key default value
  for item in "${placeholders[@]}"; do
    key="${item%%:*}"
    default=""

    if [[ "$item" == *:* ]]; then
      default="${item#*:}"
    fi

    if [[ -n "$default" ]]; then
      value="$default"
    else
      value="$(generate_property_value "$key")"
    fi

    GRADLE_PROPS+=("-D${key}=${value}")
  done
}

validate_patch() {
  local patch_path="$1"
  local expected_path_fragment="$2"
  local expected_new_version="$3"

  if [[ ! -f "$patch_path" ]]; then
    echo "rewrite.patch not found at ${patch_path}" >&2
    exit 1
  fi

  if [[ ! -s "$patch_path" ]]; then
    echo "rewrite.patch is empty for ${RECIPE_FILE}" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_path_fragment" "$patch_path"; then
    echo "rewrite.patch does not contain expected path fragment: ${expected_path_fragment}" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_new_version" "$patch_path"; then
    echo "rewrite.patch does not contain expected target version: ${expected_new_version}" >&2
    exit 1
  fi
}

prepare_example_for_recipe() {
  local example_dir="$1"
  local recipe_source="$2"
  local recipe_version="$3"
  local touched=0
  local tf_file tmp_file

  while IFS= read -r -d '' tf_file; do
    tmp_file="${tf_file}.tmp"

    awk -v sourceValue="$recipe_source" -v versionValue="$recipe_version" '
      {
        if (!replaced && $0 ~ /^[[:space:]]*source[[:space:]]*=[[:space:]]*"\.\.\/\.\.\/?"[[:space:]]*$/) {
          sub(/"\.\.\/\.\.\/?"/, "\"" sourceValue "\"")
          print
          print "  version = \"" versionValue "\""
          replaced = 1
          changed = 1
          next
        }

        print
      }

      END {
        if (changed) {
          exit 42
        }
      }
    ' "$tf_file" > "$tmp_file" || awk_exit=$?

    awk_exit=${awk_exit:-0}
    if [[ "$awk_exit" -eq 42 ]]; then
      mv "$tmp_file" "$tf_file"
      touched=1
    elif [[ "$awk_exit" -eq 0 ]]; then
      rm -f "$tmp_file"
    else
      rm -f "$tmp_file"
      echo "Failed to prepare example file ${tf_file}" >&2
      exit 1
    fi

    unset awk_exit
  done < <(find "$example_dir" -maxdepth 2 -type f -name '*.tf' -print0)

  if [[ "$touched" -eq 0 ]]; then
    echo "No local module source ('../../') found under ${example_dir}" >&2
    exit 1
  fi
}

RECIPE_NAME="$(extract_recipe_name)"
if [[ -z "$RECIPE_NAME" ]]; then
  echo "Could not extract recipe name from $RECIPE_FILE"
  exit 1
fi

MODULE_SOURCE="$(extract_change_module_version_field source)"
FROM_VERSION_RAW="$(extract_change_module_version_field version)"
TO_VERSION_RAW="$(extract_change_module_version_field newVersion)"

if [[ -z "$MODULE_SOURCE" || -z "$FROM_VERSION_RAW" || -z "$TO_VERSION_RAW" ]]; then
  echo "Could not extract ChangeModuleVersion source/version/newVersion from $RECIPE_FILE"
  exit 1
fi

FROM_VERSION="$(normalize_version "$FROM_VERSION_RAW")"
TO_VERSION="$(normalize_version "$TO_VERSION_RAW")"
REPO_PATH="${MODULE_SOURCE%/azurerm}"
MODULE_REPO="$(resolve_module_repo_url "$REPO_PATH")"
MODULE_SLUG="$(basename "$MODULE_REPO" .git)"
MODULE_DIR="$WORK_DIR/$MODULE_SLUG"
EXAMPLE_DIR="$MODULE_DIR/examples/default"
RECIPE_ID="$(sanitize_id "$(basename "$RECIPE_FILE" .yaml)")"
RUN_LOG="$REPORT_DIR/${RECIPE_ID}.log"
REPORT_PATCH="$REPORT_DIR/${RECIPE_ID}.patch"
SUMMARY_FILE="$REPORT_DIR/${RECIPE_ID}.summary.txt"

rm -rf "$MODULE_DIR"

log "Cloning ${MODULE_REPO}"
git clone --quiet "$MODULE_REPO" "$MODULE_DIR"

TAG="$(resolve_tag "$MODULE_DIR" "$FROM_VERSION")"
log "Checking out ${TAG}"
git -C "$MODULE_DIR" checkout --quiet "$TAG"

if [[ ! -d "$EXAMPLE_DIR" ]]; then
  echo "Missing examples/default in ${MODULE_DIR}" >&2
  exit 1
fi

prepare_example_for_recipe "$EXAMPLE_DIR" "$MODULE_SOURCE" "$FROM_VERSION_RAW"

if [[ "${ENABLE_TOFU_PLAN:-false}" == "true" ]]; then
  if [[ -z "${ARM_CLIENT_ID:-}" || -z "${ARM_CLIENT_SECRET:-}" || -z "${ARM_TENANT_ID:-}" || -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
    log "WARN: ENABLE_TOFU_PLAN=true but ARM_* secrets are missing; continuing without plan checks"
  fi
fi

GRADLE_PROPS=()
collect_gradle_props

rm -f "$PATCH_FILE"

log "Running rewriteDryRun for ${RECIPE_NAME}"
./gradlew rewriteDryRun -Drewrite.activeRecipes="$RECIPE_NAME" "${GRADLE_PROPS[@]}" | tee "$RUN_LOG"

validate_patch "$PATCH_FILE" "$MODULE_SLUG/examples/default" "$TO_VERSION"

cp "$PATCH_FILE" "$REPORT_PATCH"

cat > "$SUMMARY_FILE" <<EOF
recipe_file=$RECIPE_FILE
recipe_name=$RECIPE_NAME
module_repo=$MODULE_REPO
source_tag=$TAG
from_version=$FROM_VERSION
to_version=$TO_VERSION
example_dir=$EXAMPLE_DIR
result=PASS
EOF

log "Recipe test passed for ${RECIPE_FILE}"
log "Artifacts: ${RUN_LOG}, ${REPORT_PATCH}, ${SUMMARY_FILE}"

#!/usr/bin/env bash
# Posts or updates a single "sticky" PR comment from a body file.
#
# A previous run's comment is identified by an HTML marker inside its body.
# On a re-run we PATCH that comment instead of appending a new one, so the
# PR doesn't accumulate one Meldoc comment per push.
#
# After posting, the script reads a `<!-- meldoc-status:... -->` marker from
# the body to expose a `status` step output (clean | findings | unknown) and,
# when STRICT=true, exits non-zero on `findings`.
#
# Required env:
#   PR_NUMBER, REPO (owner/repo), BODY_FILE, GH_TOKEN
# Optional env:
#   MARKER (default: "<!-- meldoc-review:v1 -->")
#   STRICT (default: "false") — exit 1 if status is "findings"

set -euo pipefail

: "${PR_NUMBER:?PR_NUMBER is required}"
: "${REPO:?REPO is required}"
: "${BODY_FILE:?BODY_FILE is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"
MARKER="${MARKER:-<!-- meldoc-review:v1 -->}"
STRICT="${STRICT:-false}"

emit_status() {
  local status="$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "status=${status}" >> "$GITHUB_OUTPUT"
  fi
  echo "Meldoc status: ${status}"
}

if [ ! -s "$BODY_FILE" ]; then
  echo "::notice title=Meldoc Review::No comment to post (body file missing or empty: $BODY_FILE)"
  emit_status "unknown"
  exit 0
fi

# Safety net: if the model forgot the marker, prepend it so the next run can find this comment.
if ! grep -qF "$MARKER" "$BODY_FILE"; then
  echo "::warning title=Meldoc Review::Body did not contain the sticky marker — prepending it."
  printf '%s\n\n' "$MARKER" | cat - "$BODY_FILE" > "${BODY_FILE}.tmp"
  mv "${BODY_FILE}.tmp" "$BODY_FILE"
fi

EXISTING_ID="$(
  gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
    --jq "[.[] | select(.body | contains(\"${MARKER}\")) | .id] | first // empty" \
    2>/dev/null || true
)"

if [ -n "$EXISTING_ID" ]; then
  echo "Updating sticky Meldoc comment ${EXISTING_ID} on ${REPO}#${PR_NUMBER}"
  jq -Rs '{body: .}' < "$BODY_FILE" \
    | gh api -X PATCH "repos/${REPO}/issues/comments/${EXISTING_ID}" --input - >/dev/null
else
  echo "Creating sticky Meldoc comment on ${REPO}#${PR_NUMBER}"
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$BODY_FILE" >/dev/null
fi

echo "::notice title=Meldoc Review::Comment posted on ${REPO}#${PR_NUMBER}"

# Detect status from the body and expose it as a step output.
STATUS="unknown"
if grep -qF '<!-- meldoc-status:findings -->' "$BODY_FILE"; then
  STATUS="findings"
elif grep -qF '<!-- meldoc-status:clean -->' "$BODY_FILE"; then
  STATUS="clean"
fi
emit_status "$STATUS"

if [ "$STATUS" = "unknown" ]; then
  echo "::warning title=Meldoc Review::Could not detect status marker in the comment body; the 'status' output will be 'unknown' and strict mode will not gate this run."
fi

if [ "$STRICT" = "true" ] && [ "$STATUS" = "findings" ]; then
  echo "::error title=Meldoc Review::Strict mode: findings detected — failing the job. The sticky comment above lists what to address."
  exit 1
fi

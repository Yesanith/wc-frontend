#!/usr/bin/env bash
# keeps what a run wants kept (what a failure said, what a browser saw, a preview) in the private bucket "ci" of the Supabase
# project, never as an artifact of github, whose small storage fills and then stops every run that uploads one. the last
# $KEEP of each kind are kept and the older ones dropped. it never fails the run it is in: when it cannot keep, it says so
#
#   ci/keep.sh <kind> <path>...     for example: ci/keep.sh smoke "$RUNNER_TEMP/smoke.log" e2e/test-results
#
# what it needs, as secrets of the repository (Supabase dashboard, Storage, S3 configuration, Access keys):
#   SUPABASE_URL             the address of the project, the app has it already
#   SUPABASE_S3_KEY_ID       an S3 access key of the project. it opens storage only, not the database
#   SUPABASE_S3_SECRET       its secret
#   SUPABASE_S3_REGION       the region the same page shows, for example eu-central-1
set -uo pipefail

kind="${1:?the kind of what is kept: check, build, smoke or preview}"
shift
BUCKET="${CI_BUCKET:-ci}"
KEEP="${KEEP:-10}"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_S3_KEY_ID:-}" ] || [ -z "${SUPABASE_S3_SECRET:-}" ] || [ -z "${SUPABASE_S3_REGION:-}" ]; then
  echo "::warning::Nothing kept: the secrets SUPABASE_S3_KEY_ID, SUPABASE_S3_SECRET and SUPABASE_S3_REGION are not all set"
  exit 0
fi

paths=()
for p in "$@"; do [ -e "$p" ] && paths+=("$p"); done
if [ "${#paths[@]}" -eq 0 ]; then
  echo "nothing to keep"
  exit 0
fi

export AWS_ACCESS_KEY_ID="$SUPABASE_S3_KEY_ID" AWS_SECRET_ACCESS_KEY="$SUPABASE_S3_SECRET" AWS_DEFAULT_REGION="$SUPABASE_S3_REGION"
# the checksums newer clients add on their own are not all understood by storage that speaks S3
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
endpoint="${SUPABASE_URL%/}/storage/v1/s3"
s3() { aws --endpoint-url "$endpoint" "$@"; }

# the name starts with the date and time, so that the names sort as the runs came
name="$(date -u +%Y-%m-%dT%H%M%S)-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}.tar.gz"
archive="${RUNNER_TEMP:-/tmp}/$name"
tar czf "$archive" "${paths[@]}" 2>/dev/null || { echo "::warning::Nothing kept: the files could not be packed"; exit 0; }

# private, and made the first time; when it is there already this answers so and nothing changes
s3 s3api create-bucket --bucket "$BUCKET" >/dev/null 2>&1 || true

if ! s3 s3 cp --only-show-errors "$archive" "s3://$BUCKET/$kind/$name"; then
  echo "::warning::Nothing kept: the upload to the bucket $BUCKET failed"
  exit 0
fi
echo "kept as $BUCKET/$kind/$name ($(du -h "$archive" | cut -f1)), in the Supabase dashboard under Storage"
{
  echo "### Kept in Supabase"
  echo "\`$BUCKET/$kind/$name\`, under Storage in the dashboard of the project"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

# all but the newest $KEEP of this kind go
old="$(s3 s3 ls "s3://$BUCKET/$kind/" 2>/dev/null | awk '{print $NF}' | grep '\.tar\.gz$' | sort | head -n "-$KEEP")"
for o in $old; do
  s3 s3 rm --only-show-errors "s3://$BUCKET/$kind/$o" && echo "dropped $kind/$o"
done
exit 0

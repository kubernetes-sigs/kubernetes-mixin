#!/usr/bin/env bash

# Copyright kubernetes-mixin Authors
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Generate a NOTICE file listing contributors.
# Git history is the source of truth for WHO contributed.
# GitHub API is used only to map git emails to GitHub handles and fetch real names.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTICE_FILE="${REPO_ROOT}/NOTICE"
GITHUB_REPO="kubernetes-sigs/kubernetes-mixin"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "⚠️  Warning: GITHUB_TOKEN not set. API calls will be rate-limited (60/hr)." >&2
  echo "     Set GITHUB_TOKEN for full functionality (5000/hr)." >&2
  echo "" >&2
fi

# Fetch all commits from GitHub API and output "email|github_login" pairs
# for commits where the email is linked to a GitHub account.
fetch_email_to_login_mapping() {
  local page=1
  while true; do
    local response
    response=$(curl -s \
      -H "Accept: application/vnd.github.v3+json" \
      ${GITHUB_TOKEN:+-H "Authorization: token $GITHUB_TOKEN"} \
      "https://api.github.com/repos/${GITHUB_REPO}/commits?per_page=100&page=${page}")

    if echo "$response" | jq -e 'type == "object" and has("message")' &>/dev/null; then
      echo "Error from GitHub commits API: $(echo "$response" | jq -r '.message')" >&2
      return 1
    fi

    local count
    count=$(echo "$response" | jq 'length')
    if [[ $count -eq 0 ]]; then
      break
    fi

    # Output: git_email|github_login (only when github user is linked)
    echo "$response" | jq -r '.[] | select(.author != null and .commit.author.email != null) | "\(.commit.author.email)|\(.author.login)"'

    if [[ $count -lt 100 ]]; then
      break
    fi
    ((page++))
  done
}

# Fetch real names for handles using GraphQL (batched up to 50 per request)
fetch_names_via_graphql() {
  local -a handles=("$@")
  local batch_size=50

  for ((i = 0; i < ${#handles[@]}; i += batch_size)); do
    local batch=("${handles[@]:i:batch_size}")
    local query="query {"

    for j in "${!batch[@]}"; do
      local handle="${batch[$j]}"
      local alias="user_${handle//[^a-zA-Z0-9_]/_}"
      query+=" $alias: user(login: \"$handle\") { name login }"
    done

    query+=" }"

    local response
    response=$(curl -s \
      ${GITHUB_TOKEN:+-H "Authorization: token $GITHUB_TOKEN"} \
      -H "Content-Type: application/json" \
      -d "{\"query\": $(echo "$query" | jq -Rs .)}" \
      https://api.github.com/graphql)

    if echo "$response" | jq -e '.errors' &>/dev/null; then
      local error_msg
      error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
      echo "Warning: GraphQL error: $error_msg" >&2
      continue
    fi

    # Output: login|name (only when name is non-null)
    echo "$response" | jq -r '.data | to_entries[] | select(.value != null and .value.name != null) | "\(.value.login)|\(.value.name)"' 2>/dev/null || true
  done
}

# Step 1: Build email → github_login mapping from GitHub commits API
echo "Fetching commits from GitHub API to map emails to GitHub handles..." >&2
declare -A email_to_login=()
while IFS='|' read -r email login; do
  if [[ -n "$login" && -n "$email" ]]; then
    email_to_login["$email"]="$login"
  fi
done < <(fetch_email_to_login_mapping)
echo "Built mapping for ${#email_to_login[@]} emails" >&2

# Step 2: Iterate git history and resolve each author to a GitHub handle
echo "Reading git history..." >&2
declare -A handle_to_name=()
declare -A anon_names=()

while IFS='|' read -r name email; do
  # Skip bots
  if [[ -z "$name" ]] || [[ "$name" =~ ^(bot|renovate|dependabot|GitHub|Renovate) ]]; then
    continue
  fi

  # Determine GitHub handle for this author
  handle=""
  if [[ "$email" == *"@users.noreply.github.com" ]]; then
    # Extract handle from GitHub noreply email
    email_user="${email%%@*}"
    if [[ "$email_user" == *"+"* ]]; then
      handle="${email_user##*+}"
    else
      handle="$email_user"
    fi
  elif [[ -v "email_to_login[$email]" ]]; then
    # Look up handle from email-to-login mapping
    handle="${email_to_login[$email]}"
  fi

  if [[ -n "$handle" ]]; then
    # Skip bot handles
    if [[ "$handle" =~ \[bot\]$ ]]; then
      continue
    fi
    # Record the git name (don't overwrite if already set)
    if [[ ! -v "handle_to_name[$handle]" ]]; then
      handle_to_name["$handle"]="$name"
    fi
  else
    # No GitHub handle found - track as anonymous contributor (dedup by name)
    anon_names["$name"]=1
  fi
done < <(git -C "$REPO_ROOT" log --all --format="%aN|%aE" | sort -u)

echo "Found ${#handle_to_name[@]} unique contributors with GitHub handles" >&2

# Remove anonymous entries whose name matches an already-known handle's name
declare -A known_names=()
for handle in "${!handle_to_name[@]}"; do
  known_names["${handle_to_name[$handle]}"]=1
done
for name in "${!anon_names[@]}"; do
  if [[ -v "known_names[$name]" ]]; then
    unset 'anon_names[$name]'
  fi
done

echo "Found ${#anon_names[@]} contributors without linked GitHub accounts" >&2

# Step 3: Enrich names via GraphQL
echo "Looking up real names via GraphQL..." >&2
declare -a all_handles=("${!handle_to_name[@]}")
while IFS='|' read -r handle name; do
  if [[ -n "$name" ]]; then
    handle_to_name["$handle"]="$name"
  fi
done < <(fetch_names_via_graphql "${all_handles[@]}")

# Step 4: Write NOTICE file
cat > "$NOTICE_FILE" << 'EOF'
When donating the kubernetes-mixin project to the CNCF, we could not reach all the
kubernetes-mixin contributors to sign the CNCF CLA. As such, according to the CNCF rules
to donate a repository, we must add a NOTICE referencing section 7 of the CLA
with a list of developers who could not be reached.

`7. Should You wish to submit work that is not Your original creation, You may
submit it to the Foundation separately from any Contribution, identifying the
complete details of its source and of any license or other restriction
(including, but not limited to, related patents, trademarks, and license
agreements) of which you are personally aware, and conspicuously marking the
work as "Submitted on behalf of a third-party: [named here]".`

EOF

{
  for handle in "${!handle_to_name[@]}"; do
    echo "Submitted on behalf of a third-party: @${handle} (${handle_to_name[$handle]})"
  done
  for name in "${!anon_names[@]}"; do
    echo "Submitted on behalf of a third-party: ${name} (GitHub handle unknown)"
  done
} | sort -uVf >> "$NOTICE_FILE"

final_count=$(grep -c "^Submitted on behalf" "$NOTICE_FILE")
echo "✓ Wrote $final_count entries to NOTICE file" >&2

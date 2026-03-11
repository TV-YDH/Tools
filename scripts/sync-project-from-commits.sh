#!/usr/bin/env bash
# Sync last 10 commits to TV-YDH's Tools Project.
# Adds new commits as draft issues, moves items through statuses (In Progress → Todo → Done).
#
# Runs via GitHub Action (or manually with GH_TOKEN=your_pat).
# Project: https://github.com/users/TV-YDH/projects/3

set -e
REPO="TV-YDH/Tools"

if [[ -z "$GH_TOKEN" ]]; then
  echo "::error::PROJECT_PAT not set. Add PROJECT_PAT secret (Settings → Secrets → Actions) and run the workflow."
  exit 1
fi

# 1. Find Tools project (matches "Tools" or "Privacy Law Monitor")
echo "Finding project..."
PROJECT_JSON=$(gh api graphql -f query='
  query {
    user(login: "TV-YDH") {
      projectsV2(first: 20) {
        nodes {
          id
          number
          title
          fields(first: 20) {
            nodes {
              ... on ProjectV2SingleSelectField {
                id
                name
                options { id name }
              }
            }
          }
        }
      }
    }
  }
' 2>/dev/null) || { echo "::error::Failed to fetch projects"; exit 1; }

PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r '.data.user.projectsV2.nodes[] | select(.title | test("Tools|Privacy Law Monitor"; "i")) | .id' | head -1)
PROJECT_NUM=$(echo "$PROJECT_JSON" | jq -r '.data.user.projectsV2.nodes[] | select(.title | test("Tools|Privacy Law Monitor"; "i")) | .number' | head -1)

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "null" ]]; then
  echo "::error::Tools project not found. Create a project at github.com/users/TV-YDH/projects"
  exit 1
fi

# 2. Get Status field and options (match project by Tools or Privacy Law Monitor)
PROJECT_MATCH='.data.user.projectsV2.nodes[] | select(.title | test("Tools|Privacy Law Monitor"; "i"))'
STATUS_FIELD_ID=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .id")
TODO_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"Todo\" or .name == \"Backlog\") | .id" | head -1)
INPROG_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"In Progress\" or .name == \"In progress\") | .id" | head -1)
DONE_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"Done\" or .name == \"Complete\") | .id" | head -1)

[[ -z "$TODO_OPT" || "$TODO_OPT" == "null" ]] && TODO_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[0].id")
[[ -z "$INPROG_OPT" || "$INPROG_OPT" == "null" ]] && INPROG_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[1].id")
[[ -z "$DONE_OPT" || "$DONE_OPT" == "null" ]] && DONE_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[-1].id")

if [[ -z "$STATUS_FIELD_ID" || "$STATUS_FIELD_ID" == "null" ]]; then
  echo "::error::Status field not found. Add a Status field with Todo, In Progress, Done."
  exit 1
fi

echo "Project: $PROJECT_NUM | Status field: $STATUS_FIELD_ID"

# 3. Get last 10 commits
echo "Getting last 10 commits..."
COMMITS=$(git log -10 --format="%h|%s|%ci" | while IFS='|' read -r hash subj date; do echo "${hash}|${subj}|${date:0:10}"; done)

# 4. Get existing project items
echo "Fetching existing project items..."
ITEMS_JSON=$(gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            content {
              ... on DraftIssue {
                title
                body
              }
            }
          }
        }
      }
    }
  }
' -f projectId="$PROJECT_ID" 2>/dev/null) || true

# 5. Add missing commits as draft issues
declare -A HASH_TO_ITEM
while IFS='|' read -r hash subj date; do
  [[ -z "$hash" ]] && continue
  EXISTING=$(echo "$ITEMS_JSON" | jq -r --arg h "$hash" '
    .data.node.items.nodes[] |
    select(.content.body != null and (.content.body | contains("Commit: " + $h))) |
    .id
  ' 2>/dev/null | head -1)
  if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
    HASH_TO_ITEM[$hash]=$EXISTING
    echo "  Exists: $hash - $subj"
  else
    BODY="Commit: $hash
Date: $date
https://github.com/$REPO/commit/$hash"
    NEW_ID=$(gh api graphql -f query='
      mutation($projectId: ID!, $title: String!, $body: String!) {
        addProjectV2DraftIssue(input: { projectId: $projectId, title: $title, body: $body }) {
          projectItem { id }
        }
      }
    ' -f projectId="$PROJECT_ID" -f title="$subj" -f body="$BODY" --jq '.data.addProjectV2DraftIssue.projectItem.id' 2>/dev/null) || true
    if [[ -n "$NEW_ID" && "$NEW_ID" != "null" ]]; then
      HASH_TO_ITEM[$hash]=$NEW_ID
      echo "  Added: $hash - $subj"
    fi
  fi
done <<< "$COMMITS"

# 6. Build ordered list (newest first)
ORDERED_ITEMS=()
while IFS='|' read -r hash _; do
  [[ -z "$hash" ]] && continue
  [[ -n "${HASH_TO_ITEM[$hash]:-}" ]] && ORDERED_ITEMS+=("${HASH_TO_ITEM[$hash]}")
done <<< "$COMMITS"

# 7. Update statuses: 1-2 = In Progress, 3-5 = Todo, 6+ = Done
echo "Updating statuses..."
for i in "${!ORDERED_ITEMS[@]}"; do
  ITEM_ID="${ORDERED_ITEMS[$i]}"
  IDX=$((i + 1))
  if [[ $IDX -le 2 ]]; then OPT_ID="$INPROG_OPT"; STATUS="In Progress"
  elif [[ $IDX -le 5 ]]; then OPT_ID="$TODO_OPT"; STATUS="Todo"
  else OPT_ID="$DONE_OPT"; STATUS="Done"
  fi
  [[ -z "$OPT_ID" || "$OPT_ID" == "null" ]] && continue
  gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }) { projectV2Item { id } }
    }
  ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$STATUS_FIELD_ID" -f optionId="$OPT_ID" --silent 2>/dev/null || true
  echo "  #$IDX -> $STATUS"
done

echo "Done. Project: https://github.com/users/TV-YDH/projects/$PROJECT_NUM"

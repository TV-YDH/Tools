#!/usr/bin/env bash
# Sync commits to TV-YDH's Tools Project.
# Deletes all project items, re-adds as real GitHub Issues, assigns by commit date.
# Iteration 1: Feb 15-28, Iteration 2: Mar 1-14, etc.
#
# Requires: PROJECT_PAT with BOTH project AND repo scopes
# Project: https://github.com/users/TV-YDH/projects/3

set -e
REPO="TV-YDH/Tools"
COMMIT_LIMIT=50
SINCE_DATE="2026-02-15"

if [[ -z "$GH_TOKEN" ]]; then
  echo "::error::PROJECT_PAT not set. Add PROJECT_PAT secret (project + repo scopes) and run the workflow."
  exit 1
fi

# 1. Find Tools project
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
              ... on ProjectV2IterationField {
                id
                name
                configuration {
                  iterations {
                    id
                    startDate
                    duration
                  }
                  completedIterations {
                    id
                    startDate
                    duration
                  }
                }
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
  echo "::error::Tools project not found"
  exit 1
fi

# 2. Get Status and Iteration fields
PROJECT_MATCH='.data.user.projectsV2.nodes[] | select(.title | test("Tools|Privacy Law Monitor"; "i"))'
STATUS_FIELD_ID=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .id")
TODO_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"Todo\" or .name == \"Backlog\") | .id" | head -1)
INPROG_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"In Progress\" or .name == \"In progress\") | .id" | head -1)
DONE_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"Done\" or .name == \"Complete\") | .id" | head -1)

[[ -z "$TODO_OPT" || "$TODO_OPT" == "null" ]] && TODO_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[0].id")
[[ -z "$INPROG_OPT" || "$INPROG_OPT" == "null" ]] && INPROG_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[1].id")
[[ -z "$DONE_OPT" || "$DONE_OPT" == "null" ]] && DONE_OPT=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.name == \"Status\") | .options[-1].id")

if [[ -z "$STATUS_FIELD_ID" || "$STATUS_FIELD_ID" == "null" ]]; then
  echo "::error::Status field not found"
  exit 1
fi

ITERATION_FIELD_ID=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.configuration.iterations != null) | .id" | head -1)
ITERATIONS_DATA=""
if [[ -n "$ITERATION_FIELD_ID" && "$ITERATION_FIELD_ID" != "null" ]]; then
  ITERATIONS_DATA=$(echo "$PROJECT_JSON" | jq -r "$PROJECT_MATCH | .fields.nodes[] | select(.configuration != null) | .configuration | (.iterations[]? // empty), (.completedIterations[]? // empty) | select(.id != null and .startDate != null) | \"\(.id)|\(.startDate)|\(.duration // 14)\"" 2>/dev/null)
  echo "Iteration field: $ITERATION_FIELD_ID"
  if [[ -n "$ITERATIONS_DATA" ]]; then
    echo "Found iterations:"
    echo "$ITERATIONS_DATA" | while IFS='|' read -r id start dur; do echo "  - $id: $start (${dur}d)"; done
  fi
fi

echo "Project: $PROJECT_NUM | Status field: $STATUS_FIELD_ID"

# 3. Get commits since Feb 15, 2026
echo "Getting commits since $SINCE_DATE (up to $COMMIT_LIMIT)..."
COMMITS=$(git log --since="$SINCE_DATE" -$COMMIT_LIMIT --format="%h|%s|%ci" | while IFS='|' read -r hash subj date; do echo "${hash}|${subj}|${date:0:10}"; done)

# 4. Fetch existing project items and build hash -> issue node_id map (for re-adding after delete)
echo "Fetching existing project items..."
ITEMS_JSON=$(gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            content {
              __typename
              ... on Issue { id body }
              ... on DraftIssue { body }
            }
          }
        }
      }
    }
  }
' -f projectId="$PROJECT_ID" 2>/dev/null) || true

# 5. Build hash -> issue node_id map from existing items (for reuse after delete)
HASH_NODE_MAP=$(mktemp)
trap "rm -f $HASH_NODE_MAP" EXIT
echo "$ITEMS_JSON" | jq -r '
  .data.node.items.nodes[]? |
  select(.content.__typename == "Issue" and .content.body != null) |
  (.content.body | split("Commit: ")[1] | split("\n")[0] | split(" ")[0]) as $hash |
  .content.id as $nid |
  select($hash != null and $hash != "") |
  "\($hash)|\($nid)"
' 2>/dev/null | while IFS='|' read -r h nid; do
  [[ -n "$h" && -n "$nid" ]] && echo "$h|$nid" >> "$HASH_NODE_MAP"
done

# 6. Delete ALL project items
echo "Deleting all project items..."
echo "$ITEMS_JSON" | jq -r '.data.node.items.nodes[]? | .id' 2>/dev/null | while read -r ITEM_ID; do
  [[ -z "$ITEM_ID" || "$ITEM_ID" == "null" ]] && continue
  gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!) {
      deleteProjectV2Item(input: { projectId: $projectId, itemId: $itemId }) { deletedItemId }
    }
  ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" --silent 2>/dev/null || true
  echo "  Deleted item"
done
echo "  All items removed from project"

# 7. Add each commit as real issue (reuse existing or create new) and add to project
declare -A HASH_TO_ITEM
while IFS='|' read -r hash subj date; do
  [[ -z "$hash" ]] && continue
  BODY="Commit: $hash
Date: $date
https://github.com/$REPO/commit/$hash"
  ISSUE_NODE_ID=$(grep "^${hash}|" "$HASH_NODE_MAP" 2>/dev/null | cut -d'|' -f2 | head -1)
  if [[ -z "$ISSUE_NODE_ID" ]]; then
    ISSUE_NODE_ID=$(gh api "repos/$REPO/issues" -X POST -f title="$subj" -f body="$BODY" --jq '.node_id' 2>/dev/null) || true
    [[ -n "$ISSUE_NODE_ID" ]] && echo "  Created: $hash - $subj"
  else
    echo "  Reusing: $hash - $subj"
  fi
  if [[ -n "$ISSUE_NODE_ID" && "$ISSUE_NODE_ID" != "null" ]]; then
    NEW_ID=$(gh api graphql -f query='
      mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
          item { id }
        }
      }
    ' -f projectId="$PROJECT_ID" -f contentId="$ISSUE_NODE_ID" --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null) || true
    if [[ -n "$NEW_ID" && "$NEW_ID" != "null" ]]; then
      HASH_TO_ITEM[$hash]=$NEW_ID
    fi
  fi
done <<< "$COMMITS"

# 8. Build ordered list (newest first)
ORDERED_ITEMS=()
while IFS='|' read -r hash _; do
  [[ -z "$hash" ]] && continue
  [[ -n "${HASH_TO_ITEM[$hash]:-}" ]] && ORDERED_ITEMS+=("${HASH_TO_ITEM[$hash]}")
done <<< "$COMMITS"

# 9. Update statuses: 1-3 In Progress, 4-10 Todo, 11+ Done
echo "Updating statuses..."
for i in "${!ORDERED_ITEMS[@]}"; do
  ITEM_ID="${ORDERED_ITEMS[$i]}"
  IDX=$((i + 1))
  if [[ $IDX -le 3 ]]; then OPT_ID="$INPROG_OPT"; STATUS="In Progress"
  elif [[ $IDX -le 10 ]]; then OPT_ID="$TODO_OPT"; STATUS="Todo"
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

# 10. Assign each item to iteration by commit date (Iteration 1: Feb 15-28, Iteration 2: Mar 1-14, etc.)
if [[ -n "$ITERATION_FIELD_ID" && "$ITERATION_FIELD_ID" != "null" && -n "$ITERATIONS_DATA" ]]; then
  echo "Assigning items to sprints by commit date..."
  ASSIGNED=0
  NO_MATCH=0
  while IFS='|' read -r hash subj date; do
    [[ -z "$hash" ]] && continue
    ITEM_ID="${HASH_TO_ITEM[$hash]:-}"
    [[ -z "$ITEM_ID" ]] && continue
    ITER_ID=""
    while IFS='|' read -r iter_id start_date duration; do
      [[ -z "$iter_id" || "$iter_id" == "null" ]] && continue
      [[ -z "$duration" ]] && duration=14
      [[ -z "$start_date" || "$start_date" == "null" ]] && continue
      END_DATE=$(date -d "$start_date +${duration} days" +%Y-%m-%d 2>/dev/null)
      if [[ -n "$END_DATE" && -n "$start_date" ]]; then
        if [[ ( "$date" == "$start_date" || "$date" > "$start_date" ) && "$date" < "$END_DATE" ]]; then
          ITER_ID="$iter_id"
          break
        fi
      fi
    done <<< "$ITERATIONS_DATA"
    if [[ -n "$ITER_ID" && "$ITER_ID" != "null" ]]; then
      gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId
            itemId: $itemId
            fieldId: $fieldId
            value: { iterationId: $iterationId }
          }) { projectV2Item { id } }
        }
      ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$ITERATION_FIELD_ID" -f iterationId="$ITER_ID" --silent 2>/dev/null || true
      ASSIGNED=$((ASSIGNED + 1))
      echo "  $date $hash -> assigned"
    else
      NO_MATCH=$((NO_MATCH + 1))
      echo "  $date $hash -> no matching iteration"
    fi
  done <<< "$COMMITS"
  echo "  Assigned $ASSIGNED items to sprints, $NO_MATCH had no matching iteration"
fi

echo "Done. Project: https://github.com/users/TV-YDH/projects/$PROJECT_NUM"

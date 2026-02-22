#!/bin/bash
# resolve-pr-comments.sh — List, reply to, and resolve PR review comments
#
# Usage:
#   ./scripts/resolve-pr-comments.sh <PR#> list                          # List unresolved threads
#   ./scripts/resolve-pr-comments.sh <PR#> list-all                      # List ALL threads (including resolved)
#   ./scripts/resolve-pr-comments.sh <PR#> reply <index> "message"       # Reply + resolve thread
#   ./scripts/resolve-pr-comments.sh <PR#> resolve <index>               # Resolve thread (no reply)
#   ./scripts/resolve-pr-comments.sh <PR#> resolve-all                   # Resolve ALL unresolved threads
#
# Requires: gh CLI authenticated with repo access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Helpers ---

usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 <PR#> list                       List unresolved review threads"
    echo "  $0 <PR#> list-all                    List ALL review threads (including resolved)"
    echo "  $0 <PR#> reply <index> \"message\"     Reply to thread and resolve it"
    echo "  $0 <PR#> resolve <index>             Resolve thread without replying"
    echo "  $0 <PR#> resolve-all                 Resolve ALL unresolved threads"
    exit 1
}

get_repo() {
    gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || {
        echo -e "${RED}Error: Could not detect repo. Run from a git repo with gh configured.${NC}" >&2
        exit 1
    }
}

# Fetch all review threads as JSON array
# Each element: { id, isResolved, restCommentId, author, path, line, body }
fetch_threads() {
    local pr_number="$1"
    local repo
    repo=$(get_repo)
    local owner="${repo%/*}"
    local name="${repo#*/}"

    gh api graphql -f query="
    {
      repository(owner: \"$owner\", name: \"$name\") {
        pullRequest(number: $pr_number) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              comments(first: 1) {
                nodes {
                  databaseId
                  author { login }
                  path
                  line
                  originalLine
                  body
                }
              }
            }
          }
        }
      }
    }" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | {
        id: .id,
        isResolved: .isResolved,
        restCommentId: .comments.nodes[0].databaseId,
        author: .comments.nodes[0].author.login,
        path: .comments.nodes[0].path,
        line: (.comments.nodes[0].line // .comments.nodes[0].originalLine),
        body: .comments.nodes[0].body
    }]'
}

# Resolve a thread by its GraphQL node ID
resolve_thread() {
    local thread_id="$1"
    gh api graphql -f query="
    mutation {
      resolveReviewThread(input: {threadId: \"$thread_id\"}) {
        thread { isResolved }
      }
    }" --jq '.data.resolveReviewThread.thread.isResolved' 2>/dev/null
}

# Reply to a comment by its REST database ID
reply_to_comment() {
    local pr_number="$1"
    local comment_id="$2"
    local message="$3"
    local repo
    repo=$(get_repo)

    gh api "repos/$repo/pulls/$pr_number/comments/$comment_id/replies" \
        -f body="$message" --jq '.id' 2>/dev/null
}

# Truncate string to max length with ellipsis
truncate() {
    local str="$1"
    local max="${2:-100}"
    # Remove newlines for display
    str=$(echo "$str" | tr '\n' ' ' | sed 's/  */ /g')
    if [ "${#str}" -gt "$max" ]; then
        echo "${str:0:$max}..."
    else
        echo "$str"
    fi
}

# --- Commands ---

cmd_list() {
    local pr_number="$1"
    local show_resolved="${2:-false}"
    local threads
    threads=$(fetch_threads "$pr_number")

    local count
    count=$(echo "$threads" | jq 'length')

    if [ "$count" -eq 0 ]; then
        echo -e "${DIM}No review threads found on PR #$pr_number.${NC}"
        return
    fi

    local idx=0
    local shown=0

    echo -e "${BOLD}Review threads on PR #$pr_number:${NC}"
    echo ""

    while [ "$idx" -lt "$count" ]; do
        local resolved author path line body
        resolved=$(echo "$threads" | jq -r ".[$idx].isResolved")
        author=$(echo "$threads" | jq -r ".[$idx].author")
        path=$(echo "$threads" | jq -r ".[$idx].path")
        line=$(echo "$threads" | jq -r ".[$idx].line")
        body=$(echo "$threads" | jq -r ".[$idx].body")

        if [ "$show_resolved" = "false" ] && [ "$resolved" = "true" ]; then
            idx=$((idx + 1))
            continue
        fi

        local status_icon status_color
        if [ "$resolved" = "true" ]; then
            status_icon="[resolved]"
            status_color="$DIM"
        else
            status_icon="[open]"
            status_color="$YELLOW"
        fi

        local display_body
        display_body=$(truncate "$body" 120)

        echo -e "  ${CYAN}#$idx${NC}  ${status_color}${status_icon}${NC}  ${BLUE}${author}${NC}  ${path}:${line}"
        echo -e "      ${DIM}${display_body}${NC}"
        echo ""

        shown=$((shown + 1))
        idx=$((idx + 1))
    done

    if [ "$shown" -eq 0 ]; then
        echo -e "  ${GREEN}All threads resolved.${NC}"
    else
        echo -e "${DIM}Showing $shown thread(s). Use index number with 'reply' or 'resolve' commands.${NC}"
    fi
}

cmd_reply() {
    local pr_number="$1"
    local target_idx="$2"
    local message="$3"
    local threads
    threads=$(fetch_threads "$pr_number")

    local count
    count=$(echo "$threads" | jq 'length')

    if [ "$target_idx" -ge "$count" ]; then
        echo -e "${RED}Error: Index #$target_idx out of range (0-$((count - 1)))${NC}" >&2
        exit 1
    fi

    local thread_id rest_id author path line resolved
    thread_id=$(echo "$threads" | jq -r ".[$target_idx].id")
    rest_id=$(echo "$threads" | jq -r ".[$target_idx].restCommentId")
    author=$(echo "$threads" | jq -r ".[$target_idx].author")
    path=$(echo "$threads" | jq -r ".[$target_idx].path")
    line=$(echo "$threads" | jq -r ".[$target_idx].line")
    resolved=$(echo "$threads" | jq -r ".[$target_idx].isResolved")

    if [ "$resolved" = "true" ]; then
        echo -e "${YELLOW}Warning: Thread #$target_idx is already resolved.${NC}"
    fi

    echo -e "${BOLD}Replying to thread #$target_idx${NC} (${BLUE}${author}${NC} on ${path}:${line})..."

    # Post reply
    local reply_id
    reply_id=$(reply_to_comment "$pr_number" "$rest_id" "$message")

    if [ -n "$reply_id" ]; then
        echo -e "  ${GREEN}Reply posted${NC} (comment ID: $reply_id)"
    else
        echo -e "  ${RED}Failed to post reply${NC}" >&2
        exit 1
    fi

    # Resolve thread
    local result
    result=$(resolve_thread "$thread_id")
    if [ "$result" = "true" ]; then
        echo -e "  ${GREEN}Thread resolved${NC}"
    else
        echo -e "  ${YELLOW}Thread may already be resolved${NC}"
    fi
}

cmd_resolve() {
    local pr_number="$1"
    local target_idx="$2"
    local threads
    threads=$(fetch_threads "$pr_number")

    local count
    count=$(echo "$threads" | jq 'length')

    if [ "$target_idx" -ge "$count" ]; then
        echo -e "${RED}Error: Index #$target_idx out of range (0-$((count - 1)))${NC}" >&2
        exit 1
    fi

    local thread_id author path line
    thread_id=$(echo "$threads" | jq -r ".[$target_idx].id")
    author=$(echo "$threads" | jq -r ".[$target_idx].author")
    path=$(echo "$threads" | jq -r ".[$target_idx].path")
    line=$(echo "$threads" | jq -r ".[$target_idx].line")

    echo -e "${BOLD}Resolving thread #$target_idx${NC} (${BLUE}${author}${NC} on ${path}:${line})..."

    local result
    result=$(resolve_thread "$thread_id")
    if [ "$result" = "true" ]; then
        echo -e "  ${GREEN}Thread resolved${NC}"
    else
        echo -e "  ${YELLOW}Thread may already be resolved${NC}"
    fi
}

cmd_resolve_all() {
    local pr_number="$1"
    local threads
    threads=$(fetch_threads "$pr_number")

    local count
    count=$(echo "$threads" | jq 'length')
    local resolved_count=0

    echo -e "${BOLD}Resolving all unresolved threads on PR #$pr_number...${NC}"

    local idx=0
    while [ "$idx" -lt "$count" ]; do
        local resolved thread_id author path line
        resolved=$(echo "$threads" | jq -r ".[$idx].isResolved")

        if [ "$resolved" = "false" ]; then
            thread_id=$(echo "$threads" | jq -r ".[$idx].id")
            author=$(echo "$threads" | jq -r ".[$idx].author")
            path=$(echo "$threads" | jq -r ".[$idx].path")
            line=$(echo "$threads" | jq -r ".[$idx].line")

            local result
            result=$(resolve_thread "$thread_id")
            if [ "$result" = "true" ]; then
                echo -e "  ${GREEN}Resolved${NC} #$idx (${BLUE}${author}${NC} on ${path}:${line})"
                resolved_count=$((resolved_count + 1))
            else
                echo -e "  ${RED}Failed${NC} #$idx" >&2
            fi
        fi

        idx=$((idx + 1))
    done

    if [ "$resolved_count" -eq 0 ]; then
        echo -e "  ${DIM}No unresolved threads found.${NC}"
    else
        echo -e "${GREEN}Resolved $resolved_count thread(s).${NC}"
    fi
}

# --- Main ---

if [ $# -lt 2 ]; then
    usage
fi

PR_NUMBER="$1"
COMMAND="$2"

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR number must be numeric, got '$PR_NUMBER'${NC}" >&2
    usage
fi

case "$COMMAND" in
    list)
        cmd_list "$PR_NUMBER" false
        ;;
    list-all)
        cmd_list "$PR_NUMBER" true
        ;;
    reply)
        if [ $# -lt 4 ]; then
            echo -e "${RED}Error: 'reply' requires an index and message${NC}" >&2
            echo "  Usage: $0 $PR_NUMBER reply <index> \"message\""
            exit 1
        fi
        cmd_reply "$PR_NUMBER" "$3" "$4"
        ;;
    resolve)
        if [ $# -lt 3 ]; then
            echo -e "${RED}Error: 'resolve' requires an index${NC}" >&2
            echo "  Usage: $0 $PR_NUMBER resolve <index>"
            exit 1
        fi
        cmd_resolve "$PR_NUMBER" "$3"
        ;;
    resolve-all)
        cmd_resolve_all "$PR_NUMBER"
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}" >&2
        usage
        ;;
esac

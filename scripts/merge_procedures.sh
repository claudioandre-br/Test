#!/bin/bash -e

###############################################################################
#        _       _             _   _            _____  _
#       | |     | |           | | | |          |  __ \(_)
#       | | ___ | |__  _ __   | |_| |__   ___  | |__) |_ _ __  _ __   ___ _ __
#   _   | |/ _ \| '_ \| '_ \  | __| '_ \ / _ \ |  _  /| | '_ \| '_ \ / _ \ '__|
#  | |__| | (_) | | | | | | | | |_| | | |  __/ | | \ \| | |_) | |_) |  __/ |
#   \____/ \___/|_| |_|_| |_|  \__|_| |_|\___| |_|  \_\_| .__/| .__/ \___|_|
#                                                       | |   | |
#                                                       |_|   |_|
#
# Copyright (c) 2024 Claudio André <dev at claudioandre.slmail.me>
#
# This program comes with ABSOLUTELY NO WARRANTY; express or implied.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, as expressed in version 2, seen at
# http://www.gnu.org/licenses/gpl-2.0.html
###############################################################################
# Script to control the automatic merge process
# More info at https://github.com/openwall/john-packages

MY_MESSAGE=""

if [[ "$REQUEST" != "bot: MERGE"* ]]; then
	echo "There is no need for a merge! Nothing to do."
	exit 0
fi

if [[ "$REQUEST" == "bot: MERGE skip" || "$REQUEST" == "bot: MERGE test" ]]; then
	echo "I'm not validating the PR data in this workflow."
	echo "All GitHub rules still apply."
	MY_MESSAGE="I'm not validating the PR data in this workflow.\n"
	SKIP="true"
fi

if [[ "$REQUEST" == "bot: MERGE test" ]]; then
	echo "Test mode: I'm pretending to create a merge."
	MY_MESSAGE+="No changes will be submitted to GitHub."
	TEST="true"
fi
gh pr checkout "$PR_URL"

REVIEWS_STATUS="$(gh pr status --json latestReviews --jq '.currentBranch.latestReviews[].state == "APPROVED"')"
APPROVALS="$(echo "$REVIEWS_STATUS" | grep -c 'true' || true)"
MERGE_STATUS="$(gh pr status --json mergeStateStatus --jq '.currentBranch.mergeStateStatus == "CLEAN"')"
STATUS="$(echo "$MERGE_STATUS" | grep -c 'true' || true)"

echo "**********************************************************************"
echo -e "Approvals: $APPROVALS"
echo -e "Mergeable: $MERGE_STATUS"
echo -e "$MY_MESSAGE"
echo -e "---------------"
echo -e "Reviews: $REVIEWS_STATUS"
echo "**********************************************************************"

if [[ "$TEST" == 'true' ]]; then
	echo "$(gh pr status --json latestReviews)"
	echo "$(gh pr status --json mergeStateStatus)"
	echo "**********************************************************************"
fi
git config --global user.name "Continuous Integration"
git config --global user.email "username@users.noreply.github.com"
DEST_BRANCH="$BRANCH"

if [[ ("$APPROVALS" -ge 1 && "$STATUS" -eq 1) || "$SKIP" == 'true' || "$TEST" == 'true' ]]; then
	if [[ false == true && "$OWNER" != "openwall" ]]; then
		echo "The PR comes from a fork."
		DEST_BRANCH="$OWNER-$BRANCH"
		git checkout -b "$DEST_BRANCH" main
		git pull "https://github.com/$OWNER/$REPO.git" "$BRANCH"
	else
		git checkout "$DEST_BRANCH"
	fi
	echo "Merging the PR."
	git checkout main
	git merge --ff-only "$DEST_BRANCH" || exit 1

	if [[ "$TEST" != 'true' ]]; then
		git push origin main
	else
		echo "No new data has been submitted to be saved on GitHub."
	fi
	git log -1
else
	echo "PR is not ready for merging! Nothing to do."
	exit 1
fi

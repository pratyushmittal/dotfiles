default:
  just --list

merge-in-main:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	branch_name=$(git branch --show-current)
	git checkout main
	git merge --no-ff ${branch_name}

review:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	status=$(git status --porcelain)
	if [[ -n "$status" ]]; then
	  echo "Please clean the working tree."
	  exit 1
	fi
	source_branch_name=$(git branch --show-current)
	review_branch_name=review-${source_branch_name}
	git pull
	git merge main
	git checkout -b $review_branch_name
	git reset main

finish-review:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	status=$(git status --porcelain)
	if [[ -n "$status" ]]; then
	  echo "Please clean the working tree."
	  exit 1
	fi
	review_branch_name=$(git branch --show-current)
	if [[ ! $review_branch_name =~ ^review- ]]; then
	  echo "Error: Current branch is not a review branch. It should start with review-."
	  exit 1
	fi
	source_branch_name=${review_branch_name:7}
	messages=$(git log --reverse --format=%B main..$review_branch_name)
	git checkout $source_branch_name
	git checkout $review_branch_name . --no-overlay
	if git diff --quiet --cached && git diff --quiet; then
	  echo "No review changes to apply."
	  git branch -D $review_branch_name
	  exit 0
	fi
	printf "%s\n" "$messages" | git commit --file -
	git branch -D $review_branch_name

discard-review:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	branch_name=$(git branch --show-current)
	if [[ ! $branch_name =~ ^review- ]]; then
	  echo "Error: Current branch is not a review branch. It should start with review-."
	  exit 1
	fi
	git restore --staged .
	git restore .
	git checkout main
	git branch -d $branch_name

start-new-python-project-here:
	#!/usr/bin/env bash
	cd {{invocation_directory()}}
	git init .
	touch .gitignore
	echo ".venv\n*.pyc" > .gitignore
	uv venv
	source .venv/bin/activate
	cp ~/Websites/django-cookiecutter/\{\{cookiecutter.project_slug\}\}/.envrc ./
	cp ~/Websites/django-cookiecutter/\{\{cookiecutter.project_slug\}\}/requirements/requirements.in ./
	cp ~/Websites/django-cookiecutter/\{\{cookiecutter.project_slug\}\}/README.md ./

review-origin-main:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	status=$(git status --porcelain)
	if [[ -n "$status" ]]; then
	  echo "Please clean the working tree."
	  exit 1
	fi
	git fetch origin
	base=$(git merge-base main origin/main)
	backup_branch=backup-main-$(date +%Y%m%d-%H%M%S)
	git branch "$backup_branch" main
	git checkout -B origin-main origin/main
	for commit in $(git rev-list --reverse ${base}..main); do
	  git cherry-pick "$commit"
	done
	git checkout -B review-origin-main origin-main
	git reset main
	echo "Review and commit changes on review-origin-main, then run: just --justfile ~/justfile done-review-origin-main"

done-review-origin-main:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	status=$(git status --porcelain)
	if [[ -n "$status" ]]; then
	  echo "Please clean the working tree."
	  exit 1
	fi
	branch_name=$(git branch --show-current)
	# Avoid finalizing from an unrelated branch by mistake.
	if [[ "$branch_name" != "review-origin-main" && "$branch_name" != "origin-main" ]]; then
	  echo "Error: Run this from review-origin-main or origin-main."
	  exit 1
	fi
	if ! git show-ref --verify --quiet refs/heads/origin-main; then
	  echo "Branch origin-main not found."
	  exit 1
	fi
	backup_branch=backup-main-before-origin-main-$(date +%Y%m%d-%H%M%S)
	git branch "$backup_branch" main
	# If run before finish-review, apply the review branch to origin-main first.
	if [[ "$branch_name" == "review-origin-main" ]]; then
	  messages=$(git log --reverse --format=%B main..review-origin-main)
	  git checkout origin-main
	  git checkout review-origin-main . --no-overlay
	  # Commit only when review changed the generated origin-main tree.
	  if ! git diff --quiet --cached || ! git diff --quiet; then
	    # Fallback when the review branch has no commits.
	    if [[ -z "$messages" ]]; then
	      messages="Apply review-origin-main changes"
	    fi
	    printf "%s\n" "$messages" | git commit --file -
	  fi
	fi
	git branch -f main origin-main
	git checkout main
	# Drop temp branches after main points at reviewed origin-main.
	git branch -D review-origin-main 2>/dev/null || true
	git branch -D origin-main 2>/dev/null || true

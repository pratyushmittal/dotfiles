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
	# review-origin branches are based on their local source branch.
	if [[ $review_branch_name =~ ^review-origin- ]]; then
	  source_branch_name=${review_branch_name:14}
	  base_branch_name=$source_branch_name
	elif [[ $review_branch_name =~ ^review- ]]; then
	  source_branch_name=${review_branch_name:7}
	  base_branch_name=main
	else
	  echo "Error: Current branch is not a review branch. It should start with review-."
	  exit 1
	fi
	messages=$(git log --reverse --format=%B "$base_branch_name..$review_branch_name")
	git checkout "$source_branch_name"
	git checkout "$review_branch_name" . --no-overlay
	if git diff --quiet --cached && git diff --quiet; then
	  echo "No review changes to apply."
	  git branch -D "$review_branch_name"
	  exit 0
	fi
	printf "%s\n" "$messages" | git commit --file -
	git branch -D "$review_branch_name"

discard-review:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	branch_name=$(git branch --show-current)
	# review-origin should return to its source branch, not main.
	if [[ $branch_name =~ ^review-origin- ]]; then
	  checkout_branch_name=${branch_name:14}
	elif [[ $branch_name =~ ^review- ]]; then
	  checkout_branch_name=main
	else
	  echo "Error: Current branch is not a review branch. It should start with review-."
	  exit 1
	fi
	git restore --staged .
	git restore .
	# Remove added review files before leaving the review branch.
	git clean -fd
	git checkout "$checkout_branch_name"
	git branch -D "$branch_name"

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

review-origin:
	#!/usr/bin/env bash
	set -euo pipefail
	cd {{invocation_directory()}}
	status=$(git status --porcelain)
	if [[ -n "$status" ]]; then
	  echo "Please clean the working tree."
	  exit 1
	fi
	source_branch_name=$(git branch --show-current)
	# This recipe needs a local branch to compare against origin.
	if [[ -z "$source_branch_name" ]]; then
	  echo "Error: Current checkout is not on a branch."
	  exit 1
	fi
	git fetch origin
	origin_branch_name=origin/${source_branch_name}
	if ! git show-ref --verify --quiet "refs/remotes/${origin_branch_name}"; then
	  echo "Error: Remote branch ${origin_branch_name} not found."
	  exit 1
	fi
	# Avoid showing local-only commits as removals in the review diff.
	if ! git merge-base --is-ancestor "$source_branch_name" "$origin_branch_name"; then
	  echo "Error: ${source_branch_name} is not an ancestor of ${origin_branch_name}."
	  exit 1
	fi
	review_branch_name=review-origin-${source_branch_name}
	git checkout -b "$review_branch_name" "$origin_branch_name"
	git reset "$source_branch_name"
	echo "Review and commit origin changes on ${review_branch_name}, then run: just --justfile ~/justfile finish-review"


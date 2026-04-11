default:
  just --list

merge-in-main:
        #!/usr/bin/env bash
        cd {{invocation_directory()}}
        branch_name=$(git branch --show-current)
        git checkout main
        git merge --no-ff ${branch_name}

review:
        #!/usr/bin/env bash
        cd {{invocation_directory()}}
        source_branch_name=$(git branch --show-current)
        review_branch_name=review-${source_branch_name}
        git pull
        git merge main
        git checkout -b $review_branch_name
        git reset main

finish-review:
        #!/usr/bin/env bash
        cd {{invocation_directory()}}

        # ensure the changes are commited
        status=$(git status)
        if [[ $status != *"working tree clean"* ]]; then
          echo "Please clean the working tree."
          exit
        fi

        # checkout source and merge review
        review_branch_name=$(git branch --show-current)
        # trim "review-" from starting for source branch name
        source_branch_name=${review_branch_name:7}
        messages=$(git log ...main --format=%B)
        git checkout $source_branch_name
        git checkout $review_branch_name . --no-overlay
        echo $messages | git commit --file -
        git branch -D $review_branch_name

discard-review:
        #!/usr/bin/env bash
        cd {{invocation_directory()}}

        # ensure review branch
        branch_name=$(git branch --show-current)

        # Ensure the branch name starts with 'review-'
        if [[ ! $branch_name =~ ^review- ]]; then
                echo "Error: Current branch is not a review branch. It should start with 'review-'."
                exit 1
        fi

        # unstage everything
        git restore --staged .
        # discard everything
        git checkout .

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


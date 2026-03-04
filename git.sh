#!/bin/bash

cd /home/bahl/Desktop/aws

# Add changes to git
echo "Git Adding Files..."

git add .

# Commit changes
echo "Committing..."

git commit -m "adding file"

# Push changes to remote
echo "Pushing..."

git push

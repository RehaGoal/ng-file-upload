#!/bin/bash -xe

echo_error() {
	echo -e "\e[31m$*\e[0m"
}

echo_warning() {
    echo -e "\e[1;33m$*\e[0m"
}

function assert_no_git_changes() {
  if [ -n "$(git status --porcelain)" ]; then
    echo_error >&2 "ERROR: there are changes in the current git repository";
    git status --porcelain
    git diff
    exit 1
  fi
}

function assert_no_unstaged_git_changes() {
  if [ -n "$(git diff --name-status)" ]; then
    echo_error >&2 "ERROR: there are unstaged changes in the current git repository";
    git diff --name-status
    git diff
    exit 1
  fi
}

function assert_tag_does_not_exist() {
  if [ "$(git tag --list "$1")" ]; then
     echo_error "ERROR: Tag '$1' already exists."
     exit 1
  fi
}

function assert_current_branch_name_is() {
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$BRANCH" != "$1" ]]; then
    echo_error "ERROR: Current branch should be '$1'!";
    exit 1;
  fi
}



VERSION=$(jq -r .version package.json)
TAG_VERSION=${VERSION}
ORIGIN="origin"
MASTER_BRANCH="master"
BOWER_BRANCH="bower-release"
TAG_BOWER_VERSION="bower-release-${VERSION}"

echo "Privately releasing ${VERSION}..."

assert_no_git_changes
assert_current_branch_name_is "${MASTER_BRANCH}"
assert_tag_does_not_exist "${TAG_VERSION}"
assert_tag_does_not_exist "${TAG_BOWER_VERSION}"

echo "Running npm install..."
npm install

echo "Building dist files using grunt..."
grunt

echo "Committing new dist files to ${MASTER_BRANCH}..."
git add dist/ demo/
git status
assert_no_unstaged_git_changes
git commit -m "Build dist files using grunt"
echo "Pushing commits to ${ORIGIN}/${MASTER_BRANCH}"
git push -u "${ORIGIN}" "${MASTER_BRANCH}"

echo "Adding tag: ${TAG_VERSION}"
git tag -a "${TAG_VERSION}" -m "Release version ${VERSION}"
echo "Pushing tag to ${ORIGIN}"
git push "${ORIGIN}" "${TAG_VERSION}"

echo "Switching to ${BOWER_BRANCH}"
git checkout "${BOWER_BRANCH}"
echo "Checking out dist files from ${TAG_VERSION}"
git restore --source "${TAG_VERSION}" -- 'dist/*'
mv dist/* .
rmdir dist

echo "Committing new dist files to ${BOWER_BRANCH}"
git commit -a -m "Update dist files from ${TAG_VERSION}."
echo "Pushing commits to ${ORIGIN}/${BOWER_BRANCH}"
git push -u "${ORIGIN}" ${BOWER_BRANCH}

echo "Adding tag: ${TAG_BOWER_VERSION}"
git tag -a "${TAG_BOWER_VERSION}" -m "Release version ${VERSION}"
echo "Pushing tag to ${ORIGIN}"
git push "${ORIGIN}" "${TAG_BOWER_VERSION}"

git checkout ${MASTER_BRANCH}

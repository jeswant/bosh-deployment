#!/bin/bash -eux

tar -xzf release/release.tgz "release.MF"

UPDATE_RELEASE_OPS_FILE=update-release-ops.yml
RELEASE_NAME="$( bosh int release.MF --path /name )"
VERSION="$( bosh int release.MF --path /version )"
SHA1="$(sha1sum release/*.tgz | cut -d' ' -f1)"
URL="https://bosh.io/d/github.com/${BOSH_IO_RELEASE}?v=${VERSION}"

echo "Testing source release url: ${URL}"
if ! curl --output /dev/null --silent --head --fail $URL; then exit 1; fi

cat << EOF > $UPDATE_RELEASE_OPS_FILE
---
- type: replace
  path: /release=${RELEASE_NAME}/value
  value:
    sha1: ${SHA1}
    url: ${URL}
    version: "${VERSION}"
    name: ${RELEASE_NAME}
EOF

git clone bosh-deployment bosh-deployment-output

TMP=$(mktemp)
bosh int bosh-deployment/${FILE_TO_UPDATE} -o update-release-ops.yml > $TMP
mv $TMP bosh-deployment-output/${FILE_TO_UPDATE}

pushd $PWD/bosh-deployment-output
  if ! git diff --quiet --exit-code; then
    git add -A
    git config --global user.email "ci@localhost"
    git config --global user.name "CI Bot"
    git commit -m "Bumping $RELEASE_NAME to version $VERSION"
  fi
popd

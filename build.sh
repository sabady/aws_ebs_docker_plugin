# Build the Docker plugin
REGISTRY="harbor.belong.life"
REPOSITORY="devops/ebs-plugin"
MULTIARCH="linux/arm64,linux/amd64"

podman build --jobs=4 --platform="$MULTIARCH" --progress=plain --layers=true --compress --format=docker --manifest "$REGISTRY/$REPOSITORY:${version}_${BUILD_NUMBER}" .

# Install the plugin 
docker plugin Install $REGISTRY/$REPOSITORY:${version}_${BUILD_NUMBER} --alias ebs-volume-plugin --grant-all-permissions

# Test the plugin
docker plugin inspect ebs-volume-plugin

FROM=darkedges/s2i-base-jvm
IMAGE_NAME=darkedges/s2i-forgerock-am

# These values are changed in each version branch
# This is the only place they need to be changed
# other than the README.md file.
include versions.mk

TARGET=$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: all
all: build test

build: Dockerfile s2i
	docker build \
	--build-arg FRIG_ARCHIVE=IG-$(FORGEROCK_VERSION).zip \
	--pull -t $(TARGET) .

.PHONY: test
test: build
	 BUILDER=$(TARGET) FORGEROCK_VERSION=$(FORGEROCK_VERSION) ./test/run.sh

.PHONY: clean
clean:
	docker rmi `docker images $(TARGET) -q`

.PHONY: tag
tag:
	if [ ! -z $(LTS_TAG) ]; then docker tag $(TARGET) $(IMAGE_NAME):$(LTS_TAG); fi
	docker tag $(TARGET) $(IMAGE_NAME):$(FORGEROCK_VERSION)

.PHONY: publish
publish: all
	echo $(DOCKER_PASS) | docker login -u $(DOCKER_USER) --password-stdin
	docker push $(TARGET)
	docker push $(IMAGE_NAME):$(FORGEROCK_VERSION)
	if [ ! -z $(LTS_TAG) ]; then docker push $(IMAGE_NAME):$(LTS_TAG); fi
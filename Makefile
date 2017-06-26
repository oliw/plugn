NAME = plugn
HARDWARE = $(shell uname -m)
VERSION ?= 0.3.0
IMAGE_NAME ?= $(NAME)
BUILD_TAG ?= dev

build:
	go-bindata bashenv
	mkdir -p build/linux  && GOOS=linux  go build -a -ldflags "-X main.Version $(VERSION)" -o build/linux/$(NAME)
	mkdir -p build/darwin && GOOS=darwin go build -a -ldflags "-X main.Version $(VERSION)" -o build/darwin/$(NAME)
	mkdir -p build/arm && GOOS=linux && GOARM=6 && GOARCH=arm go build -a -ldflags "-X main.Version $(VERSION)" -o build/arm/$(NAME)
ifeq ($(CIRCLECI),true)
	docker build -t $(IMAGE_NAME):$(BUILD_TAG) .
else
	docker build -f Dockerfile.dev -t $(IMAGE_NAME):$(BUILD_TAG) .
endif

deps:
	go get -u github.com/jteeuwen/go-bindata/...
	go get -u github.com/progrium/gh-release/...
	go get -u github.com/progrium/basht/...
	go get -u github.com/tools/godep
	godep restore

release: build
	rm -rf release && mkdir release
	tar -zcf release/$(NAME)_$(VERSION)_linux_$(HARDWARE).tgz -C build/linux $(NAME)
	tar -zcf release/$(NAME)_$(VERSION)_darwin_$(HARDWARE).tgz -C build/darwin $(NAME)
	tar -zcf release/$(NAME)_$(VERSION)_linux_armv6l.tgz -C build/arm $(NAME)
	gh-release create dokku/$(NAME) $(VERSION) $(shell git rev-parse --abbrev-ref HEAD)

build-in-docker:
	docker build --rm -f Dockerfile.build -t $(NAME)-build .
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro \
		-v /var/lib/docker:/var/lib/docker \
		-v ${PWD}:/go/src/github.com/dokku/plugn -w /go/src/github.com/dokku/plugn \
		-e IMAGE_NAME=$(IMAGE_NAME) -e BUILD_TAG=$(BUILD_TAG) -e VERSION=master \
		$(NAME)-build make -e deps build
	docker rmi $(NAME)-build || true

test:
	basht tests/*/tests.sh

circleci:
	docker version
	rm -f ~/.gitconfig
	mv Dockerfile.dev Dockerfile

clean:
	rm -rf build/*
	docker rm $(shell docker ps -aq) || true
	docker rmi plugn:dev || true

.PHONY: build release deps build-in-docker clean test circleci

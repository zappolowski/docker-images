XSOCK?=/tmp/.X11-unix
DUNSTRC=${HOME}/.config/dunst/dunstrc
DOCKER_REPO?=dunst/dunst
DOCKER_REPO_CI?=dunst/ci
DOCKER_TECHNIQUE?=build
REPO=./dunst

IMG_RUN?=$(shell find * -name Dockerfile -printf '%h\n')
IMG_RUN:=${IMG_RUN}
IMG_DEV?=$(shell find ci -name 'Dockerfile.*' | sed 's/ci\/Dockerfile\.\(.*\)/\1/')
IMG_DEV:=${IMG_DEV}

all: ${IMG_DEV:%=test-%}
push: devimg-push img-push
pull: devimg-pull img-pull
build: devimg-build img-build
clean: devimg-clean img-clean

devimg-push-%: devimg-build-%
	docker push "${DOCKER_REPO_CI}:${@:devimg-push-%=%}"

devimg-push: ${IMG_DEV:%=devimg-push-%}
devimg-push-%: devimg-build-%
	docker push "${DOCKER_REPO_CI}:${@:devimg-push-%=%}"

devimg-pull-%:
	docker pull "${DOCKER_REPO_CI}:${@:devimg-pull-%=%}"

devimg-build: ${IMG_DEV:%=devimg-build-%}
devimg-build-%:
	docker build \
		-t "${DOCKER_REPO_CI}:${@:devimg-build-%=%}" \
		-f ci/Dockerfile.${@:devimg-build-%=%} \
		ci

test-%: devimg-${DOCKER_TECHNIQUE}-%
	$(eval RAND := $(shell date +%s))

	[ -e "${REPO}" ]

	docker run \
		--rm \
		--hostname "${@:test-%=%}" \
		-v "$(shell readlink -f ${REPO}):/dunstrepo" \
		-e CC \
		-e CFLAGS \
		"${DOCKER_REPO_CI}:${@:test-%=%}" \
		"/dunstrepo" \
		"/srv/dunstrepo-${RAND}" \
		"/srv/${RAND}-install"

devimg-clean: ${IMG_DEV:%=devimg-clean-%}
devimg-clean-%:
	-docker image rm "${DOCKER_REPO_CI}:${@:devimg-clean-%=%}"

img-push: ${IMG_RUN:%=img-push-%}
img-push-%: img-build-%
	docker push "${DOCKER_REPO}:${@:img-push-%=%}"

img-pull-%:
	docker pull "${DOCKER_REPO}:${@:img-pull-%=%-dev}"

img-build: ${IMG_RUN:%=img-build-%}
img-build-%:
	docker build \
		-t "${DOCKER_REPO}:${@:img-build-%=%}" \
		-f ${@:img-build-%=%}/Dockerfile \
		.

run-%: img-${DOCKER_TECHNIQUE}-%
	@[ -n "${DBUS_SESSION_BUS_ADDRESS}" ] \
		|| ( echo '$DBUS_SESSION_BUS_ADDRESS missing' && exit 1)
	@[ -n "${DISPLAY}" ] \
		|| ( echo '\$DISPLAY missing' && exit 1)
	@[ -f "${DUNSTRC}" ] \
		|| (echo 'Please create a dunstrc in "${DUNSTRC}"' && exit 1)

	$(eval XAUTH := $(shell mktemp))
	$(eval DBUS_PATH:=$(shell echo ${DBUS_SESSION_BUS_ADDRESS} | cut -d = -f 2))

	xauth nlist :0 | sed -e 's/^..../ffff/' | xauth -f ${XAUTH} nmerge -

	docker run -it --rm \
		--cap-add=SYS_ADMIN \
		--env="USER_UID=$(id -u)" \
		--env="USER_GID=$(id -g)" \
		--env="USER_NAME=$(id -un)" \
		--env="DISPLAY" \
		--env="DBUS_SESSION_BUS_ADDRESS" \
		--env="XAUTHORITY=${XAUTH}" \
		--volume=${DBUS_PATH}:${DBUS_PATH} \
		--volume=${XSOCK}:${XSOCK} \
		--volume=${XAUTH}:${XAUTH} \
		--volume=${DUNSTRC}:/tmp/dunstrc:ro \
		--volume=/usr/share/icons:/usr/share/icons:ro \
		--volume=/usr/share/fonts:/usr/share/fonts:ro \
		"${DOCKER_REPO}:${@:run-%=%}" ${DUNST_ARGS}

	rm ${XAUTH}

img-clean: ${IMG_RUN:%=img-clean-%}
img-clean-%:
	-docker image rm "${DOCKER_REPO}:${@:img-clean-%=%}"

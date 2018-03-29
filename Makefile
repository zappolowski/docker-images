XSOCK?=/tmp/.X11-unix
DUNSTRC=${HOME}/.config/dunst/dunstrc
REPO=./dunst

all: $(shell find * -name Dockerfile -printf 'img-%h\n')

devimg-%:
	docker build \
		-t dunst:${@:devimg-%=%-dev} \
		-f ${@:devimg-%=%}/Dockerfile.dev \
		.

test-%: devimg-%
	$(eval RAND := $(shell date +%s))

	[ -e "${REPO}" ]

	docker run \
		--rm \
		-v "${REPO}:/dunstrepo" \
		dunst:${@:test-%=%-dev} \
		"/dunstrepo" \
		"/srv/dunstrepo-${RAND}" \
		"/srv/${RAND}-install"

img-%:
	docker build \
		-t dunst:${@:img-%=%} \
		-f ${@:img-%=%}/Dockerfile \
		.

run-%: img-%
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
		dunst:${@:run-%=%} ${DUNST_ARGS}

	rm ${XAUTH}
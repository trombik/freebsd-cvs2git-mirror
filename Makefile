GIT_REMOTE_URL?=	git@github.com:lattera/freebsd-ports.git
GIT_REMOTE_NAME?=	github
USE_SUDO?=
USE_ZFS_SNAPSHOT?=
CSUP?=				csup
CSUP_FLAGS?=		-L2
CSUP_HOST?=			cvsup.freebsd.org
CVSROOT_NAME?=		cvsroot
GIT_NAME?=			gitrepo
CSUP_BASE_NAME?=	csup_db

.if defined(USE_SUDO)
SUDO=	sudo
.endif

.if defined(USE_ZFS)
ZFS_SNAPSHOTNAME!=	date +%F_%T
BASE_DATASET?=		rpool/ports_cvs
CVSROOT_DATASET?=	${CVSROOT_NAME}
GIT_DATASET?=		${GIT_NAME}
BASE_DIRECTORY!=	${SUDO} zfs get -H -Ovalue mountpoint ${BASE_DATASET}
CVSROOT_DIRECTORY!=	${SUDO} zfs get -H -Ovalue mountpoint ${BASE_DATASET}/${CVSROOT_DATASET}
GIT_DIRECTORY!=		${SUDO} zfs get -H -Ovalue mountpoint ${BASE_DATASET}/${GIT_DATASET}
CSUP_BASE?=			/ports_cvs/${CSUP_BASE_NAME}
.else
BASE_DIRECTORY?=	ports_cvs
CVSROOT_DIRECTORY?=	${BASE_DIRECTORY}/${CVSROOT_NAME}
GIT_DIRECTORY?=		${BASE_DIRECTORY}/${GIT_NAME}
CSUP_BASE?=			${BASE_DIRECTORY}/${CSUP_BASE_NAME}
.endif
SUPFILE?=			${BASE_DIRECTORY}/cvs-supfile
CSUP_PREFIX?=		${.CURDIR}/${BASE_DIRECTORY}/${CVSROOT_NAME}

all:	snapshot csup cvscvt git-fetch rm-cvsignore git-pull git-push

init:	mkdir-all supfile git-init

mkdir-all:
	@echo "===> ${.TARGET}"
	mkdir -p ${BASE_DIRECTORY} ${CVSROOT_DIRECTORY} ${GIT_DIRECTORY} ${CSUP_BASE}

csup:
	@echo "===> ${.TARGET}"
	${CSUP} ${CSUP_FLAGS} ${SUPFILE}

cvscvt:
	@echo "===> ${.TARGET}"
	(cd ${BASE_DIRECTORY} && cvscvt -e freebsd.org -k FreeBSD ${CVSROOT_DIRECTORY} | \
		GIT_DIR=${GIT_DIRECTORY}/.git git fast-import)

git-fetch:
	@echo "===> ${.TARGET}"
	(cd ${GIT_DIRECTORY} && git fetch ${GIT_REMOTE_NAME})

git-pull:
	@echo "===> ${.TARGET}"
	(cd ${GIT_DIRECTORY} && git pull ${GIT_REMOTE_NAME} master)

git-push:
	@echo "===> ${.TARGET}"
	(cd ${GIT_DIRECTORY} && git push ${GIT_REMOTE_NAME})

git-init:
	@echo "===> ${.TARGET}"
	find ${GIT_DIRECTORY} -depth 1 -print0 | xargs -0 rm -rf
	(cd ${GIT_DIRECTORY} && git init)
	(cd ${GIT_DIRECTORY} && git remote add ${GIT_REMOTE_NAME} ${GIT_REMOTE_URL})

# TODO Makfile.snapshot
snapshot:
	@echo "===> ${.TARGET}"
.if defined(USE_ZFS)
	${SUDO} zfs snapshot ${BASE_DATASET}/${CVSROOT_DATASET}@${ZFS_SNAPSHOTNAME}
	${SUDO} zfs snapshot ${BASE_DATASET}/${GIT_DATASET}@${ZFS_SNAPSHOTNAME}
.else
	@echo "USE_ZFS is not defined, skipping"
.endif

rm-cvsignore:
	@echo "===> ${.TARGET}"
	rm -f ${GIT_DIRECTORY}/.cvsignore

supfile:
	@echo "===> ${.TARGET}"
	@echo "# automatically created by Makefile" > ${SUPFILE}
	@echo "*default host=${CSUP_HOST}" >> ${SUPFILE}
	@echo "*default base=${CSUP_BASE}" >> ${SUPFILE}
	@echo "*default prefix=${CSUP_PREFIX}" >> ${SUPFILE}
	@echo "*default release=cvs" >> ${SUPFILE}
	@echo "*default delete use-rel-suffix" >> ${SUPFILE}
	@echo "*default compress" >> ${SUPFILE}
	@echo "ports-all" >> ${SUPFILE}
	@echo "cvsroot-all" >> ${SUPFILE}

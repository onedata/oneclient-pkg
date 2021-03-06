# distro for package building (oneof: xenial, bionic, focal, centos-7-x86_64)
DISTRIBUTION            ?= none
RELEASE                 ?= $(shell cat ./RELEASE)
HTTP_PROXY              ?= "http://proxy.devel.onedata.org:3128"
CONDA_TOKEN             ?= ""
CONDA_BUILD_OPTIONS     ?= ""
RETRIES                 ?= 0
RETRY_SLEEP             ?= 300

ifeq ($(strip $(ONECLIENT_VERSION)),)
ONECLIENT_VERSION       := $(shell git -C oneclient describe --tags --always --abbrev=7)
endif
ifeq ($(strip $(FSONEDATAFS_VERSION)),)
FSONEDATAFS_VERSION       := $(shell git -C fs-onedatafs describe --tags --always --abbrev=7)
endif
ifeq ($(strip $(ONEDATAFS_JUPYTER_VERSION)),)
ONEDATAFS_JUPYTER_VERSION       := $(shell git -C onedatafs-jupyter describe --tags --always --abbrev=7)
endif
ifeq ($(strip $(ONEDATAFS_JUPYTER_VERSION)),)
ONEDATAFS_JUPYTER_VERSION       := $(shell git -C onedatafs-jupyter describe --tags --always)
endif

ONECLIENT_VERSION             := $(shell echo ${ONECLIENT_VERSION} | tr - .)
FSONEDATAFS_VERSION           := $(shell echo ${FSONEDATAFS_VERSION} | tr - .)
ONEDATAFS_JUPYTER_VERSION     := $(shell echo ${ONEDATAFS_JUPYTER_VERSION} | tr - .)

PKG_BUILDER_VERSION     ?= -3
ONECLIENT_FPMPACKAGE_TMP ?= package_fpm

ifdef IGNORE_XFAIL
TEST_RUN := ./test_run.py --ignore-xfail
else
TEST_RUN := ./test_run.py
endif

ifdef ENV_FILE
TEST_RUN := $(TEST_RUN) --env-file $(ENV_FILE)
endif

GIT_URL := $(shell git config --get remote.origin.url | sed -e 's/\(\/[^/]*\)$$//g')
GIT_URL := $(shell if [ "${GIT_URL}" = "file:/" ]; then echo 'ssh://git@git.onedata.org:7999/vfs'; else echo ${GIT_URL}; fi)
ONEDATA_GIT_URL := $(shell if [ "${ONEDATA_GIT_URL}" = "" ]; then echo ${GIT_URL}; else echo ${ONEDATA_GIT_URL}; fi)
export ONEDATA_GIT_URL

.PHONY: docker docker-dev package.tar.gz

all: build

##
## Macros
##

NO_CACHE :=  $(shell if [ "${NO_CACHE}" != "" ]; then echo "--no-cache"; fi)

make = $(1)/make.py -s $(1) -r . $(NO_CACHE)
clean = $(call make, $(1)) clean
retry = RETRIES=$(RETRIES); until $(1) && return 0 || [ $$RETRIES -eq 0 ]; do sleep $(RETRY_SLEEP); RETRIES=`expr $$RETRIES - 1`; echo "===== Cleaning up... ====="; $(if $2,$2,:); echo "\n\n\n===== Retrying build... ====="; done; return 1 
make_rpm = $(call make, $(1)) -e DISTRIBUTION=$(DISTRIBUTION) -e RELEASE=$(RELEASE) --privileged --group mock -i onedata/rpm_builder:$(DISTRIBUTION)-$(RELEASE)$(PKG_BUILDER_VERSION) $(2)  
mv_rpm = mv $(1)/package/packages/*.src.rpm package/$(DISTRIBUTION)/SRPMS && \
	mv $(1)/package/packages/*.x86_64.rpm package/$(DISTRIBUTION)/x86_64
mv_noarch_rpm = mv $(1)/package/packages/*.src.rpm package/$(DISTRIBUTION)/SRPMS && \
	mv $(1)/package/packages/*.noarch.rpm package/$(DISTRIBUTION)/x86_64
make_deb = $(call make, $(1)) -e DISTRIBUTION=$(DISTRIBUTION) --privileged --group sbuild -i onedata/deb_builder:$(DISTRIBUTION)-$(RELEASE)$(PKG_BUILDER_VERSION) $(2)
mv_deb = mv $(1)/package/packages/*_amd64.deb package/$(DISTRIBUTION)/binary-amd64 && \
	mv $(1)/package/packages/*.tar.gz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.dsc package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.diff.gz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.debian.tar.xz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.changes package/$(DISTRIBUTION)/source | true
mv_noarch_deb = mv $(1)/package/packages/*_all.deb package/$(DISTRIBUTION)/binary-amd64 && \
	mv $(1)/package/packages/*.tar.gz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.dsc package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.diff.gz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.debian.tar.xz package/$(DISTRIBUTION)/source | true && \
	mv $(1)/package/packages/*.changes package/$(DISTRIBUTION)/source | true
unpack = tar xzf $(1).tar.gz
make_conda = $(call make, $(1)) -e CONDA_TOKEN=$(CONDA_TOKEN) -i onedata/conda:v3 $(2)

get_release:
	@echo $(RELEASE)

print_package_versions:
	@echo "oneclient:\t\t" $(ONECLIENT_VERSION)
	@echo "fs-onedatafs:\t\t" $(FSONEDATAFS_VERSION)
	@echo "onedatafs-jupyter:\t" $(ONEDATAFS_JUPYTER_VERSION)

##
## Submodules
##

branch = $(shell git rev-parse --abbrev-ref HEAD)
submodules:
	git submodule sync --recursive ${submodule}
	git submodule update --init --recursive ${submodule}

##
## Build
##

build: build_oneclient 

build_oneclient: submodules
	$(call make, oneclient) deb-info

##
## Artifacts
##

artifact:  artifact_oneclient 

artifact_oneclient:
	$(call unpack, oneclient)

##
## Test
##

BROWSER             ?= Chrome
RECORDING_OPTION    ?= failed

test_oneclient_base_packaging:
	$(call retry, ${TEST_RUN} --error-for-skips --test-type packaging -k "oneclient_base" -vvv --test-dir tests/packaging -s, :)

test_oneclient_packaging:
	$(call retry, ${TEST_RUN} --test-type packaging -k "oneclient and not oneclient_base" -vvv --test-dir tests/packaging -s, :)

test_fsonedatafs_packaging:
	$(call retry, ${TEST_RUN} --test-type packaging -k "fsonedatafs" -vvv --test-dir tests/packaging -s, :)


##
## Clean
##

clean_all:  clean_oneclient clean_packages

clean_oneclient:
	$(call clean, oneclient)

clean_fsonedatafs:
	$(call clean, fs-onedatafs)

clean_onedatafs_jupyter:
	$(call clean, onedatafs-jupyter)

clean_packages:
	rm -rf  package oneclient_package_tmp

##
## RPM packaging
##

rpm:  rpm_oneclient

rpm_oneclient_base: clean_oneclient rpmdirs
	$(call retry, $(call make_rpm, oneclient, rpm) -e PKG_VERSION=$(ONECLIENT_VERSION), make clean_oneclient rpmdirs)
	$(call mv_rpm, oneclient)

rpm_fsonedatafs: clean_fsonedatafs rpmdirs
	$(call retry, $(call make_rpm, fs-onedatafs, rpm) -e PKG_VERSION=$(FSONEDATAFS_VERSION) -e ONECLIENT_VERSION=$(ONECLIENT_VERSION), make clean_fsonedatafs rpmdirs)
	$(call mv_noarch_rpm, fs-onedatafs)

rpm_onedatafs_jupyter: clean_onedatafs_jupyter rpmdirs
	$(call retry, $(call make_rpm, onedatafs-jupyter, rpm) -e PKG_VERSION=$(ONEDATAFS_JUPYTER_VERSION) \
		                                     -e FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION) \
		                                     -e ONECLIENT_VERSION=$(ONECLIENT_VERSION), make clean_onedatafs_jupyter rpmdirs)
	$(call mv_noarch_rpm, onedatafs-jupyter)

rpmdirs:
	mkdir -p package/$(DISTRIBUTION)/SRPMS package/$(DISTRIBUTION)/x86_64

##
## DEB packaging
##

deb: deb_oneclient

deb_oneclient_base: clean_oneclient debdirs
	$(call make_deb, oneclient, deb) -e PKG_VERSION=$(ONECLIENT_VERSION)
	$(call mv_deb, oneclient)

deb_fsonedatafs: clean_fsonedatafs debdirs
	$(call make_deb, fs-onedatafs, deb) -e PKG_VERSION=$(FSONEDATAFS_VERSION) -e ONECLIENT_VERSION=$(ONECLIENT_VERSION)
	$(call mv_noarch_deb, fs-onedatafs)

deb_onedatafs_jupyter: clean_onedatafs_jupyter debdirs
	$(call make_deb, onedatafs-jupyter, deb) -e PKG_VERSION=$(ONEDATAFS_JUPYTER_VERSION) \
		                                     -e FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION) \
		                                     -e ONECLIENT_VERSION=$(ONECLIENT_VERSION)
	$(call mv_noarch_deb, onedatafs-jupyter)

debdirs:
	mkdir -p package/$(DISTRIBUTION)/source package/$(DISTRIBUTION)/binary-amd64

##
## Package artifact
##

package.tar.gz:
	tar -chzf package.tar.gz package

##
## Docker artifact
##

#
# Build intermediate Oneclient Docker image with oneclient installed from
# a normal (oneclient-base) package into /usr/ prefix.
#
docker_oneclient_base:
	$(MAKE) -C oneclient docker-base PKG_VERSION=$(ONECLIENT_VERSION) RELEASE=$(RELEASE) \
		                             FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION) \
		                             HTTP_PROXY=$(HTTP_PROXY)

#
# Build final Oneclient Docker image with oneclient installed from
# self contained package (oneclient) into /opt/oneclient prefix and
# symlinked into /usr prefix.
#
docker_oneclient:
	$(MAKE) -C oneclient docker PKG_VERSION=$(ONECLIENT_VERSION) RELEASE=$(RELEASE) \
                                FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION) \
                                HTTP_PROXY=$(HTTP_PROXY)

#
# Build Jupyter Docker with OnedataFS content manager plugin
#
docker_onedatafs_jupyter:
	$(MAKE) -C onedatafs-jupyter docker ONECLIENT_VERSION=$(ONECLIENT_VERSION) \
		                         ONEDATAFS_JUPYTER_VERSION=$(ONEDATAFS_JUPYTER_VERSION) \
		                         FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION) \
		                         HTTP_PROXY=$(HTTP_PROXY) \
		                         RELEASE=$(RELEASE)

#
# Build self-contained Oneclient archive, by extracting all necessary files
# from intermediate Oneclient Docker image (oneclient-base)
#
oneclient_tar oneclient/$(ONECLIENT_FPMPACKAGE_TMP)/oneclient-bin.tar.gz:
	$(MAKE) -C oneclient oneclient_tar

#
# Build production Oneclient RPM using FPM tool from self contained archive
#
oneclient_rpm: oneclient/$(ONECLIENT_FPMPACKAGE_TMP)/oneclient-bin.tar.gz rpmdirs
	$(MAKE) -C oneclient DISTRIBUTION=$(DISTRIBUTION) ONECLIENT_VERSION=$(ONECLIENT_VERSION) \
		oneclient_rpm
	mv oneclient/$(ONECLIENT_FPMPACKAGE_TMP)/oneclient*.rpm package/$(DISTRIBUTION)/x86_64

#
# Build production Oneclient DEB using FPM tool from self-contained archive
#
oneclient_deb: oneclient/$(ONECLIENT_FPMPACKAGE_TMP)/oneclient-bin.tar.gz debdirs
	$(MAKE) -C oneclient DISTRIBUTION=$(DISTRIBUTION) ONECLIENT_VERSION=$(ONECLIENT_VERSION) \
		oneclient_deb
	mv oneclient/$(ONECLIENT_FPMPACKAGE_TMP)/oneclient*.deb package/$(DISTRIBUTION)/binary-amd64

#
# Build and upload oneclient conda packages
#
oneclient_conda:
	$(call make_conda, oneclient, conda/oneclient) \
		-e CONDA_BUILD_OPTIONS="$(CONDA_BUILD_OPTIONS)" \
		-e PKG_VERSION=$(ONECLIENT_VERSION)

#
# Build and upload onedatafs conda packages
#
onedatafs_conda:
	$(call make_conda, oneclient, conda/onedatafs) \
		-e CONDA_BUILD_OPTIONS="$(CONDA_BUILD_OPTIONS)" \
		-e PKG_VERSION=$(ONECLIENT_VERSION)

#
# Build and upload fs.onedatafs conda packages
#
fsonedatafs_conda:
	$(call make_conda, fs-onedatafs, conda) \
		-e PKG_VERSION=$(FSONEDATAFS_VERSION) \
		-e CONDA_BUILD_OPTIONS="$(CONDA_BUILD_OPTIONS)" \
		-e ONECLIENT_VERSION=$(ONECLIENT_VERSION)

#
# Build and upload onedatafs-jupyter conda packages
#
onedatafs_jupyter_conda:
	$(call make_conda, onedatafs-jupyter, conda) \
		-e PKG_VERSION=$(ONEDATAFS_JUPYTER_VERSION) \
		-e CONDA_BUILD_OPTIONS="$(CONDA_BUILD_OPTIONS)" \
		-e FSONEDATAFS_VERSION=$(FSONEDATAFS_VERSION)


codetag-tracker:
	./bamboos/scripts/codetag-tracker.sh --branch=${BRANCH} --excluded-dirs=node_package,oneclient,fs-onedatafs

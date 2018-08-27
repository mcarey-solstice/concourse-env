###
# Project commands
##

## Variables

# Project variables
TARGET ?= lite
CONCOURSE_URL ?= http://localhost:8080

# Directories
BIN = bin
SRC = src
VENDOR = vendor

DATA = data
KEYS = $(DATA)/keys
LOGS = $(DATA)/logs
FLY = $(DATA)/fly

DOCKER_COMPOSE := docker-compose -f $(DATA)/docker-compose.yml

# Environment variables
export PATH := ./$(BIN):./$(VENDOR)/bin:$(PATH)
export LOGFILE := $(LOGS)/$(shell date '+%Y-%m-%d').log

# Get OS and Processor type
ifeq ($(OS),Windows_NT)
	OS = windows
	ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
		PROCESSOR = amd64
	else
		ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
			PROCESSOR = amd64
		endif
		ifeq ($(PROCESSOR_ARCHITECTURE),x86)
			PROCESSOR = i386
		endif
	endif
else
	UNAME_S = $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
	OS = linux
		UNAME_P := $(shell uname -p)
		ifeq ($(UNAME_P),x86_64)
			PROCESSOR = amd64
		endif
		ifneq ($(filter %86,$(UNAME_P)),)
			PROCESSOR = i386
		endif
		ifneq ($(filter arm%,$(UNAME_P)),)
			PROCESSOR = arm
		endif
	endif
	ifeq ($(UNAME_S),Darwin)
	OS = darwin
		PROCESSOR = amd64
	endif
endif


###
# Sets up the needed directories that are ignored
##
$(shell mkdir -p $(DATA) $(LOGS))

# Collects all pipelines under the pipeline directory
ALL_PIPELINES = $(foreach pipeline,$(wildcard $(PIPELINES)/*),$(shell echo $(pipeline) | sed 's/.*_//'))

## Tasks

.PHONY: *

###
# Prints the docker command
##
docker-compose:
	@echo $(DOCKER_COMPOSE)
# docker-compose

###
# Generates the merged docker-compose file that will be used by docker-compose
##
docker-compose.yml:
	spruce merge $(VENDOR)/concourse-docker/docker-compose.yml docker-compose.tpl.yml > $(DATA)/docker-compose.yml
# docker-compose

###
# Generates the keys needed by the docker containers
##
keys:
	$(BIN)/generate-keys $(KEYS)
# keys

###
# Starts the docker containers
##
start: keys docker-compose.yml
	$(DOCKER_COMPOSE) up -d
# start

###
# Stops the docker containers
##
stop: docker-compose.yml
	$(DOCKER_COMPOSE) stop
# stop

###
# Destroys the docker containers and the keys associated
##
destroy: stop docker-compose.yml
	$(DOCKER_COMPOSE) rm

	$(BIN)/destroy-keys $(KEYS)
# destroy

###
# Downloads the fly binary from $(URL) to communicate with concourse
#
# Notes:
#  - Fly requires the version to match that of the concourse server
#  - The file is dumped into $(FLY)
#  - The function attempts to determine the OS and Processor Architecure
##
fly:
ifeq (,$(wildcard $(FLY)))
	wget -O $(FLY) "$(URL)/api/v1/cli?arch=$(PROCESSOR)&platform=$(OS)"
endif
	@chmod +x $(FLY)
# fly

###
# Creates a fly session under the $(TARGET) and $(URL)
##
login: fly
	@$(FLY) -t $(TARGET) login -c $(URL)
# login

## Pipelines

###
# Lists all the available pipelines to run
##
list-pipelines:
	@for pipeline in $(ALL_PIPELINES); do echo $$pipeline; done
# list pipelines

###
# Runs ALL of the pipelines
##
pipelines: $(ALL_PIPELINES)

###
# Creates dynamic tasks foreach pipeline under the $(PIPELINES) directory
##
%: login
	@echo "Running pipeline: %"
	$(BIN)/run-pipeline -t $(TARGET) -s $(PIPELINES) $(@)
# %

# Makefile

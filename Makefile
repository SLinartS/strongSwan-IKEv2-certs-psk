TITLE_IAC_IPSEC = strongswan-test-ipsec
TITLE_IAC_SWANCTL = strongswan-test-swanctl

test: test-ipsec test-swanctl 

test-ipsec: build-ipsec run-ipsec rm-ipsec
	$(info --------------------------------------------------)
	$(info ipsec_conf test END)
	$(info --------------------------------------------------)
test-swanctl: build-swanctl run-swanctl rm-swanctl
	$(info --------------------------------------------------)
	$(info swanctl_conf test END)
	$(info --------------------------------------------------)

rm-ipsec:
	docker container rm $(TITLE_IAC_IPSEC)
	docker image rm $(TITLE_IAC_IPSEC)
build-ipsec:
	$(info --------------------------------------------------)
	$(info ipsec_conf test START)
	$(info --------------------------------------------------)
	docker build -t $(TITLE_IAC_IPSEC) -f ./tests/Dockerfile.ipsec  .
run-ipsec: 
	docker run --privileged --name $(TITLE_IAC_IPSEC) $(TITLE_IAC_IPSEC)

rm-swanctl:
	docker container rm $(TITLE_IAC_SWANCTL)
	docker image rm $(TITLE_IAC_SWANCTL)
build-swanctl:
	$(info --------------------------------------------------)
	$(info swanctl_conf test START)
	$(info --------------------------------------------------)
	docker build -t $(TITLE_IAC_SWANCTL) -f ./tests/Dockerfile.swanctl  .
run-swanctl: 
	docker run --privileged --name $(TITLE_IAC_SWANCTL) $(TITLE_IAC_SWANCTL)

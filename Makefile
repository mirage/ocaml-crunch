all:
	cd crunch && $(MAKE) all

test:
	cd crunch_test && $(MAKE)

install:
	cd crunch && $(MAKE) install

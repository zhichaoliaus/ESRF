srcdir= $(PWD)

include Makefile.vars

# Public libocxl sub-submodule
libocxl_dir = libocxl

CFLAGS += -I$(libocxl_dir)/kernel/include -I$(libocxl_dir)/src/include
LDFLAGS += -L$(libocxl_dir)/obj -locxl -lpthread

# Add tests here
#tests = ocxl_memcpy.c ocxl_lpc.c ocxl_irq.c ocxl_afp3.c ocxl_afp3_latency.c ocxl_afp3_github.c ocxl_afp3_lat_github.c
tests = ocxl_memcpy.c

# Add any .o files tests may depend on
#test_deps =

tests: all
all: $(tests:.c=)

libocxl_objs = libocxl.a libocxl.so
libocxl_deps = $(foreach dep, $(libocxl_objs), $(libocxl_dir)/obj/$(dep))

-include $(tests:.c=.d)
-include $(test_deps:.o=.d)
include Makefile.rules

$(libocxl_dir)/Makefile:
	$(call Q, GIT submodule init, git submodule init)
	$(call Q, GIT submodule update, git submodule update)

$(libocxl_deps): $(libocxl_dir)/Makefile
	$(MAKE) -C $(libocxl_dir) all

$(test_deps):

%.o : %.S
	$(call Q,CC, $(CC) -MM $(CFLAGS) $< > $*.d, $*.d)
	$(call Q,SED, sed -i -e "s/$@.o/$@/" $*.d, $*.d)
	$(call Q,CC, $(CC) $(CFLAGS) -c $<, $<)

% : %.c $(libocxl_deps) $(test_deps)
	$(call Q,CC, $(CC) -MM $(CFLAGS) $< > $*.d, $*.d)
	$(call Q,SED, sed -i -e "s/$@.o/$@/" $*.d, $*.d)
	$(call Q,CC, $(CC) $(CFLAGS) $(filter %.c %.o,$^) $(LDFLAGS) -o $@, $@)

precommit: clean all
	astyle --style=linux --indent=tab=8 --max-code-length=120 *.c

clean:
	/bin/rm -f $(tests:.c=) $(patsubst %.c,%.d,$(tests)) $(test_deps) $(patsubst %.o,%.d,$(test_deps))
	[ ! -d $(libocxl_dir) ] || $(MAKE) -C $(libocxl_dir) clean

.PHONY: clean all tests

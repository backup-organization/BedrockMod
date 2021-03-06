CXX = clang++
CC = clang

TAG = $(shell git describe --always --long --dirty --tags)

CFLAGSQL = -g -fPIC -std=c99 -Iinclude -O3 -fdiagnostics-color=always
CXXFLAGS = -g -fPIC -std=c++2a -DMODS_TAG=\"$(TAG)\" -Iinclude -I/usr/include/guile/2.2 -Wno-invalid-offsetof -Wno-undefined-var-template -O3 -fdiagnostics-color=always
LDFLAGS = -g -fPIC

LPLAYER = -Lout -lsupport
LSCRIPT = -Lout -lscript

MODS = $(shell ls src/mods)
SCRIPT_MODS = $(shell ls src/script)

$(shell mkdir -p obj dep out ref >/dev/null)

.PHONY: all
all: $(addsuffix .so,$(addprefix out/lib,$(MODS)))  $(addsuffix .so,$(addprefix out/script_,$(SCRIPT_MODS)))

.PHONY: clean
clean:
	@rm -rf obj out dep ref
	@find -name '*.[xz]' -exec rm {} \;

out/lib%.so: obj/mods/%/main.o
	@echo LD $@
	@$(CXX) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o,$^) $(addprefix -Lout -l:,$(notdir $(filter out/%.so,$^)))
out/libbridge.so: obj/mods/bridge/main.o obj/mods/bridge/bus.o obj/mods/bridge/command.o obj/mods/bridge/player_ext.o
	@echo LD $@
	@$(CXX) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o,$^) -lsystemd
out/libsupport.so: obj/mods/support/main.o
	@echo LD $@
	@$(CXX) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o,$^)
out/libscript.so: obj/mods/script/main.o out/libsupport.so out/libbridge.so
	@echo LD $@
	@$(CXX) $(LDFLAGS) $(LPLAYER) -shared -fPIC -o $@ $(filter %.o,$^) -lguile-2.2 -lgc -lbridge
out/script_%.so: obj/script/%/main.o obj/uuid.o out/libsupport.so out/libscript.so
	@echo LD $@
	@$(CXX) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o,$^) $(addprefix -Lref -l:,$(notdir $(filter ref/%.so,$^))) $(addprefix -Lout -l:,$(notdir $(filter out/%.so,$^)))

.PRECIOUS: dep/%.d
dep/%.d: src/%.cpp
	@echo DP $< 
	@mkdir -p $(@D)
	@$(CXX) $(CXXFLAGS) -MT $(patsubst dep/%.d,obj/%.o,$@) -M -MG -o $@ $<
	@sed -i 's/ \([^/ \\]\+\)\.\([xz]\)/ '$(subst /,\\/,$(<D))'\/\1.\2/g' $@
	@-grep -oP '(?<=// Deps: ).+' $< >> $@ || exit 0

.PRECIOUS: .x
src/%.x: src/%.cpp
	@echo SN $@
	@CPP="$(CXX) -DDIAG -E" guile-snarf -o $@ $< $(CXXFLAGS)
.PRECIOUS: .z
src/%.z: src/%
	@echo PH $@
	@touch $@

.PRECIOUS: obj/%.o
obj/%.o: src/%.cpp
obj/%.o: src/%.cpp dep/%.d
	@echo CC $@
	@mkdir -p $(@D)
	@$(CXX) $(CXXFLAGS) -c -o $@ $<

SOURCES = $(shell find src -name '*.cpp')

deps: $(patsubst src/%.cpp, dep/%.d, $(SOURCES))

-include $(patsubst src/%.cpp, dep/%.d, $(SOURCES))
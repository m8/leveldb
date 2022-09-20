ifneq ($(shell command -v llvm-config-9 2> /dev/null),)
  VERSION=-9
else ifneq ($(shell command -v llvm-config-12 2> /dev/null),)
  VERSION=-12
else ifneq ($(shell command -v llvm-config-11 2> /dev/null),)
  VERSION=-11
else ifneq ($(shell command -v llvm-config-10 2> /dev/null),)
  VERSION=-10
else ifneq ($(shell command -v llvm-config 2> /dev/null),)
  VERSION=
else
  $(error Unable to locate the LLVM toolchain for supported versions 9-12)
endif

# Leveldb build files
DB_FOLDER := builder c dbformat db_impl db_iter filename log_reader log_writer memtable repair table_cache version_edit version_set write_batch
TABLE_FOLDER := block_builder block filter_block format iterator merger table_builder table two_level_iterator
UTIL_FOLDER := arena bloom cache coding comparator crc32c env env_posix filter_policy hash histogram logging options status
BUILD_DIR := llvmbuild

LLVM_CONFIG = llvm-config$(VERSION)
LLVM_LINK = llvm-link$(VERSION)
OPT = opt$(VERSION)

ifneq ($(shell command -v clang-format 2> /dev/null),)
  CLANG_FORMAT = clang-format
else
  $(error Please install clang-format)
endif

LLVM_VERSION := $(shell $(LLVM_CONFIG) --version | cut -d '.' -f 1)

ifeq ($(shell uname), Darwin)
  LOADABLE_MODULE_OPTIONS = -bundle -undefined dynamic_lookup
else
  LOADABLE_MODULE_OPTIONS = -shared -O1
endif

ifndef VERBOSE
  QUIET := @
endif

LLVM_PASS := ../pass/build/yield/libYieldPass.so

CXX := clang++-9 -stdlib=libc++ -fPIC
CXX_FLAGS := -emit-llvm -g -S -O3 -I. -I./include -pthread -DOS_LINUX -DLEVELDB_PLATFORM_POSIX -DSNAPPY  -c 


PASS_CONFIG = -load $(LLVM_PASS) -yield
DEPENDENCY_CONFIG = -postdomtree -mem2reg -indvars -loop-simplify -branch-prob -scalar-evolution


all: clean build_db build_util build_table 
	llvm-link-9 -o libleveldb.bc llvmbuild/*.bc
	llvm-dis-9 libleveldb.bc -o leveldb.ll
	$(OPT) -S $(DEPENDENCY_CONFIG) < leveldb.ll > leveldb.opt.ll
	$(OPT) -S $(PASS_CONFIG) < leveldb.opt.ll > loop_leveldb.opt.ll
	$(CXX) -std=c++11 -c loop_leveldb.opt.ll -O3 -o pass_libleveldb.a -lpthread -lci

loop:
	$(OPT) -S $(DEPENDENCY_CONFIG) < leveldb.ll > leveldb.opt.ll
	$(OPT) -S $(PASS_CONFIG) < leveldb.opt.ll > loop_leveldb.opt.ll
	$(CXX) -std=c++11 -c loop_leveldb.opt.ll -O3 -o pass_libleveldb.a -lpthread -lci


create-shared-lib:
	llc-9 -filetype=obj libleveldb.bc -o libleveldb.a

build-bit-code: 
	llvm-link-10 -o libleveldb.bc llvmbuild/*.bc


create-obj: 
	llc-10 -filetype=obj libleveldb.bc -o libleveldb.a
	llvm-dis-10 libleveldb.bc -o leveldb.dis

build_db:
	for file in $(DB_FOLDER); do \
		$(CXX) $(CXX_FLAGS) db/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
		clang++-9 -std=c++11 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o; \
	done

build_util:
	for file in $(UTIL_FOLDER); do \
		$(CXX) $(CXX_FLAGS) util/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
		clang++-9 -std=c++11 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o; \
	done

build_table:
	for file in $(TABLE_FOLDER); do \
		$(CXX) $(CXX_FLAGS) table/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
		clang++-9 -std=c++11 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o; \
	done

clean:
	$(RM) $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bc  $(BUILD_DIR)/*.o
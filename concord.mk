# Leveldb build files
DB_FOLDER := builder c dbformat db_impl db_iter filename log_reader log_writer memtable repair table_cache version_edit version_set write_batch
TABLE_FOLDER := block_builder block filter_block format iterator merger table_builder table two_level_iterator
UTIL_FOLDER := arena bloom cache coding comparator crc32c env env_posix filter_policy hash histogram logging options status
BUILD_DIR := concord_build

LLVM_CONFIG = llvm-config-9
LLVM_LINK = llvm-link-9
OPT = opt-9

CXX := clang++-9 -fPIC
CXX_FLAGS := -emit-llvm -g -S -O3 -I. -I./include -pthread -DOS_LINUX -DLEVELDB_PLATFORM_POSIX -DSNAPPY  -c 

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

CONCORD_MAIN=$(ROOT_DIR)/../../../src

CONCORD_PASS=$(CONCORD_MAIN)/pass/build/src/libConcordPass.so
CONCORD_LIB=$(CONCORD_MAIN)/lib/concord.a
CONCORD_DIR=$(CONCORD_MAIN)/lib/
INC_DIR=-I$(CONCORD_DIR)

PASS_CONFIG = -load $(CONCORD_PASS) -yield
OPT_CONFIG = -postdomtree -mem2reg -indvars -loop-simplify -branch-prob -scalar-evolution

all: clean build_db build_util build_table 
	$(MAKE) -f concord.mk concord_pass

concord_pass:
	llvm-link-9 -o libleveldb.bc $(BUILD_DIR)/*.bc
	llvm-dis-9 libleveldb.bc -o leveldb.ll
	$(OPT) -S $(OPT_CONFIG) < leveldb.ll > leveldb.opt.ll
	$(OPT) -S -load $(CONCORD_PASS) -yield < leveldb.opt.ll > concord_leveldb.opt.ll
	$(CXX) -c -O3 concord_leveldb.opt.ll -o concord_libleveldb.a $(CONCORD_LIB) 
	$(CXX) -c -O3 leveldb.opt.ll -o concord_libleveldb_clear.a $(CONCORD_LIB) 

build_db:
	@mkdir -p $(BUILD_DIR)
	for file in $(DB_FOLDER); do \
		$(CXX) $(CXX_FLAGS) db/$$file.cc -o $(BUILD_DIR)/$$file.bc $(INC_DIR); \
		clang++-9 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o $(INC_DIR); \
	done

build_util:
	for file in $(UTIL_FOLDER); do \
		$(CXX) $(CXX_FLAGS) util/$$file.cc -o $(BUILD_DIR)/$$file.bc $(INC_DIR); \
		clang++-9 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o $(INC_DIR); \
	done

build_table:
	for file in $(TABLE_FOLDER); do \
		$(CXX) $(CXX_FLAGS) table/$$file.cc -o $(BUILD_DIR)/$$file.bc $(INC_DIR); \
		clang++-9 -c $(BUILD_DIR)/$$file.bc -o $(BUILD_DIR)/$$file.o $(INC_DIR); \
	done

clean:
	$(RM) $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bc  $(BUILD_DIR)/*.o *.ll *.opt.ll *.bc concord_libleveldb.a
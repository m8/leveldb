# Leveldb build files
DB_FOLDER := builder c dbformat db_impl db_iter filename log_reader log_writer memtable repair table_cache version_edit version_set write_batch
TABLE_FOLDER := block_builder block filter_block format iterator merger table_builder table two_level_iterator
UTIL_FOLDER := arena bloom cache coding comparator crc32c env env_posix filter_policy hash histogram logging options status
BUILD_DIR := concord_build

LLVM_CONFIG = llvm-config-9
LLVM_LINK = llvm-link-9
OPT = opt-9

CXX := clang++-9 -stdlib=libc++ -fPIC
CXX_FLAGS := -emit-llvm -g -S -O3 -I. -I./include -pthread -DOS_LINUX -DLEVELDB_PLATFORM_POSIX -DSNAPPY  -c 

CONCORD_PASS=../src/pass/build/src/libConcordPass.so
CONCORD_LIB=../src/lib/concord.a
CONCORD_DIR=../src/lib/
INC_DIR=-I$(CONCORD_DIR)

PASS_CONFIG = -load $(CONCORD_PASS) -yield
OPT_CONFIG = -postdomtree -mem2reg -indvars -loop-simplify -branch-prob -scalar-evolution

all: clean build_db build_util build_table 
	$(MAKE) concord_pass

concord_pass:
	llvm-link-9 -o libleveldb.bc $(BUILD_DIR)/*.bc
	llvm-dis-9 libleveldb.bc -o leveldb.ll
	$(OPT) -S $(OPT_CONFIG) < leveldb.ll > leveldb.opt.ll
	$(OPT) -S -load $(CONCORD_PASS) -yield < leveldb.opt.ll > concord_leveldb.opt.ll
	$(CXX) -std=c++11 -c concord_leveldb.opt.ll -O3 -o concord_libleveldb.a -lpthread -lci

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
	$(RM) $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bc  $(BUILD_DIR)/*.o *.ll *.opt.ll *.bc
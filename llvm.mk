CXX := clang++-10 -stdlib=libc++ -Xclang -load -Xclang /home/musa/code-analyzer/loop-pass/build/yield/libYieldPass.so
CXX_FLAGS := -emit-llvm -O3 -I. -I./include -pthread -DOS_LINUX -DLEVELDB_PLATFORM_POSIX -DSNAPPY -c 
DB_FOLDER := builder c dbformat db_impl db_iter filename log_reader log_writer memtable repair table_cache version_edit version_set write_batch
TABLE_FOLDER := block_builder block filter_block format iterator merger table_builder table two_level_iterator
UTIL_FOLDER := arena bloom cache coding comparator crc32c env env_posix filter_policy hash histogram logging options status
BUILD_DIR := llvmbuild

all: clean build_db  build_util build_table 
	llvm-link-10 -o libleveldb.bc llvmbuild/*.bc 
	llc-10 -filetype=obj libleveldb.bc -o libleveldb.a
	llvm-dis-10 libleveldb.bc -o leveldb.dis
	
build-bit-code: 
	llvm-link-10 -o libleveldb.bc llvmbuild/*.bc

create-obj: 
	llc-10 -filetype=obj libleveldb.bc -o libleveldb.a
	llvm-dis-10 libleveldb.bc -o leveldb.dis

build_db:
	for file in $(DB_FOLDER); do \
		$(CXX) $(CXX_FLAGS) db/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
	done

build_util:
	for file in $(UTIL_FOLDER); do \
		$(CXX) $(CXX_FLAGS) util/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
	done

build_table:
	for file in $(TABLE_FOLDER); do \
		$(CXX) $(CXX_FLAGS) table/$$file.cc -o $(BUILD_DIR)/$$file.bc; \
	done

clean:
	$(RM) $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bc
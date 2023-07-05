#! /bin/bash

skip_julia_install=false
mode=""

while getopts ":hm:-:" opt; do
    case $opt in
        h)
            echo "Build Julia from source, with MLIR enabled. Also build standalone MLIR dialect."
            echo "build.sh -m [release|debug] [--skip_julia_install]"
            exit 0;
            ;;
        m)
            mode=$OPTARG
            ;;
        -)
            case $OPTARG in
                skip-julia-install)
                    skip_julia_install=true
                    ;;
                *)
                    echo "Invalid option: --$OPTARG"
                    exit 1
                    ;;
            esac
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            exit 1
            ;;
        ?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [[ -z "$mode" ]]; then
    echo "Mode is required. Please specify either '-m release' or '-m debug'."
    exit 1
fi

rootpath=$(pwd)

if ! $skip_julia_install; then
    # Enable CAPI generation by inserting command in llvm.mk:
    sed -i '76{/^ifeq ($(USE_MLIR), 1)/!s/^/ifeq ($(USE_MLIR), 1)\nLLVM_CMAKE += -DMLIR_BUILD_MLIR_C_DYLIB=ON\nendif\n/}' $rootpath/deps/llvm.mk

    rm -rf $rootpath/build/$mode
    make O=$rootpath/build/$mode configure

    # Create Make.user
    cat <<EOF > $rootpath/build/$mode/Make.user
override LLVM_DEBUG=0
override USE_BINARYBUILDER_LLVM=0
override DEPS_GIT=1
override USE_MLIR=1
EOF

    # Execute make in build/debug with the number of available processors
    cd $rootpath/build/$mode
    make -j "$(nproc)"
fi

rm -rf $rootpath/build/$mode/standalone
mkdir $rootpath/build/$mode/standalone && cd $rootpath/build/$mode/standalone
cmake -G Ninja $rootpath/deps/srccache/llvm/mlir/examples/standalone -DMLIR_DIR=$rootpath/build/$mode/usr/lib/cmake/mlir -DLLVM_EXTERNAL_LIT=$rootpath/build/$mode/usr/tools/lit/lit.py
cmake --build . --target check-standalone


# #! /bin/bash

# mode=$1 # should be either `release` or `debug`.

# # Validate the mode variable
# if [[ "$mode" != "release" && "$mode" != "debug" ]]; then
#     echo "Invalid mode. Please specify either 'release' or 'debug'."
#     exit 1
# fi

# rootpath=$(pwd)

# # Enable CAPI generation by inserting command in llvm.mk:
# sed -i '76{/^ifeq ($(USE_MLIR), 1)/!s/^/ifeq ($(USE_MLIR), 1)\nLLVM_CMAKE += -DMLIR_BUILD_MLIR_C_DYLIB=ON\nendif\n/}' $rootpath/deps/llvm.mk

# make O=$rootpath/build/$mode configure

# # Create Make.user
# cat <<EOF > $rootpath/build/$mode/Make.user
# override LLVM_DEBUG=0
# override USE_BINARYBUILDER_LLVM=0
# override DEPS_GIT=1
# override USE_MLIR=1
# EOF

# # Execute make in build/debug with the number of available processors
# cd $rootpath/build/$mode
# make -j "$(nproc)"

# rm -rf $rootpath/build/$mode/standalone
# mkdir $rootpath/build/$mode/standalone && cd $rootpath/build/$mode/standalone
# cmake -G Ninja $rootpath/deps/srccache/llvm/mlir/examples/standalone -DMLIR_DIR=$rootpath/build/$mode/usr/lib/cmake/mlir -DLLVM_EXTERNAL_LIT=$rootpath/build/$mode/usr/tools/lit/lit.py
# cmake --build . --target check-standalone
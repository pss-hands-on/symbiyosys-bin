#!/bin/sh -x

root=$(pwd)
PATH_SAV=${PATH}

if test "x${CI_BUILD}" != "x"; then
    if test $(uname -s) = "Linux"; then
        yum update -y
        yum install -y glibc-static wget flex bison jq readline-static libffi libffi-devel
        export PATH=/opt/python/cp312-cp312/bin:$PATH
        rls_plat="manylinux-x64"
    elif test $(uname -s) = "Windows"; then
        rls_plat="windows-x64"
    fi
fi
if test ! -d py; then
    python3 -m venv py
    if test $? -ne 0; then exit 1; fi

    ./py/bin/pip install meson ninja
    if test $? -ne 0; then exit 1; fi
fi

proj=$(pwd)
if test "x${sby_version}" != "x"; then
    rls_version=${sby_version}
else
    rls_version=1.0.0
fi

if test "x${BUILD_NUM}" != "x"; then
    rls_version="${rls_version}.${BUILD_NUM}"
fi

release_dir="${root}/release/symbiyosys-${rls_version}"
rm -rf ${release_dir}
mkdir -p ${release_dir}

if test ! -d yosys; then
    git clone https://github.com/YosysHQ/yosys
    if test $? -ne 0; then exit 1; fi
    cd ${proj}/yosys
    git submodule update --init
    if test $? -ne 0; then exit 1; fi
    cd ${proj}
fi

cd ${proj}/yosys
make -j$(nproc) PREFIX=${release_dir}
if test $? -ne 0; then exit 1; fi

make install PREFIX=${release_dir}
if test $? -ne 0; then exit 1; fi

cd ${proj}

if test ! -d sby; then
    git clone https://github.com/YosysHQ/sby
fi

cd ${proj}/sby
make install PREFIX=${release_dir}

cd ${proj}
if test ! -d boolector; then
    git clone https://github.com/boolector/boolector
fi

cd ${proj}/boolector
./contrib/setup-btor2tools.sh
./contrib/setup-lingeling.sh
./configure.sh
make -C build -j$(nproc)
cp build/bin/boolector ${release_dir}/bin
cp build/bin/btorimc ${release_dir}/bin
cp build/bin/btormbt ${release_dir}/bin
cp build/bin/btormc ${release_dir}/bin
cp build/bin/btoruntrace ${release_dir}/bin
cp deps/btor2tools/build/bin/btorsim ${release_dir}/bin

cd ${proj}

#if test ! -f ${bwz_latest_rls}.tar.gz; then
#    wget https://github.com/bitwuzla/bitwuzla/archive/refs/tags/${bwz_latest_rls}.tar.gz
#    if test $? -ne 0; then exit 1; fi
#fi


#********************************************************************
#* Build Bitwuzla
#********************************************************************
#cd ${root}
#bwz_version=${bwz_latest_rls}
#if test -d bitwuzla-${bwz_version}; then
#    rm -rf bitwuzla-${bwz_version}
#fi

#tar xvzf ${bwz_latest_rls}.tar.gz
#if test $? -ne 0; then exit 1; fi

#export PATH=${root}/py/bin:${PATH}

#cd bitwuzla-${bwz_version}
#./configure.py --prefix ${release_dir}
#if test $? -ne 0; then exit 1; fi
#cd build
#meson compile
#if test $? -ne 0; then exit 1; fi
#meson install
#if test $? -ne 0; then exit 1; fi

# PATH=${PATH_SAV}

#********************************************************************
#* Create release tarball
#********************************************************************
cd ${root}/release


tar czf symbiyosys-${rls_plat}-${rls_version}.tar.gz symbiyosys-${rls_version}


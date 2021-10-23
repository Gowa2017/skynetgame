#!/bin/bash
PROTODIR=$(dirname $0)
ROOT=$(pwd $PROTODIR/../..)
# format file
find $PROTODIR -name "*.proto" -exec clang-format --style=google -i {} \;
# compile it
protoc -I ${PROTODIR} -o${PROTODIR}/proto.pb $(find -L ${PROTODIR} -name "*.proto")
echo "make proto done"
echo "gen proto lua class define"
cd ${PROTODIR}
${ROOT}/lua gen.lua

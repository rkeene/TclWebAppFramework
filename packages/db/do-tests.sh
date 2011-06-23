#! /bin/bash

echo 'SQLite:'
./test.tcl sqlite || exit 1

echo ''
echo 'MySQL:'
./test.tcl mysql:webapp_test:unleaded:O09vDXOddHzh3cJiJo49EGzgHkrcNyA3 || exit 1

echo ''
echo 'Metakit:'
tclkit ./test.tcl mk4 || exit 1

exit 0

#! /bin/bash

echo 'SQLite:'
time ./test.tcl sqlite || exit 1

echo ''
echo 'MySQL:'
time ./test.tcl mysql:webapp_test:unleaded:O09vDXOddHzh3cJiJo49EGzgHkrcNyA3 || exit 1

echo ''
echo 'Metakit:'
time tclkit ./test.tcl mk4 || exit 1

exit 0

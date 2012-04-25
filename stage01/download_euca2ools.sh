#!/bin/bash
dir=${PWD}

if ls -la | grep boto; then
  rm -fr  ./boto
fi
if ls -la | grep euca2ools-main; then
  rm -fr ./euca2ools-main
fi

wget http://qa-server/4qa/4_euca2ools/deps/boto-new-latest.tar.gz
wget http://qa-server/4qa/4_euca2ools/deps/euca2ools-main-latest.tar.gz

tar xzf euca2ools-main-latest.tar.gz
tar xzf boto-new-latest.tar.gz

rm -f euca2ools-main-latest.tar.gz
rm -f boto-new-latest.tar.gz

if ! ls -la | grep euca2ools-main; then
   exit 1
fi
if ! ls -la | grep boto; then
   exit 1
fi



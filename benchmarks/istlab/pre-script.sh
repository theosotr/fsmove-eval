#! /bin/bash

git clone https://github.com/theosotr/stereoConfig
cd stereoConfig && git checkout path
mkdir /home/mysql
puppet module install puppetlabs-stdlib
cp -r modules/* /home/fsmove/.puppet/etc/code/modules

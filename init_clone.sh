#! /bin/sh

echo '#!CMD:[ find trunk -type d -name bin -exec chmod -R +x {} \; ]'
find trunk -type d -name bin -exec chmod -R +x {} \;

echo '#!CMD:[ find trunk -type d -name bin -exec ls -l {} \; ]'
find trunk -type d -name bin -exec ls -l {} \;

for FILE in `ls -A trunk`; do
	rm -rf $HOME/$FILE
	ln -s -v $PWD/trunk/$FILE $HOME
done

#!/bin/sh
rm -f hxvg.zip
zip -r hxvg.zip src *.hxml *.json *.md run.n
haxelib submit hxvg.zip $HAXELIB_PWD --always
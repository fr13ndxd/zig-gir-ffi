#!/usr/bin/bash
git clone https://github.com/GNOME/gobject-introspection.git && cd gobject-introspection
git checkout 1.74.0 #debian stable
patch girepository/girnode.c ../girnode.patch
meson setup build && cd build
meson compile
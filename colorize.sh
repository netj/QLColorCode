#!/bin/bash

# This code is licensed under the GPL v2.  See LICENSE.txt for details.

# colorize.sh
# QLColorCode
#
# Created by Nathaniel Gray on 11/27/07.
# Copyright 2007 Nathaniel Gray, Jaeho Shin.

# Expects   $1 = path to resources dir of bundle
#           $2 = name of file to colorize
#           $3 = 1 if you want enough for a thumbnail, 0 for the full file
#
# Produces HTML on stdout with exit code 0 on success

###############################################################################

# Fail immediately on failure of sub-command
# Also fail whenever undefined variables are used
set -eu

: \
    ${qlcc_debug:=} \
    ${qlcc_text_fallback:=false} \
    ${maxFileSize:=} \
    ${extraHLFlags:=} \
    #

RsrcDir=$1
Target=$2
case $3 in
    1)   Thumb=true  ;;
    0|*) Thumb=false ;;
esac

debug() { [ -z "$qlcc_debug" ] || ! $Thumb || echo >&2 "QLColorCode: $@"; }

debug Starting colorize.sh

read-target() { cat "$Target"; }

# Define how we invoke highlight
# (See: http://www.andre-simon.de/doku/highlight/en/highlight.html)
lang=
highlightOpts=(
--quiet
--validate-input
--encoding "$textEncoding"
--doc-title "${Target##*/}"
--include-style
--style "$hlTheme"
--font "$font"
--font-size "$fontSizePoints"
--data-dir "$RsrcDir"/highlight/share/highlight
--add-config-dir "$RsrcDir"/etc/highlight
)
invoke-highlight() {
    set -- "${highlightOpts[@]}" $extraHLFlags "$@"
    if [ -n "$lang" ]; then
        set -- --syntax "$lang" "$@"
    fi
    "$RsrcDir"/highlight/bin/highlight "$@"
}

case ${Target##*/} in
    *.graffle )
        # some omnigraffle files are XML and get passed to us.  Ignore them.
        exit 1
        ;;

    *.plist )
        lang=xml
        read-target() { /usr/bin/plutil -convert xml1 -o - "$Target"; }
        ;;

    *.h )
        if grep -q "@interface" "$Target" &>/dev/null; then
            lang=objc
        else
            lang=h
        fi
        ;;

    *.m )
        # look for a matlab-style comment in the first 10 lines, otherwise
        # assume objective-c.  If you never use matlab or never use objc,
        # you might want to hardwire this one way or the other
        if head -n 10 "$Target" | grep -q "^[ 	]*%" &>/dev/null; then
            lang=m
        else
            lang=objc
        fi
        ;;

    *.pro )
        # Can be either IDL or Prolog.  Prolog uses /* */ and % for comments.
        # IDL uses ;
        if head -n 10 "$Target" | grep -q "^[ 	]*;" &>/dev/null; then
            lang=idlang
        else
            lang=pro
        fi
        ;;

    *.* ) 
        lang=${Target##*.}
        ;;

    Makefile )
        lang=make
        ;;

    LICENSE |\
    COPYING |\
    README )
        lang=txt
        ;;
esac
debug Resolved $Target to language $lang

generate-preview () {
    debug Generating the preview
    if $Thumb; then
        head -n 100 | head -c 20000 |
        invoke-highlight
    elif [ -n "$maxFileSize" ]; then
        head -c "$maxFileSize" |
        invoke-highlight
    else
        invoke-highlight
    fi
}

if ! read-target | generate-preview; then
    # Uh-oh, it didn't work, see if we can fallback to text
    if $qlcc_text_fallback || [[ $(file --brief --mime-type "$Target") = text/* ]]; then
        # Fallback to rendering as plain text
        debug First try failed, fallback to plain text
        lang=txt
        read-target | generate-preview
    else
        # Let other QuickLook generator handle
        exit 2
    fi
fi

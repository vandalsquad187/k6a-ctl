#!/system/bin/sh
# k6a-ctl installer banner (Magisk customize)
SKIPUNZIP=0

V=$(grep -m1 '^version=' "$ZIPPATH/module.prop" 2>/dev/null | cut -d= -f2 | tr -d ' \r')
[ -z "$V" ] && V=$(grep -m1 '^version=' ./module.prop 2>/dev/null | cut -d= -f2 | tr -d ' \r')
[ -z "$V" ] && V="1.4.8"

ui_print " ========================================"
ui_print " ██████╗  █████╗  ██████╗  █████╗ ███████╗███████╗"
ui_print " ██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚══███╔╝╚══███╔╝"
ui_print " ██████╔╝███████║██║  ██║███████║  ███╔╝   ███╔╝"
ui_print " ██╔══██╗██╔══██║██║  ██║██╔══██║ ███╔╝   ███╔╝ "
ui_print " ██████╔╝██║  ██║██████╔╝██║  ██║███████╗███████╗"
ui_print " ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝"
ui_print " "
ui_print " ██╗  ██╗███████╗██████╗ ███╗   ██╗███████╗██╗"
ui_print " ██║ ██╔╝██╔════╝██╔══██╗████╗  ██║██╔════╝██║"
ui_print " █████╔╝ █████╗  ██████╔╝██╔██╗ ██║█████╗  ██║"
ui_print " ██╔═██╗ ██╔══╝  ██╔══██╗██║╚██╗██║██╔══╝  ██║"
ui_print " ██║  ██╗███████╗██║  ██║██║ ╚████║███████╗███████╗"
ui_print " ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
ui_print " "
ui_print "            ________        ________"
ui_print "            \ .     \      / .     /"
ui_print "             \_______\    /_______/"
ui_print "              \ .     \  / .     /"
ui_print "               \_______\/_______/"
ui_print "                   .         ."
ui_print "                     \     /"
ui_print "                      \   /"
ui_print "                       \ /"
ui_print "                        <>"
ui_print "             CUSTOM ANDROID KERNEL"
ui_print "                  by BADAZZ89"
ui_print "    [ 8 CORES ] [ 4.14.369 ] [ KSU BUILTIN ]"
ui_print " ========================================"
ui_print " "
ui_print "        [ k6a-ctl v$V installing ]"
ui_print "        governor companion in action"

exit 0

# Object Icon path settings
export OIHOME="@CONFIG_DIR@"
export OIBIN="$OIHOME/bin"
export OILIB="$OIHOME/lib"
export OIPATH="$OILIB/main:$OILIB/gui:$OILIB/xml:$OILIB/parser:$OILIB/ipl"
export OIINCL="$OILIB/incl"
PATH="$PATH:$OIBIN"
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$OILIB/native"
export TRACE OIMAXLEVEL

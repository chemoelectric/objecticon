# Object Icon path settings
export OIHOME="@CONFIG_DIR@"
export OIBIN="$OIHOME/bin"
export OILIB="$OIHOME/lib"
export OIPATH="$OILIB/main:$OILIB/gui:$OILIB/xml:$OILIB/parser:$OILIB/ipl"
export OIINCL="$OILIB/incl"
export OINATIVE="$OILIB/native"
PATH="$OIBIN:$PATH"
export TRACE OIMAXLEVEL

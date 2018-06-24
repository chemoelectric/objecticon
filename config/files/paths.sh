# Object Icon path settings
export OI_HOME="@CONFIG_DIR@"
export OI_BIN="$OI_HOME/bin"
export OI_LIB="$OI_HOME/lib"
export OI_PATH="$OI_LIB/main:$OI_LIB/gui:$OI_LIB/xml:$OI_LIB/parser:$OI_LIB/ipl"
export OI_INCL="$OI_LIB/incl"
export OI_NATIVE="$OI_LIB/native"
unset OIX
PATH="$OI_BIN:$PATH"

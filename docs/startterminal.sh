#!/bin/bash
OI_FLOWTERM_LIST_FOCUS_WIDTH=2 \
~/objecticon/examples/bin/flowterm \
                               -t $HOSTNAME \
                               -width 125 \
                               -height 45 \
                               :key=INSERT,C,*,copy \
                               :key=INSERT,S,*,paste \
                               :key=PGUP,S,*,pgup \
                               :key=PGDN,S,*,pgdn \
                               :key=HOME,S,*,top \
                               :key=END,S,*,bottom \
                               :key=F1,0,*,log=/tmp/log \
                               :key=F2,0,*,clone-tab \
                               :key=F3,0,*,close-tab \
                               :key=F4,0,*,open-history \
                               :key=F5,0,*,tab-left \
                               :key=F5,S,*,move-tab-left \
                               :key=F6,0,*,tab-right \
                               :key=F6,S,*,move-tab-right \
                               :key=F7,0,*,prev \
                               :key=F8,0,*,next \
                               :key=F9,0,*,up \
                               :key=F10,0,*,copy \
                               :key=F11,0,*,paste \
                               :key=F11,M,*,paste-alt \
                               :key=F12,0,*,open-favourites \
                               :key=SCROLL_LOCK,0,*,list-focus \
                               :key=PAUSE,0,*,reorient \
                               :key=MENU,0,*,open-menu=1 \
                               /tmp \
                               $OI_HOME

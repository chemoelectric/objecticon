#!/bin/bash

function dir()
{
	if (( verbose == 1 )) ; then
		echo cd $1
	fi
	cd $1
}

function valid()
{
	if (( verbose == 1 )) ; then
		echo $DIR/testvalid $UCS "$@"
	fi
	$DIR/testvalid $UCS "$@"
}

function wf()
{
	if (( verbose == 1 )) ; then
		echo $DIR/testwf $UCS "$@"
	fi
	$DIR/testwf $UCS "$@"
}

function notwf()
{
	if (( verbose == 1 )) ; then
		echo $DIR/testnotwf $UCS "$@"
	fi
	$DIR/testnotwf $UCS "$@"
}

function invalid()
{
	if (( verbose == 1 )) ; then
		echo $DIR/testinvalid $UCS "$@"
	fi
	$DIR/testinvalid $UCS "$@"
}

DIR=`pwd`
TESTS=$DIR/xmlconf

if [ ! -d $TESTS ] ; then
    echo "The test base directory xmlconf does not exist."
    echo
    echo "Please extract the xmlconf.tar.gz archive to create it,"
    echo "and then run this script again.  Do this by cd'ing to the"
    echo "same directory this script is in, and running :-"
    echo 
    echo "tar xvfz xmlconf.tar.gz"
    echo 
    exit 1
fi

UCS="-u"
if [[ $1 == "-v" ]] ; then
	set -e
	verbose=1
fi

dir $TESTS/rpp
valid 001.xml
invalid 002.xml
invalid 003.xml
valid 004.xml
invalid 005.xml
invalid 007.xml
invalid 008.xml

dir $TESTS/sun/invalid
invalid attr01.xml
invalid attr02.xml
invalid attr03.xml
invalid attr04.xml
invalid attr05.xml
invalid attr06.xml
invalid attr07.xml
invalid attr08.xml
invalid attr09.xml
invalid attr10.xml
invalid attr11.xml
invalid attr12.xml
invalid attr13.xml
invalid attr14.xml
invalid attr15.xml
invalid attr16.xml
invalid dtd01.xml
invalid dtd02.xml
invalid dtd03.xml
invalid dtd06.xml
invalid el01.xml
invalid el02.xml
invalid el03.xml
invalid el04.xml
invalid el05.xml
invalid el06.xml
invalid empty.xml
invalid id01.xml
invalid id02.xml
invalid id03.xml
invalid id04.xml
invalid id05.xml
invalid id06.xml
invalid id07.xml
invalid id08.xml
invalid id09.xml
invalid not-sa01.xml
invalid not-sa02.xml
invalid not-sa03.xml
invalid not-sa04.xml
invalid not-sa05.xml
invalid not-sa06.xml
invalid not-sa07.xml
invalid not-sa08.xml
invalid not-sa09.xml
invalid not-sa10.xml
invalid not-sa11.xml
invalid not-sa12.xml
invalid not-sa13.xml
invalid not-sa14.xml
invalid optional01.xml
invalid optional02.xml
invalid optional03.xml
invalid optional04.xml
invalid optional05.xml
invalid optional06.xml
invalid optional07.xml
invalid optional08.xml
invalid optional09.xml
invalid optional10.xml
invalid optional11.xml
invalid optional12.xml
invalid optional13.xml
invalid optional14.xml
invalid optional15.xml
invalid optional16.xml
invalid optional17.xml
invalid optional18.xml
invalid optional19.xml
invalid optional20.xml
invalid optional21.xml
invalid optional22.xml
invalid optional23.xml
invalid optional24.xml
invalid optional25.xml
# Omitted - can't see that it's right. xmllint passes it okay
#invalid pe01.xml
invalid required00.xml
invalid required01.xml
invalid required02.xml
invalid root.xml
invalid utf16b.xml
invalid utf16l.xml

dir $TESTS/sun/valid
valid dtd00.xml out/dtd00.xml
valid dtd01.xml out/dtd01.xml
valid element.xml out/element.xml
# Omitted - a doc which cannot load an external entity is valid according to this test.
# I can't understand how that can be right.  See 4.4.3
##valid ext01.xml out/ext01.xml
# Omitted - needs UTF16 processing
#valid ext02.xml out/ext02.xml
valid not-sa01.xml out/not-sa01.xml
valid not-sa02.xml out/not-sa02.xml
valid not-sa03.xml out/not-sa03.xml
valid not-sa04.xml out/not-sa04.xml
valid notation01.xml out/notation01.xml
valid optional.xml out/optional.xml
valid -u pe00.xml out/pe00.xml
valid pe01.xml out/pe01.xml
valid pe02.xml out/pe02.xml
valid required00.xml out/required00.xml
valid sa01.xml out/sa01.xml
valid sa02.xml out/sa02.xml
valid sa03.xml out/sa03.xml
valid sa04.xml out/sa04.xml
valid sa05.xml out/sa05.xml
valid sgml01.xml out/sgml01.xml
valid v-lang01.xml out/v-lang01.xml
valid v-lang02.xml out/v-lang02.xml
valid v-lang03.xml out/v-lang03.xml
valid v-lang04.xml out/v-lang04.xml
valid v-lang05.xml out/v-lang05.xml
valid v-lang06.xml out/v-lang06.xml
#exit 0

dir $TESTS/xmltest/valid/sa
valid 001.xml out/001.xml
valid 002.xml out/002.xml
valid 003.xml out/003.xml
valid 004.xml out/004.xml
valid 005.xml out/005.xml
valid 006.xml out/006.xml
valid 007.xml out/007.xml
valid 008.xml out/008.xml
valid 009.xml out/009.xml
valid 010.xml out/010.xml
valid 011.xml out/011.xml
valid 012.xml out/012.xml
valid 013.xml out/013.xml
valid 014.xml out/014.xml
valid 015.xml out/015.xml
valid 016.xml out/016.xml
valid 017.xml out/017.xml
valid 018.xml out/018.xml
valid 019.xml out/019.xml
valid 020.xml out/020.xml
valid 021.xml out/021.xml
valid 022.xml out/022.xml
valid 023.xml out/023.xml
valid 024.xml out/024.xml
valid 025.xml out/025.xml
valid 026.xml out/026.xml
valid 027.xml out/027.xml
valid 028.xml out/028.xml
valid 029.xml out/029.xml
valid 030.xml out/030.xml
valid 031.xml out/031.xml
valid 032.xml out/032.xml
valid 033.xml out/033.xml
valid 034.xml out/034.xml
valid 035.xml out/035.xml
valid 036.xml out/036.xml
valid 037.xml out/037.xml
valid 038.xml out/038.xml
valid 039.xml out/039.xml
valid 040.xml out/040.xml
valid 041.xml out/041.xml
valid 042.xml out/042.xml
valid 043.xml out/043.xml
valid 044.xml out/044.xml
valid 045.xml out/045.xml
valid 046.xml out/046.xml
valid 047.xml out/047.xml
valid 048.xml out/048.xml
#Omitted: need UTF-16
#valid 049.xml out/049.xml
#valid 050.xml out/050.xml
#valid 051.xml out/051.xml
valid 052.xml out/052.xml
valid 053.xml out/053.xml
valid 054.xml out/054.xml
valid 055.xml out/055.xml
valid 056.xml out/056.xml
valid 057.xml out/057.xml
valid 058.xml out/058.xml
valid 059.xml out/059.xml
valid 060.xml out/060.xml
valid -u 061.xml out/061.xml
valid -u 062.xml out/062.xml
valid -u 063.xml out/063.xml
valid -u 064.xml out/064.xml
valid 065.xml out/065.xml
valid 066.xml out/066.xml
valid 067.xml out/067.xml
# Omitted- my canonical form output retains the mapping from \r -> \n
#valid 068.xml out/068.xml
valid 069.xml out/069.xml
valid 070.xml out/070.xml
valid 071.xml out/071.xml
valid 072.xml out/072.xml
valid 073.xml out/073.xml
valid 074.xml out/074.xml
valid 075.xml out/075.xml
valid 076.xml out/076.xml
valid 077.xml out/077.xml
valid 078.xml out/078.xml
valid 079.xml out/079.xml
valid 080.xml out/080.xml
valid 081.xml out/081.xml
valid 082.xml out/082.xml
valid 083.xml out/083.xml
valid 084.xml out/084.xml
valid 085.xml out/085.xml
valid 086.xml out/086.xml
valid 087.xml out/087.xml
valid 088.xml out/088.xml
valid -u 089.xml out/089.xml
valid 090.xml out/090.xml
valid 091.xml out/091.xml
valid 092.xml out/092.xml
valid 093.xml out/093.xml
valid 094.xml out/094.xml
valid 095.xml out/095.xml
valid 096.xml out/096.xml
valid 097.xml out/097.xml
valid 098.xml out/098.xml
valid 099.xml out/099.xml
valid 100.xml out/100.xml
valid 101.xml out/101.xml
valid 102.xml out/102.xml
valid 103.xml out/103.xml
valid 104.xml out/104.xml
valid 105.xml out/105.xml
valid 106.xml out/106.xml
valid 107.xml out/107.xml
valid 108.xml out/108.xml
valid 109.xml out/109.xml
valid 110.xml out/110.xml
valid 111.xml out/111.xml
valid 112.xml out/112.xml
valid 113.xml out/113.xml
valid 114.xml out/114.xml
valid 115.xml out/115.xml
valid 116.xml out/116.xml
valid 117.xml out/117.xml
valid 118.xml out/118.xml
valid 119.xml out/119.xml

dir $TESTS/xmltest/valid/not-sa
valid 001.xml out/001.xml
valid 002.xml out/002.xml
# Omitted - missing external entity is a fatal error
#valid 003.xml out/003.xml
valid 004.xml out/004.xml
valid 005.xml out/005.xml
valid 006.xml out/006.xml
valid 007.xml out/007.xml
valid 008.xml out/008.xml
valid 009.xml out/009.xml
valid 010.xml out/010.xml
valid 011.xml out/011.xml
#
# Omitted.  External entity 012.ent contains a PI beginning <?xml, which is
# illegal.  xmllint passes this okay, wrongly in my view.
# 
#valid 012.xml out/012.xml
valid 013.xml out/013.xml
valid 014.xml out/014.xml
valid 015.xml out/015.xml
valid 016.xml out/016.xml
valid 017.xml out/017.xml
valid 018.xml out/018.xml
valid 019.xml out/019.xml
valid 020.xml out/020.xml
valid 021.xml out/021.xml
valid 022.xml out/022.xml
valid 023.xml out/023.xml
valid 024.xml out/024.xml
valid 025.xml out/025.xml
valid 026.xml out/026.xml
valid 027.xml out/027.xml
valid 028.xml out/028.xml
valid 029.xml out/029.xml
valid 030.xml out/030.xml
valid 031.xml out/031.xml

dir $TESTS/xmltest/valid/ext-sa
valid 001.xml out/001.xml
valid 002.xml out/002.xml
valid 003.xml out/003.xml
valid 004.xml out/004.xml
valid 005.xml out/005.xml
valid 006.xml out/006.xml
#Omitted: utf-16 in the external entity
#valid 007.xml out/007.xml
#valid 008.xml out/008.xml
valid 009.xml out/009.xml
valid 010.xml out/010.xml
valid 011.xml out/011.xml
valid 012.xml out/012.xml
valid 013.xml out/013.xml
# Omitted: utf-16 in the external entity
#valid 014.xml out/014.xml

dir $TESTS/xmltest/invalid
invalid 001.xml
# Omitted: Don't currently validate that expanded PE's mark end of markupdecl production
# (see spec 2.8, Validity constraint: Proper Declaration/PE Nesting)
#invalid 002.xml
#invalid 006.xml
#invalid 005.xml
invalid 003.xml
invalid 004.xml

dir $TESTS/xmltest/not-wf/not-sa
notwf 001.xml
notwf 002.xml
notwf 003.xml
notwf 004.xml
notwf 005.xml
notwf 006.xml
notwf 007.xml
notwf 008.xml

dir $TESTS/xmltest/not-wf/ext-sa
notwf 001.xml
notwf 002.xml
notwf 003.xml

dir $TESTS/xmltest/not-wf/sa

notwf 001.xml
notwf 002.xml
notwf 003.xml
notwf 004.xml
notwf 005.xml
notwf 006.xml
notwf 007.xml
notwf 008.xml
notwf 009.xml
notwf 010.xml
notwf 011.xml
notwf 012.xml
notwf 013.xml
notwf 014.xml
notwf 015.xml
notwf 016.xml
notwf 017.xml
notwf 018.xml
notwf 019.xml
notwf 020.xml
notwf 021.xml
notwf 022.xml
notwf 023.xml
notwf 024.xml
notwf 025.xml
notwf 026.xml
notwf 027.xml
notwf 028.xml
notwf 029.xml
notwf 030.xml
notwf 031.xml
notwf 032.xml
notwf 033.xml
notwf 034.xml
notwf 035.xml
notwf 036.xml
notwf 037.xml
notwf 038.xml
notwf 039.xml
notwf 040.xml
notwf 041.xml
notwf 042.xml
notwf 043.xml
notwf 044.xml
notwf 045.xml
notwf 046.xml
notwf 047.xml
notwf 048.xml
notwf 049.xml
notwf 051.xml
notwf 052.xml
notwf 053.xml
notwf 054.xml
notwf 055.xml
notwf 056.xml
notwf 057.xml
notwf 058.xml
notwf 059.xml
notwf 060.xml
notwf 061.xml
notwf 062.xml
notwf 063.xml
notwf 064.xml
notwf 065.xml
notwf 066.xml
notwf 067.xml
notwf 068.xml
notwf 069.xml
notwf 070.xml
notwf 071.xml
notwf 072.xml
notwf 073.xml
notwf 074.xml
notwf 075.xml
notwf 076.xml
notwf 077.xml
notwf 078.xml
notwf 079.xml
notwf 080.xml
notwf 081.xml
notwf 082.xml
notwf 083.xml
notwf 084.xml
notwf 085.xml
notwf 086.xml
notwf 087.xml
notwf 088.xml
notwf 089.xml
notwf 090.xml
notwf 091.xml
notwf 092.xml
notwf 093.xml
notwf 094.xml
notwf 095.xml
notwf 096.xml
notwf 097.xml
notwf 098.xml
notwf 099.xml
notwf 100.xml
notwf 101.xml
notwf 102.xml
notwf 103.xml
notwf 104.xml
notwf 105.xml
notwf 106.xml
notwf 107.xml
notwf 108.xml
notwf 109.xml
notwf 110.xml
notwf 111.xml
notwf 112.xml
notwf 113.xml
notwf 114.xml
notwf 115.xml
notwf 116.xml
notwf 117.xml
notwf 118.xml
notwf 119.xml
notwf 120.xml
notwf 121.xml
notwf 122.xml
notwf 123.xml
notwf 124.xml
notwf 125.xml
notwf 126.xml
notwf 127.xml
notwf 128.xml
notwf 129.xml
notwf 130.xml
notwf 131.xml
notwf 132.xml
notwf 133.xml
notwf 134.xml
notwf 135.xml
notwf 136.xml
notwf 137.xml
notwf 138.xml
notwf 139.xml
notwf 140.xml
notwf 141.xml
notwf 142.xml
notwf 143.xml
notwf 144.xml
notwf 145.xml
notwf 146.xml
notwf 147.xml
notwf 148.xml
notwf 149.xml
notwf 150.xml
notwf 151.xml
notwf 152.xml
notwf 153.xml
notwf 154.xml
notwf 155.xml
notwf 156.xml
notwf 157.xml
notwf 158.xml
notwf 159.xml
notwf 160.xml
notwf 161.xml
notwf 162.xml
notwf 163.xml
notwf 164.xml
notwf 165.xml
notwf -u 166.xml
notwf -u 167.xml
notwf -u 168.xml
notwf -u 169.xml
notwf -u 170.xml
notwf -u 171.xml
notwf -u 172.xml
notwf -u 173.xml
notwf -u 174.xml
notwf -u 175.xml
notwf 176.xml
notwf -u 177.xml
notwf 178.xml
notwf 179.xml
notwf 180.xml
notwf 181.xml
notwf 182.xml
notwf 183.xml
notwf 184.xml
notwf 185.xml
notwf 186.xml


dir $TESTS/oasis

notwf p01fail1.xml
notwf p01fail2.xml
notwf p01fail3.xml
notwf p01fail4.xml
notwf p02fail1.xml
notwf p02fail10.xml
notwf p02fail11.xml
notwf p02fail12.xml
notwf p02fail13.xml
notwf p02fail14.xml
notwf p02fail15.xml
notwf p02fail16.xml
notwf p02fail17.xml
notwf p02fail18.xml
notwf p02fail19.xml
notwf p02fail2.xml
notwf p02fail20.xml
notwf p02fail21.xml
notwf p02fail22.xml
notwf p02fail23.xml
notwf p02fail24.xml
notwf p02fail25.xml
notwf p02fail26.xml
notwf p02fail27.xml
notwf p02fail28.xml
notwf p02fail29.xml
notwf p02fail3.xml
notwf p02fail30.xml
notwf p02fail31.xml
notwf p02fail4.xml
notwf p02fail5.xml
notwf p02fail6.xml
notwf p02fail7.xml
notwf p02fail8.xml
notwf p02fail9.xml
notwf p03fail1.xml
notwf p03fail10.xml
notwf p03fail11.xml
notwf p03fail12.xml
notwf p03fail13.xml
notwf p03fail14.xml
notwf p03fail15.xml
notwf p03fail16.xml
notwf p03fail17.xml
notwf p03fail18.xml
notwf p03fail19.xml
notwf p03fail2.xml
notwf p03fail20.xml
notwf p03fail21.xml
notwf p03fail22.xml
notwf p03fail23.xml
notwf p03fail24.xml
notwf p03fail25.xml
notwf p03fail26.xml
notwf p03fail27.xml
notwf p03fail28.xml
notwf p03fail29.xml
notwf p03fail3.xml
notwf p03fail4.xml
notwf p03fail5.xml
notwf p03fail7.xml
notwf p03fail8.xml
notwf p03fail9.xml
notwf p04fail1.xml
notwf p04fail2.xml
notwf p04fail3.xml
notwf p05fail1.xml
notwf p05fail2.xml
notwf p05fail3.xml
notwf p05fail4.xml
notwf -u p05fail5.xml
invalid p06fail1.xml
invalid p08fail1.xml
invalid p08fail2.xml
notwf p09fail1.xml
notwf p09fail2.xml
notwf p09fail3.xml
notwf p09fail4.xml
notwf p09fail5.xml
notwf p10fail1.xml
notwf p10fail2.xml
notwf p10fail3.xml
notwf p11fail1.xml
notwf p11fail2.xml
notwf p12fail1.xml
notwf p12fail2.xml
notwf p12fail3.xml
notwf p12fail4.xml
notwf p12fail5.xml
notwf p12fail6.xml
notwf p12fail7.xml
notwf p14fail1.xml
notwf p14fail2.xml
notwf p14fail3.xml
notwf p15fail1.xml
notwf p15fail2.xml
notwf p15fail3.xml
notwf p16fail1.xml
notwf p16fail2.xml
invalid p16fail3.xml
notwf p18fail1.xml
notwf p18fail2.xml
notwf p18fail3.xml
notwf p22fail1.xml
notwf p22fail2.xml
notwf p23fail1.xml
notwf p23fail2.xml
notwf p23fail3.xml
notwf p23fail4.xml
notwf p23fail5.xml
notwf p24fail1.xml
notwf p24fail2.xml
notwf p25fail1.xml
notwf p26fail1.xml
notwf p26fail2.xml
notwf p27fail1.xml
notwf p28fail1.xml
notwf p29fail1.xml
notwf p30fail1.xml
notwf p31fail1.xml
notwf p32fail1.xml
notwf p32fail2.xml
notwf p32fail3.xml
notwf p32fail4.xml
notwf p32fail5.xml
notwf p39fail1.xml
notwf p39fail2.xml
notwf p39fail4.xml
notwf p39fail5.xml
notwf p40fail1.xml
notwf p40fail2.xml
notwf p40fail3.xml
notwf p40fail4.xml
notwf p41fail1.xml
notwf p41fail2.xml
notwf p41fail3.xml
notwf p42fail1.xml
notwf p42fail2.xml
notwf p42fail3.xml
notwf p43fail1.xml
notwf p43fail2.xml
notwf p43fail3.xml
notwf p44fail1.xml
notwf p44fail2.xml
notwf p44fail3.xml
notwf p44fail4.xml
notwf p44fail5.xml
notwf p45fail1.xml
notwf p45fail2.xml
notwf p45fail3.xml
notwf p45fail4.xml
notwf p46fail1.xml
notwf p46fail2.xml
notwf p46fail3.xml
notwf p46fail4.xml
notwf p46fail5.xml
notwf p46fail6.xml
notwf p47fail1.xml
notwf p47fail2.xml
notwf p47fail3.xml
notwf p47fail4.xml
notwf p48fail1.xml
notwf p48fail2.xml
notwf p49fail1.xml
notwf p50fail1.xml
notwf p51fail1.xml
notwf p51fail2.xml
notwf p51fail3.xml
notwf p51fail4.xml
notwf p51fail5.xml
notwf p51fail6.xml
notwf p51fail7.xml
notwf p52fail1.xml
notwf p52fail2.xml
notwf p53fail1.xml
notwf p53fail2.xml
notwf p53fail3.xml
notwf p53fail4.xml
notwf p53fail5.xml
notwf p54fail1.xml
notwf p55fail1.xml
notwf p56fail1.xml
notwf p56fail2.xml
notwf p56fail3.xml
notwf p56fail4.xml
notwf p56fail5.xml
notwf p57fail1.xml
notwf p58fail1.xml
notwf p58fail2.xml
notwf p58fail3.xml
notwf p58fail4.xml
notwf p58fail5.xml
notwf p58fail6.xml
notwf p58fail7.xml
notwf p58fail8.xml
notwf p59fail1.xml
notwf p59fail2.xml
notwf p59fail3.xml
notwf p60fail1.xml
notwf p60fail2.xml
notwf p60fail3.xml
notwf p60fail4.xml
notwf p60fail5.xml
notwf p61fail1.xml
notwf p62fail1.xml
notwf p62fail2.xml
notwf p63fail1.xml
notwf p63fail2.xml
notwf p64fail1.xml
notwf p64fail2.xml
notwf p66fail1.xml
notwf p66fail2.xml
notwf p66fail3.xml
notwf p66fail4.xml
notwf p66fail5.xml
notwf p66fail6.xml
notwf p68fail1.xml
notwf p68fail2.xml
notwf p68fail3.xml
notwf p69fail1.xml
notwf p69fail2.xml
notwf p69fail3.xml
notwf p70fail1.xml
notwf p71fail1.xml
notwf p71fail2.xml
notwf p71fail3.xml
notwf p71fail4.xml
notwf p72fail1.xml
notwf p72fail2.xml
notwf p72fail3.xml
notwf p72fail4.xml
notwf p73fail1.xml
notwf p73fail2.xml
notwf p73fail3.xml
notwf p73fail4.xml
notwf p73fail5.xml
notwf p74fail1.xml
notwf p74fail2.xml
notwf p74fail3.xml
notwf p75fail1.xml
notwf p75fail2.xml
notwf p75fail3.xml
notwf p75fail4.xml
notwf p75fail5.xml
notwf p75fail6.xml
notwf p76fail1.xml
notwf p76fail2.xml
notwf p76fail3.xml
notwf p76fail4.xml

wf p01pass1.xml
wf p01pass2.xml
wf p01pass3.xml
wf p03pass1.xml
wf -u p04pass1.xml
wf p05pass1.xml
wf p06pass1.xml
wf p07pass1.xml
wf p08pass1.xml
wf p09pass1.xml
wf p10pass1.xml
wf p11pass1.xml
wf p12pass1.xml
wf p14pass1.xml
wf p15pass1.xml
wf p16pass1.xml
wf p16pass2.xml
wf p16pass3.xml
wf p18pass1.xml
wf p22pass1.xml
wf p22pass2.xml
wf p22pass3.xml
wf p22pass4.xml
wf p22pass5.xml
wf p22pass6.xml
wf p23pass1.xml
wf p23pass2.xml
wf p23pass3.xml
wf p23pass4.xml
wf p24pass1.xml
wf p24pass2.xml
wf p24pass3.xml
wf p24pass4.xml
wf p25pass1.xml
wf p25pass2.xml
wf p26pass1.xml
wf p27pass1.xml
wf p27pass2.xml
wf p27pass3.xml
wf p27pass4.xml
wf p28pass1.xml
wf p28pass2.xml
wf p28pass3.xml
wf p28pass4.xml
wf p28pass5.xml
wf p29pass1.xml
wf p30pass1.xml
wf p30pass2.xml
wf p31pass1.xml
wf p31pass2.xml
wf p32pass1.xml
wf p32pass2.xml
wf p39pass1.xml
wf p39pass2.xml
wf p40pass1.xml
wf p40pass2.xml
wf p40pass3.xml
wf p40pass4.xml
wf p41pass1.xml
wf p41pass2.xml
wf p42pass1.xml
wf p42pass2.xml
wf p43pass1.xml
wf p44pass1.xml
wf p44pass2.xml
wf p44pass3.xml
wf p44pass4.xml
wf p44pass5.xml
wf p45pass1.xml
wf p46pass1.xml
wf p47pass1.xml
wf p48pass1.xml
wf p49pass1.xml
wf p50pass1.xml
wf p51pass1.xml
wf p52pass1.xml
wf p53pass1.xml
wf p54pass1.xml
wf p55pass1.xml
wf p56pass1.xml
wf p57pass1.xml
wf p58pass1.xml
wf p59pass1.xml
wf p60pass1.xml
wf p61pass1.xml
wf p62pass1.xml
wf p63pass1.xml
wf p64pass1.xml
wf p66pass1.xml
wf p68pass1.xml
wf p69pass1.xml
wf p70pass1.xml
wf p71pass1.xml
wf p72pass1.xml
wf p73pass1.xml
wf p74pass1.xml
wf p75pass1.xml
wf p76pass1.xml

dir $TESTS/ibm/invalid

dir $TESTS/ibm/invalid/P29
invalid ibm29i01.xml out/ibm29i01.xml

dir $TESTS/ibm/invalid/P32
invalid ibm32i01.xml out/ibm32i01.xml

dir $TESTS/ibm/invalid/P32
invalid ibm32i02.xml out/ibm32i02.xml

# Don't do some standalone=yes tests
#dir $TESTS/ibm/invalid/P32
#invalid ibm32i03.xml out/ibm32i03.xml
#
#dir $TESTS/ibm/invalid/P32
#invalid ibm32i04.xml out/ibm32i04.xml
#
dir $TESTS/ibm/invalid/P39
invalid ibm39i01.xml out/ibm39i01.xml

dir $TESTS/ibm/invalid/P39
invalid ibm39i02.xml out/ibm39i02.xml

dir $TESTS/ibm/invalid/P39
invalid ibm39i03.xml out/ibm39i03.xml

dir $TESTS/ibm/invalid/P39
invalid ibm39i04.xml out/ibm39i04.xml

dir $TESTS/ibm/invalid/P41
invalid ibm41i01.xml out/ibm41i01.xml

dir $TESTS/ibm/invalid/P41
invalid ibm41i02.xml out/ibm41i02.xml

dir $TESTS/ibm/invalid/P45
invalid ibm45i01.xml out/ibm45i01.xml

# Don't check for unbalanced parentheses etc (3.2.1) in pe expansions in contentspec
#dir $TESTS/ibm/invalid/P49
#invalid ibm49i01.xml out/ibm49i01.xml
#
dir $TESTS/ibm/invalid/P49
invalid ibm49i02.xml out/ibm49i02.xml

# Don't check for unbalanced parentheses etc (3.2.1) in pe expansions in contentspec
#dir $TESTS/ibm/invalid/P50
#invalid ibm50i01.xml out/ibm50i01.xml
#
#dir $TESTS/ibm/invalid/P51
#invalid ibm51i01.xml out/ibm51i01.xml
#
dir $TESTS/ibm/invalid/P51
invalid ibm51i03.xml out/ibm51i03.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i01.xml out/ibm56i01.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i02.xml out/ibm56i02.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i03.xml out/ibm56i03.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i05.xml out/ibm56i05.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i06.xml out/ibm56i06.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i07.xml out/ibm56i07.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i08.xml out/ibm56i08.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i09.xml out/ibm56i09.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i10.xml out/ibm56i10.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i11.xml out/ibm56i11.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i12.xml out/ibm56i12.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i13.xml out/ibm56i13.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i14.xml out/ibm56i14.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i15.xml out/ibm56i15.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i16.xml out/ibm56i16.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i17.xml out/ibm56i17.xml

dir $TESTS/ibm/invalid/P56
invalid ibm56i18.xml out/ibm56i18.xml

dir $TESTS/ibm/invalid/P58
invalid ibm58i01.xml out/ibm58i01.xml

dir $TESTS/ibm/invalid/P58
invalid ibm58i02.xml out/ibm58i02.xml

dir $TESTS/ibm/invalid/P59
invalid ibm59i01.xml out/ibm59i01.xml

dir $TESTS/ibm/invalid/P60
invalid ibm60i01.xml out/ibm60i01.xml

dir $TESTS/ibm/invalid/P60
invalid ibm60i02.xml out/ibm60i02.xml

dir $TESTS/ibm/invalid/P60
invalid ibm60i03.xml out/ibm60i03.xml

dir $TESTS/ibm/invalid/P60
invalid ibm60i04.xml out/ibm60i04.xml

dir $TESTS/ibm/invalid/P68
invalid ibm68i01.xml out/ibm68i01.xml

dir $TESTS/ibm/invalid/P68
invalid ibm68i02.xml out/ibm68i02.xml

dir $TESTS/ibm/invalid/P68
invalid ibm68i03.xml out/ibm68i03.xml

dir $TESTS/ibm/invalid/P68
invalid ibm68i04.xml out/ibm68i04.xml

dir $TESTS/ibm/invalid/P69
invalid ibm69i01.xml out/ibm69i01.xml

dir $TESTS/ibm/invalid/P69
invalid ibm69i02.xml out/ibm69i02.xml

dir $TESTS/ibm/invalid/P69
invalid ibm69i03.xml out/ibm69i03.xml

dir $TESTS/ibm/invalid/P69
invalid ibm69i04.xml out/ibm69i04.xml

dir $TESTS/ibm/invalid/P76
invalid ibm76i01.xml out/ibm76i01.xml

dir $TESTS/ibm/invalid/P28
invalid ibm28i01.xml out/ibm28i01.xml


dir $TESTS/ibm/not-wf/misc
# Omitted: don't check entity expansions for well-formedness until their use.
#notwf 432gewf.xml
notwf ltinentval.xml
notwf simpleltinentval.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n01.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n02.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n03.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n04.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n05.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n06.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n07.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n08.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n09.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n10.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n11.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n12.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n13.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n14.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n15.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n16.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n17.xml

dir $TESTS/ibm/not-wf/P04
notwf ibm04n18.xml

dir $TESTS/ibm/not-wf/P05
notwf ibm05n01.xml

dir $TESTS/ibm/not-wf/P05
notwf ibm05n02.xml

dir $TESTS/ibm/not-wf/P05
notwf ibm05n03.xml

dir $TESTS/ibm/not-wf/P05
notwf -u ibm05n04.xml

dir $TESTS/ibm/not-wf/P05
notwf -u ibm05n05.xml

dir $TESTS/ibm/not-wf/P09
notwf ibm09n01.xml

dir $TESTS/ibm/not-wf/P09
notwf ibm09n02.xml

dir $TESTS/ibm/not-wf/P09
notwf ibm09n03.xml

dir $TESTS/ibm/not-wf/P09
notwf ibm09n04.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n01.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n02.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n03.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n04.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n05.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n06.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n07.xml

dir $TESTS/ibm/not-wf/P10
notwf ibm10n08.xml

dir $TESTS/ibm/not-wf/P11
notwf ibm11n01.xml

dir $TESTS/ibm/not-wf/P11
notwf ibm11n02.xml

dir $TESTS/ibm/not-wf/P11
notwf ibm11n03.xml

dir $TESTS/ibm/not-wf/P11
notwf ibm11n04.xml

dir $TESTS/ibm/not-wf/P12
notwf ibm12n01.xml

dir $TESTS/ibm/not-wf/P12
notwf ibm12n02.xml

dir $TESTS/ibm/not-wf/P12
notwf ibm12n03.xml

dir $TESTS/ibm/not-wf/P13
notwf ibm13n01.xml

dir $TESTS/ibm/not-wf/P13
notwf ibm13n02.xml

dir $TESTS/ibm/not-wf/P13
notwf ibm13n03.xml

dir $TESTS/ibm/not-wf/P14
notwf ibm14n01.xml

dir $TESTS/ibm/not-wf/P14
notwf ibm14n02.xml

dir $TESTS/ibm/not-wf/P14
notwf ibm14n03.xml

dir $TESTS/ibm/not-wf/P15
notwf ibm15n01.xml

dir $TESTS/ibm/not-wf/P15
notwf ibm15n02.xml

dir $TESTS/ibm/not-wf/P15
notwf ibm15n03.xml

dir $TESTS/ibm/not-wf/P15
notwf ibm15n04.xml

dir $TESTS/ibm/not-wf/P16
notwf ibm16n01.xml

dir $TESTS/ibm/not-wf/P16
notwf ibm16n02.xml

dir $TESTS/ibm/not-wf/P16
notwf ibm16n03.xml

dir $TESTS/ibm/not-wf/P16
notwf ibm16n04.xml

dir $TESTS/ibm/not-wf/P17
notwf ibm17n01.xml

dir $TESTS/ibm/not-wf/P17
notwf ibm17n02.xml

dir $TESTS/ibm/not-wf/P17
notwf ibm17n03.xml

dir $TESTS/ibm/not-wf/P17
notwf ibm17n04.xml

dir $TESTS/ibm/not-wf/P18
notwf ibm18n01.xml

dir $TESTS/ibm/not-wf/P18
notwf ibm18n02.xml

dir $TESTS/ibm/not-wf/P19
notwf ibm19n01.xml

dir $TESTS/ibm/not-wf/P19
notwf ibm19n02.xml

dir $TESTS/ibm/not-wf/P19
notwf ibm19n03.xml

dir $TESTS/ibm/not-wf/P20
notwf ibm20n01.xml

dir $TESTS/ibm/not-wf/P21
notwf ibm21n01.xml

dir $TESTS/ibm/not-wf/P21
notwf ibm21n02.xml

dir $TESTS/ibm/not-wf/P21
notwf ibm21n03.xml

dir $TESTS/ibm/not-wf/P22
notwf ibm22n01.xml

dir $TESTS/ibm/not-wf/P22
notwf ibm22n02.xml

dir $TESTS/ibm/not-wf/P22
notwf ibm22n03.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n01.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n02.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n03.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n04.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n05.xml

dir $TESTS/ibm/not-wf/P23
notwf ibm23n06.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n01.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n02.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n03.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n04.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n05.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n06.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n07.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n08.xml

dir $TESTS/ibm/not-wf/P24
notwf ibm24n09.xml

dir $TESTS/ibm/not-wf/P25
notwf ibm25n01.xml

dir $TESTS/ibm/not-wf/P25
notwf ibm25n02.xml

dir $TESTS/ibm/not-wf/P26
notwf ibm26n01.xml

dir $TESTS/ibm/not-wf/P27
notwf ibm27n01.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n01.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n02.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n03.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n04.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n05.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n06.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n07.xml

dir $TESTS/ibm/not-wf/P28
notwf ibm28n08.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n01.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n02.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n03.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n04.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n05.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n06.xml

dir $TESTS/ibm/not-wf/P29
notwf ibm29n07.xml

dir $TESTS/ibm/not-wf/P30
notwf ibm30n01.xml

dir $TESTS/ibm/not-wf/P31
notwf ibm31n01.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n01.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n02.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n03.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n04.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n05.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n06.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n07.xml

dir $TESTS/ibm/not-wf/P32
notwf ibm32n08.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n01.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n02.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n03.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n04.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n05.xml

dir $TESTS/ibm/not-wf/P39
notwf ibm39n06.xml

dir $TESTS/ibm/not-wf/P40
notwf ibm40n01.xml

dir $TESTS/ibm/not-wf/P40
notwf ibm40n02.xml

dir $TESTS/ibm/not-wf/P40
notwf ibm40n03.xml

dir $TESTS/ibm/not-wf/P40
notwf ibm40n04.xml

dir $TESTS/ibm/not-wf/P40
notwf ibm40n05.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n01.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n02.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n03.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n04.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n05.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n06.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n07.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n08.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n09.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n10.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n11.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n12.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n13.xml

dir $TESTS/ibm/not-wf/P41
notwf ibm41n14.xml

dir $TESTS/ibm/not-wf/P42
notwf ibm42n01.xml

dir $TESTS/ibm/not-wf/P42
notwf ibm42n02.xml

dir $TESTS/ibm/not-wf/P42
notwf ibm42n03.xml

dir $TESTS/ibm/not-wf/P42
notwf ibm42n04.xml

dir $TESTS/ibm/not-wf/P42
notwf ibm42n05.xml

dir $TESTS/ibm/not-wf/P43
notwf ibm43n01.xml

dir $TESTS/ibm/not-wf/P43
notwf ibm43n02.xml

dir $TESTS/ibm/not-wf/P43
notwf ibm43n04.xml

dir $TESTS/ibm/not-wf/P43
notwf ibm43n05.xml

dir $TESTS/ibm/not-wf/P44
notwf ibm44n01.xml

dir $TESTS/ibm/not-wf/P44
notwf ibm44n02.xml

dir $TESTS/ibm/not-wf/P44
notwf ibm44n03.xml

dir $TESTS/ibm/not-wf/P44
notwf ibm44n04.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n01.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n02.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n03.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n04.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n05.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n06.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n07.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n08.xml

dir $TESTS/ibm/not-wf/P45
notwf ibm45n09.xml

dir $TESTS/ibm/not-wf/P46
notwf ibm46n01.xml

dir $TESTS/ibm/not-wf/P46
notwf ibm46n02.xml

dir $TESTS/ibm/not-wf/P46
notwf ibm46n03.xml

dir $TESTS/ibm/not-wf/P46
notwf ibm46n04.xml

dir $TESTS/ibm/not-wf/P46
notwf ibm46n05.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n01.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n02.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n03.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n04.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n05.xml

dir $TESTS/ibm/not-wf/P47
notwf ibm47n06.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n01.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n02.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n03.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n04.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n05.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n06.xml

dir $TESTS/ibm/not-wf/P48
notwf ibm48n07.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n01.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n02.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n03.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n04.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n05.xml

dir $TESTS/ibm/not-wf/P49
notwf ibm49n06.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n01.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n02.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n03.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n04.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n05.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n06.xml

dir $TESTS/ibm/not-wf/P50
notwf ibm50n07.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n01.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n02.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n03.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n04.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n05.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n06.xml

dir $TESTS/ibm/not-wf/P51
notwf ibm51n07.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n01.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n02.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n03.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n04.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n05.xml

dir $TESTS/ibm/not-wf/P52
notwf ibm52n06.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n01.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n02.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n03.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n04.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n05.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n06.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n07.xml

dir $TESTS/ibm/not-wf/P53
notwf ibm53n08.xml

dir $TESTS/ibm/not-wf/P54
notwf ibm54n01.xml

dir $TESTS/ibm/not-wf/P54
notwf ibm54n02.xml

dir $TESTS/ibm/not-wf/P55
notwf ibm55n01.xml

dir $TESTS/ibm/not-wf/P55
notwf ibm55n02.xml

dir $TESTS/ibm/not-wf/P55
notwf ibm55n03.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n01.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n02.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n03.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n04.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n05.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n06.xml

dir $TESTS/ibm/not-wf/P56
notwf ibm56n07.xml

dir $TESTS/ibm/not-wf/P57
notwf ibm57n01.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n01.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n02.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n03.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n04.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n05.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n06.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n07.xml

dir $TESTS/ibm/not-wf/P58
notwf ibm58n08.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n01.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n02.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n03.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n04.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n05.xml

dir $TESTS/ibm/not-wf/P59
notwf ibm59n06.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n01.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n02.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n03.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n04.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n05.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n06.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n07.xml

dir $TESTS/ibm/not-wf/P60
notwf ibm60n08.xml

dir $TESTS/ibm/not-wf/P61
notwf ibm61n01.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n01.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n02.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n03.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n04.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n05.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n06.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n07.xml

dir $TESTS/ibm/not-wf/P62
notwf ibm62n08.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n01.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n02.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n03.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n04.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n05.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n06.xml

dir $TESTS/ibm/not-wf/P63
notwf ibm63n07.xml

dir $TESTS/ibm/not-wf/P64
notwf ibm64n01.xml

dir $TESTS/ibm/not-wf/P64
notwf ibm64n02.xml

dir $TESTS/ibm/not-wf/P64
notwf ibm64n03.xml

dir $TESTS/ibm/not-wf/P65
notwf ibm65n01.xml

dir $TESTS/ibm/not-wf/P65
notwf ibm65n02.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n01.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n02.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n03.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n04.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n05.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n06.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n07.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n08.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n09.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n10.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n11.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n12.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n13.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n14.xml

dir $TESTS/ibm/not-wf/P66
notwf ibm66n15.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n01.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n02.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n03.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n04.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n05.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n06.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n07.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n08.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n09.xml

dir $TESTS/ibm/not-wf/P68
notwf ibm68n10.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n01.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n02.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n03.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n04.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n05.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n06.xml

dir $TESTS/ibm/not-wf/P69
notwf ibm69n07.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm70n01.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n01.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n02.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n03.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n04.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n05.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n06.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n07.xml

dir $TESTS/ibm/not-wf/P71
notwf ibm71n08.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n01.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n02.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n03.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n04.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n05.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n06.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n07.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n08.xml

dir $TESTS/ibm/not-wf/P72
notwf ibm72n09.xml

dir $TESTS/ibm/not-wf/P73
notwf ibm73n01.xml

dir $TESTS/ibm/not-wf/P73
notwf ibm73n03.xml

dir $TESTS/ibm/not-wf/P74
notwf ibm74n01.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n01.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n02.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n03.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n04.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n05.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n06.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n07.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n08.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n09.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n10.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n11.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n12.xml

dir $TESTS/ibm/not-wf/P75
notwf ibm75n13.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n01.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n02.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n03.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n04.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n05.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n06.xml

dir $TESTS/ibm/not-wf/P76
notwf ibm76n07.xml

dir $TESTS/ibm/not-wf/P77
notwf ibm77n01.xml

dir $TESTS/ibm/not-wf/P77
notwf ibm77n02.xml

dir $TESTS/ibm/not-wf/P77
notwf ibm77n03.xml

dir $TESTS/ibm/not-wf/P77
notwf ibm77n04.xml

dir $TESTS/ibm/not-wf/P78
notwf ibm78n01.xml

dir $TESTS/ibm/not-wf/P78
notwf ibm78n02.xml

dir $TESTS/ibm/not-wf/P79
notwf ibm79n01.xml

dir $TESTS/ibm/not-wf/P79
notwf ibm79n02.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n01.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n02.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n03.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n04.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n05.xml

dir $TESTS/ibm/not-wf/P80
notwf ibm80n06.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n01.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n02.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n03.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n04.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n05.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n06.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n07.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n08.xml

dir $TESTS/ibm/not-wf/P81
notwf ibm81n09.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n01.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n02.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n03.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n04.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n05.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n06.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n07.xml

dir $TESTS/ibm/not-wf/P82
notwf ibm82n08.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n01.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n02.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n03.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n04.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n05.xml

dir $TESTS/ibm/not-wf/P83
notwf ibm83n06.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n01.xml

dir $TESTS/ibm/not-wf/P85
notwf -u ibm85n02.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n03.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n04.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n05.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n06.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n07.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n08.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n09.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n10.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n100.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n101.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n102.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n103.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n104.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n105.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n106.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n107.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n108.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n109.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n11.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n110.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n111.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n112.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n113.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n114.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n115.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n116.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n117.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n118.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n119.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n12.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n120.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n121.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n122.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n123.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n124.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n125.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n126.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n127.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n128.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n129.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n13.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n130.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n131.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n132.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n133.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n134.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n135.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n136.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n137.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n138.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n139.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n14.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n140.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n141.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n142.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n143.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n144.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n145.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n146.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n147.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n148.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n149.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n15.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n150.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n151.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n152.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n153.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n154.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n155.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n156.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n157.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n158.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n159.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n16.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n160.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n161.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n162.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n163.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n164.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n165.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n166.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n167.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n168.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n169.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n17.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n170.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n171.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n172.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n173.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n174.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n175.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n176.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n177.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n178.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n179.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n18.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n180.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n181.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n182.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n183.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n184.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n185.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n186.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n187.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n188.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n189.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n19.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n190.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n191.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n192.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n193.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n194.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n195.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n196.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n197.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n198.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n20.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n21.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n22.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n23.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n24.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n25.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n26.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n27.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n28.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n29.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n30.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n31.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n32.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n33.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n34.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n35.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n36.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n37.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n38.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n39.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n40.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n41.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n42.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n43.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n44.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n45.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n46.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n47.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n48.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n49.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n50.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n51.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n52.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n53.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n54.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n55.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n56.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n57.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n58.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n59.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n60.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n61.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n62.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n63.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n64.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n65.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n66.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n67.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n68.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n69.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n70.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n71.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n72.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n73.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n74.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n75.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n76.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n77.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n78.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n79.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n80.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n81.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n82.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n83.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n84.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n85.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n86.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n87.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n88.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n89.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n90.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n91.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n92.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n93.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n94.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n95.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n96.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n97.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n98.xml

dir $TESTS/ibm/not-wf/P85
notwf ibm85n99.xml

dir $TESTS/ibm/not-wf/P86
notwf ibm86n01.xml

dir $TESTS/ibm/not-wf/P86
notwf ibm86n02.xml

dir $TESTS/ibm/not-wf/P86
notwf ibm86n03.xml

dir $TESTS/ibm/not-wf/P86
notwf ibm86n04.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n01.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n02.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n03.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n04.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n05.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n06.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n07.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n08.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n09.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n10.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n11.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n12.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n13.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n14.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n15.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n16.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n17.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n18.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n19.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n20.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n21.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n22.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n23.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n24.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n25.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n26.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n27.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n28.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n29.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n30.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n31.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n32.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n33.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n34.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n35.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n36.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n37.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n38.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n39.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n40.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n41.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n42.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n43.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n44.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n45.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n46.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n47.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n48.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n49.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n50.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n51.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n52.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n53.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n54.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n55.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n56.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n57.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n58.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n59.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n60.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n61.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n62.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n63.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n64.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n66.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n67.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n68.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n69.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n70.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n71.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n72.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n73.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n74.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n75.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n76.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n77.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n78.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n79.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n80.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n81.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n82.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n83.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n84.xml

dir $TESTS/ibm/not-wf/P87
notwf ibm87n85.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n01.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n02.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n03.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n04.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n05.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n06.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n08.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n09.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n10.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n11.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n12.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n13.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n14.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n15.xml

dir $TESTS/ibm/not-wf/P88
notwf ibm88n16.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n01.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n02.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n03.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n04.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n05.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n06.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n07.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n08.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n09.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n10.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n11.xml

dir $TESTS/ibm/not-wf/P89
notwf ibm89n12.xml

dir $TESTS/ibm/not-wf/P01
notwf ibm01n01.xml

dir $TESTS/ibm/not-wf/P01
notwf ibm01n02.xml

dir $TESTS/ibm/not-wf/P01
notwf ibm01n03.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n01.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n02.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n03.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n04.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n05.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n06.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n07.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n08.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n09.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n10.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n11.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n12.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n13.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n14.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n15.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n16.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n17.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n18.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n19.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n20.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n21.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n22.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n23.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n24.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n25.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n26.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n27.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n28.xml

dir $TESTS/ibm/not-wf/P02
notwf ibm02n29.xml

dir $TESTS/ibm/not-wf/P02
notwf -u ibm02n30.xml

dir $TESTS/ibm/not-wf/P02
notwf -u ibm02n31.xml

dir $TESTS/ibm/not-wf/P02
notwf -u ibm02n32.xml

dir $TESTS/ibm/not-wf/P02
notwf -u ibm02n33.xml

dir $TESTS/ibm/not-wf/P03
notwf ibm03n01.xml

dir $TESTS/ibm/valid/P01
valid ibm01v01.xml out/ibm01v01.xml

# This file doesn't seem to be valid utf8
#dir $TESTS/ibm/valid/P02
#valid -u ibm02v01.xml out/ibm02v01.xml

dir $TESTS/ibm/valid/P03
valid ibm03v01.xml out/ibm03v01.xml

dir $TESTS/ibm/valid/P09
valid ibm09v01.xml out/ibm09v01.xml

dir $TESTS/ibm/valid/P09
valid ibm09v02.xml out/ibm09v02.xml

dir $TESTS/ibm/valid/P09
valid ibm09v03.xml out/ibm09v03.xml

dir $TESTS/ibm/valid/P09
valid ibm09v04.xml out/ibm09v04.xml

dir $TESTS/ibm/valid/P09
valid ibm09v05.xml out/ibm09v05.xml

dir $TESTS/ibm/valid/P10
valid ibm10v01.xml out/ibm10v01.xml

dir $TESTS/ibm/valid/P10
valid ibm10v02.xml out/ibm10v02.xml

dir $TESTS/ibm/valid/P10
valid ibm10v03.xml out/ibm10v03.xml

dir $TESTS/ibm/valid/P10
valid ibm10v04.xml out/ibm10v04.xml

dir $TESTS/ibm/valid/P10
valid ibm10v05.xml out/ibm10v05.xml

dir $TESTS/ibm/valid/P10
valid ibm10v06.xml out/ibm10v06.xml

dir $TESTS/ibm/valid/P10
valid ibm10v07.xml out/ibm10v07.xml

dir $TESTS/ibm/valid/P10
valid ibm10v08.xml out/ibm10v08.xml

dir $TESTS/ibm/valid/P11
valid ibm11v01.xml out/ibm11v01.xml

dir $TESTS/ibm/valid/P11
valid ibm11v02.xml out/ibm11v02.xml

dir $TESTS/ibm/valid/P11
valid ibm11v03.xml out/ibm11v03.xml

dir $TESTS/ibm/valid/P11
valid ibm11v04.xml out/ibm11v04.xml

dir $TESTS/ibm/valid/P12
valid ibm12v01.xml out/ibm12v01.xml

dir $TESTS/ibm/valid/P12
valid ibm12v02.xml out/ibm12v02.xml

dir $TESTS/ibm/valid/P12
valid ibm12v03.xml out/ibm12v03.xml

dir $TESTS/ibm/valid/P12
valid ibm12v04.xml out/ibm12v04.xml

dir $TESTS/ibm/valid/P13
valid ibm13v01.xml out/ibm13v01.xml

dir $TESTS/ibm/valid/P14
valid ibm14v01.xml out/ibm14v01.xml

dir $TESTS/ibm/valid/P14
valid ibm14v02.xml out/ibm14v02.xml

dir $TESTS/ibm/valid/P14
valid ibm14v03.xml out/ibm14v03.xml

dir $TESTS/ibm/valid/P15
valid ibm15v01.xml out/ibm15v01.xml

dir $TESTS/ibm/valid/P15
valid ibm15v02.xml out/ibm15v02.xml

dir $TESTS/ibm/valid/P15
valid ibm15v03.xml out/ibm15v03.xml

dir $TESTS/ibm/valid/P15
valid ibm15v04.xml out/ibm15v04.xml

dir $TESTS/ibm/valid/P16
valid ibm16v01.xml out/ibm16v01.xml

dir $TESTS/ibm/valid/P16
valid ibm16v02.xml out/ibm16v02.xml

dir $TESTS/ibm/valid/P16
valid ibm16v03.xml out/ibm16v03.xml

dir $TESTS/ibm/valid/P17
valid ibm17v01.xml out/ibm17v01.xml

dir $TESTS/ibm/valid/P18
valid ibm18v01.xml out/ibm18v01.xml

dir $TESTS/ibm/valid/P19
valid ibm19v01.xml out/ibm19v01.xml

dir $TESTS/ibm/valid/P20
valid ibm20v01.xml out/ibm20v01.xml

dir $TESTS/ibm/valid/P20
valid ibm20v02.xml out/ibm20v02.xml

dir $TESTS/ibm/valid/P21
valid ibm21v01.xml out/ibm21v01.xml

dir $TESTS/ibm/valid/P22
valid ibm22v01.xml out/ibm22v01.xml

dir $TESTS/ibm/valid/P22
valid ibm22v02.xml out/ibm22v02.xml

dir $TESTS/ibm/valid/P22
valid ibm22v03.xml out/ibm22v03.xml

dir $TESTS/ibm/valid/P22
valid ibm22v04.xml out/ibm22v04.xml

dir $TESTS/ibm/valid/P22
valid ibm22v05.xml out/ibm22v05.xml

dir $TESTS/ibm/valid/P22
valid ibm22v06.xml out/ibm22v06.xml

dir $TESTS/ibm/valid/P22
valid ibm22v07.xml out/ibm22v07.xml

dir $TESTS/ibm/valid/P23
valid ibm23v01.xml out/ibm23v01.xml

dir $TESTS/ibm/valid/P23
valid ibm23v02.xml out/ibm23v02.xml

dir $TESTS/ibm/valid/P23
valid ibm23v03.xml out/ibm23v03.xml

dir $TESTS/ibm/valid/P23
valid ibm23v04.xml out/ibm23v04.xml

dir $TESTS/ibm/valid/P23
valid ibm23v05.xml out/ibm23v05.xml

dir $TESTS/ibm/valid/P23
valid ibm23v06.xml out/ibm23v06.xml

dir $TESTS/ibm/valid/P24
valid ibm24v01.xml out/ibm24v01.xml

dir $TESTS/ibm/valid/P24
valid ibm24v02.xml out/ibm24v02.xml

dir $TESTS/ibm/valid/P25
valid ibm25v01.xml out/ibm25v01.xml

dir $TESTS/ibm/valid/P25
valid ibm25v02.xml out/ibm25v02.xml

dir $TESTS/ibm/valid/P25
valid ibm25v03.xml out/ibm25v03.xml

dir $TESTS/ibm/valid/P25
valid ibm25v04.xml out/ibm25v04.xml

dir $TESTS/ibm/valid/P26
valid ibm26v01.xml out/ibm26v01.xml

dir $TESTS/ibm/valid/P27
valid ibm27v01.xml out/ibm27v01.xml

dir $TESTS/ibm/valid/P27
valid ibm27v02.xml out/ibm27v02.xml

dir $TESTS/ibm/valid/P27
valid ibm27v03.xml out/ibm27v03.xml

dir $TESTS/ibm/valid/P28
valid ibm28v01.xml out/ibm28v01.xml

dir $TESTS/ibm/valid/P28
valid ibm28v02.xml out/ibm28v02.xml

dir $TESTS/ibm/valid/P29
valid ibm29v01.xml out/ibm29v01.xml

dir $TESTS/ibm/valid/P29
valid ibm29v02.xml out/ibm29v02.xml

dir $TESTS/ibm/valid/P30
valid ibm30v01.xml out/ibm30v01.xml

dir $TESTS/ibm/valid/P30
valid ibm30v02.xml out/ibm30v02.xml

dir $TESTS/ibm/valid/P31
valid ibm31v01.xml out/ibm31v01.xml

dir $TESTS/ibm/valid/P32
valid ibm32v01.xml out/ibm32v01.xml

dir $TESTS/ibm/valid/P32
valid ibm32v02.xml out/ibm32v02.xml

dir $TESTS/ibm/valid/P32
valid ibm32v03.xml out/ibm32v03.xml

dir $TESTS/ibm/valid/P32
valid ibm32v04.xml out/ibm32v04.xml

dir $TESTS/ibm/valid/P33
valid ibm33v01.xml out/ibm33v01.xml

dir $TESTS/ibm/valid/P34
valid ibm34v01.xml out/ibm34v01.xml

dir $TESTS/ibm/valid/P35
valid ibm35v01.xml out/ibm35v01.xml

dir $TESTS/ibm/valid/P36
valid ibm36v01.xml out/ibm36v01.xml

dir $TESTS/ibm/valid/P37
valid ibm37v01.xml out/ibm37v01.xml

dir $TESTS/ibm/valid/P38
valid ibm38v01.xml out/ibm38v01.xml

dir $TESTS/ibm/valid/P39
valid ibm39v01.xml out/ibm39v01.xml

dir $TESTS/ibm/valid/P40
valid ibm40v01.xml out/ibm40v01.xml

dir $TESTS/ibm/valid/P41
valid ibm41v01.xml out/ibm41v01.xml

dir $TESTS/ibm/valid/P42
valid ibm42v01.xml out/ibm42v01.xml

dir $TESTS/ibm/valid/P43
valid ibm43v01.xml out/ibm43v01.xml

dir $TESTS/ibm/valid/P44
valid ibm44v01.xml out/ibm44v01.xml

dir $TESTS/ibm/valid/P45
valid ibm45v01.xml out/ibm45v01.xml

dir $TESTS/ibm/valid/P47
valid ibm47v01.xml out/ibm47v01.xml

dir $TESTS/ibm/valid/P49
valid ibm49v01.xml out/ibm49v01.xml

dir $TESTS/ibm/valid/P50
valid ibm50v01.xml out/ibm50v01.xml

dir $TESTS/ibm/valid/P51
valid ibm51v01.xml out/ibm51v01.xml

dir $TESTS/ibm/valid/P51
valid ibm51v02.xml out/ibm51v02.xml

dir $TESTS/ibm/valid/P52
valid ibm52v01.xml out/ibm52v01.xml

dir $TESTS/ibm/valid/P54
valid ibm54v01.xml out/ibm54v01.xml

dir $TESTS/ibm/valid/P54
valid ibm54v02.xml out/ibm54v02.xml

dir $TESTS/ibm/valid/P54
valid ibm54v03.xml out/ibm54v03.xml

dir $TESTS/ibm/valid/P55
valid ibm55v01.xml out/ibm55v01.xml

dir $TESTS/ibm/valid/P56
valid ibm56v01.xml out/ibm56v01.xml

dir $TESTS/ibm/valid/P56
valid ibm56v02.xml out/ibm56v02.xml

dir $TESTS/ibm/valid/P56
valid ibm56v03.xml out/ibm56v03.xml

dir $TESTS/ibm/valid/P56
valid ibm56v04.xml out/ibm56v04.xml

dir $TESTS/ibm/valid/P56
valid ibm56v05.xml out/ibm56v05.xml

dir $TESTS/ibm/valid/P56
valid ibm56v06.xml out/ibm56v06.xml

dir $TESTS/ibm/valid/P56
valid ibm56v07.xml out/ibm56v07.xml

dir $TESTS/ibm/valid/P56
valid ibm56v08.xml out/ibm56v08.xml

dir $TESTS/ibm/valid/P56
valid ibm56v09.xml out/ibm56v09.xml

dir $TESTS/ibm/valid/P56
valid ibm56v10.xml out/ibm56v10.xml

dir $TESTS/ibm/valid/P57
wf ibm57v01.xml out/ibm57v01.xml

dir $TESTS/ibm/valid/P58
wf ibm58v01.xml out/ibm58v01.xml

dir $TESTS/ibm/valid/P58
valid ibm58v02.xml out/ibm58v02.xml

dir $TESTS/ibm/valid/P59
wf ibm59v01.xml out/ibm59v01.xml

dir $TESTS/ibm/valid/P59
valid ibm59v02.xml out/ibm59v02.xml

dir $TESTS/ibm/valid/P60
valid ibm60v01.xml out/ibm60v01.xml

dir $TESTS/ibm/valid/P60
valid ibm60v02.xml out/ibm60v02.xml

dir $TESTS/ibm/valid/P60
valid ibm60v03.xml out/ibm60v03.xml

dir $TESTS/ibm/valid/P60
valid ibm60v04.xml out/ibm60v04.xml

dir $TESTS/ibm/valid/P61
valid ibm61v01.xml out/ibm61v01.xml

dir $TESTS/ibm/valid/P61
valid ibm61v02.xml out/ibm61v02.xml

dir $TESTS/ibm/valid/P62
valid ibm62v01.xml out/ibm62v01.xml

dir $TESTS/ibm/valid/P62
valid ibm62v02.xml out/ibm62v02.xml

dir $TESTS/ibm/valid/P62
valid ibm62v03.xml out/ibm62v03.xml

dir $TESTS/ibm/valid/P62
valid ibm62v04.xml out/ibm62v04.xml

dir $TESTS/ibm/valid/P62
valid ibm62v05.xml out/ibm62v05.xml

dir $TESTS/ibm/valid/P63
valid ibm63v01.xml out/ibm63v01.xml

dir $TESTS/ibm/valid/P63
valid ibm63v02.xml out/ibm63v02.xml

dir $TESTS/ibm/valid/P63
valid ibm63v03.xml out/ibm63v03.xml

dir $TESTS/ibm/valid/P63
valid ibm63v04.xml out/ibm63v04.xml

dir $TESTS/ibm/valid/P63
valid ibm63v05.xml out/ibm63v05.xml

dir $TESTS/ibm/valid/P64
valid ibm64v01.xml out/ibm64v01.xml

dir $TESTS/ibm/valid/P64
valid ibm64v02.xml out/ibm64v02.xml

dir $TESTS/ibm/valid/P64
valid ibm64v03.xml out/ibm64v03.xml

dir $TESTS/ibm/valid/P65
valid ibm65v01.xml out/ibm65v01.xml

dir $TESTS/ibm/valid/P65
valid ibm65v02.xml out/ibm65v02.xml

dir $TESTS/ibm/valid/P66
valid -u ibm66v01.xml out/ibm66v01.xml

dir $TESTS/ibm/valid/P67
valid ibm67v01.xml out/ibm67v01.xml

dir $TESTS/ibm/valid/P68
valid ibm68v01.xml out/ibm68v01.xml

dir $TESTS/ibm/valid/P68
valid ibm68v02.xml out/ibm68v02.xml

dir $TESTS/ibm/valid/P69
valid ibm69v01.xml out/ibm69v01.xml

dir $TESTS/ibm/valid/P69
valid ibm69v02.xml out/ibm69v02.xml

dir $TESTS/ibm/valid/P70
valid ibm70v01.xml out/ibm70v01.xml

dir $TESTS/ibm/valid/P78
valid ibm78v01.xml out/ibm78v01.xml

dir $TESTS/ibm/valid/P79
valid ibm79v01.xml out/ibm79v01.xml

dir $TESTS/ibm/valid/P82
valid ibm82v01.xml out/ibm82v01.xml

dir $TESTS/ibm/valid/P85
valid -u ibm85v01.xml out/ibm85v01.xml

dir $TESTS/ibm/valid/P86
valid -u ibm86v01.xml out/ibm86v01.xml

dir $TESTS/ibm/valid/P87
valid -u ibm87v01.xml out/ibm87v01.xml

dir $TESTS/ibm/valid/P88
valid -u ibm88v01.xml out/ibm88v01.xml

dir $TESTS/ibm/valid/P89
valid -u ibm89v01.xml out/ibm89v01.xml


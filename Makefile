CC=cc
INSTALL=install
CFLAGS?=
CFLAGS+=$(shell pkg-config --cflags sqlite3 libpcre) -fPIC
LIBS=$(shell pkg-config --libs libpcre)
prefix=/usr
DESTDIR=/

.PHONY : install clean

anki.so : anki.c
	${CC} -shared -o $@ ${CPPFLAGS} ${CFLAGS} -W -Werror anki.c ${LIBS} ${LDFLAGS} -Wl,-z,defs


pcre.so : pcre.c
	${CC} -shared -o $@ ${CPPFLAGS} ${CFLAGS} -W -Werror pcre.c ${LIBS} ${LDFLAGS} -Wl,-z,defs


install : pcre.so
	${INSTALL} -pD -m755 pcre.so ${DESTDIR}${prefix}/lib/sqlite3/pcre.so

clean :
	-rm -f pcre.so

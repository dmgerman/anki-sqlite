DEFAULT=json1.so anki.so
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

extension-functions.so : extension-functions.c
	${CC} -shared -o $@ ${CPPFLAGS} ${CFLAGS} -W extension-functions.c ${LIBS} ${LDFLAGS} -Wl,-z,defs -lm

pcre.so : pcre.c
	${CC} -shared -o $@ ${CPPFLAGS} ${CFLAGS} -W -Werror pcre.c ${LIBS} ${LDFLAGS} -Wl,-z,defs

json1.so : json1.c
	${CC} -shared -o $@ ${CPPFLAGS} ${CFLAGS} -W -Werror pcre.c ${LIBS} ${LDFLAGS} -Wl,-z,defs

install : pcre.so
	${INSTALL} -pD -m755 pcre.so ${DESTDIR}${prefix}/lib/sqlite3/pcre.so

clean :
	-rm -f pcre.so

#cc -shared -o anki.so -I/opt/local/include -fPIC -W  anki.c -lpcre

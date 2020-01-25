/*
 * Written by Daniel M. German <dmg@turingmachine.org>
 *
 * based on the PRCE library for sqlite by Alexey Tourbin <at@altlinux.org>.
 *
 *  This software is licensed under the GPLv3+ license
 *
 */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <string.h>
#include <inttypes.h>
#include <sqlite3ext.h>
#include <errno.h>

#define SQLITE_DETERMINISTIC    0x800

//#define SEPARATOR '|'
#define SEPARATOR '\x1f'


SQLITE_EXTENSION_INIT1


int find_location(sqlite3_context *ctx, const char *st, int index, const char **beginSt, const char **endSt, int *len)
{

    const char *begin = st;

    // find the beginning
    // we only do this if index > 0
    while (begin && *begin && index > 0) {

        begin = strchr(begin, SEPARATOR);
        if (!begin ) {
            sqlite3_result_error(ctx, "illegal index to field (too large)", -1);
            return 0;
        }
        // skip the separator
        begin++;
        index --;
    }
    if (index > 0 ) {
        sqlite3_result_error(ctx, "illegal index to field (too large)", -1);
        return 0;
    }

    *beginSt = begin;

    const char *end = strchr(begin, SEPARATOR);
    if (!end) {
        // this is the last field...
        // in that  case point to the NULL at the end of the string
        end = begin + strlen(begin);
    }
    *endSt = end;
    *len = end - begin;


    return 1;


}

int convert_index (sqlite3_context *ctx, const char *indexSt) {

    int index;

    if (sscanf(indexSt,"%d", &index) != 1) {
	sqlite3_result_error(ctx, "no valid index provided", -1);
	return -1;
    }
    if (index <=0) {
	sqlite3_result_error(ctx, "Invalid index. It should be in the range [1..n]", -1);
	return -1;
    }
    // We externally use indexes based 1, but internally based zero
    index--;
    return index;

}


static
void anki_get_field(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
    const char *st = NULL;
    const char *indexSt = NULL;

    assert(argc == 2);

    st = (const char *) sqlite3_value_text(argv[0]);
    if (!st) {
	sqlite3_result_error(ctx, "no string", -1);
	return;
    }

    int index = convert_index(ctx, sqlite3_value_text(argv[1]));
    // index is zero based at this point
    if (index < 0) {
        return;
    }

    const char *begin = st;
    const char *end = st;
    int len = 0;

    if (!find_location(ctx, st, index, &begin, &end, &len)) {
        return;
    }

    // We must copy only before end
    // allocate end of character, make sure it is clean
    // since we do not copy a null
    char *result = calloc(len+1, 1);
    strncpy(result, begin, len); // copy only the string

    //    printf("Debugging input [%s] [%s][%d] -> [%s]len [%d] \n",
    //           st, indexSt, index, result, len
    //);
    sqlite3_result_text(ctx, result, len, &free);

}

static
void anki_set_field(sqlite3_context *ctx, int argc, sqlite3_value **argv)
{
    const char *st = NULL;
    const char *newSt = NULL;
    assert(argc == 3);

    st = (const char *) sqlite3_value_text(argv[0]);
    if (!st) {
	sqlite3_result_error(ctx, "no string", -1);
	return;
    }

    int index = convert_index(ctx, sqlite3_value_text(argv[1]));
    // index is zero based at this point
    if (index <= 0) {
        if (index == 0) {
            sqlite3_result_error(ctx, "Setting the first field is not supported", -1);
        }
        return;
    }

    newSt = (const char *) sqlite3_value_text(argv[2]);
    if (!newSt) {
        sqlite3_result_error(ctx, "no replacement value provided", -1);
	return;
    }

    const char *begin;
    const char *end;
    int len;

    if (!find_location(ctx, st, index, &begin, &end, &len)) {
        return;
    }

    // we have pointers to the beginning and the end of the part to replace
    // the end is one char after
    char *result = calloc(strlen(st) - len + strlen(newSt) + 1, 1);

    // this will copy the fields before the string...
    strncpy(result, st, begin-st);
    strcat(result, newSt);
    // now append the end...
    strcat(result, end);

    //    printf("Before the end [%d] string [%s] begin [%s] end [%s]-> [%s]\n", index, st, begin, end, result);


    sqlite3_result_text(ctx, result, strlen(result), &free);

}




int sqlite3_extension_init(sqlite3 *db, char **err, const sqlite3_api_routines *api)
{
	SQLITE_EXTENSION_INIT2(api)
            sqlite3_create_function(db, "anki_getfld", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC, NULL, anki_get_field, NULL, NULL);

        SQLITE_EXTENSION_INIT2(api)
            sqlite3_create_function(db, "anki_setfld", 3, SQLITE_UTF8 | SQLITE_DETERMINISTIC, NULL, anki_set_field, NULL, NULL);
	return 0;
}

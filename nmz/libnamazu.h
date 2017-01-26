/*
 * 
 * libnamazu.h - Namazu library api
 *
 * $Id: libnamazu.h,v 1.46.4.9 2009-02-17 01:28:39 opengl2772 Exp $
 * 
 */

#ifndef _LIBNAMAZU_H
#define _LIBNAMAZU_H

#include <stdio.h>   /* for FILE struct */


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/*
 * Set the message of error occurred in libnmz.
 */

#ifdef __GNUC__

#define nmz_set_dyingmsg(msg) \
    { \
        if (nmz_is_debugmode()) { \
            nmz_set_dyingmsg_sub("%s:%d (%s): %s", \
                __FILE__, __LINE__, __PRETTY_FUNCTION__, msg);\
        } else { \
            nmz_set_dyingmsg_sub("%s", msg);\
	} \
    }

#else /* !__GNUC__ */

#define nmz_set_dyingmsg(msg) \
    { \
        if (nmz_is_debugmode()) { \
            nmz_set_dyingmsg_sub("%s:%d: %s", __FILE__, __LINE__, msg);\
        } else { \
            nmz_set_dyingmsg_sub("%s", msg);\
	} \
    }

#endif /* __GNUC__ */


/*
 *
 * Critical values.
 *
 */

enum {
    /* Size of general buffers. This MUST be larger than QUERY_MAX */
    BUFSIZE = 1024,        

    QUERY_TOKEN_MAX =  32, /* Max number of tokens in the query. */
    QUERY_MAX       = 256, /* Max length of the query. */

    INDEX_MAX       = 64   /* Max number of databases */
};


/*
 *
 * Magic Numbers.
 *
 */

enum {
    ESC    = 0x1b,      /* Code of ESC */
    STDIN  = 0,		/* stdin's  fd */
    STDOUT = 1,		/* stdout's fd */
    STDERR = 2		/* stderr's fd */
};


/*
 *
 * Data Structures.
 *
 */

typedef unsigned char uchar;

/*
 * forward declarations of namazu types.
 */

typedef struct _NmzResult NmzResult;

/* 
 * Status code for error handling.
 */
enum nmz_stat {
    FAILURE = -1,
    SUCCESS,
    ERR_FATAL,
    ERR_TOO_LONG_QUERY,
    ERR_INVALID_QUERY,
    ERR_TOO_MANY_TOKENS,
    ERR_TOO_MUCH_MATCH,
    ERR_TOO_MUCH_HIT,
    ERR_REGEX_SEARCH_FAILED,
    ERR_PHRASE_SEARCH_FAILED,
    ERR_FIELD_SEARCH_FAILED,
    ERR_CANNOT_OPEN_INDEX,
    ERR_NO_PERMISSION,
    ERR_CANNOT_OPEN_RESULT_FORMAT_FILE,
    ERR_INDEX_IS_LOCKED,
    ERR_OLD_INDEX_FORMAT
};

/* 
 * Modes of searching.
 */
enum nmz_searchmethod {
    WORD_MODE,
    PREFIX_MODE,
    REGEX_MODE,
    PHRASE_MODE,
    FIELD_MODE,
    ERROR_MODE
};


/* 
 * Methods of sorting.
 */
enum nmz_sortmethod {
    SORT_BY_SCORE,
    SORT_BY_DATE,
    SORT_BY_FIELD
};

/* 
 * Orders of sorting.
 */
enum nmz_sortorder {
    ASCENDING,
    DESCENDING
};


/* 
 * Data structure for each hit document.
 */
struct nmz_data {
    int score;
    int docid;   /* document ID */
    int idxid;   /* index ID */
    int date;    /* document's date */
    int rank;    /* ranking data for stable sorting */
    char *field; /* field's contents for field-specified search */
};

/* 
 * Data structure for search result.
 */
struct _NmzResult {
    int num;           /* number of elements in its data */
    enum nmz_stat stat; /* status code mainly used for error handling */
    struct nmz_data *data;  /* dynamic array for storing nmz_data's. */
};

/* 
 * NMZ.* files' names.
 */
struct nmz_names {
#define MAXPATH BUFSIZE
    char i[MAXPATH];
    char ii[MAXPATH];
    char head[MAXPATH]; /* followed by a language code */
    char foot[MAXPATH]; /* followed by a language code */
    char body[MAXPATH]; /* followed by a language code */
    char lock[MAXPATH];
    char result[MAXPATH];
    char slog[MAXPATH];
    char w[MAXPATH];
    char wi[MAXPATH];
    char field[MAXPATH];  /* followed by a field name */
    char t[MAXPATH]; 
    char p[MAXPATH];
    char pi[MAXPATH];
    char tips[MAXPATH];
    char access[MAXPATH];
    char version[MAXPATH];
    char warnlog[MAXPATH];
};

/* 
 * NMZ.* files' file pointers 
 */
struct nmz_files {
    FILE *i;
    FILE *ii;
    FILE *p;
    FILE *pi;
    FILE *w;
    FILE *wi;
};

struct nmz_indices {
    int num;                    /* Number of indices */
    char *names[INDEX_MAX + 1]; /* Index names */
    struct nmz_hitnumlist 
    *hitnumlists[INDEX_MAX + 1];       /* hitnum list of each index */
    int totalhitnums[INDEX_MAX + 1];   /* total hit number of each index */
};

struct nmz_query {
    int  tokennum;                   /* Number of tokens in the query */
    char str[BUFSIZE];               /* Query string */
    char *tab[QUERY_TOKEN_MAX + 1];  /* Token pointers pointed to str */
};


/* 
 * List containig hit numbers of each index word by word.
 */
struct nmz_hitnumlist {
    char *word;
    int hitnum;
    enum nmz_stat stat;        /* status code mainly used for error handling */
    struct nmz_hitnumlist *phrase; /* for a result of a phrase search */
    struct nmz_hitnumlist *next;
};

/*
 * Field cache information
 */
struct field_cache {
    int idxid;
    int docid;
    char field[BUFSIZE];
    char data[BUFSIZE];
};

extern void nmz_free_aliases ( void );
extern void nmz_free_replaces ( void );
extern void nmz_set_sortmethod ( enum nmz_sortmethod method );
extern enum nmz_sortmethod nmz_get_sortmethod(void);
extern void nmz_set_sortorder ( enum nmz_sortorder order );
extern enum nmz_sortorder nmz_get_sortorder(void);
extern void nmz_set_maxhit ( int max );
extern int nmz_get_maxhit ( void );
extern void nmz_set_maxmatch ( int max );
extern int nmz_get_maxmatch ( void );
extern void nmz_set_debugmode ( int mode );
extern int  nmz_is_debugmode ( void );
extern void nmz_set_loggingmode ( int mode );
extern int  nmz_is_loggingmode ( void );
extern void nmz_set_regex_searchmode ( int mode );
extern int  nmz_is_regex_searchmode ( void );
extern void nmz_set_output_warn_to_file ( int mode );
extern int  nmz_is_output_warn_to_file ( void );
extern char *nmz_get_dyingmsg ( void );
extern char *nmz_set_dyingmsg_sub(const char *fmt, ...);
extern char *nmz_msg(const char *fmt, ...);
extern void nmz_free_internal(void);

/* since v2.0.13 */
extern char *nmz_get_version();

/* since v2.0.17 */
#define nmz_isascii(c) (!(c & 0x80))
#define nmz_isprint(c) (nmz_isascii(c) && isprint(c))
#define nmz_isdigit(c) (nmz_isascii(c) && isdigit(c))
#define nmz_isalnum(c) (nmz_isascii(c) && isalnum(c))
#define nmz_isalpha(c) (nmz_isascii(c) && isalpha(c))
#define nmz_iscntrl(c) (nmz_isascii(c) && iscntrl(c))
#define nmz_islower(c) (nmz_isascii(c) && islower(c))
#define nmz_ispunct(c) (nmz_isascii(c) && ispunct(c))
#define nmz_isspace(c) (nmz_isascii(c) && isspace(c))
#define nmz_isupper(c) (nmz_isascii(c) && isupper(c))
#define nmz_isxdigit(c) (nmz_isascii(c) && isxdigit(c))

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _LIBNAMAZU_H */

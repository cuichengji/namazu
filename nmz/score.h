#ifndef _SCORE_H
#define _SCORE_H

#include "libnamazu.h"  /* for nmz_data */

extern void nmz_recompute_score( NmzResult *hlist );
extern void nmz_set_scoring( const char *str );
extern int nmz_is_tfidfmode( void );
extern void nmz_set_tfidfmode( int mode );
extern void nmz_set_doclength( char *str );
extern void nmz_set_freshness( char *str );
extern void nmz_set_urilength( char *str );

#endif /* _SCORE_H */

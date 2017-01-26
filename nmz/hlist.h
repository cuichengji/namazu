#ifndef _HLIST_H
#define _HLIST_H

#include "libnamazu.h"  /* for NmzResult and enum nmz_* */

extern NmzResult nmz_andmerge ( NmzResult left, NmzResult right, int *ignore );
extern NmzResult nmz_notmerge ( NmzResult left, NmzResult right, int *ignore );
extern NmzResult nmz_ormerge ( NmzResult left, NmzResult right );
extern void nmz_malloc_hlist ( NmzResult * hlist, int n );
extern void nmz_realloc_hlist ( NmzResult * hlist, int n );
extern void nmz_free_hlist ( NmzResult hlist );
extern void nmz_copy_hlist ( NmzResult to, int n_to, NmzResult from, int n_from );
extern void nmz_set_idxid_hlist ( NmzResult hlist, int id );
extern NmzResult nmz_merge_hlist ( NmzResult *hlists );
extern NmzResult nmz_do_date_processing ( NmzResult hlist );
extern NmzResult nmz_get_hlist ( int index );
extern int nmz_sort_hlist ( NmzResult hlist, enum nmz_sortmethod mode );
extern int nmz_reverse_hlist ( NmzResult hlist );
extern void nmz_set_docnum ( int n );
extern void nmz_set_sortfield ( const char *field );
extern char *nmz_get_sortfield ( void );
extern int nmz_get_docnum( void );
#endif /* _HLIST_H */

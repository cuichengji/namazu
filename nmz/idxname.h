/*
 * 
 * idxname.h - header files for Idx handling.
 *
 * $Id: idxname.h,v 1.8 2000-01-13 01:13:22 satoru Exp $
 * 
 * 
 */

#ifndef _IDXNAME_H
#define _IDXNAME_H

extern enum nmz_stat nmz_add_index(const char *idxname);
extern int nmz_get_idxnum();
extern void nmz_free_idxnames ( void );
extern void nmz_uniq_idxnames ( void );
extern int nmz_expand_idxname_aliases ( void );
extern int nmz_complete_idxnames ( void );
extern char *nmz_get_idxname(int num);
extern int nmz_get_idx_totalhitnum(int id);
extern void nmz_set_idx_totalhitnum(int id, int hitnum);
extern struct nmz_hitnumlist *nmz_get_idx_hitnumlist(int id);
extern void nmz_set_idx_hitnumlist(int id, struct nmz_hitnumlist *hnlist);
extern struct nmz_hitnumlist *nmz_push_hitnum ( struct nmz_hitnumlist *hn, const char *str, int hitnum, enum nmz_stat stat );
extern void nmz_set_defaultidx(const char *idx);
extern char *nmz_get_defaultidx(void);

#endif /* _IDXNAME_H */

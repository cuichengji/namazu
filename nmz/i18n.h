#ifndef _I18N_H
#define _I18N_H

/*
 * settings for gettext (libintl)
 */
#if ENABLE_NLS
# include <libintl.h>
# define _(Text) gettext (Text)
#else
# undef bindtextdomain
# define bindtextdomain(Domain, Directory) /* empty */
# undef textdomain
# define textdomain(Domain) /* empty */
# define _(Text) Text
#endif
#define N_(Text) Text

#include "libnamazu.h" /* for nmz_stat */

extern char *nmz_set_lang ( const char *lang );
extern char *nmz_get_lang ( void );
extern char *nmz_get_lang_ctype ( void );
extern enum nmz_stat nmz_choose_msgfile_suffix ( const char *pfname, char *lang_suffix );

#endif /* _I18N_H */

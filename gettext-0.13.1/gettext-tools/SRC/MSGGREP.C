/* Extract some translations of a translation catalog.
   Copyright (C) 2001-2003 Free Software Foundation, Inc.
   Written by Bruno Haible <haible@clisp.cons.org>, 2001.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */


#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include <alloca.h>

#include <errno.h>
#include <getopt.h>
#include <limits.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#elif defined _MSC_VER || defined __MINGW32__
# include <io.h>
#endif

#include <fnmatch.h>

#include "closeout.h"
#include "dir-list.h"
#include "error.h"
#include "error-progname.h"
#include "progname.h"
#include "relocatable.h"
#include "basename.h"
#include "message.h"
#include "read-po.h"
#include "write-po.h"
#include "str-list.h"
#include "msgl-charset.h"
#include "xalloc.h"
#include "exit.h"
#include "full-write.h"
#include "findprog.h"
#include "pipe.h"
#include "wait-process.h"
#include "gettext.h"

#define _(str) gettext (str)


/* Force output of PO file even if empty.  */
static int force_po;

/* Selected source files.  */
static string_list_ty *location_files;

/* Selected domain names.  */
static string_list_ty *domain_names;

/* Arguments to be passed to the grep subprocesses.  */
static string_list_ty *grep_args[3];

/* Pathname of the grep program.  */
static const char *grep_path;

/* Argument lists for the grep program.  */
static char **grep_argv[3];

/* Long options.  */
static const struct option long_options[] =
{
  { "add-location", no_argument, &line_comment, 1 },
  { "comment", no_argument, NULL, 'C' },
  { "directory", required_argument, NULL, 'D' },
  { "domain", required_argument, NULL, 'M' },
  { "escape", no_argument, NULL, CHAR_MAX + 1 },
  { "extended-regexp", no_argument, NULL, 'E' },
  { "file", required_argument, NULL, 'f' },
  { "fixed-strings", no_argument, NULL, 'F' },
  { "force-po", no_argument, &force_po, 1 },
  { "help", no_argument, NULL, 'h' },
  { "ignore-case", no_argument, NULL, 'i' },
  { "indent", no_argument, NULL, CHAR_MAX + 2 },
  { "location", required_argument, NULL, 'N' },
  { "msgid", no_argument, NULL, 'K' },
  { "msgstr", no_argument, NULL, 'T' },
  { "no-escape", no_argument, NULL, CHAR_MAX + 3 },
  { "no-location", no_argument, &line_comment, 0 },
  { "no-wrap", no_argument, NULL, CHAR_MAX + 6 },
  { "output-file", required_argument, NULL, 'o' },
  { "properties-input", no_argument, NULL, 'P' },
  { "properties-output", no_argument, NULL, 'p' },
  { "regexp", required_argument, NULL, 'e' },
  { "sort-by-file", no_argument, NULL, CHAR_MAX + 4 },
  { "sort-output", no_argument, NULL, CHAR_MAX + 5 },
  { "strict", no_argument, NULL, 'S' },
  { "stringtable-input", no_argument, NULL, CHAR_MAX + 7 },
  { "stringtable-output", no_argument, NULL, CHAR_MAX + 8 },
  { "version", no_argument, NULL, 'V' },
  { "width", required_argument, NULL, 'w' },
  { NULL, 0, NULL, 0 }
};


/* Forward declaration of local functions.  */
static void no_pass (int opt)
#if defined __GNUC__ && ((__GNUC__ == 2 && __GNUC_MINOR__ >= 5) || __GNUC__ > 2)
	__attribute__ ((noreturn))
#endif
;
static void usage (int status)
#if defined __GNUC__ && ((__GNUC__ == 2 && __GNUC_MINOR__ >= 5) || __GNUC__ > 2)
	__attribute__ ((noreturn))
#endif
;
static msgdomain_list_ty *process_msgdomain_list (msgdomain_list_ty *mdlp);


int
main (int argc, char **argv)
{
  int opt;
  bool do_help;
  bool do_version;
  char *output_file;
  const char *input_file;
  int grep_pass;
  msgdomain_list_ty *result;
  bool sort_by_filepos = false;
  bool sort_by_msgid = false;

  /* Set program name for messages.  */
  set_program_name (argv[0]);
  error_print_progname = maybe_print_progname;

#ifdef HAVE_SETLOCALE
  /* Set locale via LC_ALL.  */
  setlocale (LC_ALL, "");
#endif

  /* Set the text message domain.  */
  bindtextdomain (PACKAGE, relocate (LOCALEDIR));
  textdomain (PACKAGE);

  /* Ensure that write errors on stdout are detected.  */
  atexit (close_stdout);

  /* Set default values for variables.  */
  do_help = false;
  do_version = false;
  output_file = NULL;
  input_file = NULL;
  grep_pass = -1;
  location_files = string_list_alloc ();
  domain_names = string_list_alloc ();
  grep_args[0] = string_list_alloc ();
  grep_args[1] = string_list_alloc ();
  grep_args[2] = string_list_alloc ();

  while ((opt = getopt_long (argc, argv, "CD:e:Ef:FhiKM:N:o:pPTVw:",
			     long_options, NULL))
	 != EOF)
    switch (opt)
      {
      case '\0':		/* Long option.  */
	break;

      case 'C':
	grep_pass = 2;
	break;

      case 'D':
	dir_list_append (optarg);
	break;

      case 'e':
	if (grep_pass < 0)
	  no_pass (opt);
	string_list_append (grep_args[grep_pass], "-e");
	string_list_append (grep_args[grep_pass], optarg);
	break;

      case 'E':
	if (grep_pass < 0)
	  no_pass (opt);
	string_list_append (grep_args[grep_pass], "-E");
	break;

      case 'f':
	if (grep_pass < 0)
	  no_pass (opt);
	string_list_append (grep_args[grep_pass], "-f");
	string_list_append (grep_args[grep_pass], optarg);
	break;

      case 'F':
	if (grep_pass < 0)
	  no_pass (opt);
	string_list_append (grep_args[grep_pass], "-F");
	break;

      case 'h':
	do_help = true;
	break;

      case 'i':
	if (grep_pass < 0)
	  no_pass (opt);
	string_list_append (grep_args[grep_pass], "-i");
	break;

      case 'K':
	grep_pass = 0;
	break;

      case 'M':
	string_list_append (domain_names, optarg);
	break;

      case 'N':
	string_list_append (location_files, optarg);
	break;

      case 'o':
	output_file = optarg;
	break;

      case 'p':
	message_print_syntax_properties ();
	break;

      case 'P':
	input_syntax = syntax_properties;
	break;

      case 'S':
	message_print_style_uniforum ();
	break;

      case 'T':
	grep_pass = 1;
	break;

      case 'V':
	do_version = true;
	break;

      case 'w':
	{
	  int value;
	  char *endp;
	  value = strtol (optarg, &endp, 10);
	  if (endp != optarg)
	    message_page_width_set (value);
	}
	break;

      case CHAR_MAX + 1:
	message_print_style_escape (true);
	break;

      case CHAR_MAX + 2:
	message_print_style_indent ();
	break;

      case CHAR_MAX + 3:
	message_print_style_escape (false);
	break;

      case CHAR_MAX + 4:
	sort_by_filepos = true;
	break;

      case CHAR_MAX + 5:
	sort_by_msgid = true;
	break;

      case CHAR_MAX + 6: /* --no-wrap */
	message_page_width_ignore ();
	break;

      case CHAR_MAX + 7: /* --stringtable-input */
	input_syntax = syntax_stringtable;
	break;

      case CHAR_MAX + 8: /* --stringtable-output */
	message_print_syntax_stringtable ();
	break;

      default:
	usage (EXIT_FAILURE);
	break;
      }

  /* Version information is requested.  */
  if (do_version)
    {
      printf ("%s (GNU %s) %s\n", basename (program_name), PACKAGE, VERSION);
      /* xgettext: no-wrap */
      printf (_("Copyright (C) %s Free Software Foundation, Inc.\n\
This is free software; see the source for copying conditions.  There is NO\n\
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n\
"),
	      "2001-2003");
      printf (_("Written by %s.\n"), "Bruno Haible");
      exit (EXIT_SUCCESS);
    }

  /* Help is requested.  */
  if (do_help)
    usage (EXIT_SUCCESS);

  /* Test whether we have an .po file name as argument.  */
  if (optind == argc)
    input_file = "-";
  else if (optind + 1 == argc)
    input_file = argv[optind];
  else
    {
      error (EXIT_SUCCESS, 0, _("at most one input file allowed"));
      usage (EXIT_FAILURE);
    }

  /* Verify selected options.  */
  if (!line_comment && sort_by_filepos)
    error (EXIT_FAILURE, 0, _("%s and %s are mutually exclusive"),
	   "--no-location", "--sort-by-file");

  if (sort_by_msgid && sort_by_filepos)
    error (EXIT_FAILURE, 0, _("%s and %s are mutually exclusive"),
	   "--sort-output", "--sort-by-file");

  /* Read input file.  */
  result = read_po_file (input_file);

  if (grep_args[0]->nitems > 0
      || grep_args[1]->nitems > 0
      || grep_args[2]->nitems > 0)
    {
      /* Warn if the current locale is not suitable for this PO file.  */
      compare_po_locale_charsets (result);

      /* Attempt to locate the 'grep' program.
	 This is an optimization, to avoid that spawn/exec searches the PATH
	 on every call.  */
      grep_path = find_in_path ("grep");

      /* On Solaris, we need to use /usr/xpg4/bin/grep instead of
	 /usr/bin/grep, because /usr/bin/grep doesn't understand the options
	 -q and -e.  */
#if (defined (sun) || defined (__sun)) && defined (__SVR4)
      if ((strcmp (grep_path, "/usr/bin/grep") == 0
	   || strcmp (grep_path, "/bin/grep") == 0)
	  && access ("/usr/xpg4/bin/grep", X_OK) == 0)
	grep_path = "/usr/xpg4/bin/grep";
#endif
    }

  /* Build argument lists for the 'grep' program.  */
  for (grep_pass = 0; grep_pass < 3; grep_pass++)
    if (grep_args[grep_pass]->nitems > 0)
      {
	string_list_ty *args = grep_args[grep_pass];
	size_t option_q;
	size_t i, j;

	/* We use "grep -q" because it is slightly more efficient than
	   "grep".  We pipe grep's output to /dev/null anyway.  But
	   SunOS4's grep program doesn't understand the -q option.  */
#if (defined (sun) || defined (__sun)) && !defined (__SVR4)
	option_q = 0;
#else
	option_q = 1;
#endif

	grep_argv[grep_pass] =
	  (char **) xmalloc ((1 + option_q + args->nitems + 1)
			     * sizeof (char *));
	grep_argv[grep_pass][0] = (char *) grep_path;
	j = 1;
	if (option_q)
	  grep_argv[grep_pass][j++] = "-q";
	for (i = 0; i < args->nitems; i++)
	  grep_argv[grep_pass][j++] = (char *) args->item[i];
	grep_argv[grep_pass][j] = NULL;
      }

  /* Select the messages.  */
  result = process_msgdomain_list (result);

  /* Sort the results.  */
  if (sort_by_filepos)
    msgdomain_list_sort_by_filepos (result);
  else if (sort_by_msgid)
    msgdomain_list_sort_by_msgid (result);

  /* Write the merged message list out.  */
  msgdomain_list_print (result, output_file, force_po, false);

  exit (EXIT_SUCCESS);
}


static void
no_pass (int opt)
{
  error (EXIT_SUCCESS, 0,
	 _("option '%c' cannot be used before 'K' or 'T' or 'C' has been specified"),
	 opt);
  usage (EXIT_FAILURE);
}


/* Display usage information and exit.  */
static void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    fprintf (stderr, _("Try `%s --help' for more information.\n"),
	     program_name);
  else
    {
      printf (_("\
Usage: %s [OPTION] [INPUTFILE]\n\
"), program_name);
      printf ("\n");
      /* xgettext: no-wrap */
      printf (_("\
Extracts all messages of a translation catalog that match a given pattern\n\
or belong to some given source files.\n\
"));
      printf ("\n");
      printf (_("\
Mandatory arguments to long options are mandatory for short options too.\n"));
      printf ("\n");
      printf (_("\
Input file location:\n"));
      printf (_("\
  INPUTFILE                   input PO file\n"));
      printf (_("\
  -D, --directory=DIRECTORY   add DIRECTORY to list for input files search\n"));
      printf (_("\
If no input file is given or if it is -, standard input is read.\n"));
      printf ("\n");
      printf (_("\
Output file location:\n"));
      printf (_("\
  -o, --output-file=FILE      write output to specified file\n"));
      printf (_("\
The results are written to standard output if no output file is specified\n\
or if it is -.\n"));
      printf ("\n");
      /* xgettext: no-wrap */
      printf (_("\
Message selection:\n\
  [-N SOURCEFILE]... [-M DOMAINNAME]...\n\
  [-K MSGID-PATTERN] [-T MSGSTR-PATTERN] [-C COMMENT-PATTERN]\n\
A message is selected if it comes from one of the specified source files,\n\
or if it comes from one of the specified domains,\n\
or if -K is given and its key (msgid or msgid_plural) matches MSGID-PATTERN,\n\
or if -T is given and its translation (msgstr) matches MSGSTR-PATTERN,\n\
or if -C is given and the translator's comment matches COMMENT-PATTERN.\n\
\n\
When more than one selection criterion is specified, the set of selected\n\
messages is the union of the selected messages of each criterion.\n\
\n\
MSGID-PATTERN or MSGSTR-PATTERN syntax:\n\
  [-E | -F] [-e PATTERN | -f FILE]...\n\
PATTERNs are basic regular expressions by default, or extended regular\n\
expressions if -E is given, or fixed strings if -F is given.\n\
\n\
  -N, --location=SOURCEFILE   select messages extracted from SOURCEFILE\n\
  -M, --domain=DOMAINNAME     select messages belonging to domain DOMAINNAME\n\
  -K, --msgid                 start of patterns for the msgid\n\
  -T, --msgstr                start of patterns for the msgstr\n\
  -C, --comment               start of patterns for the translator's comment\n\
  -E, --extended-regexp       PATTERN is an extended regular expression\n\
  -F, --fixed-strings         PATTERN is a set of newline-separated strings\n\
  -e, --regexp=PATTERN        use PATTERN as a regular expression\n\
  -f, --file=FILE             obtain PATTERN from FILE\n\
  -i, --ignore-case           ignore case distinctions\n\
"));
      printf ("\n");
      printf (_("\
Input file syntax:\n"));
      printf (_("\
  -P, --properties-input      input file is in Java .properties syntax\n"));
      printf (_("\
      --stringtable-input     input file is in NeXTstep/GNUstep .strings syntax\n"));
      printf ("\n");
      printf (_("\
Output details:\n"));
      printf (_("\
      --no-escape             do not use C escapes in output (default)\n"));
      printf (_("\
      --escape                use C escapes in output, no extended chars\n"));
      printf (_("\
      --force-po              write PO file even if empty\n"));
      printf (_("\
      --indent                indented output style\n"));
      printf (_("\
      --no-location           suppress '#: filename:line' lines\n"));
      printf (_("\
      --add-location          preserve '#: filename:line' lines (default)\n"));
      printf (_("\
      --strict                strict Uniforum output style\n"));
      printf (_("\
  -p, --properties-output     write out a Java .properties file\n"));
      printf (_("\
      --stringtable-output    write out a NeXTstep/GNUstep .strings file\n"));
      printf (_("\
  -w, --width=NUMBER          set output page width\n"));
      printf (_("\
      --no-wrap               do not break long message lines, longer than\n\
                              the output page width, into several lines\n"));
      printf (_("\
      --sort-output           generate sorted output\n"));
      printf (_("\
      --sort-by-file          sort output by file location\n"));
      printf ("\n");
      printf (_("\
Informative output:\n"));
      printf (_("\
  -h, --help                  display this help and exit\n"));
      printf (_("\
  -V, --version               output version information and exit\n"));
      printf ("\n");
      fputs (_("Report bugs to <bug-gnu-gettext@gnu.org>.\n"),
	     stdout);
    }

  exit (status);
}


/* Return 1 if FILENAME is contained in a list of filename patterns,
   0 otherwise.  */
static bool
filename_list_match (const string_list_ty *slp, const char *filename)
{
  size_t j;

  for (j = 0; j < slp->nitems; ++j)
    if (fnmatch (slp->item[j], filename, FNM_PATHNAME) == 0)
      return true;
  return false;
}


#ifdef EINTR

/* EINTR handling for close().
   These functions can return -1/EINTR even though we don't have any
   signal handlers set up, namely when we get interrupted via SIGSTOP.  */

static inline int
nonintr_close (int fd)
{
  int retval;

  do
    retval = close (fd);
  while (retval < 0 && errno == EINTR);

  return retval;
}
#define close nonintr_close

#endif


/* Process a string STR of size LEN bytes through grep, and return true
   if it matches.  */
static bool
is_string_selected (int grep_pass, const char *str, size_t len)
{
  if (grep_args[grep_pass]->nitems > 0)
    {
      pid_t child;
      int fd[1];
      int exitstatus;

      /* Open a pipe to a grep subprocess.  */
      child = create_pipe_out ("grep", grep_path, grep_argv[grep_pass],
			       DEV_NULL, false, true, true, fd);

      if (full_write (fd[0], str, len) < len)
	error (EXIT_FAILURE, errno,
	       _("write to grep subprocess failed"));

      close (fd[0]);

      /* Remove zombie process from process list, and retrieve exit status.  */
      exitstatus = wait_subprocess (child, "grep", false, true, true);
      return (exitstatus == 0);
    }
  else
    return 0;
}


/* Return true if a message matches.  */
static bool
is_message_selected (const message_ty *mp)
{
  size_t i;
  const char *msgstr;
  size_t msgstr_len;
  const char *p;

  /* Always keep the header entry.  */
  if (mp->msgid[0] == '\0')
    return true;

  /* Test whether one of mp->filepos[] is selected.  */
  for (i = 0; i < mp->filepos_count; i++)
    if (filename_list_match (location_files, mp->filepos[i].file_name))
      return true;

  /* Test msgid and msgid_plural using the --msgid arguments.  */
  if (is_string_selected (0, mp->msgid, strlen (mp->msgid)))
    return true;
  if (mp->msgid_plural != NULL
      && is_string_selected (0, mp->msgid_plural, strlen (mp->msgid_plural)))
    return true;

  /* Test msgstr using the --msgstr arguments.  */
  msgstr = mp->msgstr;
  msgstr_len = mp->msgstr_len;
  /* Process each NUL delimited substring separately.  */
  for (p = msgstr; p < msgstr + msgstr_len; )
    {
      size_t length = strlen (p);

      if (is_string_selected (1, p, length))
	return true;

      p += length + 1;
    }

  /* Test translator comments using the --comment arguments.  */
  if (grep_args[2]->nitems > 0
      && mp->comment != NULL && mp->comment->nitems > 0)
    {
      size_t length;
      char *total_comment;
      char *q;
      size_t j;

      length = 0;
      for (j = 0; j < mp->comment->nitems; j++)
	length += strlen (mp->comment->item[j]) + 1;
      total_comment = (char *) alloca (length);

      q = total_comment;
      for (j = 0; j < mp->comment->nitems; j++)
	{
	  size_t l = strlen (mp->comment->item[j]);

	  memcpy (q, mp->comment->item[j], l);
	  q += l;
	  *q++ = '\n';
	}
      if (q != total_comment + length)
	abort ();

      if (is_string_selected (2, total_comment, length))
	return true;
    }

  return false;
}


static void
process_message_list (const char *domain, message_list_ty *mlp)
{
  if (string_list_member (domain_names, domain))
    /* Keep all the messages in the list.  */
    ;
  else
    /* Keep only the selected messages.  */
    message_list_remove_if_not (mlp, is_message_selected);
}


static msgdomain_list_ty *
process_msgdomain_list (msgdomain_list_ty *mdlp)
{
  size_t k;

  for (k = 0; k < mdlp->nitems; k++)
    process_message_list (mdlp->item[k]->domain, mdlp->item[k]->messages);

  return mdlp;
}

/* Waiting for a subprocess to finish.
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

/* Specification.  */
#include "wait-process.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <sys/types.h>

#if defined _MSC_VER || defined __MINGW32__

/* Native Woe32 API.  */
#include <process.h>
#define waitpid(pid,statusp,options) _cwait (statusp, pid, WAIT_CHILD)
#define WAIT_T int
#define WTERMSIG(x) ((x) & 0xff) /* or: SIGABRT ?? */
#define WCOREDUMP(x) 0
#define WEXITSTATUS(x) (((x) >> 8) & 0xff) /* or: (x) ?? */
#define WIFSIGNALED(x) (WTERMSIG (x) != 0) /* or: ((x) == 3) ?? */
#define WIFEXITED(x) (WTERMSIG (x) == 0) /* or: ((x) != 3) ?? */
#define WIFSTOPPED(x) 0

#else

/* Unix API.  */
#include <sys/wait.h>
/* On Linux, WEXITSTATUS are bits 15..8 and WTERMSIG are bits 7..0, while
   BeOS uses the contrary.  Therefore we use the abstract macros.  */
#if HAVE_UNION_WAIT
# define WAIT_T union wait
# ifndef WTERMSIG
#  define WTERMSIG(x) ((x).w_termsig)
# endif
# ifndef WCOREDUMP
#  define WCOREDUMP(x) ((x).w_coredump)
# endif
# ifndef WEXITSTATUS
#  define WEXITSTATUS(x) ((x).w_retcode)
# endif
#else
# define WAIT_T int
# ifndef WTERMSIG
#  define WTERMSIG(x) ((x) & 0x7f)
# endif
# ifndef WCOREDUMP
#  define WCOREDUMP(x) ((x) & 0x80)
# endif
# ifndef WEXITSTATUS
#  define WEXITSTATUS(x) (((x) >> 8) & 0xff)
# endif
#endif
/* For valid x, exactly one of WIFSIGNALED(x), WIFEXITED(x), WIFSTOPPED(x)
   is true.  */
#ifndef WIFSIGNALED
# define WIFSIGNALED(x) (WTERMSIG (x) != 0 && WTERMSIG(x) != 0x7f)
#endif
#ifndef WIFEXITED
# define WIFEXITED(x) (WTERMSIG (x) == 0)
#endif
#ifndef WIFSTOPPED
# define WIFSTOPPED(x) (WTERMSIG (x) == 0x7f)
#endif
/* Note that portable applications may access
   WTERMSIG(x) only if WIFSIGNALED(x) is true, and
   WEXITSTATUS(x) only if WIFEXITED(x) is true.  */

#endif

#include "error.h"
#include "exit.h"
#include "fatal-signal.h"
#include "xalloc.h"
#include "gettext.h"

#define _(str) gettext (str)

#define SIZEOF(a) (sizeof(a) / sizeof(a[0]))


#if defined _MSC_VER || defined __MINGW32__

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* The return value of spawnvp() is really a process handle as returned
   by CreateProcess().  Therefore we can kill it using TerminateProcess.  */
#define kill(pid,sig) TerminateProcess ((HANDLE) (pid), sig)

#endif


/* Type of an entry in the slaves array.
   The 'used' bit determines whether this entry is currently in use.
   (If pid_t was an atomic type like sig_atomic_t, we could just set the
   'child' field to 0 when unregistering a slave process, and wouldn't need
   the 'used' field.)
   The 'used' and 'child' fields are accessed from within the cleanup_slaves()
   action, therefore we mark them as 'volatile'.  */
typedef struct
{
  volatile sig_atomic_t used;
  volatile pid_t child;
}
slaves_entry_t;

/* The registered slave subprocesses.  */
static slaves_entry_t static_slaves[32];
static slaves_entry_t * volatile slaves = static_slaves;
static sig_atomic_t volatile slaves_count = 0;
static size_t slaves_allocated = SIZEOF (static_slaves);

/* The termination signal for slave subprocesses.
   2003-10-07:  Terminator becomes Governator.  */
#ifdef SIGHUP
# define TERMINATOR SIGHUP
#else
# define TERMINATOR SIGTERM
#endif

/* The cleanup action.  It gets called asynchronously.  */
static void
cleanup_slaves (void)
{
  for (;;)
    {
      /* Get the last registered slave.  */
      size_t n = slaves_count;
      if (n == 0)
	break;
      n--;
      slaves_count = n;
      /* Skip unused entries in the slaves array.  */
      if (slaves[n].used)
	{
	  pid_t slave = slaves[n].child;

	  /* Kill the slave.  */
	  kill (slave, TERMINATOR);
	}
    }
}

/* Register a subprocess as being a slave process.  This means that the
   subprocess will be terminated when its creator receives a catchable fatal
   signal or exits normally.  Registration ends when wait_subprocess()
   notices that the subprocess has exited.  */
void
register_slave_subprocess (pid_t child)
{
  static bool cleanup_slaves_registered = false;
  if (!cleanup_slaves_registered)
    {
      atexit (cleanup_slaves);
      at_fatal_signal (cleanup_slaves);
      cleanup_slaves_registered = true;
    }

  /* Try to store the new slave in an unused entry of the slaves array.  */
  {
    slaves_entry_t *s = slaves;
    slaves_entry_t *s_end = s + slaves_count;

    for (; s < s_end; s++)
      if (!s->used)
	{
	  /* The two uses of 'volatile' in the slaves_entry_t type above
	     (and ISO C 99 section 5.1.2.3.(5)) ensure that we mark the
	     entry as used only after the child pid has been written to the
	     memory location s->child.  */
	  s->child = child;
	  s->used = 1;
	  return;
	}
  }

  if (slaves_count == slaves_allocated)
    {
      /* Extend the slaves array.  Note that we cannot use xrealloc(),
	 because then the cleanup_slaves() function could access an already
	 deallocated array.  */
      slaves_entry_t *old_slaves = slaves;
      size_t new_slaves_allocated = 2 * slaves_allocated;
      slaves_entry_t *new_slaves =
	malloc (new_slaves_allocated * sizeof (slaves_entry_t));
      if (new_slaves == NULL)
	{
	  /* xalloc_die() will call exit() which will invoke cleanup_slaves().
	     Additionally we need to kill child, because it's not yet among
	     the slaves list.  */
	  kill (child, TERMINATOR);
	  xalloc_die ();
	}
      memcpy (new_slaves, old_slaves,
	      slaves_allocated * sizeof (slaves_entry_t));
      slaves = new_slaves;
      slaves_allocated = new_slaves_allocated;
      /* Now we can free the old slaves array.  */
      if (old_slaves != static_slaves)
	free (old_slaves);
    }
  /* The three uses of 'volatile' in the types above (and ISO C 99 section
     5.1.2.3.(5)) ensure that we increment the slaves_count only after the
     new slave and its 'used' bit have been written to the memory locations
     that make up slaves[slaves_count].  */
  slaves[slaves_count].child = child;
  slaves[slaves_count].used = 1;
  slaves_count++;
}

/* Unregister a child from the list of slave subprocesses.  */
static inline void
unregister_slave_subprocess (pid_t child)
{
  /* The easiest way to remove an entry from a list that can be used by
     an asynchronous signal handler is just to mark it as unused.  For this,
     we rely on sig_atomic_t.  */
  slaves_entry_t *s = slaves;
  slaves_entry_t *s_end = s + slaves_count;

  for (; s < s_end; s++)
    if (s->used && s->child == child)
      s->used = 0;
}


/* Wait for a subprocess to finish.  Return its exit code.
   If it didn't terminate correctly, exit if exit_on_error is true, otherwise
   return 127.  */
int
wait_subprocess (pid_t child, const char *progname,
		 bool null_stderr,
		 bool slave_process, bool exit_on_error)
{
#if HAVE_WAITID && defined WNOWAIT && 0
  /* Commented out because waitid() with WNOWAIT doesn't work: On Solaris 7
     and OSF/1 4.0, it returns -1 and sets errno = ECHILD, and on HP-UX 10.20
     it just hangs.  */
  /* Use of waitid() with WNOWAIT avoids a race condition: If slave_process is
     true, and this process sleeps a very long time between the return from
     waitpid() and the execution of unregister_slave_subprocess(), and
     meanwhile another process acquires the same PID as child, and then - still
     before unregister_slave_subprocess() - this process gets a fatal signal,
     it would kill the other totally unrelated process.  */
  siginfo_t info;
  for (;;)
    {
      if (waitid (P_PID, child, &info, slave_process ? WNOWAIT : 0) < 0)
	{
# ifdef EINTR
	  if (errno == EINTR)
	    continue;
# endif
	  if (exit_on_error || !null_stderr)
	    error (exit_on_error ? EXIT_FAILURE : 0, errno,
		   _("%s subprocess"), progname);
	  return 127;
	}

      /* info.si_code is set to one of CLD_EXITED, CLD_KILLED, CLD_DUMPED,
	 CLD_TRAPPED, CLD_STOPPED, CLD_CONTINUED.  Loop until the program
	 terminates.  */
      if (info.si_code == CLD_EXITED
	  || info.si_code == CLD_KILLED || info.si_code == CLD_DUMPED)
	break;
    }

  /* The child process has exited or was signalled.  */

  if (slave_process)
    {
      /* Unregister the child from the list of slave subprocesses, so that
	 later, when we exit, we don't kill a totally unrelated process which
	 may have acquired the same pid.  */
      unregister_slave_subprocess (child);

      /* Now remove the zombie from the process list.  */
      for (;;)
	{
	  if (waitid (P_PID, child, &info, 0) < 0)
	    {
# ifdef EINTR
	      if (errno == EINTR)
		continue;
# endif
	      if (exit_on_error || !null_stderr)
		error (exit_on_error ? EXIT_FAILURE : 0, errno,
		       _("%s subprocess"), progname);
	      return 127;
	    }
	  break;
	}
    }

  switch (info.si_code)
    {
    case CLD_KILLED:
    case CLD_DUMPED:
      if (exit_on_error || !null_stderr)
	error (exit_on_error ? EXIT_FAILURE : 0, 0,
	       _("%s subprocess got fatal signal %d"),
	       progname, info.si_status);
      return 127;
    case CLD_EXITED:
      if (info.si_status == 127)
	{
	  if (exit_on_error || !null_stderr)
	    error (exit_on_error ? EXIT_FAILURE : 0, 0,
		   _("%s subprocess failed"), progname);
	  return 127;
	}
      return info.si_status;
    default:
      abort ();
    }
#else
  /* waitpid() is just as portable as wait() nowadays.  */
  WAIT_T status;

  *(int *) &status = 0;
  for (;;)
    {
      int result = waitpid (child, &status, 0);

      if (result != child)
	{
# ifdef EINTR
	  if (errno == EINTR)
	    continue;
# endif
# if 0 /* defined ECHILD */
	  if (errno == ECHILD)
	    {
	      /* Child process nonexistent?! Assume it terminated
		 successfully.  */
	      *(int *) &status = 0;
	      break;
	    }
# endif
	  if (exit_on_error || !null_stderr)
	    error (exit_on_error ? EXIT_FAILURE : 0, errno,
		   _("%s subprocess"), progname);
	  return 127;
	}

      /* One of WIFSIGNALED (status), WIFEXITED (status), WIFSTOPPED (status)
	 must always be true.  Loop until the program terminates.  */
      if (!WIFSTOPPED (status))
	break;
    }

  /* The child process has exited or was signalled.  */

  if (slave_process)
    /* Unregister the child from the list of slave subprocesses, so that
       later, when we exit, we don't kill a totally unrelated process which
       may have acquired the same pid.  */
    unregister_slave_subprocess (child);

  if (WIFSIGNALED (status))
    {
      if (exit_on_error || !null_stderr)
	error (exit_on_error ? EXIT_FAILURE : 0, 0,
	       _("%s subprocess got fatal signal %d"),
	       progname, (int) WTERMSIG (status));
      return 127;
    }
  if (WEXITSTATUS (status) == 127)
    {
      if (exit_on_error || !null_stderr)
	error (exit_on_error ? EXIT_FAILURE : 0, 0,
	       _("%s subprocess failed"), progname);
      return 127;
    }
  return WEXITSTATUS (status);
#endif
}

/* Creation of autonomous subprocesses.
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

#ifndef _EXECUTE_H
#define _EXECUTE_H

#include <stdbool.h>

/* Execute a command, optionally redirecting any of the three standard file
   descriptors to /dev/null.  Return its exit code.
   If it didn't terminate correctly, exit if exit_on_error is true, otherwise
   return 127.
   If slave_process is true, the child process will be terminated when its
   creator receives a catchable fatal signal.
   It is recommended that no signal is blocked or ignored while execute()
   is called.  See pipe.h for the reason.  */
extern int execute (const char *progname,
		    const char *prog_path, char **prog_argv,
		    bool null_stdin, bool null_stdout, bool null_stderr,
		    bool slave_process, bool exit_on_error);

#endif /* _EXECUTE_H */

# File::MMagic Makefile.PL 
#
# $Id: Makefile.PL,v 1.19.8.3 2006-10-13 16:59:20 opengl2772 Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
	      'NAME' => 'File::MMagic',
	      'VERSION_FROM' => 'MMagic.pm',
	      ($] ge '5.005') ? 
	      ('AUTHOR' => 'NOKUBI Takatsugu <knok@daionet.gr.jp>',
	       'ABSTRACT' => 'Guess file type from contents',
	      ) : (),
);

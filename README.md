# Preamble

This is some code I wrote during 2005.

# gen-docheck

gen-docheck is a useful tool for the [gentoo italian translation team](http://www.gentoo.org/doc/it/index.xml).
gen-dockeck compares the version number of english document and italian translation.

In this way you can watch the status of one or more guides, keeping the
translations updated.

## Features:

  * mail notification support (straight to guide's translator or to a specified address)
  * filter guides using regular expressions

## Requirements:

gen-dockeck requires:

  * perl
  * perl module [LWP::Simple](http://search.cpan.org/dist/libwww-perl/lib/LWP/Simple.pm) (under debian is provided by [libwww-perl](http://packages.debian.org/cgi-bin/search_packages.pl?searchon=names&subword=1&version=all&release=all&keywords=libwww-perl&sourceid=mozilla-search))
  * perl module [Net::SMTP](http://search.cpan.org/~gbarr/libnet/Net/SMTP.pm)
  * perl module [Getopt::Long](http://search.cpan.org/~jv/Getopt-Long-2.35/lib/Getopt/Long.pm) (usually available by default with all perl installation)
  * perl module [Pod::Usage](http://search.cpan.org/~marekr/Pod-Parser-1.34/lib/Pod/Usage.pm) (usually available by default with all perl installation)

## Synopsis:

gen-docheck syntax: `gen-docheck [--help] [--man] [--config configuration
file]` for more informations read the man page: `gen-docheck --manan`

## Configuration file:

gen-docheck support also configuration files.

This is an example:

    #mail sender
    sender = gentoo_doccheck@gentoo.orgThis email address is being protected from spam bots, you need Javascript enabled to view it  
    #check only guides mathing these names (use "." to match all, "," to separate names)
    checkonly = diskless,macos
    #checkonly = .  
    #send mail notify to translator
    mailnotify = 0  
    #send all mail notify to this address
    force_mail_destination = flavio.castelli@gmail.com  
    # smtp server
    smtp = smtp.tiscali.it  
    # debug smtp commands
    smtpdebug = 0

## Usage:

You can automate gen-docheck adding it to cron.

Here's an example:

    0 10 * * 0 /home/micron/gen\-docheck/gen\-docheck.pl --config /home/micron/gen\-docheck/gen\-docheck.conff

In this way you'll run gen-docheck every sunday at 10:00 AM

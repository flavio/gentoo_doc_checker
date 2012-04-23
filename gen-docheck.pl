#!/usr/bin/perl

#########################################################################
#	gen-docheck - Gentoo translation checker 	
# 
#	This program is free software; you can redistribute it and/or
#	 modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#	
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
# 
# 
# 	begin:	Thu July 20 2005
# 	author:	Flavio <micron> Castelli
# 	email:	micron@madlab.it
#
#	revision 0.1 	3/9/05: added force_mail_destination option
#	revision 0.2	9/11/05: added help message and man page
# 	
#########################################################################

use strict;
use LWP::Simple;
use Net::SMTP;
use Getopt::Long;
use Pod::Usage;

sub retrievePreferences
{
	my %conf;

	unless (open (CONFIG,$_[0]))
	{
		print "gen-docheck configuration file not found\n";
		print "using default values\n";

		## default options
		$conf{"mailnotify"} = 0; #don't send any mail
		$conf{"smtpdebug" } = 0; #don't debug smtp commands
		@{$conf{"checkonly"}} = (".");#check all guides

		return %conf;
	}

	while (<CONFIG>)
	{
		chomp;                  # no newline
		s/#.*//;                # no comments
		s/^\s+//;               # no leading white
		s/\s+$//;               # no trailing white
		next unless length;     # anything left?
	
		my ($var, $value) = split(/\s*=\s*/, $_, 2);

		if ($var eq "checkonly")
		{
			my @values = split (/,/,$value);
			$conf{$var} = \@values;
		}
		else
		{
			$conf{$var} = $value;
		}
	}

	close (CONFIG);
	
	print "Configuration preferences successfully loaded\n";

	return %conf;
}

sub sendmail
# $_[0] = document name, $_[1] translator mail, $_[2]  original_version, $_[3] Translated_version, $_[4] snmp, $_[5] sender, $_[6] debug smtp
{
	print "Document $_[0], sending mail to $_[1]\n";
	my $subject = "$_[0] has been updated";
	
	my $mailer;
	my $success = 1;
	my @data = (	"To: $_[1]\n",
				"Subject: $subject\n",
				"\n",
				"Your guide $_[0] has been updated.\nCurrent version is: $_[2]\nTranslated version:  $_[3]\n\nCheers\n\tgentoo-docheck"
				);
#".\r\n"
	my $smtp = Net::SMTP->new($_[4],
                        Timeout => 30,
                        Debug   => $_[6],
                       )
	or $success = 0;

	#mailfrom
	if ($success)
	{
		 $smtp->mail ($_[5]) or $success = 0;
	}

	if ($success)
	{
		$smtp->to($_[1]) or $success = 0;
	}
	
	if ($success)
	{
		$smtp->data() or $success = 0;
	}
	
	for (my $iter=0; (($iter < @data) && ($success)); $iter++)
	{
		$smtp->datasend($data[$iter]) or $success = 0;
	}
	
	if ($success)
	{
		$smtp->quit() or $success = 0;
	}

	if ($success)
	{
		print "Mail successfully sent\n";
	}
	else
	{
		print "Error sending mail\n";
	}
}

#### MAIN PROGRAM ####
my %options;
my %cliArgs;
my $optionFile = "/etc/gen-docheck";

GetOptions (	\%cliArgs,
		"config=s"   => \$optionFile,
		"man",
		"help")  || pod2usage(-verbose => 1) ;

pod2usage(1)  if (exists $cliArgs{"help"});
pod2usage(-verbose => 2)  if (exists $cliArgs{"man"});

#if (!(exists $cliArgs{"config"}))
#{
#	$cliArgs{"config"} = $optionFile;
#}

%options = retrievePreferences ($optionFile);

#%options = retrievePreferences ($cliArgs{"config"});

my $URL ="http://www.gentoo.org/doc/it/overview.xml";

my $report = get($URL);
defined $report
	or die "Non riesco a prelevare l'HTML da $URL\n";

my @lines = split (/\n/,$report);

my %todo;

for (my $iter=0, my $flag1=1, my $flag2=0; (($iter < @lines) && $flag1); $iter++)
{
	if ($lines[$iter] =~ /<p class="chaphead"><a name="files">.*/)
	{
		$flag2=1;
	}

	if ($lines[$iter] =~ /<p class="chaphead"><a name="bugs">.*/)
	{
		$flag1=0;
		$flag2=0;
	}

	if (($flag2 ) && ($lines[$iter] =~ /.*href="\/doc\/it\/.*/))
	{
		my $doc;
		my $Translated_version;
		my $original_version;

		$_ = $lines[$iter];
		s#</?\w+(((\s|\n)+\w+((\s|\n)*=(\s|\n)*(?:".*?"|'.*?'|[^'">\s]+))?)+(\s|\n)*|(\s|\n)*)/?>##g;
		$doc = $_;
		$_ = $lines[$iter+1];
		s#</?\w+(((\s|\n)+\w+((\s|\n)*=(\s|\n)*(?:".*?"|'.*?'|[^'">\s]+))?)+(\s|\n)*|(\s|\n)*)/?>##g;
		$Translated_version = $_;
		$_ = $lines[$iter+2];
		s#</?\w+(((\s|\n)+\w+((\s|\n)*=(\s|\n)*(?:".*?"|'.*?'|[^'">\s]+))?)+(\s|\n)*|(\s|\n)*)/?>##g;
		$original_version = $_;
		
		foreach my $pattern (@{$options{"checkonly"}})
		{
			if (($doc =~ /.*$pattern.*/) && (!($Translated_version eq $original_version)))
			{
				$todo{$doc}{"Original version"}=$original_version;
				$todo{$doc}{"Translated version"}=$Translated_version;
				last;
			}
		}
		
		$iter+=2;
	}
}

foreach my $document (keys %todo)
{
	foreach my $pattern (@{$options{"checkonly"}})
	{
		if ($document =~ /.*$pattern.*/)
		{
			my $baseurl ="http://www.gentoo.org";
	
			print "Retrieving informations about: ", $baseurl.$document,"\n";	
	
			my $guide = get($baseurl . $document);
		
			defined $guide
				or die "Non riesco a prelevare l'HTML da $baseurl\n";
	
			my @guide_lines = split (/\n/,$guide);
		
			for (my $iter=0; $iter < @guide_lines; $iter++)
			{
				if (($guide_lines[$iter] =~ /.*href="mailto.*/) && ($guide_lines[$iter+1] =~ /.*Tradu.*/))
				{
					$_ = $guide_lines[$iter];
					s/.*href.*mailto://g;
					s/$\">.*//g;
					if (length $_ > 0)
					{
						$todo{$document}{"Translator mail"} = $_;
					}
					else
					{
						$todo{$document}{"Translator mail"} = "unknown";
					}
	
					$_ = $guide_lines[$iter];
					s#</?\w+(((\s|\n)+\w+((\s|\n)*=(\s|\n)*(?:".*?"|'.*?'|[^'">\s]+))?)+(\s|\n)*|(\s|\n)*)/?>##g;
					s/\s*//;
					if (length $_ > 0)
					{
						$todo{$document}{"Translator"} = $_;
					}
					else
					{
						$todo{$document}{"Translator"} = "unknown";
					}
						
					last;
				}
				elsif (($guide_lines[$iter] =~ /.*href="mailto.*/) && ($guide_lines[$iter] =~ /.*Tradu.*/))
				{
					$_ = $guide_lines[$iter];
					s/.*href.*mailto://g;
					s/$\">.*//g;
					if (length $_ > 0)
					{
						$todo{$document}{"Translator mail"} = $_;
					}
					else
					{
						$todo{$document}{"Translator mail"} = "unknown";
					}
						
					$_ = $guide_lines[$iter+1];
					s#</?\w+(((\s|\n)+\w+((\s|\n)*=(\s|\n)*(?:".*?"|'.*?'|[^'">\s]+))?)+(\s|\n)*|(\s|\n)*)/?>##g;
					s/\s*//;
					if (length $_ > 0)
					{
						$todo{$document}{"Translator"} = $_;
					}
					else
					{
						$todo{$document}{"Translator"} = "unknown";
					}
					
					last;
				}
			}
			
			last;
		}
	}
}	

printf  ("%i guides need to be updated\n", scalar (keys %todo));

foreach (keys %todo)
{
	print "Documento: $_\n";
	print "\tTraduttore: |", $todo{$_}{"Translator"},"|\n";
	print "\tMail del traduttore: |", $todo{$_}{"Translator mail"},"|\n";
	print "\tVersione originale: |", $todo{$_}{"Original version"},"|\n";
	print "\tVersione tradotta: |",$todo{$_}{"Translated version"},"|\n";
			
	if ($options{"mailnotify"})
	{
		if ($todo{$_}{"Translator mail"} eq "not checked")
		{
			print "Unable to send mail, I don't know translator's mail address\n";
			last;
		}

		if (exists ($options{"smtp"}))
		{	
			if (exists $options{"force_mail_destination"})
			{
				sendmail ($_, $options{"force_mail_destination"}, $todo{$_}{"Original version"}, $todo{$_}{"Translated version"},$options{"snmp"},$options{"sender"},$options{"smtpdebug"});
			}
			else
			{
				sendmail ($_, $todo{$_}{"Translator mail"}, $todo{$_}{"Original version"}, $todo{$_}{"Translated version"},$options{"snmp"},$options{"sender"},$options{"smtpdebug"});
			}
		}
		else
		{
			print "Unable to send mail because you haven't defined a smtp server in you configuration file\n";
			print "Use the directive \"smtp = smtp_server\" in the configuration file (/etc/gen-docheck)\n";
		}
	}
}

__END__

=head1 gen-docheck

gen-dockeck - A tool for staying updated with gentoo's docs translations

=head1 SYNOPSIS

gen-docheck [--config configuration file]

=head1 OPTIONS

=over 8

=item B<-c --config>

Load a custom configuration file instead of /etc/gen-docheck.conf

=item B<--help>

some help informations

=item B<--man>

simple man page

=back

=head1 DESCRIPTION

B<gen-dochek> discovers the gentoo italian documents that aren't updated.

It's able to notify my mail the document translator or another person.

If the default configuration file is missing and the user hasn't specified a custom one, gen-docheck will use default settings: it will check all documents and wont send any mail notify.

=head1 AUTHOR

Flavio Castelli: micron at madlab dot it

=cut

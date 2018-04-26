#!/usr/bin/perl
#
# mhmail.perl
# 
# Takes an mh-mail message directory as an argument, 
# creates an html page that links to each.
# 
# dpwe@media.mit.edu 1995jan10
# $Header: /homes/dpwe/public_html/AUDITORY/scripts/RCS/mhmail.perl,v 1.2 2001/05/04 04:40:24 dpwe Exp dpwe $

# extend path to find mh commands
#$ENV{'PATH'}="/mas/bin:".$ENV{'PATH'}.":/usr/new/mh:/usr/local/bin";
#$ENV{'PATH'}=$ENV{'PATH'}.":/usr/local/mh/bin:/usr/local/bin";
$ENV{'PATH'}=$ENV{'PATH'}.":/usr/bin/mh";

#do 'headfoot.sperl';    # definitions of header and footer fns
####################
# headfoot.sperl
#
# Definition of 'header' and 'footer' subroutines for use in 
# perl functions that generate html pages on the fly
#
# dpwe@media.mit.edu 1995jan10  Extracted from parsesos1.perl

sub header    # write the header, specify page title
{
    local($title)=@_;
    print "<HTML>\n<HEAD>\n<meta name=viewport content=\"width=device-width, initial-scale=1\">\n<TITLE>\n$title\n</TITLE>\n";
#    print "<ISINDEX>\n";
    print "</HEAD>\n";
    print "<BODY>\n<H1>$title</H1>\n";
    print "<A HREF=\"/postings/\">Back to postings index</A>\n";
    print "<HR>\n";
}

sub footer    # finish off the page
{
    print "<HR>\n<ADDRESS>\n<A HREF=\"http://www.ee.columbia.edu/~dpwe/\">\n";
    print "DAn Ellis &lt;dpwe\@ee.columbia.edu&gt; </A><BR>\n";
    print "Dept. of Elec. Eng., Columbia\n</ADDRESS>\n</BODY>\n</HTML>\n";
}
####################

$mhdir = $ARGV[0];
if($#ARGV > 0)  {    # $#ARGV is the largest usable index for ARGV
  $mhprefix = $ARGV[1];
} else {
  $mhprefix = $mhdir;
}

#print "mhdir is $mhdir\n";

# unfortunately, mh's 'scan' insists on creating a Mail directory and a 
# .mh_profile file in $HOME if they do not exist.  Thus, set $HOME to 
# somewhere harmless

#$fakehome = "/usr/tmp";	# place to create and then destroy Mail dir
#$ENV{'HOME'}=$fakehome;

# Alterntatively, put an .mh_profile in / which contains 
# "Path: /usr/tmp/Mail" and then create that directory

#system("which scan");

#exec "/mas/bin/scan", "+$mhdir";

#open(scan, "/mas/bin/scan +$mhdir |");

#print "./scan.tcl $mhdir |\n";
open(scan, "./scan.tcl $mhdir |");

# remove the unwanted things made by scan
#unlink "$fakehome/.mh_profile";
#unlink "$fakehome/Mail/context";
#rmdir  "$fakehome/Mail";

&header("Mailbox index - $mhprefix");
#print "<pre width=80><tt>\n";
print "<pre><tt>\n";

# *** rdrprefix not currently used
$rdrprefix="/dpwe-bin/mhmessage.cgi/";   # filter to format message, or
				         # leave blank for plain text  

$sufx=".html";
while(<scan>)  {
  chop;
  s/</&lt;/g;
  s/>/&gt;/g;
  m/^( *)([1-90]+)(.*)/;
  if( length($_) > 0 )  {
  #  print "$1<a href=\"$mhprefix/$2\">$2</a>$3<p>\n";
  #  print "<a href=\"$rdrprefix$mhprefix/$2\"><IMG SRC=\"/gifs/tiny.txt.gif\" ALT=\"(txt)\"></a>$1$2$3\n";  # omit terminal <p> to get <pre> lines closepacked
  # 2002-05-12: msgs are now converted to HTML when inc'd
    print "<a href=\"$2$sufx\"><IMG SRC=\"/gifs/tiny.txt.gif\" ALT=\"(txt)\"></a>$1$2$3\n";  # omit terminal <p> to get <pre> lines closepacked
  }
}

print "</tt></pre>\n";

&footer


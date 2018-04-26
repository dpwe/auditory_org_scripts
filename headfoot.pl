####################
# headfoot.pl
#
# Definition of 'header' and 'footer' subroutines for use in 
# perl functions that generate html pages on the fly
#
# dpwe@media.mit.edu 1995jan10  Extracted from parsesos1.perl

sub header    # write the header, specify page title
{
    local($title,$icon,$isindex,$omitcontenttype,$file)=@_;

    if( $file eq "") {
        $file = STDOUT;
    }

    if( ($omitcontenttype eq "") )  {
        print "Content-type: text/html\n\n";
    }
    print "<HTML>\n<HEAD>\n<TITLE>\n$title\n</TITLE>\n";
    if(! ($isindex eq "") )  {
      print "<ISINDEX>\n";
    }
    print "</HEAD>\n";
    print "<BODY>\n<H1>";
    if(! ($icon eq "") )  {
      print "<IMG SRC=\"$icon\" align=middle> ";
    }
    print "$title</H1>\n<HR>\n";
}

sub footer    # finish off the page
{
    print "<HR>\n<ADDRESS>\n<A HREF=\"http://www.ee.columbia.edu/~dpwe/\">\n";
    print "DAn Ellis &lt;dpwe\@ee.columbia.edu&gt; </A><BR>\n";
    print "Columbia University Electrical Engineering\n</ADDRESS>\n</BODY>\n</HTML>\n";
}

# ob. return code
1;
####################

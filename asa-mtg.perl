# asa-mtg.perl
# This is perl script for converting the asa marked up files into HTML
# usage: 
#    cd ~/public_html/AUDITORY/asamtgs
#    mkdir asaYYppp
#    cd asaYYppp
#    perl ../../asa-mtg.perl ~/docs/asaYYppp.prog 
#
# (assumes this file is in ~/public_html)
#
# First line of .prog file must specify common title of conference 
#  after the DPWEHEADER keyword, e.g
#
# DPWEHEADER ASA 128th Meeting - Austin, Texas - 1994 Nov 28 .. Dec 02
# 
#  If not, script prompts for it.
#
# Generates a directory full of "2pSP.html" and the like
# and one "index.html" which points at them all
# 
# Run through the index for unexpected entries to find bugs 
# in original program
#
# dpwe 1994feb28
#
# 1994mar14 - added title line as <TITLE> of leaf docs
# 1995oct12 - lots of bugs from running htmlpty-0.10 over my entire web tree.
#   - Added ENDOLINDEX to close ordered lists <OL> in session indexes
#   - gave $fh a value (???) to allow it to write <TITLE> stuff to 
#     individual papers

$days{'1'} = "Monday";
$days{'2'} = "Tuesday";
$days{'3'} = "Wednesday";
$days{'4'} = "Thursday";
$days{'5'} = "Friday";

$times{'a'} = "morning";
$times{'p'} = "afternoon";
$times{'e'} = "evening";

$sesstype{'AA'} = "Architectural Acoustics";
$sesstype{'AO'} = "Acoustical Oceanography";
$sesstype{'EA'} = "Engineering Acoustics";
$sesstype{'NS'} = "Noise";
$sesstype{'PA'} = "Physical Acoustics";
$sesstype{'PP'} = "Psychological & Physiological Acoustics";
$sesstype{'SA'} = "Structural Acoustics";
$sesstype{'ID'} = "Tutorial";
$sesstype{'MU'} = "Musical Acoustics";
#$sesstype{'SP'} = "Speech Communications";
$sesstype{'SC'} = "Speech Communications";
$sesstype{'SP'} = "Signal Processing";
$sesstype{'UW'} = "Underwater Acoustics";
$sesstype{'AB'} = "Animal Bioacoustics";
$sesstype{'BV'} = "Bioresponse to Vibration";
$sesstype{'ED'} = "Acoustics Education";

$lastday = "";
$lastdaypart = "";

$donepar = 0;
$cursess = "";
$sessixfh = SESSIXFH;
$paperfh = "PAPERFILEHANDLE";

$_=<>;
@F= split(' ');
if($F[0] ne "DPWEHEADER")  {
  print(STDERR "** Please put 'DPWEHEADER ASA 125th Meeting Ottawa 1993 May' at the   \n   1st line of the data file.\n");
  exit(0);
} else {
  shift @F;
  $commontitle = join(" ",@F);
  # $commontitle is prepended to all indexes
}

# Find just the last component of the current directory - should be "asa95stl"
chop($cwd = `pwd`);
$stem = $cwd;
$stem =~ s@.*/@@;

open(IX, ">index.html");
print(IX "<Title>Abstracts $commontitle</Title>\n");
print(IX "<H1>$commontitle</H1>\n");
print(IX "<p>\n The following is a list of sessions.  Each points to a document \n pointing to all the abstracts for that session.<p>\n");
print(IX "Click here for <a href=/dpwe-bin/search-arg/~dpwe/AUDITORY/asamtgs/$stem>keyword searching</a> over all the abstracts at this meeting.<p>\n");

while (<>) {
  @F = split(' ');
  $w = $_; 
  chop $w;
  if(/^XX/) {
    $t = $F[0]; 
    shift @F; 
    $l = join(" ",@F);
    if($t eq XXTT) {
      &NEWPAPER(@F);
      $oldmode = "none";
    }
    $oldmode = &SETMODE($t, $oldmode);
    if ($t ne XXSU && $t ne XXTM) {
      print $l,"\n"
    }
  } elsif ($w eq par || $w eq ""){ 
    print"<p>\n";
    $donepar = 1;
  } elsif ($w ne section){
    print
  }
}

&ENDOLINDEX($sessixfh); # finish index of final session

print(IX "</UL>\n");	# finish last nested loop
&ENDINDEX(IX);		# finish enclosing loop & close file

print(STDOUT "Now you must add something like\n<li><a href=\"$stem/\">$commontitle</a>\nto ~/public_html/AUDITORY/asamtgs/index.html\n");
exit(0);

sub SETMODE  {
  local($newmode, $oldmode) = @_;
  if($oldmode ne $newmode) {
    if($donepar == 0)  {
       print "<p>\n";
    }
    if($oldmode eq XXTT)  {
       print "</H2>\n"
    } elsif ($oldmode eq XXAU) {
       print "</b>\n"
    } elsif ($oldmode eq XXLO) {
       print "</i>\n"
    }
    if($newmode eq XXTT)  {
       print "<H2>"
    } elsif ($newmode eq XXAU) {
       print "<b>"
    } elsif ($newmode eq XXLO) {
       print "<i>"
    }
    $oldmode = $newmode;
    $donepar = 0;
  }
  $oldmode;
}  

sub NEWPAPER {
  local(@F) = @_;
  $paperref = $F[0];
  if( (chop $paperref) ne ".")  {
    warn "bad paperref: $paperref";
    select(STDERR);
  } else {
    # $paperref is eg "1aPPb12"
    ($sessn=$paperref) =~ s/[0-9]*$//;     # $sessn = "1aPPb"
    ($paper=$paperref) =~ s/^.*[A-z]//;    # $paper = "12"
    # warn "s $sessn p $paper";
    # close previous paper output
    if($cursess ne "")  {
      close($paperfh);
    }
    if($sessn ne $cursess)  {
      if($cursess ne "")  {
        # warn "closing $cursess";
        &ENDOLINDEX($sessixfh);
        #close($sessixfh);
      }
      # new session - make new subdirectory
      $cursess = $sessn;
      $titline = &ADDINDEX($cursess, $cursess . "/", IX);
      if(-e $cursess)  {
	warn "** $cursess directory already exists ($paperref)!  Bailing..";
	exit(-1);
      }
      mkdir("$cursess",0777);
      open($sessixfh, ">${cursess}/index.html");
      print($sessixfh "<Title>Session $cursess</Title>\n");
      print($sessixfh "<H3>$commontitle</H3>\n");
      print($sessixfh "<H2>Papers in $titline</H2>\n");
      print($sessixfh "<p>\n<ol>\n");	# list is numbered
    }
    # add new paper to current index
    shift @F;
    $filename = "${paperref}" . ".html";
    $paptitline = "$paperref " . join(" ",@F);
    print($sessixfh "  <li><a href=\"$filename\">\n");
    print($sessixfh "      $paptitline</a>\n");
    # redirect prints to that paper
    $filename2 = "${cursess}/" . ${filename};
    open($paperfh, ">$filename2");
    print($paperfh "<TITLE>$paptitline</TITLE>\n");
    print($paperfh "<H3>$commontitle</H3>\n");
    select($paperfh);
  }
}

sub ADDINDEX  {
  # add an entry to the index file
  local($sess, $fn, $ix) = @_;
  $tel = tell($ix);
  warn("new sess $sess at $tel");
  # $sess = "1aPPb" or "5pEA"
  ($day     = $sess) =~ s/^(.).*/\1/;          # "1"
  ($daypart = $sess) =~ s/^.(.).*/\1/;         # "a"
  ($type    = $sess) =~ s/^..(.*)/\1/;         # "PPb"
  ($truetype= $type) =~ s/^(..).*/\1/;         # "PP"
  # now day is 1,2,3.. and daypart is "a", "p" etc
  if($day ne $lastday || $daypart ne $lastdaypart) {   # new day part
    if($lastday eq "")  {  # first day
      print($ix "<UL>\n");
    } else {  # terminate previous list
      print($ix " </UL>\n");
    }
    # print day/part
    print($ix "<LI> $day$daypart - $days{$day} $times{$daypart}\n");
    print($ix " <UL>\n");
  }
  $titline = "$sess - $sesstype{$truetype}";
  print($ix " <LI> <A HREF=\"$fn\"> $titline </a>\n");
  $lastday = $day;
  $lastdaypart = $daypart;
  # last line is return code, used as title for the index for this sess
  $titline;
}

sub ENDINDEX  {
  # finish off the index file
  local($ix) = @_;
  print($ix "</UL>\n");
  &STAMPADDRESS($ix);
  close($ix);
}

sub ENDOLINDEX  {
  # finish off the index file
  local($ix) = @_;
  print($ix "</OL>\n");
  &STAMPADDRESS($ix);
  close($ix);
}

sub STAMPADDRESS {
  local($fh) = @_;
  print($fh "\n<hr>\n<address>\n");
  print($fh "<a href=\"http://sound.media.mit.edu/~dpwe/\">\n");
  print($fh "DAn Ellis\n&lt;dpwe@media.mit.edu&gt;\n");
  print($fh "</a></address>\n");
}

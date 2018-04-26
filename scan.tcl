#!/usr/bin/tclsh
#
# scan.tcl
#
# Emulate mh's scan in Tcl.
#
# 2001-02-03 dpwe@ee.columbia.edu - trying to get AUD postings on cec
# $Header: /var/www/AUDITORY/scripts/RCS/scan.tcl,v 1.4 2014/01/29 19:28:34 dpwe Exp $

# -----------------------------------------------------------------------
# ------ Functions to scan a directory of mh-mail files and generate an 
#        index file (i.e. do what 'scan' does in unix)

proc findField {field text} {
# Take a prefix such as "From:", and return the rest of any line 
# that it starts in text

# set up regular expression
	set re "\r${field}(\[^\r\]*)"
# must preprend \r to text in search so that \r-prepended match will
# match beginning of text
	if {[regexp $re "\r$text" dummy match] == 0} {
# field not found in text
		return ""
	} else {
		return [string trim $match]
	}
}

proc val str {
# return the `value' of a string - 
# but since that is just a string anyway, really just 
# stripping leading zeros and nonnumerics
# i.e. "  009 " becomes "9"
	set rslt [string trim $str]
	set scale 0
	set c1 [string index $rslt 0]
	if { $c1 == "+" } {
		set scale 1
	} elseif { $c1 == "-" } {
		set scale -1
	}
	if { $scale == 0 } {
		set scale 1
	} else {
		# scale *was* set, so strip 1st chr off string
		set rslt [string range $rslt 1 end]
 	}
	set rslt [string trimleft $rslt "0"]
	if { [string length $rslt] == 0 }  {
		# stripped it *all* away - add something back!
		return "0"
	} else {
		if { $scale == -1 } {
			set rslt "-$rslt"
		}
		return $rslt
	}
}

proc parseTime str {
# find a field of form "hh:mm[:ss][ {am|pm}]" and return canonical
# "h m s" list.  Also return the indices of the located string
# first try for date followed by am/pm
	set timetxt ""
	# first look for colon-containing numeric string followed by am/pm
	set re "\[0-9:\]+:\[0-9:\]+\[ \t\]*\[AaPp\]\[Mm\]"
	if { [regexp -indices $re $str ixs] }  {
		# found time with am/pm
		set timetxt [string range $str [lindex $ixs 0] [lindex $ixs 1]]
		if { [regsub "\[ \t\]*\[Pp\]\[Mm\]" $timetxt "" timetxt ] } {
			# was pm 
			set houroffs 12
		} else {
			# must have been am - remove it
			if { [regsub "\[ \t\]*\[Aa\]\[Mm\]" $timetxt "" timetxt] == 0 } {
				alertnote "parseTime: lost am in $timetxt"
				return 0
			}
		set houroffs 0
		}
		# should now have time string without am/pm
	} else {
		# that didn't work - try it without am/pm
		set re "\[0-9:\]+:\[0-9:\]+"
		if { [regexp -indices $re $str ixs] }  {
			# found time alone
			set timetxt [string range $str [lindex $ixs 0] [lindex $ixs 1]]
		}
	}
	if { [string length $timetxt] == 0 } {
		# no time found
		return 0
	}
	# else parse timetxt into hrs/mins/secs
	set time [split $timetxt ":"]
	# add on pm offset, if any 
	#  (have to take 'val' of hours to stop it being invalid octal if "08")
	set hours [val [lindex $time 0]]
	if { [info exists houroffs ] }  { 
		# i.e. we had an am/pm detected above
		if { $hours == 12 } {
			# 12 is dealt with specially 
			set hours 0
		} 
		set hours [expr "$houroffs + $hours"]
	}
	set mins [lindex $time 1]
	if { [llength $time] < 3 }  {
		# no seconds - set to zero
		set secs 0
	} else {
	 	set secs [lindex $time 2]
	}
	set time [list $hours [val $mins] [val $secs]]
	# return both time and indexes within string
	return [list $time $ixs]
}

set mail_tzTable "GMT 0 UT 0 CET 100 BST 100 EST -500 EDT -400 \
CST -600 CDT -500 MST -700 MDT -600 PST -800 PDT -700 JST 900 \
MET 100 MEST 200 MESZ 200 {WSU DST} 400"

proc tzNameToNum {n} {
	# convert a timezone name into corresponding offset from the table
	global mail_tzTable
	set ix [lsearch $mail_tzTable [string toupper $n]]
	if {$ix == -1} {
		alertnote "tzNameToNum: zone '$n' unknown"
		return 0
	} else {
		return [lindex $mail_tzTable [expr "$ix+1"]]
	}
}

proc tzNumToName {t} {
	# convert an offset in minutes into a name (first found) or
	# format the number nicely
	global mail_tzTable
	set ix [lsearch $mail_tzTable $t]
	if {$ix == -1} {
		if { $t < 0 } {
			set t [expr -$t]
			set n "-[rpadLen "000$t" 4]"
		} else {
			set n "+[rpadLen "000$t" 4]"
		}
	} else {
		set n [lindex $mail_tzTable [expr "$ix - 1"]]
	}
	return $n
}

proc parseDate {str {notime 0}} {
# Take a string that is, e.g., the Date: field from a piece of email
# return the date it represents in canonical numeric form: "1965 12 31"
# If time component is find, return six element "1965 12 31 11 59 0"
# seventh element is time zone as 100*signed hours + minutes rel GMT
# (thus Eastern Standard Time is 500)
# Will skip time parsing if notime is specified and nonzero

# before starting, pull out any time field - defined as numeric 
#  containing colons
	if {$notime==0} {
		set trtn [parseTime $str]
		if { [llength $trtn] > 1 } {
			# did actually get a return
			set time [lindex $trtn 0]
			# time is now a three-element numeric list
			set tlims [lindex $trtn 1]
			# tlims is character indexes of time component
			# strip out the time field from str
			set str1 [string range $str 0 [expr "[lindex $tlims 0]-1"]]
			set str2 [string range $str [expr "[lindex $tlims 1]+1"] end]
			set str ${str1}${str2}
		}
	}

# first find month name
	set months [concat jan feb mar apr may jun jul aug sep oct nov dec]
	if {[regexp -indices -nocase [join $months "|"] $str indxs] == 0} {
# no month name, so can only be "5/5/93" or "1993-5-5"
		if {[regexp "\[^0-9\]*(\[0-9\]*)\[^0-9\]*(\[0-9\]*)\[^0-9\]*(\[0-9\]*)" \
				$str dummy num1 num2 num3] }  {
			if {[string length $num1] == 0 || [string length $num2] == 0 || \
				 [string length $num3] == 0} {
# must find all three strings
				return ""
			}
			if {$num1 > 31}  {
				set year [val $num1]
				set monthIx [val $num2]
				set day [val $num3]
			} else {
				if {$num1 > 12} {
# must be British format, dd/mm/yy, although most unreliable
					set year [val $num3]
					set monthIx [val $num2]
					set day [val $num1]
				} else {
# assume american format: mm/dd/yy
					set year [val $num3]
					set monthIx [val $num1]
					set day [val $num2]
				}
			}
		} else {
# no month and couldn't get three numeric fields
			return ""
		}
	} else {
# found month name
		set monthName [string tolower [string range $str [lindex $indxs 0] \
													 [lindex $indxs 1] ]]
		set monthIx [expr "[lsearch $months $monthName] +1"]
# now find tokens before and after month name
		set part [string range $str 0 [expr "[lindex $indxs 0] -1"]]
		set isbfr [regexp "(\[0-9\]*)\[^0-9]*$" $part dummy before]
		set part [string range $str [expr "[lindex $indxs 1] +1"] end]
		set isa1  [regexp "\[^0-9\]*(\[0-9\]*)" $part dummy after1]
		set isa2  [regexp "\[^0-9\]*\[0-9\]*\[^0-9\]*(\[0-9\]*)" $part dummy after2]
		if {$isa1 == 0 || [string length $after1] == 0} {
# no valid numeric after month name - not legal format (assume current year??)
			return ""
		}
		if {$isbfr && [string length $before] > 0} {
# valid numeric prior to month: distinguish "1993mar03" and "03 mar 93"
			if {$before > 31}  {
				set year [val $before]
				set day [val $after1]
			} else {
				set year [val $after1]
				set day [val $before]
			}
		} else {
# no 'before', so assume format "May 1st, 1907"
			if {$isa2 == 0 || [string length $after2] == 0} {
# must have two numeric fields after month if none before, else fail
				return ""
			}
			set year [val $after2]
			set day  [val $after1]
			# as a hack, strip out the second post-month numeric field we used
			# to permit correct parsing of dates with year *after* timezone
			# e.g. from /bin/date
			regsub $after2 $str "" str
			set str [string trim $str]
		}
	}
# year, monthIx and day set up
	
	if { $year < 100}  { set year [expr "$year + 1900"]  }
	if { [info exists time] } {
		# Check for timezone indication at end of string
		# three formats: "[+|-]0000" or "EST" or "-0700 (PST)"
		# also accept "UT" (universal time) from msn ??
		# must be at end
		if { [regexp {[+-][0-9][0-9][0-9][0-9]$} $str m] == 1 } {
			set tz [val $m]
		} elseif { [regexp {[ \t][A-z][A-z][A-z]?[A-z]?$} $str m] == 1 } {
			# (matches 2 or 3 alpha characters preceded by whitespace)
			# strip the delimiter off the front
			set m [string range $m 1 end]
			set tz [tzNameToNum $m]
		} elseif { [regexp {[+-][0-9][0-9][0-9][0-9] \([A-z ]+\)} \
					$str m] } {
			# both - extract both
			set tznum  [string range $m 0 4]
			set tzname [string range $m 7 [expr [string len $m]-2]]
		#	alertnote "tznum:'$tznum'; tzname:'$tzname'"
			# use the num field
			set tz [val $tznum]
		} elseif { [regexp {([A-Z][A-Z][A-Z])([+-][0-9]+)([A-Z]*)} \
					$str m tzname tzoffs tzofnam] } {
			# was something like "MET+1MEST" which I have seen - 
			# treat as MET
			set tz [tzNameToNum $tzname]
		} elseif { [regexp {\(([A-Z ]+)\)$} \
					$str m tzname] } {
			# accept (MET DST) as "MET DST"
			set tz [tzNameToNum $tzname]
		} else {
			# No timezone spec found
			set tz 0
			alertnote "couldn't find a tzname in '$str'"
		}
		return [concat $year $monthIx $day $time $tz]
	} else {
		# no time found
		return [concat $year $monthIx $day]
	}
}

proc shortDate date {
# convert canonical numeric date "1993 12 31" into short "dec31" format
	set months [concat jan feb mar apr may jun jul aug sep oct nov dec]
	set rslt [lindex $months [expr "[lindex $date 1] - 1"]]
	set day  [lindex $date 2]
	if {$day < 10} {
		set rslt "${rslt}0${day}"
	} else {
		set rslt "${rslt}${day}"
	}
	return $rslt
}

proc danDate date {
# convert canonical date "1993 12 31" to 'dan' format "1993dec31"
	return "[lindex $date 0][shortDate $date]"
}

proc timeFmt time {
# convert two or three element list into "20:29" or "20:29:13"
	set l [llength $time]
	if { $l != 2 && $l != 3 }  {
		alertnote "timeFmt: $time is not two or three element list"
		return
	}
	set rslt ""
	for { set i 0 } { $i < $l } { incr i } {
		set x [lindex $time $i]
		if { $x < 10 }  {
			set rslt "${rslt}0$x"
		} else {
			set rslt "${rslt}$x"
		}
		if { $i < [expr "$l - 1"]  }  {
			set rslt "$rslt:"
		}
	}
	return $rslt
}

proc CanonicalDays date {
# calculate canonical days since jan1 1970
	set monthDays "31 28 31 30 31 30 31 31 30 31 30 31"
	set monthDaysCum "0"
	set x 0
	for {set i 0} {$i<12} {incr i} {
		incr x [lindex $monthDays $i]
	    set monthDaysCum "$monthDaysCum $x"
	}
	set year  [lindex $date 0]
	set month [lindex $date 1]
	set day   [lindex $date 2]
	set ndays  [expr "( ( 1461 * ( $year - 1970 ) + 1) / 4 )"]
# add 1 before dividing by 4 because 1972 is the first leap year - 
# want to make sure the .25 * year adds one for 1973
	set isLeapYear [expr "($year % 4) == 0"]
	set ndays [expr "$ndays + [lindex $monthDaysCum [expr "$month - 1"]] \
						+ ($isLeapYear && ($month > 2))"]
	set ndays [expr "$ndays + $day - 1"]
	return $ndays
}

proc DayOfWeek date {
# return 0..6 corresponding to Sun..Sat for the given numeric date
	set ndays [CanonicalDays $date]
	return [expr "($ndays + 4) % 7"]
# jan 1st 1970 was a thursday (of course) - so add 4
# works for christmas 1992 & today (1994 2 9)
}

proc Capitalize str {
# make first chr of str a capital letter
	set first [string index $str 0]
	set rest  [string range $str 1 end ]
	return "[string toupper $first]$rest"
}

proc medTime time {
# take canonical time format "18 52 25 500" and convert to "18:52:25 +0500"
	set len [llength $time]
	set hrs [lindex $time 0]
	set min [lindex $time 1]
	set sec 0
	set tz 0
	if { $len > 2 }  {
	  # more than just hrs and min
	  set sec [lindex $time 2]
	  if { $len > 3 }  {
	    set tz [lindex $time 3]
	  }
	}
	set rslt "[rpadLen "0$hrs" 2]:[rpadLen "0$min" 2]:[rpadLen "0$sec" 2]"
	return "$rslt [tzNumToName $tz]"
}

proc medDate date {
# convert canonical numeric date "1993 12 31" into medium format e.g.
# "Mon, 31 Jan 94 18:52:35 EST."
	set weekdays [concat sun mon tue wed thu fri sat]
	set months [concat jan feb mar apr may jun jul aug sep oct nov dec]
	set rslt [Capitalize [lindex $weekdays [DayOfWeek $date]]]
	set year  [lindex $date 0]
	set month [lindex $date 1]
	set day   [lindex $date 2]
	set rslt "${rslt}, $day [Capitalize [lindex $months [expr ${month}-1]]]"
	set rslt "${rslt} [rpadLen "00[expr ${year}%100]" 2]"
	if { [llength $date] > 3 } {
	  # date has more than three fields -> must have time too
	  set rslt "${rslt} [medTime [lrange $date 3 end]]"
	}
#	return "${rslt}."
	return "${rslt}"
}
	
proc padLen {str len} {
# truncate str, or append spaces, to make exactly <len> long
	set spaces "                                                        "
	set slen [string length $str]
	set rslt $str
	if {$slen > $len}  {
		set rslt [string range $rslt 0 [expr "$len - 1"]]
	} else {
		if {$slen < $len} {
			set rslt ${rslt}[string range $spaces 0 [expr "$len - $slen - 1"]]
		}
	}
	return $rslt
}

proc rpadLen {str len} {
# truncate str FROM END, or PREpend spaces, to make exactly <len> long
	set spaces "                "
	set slen [string length $str]
	set rslt $str
	if {$slen > $len}  {
		set rslt [string range $rslt [expr "$slen - $len"] end]
	} else {
		if {$slen < $len} {
			set rslt [string range $spaces 0 [expr "$len - $slen - 1"]]${rslt}
		}
	}
	return $rslt
}

proc parseFrom from {
# take an RFC822 from field and return some canonical form
# - a two-element list with the real-name first, then the email (bare)
# Have to identify email address and real name
	set realname ""
	set email ""
# anything in angle brackets is email
	set re "<(.*)>"
	if { [regexp $re $from dummy email] } {
		regsub $re $from " " from
	}
# anything in quotes is real name
	set re "\"(.*)\""
	if { [regexp $re $from dummy realname] } {
		regsub $re $from " " from
	}
# anything in parens is real name
	set re "\\((.*)\\)"
	# had to convert single \'s (getting swallowed) to double \\'s for 5.76
	if { [regexp $re $from dummy realname] } {
		regsub $re $from " " from
	}
# assign leftover to unread field, email takes precedence
	set from [string trim $from]
	if { [string length $email] == 0 }  {
		set email [string trim $from]
	} else {
# significant unused plaintext takes precedence (over () at least) for name 
		if {[string length $from]} {
			set realname $from
		}
	}
	return [list $realname $email]
}

proc realNameFrom from {
# parse the from field and return just the real name - 
# or the email address if no realname found
	set parsedFrom [parseFrom $from]
	set realName [lindex $parsedFrom 0]
	set email [lindex $parsedFrom 1]
	if { [string length $realName] == 0 }  {
# use email if no real name
		return $email
	}
	return $realName
}	

proc findMsg txt {
# msg of email currently defined as text following first blank line
	if { [regexp "\r\r(.*)" $txt dummy msg] } {
		return $msg
	}
# if can't find it, return whole lot
	return $txt
}

proc parseMsg txt {
# replace all whitespace in msg with single spaces
	if { [regsub -all "\[ \t\r\]+" $txt " " rslt] }  {
		return $rslt
	}
# no substitutions possible
	return $txt
}

proc mailHeadline {text size} {
# Return a headline of the format "apr03 John Stautner  Yo Dan!<<When are you"
# i.e. shortform date, from field, subject and some of text
    global mailMyEmails
	set date [parseDate [findField "Date:" $text] 1]
	set fromfull [findField "From:" $text]
	# check from's email to see if it's from `us'
	if { [lsearch $mailMyEmails [lindex [parseFrom $fromfull] 1]] == -1 }  {
		# not from me - so say who it's from 
		set from [realNameFrom $fromfull]
	} else {
		# was from me - so use To: field instead
		set from "To:[realNameFrom [findField "To:" $text]]"
	}
	set subj [findField "Subject:" $text]
	set msg  [parseMsg  [findMsg $text]]
	set ksize [expr "($size+500)/1000"]
	set sizestr "(${ksize}k)"
	set lszstr [string length $sizestr]
	set firsthalf "[shortDate $date] [padLen $from [expr "20-$lszstr"]]$sizestr"
	return "$firsthalf [padLen "${subj}<<${msg}" 80]"
}

proc mailFullHL {msg txt size} {
# generate a full headline (" 32- apr03 John Stautner (32k) Yo Dan!<<Where")
# from the <txt> taken from the top of the mail file, and <msg> which 
# is the message number ("32" in the example - cannot be found in <txt>)
	set flags " "
	if { [string length [findField "Replied:" $txt]] } {
		set flags "${flags}-"
	} else {
		set flags "${flags} "
	}
#	set ksize [expr "($size+500)/1000"]
#	set sizem [padLen "(${ksize}k)" 6]
#	return "[rpadLen $msg 5]${flags}${sizem}[mailHeadline $txt]"
	return "[rpadLen $msg 4]${flags}[mailHeadline $txt $size]"
}

proc winCharCount {win}  {
# return the number of characters in the buffer for window <win>
	set inWin [lindex [winNames] 0]
	bringToFront $win
	endOfBuffer
	set chars [getPos]
	bringToFront $inWin
	return $chars
}
    

proc mailHLforWin {win} {
# get a mail headline for the named window 
	set inWin [lindex [winNames] 0]
	bringToFront $win
	# header now reports message length i.e. the <pos> of the last chr
	endOfBuffer
	set wsize [getPos]
	# hopefully all the header fields will be in the first 2k of the file
	select 0 2001
	set txt [getSelect]
	select 0 0
	bringToFront $inWin
	return [mailFullHL $win $txt $wsize]
}

proc mailHLforFile file {
# get a mail headline for the named file 
	# trailing component (after last colon) is message number
	#regsub "^.*:" $file "" win   
        set win [file tail $file]
	# should check return, else num may not exist
	set fileID [open $file r]
	if { $fileID == 0 }  {
		alertnote "mailHL: unable to open $file"
		return ""
	} else {
		# quick: find file size
		set fsize [file size $file]
	#	set fsize [lindex [ls -l $file] 1]
	# file size broken in 5.76 1994apr02 - use ls output instead
		# hopefully all the header fields will be in the first 64k of the file
		set txt [ read $fileID 64001 ]
		# 1000 chrs was not enough to handle headers with long 'To' lists
		# 2014-01-29 8001 was not long enough for increasingly long spam reports etc.
		# 2017-02-02 16001 was not long enough for ever-expanding envelope metadata.
		close $fileID
		# replace \n by \r in case of unix file
		if { [regsub -all "\n" $txt "\r" subtxt] } {
			set txt $subtxt
			# was unix; now fixed
		}
		return [mailFullHL $win $txt $fsize]
	}
}

proc mailFiles dir {
# return a list of all the files in directory <dir> that we should 
# make headlines for.
	return [concat [lsort [glob -nocomplain [file join $dir \[0-9\]]]] \
		       [lsort [glob -nocomplain [file join $dir \[0-9\]\[0-9\]]]] \
		       [lsort [glob -nocomplain [file join $dir \[0-9\]\[0-9\]\[0-9\]]]] \
		       [lsort [glob -nocomplain [file join $dir \[0-9\]\[0-9\]\[0-9\]\[0-9\]]]]]
}

proc mailScanFiles fileList {
# emit mail headlines for each file in the list
	set rslt ""
	# put a return in front to clear us of the command line in cmd window
    #insertText "\n"
	foreach file $fileList {
		set hl [mailHLforFile $file]
		# keep track of progress
	    #insertText "$file\n"		
		#insertText "${hl}\n"
		append rslt "${hl}\n"
	}
	return $rslt
}

proc mailScanDir dir {
# run mailScan over a directory and sort the results
# Should use mailScan, but mailFiles doesn't work anymore due to 
# reduced 'glob' functionality in Alpha 5.65
   return [join [lsort [split [mailScanFiles [glob [file join $dir *]]] "\n"]] "\n"]
}

proc mailScan {dir} {
# 'scan' the directory <dir>, presumed to contain mh-style mail files 
	set fileList [mailFiles $dir]
	return [mailScanFiles $fileList]
}

# -----------------------------------------------------------------------
# ------ Other functions for interactive mail access from 'mindex' window
#        once it has been created

proc thisWinFullName {} {
# returns the full path name of the current window
	return [lindex [winNames -f] 0]
}

proc pathTail path {
# strip the tail part of a full path
#	if { [regexp ":(\[^:\]*)$" $path out sub1] } {
#		return $sub1
#	} else {
#		# if cannot match, probably no colons in string - return all
#		return $path
#	}
    return [file tail $path]
}

proc pathHead path {
# strip the head part of a full path
#	if { [regexp "^(.*):\[^:\]*$" $path out sub1] } {
#		return $sub1
#	} else {
#		# if cannot match, probably no colons in string - return all
#		return $path
#	}
return [file dirname $path]
}

proc mailFilename pos {
# return a filename for an MH file associated with the current 
# line in the index window
	set start [lineStart $pos]
	set line  [getText $start [expr "$start + 10"]]
	regexp {[^0-9]*([0-9]*)} $line dummy num
	return [file join [pathHead [thisWinFullName]] $num]
}

# ----- mail reply functions ---------------------------------------

proc mailNewHeader {to cc subj} {
# generate text to serve as the header of a mail file
# with the given fields
	global dpwe_phys_location dpwe_phone
	set hdr "To: ${to}\n"
	set hdr "${hdr}Cc: ${cc}\n"
	set saveFolder [string range [danDate [parseDate [date]]] 0 6]
	set hdr "${hdr}Fcc: savebox/${saveFolder}\n"
	set hdr "${hdr}X-Phys-Location: ${dpwe_phys_location}\n"
	set hdr "${hdr}X-Phone: ${dpwe_phone}\n"
	set hdr "${hdr}Subject: ${subj}\n"
	return $hdr
}

proc mailGrabFile {file size} {
# open the file and grab the first <size> chrs
	set fileID [open $file r]
	if { $fileID == 0 }  {
		return ""
	} else {
		set txt [ read $fileID $size ]
		close $fileID
		# replace \n by \r in case of unix file
		if { [regsub -all "\n" $txt "\r" subtxt] } {
			set txt $subtxt
			# was unix; now fixed
		}
		return $txt
	}
}

proc username email {
# get recipient's username without host
# e.g. "dpwe@media.mit.edu" becomes "dpwe"
	if { [regexp "(\[A-z0-9_.\]*)\@" $email dum uname]==1 } {
		return $uname
	} else {
		# no '@' detected - must be a local address: return it all
		return $email
	}
}

# Added to $dpwe_outbox to find where drafts really are
set mailDraftDir ":drafts"
# Where messages get moved after they're sent
set mailSentMailDir ":sentmail"

proc mailNewTo {uname hdr} {
# open a new mail file to the specified user with the passed header
	global dpwe_outbox dpwe_tz mailDraftDir mailSentMailDir
#	new
# Save as a file name of the form "dpwe-1994feb15"
# get today's date as desired by reformatting ctime
	set today [danDate [parseDate "[mtime [now]] $dpwe_tz"]]
	# make sure file name does not exceed max length
	set maxFnameLen 30
	set maxNLen [expr "$maxFnameLen - 1 - [string len $today]"]
	set outdir   ${dpwe_outbox}
	set draftdir ${outdir}${mailDraftDir}
	set sentdir  ${outdir}${mailSentMailDir}
	set fnamebase [string trim [padLen ${uname} $maxNLen]]-${today}
	# fnamesufx is the ascii code for a suffix chr - start at "a"
	set fnamesufx 97
	set fname $fnamebase
	# Put suffix on name in case of conflict with existing file
	while {[file exists [file join $sentdir $fname]] || [file exists [file join $outdir $fname]]} {
		set fname $fnamebase[format %c $fnamesufx]
		incr fnamesufx
	}
	# Modify name to point to full path to draft
	set fname [file join $draftdir $fname]
	# Check to see if such a draft already exists
	set ans "yes"
	# default to overwrite mode if no file exists
	if { [file exists $fname] } {
		set ans [askyesno "Overwrite existing $fname ?"]
		if { $ans == "cancel" }  {
			# stop answering
			return
		}
	}
	if { $ans == "yes"  }  {
		# create an empty file, or overwrite existing one
		if { [catch {set file [open $fname "w"]} rslt] }  {
			alertnote "Unable to create '$fname':\r$rslt"
			return
		} else {
			close $file
		}
	}
	# if no, just add it onto the existing file		
	if { ! [catch {edit $fname}] } {
		goto [maxPos]
		insertText $hdr
	} else {
		alertnote "Unable to edit '$fname'"
	}
}

proc mailQueueMsg {} {
	# A bound key, means this message is ready to be sent - 
	# save & close the window, then move the file out of 
	# the drafts folder, and into the main outbox folder, 
	# where mh-cliserver will pick it up and send it next time
	# it is run
#	global dpwe_outbox
	global mailDraftDir
	set thisfile	[lindex [winNames -f] 0]
        set colon [file join a a]
        regsub "a" $colon "" colon
	if {![regsub "${mailDraftDir}$colon" $thisfile $colon destfile]} {
		alertnote "Cannot save $thisfile - no 'drafts' component"
		return ""
	}
	# Save it
	save
	# Close it
	killWindow
	# Move the file
	mv $thisfile $destfile
	return $destfile
}

proc mailRepl filename {
# Open a new file as a template response to pointed mail message
# 'filename' is full path filename of msg to be replied to
	set text [mailGrabFile $filename 8001]  
# headers in first 2k
	if { [string length $text] == 0 }  {
		alertnote "mailRepl: unable to open $filename"
		return ""
	}
	set date [parseDate [findField "Date:" $text]]
	set from [parseFrom [findField "From:" $text]]
	set subj [findField "Subject:" $text]
	set mid  [findField "Message-Id:" $text]
	if {$mid == ""} {
		# Sometimes final "d" is capitalized ("-ID")..
		set mid  [findField "Message-ID:" $text]
	}
	set cc   [findField "Cc:" $text]
	set name [lindex $from 0]
	set email [lindex $from 1]
	if {$name != ""} {
		set to "\"$name\" <$email>"
	} else {
		set to "<$email>"
	}
	set uname [username [lindex $from 1]]
	set hdr [mailNewHeader $to $cc "Re: $subj"]
	set hdr "${hdr}In-Reply-To: Your message of [medDate $date]\n"
	set hdr "${hdr}             ${mid}\n"
	set hdr "${hdr}--------\n"
# now have complete header
# get recipient's username without host
	mailNewTo $uname $hdr
}

proc mailIdxRepl {} {
# reply function called from mail index window chooses message to 
#   reply to by current headline
	set filename [mailFilename [getPos] ]
	mailSetFateChar [getPos] "+" 1
	# Display the message to be replied to
	mailOpenSel
	# create the reply window
	mailRepl $filename
	# tile the reply and the original message vertically
	winvertically
}
	
proc mailShwRepl {} {
# reply from within actual message window -gets msg to reply to from
#   the current window name
	set filename [lindex [winNames -f] 0]
	set msgnum [pathTail $filename]
	mailRaiseIndex
	mailMovetoMsg $msgnum
	mailSetFateChar [getPos] "+" 1
	# make sure the msg to reply to is 2nd from the front
	bringToFront $msgnum	
	mailRepl $filename
	# Arrange the windows to both be visible
	winvertically
}

proc mailCompose {} {
# function to start a new piece of mail
	set to [getline "Mail to:" " "]
	if { [string length $to] == 0 } 	return
	set uname [username [lindex [parseFrom [lindex [split $to ","] 0]] 1]]
	set cc [getline "Mail cc:" " "]
	if { [string length $cc] == 0 }		return
	set subj [getline "Mail Subject:" " "]
	if { [string length $subj] == 0 } 	return
	set hdr [mailNewHeader $to $cc $subj]
	set hdr "${hdr}--------\n"
# now have complete header
# get recipient's username without host
	mailNewTo $uname $hdr
}

#### -------- more mh-e emulation -----------------------

proc mailOpenSel {} {
# Open file indicated by current line in index as a mail message
	set filename [mailFilename [getPos] ]
	if { ! [file isfile $filename] } {
		alertnote "File '$filename' not file"
	} else {
		if { ! [file readable $filename] } {
			alertnote "File '$filename' not readable"
		} else {
			if { ! [catch {edit -r -w $filename}] } {
				# set the mode of the new window to be the one that 
				#   enables the special navigation Bindings - 
				#   <spc> for page fwd etc
				setMailMode
			}
		}
	}
}

# marking a line for deletion or refiling is reflected by this 
# character cell changing (where 0 would be the leftmost cell)
set mailFateCharCell 4

proc mailFateCharPos {pos}  {
# return the 'pos' address for the fate chr on the line containing <pos>
	global mailFateCharCell
	set start [lineStart $pos]
	incr start $mailFateCharCell
	return $start
}

proc mailGetFateChar {pos {ofst 0}}  {
# just return the contents of the character that indicates the current 
#  fate of the message headline containing $pos. 'D' for deletion, 
#  '^' for refiling, ' ' for nothing
#  <ofst> can be used to indicate a cell offset from the fate chr.
#  Mainly, this is just for the 'replied' flag at offset 1
	set start [expr "[mailFateCharPos $pos] + $ofst"]
	set end [expr "$start + 1"]
	if { $end >= [maxPos] } {
		return ""
	} else {
		return [getText $start $end]
	}
}

proc mailSelFateChar {pos {ofst 0}} {
# the char just after the message number is used to indicate the 
#  fate of this message - is it to be deleted or refiled?
#  This function selects and returns it.  (select means caller 
#  can simply delete or replace it).
#  <ofst> can be used to indicate a cell offset from the fate chr.
#  Mainly, this is just for the 'replied' flag at offset 1
	set start [expr "[mailFateCharPos $pos] + $ofst"]
	select $start [expr "$start+1"]
	return [getSelect]
}

proc mailSetFateChar {pos char {ofst 0}}  {
# change the contents of the character that indicates the current 
#  fate of the message headline containing $pos. 'D' for deletion, 
#  '^' for refiling, ' ' for nothing
#  <ofst> can be used to indicate a cell offset from the fate chr.
#  Mainly, this is just for the 'replied' flag at offset 1
	set start [expr "[mailFateCharPos $pos] + $ofst"]
	set end [expr "$start + 1"]
	set prev [getText $start $end]
	deleteText $start $end
	goto $start
	insertText $char
}

# mail prevailing sense determines if the next or previous message 
#  is selected after a delete
set mailPrevailingSense 1

proc mailPrevMsg {} {
# bound to 'p' in mail mode - up one (unmarked) message
	global mailPrevailingSense
	goto [lineStart [getPos]]
	previousLine
	set done 0
	while { $done == 0 }  {
		set pos [getPos]
		if { $pos == 0  }  {
			set done 1
		}
		if { [mailGetFateChar $pos] == " " }  {
			set done 1
		} else {
			goto [lineStart $pos]
			previousLine
		}
	} 
	goto [lineStart $pos]
	set mailPrevailingSense -1
	selectLine
}

proc mailNextMsg {} {
# bound to 'n' in mail mode - down one (unmarked) message
	global mailPrevailingSense
	goto [lineStart [getPos]]
	nextLine
	set done 0
	set end [maxPos]
	while { $done == 0 }  {
		set pos [getPos]
		if { $pos == $end  }  {
			set done 1
		}
		if { [mailGetFateChar $pos] == " " }  {
			set done 1
		} else {
			goto [lineStart $pos]
			nextLine
		}
	} 
	goto [lineStart $pos]
	set mailPrevailingSense 1
	selectLine
}

proc mailRaiseIndex {{path ""}} {
	# find a *.mindex window (optionally related to msg $path)
	# and bring it to the front.
	# Returns 1 on success, 0 if not found & alerts user too
	if {$path != ""} {
		# $path not yet implemented
		alertnote "mailRaiseIndex: path $path ignored"
	}
	set wnames [winNames]
	if { [regexp "\[^ \{\]*\.mindex" $wnames midxwin]==0 } {
		alertnote "Couldn't find a mail-index window"
		return 0
	}
	# switch to the mail window and find the msg line
	bringToFront $midxwin
	return 1
}

proc mailMovetoMsg {msg} {
	# move the cursor to the beginning of the line for msg # $msg (e.g. "123")
	# return 0 if it wasn't found (and alert user), else 1	

	# Find the index line corresponding to the message we started with
	set msgpos [search -f 1 -r 1 -s -i 1 -m 0 -n "^ *$msg\[^0-9\]" 0]
	if {[llength $msgpos]==0}  {
		# search for msgtagline failed
		alertnote "Couldn't find msg $msgnum in index window"
		return 0
	}
	# move insertion point to that msg
	select [lindex $msgpos 0]
	return 1
}

proc mailShowMsg {sense} {
	# Switch to the next or prev message in mail-show mode - have to guess
	# to find proper index window
	
	# the number of the current msg is in this window name
	set msgnum [lindex [winNames] 0]
	# kill this msg window
	killWindow
	# find the mindex window & select the message we were looking at
	mailRaiseIndex
	mailMovetoMsg $msgnum
	if {$sense=="prev"} {
		mailPrevMsg
	} else {
		mailNextMsg
	}
	# Open the new mail message
	mailOpenSel	
}

proc mailShowNextMsg {} {
	# bound to n in mail-show mode - close this window, switch to 
	# mail index window, choose next msg
	mailShowMsg "next"
}

proc mailShowPrevMsg {} {
	# bound to p in mail-show mode - close this window, switch to 
	# mail index window, choose prev msg
	mailShowMsg "prev"
}

proc mailDelSel {} {
# Delete the file indicated by the current line in the index
	global mailPrevailingSense
	set filename [mailFilename [getPos] ]
	# mark the entry as deleted in the index
#	mailSelFateChar [getPos]
#	deleteText [getPos] [selEnd]
#	insertText "D"
	mailSetFateChar [getPos] "D"
	# then move to a different message depending on prevailing sense
	if { $mailPrevailingSense == 1  }  {
		mailNextMsg
	} else {
		mailPrevMsg
	}
}

proc mailDelWin {} {
	# Mark as deleted in the index window the currently-displayed message

	# the number of the current msg is in this window name
	set msgnum [lindex [winNames] 0]
	# close this window
	killWindow
	# find the mindex window and the entry for this message
	mailRaiseIndex
	mailMovetoMsg $msgnum
	# invoke the index delete function
	mailDelSel
}
	

proc mailUnmarkSel {} {
# bound to 'u' in mail mode
	set filename [mailFilename [getPos] ]
	# find current status of this line (i.e. character in relevant field)
	set ch [mailSetFateChar [getPos] " "]
	# move to start of line
	goto [lineStart [getPos]]
}

proc mailRefileSel {}  {
# bound to 'o' i.e. refiles mail (marks to be copied into new dir)
# problem: how to remember where to send it?
	set filename [mailFilename [getPos] ]
	# find current status of this line (i.e. character in relevant field)
	set pos [getPos]
	set ch [mailGelFateChar $pos]
	mailSetFateChar $pos "^"
	# move to start of line
	goto [lineStart $pos]
}

proc mailPackFolder folder {
# renumber all the mh-message-like files in a folder to form a 
# continuous sequence of numbers
	set cwd [pwd]
	cd $folder
	set files [glob \[0-9\] \[0-9\]\[0-9\] \[0-9\]\[0-9\]\[0-9\] \[0-9\]\[0-9\]\[0-9\]\[0-9\] ]
	set fn "0"
	foreach file $files {
		incr fn
		echo $fn
		if { $fn != $file } {	# only mv if need to
			mv $file $fn
		}
	}
	# restore entry directory
	cd $cwd
	return $fn 
	# [llength $files]
}

proc timeStamp time {
# formats the 'mtime'-like time/date string into something we like
# i.e. [timeStamp [mtime [now]]] returns "1994apr08 20:27"
	global dpwe_tz
	# if the passed-in time doesn't end in a time zone, append our 
	# global one to prevent parseDate from making a diagnosic error msg
	if {![regexp {[ \t][A-z][A-z]?$} $time] \
		&& ![regexp {[+-][0-9][0-9][0-9][0-9]([ \t]*\([A-z]*\))} $time] } {
		set time "$time $dpwe_tz"
	}
	set canonDate [parseDate $time]
	return "[danDate $canonDate] [timeFmt [lrange $canonDate 3 5]]"
}

proc mailDoMods {} {
# bound to 'x'; commits to refiles and deletes
	# append record of mods to file
	set modFH [open "[file join [pathHead [thisWinFullName]] mod.log]" "a+"]
#	goto 0
	set pos 0
	while { $pos < [maxPos] }  {
		set ch [mailGetFateChar $pos]
		if { $ch == "D" } {
			set filename [mailFilename $pos]
			if { [catch "rm $filename"] } {
			#	alertnote "Could not rm '$filename'"
				# move to next line
				set pos [nextLineStart $pos]
			} else {
				# remove that line from the index
				deleteText [lineStart $pos] [nextLineStart $pos]
			}
			puts $modFH "[timeStamp [mtime [now]]]: deleted $filename"
		} else { if { $ch == "^" }  {
			# do redirect
			set filename [mailFilename $pos]
			regsub "inbox" $filename "savebox" destname
			if { [catch "mv $filename $destname"] } {
			#	alertnote "Could not mv '$filename' to '$destname'"
				# move to next line
				set pos [nextLineStart $pos]
			} else {
				# remove that line from the index
				deleteText [lineStart $pos] [nextLineStart $pos]
			}
			puts $modFH "[timeStamp [mtime [now]]]: refiled $filename to $destname"
		} else {
			# assume nothing to be done - move to next line
			set pos [nextLineStart $pos]
		} }
	}
	close $modFH
}

proc dumFn {}  {
    set pos [getPos]
    deleteText [lineStart $pos] [nextLineStart $pos]
}

#### Refile (for this and for remote operation)
#
# First, collect output folder choice for each message that is marked, 
# and store in array?  write to file?
# Then, when 'x' is typed, commit changes by (a) moving messages or deleting 
# them if they don't exist, and (b) writing a record of those changes to 
# a special file in the outbox, which will be used to mirror the moves on 
# the remote host.  No way to do the inverse (reflect Unix-based moves on 
# mac) at present.

# The refiles are stored in two ways:
# in the refileDestArray(msgnum), set to the directory name
# in the file refileDest.txt, which has "msgnum destdir" lines.

#resetArray refileDestArray
# .. which amounts to ..
set refileDestArray(dummy) ""
unset refileDestArray(dummy)

proc resetArray name {
	# make sure that "name" exists as an array in the calling context, 
	# but leave it empty
	upvar 1 $name localname
	set localname(dummy) ""
	unset localname(dummy)
}

proc RefileDestsSave {filename "refileDest.txt"} {
	# Save out all the info in the refileDestArray
	global refileDestArray
	set f [open $filename "w"]
	foreach msg [lsort [array names refileDestArray]] {
		set dest $refileDestArray($msg)
		puts $f "$msg $dest"
	}
	close $f
}

proc RefileDestsLoad {filename "refileDest.txt"} {
	# Read back the saved refileDestArray
	global refileDestArray
	if {[file exists $filename]} {
		set f [open $filename "r"]
		# Empty the array before we read something in
		resetArray refileDestArray
		close $f
		# Remove it after we read it in???
		file remove $f
	}
	NOT FINISHED
}
	

# Bound to "o"

#### Other functions

proc mailMakeMailFile {mailFile {mhFiles ""} {mhDir ""}} {
	# Take a list of message file IDs $mhFiles found in $mhDir
	# (defaults to $dpwe_inbox) and write them out as a single, 
	# composite mail file in /bin/mail format ("From " separators)
	global dpwe_inbox
	if {$mhDir == ""} {set mhDir $dpwe_inbox}
	if { [set file [open $mailFile "w"]] == ""} {
		alertnote "makeMail: Couldn't write mailFile $mailFile"
		return 0
	}
	if {$mhFiles == ""} {
		# Take all the files in $mhDir
		set mhFiles [glob [file join $mhDir \[0-9\]] [file join $mhDir \[0-9\]\[0-9\]] \
			[file join $mhDir \[0-9\]\[0-9\]\[0-9\]] [file join $mhDir \[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
	}	
	set nfiles 0
	foreach m $mhFiles {
		# Separator is of form:
		# From ???@??? Sat Jul 13 15:19:49 1996
		# - parse this message to get that info
		if {[regexp {:|/} $m]==0} {
			set mhFile [file join $mhDir $m]
		} else {
			set mhFile $m
		}
		set text [mailGrabFile $mhFile 2001]  
		if { [string length $text] == 0 }  {
			alertnote "makeMail: unable to read $mhFile"
		} else {
			set date [parseDate [findField "Date:" $text]]
			set from [parseFrom [findField "From:" $text]]
			set uadr [lindex $from 1]
			# Write output prefix
			puts $file "From $uadr [medDate $date]"
			# Copy message
			set f2 [open $mhFile "r"]
			set txt [read $f2]
			close $f2
			puts -nonewline $file $txt
			# append blank line
			puts $file ""
			incr nfiles
		}
	}
	close $file
	return $nfiles
}

proc selectLine {} {
	# Select a whole line, rather than just leaving the cursor somewhere
	beginningOfLine
	endLineSelect
}

set mailMyEmails "dpwe@ee.columbia.edu"

puts [mailScan $argv]
exit 0


global notestate accidstate outputline
# sharpers and flatters are used to sharpen
# or flatten the note degrees in the scale
# to accomodate the key signature.
set sharpers {7 3 6 2 5 1 4}
set flatters {4 1 5 2 6 3 7}
# sharpkeys and flatkeys is used to detrmine
# how many sharps or flats are needed for a
# particular key signature.
set sharpkeys {G D A E B C# F#}
set flatkeys {F Bb Eb Ab Db Gb}

array set accid2sym {-1 _ 0 = 1 ^}

proc set_pitchtype {key} {
# pitchtype applies the key signature to the note degrees.
# it is copied to accidstate which is used to propagate
# accidentals inside a bar. Each time a new bar line
# is set accidstate is reset to pitchtype.
global pitchtype accidstate
global sharpers flatters
global sharpkeys flatkeys
for {set i 1} {$i <= 7} {incr i} {
   set pitchtype($i) 0
   set accidstate($i) 0
   }
set n [lsearch $sharpkeys $key]
if {$n >= 0} {
   for {set i 0} {$i <= $n} {incr i} {
     set j [lindex $sharpers $i]
     set pitchtype($j) 1
     set accidstate($j) 1
     }
  set pitchtype(x) 0
  set accidstate(x) 0
  return
  }
set n [lsearch $flatkeys $key]
if {$n >= 0} {
   for {set i 0} {$i <= $n} {incr i} {
     set j [lindex $flatters $i]
     set pitchtype($j) -1 
     set accidstate($j) -1
     }
 }

return
}

proc setkeysig {key} {
global keyindex
# keyindex is the index number corresponding to the
# tonic of the piece (ignoring sharps and flats).
set keyindex [string first $key "CDEFGAB" ]
if {$keyindex >= 0} return
set keyindex [lsearch {CB DB EB FB GB AB BB} $key]
}



proc process_digit {token} {
# the digit is used to indicate the note degree relative
# to the tonic. If a digit is encountered, any note in
# notestate is sent to the output file and notestate is
# cleared. We convert the note degree to ABC notation
# pitch applying any octave shifts if present and store
# it in notestate(note). We also store the note degree
# in notestate(number) which is used for processing ties.
global notestate keyindex
global newbarline
set newbarline 0
#  puts "process_digit  $token"
if {[info exist notestate(note)]} {send_note_to_output}
if {$token == "0"} {set note z
  } elseif {$token == "x"} {set note c'
  } else {
    set melindex [expr $keyindex + $token -1]
    set note [string index  "CDEFGABcdefgab" $melindex]
    }
if {[info exist notestate(octave)]} {
    if {$notestate(octave) == 1 && [string is upper $note]} {
          set note [string tolower $note]}
    if {$notestate(octave) == -1 && [string is lower $note]} {
          set note [string toupper $note]
    } elseif {$notestate(octave) == -1} {set note $note,}
   }
set notestate(length) 1
set notestate(note) $note
set notestate(number) $token
#puts "$notestate(note) $notestate(number)"
}

proc process_tie {} {
global notestate lastnote lastnumber
global newbarline outputline
if {$newbarline == 0} {
  send_note_to_output
  set outputline $outputline-
  }
set notestate(note) $lastnote
set notestate(number) $lastnumber
set notestate(length) 1
if {[info exist lastoctave]} {set notestate(octave) $lastoctave}
}

proc process_space {} {
# two spaces signals a new bar; so we need to count them and
# produce a bar line each time we encounter two spaces.
global notestate 
#  puts "process_space"
  if {[info exist notestate(space)]} {send_bar_to_output
    } else {set notestate(space) 1}
}

proc process_accidental {token} {
# Remember the accidental if we encounter it. These accidentals
# do not propagate and only shift a note up or down from the
# assumed placement determined by the key signature. Note there
# is no natural code. For example in the key of F, note degree
# 4 is converted to Bb, note degree 4# is converted to B natural.
global notestate
set notestate(accidental)  $token
}


proc process_length {token} {
global notestate
if {$token == "_"} {
   set notestate(length) [expr 2 * $notestate(length)]
   } elseif {$token == "."} {
   set notestate(length) [expr $notestate(length) + $notestate(length)/2]
   } else {
   puts "$token not implemented"
  }
}

proc process_octave {token} {
global notestate
if {[info exist notestate(note)]} {send_note_to_output}
if {$token == "+"} {
   set notestate(octave) 1
 } else {
   set notestate(octave) -1
  }
}

proc process_token {token} {
#puts "process_token $token"
if {[string is digit $token]}  {process_digit $token}
if {[string is space $token]}  {process_space}
if {[string equal $token "b"]} {process_accidental $token}
if {[string equal $token "#"]} {process_accidental $token}
if {[string equal $token "_"]} {process_length $token}
if {[string equal $token "."]} {process_length $token}
if {[string equal $token "+"]} {process_octave $token}
if {[string equal $token "-"]} {process_octave $token}
if {[string equal $token "^"]} process_tie
if {[string equal $token "x"]}  {process_digit $token}

}


proc parse_mel_line {line} {
global outputline outhandle next_token melcount body
set length [string length $line]
for {set i 0} {$i < $length} {incr i} {
  set token [string index $line $i]
  set next_token [string index $line [expr $i + 1]]
  process_token $token
  if {[string equal $token "/"]} {
          send_note_to_output
          return 1};
  }  
send_note_to_output
#puts $outhandle $outputline
set body($melcount) $outputline
incr melcount
return 0
}

proc get_accidental {} {
# returns b,=, or ^ if it is necessary to precede
# a note with an accidental; otherwise returns
# nothing. Also performs accidental propagation
# over a music bar.
global accidstate notestate
global pitchtype accid2sym
if {![info exist notestate(accidental)]} {set avalue 0
  } else {
  if {$notestate(accidental) == "b"} {set avalue -1
    } else {
    set avalue 1}
  }
set n $notestate(number)
if {$n == 0} {return ""}
set newvalue [expr $pitchtype($n)+$avalue]
 
if {$accidstate($n) == $newvalue} {return ""}
if {$accidstate($n) != $newvalue} {
  set accidstate($n) $newvalue
  return $accid2sym($newvalue)
  }
}
   

proc send_note_to_output {} {
global notestate outputline lastnote lastoctave lastnumber
if {![info exist notestate(note)]} return
set a [get_accidental]
#puts $a
#puts "$notestate(note) $notestate(length)"
if {$notestate(length) == 1} {
   set output $a$notestate(note)
} else {
   set output $a$notestate(note)$notestate(length)
   }
set outputline $outputline$output
#puts $outputline
set lastnote $notestate(note)
set lastnumber $notestate(number)
if {[info exist notestate(octave)]} {set lastoctave $notestate(octave)}
unset notestate
}

proc send_bar_to_output {} {
global outputline accidstate next_token
global newbarline pitchtype
send_note_to_output
# check for tied note
if {$next_token == "^"} {set outputline $outputline-}
set outputline "$outputline | "
for {set i 1} {$i < 8} {incr i} {set accidstate($i) $pitchtype($i)}
set newbarline 1
#puts $outputline
}

proc dump_body {} {
global melcount outhandle body
for {set i 0} {$i < $melcount} {incr i} {
  puts $outhandle $body($i)
  }
} 

proc dump_field_data {} {
global outhandle xcount title fname origin
global timesig len key description
global notice noticecount sourc;
puts $outhandle ""
puts $outhandle "X:$xcount"
puts $outhandle "T: $title"
puts $outhandle "N: $fname"
puts $outhandle "O: $origin"
if {[info exist sourc]} {puts $outhandle "S: $sourc"}
if {$noticecount > 0} {
   for {set i 0} {$i < $noticecount} {incr i} {
      puts $outhandle "N: $notice($i)"
      }
   }
if {[info exist description]} {
  puts $outhandle "R: $description"
  }
if {$timesig == "FREI"} {puts $outhandle "M: none"
  } else {puts $outhandle "M: $timesig"}
# remove initial 0 from note length code (eg 04 to 4).
if {[string index $len 0] == "0"} {
   set len [string range $len 1 end]
   }
puts $outhandle "L: 1/$len"
if {[string is lower $key]} {
# minor key signature 
  puts $outhandle "K: [string toupper $key]m"
  } else {
  puts $outhandle "K: $key"
  }
}

  



set filelist [glob esac/*.sm]
#set filelist {esac/altdeu10.sm}
#set filelist {esac/HAN1.sm}
#set filelist {bug.sm}
#set filelist {esac/LOT.SM esac/LUX.SM esac/HAYDN.SM esac/IRL.SM}
#set filelist {esac/HAN1.SM esac/HAN2.SM }
puts $filelist

foreach infile $filelist {
 set outfile [file rootname $infile].abc
 puts $outfile
 set inhandle [open $infile r]
 set outhandle [open $outfile w]
 set xcount 1

 while {[gets $inhandle line]>= 0} {
#  puts $line
  set code [string range $line 0 2]
  set length [string length $line]
#  incr length -2
  incr length -1
  if {[string compare $code "CUT"] == 0} {
        set title [string range $line 4 $length]
        set title [string trimright $title "]"]
        if {[info exist description]} {unset description}
        set noticecount 0
        if {[info exist sourc]} {unset sourc}
        #puts $title
     }
  if {[string compare $code "KEY"] == 0} {
        set keycode [string range $line 4 $length]
        set keycode [string trimright $keycode "]"]
        #puts $keycode
        scan $keycode {%s %s %s %s} fname len key timesig
        setkeysig [string toupper $key] ;#in case of minor key
        set_pitchtype $key
	}
 if {[string compare $code "REG"] == 0} {
        set origin [string range $line 4 $length]
        set origin [string trimright $origin "]"]
        #puts $origin
	}
 if {[string compare $code "FCT"] == 0} {
        set description [string range $line 4 $length]
        set description [string trimright $description "]"]
       # puts "description = $description"
        }
 if {[string compare $code "FKT"] == 0} {
        set description [string range $line 4 $length]
        }
 if {[string compare $code "TRD"] == 0} {
        set sourc [string trimright $line "]"]
        set sourc [string range $line 4 $length]
        }

 if {[string compare $code "BEM"] == 0 ||
     [string compare $code "CMT"] == 0} {
       set stop -1
       set noticecount 0;
       #incr length
       while {$stop < 0} {
         set inputline [string range $line 4 $length]
         set stop [string first "]" $inputline]
         if {$stop > 0} {incr stop -1
                         set inputline [string range $inputline 0 $stop]
                        }
         set notice($noticecount) $inputline
         if {[gets $inhandle line] < 0} break
         set length [string length $line]
         incr noticecount
         }
       }

 if {[string compare $code "MEL"] == 0} {
    set melcount 0
    set inputline [string range $line 4 end ]
    while {[string length $inputline] > 1} {
      set outputline ""
      #puts $inputline
      set inputline [string trimright $inputline]
      set done [parse_mel_line $inputline]
      if {$done} {
         set body($melcount) $outputline
         incr melcount
         #puts $outhandle $outputline
         break}
      gets $inhandle line 
      #puts $line
      set inputline [string range $line 4 end ]
      }
    #puts $outhandle ""
    }
    if {[string length $line] == 0} {
      dump_field_data
      dump_body
      incr xcount
      }
  }
   close $outhandle
   close $inhandle
}



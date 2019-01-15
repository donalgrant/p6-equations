use v6;

unit module Globals;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

our %opt;  # global options
our %debug; # debug keywords

multi sub opt( $key ) is export { %opt{$key}:exists ?? %opt{$key} !! Nil }
multi sub opt()       is export { %opt }

multi sub set_opt( *%o  )  is export { %opt{$_}=%o{$_} for %o<>:k }
multi sub set_opt( *@key ) is export { %opt{$_}=True for @key }

multi sub clr_opt( *@key ) is export { %opt{$_}:delete for @key }
multi sub clr_opt()        is export { %opt=() }

multi sub debug()            is export { so %debug{caller[4].subname} or %debug<all> }
multi sub debug( $key )      is export { %debug{$key}:exists ?? %debug{$key} !! ( so %debug{caller[4].subname} or so %debug<all> )  }
multi sub debug_all( *@key ) is export { so %debug<all>:exists or so %debug{all @key}.grep( *.defined ) }
multi sub debug_any( *@key ) is export { so %debug<all>:exists or so %debug{any @key}.grep( *.defined ) }
multi sub debug_list()       is export { %debug<>:k }


multi sub set_debug( *%o  )  is export { %debug{$_}=%o{$_} for %o<>:k }
multi sub set_debug( *@key ) is export { %debug{$_}=True for @key }

multi sub clr_debug( *@key ) is export { %debug{$_}:delete for @key }
multi sub clr_debug()        is export { %debug=() }

sub caller() is export { Backtrace.new.list }

sub msg($txt='[ Undefined text ]', $src?, :$trace) is export {
#  return if opt('quiet') and not so debug_list;
  my $out=$txt;
  $out ~= "[from $src]" if $src;
  $out ~= caller() if $trace;
  note $out; 
}  

sub quit($txt='[ Undefined text ]') is export { msg($txt, :trace); die() }

sub assert(Block $test, $msg='[ Unspecified assertion ]') is export {
  quit('FAIL***'~$msg) unless so $test();
}

sub shuffle_in_place ( @array ) is export {
  for 0..@array.end-1 { @array[ $_, ($_+1..@array.end).pick ] .= reverse }
}
sub shuffle ( @array ) is export { my @c=@array; shuffle_in_place @c; return @c }

sub chance( Numeric $x ) is export { return rand < $x }

sub p5-deref1( $p5ref ) is export {
  [ gather { for @$p5ref -> $a { take @$a } } ]
}

sub p5-deref2( $p5ref ) is export {
  [ gather {
      for @$p5ref -> $a {
	take [ gather { for @$a -> $b { take @$b } } ]
      }
    } ]
}

# compute a string corresponding to the number of operators allowable in an RPN expression
# at each position defined by the digits in the string, where the first position is after
# the second digit.  There is always one fewer operator than the number of digits.
# For example:
#
#   32+548//+   (3+2) + (5/(4/8))    ops_slots = '1003'
#   32548+//+   3 + (2/(5/(4+8)))    ops_slots = '0004'
#
# In an RPN expression ops-slot, the digit in each slot must be <= the position of the slot;
# and the total of the digits in the ops-slot equals the number of ops-slots.  At every slot,
# the cumulative number of ops must be < the number of digits, i.e., less than or equal to
# the slot number.  Finally, the final ops-slot digit must always be >=1.
#
# the routine returns a list of all possible ops-slot strings for the length of the ops-slot string

sub build_ops_slot_options($slot,$n,@options) {
  gather {
    for @options -> $this_option {
      my $naccum=$slot - [+] $this_option.comb;  # potentially available operators
      for 0..$naccum { take "$this_option$_" } 
    }
  }
}

sub ops_slots($n) is export {
  return ['1'] if $n==1;
  return ['11','02'] if $n==2;
  my @options=['0', '1'];  # start list -- will build in next line
  for 2..$n-1 -> $slot { @options=build_ops_slot_options($slot,$n,@options) }
  @options.map( { $_~($n - [+] $_.comb) } );  # get last slot
}


# this method assumes on input that num_list has at least two entries,
# and ops_list has at least one entry; and also that $slot has been
# created consistent with the number of operations in $ops_list

sub num-ops-slot($num_list,$ops_list,$slot) is export {
#  msg "constructing RPN for pn={$num_list.join(',')}; po={$ops_list.join(',')}; slot=$slot" if debug('RPN-build');
  my ($ipn,$ipo)=(0,0);
  my $x=$num_list[$ipn++];
  for $slot.comb -> $s {
#    msg "inner block:  s=$s, x=$x, ipn=$ipn, ipo=$ipo, pn={$num_list.join(',')}, po={$ops_list.join(',')}" if debug('RPN-build');
    $x~=$num_list[$ipn++];
    $x~=$ops_list[$ipo++] for (1..$s);
  }
  return $x;
}

sub unique_tuples(@a) is export { @a.unique(:as( *.join('') )) }

# generate the list of tuples of length $n from Bag $src while enforcing use of all in Bag $req

sub get_tuples($n,Bag $src,Bag $req) is export { 
  return () unless $src (>=) $req;
  return () unless $n >= $req.total;   # can't generate tuples w/length less than # of req cubes
  my $remain=($src (-) $req).BagHash;
  my @req_list=$req.kxxv;
  # this is tricky -- combinations will return an array of arrays unless there is only a single combination, in which case it's just an array
  # single combination happens in case where number of elements to combine is the same as the number at a time for the combinations
  my @comb = gather {
    if ($n > @req_list) {
      if ($n-@req_list == $remain.total) {
	take [ gather { @req_list.map({ take $_ }); [$remain.kxxv].map({ take $_ }) } ];
      } else {
	unique_tuples(
	  gather {
	    p5-deref1(combinations( $[ $remain.kxxv ], $n - @req_list )).map({ take Array.new.append(@req_list).append(@$_) });
	  }
	).map({ take $_ });
      }
    } else { take $[ $req.kxxv ] }
  }
  # now for each element of @comb, generate all the permutations and add to the total list; return unique tuples
  unique_tuples gather { for (@comb) { p5-deref1(permutations( $_ )).map({ take $_ }) } }
}

sub choose_n($n,@c) is export {
  die "choose_n range should be 1<=n<={@c.elems}" unless $n>0;
  return @c if $n>=@c.elems;
  for 0..$n-1 { @c[$_,($_+1..@c.end).pick].=reverse }
  @c[0..$n-1];
}


=begin pod

=head1 NAME

Globals.pm - Global functions useful to all modules and the main program

=head1 DESCRIPTION

Global functions should be referenced with the full package qualifier, in order 
to make it obvious that these are defined outside the current file / module.

Not implemented yet, but this should include any Global data, particularly
an %::opt hash of execution options.

=head2 Execution Functions

  * caller_list()                       - for diagnostics, returns list of calling subroutines
  * msg  "message text", "source"       - display a message ("source" argument is optional)
  * quit "message", "source"            - quit with a message ("source argument is optional)
  * assert { test_code } "test message" - like Test::ok(), but quits on failure and operates quietly.

=head2 Array Operations

  * unique(@)        - Built-in to Perl 6
  * shuffle_in_place - shuffles an array in-place -- no return value
  * shuffle(@)       - makes a copy of the list, randomly reorder elements of the list copy, 
                       and returns the re-ordered list copy.  Original remains unchanged.
  * min(@)           - Built-in to Perl 6
  * max(@)           - Built-in to Perl 6

=end pod


use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

module Globals {

  sub caller() is export { Backtrace.new.list }

  sub msg($txt='[ Undefined text ]', $src?, :$trace) is export { 
    my $out=$txt;
    $out ~= "[from $src]" if $src;
    $out ~= caller() if $trace;
    put($out); 
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
    my @s;
    for @$p5ref -> $a { push @s, @$a }
    return @s;
  }
  
  sub p5-deref2( $p5ref ) is export {
    my @s;
    for @$p5ref -> $a {
      my @t;
      for @$a -> $b { push @t, @$b }
      push @s, @t;
    }
    return @s;
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
  # and the total of the digits in the ops-slot equals the number of ops-slots.  Finally,
  # the final ops-slot digit must always be >=1.
  #
  # the routine returns a list of all possible ops-slot strings for the length of the ops-slot string

  sub ops_slots($n) is export {
    return ['1'] if $n==1;
    return ['11','02'] if $n==2;
    my @options=['0', '1'];
    for 2..$n-1 -> $slot {
      my @new_options;
      for @options -> $this_option {
	my $naccum=min($slot, ($n-1) - [+] $this_option.comb);  # potentially available positions
	my @accum_options;
	for 0..$naccum -> $n_in_slot {
	  @accum_options.push("$this_option$n_in_slot");
	}
	@new_options.append(@accum_options);
      }
      @options=@new_options;
    }
    @options.map( { $_~($n - [+] $_.comb) } );
  }
  
  sub unique_tuples(@a) is export { @a.unique(:as( *.join('') )) }
  
  # generate the list of tuples of length $n from Bag $src while enforcing use of all in Bag $req
  
  sub get_tuples($n,Bag $src,Bag $req) is export { 
    return () unless $src (>=) $req;
    return () unless $n >= $req.total;   # can't generate tuples w/length less than # of req cubes
    my $remain=($src (-) $req).BagHash;  
    my @req_list=$req.kxxv;
    #  note "for $n cubes, src={$src.kxxv}, req={$req.kxxv}";
    #  note "$n vs {+@req_list} will generate combinations {[combinations( $[ $remain.kxxv ], $n - @req_list )].join(',')}";
    # this is tricky -- combinations will return an array of arrays unless there is only a single combination, in which case it's just an array
    my @comb = $[ $req.kxxv ];
    if ($n > @req_list) {
      my @temp=[combinations( $[ $remain.kxxv ], $n - @req_list ) ];  # note "temp=[{@temp.map({ $_.join(',') }).join('],[')}]"; note "type of [0] is {@temp[0].^name}";
      #   note "truth of temp[0] ~~ /Array/:  {so @temp[0].^name ~~ /Array/}";
      if (@temp[0].^name~~/ Array | List /) {  # array of arrays
	@comb=unique_tuples @temp.map({ Array.new.append(|@req_list,|$_) }); #  note "array of arrays";
      } else { # just an array
	@comb[0]=Array.new.append(|@req_list,|@temp);  #  note "just an array; comb=[{@comb.map({ $_.join(',') }).join('],[')}]";
      }
    }
    # now for each element of @comb, generate all the permutations and add to the total list
    #  note "number of combinations is {@comb.elems}; comb=[{@comb.map({ $_.join(',') }).join('],[')}]";
    my @perms;
    for (@comb) { @perms.append(permutations( $_ )) }
    #  note "number of permutation elements is {@perms.elems}; perms=[{@perms.map({ $_.join(',') }).join('],[')}]";
    @perms=unique_tuples @perms;
    #  note "after unique:   num elements  = {@perms.elems}; perms=[{@perms.map({ $_.join(',') }).join('],[')}]";
    return @perms; 
    #  note "will return [{ unique_tuples( @comb.map({ permutations($[ |$_ ]) }).flat ).map({ $_.join(',') }).join('],[') }]";
    #  unique_tuples( @comb.map({ permutations($[ |$_ ]) }).flat );
  }
  
  sub choose_n($n,@c) is export {
    die "choose_n range should be 1<=n<={@c.elems}" unless $n>0;
    return @c if $n>=@c.elems;
    for 0..$n-1 { @c[$_,($_+1..@c.end).pick].=reverse }
    @c[0..$n-1];
  }
  
}  # end of Globals module

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


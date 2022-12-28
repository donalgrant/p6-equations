use v6;

unit module Tuples;

use Globals;
use Math::Combinatorics :ALL;

sub unique_tuples($a) is export { $a.unique(:as( *.join('') )) }

# generate the list of tuples of length $n from Bag $src while enforcing use of all in Bag $req

sub get_tuples($n,Bag $src,Bag $req) is export {
  return () unless $src ⊇ $req;
  return () unless $n >= $req.total; # can't generate tuples w/length less than # of req cubes
  my @remain=($src ∖ $req).kxxv;  # set op (^), not backslash; List of additional beyond required
  my @req=$req.kxxv;        # list of required 

#  msg "remain="~@remain.raku~"; req_list="~@req.raku;
  # this is tricky -- combinations will return an array of arrays unless there is only a single combination,
  # in which case it's just an array.  single combination happens in case where number of elements to combine
  # is the same as the number at a time for the combinations

  my @comb = gather {
    if ($n > @req) { 
      if ($n-@req == @remain) {	take [ |@req,|@remain ] }
      else {
	  my @c = combinations(@remain,$n-@req);
	  # msg "comb-0 is {@c.raku}";
	  unique_tuples( gather { for @c { take [ |@req, |$_ ] } } ).map({ take $_ });
      }
    } else { take @req }
  }
#  msg "first comb collection yields {@comb.raku}";
  # now for each element of $comb, generate all the permutations and add to the total list; return unique tuples
  unique_tuples gather { for (@comb) { variations( $_, $_.elems ).map({ take $_ }) } }
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


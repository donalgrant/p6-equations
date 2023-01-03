use v6;

use Math::Combinatorics :ALL;

# use lib q<.>;
use Globals;
use Tuples;
use RPN;

sub board_sort($a,$b) { $a~~/\d/ && $b~~/\d/ ?? $a <=> $b !! ( $a~~/\d/ ?? +1 !! ($b~~/\d/ ?? -1 !! $a cmp $b) ) }  # ops before digits

class Board {

  has BagHash $.U is required;   # Unused cubes
  has BagHash $.R;   # Required cubes
  has BagHash $.P;   # Permitted cubes
  has BagHash $.F;   # Forbidden cubes
  
  has Str $.G='';    # goal (string of cubes)

  multi method new( BagHash $U  ) { Board.new( :$U                               ) }
  multi method new( Bag $B      ) { Board.new( U=>$B.BagHash                     ) }
  multi method new( Seq $cubes  ) { Board.new( U=>BagHash.new($[$cubes])         ) }
  multi method new( Str $cubes  ) { Board.new( U=>BagHash.new($cubes.comb(/\S/)) ) }
  multi method new( List $cubes ) { Board.new( $cubes.join('')                   ) }

  method clone { Board.new(U=>self.U.clone,R=>self.R.clone,P=>self.P.clone,F=>self.F.clone,G=>self.G) }

  submethod TWEAK() { $!R//=BagHash.new; $!P//=BagHash.new; $!F//=BagHash.new }
  
  method required  { $!R.kxxv }
  method permitted { $!P.kxxv }
  method forbidden { $!F.kxxv }
  method unused    { $!U.kxxv }

  method goal      { $!G.chars > 0 ?? $!G !! Nil }

  method allowed   { $!R ⊎ $!P ⊎ $!U }
  method available { self.allowed.kxxv }
  
  method display {
    my $div='_' x 40;
    my $out=qq:to/END/;
      $div                            
      Unused:     { self.unused.sort(&board_sort)    } ({$!U.total} cubes)
      Required:   { self.required.sort(&board_sort)  } ({$!R.total} cubes)
      Permitted:  { self.permitted.sort(&board_sort) } ({$!P.total} cubes)
      Forbidden:  { self.forbidden.sort(&board_sort) } ({$!F.total} cubes)
      Goal:       { $!G } { self.goal.defined ?? '' !! '(not yet set)' }
      $div
    END
    return $out;
  }
  
  method !move(Str $cube, BagHash $from_bag is rw, BagHash $to_bag is rw) {
    quit "$cube not available to move" unless $from_bag{$cube}>0;
    $from_bag{$cube}--;
    $to_bag{$cube}++;
    self;
  }
  method move_to_required(Str $cube)  { self!move($cube,$!U,$!R) }
  method move_to_permitted(Str $cube) { self!move($cube,$!U,$!P) }
  method move_to_forbidden(Str $cube) { self!move($cube,$!U,$!F) }

  method move_to_goal(Str $cubes) {  
    for $cubes.comb -> $g { die "$g not available for goal for this Board\n{self.display}" unless $!U{$g} > 0; $!U{$g}-- }
    $!G=$cubes;
    self;
  }

  method install_goal($goal) { $!G=$goal; self }

  method !req_tuples(@c,&r) {
    my $bag=self.required.grep(&r).Bag;      # should this be $!R.list... or self.required...?
    @c.grep( Bag.new(*) (>=) $bag );
  }
  method req_num_tuples(@c) { self!req_tuples(@c,&digit) }
  method req_ops_tuples(@c) { self!req_tuples(@c,&op)    }

  method !cube_count(BagHash $B, &r) { $B.kxxv.grep(&r).elems }
  method !req_cube_count(&r) { self!cube_count($!R,&r) }
  method !all_cube_count(&r) { self!cube_count(self.allowed.BagHash,&r) }
  
  method n_req_ops { self!req_cube_count(&op) }
  method n_req_num { self!req_cube_count(&digit) }
  method n_all_ops { self!all_cube_count(&op) }
  method n_all_num { self!all_cube_count(&digit) }

  method equation_feasible { (self.n_req_ops < self.n_all_num) and (self.n_req_num <= self.n_all_ops + 1) }

  method goal_options( $max_digits=3 ) {                               
    my $digit_bag=self.available.grep(/<digit>/).Bag;                  
    my @goal_options=$digit_bag.pairs.grep( *.value==1 ).map( *.key ); 
    for 2..$max_digits -> $k {                                         
      last if $k>$digit_bag.total;
      msg "for $k cube goals, taking permutations of {$digit_bag.kxxv}" if debug 'goal options';
      my @p=variations( $digit_bag.kxxv, $k );
      msg "  adding these goal options: {@p}" if debug 'goal options';
      @goal_options.push( |@p.unique(:as( *.join('') )).map( *.join('') ).grep( none /^0\d+/ ) );
      msg "  new list of goal options:  {@goal_options}" if debug 'goal options';
    }
    @goal_options;   
  }

}  # end of class declaration

# non-member subs related to Board

multi sub board( BagHash $U  ) is export { Board.new( :$U                               ) }
multi sub board( Bag $B      ) is export { Board.new( U=>$B.BagHash                     ) }
multi sub board( Seq $cubes  ) is export { Board.new( U=>BagHash.new($[$cubes])         ) }
multi sub board( Str $cubes  ) is export { Board.new( U=>BagHash.new($cubes.comb(/\S/)) ) }
multi sub board( List $cubes ) is export { Board.new( $cubes.join('')                   ) }

=begin pod

=head1 NAME

Board.pm - Operate on Board

=head1 DESCRIPTION

  Board Components:
     * Unused cubes
     * Required cubes
     * Permitted cubes
     * Forbidden cubes
     * Goal

  The functions a Board needs to be able to do are:
     * move a cube from unused to one of the other sections
     * board display
     * decide whether goal is achievable

  Also, put the Calculation Engine here, which can be used by the 
  Computer.

=head2 Object Data

  * U - BagHash of Unused cubes
  * R - BagHash of Required cubes
  * P - BagHash of Permitted cubes
  * F - BagHash of Forbidden cubes

  * G - goal (number)

  * S - hash of Solutions where key=rpn display string, with value=rpn value (***moved to Player***)

=head2 Constructors

  * new(List) - Creates a new board using cubes in a List argument

=head2 Accessors

  * solutions()       - return a reference to the 'S' Solutions hash (should be a copy, or a true accessor fn) (***moved to Player***)

=head2 Mutators

Each of these Mutators return a reference to self to allow chaining

  * move(cube,from,to) - primarily access via synonym functions (below); move a cube
                         from the "from" bag (an element of self) to the "to" bag
  * move_to_required(cube) - move a cube from the Unused bag to the Required bag
  * move_to_permitted(cube) - move a cube from the Unused bag to the Permitted bag
  * move_to_forbidden(cube) - move a cube from the Unused bag to the Forbidden bag

  * clear_solutions() - reset the cache to an empty hash (***moved to Player***)

=end pod

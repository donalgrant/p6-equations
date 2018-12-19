use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

use lib ".";
use Globals;
use RPN;

class Board {

  has BagHash $.U is required;   # Unused cubes
  has BagHash $.R;   # Required cubes
  has BagHash $.P;   # Permitted cubes
  has BagHash $.F;   # Forbidden cubes
  
  has Str $.G='';        # goal (string of cubes)
  has Numeric %.S{Str};  # solutions (keys are rpn strings, values are numeric for RPN)

  multi method new( BagHash $U ) { note "Board from BagHash {$U.kxxv.join(',')}"; self.bless(:$U) }
  multi method new( Bag $B     ) { note "Board from Bag {$B.kxxv.join(',')}";     my $U=$B.BagHash;                     Board.new(:$U) }
  multi method new( Seq $cubes ) { note "Board from Seq {$cubes.join(',')}";     my $U=BagHash.new($[$cubes]);         Board.new(:$U) }
  multi method new( Str $cubes ) { note "Board from Str $cubes";     my $U=BagHash.new($cubes.comb(/\S/)); note "U will be {$U.kxxv.join(',')}"; Board.new(:$U) }
  multi method new( List $cubes) { note "Board from List {$cubes.join(',')}";    my $U=BagHash.new($cubes);            Board.new(:$U) }
  
  submethod TWEAK() { self.clear_solutions; $!R=BagHash.new; $!P=BagHash.new; $!F=BagHash.new }
  
  method clear_solutions { %!S=(); self }

  method save_solution (RPN $rpn) {
    my $v=+$rpn;
    %!S{~$rpn}=$v if $v.defined && self.goal==$v;
  }
  
  method required  { $!R.kxxv }
  method permitted { $!P.kxxv }
  method forbidden { $!F.kxxv }
  method unused    { $!U.kxxv }

  method goal      { +$!G // Nil }

  method available  { ($!R (+) $!P (+) $!U).kxxv }
  
  method display {
    my $div='_' x 40;
    my $out=qq:to/END/;
      $div                            
      Unused:     { self.unused.sort } ({$!U.total} cubes)
      Required:   { self.required.sort } ({$!R.total} cubes)
      Permitted:  { self.permitted.sort } ({$!P.total} cubes)
      Forbidden:  { self.forbidden.sort } ({$!F.total} cubes)
      Goal:       { self.goal }
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
    for $cubes.comb -> $g { die "$g not available for goal" unless $!U{$g} > 0; $!U{$g}-- }
    $!G=$cubes;
    self;
  }

  method install_goal($goal) { $!G=$goal; self }

  method solution_list { %!S.keys.grep({ %!S{$_}.defined }).map({ RPN.new($_) }) }

  method !req_tuples(@c,&r) {
    my $bag=$!R.list.grep(&r).Bag;
    @c.grep( Bag.new(*) (>=) $bag );
  }
  method req_num_tuples(@c) { self!req_tuples(@c,&digit) }
  method req_ops_tuples(@c) { self!req_tuples(@c,&op)    }

  method goal_options( $max_digits=3 ) {                               
    my $digit_bag=self.available.grep(/<digit>/).Bag;                  
    my @goal_options=$digit_bag.pairs.grep( *.value==1 ).map( *.key ); 
    for 2..$max_digits -> $k {                                         
      last if $k>$digit_bag.total;
      my @p=tuples( $digit_bag.kxxv, $k );                             
      @goal_options.push( |@p.unique(:as( *.join('') )).map( *.join('') ).grep( none /^0\d+/ ) );
    }
    @goal_options;   
  }

  method calculate_solutions($ncubes) {  # ncubes is maximum number of cubes to use
#    note "calculate_solutions for ncubes=$ncubes";
    die "Goal must be set before calculating solutions" unless $!G.chars > 0;
    die "Number of cubes in a solution must be odd!" if $ncubes %% 2;
    my Bag $bag  = self.available.Bag;
    my Bag $num .= new( $bag.kxxv.grep(/<digit>/) ); 
    my Bag $ops .= new( $bag.kxxv.grep(/ <op>  /) );
    my $nops=min($ops.total,$num.total-1,floor($ncubes/2));
    my $nnum=min($nops+1,$num.total,$ncubes-$nops);
#    note "nops=$nops; nnum=$nnum";
    return self unless $nops>=1 && $nnum>=2;
    my @pn=get_tuples $nnum, $num, Bag.new( $!R.kxxv.grep(/<digit>/) );
    my @po=get_tuples $nops, $ops, Bag.new( $!R.kxxv.grep(/ <op>  /) );
    my @ops_slots=ops_slots($nops);
#    note "pn=[{@pn.map({ $_.join(',') }).join('],[')}]";
#    note "po=[{@po.map({ $_.join(',') }).join('],[')}]";
#    note "ops_slots={@ops_slots.join(',')}";
    my $max_solutions=200000;
    my $n_solutions= @pn * @po * @ops_slots;    # numeric context -- product of array sizes
#    note "n_solutions=$n_solutions";
    die "issue with get_tuples? pn={@pn}, po={@po}; ops_slots={@ops_slots}" unless $n_solutions>0;
    if ($n_solutions>$max_solutions) {
      my $reduce_factor=min( 4.0, ($n_solutions/$max_solutions)**(1.0/3.0) ); 
      my $nsl=max( 3, (+@ops_slots/$reduce_factor).floor ); 
      my $max_tuples=sqrt($max_solutions/@ops_slots).floor;
      my $npn=$max_tuples;
      my $npo=$max_tuples;
      @pn       =choose_n $npn, @pn;
      @po       =choose_n $npo, @po;
      @ops_slots=choose_n $nsl, @ops_slots;
      $n_solutions= @pn * @po* @ops_slots;
    }
    my $i=0;
    for @pn -> $pn {
      for @po -> $po {
        for @ops_slots -> $slot {  # now construct this RPN
# note "constructing RPN for pn={$pn.join(',')}; po={$po.join(',')}; slot=$slot";
	  my ($ipn,$ipo)=(0,0);
	  my $x=$pn[$ipn++];
	  for $slot.comb -> $s {
	    $x~=$pn[$ipn++];
	    $x~=$po[$ipo++] for (1..$s);
	  }
#	  note "creating RPN from $x";
	  my $rpn=RPN.new($x);
# note "RPN=$rpn with value {+$rpn}";	  
	  self.save_solution($rpn);
	}
      }
    }
    self;
  }
}  # end of class declaration

sub ops_slots($n) is export {
  return ['1'] if $n==1;
  return ['11','02'] if $n==2;
  my @options=['0', '1'];
  for 2..$n-1 -> $slot {
    my @new_options;
    for @options -> $this_option {
      my $naccum=$slot - $this_option.comb.join('+').EVAL;
      my @accum_options;
      for 0..$naccum -> $n_in_slot {
	@accum_options.push("$this_option$n_in_slot");
      }
      @new_options.push(|@accum_options);
    }
    @options=@new_options;
  }
  @options.map( { $_~($n-$_.comb.join('+').EVAL) } );
}

sub unique_tuples(@a) { @a.unique(:as( *.join('') )) }

# generate the list of tuples of length $n from Bag $src while enforcing use of all in Bag $req

sub get_tuples($n,Bag $src,Bag $req) { 
  return () unless $src (>=) $req;
  my $remain=($src (-) $req).BagHash;  
  my @req_list=$req.kxxv;
#  note "$n vs {+@req_list} will generate combinations {[combinations( $[ $remain.kxxv ], $n - @req_list )].join(',')}";
  # this is tricky -- combinations will return an array of arrays unless there is only a single combination, in which case it's just an array
  my @comb = $[ $req.kxxv ];
  if ($n > @req_list) {
    my @temp=[combinations( $[ $remain.kxxv ], $n - @req_list ) ];   # note "temp={@temp.join(',')}"; note "type of [0] is {@temp[0].^name}";
 #   note "truth of temp[0] ~~ /Array/:  {so @temp[0].^name ~~ /Array/}";
    if (@temp[0].^name~~/Array/) {  # array of arrays
      @comb=unique_tuples @temp.map({ Array.new.append(|@req_list,|$_) }); #  note "array of arrays";
    } else { # just an array
      @comb[0]=Array.new.append(|@req_list,|@temp);  # note "just an array; comb=[{@comb.map({ $_.join(',') }).join('],[')}]";
    }
  }
  # now for each element of @comb, generate all the permutations and add to the total list
#  note "number of combinations is {@comb.elems}; comb=[{@comb.map({ $_.join(',') }).join('],[')}]";
#  note "will return [{ unique_tuples( @comb.map({ permutations($[ |$_ ]) }).flat ).map({ $_.join(',') }).join('],[') }]";
  unique_tuples( @comb.map({ permutations($[ |$_ ]) }).flat );
}
	       
sub choose_n($n,@c) {
  return @c if $n>=@c.elems;
  for 0..$n-1 { @c[$_,($_+1..@c.end).pick].=reverse }
  @c[0..$n-1];
}


sub filter_solutions_usable(  @h, Bag $b) is export { @h.grep({ $_.comb.Bag (<=) $b }) }
sub filter_solutions_required(@h, Bag $b) is export { @h.grep({ $_.comb.Bag (>=) $b }) }

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

  * S - hash of Solutions where key=rpn display string, with value=rpn value

=head2 Constructors

  * new(List) - Creates a new board (resetting the %SOLUTIONS cache) using cubes in a List argument

=head2 Accessors

  * solutions()       - return a reference to the 'S' Solutions hash (should be a copy, or a true accessor fn)

=head2 Mutators

Each of these Mutators return a reference to self to allow chaining

  * move(cube,from,to) - primarily access via synonym functions (below); move a cube
                         from the "from" bag (an element of self) to the "to" bag
  * move_to_required(cube) - move a cube from the Unused bag to the Required bag
  * move_to_permitted(cube) - move a cube from the Unused bag to the Permitted bag
  * move_to_forbidden(cube) - move a cube from the Unused bag to the Forbidden bag

  * clear_solutions() - reset the cache to an empty hash

=end pod

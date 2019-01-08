use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

use lib ".";
use Globals;
use RPN;
use Board;

class Board_Solver {
  
  has Board $.B;
  has Numeric %.S{Str}=();  # solutions (keys are rpn strings, values are numeric for RPN)

  method new(Board $B) { self.bless(:$B) }
  
  method clear_solutions          { %!S        = ();    self }
  method !save_solution(RPN $rpn) { %!S{~$rpn} = +$rpn; self }
  method solution_list            { %!S.keys.grep({ %!S{$_}.defined }).map({ RPN.new($_) }) }
  method solution_found           { %!S.elems>0 }

  method !solution_cubes(@cubes,&min_max) {       
    my Bag $num .= new( @cubes.grep(/<digit>/) ); 
    my Bag $ops .= new( @cubes.grep(/ <op>  /) ); 
    my $nops=&min_max($ops.total,$num.total-1);
    return 2*$nops+1;
  }
  method min_solution_cubes { self!solution_cubes($!B.required, &max) }
  method max_solution_cubes { self!solution_cubes($!B.available,&min) }

  method valid_solution(    RPN $rpn ) { return +$rpn == $!B.goal }
  method doable_solution(   RPN $rpn ) { my $b=$rpn.Bag; ( $b (<=) ( $!B.allowed ) ) and ( ($!B.R) (<=) $b ) }
  method on-board_solution( RPN $rpn ) { my $b=$rpn.Bag; ( $b (<=) ( $!B.R (+) $!B.P ) ) and ( $b (>=) $!B.R ) }

  # consolidate the following two with an internal method
  
  # bag of cubes in RPN which are not available anywhere on the board
  method cubes-missing_for( RPN $rpn ) {
    my BagHash $b=$rpn.BagHash; 
    my BagHash $a=$!B.allowed.BagHash;
    for $b.kxxv { if ($a{$_} > 0) { $a{$_}--; $b{$_}-- } }
    return $b;
  }

  # bag of cubes in required which don't appear in the RPN
  method req-not-in( RPN $rpn ) {
    my BagHash $b=$rpn.BagHash;
    my BagHash $r=$!B.R.clone;
    for $r.kxxv { if ($b{$_} > 0) { $b{$_}--; $r{$_}-- } }
    return $r;
  }
  
  # Bag of RPN cubes not yet in required and in unused
  method cubes-to-go_for(   RPN $rpn ) {
    my $b=$rpn.Bag;
    return Nil unless $b (>=) $!B.R;       # won't work if requireds aren't part of rpn
    my BagHash $g=($b (-) $!B.R).BagHash;  # subtract of cubes already in req'd
    my BagHash $p=$!B.P.clone;             # copy of permitted cubes
    for $g.kxxv -> $cube { if ($p{$cube}>0) { $g{$cube}--; $p{$cube}-- } }  # use permitteds as avail
    return $g;
  }  
  
  # is this RPN one cube unused cube away from a solution?  if so, return that cube
  method go-out_check( RPN $rpn )    {
    my $b=$rpn.Bag;
    my $g=self.cubes-to-go_for($rpn);
    return Nil unless $g.total < 2;
    return '' if $g.total==0;  # should have been caught by a on-board_solution!
    # should be one key left -- check if in unused
    my ($cube)=$g.keys;
    return $cube if $cube (elem) $!B.U;
    return Nil;
  }
  
  method calculate_solutions($ncubes,:$max_solutions=50000) {  # ncubes is maximum number of cubes to use
    note "calculate_solutions for ncubes=$ncubes";
    die "Goal must be set before calculating solutions" unless $!B.goal;
    die "Number of cubes in a solution must be odd!" if $ncubes %% 2;
    my Bag $bag .= new( $!B.available );
    my Bag $num .= new( $bag.kxxv.grep(/<digit>/) );  # note "Digits are {$num.kxxv}";
    my Bag $ops .= new( $bag.kxxv.grep(/ <op>  /) );  # note "Ops    are {$ops.kxxv}";
    my $nops=min($ops.total,$num.total-1,floor($ncubes/2));
    my $nnum=min($nops+1,$num.total,$ncubes-$nops);
#    note "nops=$nops; nnum=$nnum";
    return Nil unless $nops>=1 && $nnum>=2; 
    my @pn=get_tuples $nnum, $num, Bag.new( $!B.required.grep(/<digit>/) );
    my @po=get_tuples $nops, $ops, Bag.new( $!B.required.grep(/ <op>  /) );
    my @ops_slots=ops_slots($nops);
#    note "pn=[{@pn.map({ $_.join(',') }).join('],[')}]";
#    note "po=[{@po.map({ $_.join(',') }).join('],[')}]";
#    note "ops_slots={@ops_slots.join(',')}";
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
      note "after sub-select, n_solutions=$n_solutions";
    }
    my $i=0;
    for @pn -> $pn {  # note "working with pn={$pn.join(',')}";
      for @po -> $po { # note "working with po={$po.join(',')}";
        for @ops_slots -> $slot {  # now construct this RPN
#	  note "constructing RPN for pn={$pn.join(',')}; po={$po.join(',')}; slot=$slot";
	  my ($ipn,$ipo)=(0,0);
	  my $x=$pn[$ipn++];
	  for $slot.comb -> $s { #  note "inner block:  s=$s, x=$x, ipn=$ipn, ipo=$ipo, pn={$pn.join(',')}, po={$po.join(',')}";
	    $x~=$pn[$ipn++];
	    $x~=$po[$ipo++] for (1..$s);
	  }
#	  note "creating RPN from $x";
	  my $rpn=RPN.new($x);
	  if ($rpn.defined) {
#	    note "RPN=$x with value {+$rpn}";	  
	    self!save_solution($rpn) if $rpn==$!B.goal;
	  } # else { note "$x leads to undefined RPN" }
	}
      }
    }
    self;
  }
}

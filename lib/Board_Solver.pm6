use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

use Globals;
use RPN;
use Board;
use Solutions;

class Board_Solver does Solutions {
  
  has Board $.B;

  method new(Board $B) { self.bless(:$B) }
  
  method !solution_cubes(@cubes,&min_max) {       
    my Bag $num .= new( @cubes.grep(/<digit>/) ); 
    my Bag $ops .= new( @cubes.grep(/ <op>  /) ); 
    my $nops=&min_max($ops.total,$num.total-1);
    return 2*$nops+1;
  }
  method min_solution_cubes { self!solution_cubes($!B.required, &max) }
  method max_solution_cubes { self!solution_cubes($!B.available,&min) }

  method valid_solution(    RPN $rpn ) { $rpn.Numeric == $!B.goal }
  method doable_solution(   RPN $rpn ) { $rpn.formable($!B.P.Bag (+) $!B.U.Bag,$!B.R.Bag) }
  method on-board_solution( RPN $rpn ) { $rpn.formable($!B.P.Bag,              $!B.R.Bag) }
  
  # method doable_solution(   RPN $rpn ) { my $b=$rpn.Bag; ( $b (<=) ( $!B.allowed ) ) and ( ($!B.R) (<=) $b ) }
  # method on-board_solution( RPN $rpn ) { my $b=$rpn.Bag; ( $b (<=) ( $!B.R (+) $!B.P ) ) and ( $b (>=) $!B.R ) }

  method cubes-missing_for( RPN $rpn ) { $rpn.cubes-to-go($!B.allowed.Bag)     }  # rpn cubes which are not available anywhere (including unused)
  method cubes-to-go_for(   RPN $rpn ) { $rpn.cubes-to-go($!B.P.Bag,$!B.R.Bag) }  # rpn cubes not yet in required and in permitted
  method req-not-in(        RPN $rpn ) { $rpn.req-missing($!B.R.Bag)           }  # rpn cubes in required which don't appear in the RPN
  
  # is this RPN one cube unused cube away from a solution?  if so, return that cube
  method go-out_check( RPN $rpn )    {
    my $g=self.cubes-to-go_for($rpn);
    return Nil unless $g.total < 2;
    return '' if $g.total==0;  # should have been caught by a on-board_solution!
    my ($cube)=$g.keys;
    ( $cube ∈ $!B.U ) ?? $cube !! Nil;
  }

  method solve(:$min_cubes=1,:$max_cubes=5,:$max_solutions=20000,:$quit_on_found=True) {
    for $min_cubes, {$_+2}...$max_cubes -> $n {
      self.calculate_solutions($n,:$max_solutions);
      msg "in solve after calculate with n=$n; solutions {self.list.join('; ')}" if debug;
      return self if $quit_on_found and self.found;
    }
    self;
  }
  
  method calculate_solutions($ncubes,:$max_solutions=20000) {  # ncubes is maximum number of cubes to use
    msg "calculate_solutions for ncubes=$ncubes" if debug('calc');
    die "Goal must be set before calculating solutions" unless $!B.goal;
    die "Number of cubes in a solution must be odd!" if $ncubes %% 2;
    return self unless $!B.equation_feasible;
    my Bag $num = num_bag($!B.allowed.Bag);
    my Bag $ops = ops_bag($!B.allowed.Bag);
    msg "allowed num={$num.kxxv.join(',')}, ops={$ops.kxxv.join(',')}" if debug;
    if ($ncubes==1) { self.save(~$!B.goal) if $!B.goal (elem) $num; return self }
    my $nops=min($ops.total,$num.total-1,floor($ncubes/2));
    my $nnum=min($nops+1,$num.total,$ncubes-$nops);
    msg "nops=$nops; nnum=$nnum" if debug;
    return Nil unless $nops>=1 && $nnum>=2;
    return Nil if num_bag($!B.R.Bag).total > $nnum;
    return Nil if ops_bag($!B.R.Bag).total > $nops;
    my @pn=get_tuples $nnum, $num, num_bag($!B.R.Bag);
    my @po=get_tuples $nops, $ops, ops_bag($!B.R.Bag);
    my @ops_slots=ops_slots($nops);
    msg "pn=[{@pn.map({ $_.join(',') }).join('],[')}]" if debug;
    msg "po=[{@po.map({ $_.join(',') }).join('],[')}]" if debug;
    msg "ops_slots={@ops_slots.join(',')}" if debug;
    my $n_solutions= @pn * @po * @ops_slots;    # numeric context -- product of array sizes
    msg "n_solutions=$n_solutions" if debug;
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
      msg "after sub-select, n_solutions=$n_solutions" if debug;
    }
    my $i=0;
    for @pn -> $pn {  
      for @po -> $po { 
        for @ops_slots -> $slot {  # now construct this RPN
	  my RPN $rpn .= new(num-ops-slot($pn,$po,$slot));  # could be undefined ('10/', etc)
	  self.save($rpn) if $rpn.defined and +$rpn==$!B.goal;
	  msg "{num-ops-slot($pn,$po,$slot)} at count=$i / $n_solutions" if debug('count') and ++$i %% 5000;
	}
      }
    }
    self;
  }
}

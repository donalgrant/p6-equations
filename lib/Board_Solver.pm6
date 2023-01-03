use v6;

# use Algorithm::Combinatorics:from<Perl5> qw<tuples combinations permutations>;

use Globals;
use Tuples;
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

  method solve(:$min_cubes=1,:$max_cubes=9,:$max_solutions=20000,:$quit_on_found=True) {
    my $start_cubes=max($min_cubes,self.min_solution_cubes);
    my $end_cubes=min($max_cubes,self.max_solution_cubes);
    return self if $end_cubes < $start_cubes;
    msg "solve for goal {$!B.goal} from $start_cubes to $end_cubes" if debug 'solve';
    for $start_cubes, {$_+2}...$end_cubes -> $n {
      self.calculate_solutions($n,:$max_solutions);
      msg "in solve after calculate with n=$n; solutions {self.list.join('; ')}" if debug 'solve';
      return self if $quit_on_found and self.found;
    }
    self;
  }
  
  method calculate_solutions($ncubes,:$max_solutions=50000) {  # ncubes is maximum number of cubes to use
    msg "calculate_solutions for ncubes=$ncubes" if debug('calc');
    die "Goal must be set before calculating solutions" unless $!B.goal.defined;
    die "Number of cubes in a solution must be odd!" if $ncubes %% 2;
    return self unless $!B.equation_feasible;
    msg "allowed={$!B.allowed.Bag.kxxv.join(',')}" if debug 'calc';
    my Bag $num = num_bag($!B.allowed.Bag);
    my Bag $ops = ops_bag($!B.allowed.Bag);
    msg "allowed num={$num.kxxv.join(',')}, ops={$ops.kxxv.join(',')}" if debug 'calc';
    if ($ncubes==1) { self.save(~$!B.goal) if $!B.goal (elem) $num; return self }
    my $nops=min($ops.total,$num.total-1,floor($ncubes/2));
    my $nnum=min($nops+1,$num.total,$ncubes-$nops);
    msg "nops=$nops; nnum=$nnum" if debug 'calc';
    return Nil unless $nops>=1 && $nnum>=2;
    return Nil if num_bag($!B.R.Bag).total > $nnum;
    return Nil if ops_bag($!B.R.Bag).total > $nops;
    my @pn=get_tuples $nnum, $num, num_bag($!B.R.Bag);
    my @po=get_tuples $nops, $ops, ops_bag($!B.R.Bag);
    my @ops_slots=ops_slots($nops);
    msg "pn={@pn.raku}" if debug 'calc variations';
    msg "po={@po.raku}" if debug 'calc variations';
    msg "ops_slots={@ops_slots}" if debug 'calc variations';
    my $n_solutions= @pn * @po * @ops_slots;    # numeric context -- product of array sizes
    msg "n_solutions=$n_solutions" if debug 'calc';
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
      $n_solutions= @pn * @po * @ops_slots;
      msg "after sub-select, n_solutions=$n_solutions" if debug 'calc';
    }
    my $i=0;
    for @pn -> $pn {  
      for @po -> $po { 
        for @ops_slots -> $slot {  # now construct this RPN
	  msg "constructing rpn from $pn, $po, $slot" if debug 'calc-every-rpn';
	  my RPN $rpn .= new(num-ops-slot($pn,$po,$slot));  # could be undefined ('10/', etc)
	  self.save($rpn) if $rpn.defined and +$rpn==$!B.goal;
	  msg "{num-ops-slot($pn,$po,$slot)} at count=$i / $n_solutions" if debug('calc') and ++$i %% 5000;
	}
      }
    }
    self;
  }

  method find_goal(Int :$max_digits=2) { find_goal($!B, :$max_digits) }
}

# non class functions related to Board Solving

sub board_solver(Board $B) is export { return Board_Solver.new($B) }

sub find_goal(Board $B, Int :$max_digits=2) is export {
  my @go=$B.goal_options($max_digits);
  msg "goal options are: {@go}" if debug 'goal_options';
  for shuffle(@go) -> $g {
    msg "find_goal -- trying $g" if debug 'find_goal';
    return $g if board_solver(board($B.U.clone).move_to_goal($g)).solve.found;
  }
  return Nil;
}
  
# required cubes are for entire new $rpn, which will actually be the cubes in
#   $rpn - $rpn_extract + $arg1 + $_ from solution + $alt_cube
#   so the req cubes which need to be in $_ from solution are the ones which are
#   not in the rest of it, namely, $req (-) ($rpn-$rpn_extract+$arg1+alt_cube)

sub replace_op(BagHash $excess, BagHash $req, $cube, $alt_cube, $rpn, &goal_fn, :$swap=False, :$exp=False) {
  msg "try_replace on $rpn for $cube with $alt_cube vs. {$excess.kxxv.join(',')} and req {$req.kxxv.join(',')}" if debug 'replace_op';
  for 0..Inf -> $nskip {
    my $rpn_extract=$rpn.rpn_at_op($cube,$nskip);
    last unless $rpn_extract.defined;
    msg "rpn=$rpn; nskip=$nskip; rpn_extract=$rpn_extract" if debug 'replace_op';
    my ($arg1,$arg2,$op)=decompose_rpn(rpn_at_op($rpn_extract,$cube,$nskip));
    msg "after decompose, arg1=$arg1, arg2=$arg2, op=$op" if debug 'replace_op';
    ($arg1,$arg2).=reverse if $swap;
    last if rpn_value($arg2)==0 and abs(&goal_fn('2')) < 1.0;  # trap divide-by-zero
    my $e=$excess ⊎ rpn($arg2).Bag;
    next unless $alt_cube ∈ $e;
    my $used_cubes=($rpn.Bag ∖ rpn($rpn_extract).Bag) ⊎ rpn($arg1).Bag ⊎ Bag.new($alt_cube);
    my $r=($req ∖ $used_cubes) // Bag.new;  # make sure $r is defined
    for board_solver(Board.new(
			    U=>$e.BagHash,R=>$r.BagHash,G=>(&goal_fn($arg2)).Str
			  ).move_to_forbidden($alt_cube)
			).solve(min_cubes=>3,max_cubes=>7,max_solutions=>10000).list
    { take $rpn.Str.subst($rpn_extract.Str,($exp ?? $_~$arg1 !! $arg1~$_)~$alt_cube) }
  }
}

sub replace_digit(BagHash $excess, $cube, $rpn) {
  for board_solver(Board.new(U=>$excess,G=>$cube)).solve(min_cubes=>3).list -> $r {
    next if $cube ∈ rpn($r).Bag;     # don't replace with the same cube!
    my $new-rpn=$rpn.Str;            # need a mutable copy
    take $new-rpn.=subst($cube,$r);  # create a new RPN by replacing in the original rpn
  }
}

my %Replacement_Cache;
sub replacement_hash($RB,$c,$BH) { $RB~':'~$c~':'~$BH }

sub find_replacement(Board $B, BagHash $missing, RPN $rpn) is export {
  my $rb=$rpn.Bag;
  return [] unless $B.R ⊆ $rb;   # must be able to use all required cubes
  return [] if $missing.total > 1;    # only replace one cube (for now)
  my $cube=$missing.pick;
  my $excess=($B.allowed ∖ ($rb ∖ $missing)).BagHash;
  my $h=replacement_hash($rpn,$cube,$excess);
  my @R;
  if (not %Replacement_Cache{$h}.defined) {
    msg "find a replacement for $cube in $rpn using excess {$excess.kxxv.join(',')}" if debug 'find_replacement';
    given $cube {
      when /<digit>/ { @R = gather replace_digit($excess,$cube,$rpn) }
      when /<[+]>/   { @R = gather { replace_op($excess,$B.R,'+','-',$rpn,{  '-'~rpn_value($^a) },swap=>$_) for (False,True) } }
      when /<[*]>/   { @R = gather { replace_op($excess,$B.R,'*','/',$rpn,{ '1/'~rpn_value($^a) },swap=>$_) for (False,True) } }
      when /<[^]>/   { @R = gather { replace_op($excess,$B.R,'^','@',$rpn,{ '1/'~rpn_value($^a) },exp=>True ) } }
      when /<[@]>/   { @R = gather { replace_op($excess,$B.R,'@','^',$rpn,{ '1/'~rpn_value($^a) },swap=>True) } }
      when /<[-/]>/  { @R = [] }
    }
    %Replacement_Cache{$h}=@R;
  } else { msg "will use cached replacement {%Replacement_Cache{$h}.flat.join('; ')}" if debug 'find_replacement' }
  return %Replacement_Cache{$h}.flat;
}

my %goal-for;
%goal-for{$_}='1' for qw{ / * ^ @ };
%goal-for{$_}='0' for qw{ + - };

multi sub expand-list(BagHash $e, $f-cube, $r-cube)
{ board_solver(Board.new(U=>$e.clone,G=>%goal-for{$f-cube}).move_to_forbidden($f-cube).move_to_required($r-cube)).solve.list }

multi sub expand-list(BagHash $e, $f-cube)
{ board_solver(Board.new(U=>$e.clone,G=>%goal-for{$f-cube}).move_to_forbidden($f-cube)).solve.list }

my %Expansion_Cache;
sub expansion_hash($RB,$c,$BH) { $RB~':'~$c~':'~$BH }

sub find_expansion(Board $B, BagHash $req, BagHash $excess, RPN $rpn) is export {
  return [] unless $req.total==1;  # only handling single newly req cube (for now)
  my $cube=$req.pick;
  msg "single cube $cube newly required with excess {$excess.kxxv.join(',')}" if debug;
  my $h=expansion_hash($rpn,$cube,$excess);
  if (not %Expansion_Cache{$h}.defined) {
    my @m_ops-excess=qw{ / * ^ + - }.grep(* ∈ $excess);  
    my @s_ops-excess=qw{     @     }.grep(* ∈ $excess);
    my @R = gather {
      given $cube {
	when /<[*/^+-]>/ { expand-list($excess,$cube).map({ take "$rpn$_$cube" }) }
	when /  <[@]>  / { expand-list($excess,$cube).map({ take "$_$rpn$cube" }) }
	when / <digit> / { 
	  for @s_ops-excess -> $op { expand-list($excess,$op,$cube).map({ take "$_$rpn$op" }) }
	  for @m_ops-excess -> $op { expand-list($excess,$op,$cube).map({ take "$rpn$_$op" }) }
	}
      }
    }
    %Expansion_Cache{$h}=@R;
  } else { msg "will use cached expansion {%Expansion_Cache{$h}.flat.join('; ')}" if debug }
  return %Expansion_Cache{$h}.flat;
}

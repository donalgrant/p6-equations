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

# non class functions related to Board Solving

sub replace_op(BagHash $excess, BagHash $req, $cube, $alt_cube, $rpn, &goal_fn, :$swap=False) {
  msg "###\n#####\n####try_replace on $rpn for $cube with $alt_cube vs. {$excess.kxxv.join(',')} and req {$req.kxxv.join(',')}" if debug;
  for 0..Inf -> $nskip {
    msg "for nskip=$nskip:" if debug;
    my $rpn_extract=$rpn.rpn_at_op($cube,$nskip);
    last unless $rpn_extract.defined;
    my ($arg1,$arg2,$op)=decompose_rpn(rpn_at_op($rpn_extract,$cube,$nskip));
    msg "for $rpn_extract:   arg1=$arg1, arg2=$arg2, op=$op" if debug;
    ($arg1,$arg2).=reverse if $swap;
    msg "after swap ($swap): arg1=$arg1, arg2=$arg2" if debug;
    msg "divide-by-zero test value:  {abs(&goal_fn('2'))}";
    last if rpn_value($arg2)==0 and abs(&goal_fn('2')) < 1.0;  # trap divide-by-zero
    msg "survived divide-by-zero" if debug;
    my $e=$excess ⊎ rpn($arg2).Bag;
    # required cubes are for entire new $rpn, which will actually be the cubes in
    #   $rpn - $rpn_extract + $arg1 + $_ from solution + $alt_cube
    #   so the req cubes which need to be in $_ from solution are the ones which are
    #   not in the rest of it, namely, $req (-) ($rpn-$rpn_extract+$arg1+alt_cube)
    my $used_cubes=($rpn.Bag ∖ rpn($rpn_extract).Bag) ⊎ rpn($arg1).Bag ⊎ Bag.new($alt_cube);
    msg "rpn-rpn_extract = {($rpn.Bag ∖ rpn($rpn_extract).Bag).kxxv.join(',')}" if debug;
    msg "arg1 + alt_cube = {(rpn($arg1.Str).Bag ⊎ Bag.new($alt_cube)).kxxv.join(',')}" if debug;
    my $r=($req ∖ $used_cubes) // Bag.new;  # make sure $r is defined
    msg "for this try: reserved={$used_cubes.kxxv.join(',')}, req will be {$r.kxxv.join(',')}" if debug;
    msg "Test '$alt_cube' is in modified excess {$e.kxxv.join(',')} ? {$alt_cube ∈ $e}" if debug;
    next unless $alt_cube ∈ $e;
    my $B=Board.new(U=>$e.BagHash,R=>$r.BagHash,G=>(&goal_fn($arg2)).Str).move_to_forbidden($alt_cube);
    msg "  try to solve board:\n{$B.display}";
    my $BS=Board_Solver.new($B).solve(min_cubes=>3,max_cubes=>7,max_solutions=>10000);
    msg "solutions to board are {$BS.list.map({ $rpn.Str.subst($rpn_extract.Str,$arg1~$_~$alt_cube) }).join('; ')}" if debug;
    for $BS.list { take $rpn.Str.subst($rpn_extract.Str,$arg1~$_~$alt_cube) }
  }
}

sub try_replace_exp(BagHash $excess, $cube, $alt_cube,$rpn, BagHash $req) {
  return unless $alt_cube (elem) $excess;
  my $nskip=0;
  loop {
    my $rpn_extract=$rpn.rpn_at_op($cube,$nskip);
    return unless $rpn_extract.defined;
    my ($arg1,$arg2,$op)=decompose_rpn($rpn.rpn_at_op($cube,$nskip));
    next if rpn_value($arg2)==0;
    Board_Solver.new(
      Board.new(U=>$excess,G=>(1/rpn_value($arg2)).Str).move_to_forbidden($alt_cube)
    ).solve.list.map({ my $n=$_~$arg1~$alt_cube; take $n if rpn($n).has($req.Bag) });
    $nskip++;
  }
}
sub try_replace_rad(BagHash $excess, $cube, $alt_cube,$rpn, BagHash $req) {
  return unless $alt_cube ∈ $excess;
  my $nskip=0;
  loop {
    my $rpn_extract=$rpn.rpn_at_op($cube,$nskip);
    return unless $rpn_extract.defined; 
    my ($arg1,$arg2,$op)=decompose_rpn($rpn.rpn_at_op($cube,$nskip));
    next if rpn_value($arg1)==0;
    Board_Solver.new(
      Board.new(U=>$excess,G=>(1/rpn_value($arg1)).Str).move_to_forbidden($alt_cube)
    ).solve.list.map({ my $n=$arg2~$_~$alt_cube; take $n if rpn($n).has($req.Bag) });
    $nskip++;
  }
}

sub replace_digit(BagHash $excess, $cube, $rpn) {
  for Board_Solver.new(Board.new(U=>$excess,G=>$cube)).solve(min_cubes=>3).list -> $r {
    next if $cube ∈ rpn($r).Bag;     # don't replace with the same cube!
    my $new-rpn=$rpn.Str;            # need a mutable copy
    take $new-rpn.=subst($cube,$r);  # create a new RPN by replacing in the original rpn
  }
}

# returns a list of replacement rpn-strings, or empty list if none found
# maybe make this whole thing a gather / take?
sub find_replacement(Board $B, BagHash $missing, RPN $rpn) is export {
  return [] unless $B.R ⊆ $rpn.Bag;   # must be able to use all required cubes
  return [] if $missing.total > 1;       # only replace one cube (for now)
  my $cube=$missing.pick;
  my $excess=($B.allowed ∖ ($rpn.Bag ∖ $missing)).BagHash;
  msg "find a replacement for $cube in $rpn using excess {$excess.kxxv.join(',')}" if debug;
  given $cube {
    when /<digit>/ { return gather replace_digit($excess,$cube,$rpn) }
    when /<[+]>/   { return gather { replace_op($excess,$B.R,'+','-',$rpn,{ -rpn_value($^a)  },swap=>$_) for (False,True) } }
    when /<[*]>/   { return gather { replace_op($excess,$B.R,'*','/',$rpn,{ 1/rpn_value($^a) },swap=>$_) for (False,True) } }
    when /<[^]>/   { msg "replacing $cube" if debug; my @g=gather try_replace_exp($excess,'^','@',$rpn,$B.R); msg "gathered {@g.join('; ')}"; return @g; }
    when /<[@]>/   { msg "replacing $cube" if debug; my @g=gather try_replace_rad($excess,'@','^',$rpn,$B.R); msg "gathered {@g.join('; ')}"; return @g; }
  }
  return [];
}

my %goal-for;
%goal-for{$_}='1' for qw{ / * ^ @ };
%goal-for{$_}='0' for qw{ + - };

multi sub expand-list(BagHash $e, $f-cube, $r-cube) { msg "expand-list 3 args with $f-cube and $r-cube" if debug;
						      Board_Solver.new(Board.new(U=>$e.clone,G=>%goal-for{$f-cube}).move_to_forbidden($f-cube).move_to_required($r-cube)).solve.list
						    }
multi sub expand-list(BagHash $e, $f-cube) { msg "expand-list 2 args with $f-cube" if debug;
					     Board_Solver.new(Board.new(U=>$e.clone,G=>%goal-for{$f-cube}).move_to_forbidden($f-cube)).solve.list
					   }

sub find_expansion(Board $B, BagHash $req, BagHash $excess, RPN $rpn) is export {
  return [] unless $req.total==1;  # only handling single newly req cube (for now)
  my $cube=$req.pick;
  msg "single cube $cube newly required with excess {$excess.kxxv.join(',')}" if debug;
  my @m_ops-excess=qw{ / * ^ + - }.grep(* ∈ $excess);  
  my @s_ops-excess=qw{     @     }.grep(* ∈ $excess);  
  return gather {
    given $cube {
      when /<[*/^+-]>/ { expand-list($excess,$cube).map({ take "$rpn$_$cube" }) }
      when /  <[@]>  / { expand-list($excess,$cube).map({ take "$_$rpn$cube" }) }
      when / <digit> / { 
	for @s_ops-excess -> $op { expand-list($excess,$op,$cube).map({ take "$_$rpn$op" }) }
	for @m_ops-excess -> $op { expand-list($excess,$op,$cube).map({ take "$rpn$_$op" }) }
      }
    }
  }
}

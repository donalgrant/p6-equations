use v6;

use Globals;

class Player {
    
  use RPN;
  use Board;
  use Board_Solver;

  has Numeric %.S{Str}=();  # solutions (keys are rpn strings, values are numeric for RPN)

  method clear_solutions         { %!S        = ();    self }
  method save_solution(RPN $rpn) { %!S{~$rpn} = +$rpn; self }
  method solution_list           { %!S.keys.grep({ %!S{$_}.defined }).map({ RPN.new($_) }) }
  method solution_found          { self.solution_list.elems > 0 }
  
  method filter_solutions( Board $B ) {
    my Board_Solver $BS .= new($B);
    for self.solution_list { %!S{~$_}:delete unless ($BS.valid_solution($_) and $BS.doable_solution($_))  }
    self;
  }
  
  method generate_solutions( Board $B ) {
    my Board_Solver $BS .= new($B);
    loop (my $rpn_length=$BS.min_solution_cubes; $rpn_length <= $BS.max_solution_cubes; $rpn_length+=2) {
      $BS.calculate_solutions($rpn_length);
      last if $BS.solution_found;
    }
    note "No solutions possible" unless $BS.solution_found;
    for $BS.solution_list -> $rpn { self.save_solution($rpn) }
  }
  
  # move to Board_Solver
  method choose_goal(Board $board, Int $max_digits=3) {
    my Board $B.= new('');  # Empty Board -- placeholder 
    # look for constructibility for each goal option
    for shuffle($board.goal_options($max_digits)) -> $g {
      $B=Board.new($board.unused.join(''));              
      $B.move_to_goal($g);  note "choose_goal -- trying $g";
      my Board_Solver $BS .= new($B);
      $BS.calculate_solutions($_) for (3,5);
      self.clear_solutions;
      for $BS.solution_list -> $rpn { self.save_solution($rpn) }
      last if self.solution_list.elems > 0;
    }
    return Nil unless self.solution_list.elems > 0;
    note "Chose a goal:  {$B.goal}";
    note "Can get this by:  {self.solution_list.join('  ')}";
    return $B.goal;
  }

  method manual(Board $B, $bonus_taken=False) {

    my ($move,$section);

    put $B.display();
    repeat { $move    = prompt "Cube:  " } until $B.unused.Bag{$move} > 0;
    repeat { $section = prompt "To (R(equired) P(ermitted) F(orbidden) B(onus) E(quation):  " }
      until $section ~~ m:i/^<[RPFEB]>/;

    given ($section.uc) {
      when ('R') {  $B.move_to_required($move) }
      when ('P') { $B.move_to_permitted($move) }
      when ('F') { $B.move_to_forbidden($move) }
      when ('B') { 
	do { say "Only one bonus per turn"; return self.manual($B,$bonus_taken) } if $bonus_taken;
	$B.move_to_forbidden($move);
	return self.manual($B,True);
      }
      when ('E') { 
	my $must_use=$B.required.add($move);
	my $now_avail=$B.permitted.add($must_use);
	my $eq_in = prompt "Enter Equation in either AOS or RPN form; use '?' to escape:  ";
	my $rpn;
	if    (valid_rpn($eq_in)) { $rpn=RPN.new($eq_in) }
	elsif (valid_aos($eq_in)) { $rpn=RPN.new_from_aos($eq_in) }
	else                      { return self.manual($B,$bonus_taken) }
	my $rpn_cubes=Bag.new($rpn.list);
	my $result = +$rpn;  # need to validate RPN here
	unless ($result==$B.goal)           { say "Your RPN=$result, which is not the goal!";  return self.manual($B,$bonus_taken) }
	unless ($rpn_cubes (>=) $must_use)  { say "Your RPN does not use all required cubes!"; return self.manual($B,$bonus_taken) }
	unless ($now_avail (>=) $rpn_cubes) { say "Not enough cubes to make your RPN!";        return self.manual($B,$bonus_taken) }
	say "You win!  Congratulations!";  return Nil;
      }
    }
    self; 
  }

  method get_targets(Board $B) {

    note "get_targets for Board:\n{$B.display}";
    
    self.generate_solutions($B) unless (%!S.elems>0);

    unless (%!S.elems>0) {
      note "***I challenge -- I see no solution";
      return Nil;
    }
    
    my Board_Solver $BS .= new($B);
    my Numeric %still_doable{Str};
    my Numeric %not_doable{Str};

    for self.solution_list -> $rpn { $BS.doable_solution($rpn) ?? ( %still_doable{~$rpn} = +$rpn ) !! ( %not_doable{~$rpn} = +$rpn ) }

    if (%still_doable.elems>0) {
      # could possible extend doable solutions here via add / replace
      # choose a move based on the current list of valid solutions
    } else {
      # can we make some solutions doable by extend / replace, or both?

      self.generate_solutions($B) unless (%still_doable.elems>0);
    }
    
    self.filter_solutions($B); 
    self.choose_move($B);  
  }

  # for choose_move, we are guaranteed to only have valid, doable solutions in our current solution_list
  method choose_move(Board $B) {
    my Board_Solver $BS .= new($B);
    
    unless (self.solution_found) { note "***I challenge the bluff -- no solution"; return Nil }  # this shouldn't actually happen here
    
    for self.solution_list -> $rpn {
      if $BS.on-board_solution($rpn) {
	note "***I win:  $rpn, or {$rpn.aos}, is already on the board";
	return Nil;
      }
      my $go_out_cube=$BS.go-out_check($rpn);
      if ($go_out_cube.defined) {
	note "***I win:  I can construct $rpn, or {$rpn.aos}, by bringing $go_out_cube to the Solution";
	return Nil;
      }
    }

    # not done yet -- find a good play
    return self.crazy_move($B) if (^100).pick < 10;    # make probability a Player parameter, and make interface nicer

    # okay--really, now find a good play
    my $target_rpn = self.target_rpn($B);  note "I'm working towards $target_rpn";
    my $pos_options = $BS.cubes-to-go_for($target_rpn);
    if ($pos_options.total>2) { # can consider a move to req or perm -- won't cause a "go-out" for other player
      my $cube=$pos_options.roll;
      if ((^100).pick > 30) {
	say "***I'm moving $cube to required";
	$B.move_to_required($cube);
      } else {  # randomly make a potentially sub-optimal move which nevertheless adds complexity
	say "***I'm moving $cube to permitted";
	$B.move_to_permitted($cube);       # this can be a mistake, if it enables a different solution than $target_rpn
      }
    } else { # do a move to forbidden if possible, otherwise permitted
      my $excess=$B.U (-) $target_rpn.Bag;
      if ($excess.total > 0) {
	my $cube=$excess.roll;
	say "***I'm moving excess $cube to forbidden";
	$B.move_to_forbidden($cube);
      } else {  # no forbidden cubes -- put in permitted
	my $cube=$B.unused.roll;
	say "***I'm moving remaining cube $cube to permitted";
	$B.move_to_permitted($B.unused.roll);
      }
    }

    self;
  }

  method crazy_move(Board $B) {
    my $cube=$B.unused.roll;
    note "***I'm crazily moving $cube to forbidden";  # could move it anywhere, not just forbidden...
    $B.move_to_forbidden($cube);
    return self;
  }

  method target_rpn(Board $B) {
    # should target rpn which uses permitted, since opponent might, all things the same, use a longer rpn
    sub target_fn($a) { ((Bag.new($a.list) (-) $B.R) (-) $B.P).total }
    sub target_sort($a,$b) { ($b.Str.chars <=> $a.Str.chars) or (&target_fn($a) <=> &target_fn($b)) }
    self.solution_list.sort( &target_sort ).[0];
  }
  
  method computed(Board $B, $max_cubes_in?) {
    my $nr = +@[$B.required];
    my $max_cubes = $max_cubes_in // max($nr+(1-($nr%2)),self.solution_list.map({ $_.Str.chars }).max,3);   note "computed with nr=$nr, max_cubes=$max_cubes";

    my Board_Solver $BS .= new($B);
    
    # once in awhile, grab a longer solution
    if ( (^100).pick > 90 ) {
      $BS.calculate_solutions($max_cubes+2);
      for $BS.solution_list -> $rpn { self.save_solution($rpn) }
    }

    # need to work out bonus move for computer, triggered when forbidden move is available
    # and number of unused cubes on board module number of players is not 1.
    
    # need to check permitted+required+1 from unused to make sure we aren't a single 
    # cube away from a solution -- do a recalculation to make sure opponent isn't about
    # to go out.  Maybe only need to do this in the scenario where haven't got a "required" move.
    
    # current solutions still valid?
    my @Go_Out_Cubes=($B.required.Bag (+) $B.permitted.Bag).kxxv;  # + one from the board
 # note "go_out_cubes=@Go_Out_Cubes";    
    loop:  
    my @solutions=self.solution_list;
 # note "old solutions were {@solutions.join("  ")}";
    @solutions=filter_solutions_required(@solutions,$B.required.Bag);  # note "after filtering by required:  {@solutions.join("  ")}";
    for $B.unused.Set {   # note "checking for unused item cube $_";  note "available will be {$Go_Out_Cubes.Bag (+) $_.Bag}";
      my @go_out=filter_solutions_usable(@solutions,@Go_Out_Cubes.Bag (+) $_.Bag);
      if (@go_out.elems > 0) {
	say "I win!  I can go out with solution(s):\n{@go_out.map({$_.aos}).join("  ")}";
	return Nil;
      }
    }
    @solutions=filter_solutions_usable(@solutions,$B.available.Bag);
    if (@solutions) {  # solution still exists; find required or irrelevant cubes
# note "solution still exists with {$B.available} for: {@solutions.join("  ")}";      
      if ( (^100).pick < 10) {  # do something crazy about 10% of the time
	  my $cube=$B.unused.roll;
	  say "***I'm crazily moving $cube to forbidden";
      	  $B.move_to_forbidden($cube);
	  return self;
      }
      # should target rpn which uses permitted, since opponent might, all things the same, use a longer rpn
      sub target_fn($a) { ((Bag.new($a.list) (-) $B.required.Bag) (-) $B.permitted).total }
      sub target_sort($a,$b) { ($b.Str.chars <=> $a.Str.chars) or (&target_fn($a) <=> &target_fn($b)) }
      my $target_rpn = @solutions.sort( &target_sort ).[0];
#      my ($target_rpn) = shuffle @solutions;  # solution we're working towards
note "I'm working towards $target_rpn";      
      my $target_rpn_cubes = Bag.new($target_rpn.list);
      # need to qualify $req_options by what's actually unused!  (could already be in permitted, so not unused)
      my $req_options = ($target_rpn_cubes (-) $B.required.Bag) (&) $B.unused.Bag;
      my $n_from_solve=(($target_rpn_cubes (-) $B.required.Bag) (-) $B.permitted).total;  # n left to solve
      if (($req_options.total > 0) && ($n_from_solve > 2)) {  # can -->req'd if >2 to solve (no go out) & non-empty req'd options
	my $cube=$req_options.roll;
	assert { $B.unused.Bag{$cube} > 0 }, "cube $cube is actually still unused";
	if ((^100).pick > 30) {  
	  say "***I'm moving $cube to required";
	  $B.move_to_required($cube);
	} else {  # randomly make a potentially sub-optimal move which nevertheless adds complexity
	  say "***I'm moving $cube to permitted";
	  $B.move_to_permitted($cube);       # this can be a mistake, if it enables a different solution than $target_rpn
	} 
      } else {
	my $excess=$B.unused.Bag (-) $target_rpn_cubes;
	note "excess cubes for $target_rpn are {$excess.kxxv}";
	if ($excess.total > 0) {
	  my $cube=$excess.roll;
	  say "***I'm moving excess $cube to forbidden";
	  $B.move_to_forbidden($cube);
	} else {  # no forbidden cubes -- put in permitted
	  my $cube=$B.unused.roll;
	  say "***I'm moving remaining cube $cube to permitted";
	  $B.move_to_permitted($B.unused.roll);
	}
      }
    } else {  # have to now go and find new solutions
      note "Recalculating solutions with two more cubes (will be {$max_cubes+2})";
      # not sure any of the following is useful -- reassess later -- might be able "build" new solution from missing number / op?
=begin pod
      # before we clear out the solutions and start over, can we build on our current solution list?
      my @old_solutions=$B.solution_list;  # should filter out solutions which no longer have available cubes
      note "old solutions {@old_solutions.join("  ")}";
      note "Will that ever work with available {$B.available}?";
      my @maybe_solutions=filter_solutions_usable(@old_solutions,$B.available.Bag);
      note "maybe_solutions={@maybe_solutions.join("  ")}";
      for @maybe_solutions -> $old_rpn {
	msg "***>looking at this RPN:  $old_rpn";
	# generate the bag of cubes for this rpn
	my Bag $rpn_bag.= new($old_rpn.list);
	# figure out which required is not in the solution
	my $missing=$B.required.Bag (-) $rpn_bag;
	msg "missing item is $missing";
	# take the available cubes minus those in solution; separate into operators and numbers
	my $avail=$B.available.Bag (-) $rpn_bag;
	msg "available for new board = $avail";
	my @avail_num = $avail.kxxv.grep(/<digit>/); msg "nums = {@avail_num.join(',')}";
	my @avail_ops = $avail.kxxv.grep(/ <op>  /); msg "ops  = {@avail_ops.join(',')}";
	# step through operators
	for @avail_ops.unique -> $op {
	  note "try op $op";
	  #    generate a Board with one required cube and the rest of the available cubes as unused (not including this op)
	  my Board $NB.=new( ($avail (-) $op.Bag) (+) $missing.Bag);
	  $NB.move_to_required($_) for $missing.kxxv;
	  #    set goal to either 0 or 1 depending on operator:
	  if    ($op ~~ /<[+-]>/)    { $NB.install_goal('0') }
	  #      +-   => goal=0
	  elsif ($op ~~ m{<[*/^@]>}) { $NB.install_goal('1') }
	  #      */^@ => goal=1
	  #    calculate goals for (1,3,5,7) cubes
	  msg "Temp Board now set up:\n{$NB.display}";
	  my @i_solutions;
	  for 1,3,5 {
	    $NB.calculate_solutions($_);
	    @i_solutions=$NB.solution_list;
	    last if @i_solutions > 0;
	  }
	  msg "Temp Board solutions {$NB.solution_list.join("  ")}";
	  # append new solutions to old ones
	  if (@i_solutions > 0) {
	    $B.clear_solutions;
	    for @i_solutions -> $new_solution {
	      my $rpn=($op eq '@') ?? RPN.new("$new_solution$old_rpn$op") !! RPN.new("$old_rpn$new_solution$op");
	      msg "FOUND ONE!!!  saving new solution:  $rpn";
	      $B.save_solution($rpn);
	    }
	    msg "And now redo the turn with new solution list";
	    self.computed($B,$max_cubes);
	  }
	}
      }
=end pod
      self.clear_solutions;
      # try to construct the goal with additional cubes for the equation
      die "I challenge you;  I can't see the solution" if $max_cubes+2 > $B.available.Bag.total;  # don't die, but get RPN, eval, then maybe concede
      $BS.calculate_solutions($max_cubes+2);
      for $BS.solution_list -> $rpn { self.save_solution($rpn) }
      
      return self.computed($B,$max_cubes+2);
    }
    
    self;
    
  } # method computed

}  # end class Player

=begin pod

=head1 NAME

Player.pm - Player in an Equations Game

=head1 DESCRIPTION

Functions a player must be able to perform:

   * choose a goal from the board (Unused cubes)
   * Keep track of formulas for achieving a goal
   * decide when to recalculate formulas for achieving a goal
   * decide what cube to move on the board:
     - "forbidden" -- when cubes are not necessary for a solution and too many cubes are on the board
                      so that a solution would be otherwise made possible.
     - "timing" -- bonus move based on cubes left to go out and number of players
     - "go-out" -- when a solution can be achieved
     - "required" -- to cut down on list of allowed solutions
     - "permitted" -- random fraction of moves which would have been "required"
   * identify opponent "mistakes"---when goal has been made impossible
   * resign -- when loss is inevitable

=end pod

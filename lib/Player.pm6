use v6;

use Globals;

class Player {
    
  use RPN;
  use Board;
  
  method choose_goal(Board $board, Int $max_digits=3) {
    my Board $B;  # empty board, will be replaced
    # look for constructibility for each goal option
                                                            note "goal options are {$board.goal_options($max_digits).join(',')}, unused={$board.unused.join(',')}";
    for shuffle($board.goal_options($max_digits)) -> $g {   note "one goal option is $g";
      $B=Board.new($board.unused.join(''));                 note $B.display;
      $B.move_to_goal($g);
      note "calculating goal $g";
      $B.clear_solutions;
      $B.calculate_solutions($_) for (3,5);
      last if $B.solution_list.elems > 0;
    }
    return Nil unless $B.solution_list.elems > 0;
    note "Solutions:  {$B.solution_list.join("\n")}";
    return $B.goal();
  }

  method manual(Board $B, $bonus_taken=False) {

    my ($move,$section);

    put $B.display();
    repeat { $move    = prompt "Cube:  " } until $B.unused.Bag{$move} > 0;
    repeat { $section = prompt "To (R(equired) P(ermitted) F(orbidden) B(onus) E(quation):  " }
      until $section ~~ m:i/^[RPFEB]/;

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

  method computed(Board $B, $max_cubes?) {
    my $nr=$B.required.total;
    $max_cubes //= max($nr+(1-($nr%2)),3);
    
    # need to work out bonus move for computer, triggered when forbidden move is available
    # and number of unused cubes on board module number of players is not 1.
    
    # need to check permitted+required+1 from unused to make sure we aren't a single 
    # cube away from a solution -- do a recalculation to make sure opponent isn't about
    # to go out.  Maybe only need to do this in the scenario where haven't got a "required" move.
    
    # current solutions still valid?
    my $Go_Out_Cubes=$B.required.add($B.permitted);  # + one from the board 
    loop:  
    my @solutions=$B.solution_list;
    @solutions=filter_solutions_required(@solutions,$B.required);
    for ($B.unused.set) {
      my @go_out=filter_solutions_usable(@solutions,$Go_Out_Cubes (+) $_.Bag);
      if (@go_out.elems > 0) {
	say "I win!  I can go out with solution(s):\n{@go_out.map({$_.aos}).join("\n")}";
	return Nil;
      }
    }
    @solutions=filter_solutions_usable(@solutions,$B.available);
    if (@solutions) {  # solution still exists; find required or irrelevant cubes
      if ( (^100).pick < 10) {  # do something crazy about 10% of the time
      	  $B.move_to_forbidden($B.unused.roll);
	  return self;
      }	 
      my Bag $keep;  # keep is all the cubes used in solutions -- don't forbid these
      for (@solutions) { $keep = $keep (+) Bag.new(~$_.list) }  # each $_ is now an RPN object
      # try to put cube in required for shortest solution
      #    my ($shortest_rpn) = sort { length($a) <=> length($b) } @$solutions;  # solution we're working towards
      my ($shortest_rpn) = shuffle @solutions;  # solution we're working towards
      my $shortest_rpn_cubes = Bag.new($shortest_rpn.list);
      # need to qualify $req_options by what's actually unused!  (could already be in permitted, so not unused)
      my $req_options =($shortest_rpn_cubes (-) $B.required.Bag) (&) $B.unused.Bag;
      my $n_from_solve=($shortest_rpn_cubes (-) $B.required.Bag (-) $B.permitted).total;  # n left to solve
      if (($req_options.total > 0) && ($n_from_solve > 2)) {  # can -->req'd if >2 to solve (no go out) & non-empty req'd options
	my $cube=$req_options.roll;
	assert { $B.unused.Bag{$cube} > 0 }, "cube $cube is actually still unused";
	if ((^100).pick > 30) { $B.move_to_required($cube) } else { $B.move_to_permitted($cube) }  # change it up
      } else {
	my $excess=$B.unused.Bag (-) $keep;
	if ($excess.total > 0) {
	  $B.move_to_forbidden($excess.roll);
	} else {  # no forbidden cubes -- put in permitted
	  $B.move_to_permitted($B.unused.roll);
	}
      }
    } else {  # have to now go and find new solutions
      say "Recalculating solutions...";
      # before we clear out the solutions and start over, can we build on our current solution list?
      my @old_solutions=$B.solution_list;  
      msg "old solutions {@old_solutions.join("\n")}";
      for @old_solutions -> $old_rpn {
	msg "looking at this RPN:  $old_rpn";
	# generate the bag of cubes for this rpn
	my Bag $rpn_bag.= new($old_rpn.list);
	# figure out which required is not in the solution
	my $missing=$B.required.Bag (-) $rpn_bag;
	msg "missing item is $missing";
	# take the available cubes minus those in solution; separate into operators and numbers
	my $avail=$B.available.Bag (-) $rpn_bag;
	msg "available for new board = $avail";
	my @avail_num = $avail.kxxv.grep(/<digit>/); msg "nums = {@avail_num.join(',')}";
	my @avail_ops = $avail.kxxv.grep(/ <ops> /); msg "ops  = {@avail_ops.join(',')}";
	# step through operators
	for @avail_ops.unique -> $op {
	  note "try op $op";
	  #    generate a Board with one required cube and the rest of the available cubes as unused (not including this op)
	  my Board $NB.=new( ($avail (-) $op.Bag) (+) $missing.Bag);
	  $NB.move_to_required($_) for $missing.list;
	  #    set goal to either 0 or 1 depending on operator:
	  if    ($op ~~ /<[+-]>/)    { $NB.install_goal('0') }
	  #      +-   => goal=0
	  elsif ($op ~~ m{<[*/^@]>}) { $NB.install_goal('1') }
	  #      */^@ => goal=1
	  #    calculate goals for (1,3,5,7) cubes
	  msg "Temp Board now set up:\n{$NB.display}";
	  my @i_solutions;
	  for (1,3,5) {
	    $NB.calculate_solutions($_);
	    @i_solutions=$NB.solution_list;
	    last if @i_solutions > 0;
	  }
	  msg "Temp Board solutions {$NB.solution_list.join("\n")}";
	  # append new solutions to old ones
	  if (@i_solutions > 0) {
	    $B.clear_solutions;
	    for @i_solutions -> $new_solution {
	      my $rpn=($op eq '@') ?? RPN.new("$new_solution$old_rpn$op") !! RPN.new("$old_rpn$new_solution$op");
	      msg "saving new solution:  $rpn";
	      $B.save_solution($rpn);
	    }
	    msg "And now redo the turn with new solution list";
	    self.computed($B,$max_cubes);
	  }
	  # and we should consider moving solutions to Player instead of Board
	}
      }
      msg "finished";
      $B.clear_solutions;
      # try to construct the goal
      $max_cubes+=2;
      die "I challenge you;  I can't see the solution" if $max_cubes>$B.available.Bag.total;  # don't die, but get RPN, eval, then maybe concede
      $B.calculate_solutions($max_cubes);
      say "{dd $B.solution_list}";
      return self.computed($B,$max_cubes);
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

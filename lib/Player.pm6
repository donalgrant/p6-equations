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

  # should make cube_limit a Player parameter; would also like to thread this
  method generate_solutions( Board $B, $cube_limit=13 ) {
    my Board_Solver $BS .= new($B);
    loop (my $rpn_length=$BS.min_solution_cubes; $rpn_length <= $BS.max_solution_cubes; $rpn_length+=2) {
      last if $rpn_length > $cube_limit;
      $BS.calculate_solutions($rpn_length);
      last if $BS.solution_found;
    }
    note "No solutions possible" unless $BS.solution_found;
    for $BS.solution_list -> $rpn { self.save_solution($rpn) }
  }
  
  # move to Board_Solver
  method choose_goal(Board $board, Int $max_digits=2) {
    my Board $B.= new('');  # Empty Board -- placeholder
    self.clear_solutions;
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
    note "Can get this by:  {self.solution_list.map({ $_.aos }).join('  ')}";
    return $B.goal;
  }

  method manual(Board $B, $bonus_taken=False) {

    my ($move,$section);

    put $B.display();
    repeat { $move    = prompt "Cube or H(int):  " } until ($move ~~ m:i/<[H]>/) or ($B.unused.Bag{$move} > 0);
    if ($move ~~ m:i/<[H]>/) {
	self.generate_solutions($B) unless (%!S.elems>0);
	my Board_Solver $BS .= new($B);
	my @hint_list = self.solution_list.grep({ $BS.doable_solution($_) });
	self.generate_solutions($B) unless @hint_list.elems>0;
	if (@hint_list.elems>0) {
	  say "Example Solution:  {@hint_list.roll.aos}";
	} else { say "I have no idea!" }
	return self.manual($B,$bonus_taken);
    }
    
    repeat { $section = prompt "To (R(equired) P(ermitted) F(orbidden) B(onus) E(quation) H(int):  " }
      until $section ~~ m:i/^<[RPFHEB]>/;

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

  method turn( Board $B ) {

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
      # could possibly extend doable solutions here via add / replace
      # choose a move based on the current list of valid solutions.
      # only worth doing if we then rule out the original solution
      # by requiring something from the new one
      for %still_doable.keys -> $r {
	if (chance(0.1)) {  # make a parameter
	  for $r.comb -> $cube {
	    if (self.find_replacement($B,BagHash.new($cube),RPN.new($r))) {  # add new doable solutions
	      for self.solution_list -> $rpn { %still_doable{~$rpn} = +$rpn if $BS.doable_solution($rpn) }
	      note "***I'm moving $cube to forbidden (because I can replace it in $r)";
	      $B.move_to_forbidden($cube);  # get rid of the cube we can replace -- that's the move
	      return self;
	    }
	  }
	}
      }
    } else {
      # can we make some solutions doable by extend / replace, or both?
      for %not_doable.keys -> $r {
	my $missing = $BS.cubes-missing_for( RPN.new($r) );
	if ($missing.elems > 0) {
	  note "{RPN.new($r).aos} is no longer doable -- needs {$missing.kxxv}";
	  if (self.find_replacement($B,$missing,RPN.new($r))) {  # add new doable solutions
	    for self.solution_list -> $rpn { %still_doable{~$rpn} = +$rpn if $BS.doable_solution($rpn) }
	  }
	} else { # must be a new required which is not part of the RPN
	  my $extra_req = $BS.req-not-in( RPN.new($r) );
	  note "{RPN.new($r).aos} is no longer doable -- required {$extra_req.kxxv}";
	  # only do this (for now?) for a single extra required element
	  
	  # can we extend the formula to include the new number using
	  #   an identity relation?  If R is the original formula, and 
	  #   w is the new number:
	  #     R+(w-F) R-(w-F) where F is 1,3,5 cubes which evaluate to w (needs +,- or -,-)
	  #     R/(w/F) R*(w/F) where F is 1,3,5 cubes which evaluate to w (needs /,* or /,/)
	  #     (w/F)@R R^(w/F) where F is 1,3,5 cubes which evaluate to w (needs /,@ or ^,/)

	  # can we extend the formula to include a new operator using
	  #   an identity relation?  If R is the original formula, and
	  #   o is the new operator:
	  #     RoF      where F is 1,3,5 cubes which evaluate to 0 for o = +,-
	  #     RoF, FoR where F is 1,3,5 cubes which evaluate to 1 for o = *,/,^,@

	}
      }
      note $B.display if %not_doable.elems > 0;
      self.generate_solutions($B) unless (%still_doable.elems>0);
    }
    
    self.filter_solutions($B); 
    self.choose_move($B);  
  }
  
  method find_replacement(Board $B, BagHash $missing, RPN $rpn) {
    return False unless $B.R (<=) $rpn.Bag;   # must be able to use all required cubes
    if ($missing.total>1) {
      note "find_replacement for $rpn is missing ({$missing.kxxv}) more than one cube";
      return False;
    }
    my ($cube)=$missing.kxxv;
    if ($cube~~/<digit>/) {
      # can we construct a missing number with a 3 or 5 element equation
      #     from available cubes not used by RPN?	
      # Set up a Board_Solver to try to find missing cube
      my Bag $b = ($missing (+) $B.allowed) (-) ($rpn.Bag (-) $missing);  # add missing for goal
#      note "Setting up a Board with cubes {$b.kxxv}, which should include missing cube $cube";
      my Board_Solver $BS .= new(Board.new($b).move_to_goal($cube));
      for 3,5 -> $ncubes {
	$BS.calculate_solutions($ncubes);
	if ($BS.solution_found) {
	  for $BS.solution_list -> $r {
#	    note "$ncubes cube solution:  $r";
	    # create a new RPN by replacing in the original rpn
	    my $new_rpn = $rpn.Str;  $new_rpn~~s/$cube/{~$r}/;
#	    note "saving new solution:  $rpn --> $new_rpn";
	    self.save_solution(RPN.new($new_rpn));
	  }
	  return True;
	}
      }
      return False;
    }
#    note "missing cube $cube is an operator";
    return False if $cube~~/<[-/]>/;
    # can we construct a missing operator with an equation representing
    #     is inverse?  (can't do it for '-' and '/')
    #   x+w --> x-(y-z)   where w = z-y
    #   x*w --> x/(y/z)   where w = z/y
    #   x^w --> (y/z)@x   where w = z/y
    #   w@x --> (x^(y/z)) where w = z/y
    
    return False;
  }
  
  # for choose_move, we are guaranteed to only have valid, doable solutions in our current solution_list
  method choose_move(Board $B) {
    
    unless (self.solution_found) { note "***I challenge the bluff -- no solution"; return Nil }  # this shouldn't actually happen here

    my Board_Solver $BS .= new($B);

    for self.solution_list -> $rpn {
      if $BS.on-board_solution($rpn) {
	note "***I win:  {$rpn.aos} is already on the board";
	return Nil;
      }
      my $go_out_cube=$BS.go-out_check($rpn);
      if ($go_out_cube.defined) {
	note "***I win:  I can construct {$rpn.aos} by bringing $go_out_cube to the Solution";
	return Nil;
      }
    }

    # not done yet -- find a good play
    return self.crazy_move($B) if chance(0.1);    # make probability a Player parameter, and make interface nicer

    # okay--really, now find a good play
    # would like to target destruction (culling) of competing rpn's if possible.
    my $target_rpn = self.target_rpn($B);  note "I'm working towards {$target_rpn.aos}";
    my $pos_options = $BS.cubes-to-go_for($target_rpn);
    if ($pos_options.total>2) { # can consider a move to req or perm -- won't cause a "go-out" for other player
      my $cube=$pos_options.roll;
      if (chance(0.75)) {
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
    if (chance(0.75)) {
      note "***I'm crazily moving $cube to forbidden"; 
      $B.move_to_forbidden($cube);
    } else {
      note "***I'm crazily moving $cube to required"; 
      $B.move_to_required($cube);
    }
    return self;
  }

  method target_rpn(Board $B) {
    # should target rpn which uses permitted, since opponent might, all things the same, use a shorter rpn
    sub target_fn($a) { ((Bag.new($a.list) (-) $B.R) (-) $B.P).total }
    sub target_sort($a,$b) { ($a.Str.chars <=> $b.Str.chars) or (&target_fn($a) <=> &target_fn($b)) }
    self.solution_list.sort( &target_sort ).[0];
  }

    # need to work out bonus move for computer, triggered when forbidden move is available
    # and number of unused cubes on board modulo number of players is not 1.

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

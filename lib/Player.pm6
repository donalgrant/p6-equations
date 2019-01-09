use v6;

use Globals;

class Player {
    
  use RPN;
  use Board;
  use Board_Solver;
  use Play;

  has Numeric %.S{Str}=();  # solutions (keys are rpn strings, values are numeric for RPN)

  has $.name              is rw = "Nemo";
  
  has $.crazy_moves       is rw;
  has $.permitted_crazy   is rw;
  has $.required_crazy    is rw;
  has $.forbidden_crazy   is rw;
  has $.extend_solutions  is rw;
  has $.force_required    is rw;

  submethod TWEAK { self.default_parms }
  
  method default_parms {
    $!crazy_moves=0.05;
    $!permitted_crazy=0.50;
    $!required_crazy=0.25;
    $!forbidden_crazy=0.25;
    $!extend_solutions=0.10;
    $!force_required=0.75;
    return self;
  }
  
  method display {
    my $div='–' x 40;
    my $out=qq:to/END/;
    $div
    Player $!name:
           Crazy moves:  {$!crazy_moves*100.0}%
               Permitted:  {$!crazy_moves*$!permitted_crazy*100.0}% 				       
                Required:  {$!crazy_moves*$!required_crazy *100.0}%							   
               Forbidden:  {$!crazy_moves*$!forbidden_crazy*100.0}%
      Extend Solutions:  {$!extend_solutions*100.0}%
        Force Required:  {$!force_required  *100.0}%
    $div													      
    END
    return $out;
  }

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
    self;
  }
  
  # move to Board_Solver
  method choose_goal(Board $board, Int $max_digits=2) {
    my Board $B.= new('');  # Empty Board -- placeholder
    self.clear_solutions;
    # look for constructibility for each goal option
    for shuffle($board.goal_options($max_digits)) -> $g {
      $B=Board.new($board.U.clone);              
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

  method manual_select_cube(Board $B, $p="Cube:  ") {
    my $cube;
    repeat { $cube = prompt $p } until $B.unused.Bag{~$cube} > 0;
    return $cube;
  }

  my %DEST=( F=>'Forbidden', P=>'Permitted', R=>'Required' );
  method manual_select_dest($p="F(orbidden), P(ermitted), or R(equired):  ") {
    my $dest;
    repeat { $dest = prompt $p } until %DEST{$dest.uc}:exists ;
    return %DEST{$dest.uc};
  }
  
  method manual(Board $B) {

    put $B.display();
    
    my $type;
    repeat { $type = prompt "Play:  M=Move a cube, B=Bonus Move, E=Equation, C=Call a bluff, H=Hint:  " }
      until $type ~~ m:i/^<[MBECH]>/;

    given ($type.uc) {
      when ('M') {
	my $cube=self.manual_select_cube($B);
	my $dest=self.manual_select_dest;
	return Play.new(who=>$!name,type=>'Move',:$cube,:$dest);
      }
      when ('B') {
	my $bonus_cube=self.manual_select_cube($B,"Forbidden Cube:  ");
	my $cube=self.manual_select_cube($B);
	my $dest=self.manual_select_dest;
	return Play.new(who=>$!name,type=>'Bonus',:$bonus_cube,:$cube,:$dest);
      }
      when ('C') {
	return Play.new(who=>$!name,type=>'Terminal');
      }
      when ('H') {
	self.generate_solutions($B) unless (%!S.elems>0);
	my Board_Solver $BS .= new($B);
	my @hint_list = self.solution_list.grep({ $BS.doable_solution($_) });
	self.generate_solutions($B) unless @hint_list.elems>0;
	if (@hint_list.elems>0) {
	  say "Example Solution:  {@hint_list.roll.aos}";
	} else { say "I have no idea!" }
	return self.manual($B);
      }
      when ('E') {
	my $cube=self.manual_select_cube($B);
	my Bag $must_use= $B.R (+) Bag.new($cube);
	my Bag $now_avail=$B.P (+) $must_use;
	my $eq_in = prompt "Enter Equation in either AOS or RPN form; use '?' to escape:  ";
	my $rpn;
	if    (valid_rpn($eq_in)) { $rpn=RPN.new($eq_in) }
	elsif (valid_aos($eq_in)) { $rpn=RPN.new_from_aos($eq_in) }
	else                      { return self.manual($B) }
	my $rpn_bag=$rpn.Bag;
	my $result = +$rpn;  # need to validate RPN here
	unless ($result==$B.goal)          { say "Your RPN=$result, which is not the goal!";  return self.manual($B) }
	unless ($rpn_bag (>=) $must_use)   { say "Your RPN does not use all required cubes!"; return self.manual($B) }
	unless ($now_avail (>=) $rpn_bag)  { say "Not enough cubes to make your RPN!";        return self.manual($B) }
	say "You'll win!  Congratulations!";
	return Play.new(who=>$!name,type=>'Terminal',rpn=>$rpn);
      }
    }
  }

  method turn( Board $B ) {

    self.generate_solutions($B) unless (%!S.elems>0);
    
    unless (%!S.elems>0) {
      note "***I challenge -- I see no solution";
      return Play.new(who=>$!name,type=>'Terminal');
    }
    
    my Board_Solver $BS .= new($B);
    my Numeric %still_doable{Str};
    my Numeric %not_doable{Str};

    for self.solution_list -> $rpn { $BS.doable_solution($rpn) ?? ( %still_doable{~$rpn} = +$rpn ) !! ( %not_doable{~$rpn} = +$rpn ) }

    if (%still_doable.elems > 0) {
      # could possibly extend doable solutions here via add / replace
      # choose a move based on the current list of valid solutions.
      # only worth doing if we then rule out the original solution
      # by requiring something from the new one
      for %still_doable.keys -> $r {
	if (chance($!extend_solutions)) {  # make a parameter
	  note "Replacing $r; Board is \n {$B.display}";
	  for $r.comb -> $cube {
	    for self.find_replacement($B,BagHash.new($cube),RPN.new($r)) -> $new_rpn {
	      note "replacement for ($r) is ($new_rpn)";
	      my RPN $rep_rpn .=new($new_rpn);
	      %still_doable{$new_rpn} = +$rep_rpn if $BS.doable_solution($rep_rpn);  # make sure -- not sure we need the call to $BS
	      self.save_solution($rep_rpn);
	      if (BagHash.new($cube) (<=) $B.U) {
		return Play.new(who=>$!name,type=>'Move',dest=>'Forbidden',cube=>$cube,rpn=>$rep_rpn,
				notes=>"I can replace the $cube in $r to get $rep_rpn");
		self.filter_solutions($B);   # need to figure out how to do this
	      }
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
	  for self.find_replacement($B,$missing,RPN.new($r)) -> $new_rpn {
	    my RPN $rpn .=new($new_rpn);
	    %still_doable{$new_rpn} = +$rpn if $BS.doable_solution($rpn);  # make sure -- not sure we need the call to $BS
	    self.save_solution($rpn);
	  }
	} else { # must be a new required which is not part of the RPN
	  my $extra_req = $BS.req-not-in( RPN.new($r) );
	  note "{RPN.new($r).aos} is no longer doable -- does not have required {$extra_req.kxxv}";
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
      self.generate_solutions($B) unless %still_doable.elems > 0;
    }

    self.filter_solutions($B); 
    self.choose_move($B);  
  }

  # returns a list of replacement rpn-strings, or empty list if none found
  # maybe make this whole thing a gather / take?
  method find_replacement(Board $B, BagHash $missing, RPN $rpn) {
    return [] unless $B.R (<=) $rpn.Bag;   # must be able to use all required cubes
    if ($missing.total>1) {
      note "find_replacement for $rpn is missing ({$missing.kxxv}) more than one cube";
      return [];
    }
    my ($cube)=$missing.kxxv;
    if ($cube~~/<digit>/) {
      # can we construct a missing number with a 3 or 5 element equation
      #     from available cubes not used by RPN?	
      # Set up a Board_Solver to try to find missing cube
#      note "creating a bag from missing={$missing.kxxv}; allowed={$B.allowed.kxxv}; rpn={$rpn.Bag.kxxv}";
#      note "bag sums are:  missing+allowed={($missing (+) $B.allowed).kxxv}; rpn-missing={($rpn.Bag (-) $missing).kxxv}";
      my BagHash $b = ($missing (+) $B.allowed) (-) ($rpn.BagHash (-) $missing);  # add missing for goal
#      note "Setting up a Board with cubes {$b.kxxv}, which should include missing cube $cube";
      my Board_Solver $BS .= new(Board.new($b).move_to_goal($cube));
      for 3,5 -> $ncubes {  # no need for 1, otherwise not really a replacement!
	$BS.calculate_solutions($ncubes);
	my @rpn_list = gather {
	  for $BS.solution_list -> $r {
	    next if $cube (elem) $r.Bag;   # don't replace with the same cube!
	    # create a new RPN by replacing in the original rpn
	    my $new_rpn = $rpn.Str;  $new_rpn~~s/$cube/{~$r}/;
	    take $new_rpn;
	  }
	}
	return @rpn_list.elems > 0 ?? @rpn_list !! [];
      }
      return [];
    }
#    note "missing cube $cube is an operator";
    return [] if $cube~~/<[-/]>/;
    # can we construct a missing operator with an equation representing
    #     is inverse?  (can't do it for '-' and '/')
    #   x+w --> x-(y-z)   where w = z-y
    #   x*w --> x/(y/z)   where w = z/y
    #   x^w --> (y/z)@x   where w = z/y
    #   w@x --> (x^(y/z)) where w = z/y
    
    return [];
  }

  # for choose_move, we are guaranteed to only have valid, doable solutions in our current solution_list
  method choose_move(Board $B) {
    
    return self.crazy_move($B) if chance($!crazy_moves) and $B.U.elems > 1;    # non-thinking move -- has to be more than one cube left

    # this shouldn't actually happen here
    unless (self.solution_found) { return Play.new(who=>$!name,type=>'Terminal',note=>"Challenge the bluff -- no solution")  }

    my Board_Solver $BS .= new($B);

    for self.solution_list -> $rpn {
      if $BS.on-board_solution($rpn) {
	return Play.new(who=>$!name,type=>'Terminal',rpn=>$rpn,notes=>"{$rpn.aos} is already on the board");
      }
      my $go_out_cube=$BS.go-out_check($rpn);
      if ($go_out_cube.defined) {
	return Play.new(who=>$!name,type=>'Terminal',rpn=>$rpn,cube=>$go_out_cube,
			notes=>"{$rpn.aos} can be constructed by bringing $go_out_cube to the Solution");
      }
    }

    # now find a good play
    # would like to target destruction (culling) of competing rpn's if possible.
    my $target_rpn = self.target_rpn($B);  note "I'm working towards {$target_rpn.aos}";
    my $pos_options = $BS.cubes-to-go_for($target_rpn);
    my %play=(who=>$!name,type=>'Move',rpn=>$target_rpn);
    if ($pos_options.total>2) { # can consider a move to req or perm -- won't cause a "go-out" for other player
      %play<cube>=$pos_options.roll;
      return Play.new(dest=>'Required', |%play) if chance($!force_required);
      return Play.new(dest=>'Permitted',|%play);
    } else { # do a move to forbidden if possible, otherwise permitted
      my $excess=$B.U (-) $target_rpn.Bag;
      return Play.new(dest=>'Forbidden',cube=>$excess.roll,  notes=>'excess',   |%play) if $excess.total > 0;
      return Play.new(dest=>'Permitted',cube=>$B.unused.roll,notes=>'remaining',|%play);
    }

  }

  method crazy_move(Board $B) {
    my $pc=$!permitted_crazy;
    my $pr=$!required_crazy+$pc;
    my $pf=$!forbidden_crazy+$pr;
    die "crazy moves don't add up:  $pf != 100% for\n {self.display}" unless $pf==1.0;
    my %play=(who=>$!name,type=>'Move',cube=>$B.unused.roll,notes=>'crazy move');
    given rand {
      when 0.0 <= $_ < $pc { return Play.new(dest=>'Permitted',|%play) }
      when $pc <= $_ < $pr { return Play.new(dest=>'Forbidden',|%play) }
      when $pr <= $_ < $pf { return Play.new(dest=>'Required', |%play) }
    }
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

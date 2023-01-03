#!/usr/bin/env perl

use v6;

# use Algorithm::Combinatorics:from<Perl5> qw<tuples>;

use lib '/Users/imel/gitdev/donalgrant/p6-equations/lib';

use Globals;
use RPN;
use Board;
use Board_Solver;
use Player;
use Play;
use Cube;      

sub do-move(Board $b, Play $p) {
  msg $p.display;
  given $p.type {
    when 'Terminal'      { msg "You're calling a bluff" unless defined $p.rpn; return False }
    when 'Bonus'         { $b.move_to_forbidden($p.bonus_cube); proceed }  
    when 'Bonus'|'Move'  {
			  given $p.dest {
			    when 'Forbidden' { $b.move_to_forbidden($p.cube) }
			    when 'Permitted' { $b.move_to_permitted($p.cube) }
			    when 'Required'  { $b.move_to_required( $p.cube) }
			  }
			 }
  }
  return True;
}

sub MAIN(
	 :$verbose=False,          #= print extra diagnostic messages (default=False)
         Int :$seed,               #= specify random number seed
         Int :$max_goal_digits=2 , #= maximum number of digits in the goal (default is two)
	 :$debug,                  #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  my $P1=Player.new(name=>'Computer 1');
  my $P2=Player.new(name=>'Computer 2',
		    crazy_moves=>0.2, required_crazy=>0.5, forbidden_crazy=>0.5, permitted_crazy=>0.0);

  srand($seed) if $seed.defined;
  my @c=[1..12].map({   Red_Cube.new });
  my @d= [1..8].map({  Blue_Cube.new });
  my @e= [1..6].map({ Green_Cube.new });
  my @f= [1..6].map({ Black_Cube.new });
  
  my Cube_Bag $CB.=new([|@c,|@d,|@e,|@f]);

  my $B;
  
  repeat {
    $CB.roll;
    $B=board(Bag.new($CB.showing));
    msg $B.display;
    my $g=board_solver($B).find_goal(max_digits=>$max_goal_digits);
    $B.move_to_goal($g) if $g.defined;
  } until $B.goal.defined;

  msg "Starting Board:\n{$B.display}";

  # Play the game

  loop { 

      msg "Turn {++$}:";
      my $p;  # current play
      
      unless do-move($B,$p=$P1.turn($B)) {
	  if (defined $p.rpn) { msg "{$P1.name} wins!"; last }
	  my $s=$P2.filter_solutions($B).rpn_list;
	  if ($s.elems==0) { msg "{$P1.name} wins by calling Bluff!" }
	              else { msg "{$P2.name} not bluffing and wins with {$s>>.display}!" }
	  last;
      }
      unless do-move($B,$p=$P2.turn($B)) {
	  if (defined $p.rpn) { msg "{$P2.name} wins!"; last }
	  my $s=$P1.filter_solutions($B).rpn_list;
	  if ($s.elems==0) { msg "{$P2.name} wins by calling Bluff!" }
	              else { msg "{$P1.name} not bluffing and wins with {$s>>.display}!" }
	  last;
      }

  }

  msg "Final Board:\n{$B.display}";
}


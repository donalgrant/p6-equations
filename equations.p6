#!/usr/bin/env perl

use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples>;

use lib '/Users/imel/gitdev/donalgrant/p6-equations/lib';

use Globals;
use RPN;
use Board;
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
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  my @c=[1..12].map({   Red_Cube.new });
  my @d= [1..8].map({  Blue_Cube.new });
  my @e= [1..6].map({ Green_Cube.new });
  my @f= [1..6].map({ Black_Cube.new });

  my Cube_Bag $CB.=new([|@c,|@d,|@e,|@f]);
  $CB.roll;

  my Board $B.=new(Bag.new($CB.showing));

  msg $B.display;

  my $P1=Player.new(name=>'Computer 1');
  my $P2=Player.new(name=>'Computer 2',
		    crazy_moves=>0.5, required_crazy=>0.5, forbidden_crazy=>0.5, permitted_crazy=>0.0);

  my $g=$P1.choose_goal($B);

  assert { $g.defined }, "Found a goal from:\n{$B.display}";

  $B.move_to_goal($g);

  msg "Starting Board:\n{$B.display}";

  # Play the game

  loop {

    last unless do-move($B,$P1.turn($B));
    last unless do-move($B,$P2.turn($B));

  }

  msg "Final Board:\n{$B.display}";
}


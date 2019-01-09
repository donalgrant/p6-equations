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

# $::opt{debug}=scalar(@ARGV);

sub do-move(Board $b, Play $p) {
  note $p.display;
  given $p.type {
    when 'Terminal'      { note "You're calling a bluff" unless defined $p.rpn; return False }
    when 'Bonus'         { $b.move_to_forbidden($p.bonus_cube); proceed }  
    when 'Bonus'|'Move'  { given $p.dest {
                               when 'Forbidden' { $b.move_to_forbidden($p.cube) }
			       when 'Permitted' { $b.move_to_permitted($p.cube) }
			       when 'Required'  { $b.move_to_required( $p.cube) }
			     }
			 }
  }
  return True;
}

my @c=[1..12].map({   Red_Cube.new });
my @d= [1..8].map({  Blue_Cube.new });
my @e= [1..6].map({ Green_Cube.new });
my @f= [1..6].map({ Black_Cube.new });

my Cube_Bag $CB.=new([|@c,|@d,|@e,|@f]);
$CB.roll;

my Board $B.=new(Bag.new($CB.showing));

msg $B.display;

my $P1=Player.new(name=>'Computer 1');
my $P2=Player.new(name=>'Computer 2');

my $g=$P1.choose_goal($B);

assert { $g.defined }, "Found a goal from {$B.display}";

$B.move_to_goal($g);

note "Starting Board:\n{$B.display}";

# Play the game

loop {

  last unless do-move($B,$P1.turn($B));
  last unless do-move($B,$P2.turn($B));

}

note "Final Board:\n{$B.display}";


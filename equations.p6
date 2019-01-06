#!/usr/bin/env perl

use v6;

use Algorithm::Combinatorics:from<Perl5> qw<tuples>;

use lib '/Users/imel/gitdev/donalgrant/p6-equations/lib';

use Globals;
use RPN;
use Board;
use Player;
use Cube;      

# $::opt{debug}=scalar(@ARGV);

my @c=[1..12].map({   Red_Cube.new });
my @d= [1..8].map({  Blue_Cube.new });
my @e= [1..6].map({ Green_Cube.new });
my @f= [1..6].map({ Black_Cube.new });

my Cube_Bag $CB.=new([|@c,|@d,|@e,|@f]);
$CB.roll;

my Board $B.=new(Bag.new($CB.showing));

msg $B.display;

my $P1=Player.new;
my $P2=Player.new;
my $P3=Player.new;

my $g=$P1.choose_goal($B);

assert { $g.defined }, "Found a goal from {$B.display}";

$B.move_to_goal($g);

note "Starting Board:\n{$B.display}";

# Play the game

# keep solutions as game is played.  Monitor bag of cubes required for
# solution, and only recalculate if bag is no longer available 

loop {

                    last unless $P3.manual($B); 
#  note "Player 2:"; last unless $P2.turn($B); 
  note "Player 1:"; last unless $P1.turn($B);  

}

note "Final Board:\n{$B.display}";


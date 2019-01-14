#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;

use-ok 'Globals';
use Globals;

use-ok 'Board';
use Board;

use-ok 'Player';
use Player;

use-ok 'Play';
use Play;

sub MAIN(
  :$nBoards=2,           #= Number of boards to play (default=5)
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  subtest "Methods" => {
    my @methods=qw< new choose_goal manual >;  
    can-ok( Player.new, $_ ) for @methods;
  }

  my $P=Player.new;
  my $B=Board.new(Bag.new(qw{1 2 2 3 -}));

  isa-ok($P,'Player');
  isa-ok($B,'Board');

  diag $B.display if opt('verbose');

  subtest "Choose Goal" => {

    my $g=$P.choose_goal($B);

    is( $g, 1, "Only one goal possible");

    ok( $P.choose_goal(Board.new(Bag.new(qw{ 1 2 3 4 5 6 7 8 9 - + * / ^ @ }))).defined, "Found a goal on a larger board" );
    is( $P.choose_goal(Board.new(Bag.new(qw{ - * - + / }))),      Nil, "No goal possible: no numbers");
    is( $P.choose_goal(Board.new(Bag.new(qw{ 1 - + / }))),        Nil, "No goal possible: single digit");
    is( $P.choose_goal(Board.new(Bag.new(qw{ 1 2 3 * / }))),      Nil, "No goal possible: cannot construct" );
    is( $P.choose_goal(Board.new(Bag.new(qw{ 1 2 1 2 * / })), 1), Nil, "No goal possible: 1 digit, no singletons" );

  }

  my $cube_str='*++------///001111112333356@@@25';

  subtest "Parameter Verification" => {

    $P.permitted_crazy=0.6;   # without changing the other types, this should break
    dies-ok { $P.crazy_move(Board.new(Bag.new($cube_str.comb))) }, "crazy_move fails with inconsistent parameters";
    $P.permitted_crazy=0.5;   # reset

  }

  # play boards


  sub do-move(Board $b, Play $p) {
    diag $p.display if opt('verbose');
    given $p.type {
      when 'Terminal'      { msg "You're calling a bluff" unless defined $p.rpn; return False }
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

  set_opt('quiet') unless opt('verbose') or debug;
  
  subtest "Play $nBoards Games" => {
    plan $nBoards * 3;
    for ^$nBoards {
      diag "Testing Game $_" if opt('verbose');
      $P.name="Test Player $_";
      $P.crazy_moves=$_*0.25;
      $P.force_required=1.0-0.1*$_;
      $P.extend_solutions=0.1*$_;
      diag $P.display if opt('verbose');
      $B=Board.new(Bag.new($cube_str.comb));
      my $g=$P.choose_goal($B);
      ok( $g.defined, "Choose a goal" );
      ok( $B.move_to_goal($g), "move to goal" );
      inner:
      loop { 
	diag $B.display if opt('verbose');
	last unless do-move($B,$P.turn($B));
      }
      pass "Game $_ Completed";
    }
  }

  # test for manual?

  done-testing();
  
}

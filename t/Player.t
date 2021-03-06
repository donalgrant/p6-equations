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

use-ok 'Board_Solver';
use Board_Solver;

use-ok 'RPN';
use RPN;

sub MAIN(
  :$nBoards=2,           #= Number of boards to play (default=5)
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  subtest "Methods" => {
    my @methods=qw< new manual reset >;  
    can-ok( Player.new, $_ ) for @methods;
  }

  my $P=Player.new;
  my $B=board(Bag.new(qw{1 2 2 3 -}));

  isa-ok($P,'Player');
  isa-ok($B,'Board');

  diag $B.display if opt('verbose');

  my $cube_str='*++------///001111112333356@@@25';

  subtest "Parameter Verification" => {

    my $P=Player.new(force_required=>1.0,name=>'Parm-Ver-Test');
    is $P.force_required,  1.0, "Can initialize force_required in constructor";
    is $P.permitted_crazy, 0.5, "But other parameters get default";
    
    $P.permitted_crazy=0.6;   # without changing the other types, this should break
    is $P.permitted_crazy, 0.6, "Able to set permitted_crazy";
    dies-ok { $P.crazy_move(board(Bag.new($cube_str.comb))) }, "crazy_move fails with inconsistent parameters";
    
    isa-ok($P.reset, 'Player', "Force reset to defaults");
    is $P.name, 'Parm-Ver-Test', "Name preserved through reset";
    is $P.permitted_crazy, 0.5, "Back to default value of permitted_crazy";

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

  set_opt('quiet') unless opt('verbose');
  
  subtest "Play $nBoards Games" => {
    plan $nBoards * 3;
    for ^$nBoards {
      diag "Testing Game $_" if opt('verbose');
      $P.name="Test Player $_";
      $P.crazy_moves=$_*0.25;
      $P.force_required=1.0-0.1*$_;
      $P.extend_solutions=0.1*$_;
      diag $P.display if opt('verbose');
      $B=board(Bag.new($cube_str.comb));
      my $g=board_solver($B).find_goal;
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

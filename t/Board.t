#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;
use-ok 'Board';
use Board;

use-ok 'Globals';
use Globals;

sub MAIN(
  :$verbose=False,       #= print extra diagnostic messages (default=False)
  :$debug,               #= comma separated list of debug labels (or 'all') (default none)
) {

  set_opt('verbose') if $verbose;
  if ($debug) { set_debug($_) for $debug.split(',') }

  subtest "methods" => {
    my @board_methods=qw<new U R P F G required permitted forbidden unused goal
  		       available display move_to_required move_to_permitted move_to_forbidden move_to_goal
  		       install_goal req_num_tuples req_ops_tuples goal_options>;
  
    can-ok( Board.new(''), $_ ) for @board_methods;
  }
  
  my $cube_list=qw{1 2 2 3 - +};
  
  my $B;
  
  subtest "Construction" => {
    dies-ok( { Board.new }, "Must specify mandatory BagHash U");
  
    isa-ok($B=Board.new(U=>BagHash.new($cube_list)),'Board', "Board constructed with named Unused");
    isa-ok($B=Board.new(U=>BagHash.new(qw{ 3 }),
  		      R=>BagHash.new(qw{ 2 + }),
  		      P=>BagHash.new(qw{ 2 2 / }),
  		      F=>BagHash.new(qw{ 0 0 0 ^ ^ @ @ * 1 3 2 2 5 7 }),
  		      G=>"4"),                       'Board', "Board with all regions specified\n{$B.display}");
  
    isa-ok(Board.new($cube_list.join('')),       'Board', "Board from String");
    isa-ok(Board.new($cube_list.join(' ')),      'Board', "Board with spaces");   # ignore spaces
    isa-ok(Board.new([$cube_list]),              'Board', "Board from Array");
    isa-ok(Board.new($cube_list),                'Board', "Board from List");
    isa-ok(Board.new(Bag.new($cube_list)),       'Board', "Board from Bag");
    isa-ok(Board.new(Bag.new($cube_list).kxxv),  'Board', "Board from Seq");
    isa-ok(Board.new(BagHash.new($cube_list)),   'Board', "Board from BagHash");
  }

  subtest "Construction using board" => {
    isa-ok(board($cube_list.join('')),       'Board', "Board from String");
    isa-ok(board($cube_list.join(' ')),      'Board', "Board with spaces");   # ignore spaces
    isa-ok(board([$cube_list]),              'Board', "Board from Array");
    isa-ok(board($cube_list),                'Board', "Board from List");
    isa-ok(board(Bag.new($cube_list)),       'Board', "Board from Bag");
    isa-ok(board(Bag.new($cube_list).kxxv),  'Board', "Board from Seq");
    isa-ok(board(BagHash.new($cube_list)),   'Board', "Board from BagHash");
  }
  
  $B = Board.new($cube_list.join(' '));
  
  subtest "Regions" => {
    isa-ok($B,'Board',"Board from string with spaces");
    lives-ok({ put $B.display },"Display a board -- check for space removal");
    
    ok $B.unused.Bag == $cube_list.comb(/\S/).Bag, "initial unused";
    
    ok $B.required  == qw< >,   "initial required";
    ok $B.permitted == qw< >,   "initial permitted";
    ok $B.forbidden == qw< >,   "initial forbidden";
  
    ok $B.available == $B.unused, "initial available";

    nok $B.goal.defined, "initially, goal is not defined";
    
    is $B.goal_options.sort(+*), [ 1,3,12,13,21,22,23,31,32,
  				 122,123,132,212,213,221,
  				 223,231,232,312,321,322 ].sort(+*), "initial goals";
  }
  
  subtest "Moves" => {
    lives-ok( { $B.move_to_forbidden('3').move_to_permitted('+') }, "Chained moves" );
    
    my Board $C = $B.clone;  # create a disconnected copy of $B
    
    lives-ok( { $C.move_to_required('2') }, "move a cube in the cloned board" );
    
    ok $C.unused    == qw{ 1 2 - },  "moves in original should not affect clone";
    
    $B.move_to_required('-');
    
    ok $B.unused    == qw< 1 2 2 >, "initial unused; moves in clone should not affect original";
    ok $B.required  == [ '-' ],     "initial required";
    ok $B.permitted == [ '+' ],     "initial permitted";
    ok $B.forbidden == [ '3' ],     "initial forbidden";
    ok $B.available.sort == [ |$B.unused, |$B.required, |$B.permitted ].sort,  "initial available";
  
    ok $B.goal_options == ( 1,12,21,22,122,212,221 ), "initial goals";
  
    $B=Board.new(qw{ 0 0 0 0 2 2 3 3 3 4 5 7 7 8 8 * + + + - - / / @ @ ^ 8 3 + 8 - - / / ^ * 2 5 > }.join(''));
    $B.move_to_permitted($_) for qw{ 8 3 + };
    $B.move_to_required($_)  for qw{ 8 - - ^ * 2 5 };
  
    lives-ok({ put $B.display },"Display a larger board");

    nok $B.goal.defined, "Goal not defined prior to being set";
    
    $B.move_to_goal("20");
    ok $B.goal.defined, "Goal defined after being set";
    
    is( $B.goal, 20, "Goal is set for this board" );
  }

  subtest "Feasibility and Cube Counts" => {
    $B=Board.new(U=>BagHash.new(qw{ 1 2 + + + }), R=>BagHash.new(qw{ 6 - - }));
    is $B.n_req_ops, 2, "Number of Required ops";
    is $B.n_req_num, 1, "Number of Required digits";
    is $B.n_all_ops, 5, "Number of Allowed ops";
    is $B.n_all_num, 3, "Number of Allowed digits";
    ok $B.equation_feasible, "Required ops one less than available digits";
    $B.move_to_required('+');
    nok $B.equation_feasible, "Required ops equal to available digits is unfeasible equation";
  }
  done-testing;

}
